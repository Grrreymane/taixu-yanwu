'use strict';

// Normal keys, HUD actions and a second blank tab only. Audio probes observe
// the existing Web Audio output; they never replace the game's audio engine.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../../build/screenshots', process.env.GODOT_TEST_OUTPUT || 'defensive-retarget');
const report = { checks: [], errors: [], warnings: [], httpErrors: [], samples: {}, failures: [] };

function check(label, body) {
  try { body(); report.checks.push({ label, passed: true }); }
  catch (e) { report.checks.push({ label, passed: false }); report.failures.push({ label, message: e.message }); }
}
function save() { fs.mkdirSync(out, { recursive: true }); fs.writeFileSync(path.join(out, 'music-report.json'), JSON.stringify(report, null, 2)); }

(async () => {
  fs.mkdirSync(out, { recursive: true });
  // Do not bypass autoplay: a real key or click must enable the audio context.
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    await context.addInitScript(() => {
      window.__musicProbe = { outputs: [], samples: [], sources: [] };
      const start = AudioBufferSourceNode.prototype.start;
      AudioBufferSourceNode.prototype.start = function (...args) {
        const entry = { node: this, ended: false, args, startedAt: this.context.currentTime };
        this.addEventListener('ended', () => { entry.ended = true; });
        window.__musicProbe.sources.push(entry);
        return start.apply(this, args);
      };
      const connect = AudioNode.prototype.connect;
      AudioNode.prototype.connect = function (...args) {
        const result = connect.apply(this, args);
        if (args[0] instanceof AudioDestinationNode) {
          const analyser = this.context.createAnalyser();
          analyser.fftSize = 1024;
          connect.call(this, analyser);
          window.__musicProbe.outputs.push({ analyser, context: this.context, data: new Float32Array(1024) });
        }
        return result;
      };
      setInterval(() => {
        const p = window.__musicProbe;
        let sum = 0, count = 0;
        for (const output of p.outputs) {
          output.analyser.getFloatTimeDomainData(output.data);
          for (const value of output.data) { sum += value * value; count++; }
        }
        p.samples.push({ ms: performance.now(), rms: count ? Math.sqrt(sum / count) : 0 });
        if (p.samples.length > 600) p.samples.shift();
      }, 20);
    });
    const page = await context.newPage();
    page.setDefaultTimeout(15000);
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); else if (m.type() === 'warning') report.warnings.push(m.text()); });
    page.on('response', r => { if (r.status() >= 400) report.httpErrors.push({ url: r.url(), status: r.status() }); });
    const read = () => page.evaluate(() => JSON.parse(JSON.stringify(window.__godotState)));
    const action = name => page.evaluate(name => window.__godotAction(name), name);
    const ready = () => page.waitForFunction(() => window.__godotState?.ready && window.__godotState.music, null, { timeout: 90000 });
    const audio = () => page.evaluate(() => ({ contexts: window.__musicProbe.outputs.map(output => output.context.state),
      peakRms: Math.max(0, ...window.__musicProbe.samples.map(sample => sample.rms)), samples: window.__musicProbe.samples.slice(-30),
      musicSourceStarts: window.__musicProbe.sources.filter(source => source.node.buffer?.duration > 5).length,
      musicSources: window.__musicProbe.sources.filter(source => source.node.buffer?.duration > 5).map(source => ({ args: source.args, startedAt: source.startedAt, ended: source.ended })),
      loopingSources: window.__musicProbe.sources.filter(source => !source.ended && source.node.loop).map(source => ({ duration: source.node.buffer?.duration, loop: source.node.loop, loopStart: source.node.loopStart })) }));
    const clearAudio = () => page.evaluate(() => { window.__musicProbe.samples = []; });
    const shot = name => page.screenshot({ path: path.join(out, name + '.png') });

    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/');
    await ready();
    report.samples.beforeGesture = await read();
    check('A fresh page has music enabled but does not autoplay', () => {
      const m = report.samples.beforeGesture.music;
      assert.ok(m.available, 'The real battle_theme.ogg is in this export');
      assert.ok(m.enabled && !m.unlocked && !m.playing && m.starts === 0);
    });
    await shot('music-menu');
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => window.__godotState.started && window.__godotState.music.playing);
    // Godot's sample-position reporter holds its reset for its first second.
    await page.waitForTimeout(2100);
    report.samples.enabled = await read(); report.samples.audible = await audio();
    check('The first normal key unlocks a single looping music player', () => {
      const m = report.samples.enabled.music;
      assert.ok(m.unlocked && m.playing && m.activePlayers === 1 && m.starts === 1 && m.position > 0.65);
      assert.ok(m.length > 5);
    });
    check('Web Audio is running and the music produces nonzero output', () => {
      assert.ok(report.samples.audible.contexts.includes('running'));
      assert.ok(report.samples.audible.peakRms > 0.00001);
      assert.equal(report.samples.audible.musicSourceStarts, 1, 'Web Audio does not restart the song every frame');
    });

    await page.keyboard.press('Escape');
    await page.waitForFunction(() => window.__godotState.paused && window.__godotState.music.paused);
    await page.waitForTimeout(150);
    report.samples.pauseA = await read();
    await page.waitForTimeout(350); report.samples.pauseB = await read();
    await shot('music-pause');
    check('Pause holds both game time and the real playback cursor', () => {
      assert.equal(report.samples.pauseA.time, report.samples.pauseB.time);
      assert.ok(Math.abs(report.samples.pauseA.music.position - report.samples.pauseB.music.position) < 0.03);
      assert.equal(report.samples.pauseB.music.playing, false);
    });
    await page.keyboard.press('m');
    await page.waitForFunction(() => window.__godotState.music.muted);
    check('M works while the pause menu is open', () => assert.equal(report.samples.pauseB.music.starts, 1));
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => !window.__godotState.paused);
    await action('practice');
    await page.waitForFunction(() => window.__godotState.campaign.mode === 'practice');
    if (!(await read()).training) { await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training); }
    await page.waitForTimeout(400); await clearAudio(); await page.waitForTimeout(350);
    report.samples.muted = await read(); report.samples.mutedAudio = await audio();
    check('Music-off is silent without resetting its playback', () => {
      assert.ok(report.samples.muted.music.muted && report.samples.muted.music.volumeDb <= -75);
      assert.equal(report.samples.muted.music.starts, 1);
      assert.ok(report.samples.mutedAudio.peakRms < 0.00001);
    });
    await page.keyboard.down('d');
    try { await page.waitForFunction(() => Math.abs(window.__godotState.enemy.x - window.__godotState.player.x) < 1.15); }
    finally { await page.keyboard.up('d'); }
    await page.waitForFunction(() => window.__godotState.player.state === 'idle');
    await clearAudio(); await page.keyboard.press('j');
    await page.waitForFunction(() => window.__godotState.enemy.hp < 100);
    await page.waitForTimeout(250); report.samples.sfxWhileMuted = await audio();
    check('Muting music leaves normal hit sounds audible', () => assert.ok(report.samples.sfxWhileMuted.peakRms > 0.00001));

    await action('menu');
    await page.reload(); await ready();
    report.samples.reloadedOff = await read();
    check('Music-off persists across a real browser reload', () => assert.equal(report.samples.reloadedOff.music.enabled, false));
    // The menu card is part of Godot's canvas; click its displayed music button.
    const viewport = page.viewportSize();
    const uiScale = Math.min(viewport.width / 1280, viewport.height / 800);
    const uiWidth = viewport.width / uiScale, uiHeight = viewport.height / uiScale;
    await page.mouse.click((Math.max(32, uiWidth * 0.055) + 169) * uiScale,
      (Math.max(110, (uiHeight - 468) * 0.5) + 432) * uiScale);
    await page.waitForFunction(() => window.__godotState.music.enabled && window.__godotState.music.playing);
    await page.waitForTimeout(400); report.samples.menuOn = await read();
    check('The visible menu button reenables music using a real click', () => assert.equal(report.samples.menuOn.music.starts, 1));
    await action('practice');
    await page.waitForFunction(() => window.__godotState.campaign.mode === 'practice');
    if (!(await read()).training) { await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training); }
    await page.keyboard.press('q');
    await page.waitForFunction(() => window.__godotState.ultimate && window.__godotState.ultimateTime > 0.6);
    report.samples.ultimate = await read();
    await page.waitForFunction(() => !window.__godotState.ultimate);
    await page.waitForTimeout(750); report.samples.afterUltimate = await read();
    check('Ultimate ducks then restores music without restarting it', () => {
      assert.ok(report.samples.ultimate.music.ducked);
      assert.ok(report.samples.ultimate.music.targetDb < report.samples.afterUltimate.music.targetDb);
      assert.ok(!report.samples.afterUltimate.music.ducked);
      assert.equal(report.samples.afterUltimate.music.starts, 1);
    });

    const other = await context.newPage();
    await other.goto('about:blank'); await other.bringToFront();
    let lostFocus = true;
    try { await page.waitForFunction(() => !window.__godotState.music.focused, null, { timeout: 2500 }); }
    catch (_) { lostFocus = false; report.warnings.push('This headless browser did not deliver tab-focus loss; native music_suite verifies the focus state contract.'); }
    if (lostFocus) {
      await page.waitForTimeout(160); report.samples.blurA = await read();
      await page.waitForTimeout(250); report.samples.blurB = await read();
      check('Switching away pauses the track cursor', () => assert.ok(Math.abs(report.samples.blurA.music.position - report.samples.blurB.music.position) < 0.03));
    }
    await other.close(); await page.bringToFront();
    if ((await read()).paused) { await page.keyboard.press('Escape'); await page.waitForFunction(() => !window.__godotState.paused); }
    await page.waitForTimeout(250);

    // Let the original full piece reach its first natural loop. No seek/reset.
    console.log('CHECK natural music loop');
    const loopStart = await read();
    const duration = loopStart.music.length;
    const untilBoundary = duration - (loopStart.music.position % duration);
    const loopDeadline = Date.now() + (untilBoundary + 2.5) * 1000;
    let previous = loopStart.music.position, crossed = false;
    report.samples.loop = [];
    while (Date.now() < loopDeadline) {
      await page.waitForTimeout(250);
      const state = await read(), position = state.music.position;
      if (previous > duration * 0.75 && position < previous - 1) crossed = true;
      if (previous < duration && position >= duration) crossed = true;
      if (position > duration - 1 || crossed) report.samples.loop.push({ music: state.music, audio: await audio() });
      previous = position;
      if (crossed && report.samples.loop.length > 4) break;
    }
    check('The complete original piece loops naturally without starting a second player', () => {
      assert.ok(crossed, 'A real loop boundary is observed');
      assert.ok(report.samples.loop.length > 0);
      for (const sample of report.samples.loop) assert.equal(sample.music.starts, 1);
      const last = report.samples.loop.at(-1);
      // Sample playback exposes a looping AudioBufferSource; a Worklet-backed
      // stream exposes the natural Godot cursor wrap plus actual mixed output.
      if (last.audio.loopingSources.length) assert.ok(last.audio.loopingSources.some(source => source.duration > 5 && source.loopStart === 0));
      assert.ok(Math.max(...last.audio.samples.map(sample => sample.rms)) > 0.00001, 'Audio output remains audible after the loop');
    });
    check('No failed assets or engine/browser errors', () => { assert.deepEqual(report.errors, []); assert.deepEqual(report.httpErrors, []); });
    report.passed = report.failures.length === 0;
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, errors: report.errors, warnings: report.warnings }, null, 2));
    assert.ok(report.passed, 'See music-report.json');
  } catch (e) { report.passed = false; report.fatal = e.stack; throw e; }
  finally { save(); await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
