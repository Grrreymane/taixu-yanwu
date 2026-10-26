'use strict';

// Focused follow-up to music-browser.cjs: preserve the full natural-loop report.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../build/screenshots/defensive-retarget');
const report = { checks: [], failures: [], errors: [], warnings: [], samples: {} };
function check(label, body) {
  try { body(); report.checks.push({ label, passed: true }); }
  catch (e) { report.checks.push({ label, passed: false }); report.failures.push({ label, message: e.message }); }
}
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(15000);
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); else if (m.type() === 'warning') report.warnings.push(m.text()); });
    await page.addInitScript(() => {
      window.__muteProbe = { outputs: [], peak: 0, starts: 0 };
      const connect = AudioNode.prototype.connect;
      AudioNode.prototype.connect = function (...args) {
        const result = connect.apply(this, args);
        if (args[0] instanceof AudioDestinationNode) {
          const analyser = this.context.createAnalyser(); analyser.fftSize = 1024;
          connect.call(this, analyser);
          window.__muteProbe.outputs.push({ analyser, data: new Float32Array(1024) });
        }
        return result;
      };
      const start = AudioBufferSourceNode.prototype.start;
      AudioBufferSourceNode.prototype.start = function (...args) {
        if (this.buffer?.duration > 5) window.__muteProbe.starts++;
        return start.apply(this, args);
      };
      setInterval(() => {
        const p = window.__muteProbe; let sum = 0, count = 0;
        for (const output of p.outputs) {
          output.analyser.getFloatTimeDomainData(output.data);
          for (const value of output.data) { sum += value * value; count++; }
        }
        p.peak = Math.max(p.peak, count ? Math.sqrt(sum / count) : 0);
      }, 20);
    });
    await page.goto('http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready && Number.isFinite(window.__godotState.music?.gain), null, { timeout: 90000 });
    const read = () => page.evaluate(() => ({ state: structuredClone(window.__godotState), rms: window.__muteProbe.peak, sourceStarts: window.__muteProbe.starts }));
    const clear = () => page.evaluate(() => { window.__muteProbe.peak = 0; });
    const action = name => page.evaluate(name => window.__godotAction(name), name);
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => window.__godotState.music.playing);
    await page.waitForTimeout(800);
    await action('practice'); await page.waitForFunction(() => window.__godotState.campaign.mode === 'practice' && !window.__godotState.paused);
    if (!(await read()).state.training) { await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training); }
    report.samples.on = await read();
    check('Music starts once and produces actual audio', () => { assert.equal(report.samples.on.sourceStarts, 1); assert.ok(report.samples.on.rms > 0.00001); });
    await page.keyboard.press('m'); await page.waitForFunction(() => window.__godotState.music.gain === 0);
    await page.waitForTimeout(160); await clear(); await page.waitForTimeout(400);
    report.samples.off = await read();
    check('Music-off has exactly zero output rather than residual attenuation', () => {
      assert.equal(report.samples.off.state.music.gain, 0); assert.equal(report.samples.off.rms, 0);
      assert.equal(report.samples.off.sourceStarts, 1);
    });
    await page.keyboard.down('d');
    try { await page.waitForFunction(() => Math.abs(window.__godotState.enemy.x - window.__godotState.player.x) < 1.15); }
    finally { await page.keyboard.up('d'); }
    await page.waitForFunction(() => window.__godotState.player.state === 'idle');
    await clear(); await page.keyboard.press('j'); await page.waitForFunction(() => window.__godotState.enemy.hp < 100);
    await page.waitForTimeout(200); report.samples.hit = await read();
    check('A normal J still produces its hit sound while BGM is fully muted', () => {
      assert.equal(report.samples.hit.state.music.gain, 0); assert.ok(report.samples.hit.rms > 0.00001);
    });
    await page.waitForFunction(() => window.__godotState.player.state === 'idle'); await page.waitForTimeout(200);
    await clear(); await page.keyboard.press('m'); await page.waitForTimeout(800);
    report.samples.restored = await read();
    check('M restores the same song without stacking or restarting it', () => {
      assert.ok(report.samples.restored.state.music.gain > 0.05 && report.samples.restored.rms > 0.00001);
      assert.equal(report.samples.restored.sourceStarts, 1); assert.equal(report.samples.restored.state.music.starts, 1);
    });
    check('Every exposed numeric music value stays finite, including true mute', () => {
      for (const sample of Object.values(report.samples)) for (const value of Object.values(sample.state.music)) if (typeof value === 'number') assert.ok(Number.isFinite(value));
    });
    check('No engine/browser errors or warnings', () => { assert.deepEqual(report.errors, []); assert.deepEqual(report.warnings, []); });
    report.passed = report.failures.length === 0;
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, errors: report.errors, warnings: report.warnings,
      rms: Object.fromEntries(Object.entries(report.samples).map(([key, value]) => [key, value.rms])) }, null, 2));
    assert.ok(report.passed, 'See music-mute-report.json');
  } catch (e) { report.passed = false; report.fatal = e.stack; throw e; }
  finally { fs.mkdirSync(out, { recursive: true }); fs.writeFileSync(path.join(out, 'music-mute-report.json'), JSON.stringify(report, null, 2)); await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
