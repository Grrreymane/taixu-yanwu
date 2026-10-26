'use strict';

// Final export smoke check. Ordinary start action; no combat state mutations.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../build/screenshots/scene-art-browser');
const report = { errors: [], warnings: [] };
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); else if (m.type() === 'warning') report.warnings.push(m.text()); });
    await page.goto('http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    await page.locator('canvas').click({ position: { x: 700, y: 400 } });
    await page.evaluate(() => window.__godotAction('start'));
    await page.waitForFunction(() => window.__godotState.started && window.__godotState.campaign.mode === 'trial');
    await page.waitForTimeout(2000);
    report.state = await page.evaluate(() => JSON.parse(JSON.stringify(window.__godotState)));
    await page.screenshot({ path: path.join(out, 'final-courtyard.png') });
    assert.ok(report.state.ready && report.state.started);
    assert.deepEqual(report.errors, []);
    report.passed = true;
    console.log(JSON.stringify({ passed: true, ready: report.state.ready, errors: report.errors, warnings: report.warnings, fps: report.state.fps }));
  } catch (e) { report.passed = false; report.fatal = e.stack; throw e; }
  finally { fs.writeFileSync(path.join(out, 'scene-final-load-report.json'), JSON.stringify(report, null, 2)); await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
