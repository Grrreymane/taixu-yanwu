'use strict';

// Normal movement and attacks only: inspect both horizontal scene limits.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../build/screenshots/scene-art-browser');
const report = { errors: [], warnings: [], captures: [], fps: [] };
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(15000);
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); else if (m.type() === 'warning') report.warnings.push(m.text()); });
    await page.goto('http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    await page.locator('canvas').click({ position: { x: 700, y: 400 } });
    const read = () => page.evaluate(() => JSON.parse(JSON.stringify(window.__godotState)));
    const action = name => page.evaluate(name => window.__godotAction(name), name);
    const idle = () => page.waitForFunction(() => window.__godotState.player.state === 'idle');
    async function shot(name) {
      report.captures.push({ name, state: await read() });
      await page.screenshot({ path: path.join(out, name + '.png') });
    }
    async function practice() {
      await action('practice');
      await page.waitForFunction(() => window.__godotState.started && window.__godotState.campaign.mode === 'practice' && window.__godotState.enemy.hp === 100 && window.__godotState.time < 0.5);
      if (!(await read()).training) { await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training); }
    }
    async function approach() {
      await page.keyboard.down('d');
      try { await page.waitForFunction(() => window.__godotState.enemy.x - window.__godotState.player.x < 1.15); }
      finally { await page.keyboard.up('d'); }
      await idle();
    }
    await practice();
    await page.keyboard.down('a');
    await page.waitForFunction(() => window.__godotState.player.x < -5.45);
    await page.keyboard.up('a'); await idle(); await page.waitForTimeout(350);
    await shot('edge-left-wide');
    assert.ok(report.captures.at(-1).state.player.x <= -5.45);
    await practice();
    // Body collision prevents walking through the dummy. Five K strikes and
    // one E push its living body to +5.5; D then reaches the playable right gap.
    for (const key of ['k', 'k', 'k', 'k', 'k', 'e']) {
      await approach(); await page.keyboard.press(key);
      await page.waitForFunction(() => window.__godotState.player.state === 'attack');
      await idle(); await page.waitForTimeout(130);
      report.fps.push((await read()).fps);
    }
    await page.keyboard.down('d');
    await page.waitForFunction(() => window.__godotState.player.x > 4.75);
    await page.keyboard.up('d'); await idle(); await page.waitForTimeout(400);
    await shot('edge-right-wide');
    const edge = report.captures.at(-1).state;
    assert.ok(edge.enemy.hp > 0 && edge.enemy.x > 5.4 && edge.player.x > 4.75);
    await page.setViewportSize({ width: 960, height: 540 }); await page.waitForTimeout(250);
    await shot('edge-right-small');
    assert.deepEqual(report.errors, []);
    report.passed = true;
    console.log(JSON.stringify({ passed: true, errors: report.errors, warnings: report.warnings, fps: report.fps }));
  } catch (e) { report.passed = false; report.fatal = e.stack; throw e; }
  finally { fs.writeFileSync(path.join(out, 'scene-edge-report.json'), JSON.stringify(report, null, 2)); await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
