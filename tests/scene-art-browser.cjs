'use strict';

// Real-input scene QA: progress through the trial to all three regions.
// No state mutation, stage skipping, or user-facing debug controls.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../build/screenshots/scene-art-browser');
const report = { startedAt: new Date().toISOString(), errors: [], regions: [], captures: [], retries: 0 };
function save() { fs.mkdirSync(out, { recursive: true }); fs.writeFileSync(path.join(out, 'scene-art-report.json'), JSON.stringify(report, null, 2)); }

(async () => {
  save();
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(15000);
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); });
    page.on('response', r => { if (r.status() >= 400) report.errors.push(`${r.status()} ${r.url()}`); });
    await page.goto('http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    const read = () => page.evaluate(() => JSON.parse(JSON.stringify(window.__godotState)));
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    async function shot(name) {
      const before = await read();
      await page.screenshot({ path: path.join(out, name + '.png') });
      report.captures.push({ name, state: before }); save();
    }
    async function release() { await action('move', 0); await action('guard_held', false); }
    await page.locator('canvas').click({ position: { x: 700, y: 400 } });
    await action('menu'); await page.waitForFunction(() => window.__godotState.campaign.phase === 'menu');
    await page.waitForTimeout(400); await shot('00-menu');
    await page.keyboard.press('Enter'); await page.waitForFunction(() => window.__godotState.started);
    const began = Date.now();
    let seenStage = -1, rewardStage = -1, inkCaptured = false, inkRestored = false;
    while (Date.now() - began < 240000) {
      const s = await read(), c = s.campaign, p = s.player;
      if (c.phase === 'failed') {
        await shot('failed-' + c.stageIndex);
        if (report.retries++ >= 1) throw new Error('Normal-input trial could not reach region ' + c.regionIndex);
        await action('retry'); await page.waitForTimeout(250); continue;
      }
      if (c.phase === 'cleared') break;
      if (c.phase === 'reward') {
        await release();
        if (rewardStage !== c.stageIndex) {
          rewardStage = c.stageIndex;
          const choice = c.rewards.findIndex(reward => reward.id === 'breath');
          await page.keyboard.press(String((choice < 0 ? 0 : choice) + 1));
        }
        await page.waitForTimeout(100); continue;
      }
      if (seenStage !== c.stageIndex) {
        seenStage = c.stageIndex; await release();
        if (c.stageIndex % 2 === 0) {
          const region = Math.floor(c.stageIndex / 2);
          console.log('SCENE region', region, c.region);
          await page.waitForTimeout(400); await shot('region-' + region + '-opening');
          await page.waitForFunction(() => window.__godotState.stageCountdown <= 0);
          await shot('region-' + region + '-combat');
          report.regions.push(region);
          if (region === 2) {
            await page.setViewportSize({ width: 960, height: 540 });
            await page.waitForTimeout(200); await shot('region-2-small');
            await page.setViewportSize({ width: 1440, height: 900 });
          }
          if (report.regions.length === 3 && inkRestored) break;
        }
        continue;
      }
      if (s.paused) { await page.keyboard.press('Escape'); continue; }
      if (s.ended) { await release(); await page.waitForTimeout(100); continue; }
      if (s.ultimate) {
        await release();
        if (!inkCaptured && s.ultimateTime > 0.75 && s.ultimateTime < 2.0) {
          await shot('ultimate-arena-hidden'); inkCaptured = true;
        }
        await page.waitForTimeout(65); continue;
      }
      if (inkCaptured && !inkRestored && !s.cinematic.returning) {
        await release(); await page.waitForTimeout(250); await shot('ultimate-arena-restored');
        const restored = await read();
        assert.equal(restored.cinematic.active, false); assert.equal(restored.cinematic.returning, false);
        inkRestored = true;
      }
      const live = s.enemies.filter(e => e.hp > 0);
      const nearest = live.sort((a, b) => Math.abs(a.x - p.x) - Math.abs(b.x - p.x))[0];
      if (!nearest) { await page.waitForTimeout(70); continue; }
      const distance = Math.abs(nearest.x - p.x);
      const threat = live.find(e => e.state === 'attack' && !e.attack.hasHit && Math.abs(e.x - p.x) < e.attack.range + 0.3 && e.attack.windup - e.stateTime > 0 && e.attack.windup - e.stateTime < 0.19);
      let command = null, guard = false;
      if (['idle', 'move', 'guard'].includes(p.state)) {
        if (threat) { if (threat.attack.unblockable) command = 'dodge'; else guard = true; }
        else if (p.energy >= 100) command = 'ultimate';
        else if (p.skillCooldown <= 0 && distance < 2.5) command = 'ability';
        else if (distance < 1.7) command = nearest.state === 'guard' ? 'heavy' : 'light';
      } else if (p.state === 'attack' && p.attack.name === 'light' && p.stateTime > 0.1) command = nearest.state === 'guard' ? 'heavy' : 'light';
      await action('move', distance > 1.3 ? Math.sign(nearest.x - p.x) : 0);
      await action('guard_held', guard); if (command) await action(command);
      await page.waitForTimeout(65);
    }
    await release(); report.final = await read(); report.inkCaptured = inkCaptured; report.inkRestored = inkRestored;
    assert.deepEqual([...new Set(report.regions)].sort(), [0, 1, 2]);
    assert.ok(inkCaptured && inkRestored, 'Real ultimate and battle restoration were captured');
    assert.equal(report.final.training, false); assert.deepEqual(report.errors, []);
    report.passed = true; report.finishedAt = new Date().toISOString(); save();
    console.log('SCENE PASS: 3 real trial regions, small window, ultimate hide/restore, errors=0');
  } catch (e) { report.passed = false; report.fatal = e.stack; save(); throw e; }
  finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
