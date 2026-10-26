'use strict';

// Focused visual recheck after the final parry and opening-banner adjustment.
// Inputs are ordinary game actions; all game state is read-only.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../build/screenshots/visual-iteration-final');
const report = { startedAt: new Date().toISOString(), checks: [], failures: [], errors: [], captures: [], attempts: [] };
function save() { fs.mkdirSync(out, { recursive: true }); fs.writeFileSync(path.join(out, 'visual-focus-report.json'), JSON.stringify(report, null, 2)); }
function check(name, body) { try { body(); report.checks.push({ name, passed: true }); } catch (e) { report.checks.push({ name, passed: false }); report.failures.push({ name, error: e.message }); } }

(async () => {
  save();
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(12000);
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); });
    page.on('response', r => { if (r.status() >= 400) report.errors.push(`${r.status()} ${r.url()}`); });
    await page.goto('http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    await page.locator('canvas').click({ position: { x: 700, y: 400 } });
    const read = () => page.evaluate(() => JSON.parse(JSON.stringify(window.__godotState)));
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    async function shot(name) {
      const before = await read();
      await page.screenshot({ path: path.join(out, name + '.png') });
      report.captures.push({ name, before, after: await read() }); save();
    }
    async function practice() {
      for (const key of ['l', 'a', 'd']) await page.keyboard.up(key);
      await action('move', 0); await action('guard_held', false); await action('practice');
      await page.waitForFunction(() => {
        const s = window.__godotState;
        return s.started && !s.paused && s.campaign.mode === 'practice' && s.enemy.hp === 100 && s.time < 0.5;
      });
      if (!(await read()).training) { await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training); }
      await page.keyboard.down('d');
      try { await page.waitForFunction(() => Math.abs(window.__godotState.enemy.x - window.__godotState.player.x) < 1.15); }
      finally { await page.keyboard.up('d'); }
      await page.waitForFunction(() => window.__godotState.player.state === 'idle');
      return read();
    }
    await practice(); await shot('01-opening-near');
    await page.waitForTimeout(1700); await shot('02-idle-clear');
    console.log('FOCUS normal parry');
    let parried = false;
    for (let attempt = 0; attempt < 4; attempt++) {
      await practice(); await page.waitForTimeout(200);
      await page.keyboard.press('t'); await page.waitForFunction(() => !window.__godotState.training);
      await page.waitForFunction(() => {
        const e = window.__godotState.enemy;
        return e.state === 'attack' && !e.attack.hasHit && e.attack.windup - e.stateTime > 0.12;
      });
      const before = await read();
      const remaining = before.enemy.attack.windup - before.enemy.stateTime;
      await page.waitForTimeout(Math.max(0, (remaining - [0.1, 0.08, 0.12, 0.06][attempt]) * 1000));
      await page.keyboard.down('l');
      try {
        await page.waitForFunction(() => window.__godotState.feel.accent.kind === 'parry' && window.__godotState.feel.accent.amount > 0.4, null, { timeout: 1800 });
        await page.keyboard.press('Escape'); await page.waitForFunction(() => window.__godotState.paused);
        const contact = await read();
        report.attempts.push({ attempt, remaining, success: true, contact });
        await shot('03-parry-paused');
        check('Normal L input produces a real perfect defense', () => {
          assert.equal(contact.player.hp, 100); assert.equal(contact.enemy.state, 'stagger');
          assert.equal(contact.feel.accent.kind, 'parry'); assert.ok(contact.feel.accent.amount > 0);
        });
        await page.keyboard.press('Escape'); await page.waitForFunction(() => !window.__godotState.paused);
        await page.keyboard.up('l');
        await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training);
        await page.waitForTimeout(500); await shot('04-parry-restored');
        check('Parry accent clears after normal resume', () => assert.equal(report.captures.at(-1).before.feel.accent.amount, 0));
        parried = true; break;
      } catch (e) { report.attempts.push({ attempt, remaining, success: false, error: e.message }); }
    }
    check('A real parry was captured', () => assert.equal(parried, true));
    console.log('FOCUS small opening');
    await page.setViewportSize({ width: 960, height: 540 });
    await practice(); await shot('05-small-opening');
    await page.waitForTimeout(1700); await shot('06-small-idle');
    check('Small-window idle keeps a valid camera and healthy fighters', () => {
      const s = report.captures.at(-1).before;
      assert.equal(s.player.hp, 100); assert.equal(s.enemy.hp, 100);
      assert.ok(s.cinematic.position.every(Number.isFinite)); assert.equal(s.cinematic.active, false);
    });
    check('No browser or asset errors', () => assert.deepEqual(report.errors, []));
    report.passed = report.failures.length === 0; report.finishedAt = new Date().toISOString(); save();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, errors: report.errors, failures: report.failures }));
    assert.ok(report.passed, 'See visual-focus-report.json');
  } catch (e) { report.fatal = e.stack; report.passed = false; save(); throw e; }
  finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
