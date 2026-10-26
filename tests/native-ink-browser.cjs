'use strict';

// Run only after the current Godot web build is exported and served on 4187.
// Every gameplay operation is a normal key or the existing UI action bridge.
// The probe reads snapshots; it never changes a fighter, timer, or VFX instance.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const out = path.resolve(__dirname, '../build/screenshots', process.env.GODOT_TEST_OUTPUT || 'native-ink');
const url = process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/';
const caseFilter = process.env.GODOT_TEST_CASES || '';
const report = {
  startedAt: new Date().toISOString(), url, caseFilter,
  viewport: { width: 1440, height: 900 },
  method: 'Normal practice/training inputs; independent restart for every screenshot; read-only telemetry.',
  errors: [], httpErrors: [], warnings: [], cases: [], checks: [], failures: []
};

function fpsSummary(samples) {
  const values = samples.map(s => s.fps).filter(v => Number.isFinite(v) && v > 0).sort((a, b) => a - b);
  if (!values.length) return { count: 0 };
  return {
    count: values.length, min: values[0], max: values[values.length - 1],
    median: values[Math.floor(values.length / 2)],
    p10: values[Math.floor((values.length - 1) * 0.1)]
  };
}

function saveReport() {
  fs.mkdirSync(out, { recursive: true });
  report.updatedAt = new Date().toISOString();
  fs.writeFileSync(path.join(out, 'native-ink-report.json'), JSON.stringify(report, null, 2));
}

function verify(description, assertion) {
  try {
    assertion();
    report.checks.push({ description, passed: true });
  } catch (error) {
    report.checks.push({ description, passed: false, message: error.message });
    report.failures.push({ description, message: error.message });
  }
}

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({
    channel: 'msedge', headless: true,
    args: ['--enable-webgl', '--ignore-gpu-blocklist']
  });
  let page;
  try {
    page = await browser.newPage({ viewport: report.viewport, deviceScaleFactor: 1 });
    page.setDefaultTimeout(12000);
    page.on('pageerror', error => report.errors.push({ type: 'pageerror', message: error.message }));
    page.on('console', message => {
      if (message.type() === 'error') report.errors.push({ type: 'console', message: message.text() });
      else if (message.type() === 'warning') report.warnings.push(message.text());
    });
    page.on('response', response => {
      if (response.status() >= 400) report.httpErrors.push({ status: response.status(), url: response.url() });
    });
    const loadStart = Date.now();
    await page.goto(url);
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    report.loadMs = Date.now() - loadStart;
    report.engine = await page.evaluate(() => window.__godotState.engine);

    // The independent recorder still samples while PNG encoding is in progress.
    // Godot publishes at about 10 Hz, so retain real observed times in the report.
    await page.evaluate(() => {
      window.__nativeInkProbe = { active: false, samples: [], events: [], eventTail: [], signature: '' };
      window.__nativeInkRead = () => {
        const s = window.__godotState;
        if (!s) return null;
        const p = s.player || {}, e = s.enemy || {};
        return {
          wallMs: performance.now(), time: s.time, fps: s.fps,
          started: s.started, paused: s.paused, ended: s.ended, training: s.training,
          ultimate: s.ultimate, ultimateTime: s.ultimateTime,
          distance: Math.abs((e.x || 0) - (p.x || 0)),
          player: { x: p.x, hp: p.hp, energy: p.energy, state: p.state, stateTime: p.stateTime,
            attack: p.attack, skillCooldown: p.skillCooldown },
          enemy: { x: e.x, hp: e.hp, state: e.state },
          vfx: s.vfx ? JSON.parse(JSON.stringify(s.vfx)) : null
        };
      };
      setInterval(() => {
        const probe = window.__nativeInkProbe;
        if (!probe.active) return;
        const sample = window.__nativeInkRead();
        if (!sample) return;
        const signature = JSON.stringify([sample.time, sample.paused, sample.fps, sample.player.state,
          sample.player.stateTime, sample.ultimateTime, sample.vfx]);
        if (signature !== probe.signature) {
          probe.samples.push(sample);
          probe.signature = signature;
        }
        // Events form a rolling 100-item history. Match the overlapping tail;
        // timestamps can repeat after restart, so global content deduplication
        // would incorrectly erase a repeated ultimate's four contacts.
        const currentEvents = (window.__godotState.events || []).map(event => JSON.stringify(event));
        let overlap = Math.min(probe.eventTail.length, currentEvents.length);
        while (overlap > 0 && !probe.eventTail.slice(-overlap).every((key, i) => key === currentEvents[i])) overlap--;
        probe.events.push(...currentEvents.slice(overlap).map(key => JSON.parse(key)));
        probe.eventTail = currentEvents;
      }, 25);
    });

    const read = () => page.evaluate(() => window.__nativeInkRead());
    const act = command => page.evaluate(value => window.__godotAction(value), command);
    const waitAttack = (name, combo = 0, time = 0) => page.waitForFunction(({ name, combo, time }) => {
      const p = window.__godotState?.player;
      return p?.state === 'attack' && p.attack?.name === name &&
        p.attack.comboIndex === combo && p.stateTime >= time;
    }, { name, combo, time });

    await page.locator('canvas').click({ position: { x: 700, y: 400 } });
    await act('practice');
    await page.waitForFunction(() => window.__godotState?.started && window.__godotState.campaign?.mode === 'practice');
    await page.keyboard.press('t');
    await page.waitForFunction(() => window.__godotState.training);

    async function resetAndApproach() {
      await page.evaluate(() => { window.__nativeInkProbe.active = false; });
      await page.keyboard.up('a');
      await page.keyboard.up('d');
      await page.keyboard.up('l');
      await page.keyboard.press('r');
      await page.waitForFunction(() => {
        const s = window.__godotState;
        return s?.started && !s.paused && !s.ultimate && s.time < 0.5 &&
          s.player.state === 'idle' && s.player.hp === 100 && s.enemy.hp === 100 &&
          Math.abs(s.player.x + 1.65) < 0.05 && Math.abs(s.enemy.x - 1.65) < 0.05;
      });
      assert.equal(await page.evaluate(() => window.__godotState.training), true, 'Practice restart preserves training dummy');
      await page.keyboard.down('d');
      try {
        await page.waitForFunction(() => Math.abs(window.__godotState.enemy.x - window.__godotState.player.x) < 1.2);
      } finally {
        await page.keyboard.up('d');
      }
      await page.waitForFunction(() => window.__godotState.player.state === 'idle');
      const initial = await read();
      assert.ok(initial.distance < 1.2, 'Normal movement reaches reliable melee range');
      assert.equal(initial.enemy.hp, 100);
      await page.evaluate(() => {
        const probe = window.__nativeInkProbe;
        probe.samples = [];
        probe.events = [];
        probe.eventTail = (window.__godotState.events || []).map(event => JSON.stringify(event));
        probe.signature = '';
        probe.active = true;
      });
      return initial;
    }

    async function beginAttack(name, combo = 0) {
      const key = { light: 'j', heavy: 'k', ability: 'e' }[name];
      await page.keyboard.press(key);
      for (let i = 0; i < combo; i++) {
        await waitAttack('light', i, 0.10);
        await page.keyboard.press('j');
      }
      await waitAttack(name, combo);
    }

    async function captureCase(spec) {
      console.log('Capture', spec.id);
      const item = { id: spec.id, input: spec.input, targetTime: spec.time, clock: spec.ultimate ? 'ultimateTime' : 'player.stateTime' };
      report.cases.push(item);
      try {
        item.initial = await resetAndApproach();
        if (spec.ultimate) {
          await page.keyboard.press('q');
          await page.waitForFunction(time => window.__godotState.ultimate && window.__godotState.ultimateTime >= time, spec.time);
        } else {
          await beginAttack(spec.name, spec.combo || 0);
          if (spec.name === 'light' && spec.nativeAtCapture) {
            // Normal pause captures the actual contact, rather than a stale
            // pre-combat-retiming timestamp plus two telemetry round trips.
            await page.waitForFunction(({name,combo}) => {
              const s=window.__godotState, p=s.player;
              if (p.state==='attack' && p.attack.name===name && p.attack.comboIndex===combo &&
                  p.stateTime>=p.attack.windup && s.vfx.nativeCount>0) {
                window.__godotAction('pause');
                return true;
              }
              return false;
            }, {name:spec.name,combo:spec.combo||0});
            await page.waitForFunction(() => window.__godotState.paused);
            item.captureTiming='actual contact frozen through ordinary pause input';
          } else await waitAttack(spec.name, spec.combo || 0, spec.time);
        }
        item.before = await read();
        const shotStart = Date.now();
        item.screenshot = spec.id + '.png';
        await page.screenshot({ path: path.join(out, item.screenshot) });
        item.screenshotMs = Date.now() - shotStart;
        item.after = await read();
        item.actualTime = spec.ultimate ? item.before.ultimateTime : item.before.player.stateTime;
        item.sampleLateness = item.actualTime - spec.time;
        if (item.before.paused) await act('pause');
        // Complete each normal action so hit events can also be verified.
        await page.waitForFunction(() => !window.__godotState.ultimate && window.__godotState.player.state === 'idle');
        await page.waitForTimeout(150);
        item.final = await read();
        const probe = await page.evaluate(() => ({ samples: window.__nativeInkProbe.samples, events: window.__nativeInkProbe.events }));
        item.samples = probe.samples;
        item.events = probe.events;
        item.fps = fpsSummary(probe.samples);
        item.textureKeysSeen = [...new Set(probe.samples.flatMap(s => s.vfx?.textureKeys || []))];
        item.peakNativeCount = Math.max(0, ...probe.samples.map(s => s.vfx?.nativeCount || 0));
        verify(spec.id + ': original C5 textures are loaded', () => {
          assert.equal(item.before.vfx?.source, 'hi3-c5-native');
          assert.ok(item.before.vfx.loadedTextures.length > 0);
        });
        verify(spec.id + ': native textured effects were active', () => assert.ok(item.peakNativeCount > 0));
        if (spec.nativeAtCapture) {
          verify(spec.id + ': native ink is active at the requested impact', () => assert.ok(item.before.vfx?.nativeCount > 0));
        }
        verify(spec.id + ': normal input dealt expected damage', () => assert.equal(item.final.enemy.hp, spec.hp));
        verify(spec.id + ': effect counts are internally consistent', () => {
          for (const sample of probe.samples) {
            const vfx = sample.vfx;
            assert.ok(vfx && vfx.nativeCount >= 0 && vfx.proceduralCount >= 0);
            assert.equal(vfx.total, vfx.nativeCount + vfx.proceduralCount);
          }
        });
        if (spec.ultimate) verify(spec.id + ': all four ultimate contacts fire', () => {
          assert.equal(item.events.filter(event => event.type === 'ultHit' && event.side === 'player').length, 4);
        });
      } catch (error) {
        item.error = error.stack || error.message;
        report.failures.push({ description: spec.id, message: error.message });
      }
      saveReport();
    }

    const captures = [
      { id: '01-j-first-025', input: 'J', name: 'light', combo: 0, time: 0.25, hp: 94, nativeAtCapture: true },
      { id: '02-j-second-022', input: 'J, queued J', name: 'light', combo: 1, time: 0.22, hp: 87, nativeAtCapture: true },
      { id: '03-j-third-083', input: 'J, queued J, queued J', name: 'light', combo: 2, time: 0.83, hp: 77, nativeAtCapture: true },
      { id: '04-k-charge-025', input: 'K', name: 'heavy', time: 0.25, hp: 85 },
      { id: '05-k-impact-080', input: 'K', name: 'heavy', time: 0.80, hp: 85, nativeAtCapture: true },
      { id: '06-e-charge-025', input: 'E', name: 'ability', time: 0.25, hp: 82 },
      { id: '07-e-release-065', input: 'E', name: 'ability', time: 0.65, hp: 82 },
      { id: '08-e-impact-078', input: 'E', name: 'ability', time: 0.78, hp: 82, nativeAtCapture: true },
      ...[0.25, 0.65, 1.2, 1.9, 2.65, 3.05].map((time, index) => ({
        id: `${String(9 + index).padStart(2, '0')}-q-${time.toFixed(2).replace('.', '')}`,
        input: 'Q', ultimate: true, time, hp: 64
      }))
    ];
    // Match the descriptive ID without its ordinal, e.g. ^q- selects all Q captures.
    const filter = caseFilter ? new RegExp(caseFilter) : null;
    const selectedCaptures = captures.filter(spec => !filter || filter.test(spec.id.replace(/^\d+-/, '')));
    assert.ok(selectedCaptures.length > 0, 'GODOT_TEST_CASES must select at least one capture');
    for (const spec of selectedCaptures) await captureCase(spec);

    const pause = { id: '15-q-pause-freeze', targetTime: 0.70 };
    report.pause = pause;
    try {
      await resetAndApproach();
      await page.keyboard.press('q');
      await page.waitForFunction(() => window.__godotState.ultimate && window.__godotState.ultimateTime >= 0.70);
      await page.keyboard.press('Escape');
      await page.waitForFunction(() => window.__godotState.paused);
      pause.before = await read();
      await page.waitForTimeout(250);
      pause.after = await read();
      await page.screenshot({ path: path.join(out, '15-q-paused.png') });
      verify('Pause freezes original ink effect ages and active textures', () => {
        assert.ok(pause.before.vfx.nativeCount > 0, 'Pause begins during an active original effect');
        assert.equal(pause.after.time, pause.before.time);
        assert.equal(pause.after.ultimateTime, pause.before.ultimateTime);
        assert.equal(pause.after.vfx.nativeTime, pause.before.vfx.nativeTime);
        assert.equal(pause.after.vfx.nativeCount, pause.before.vfx.nativeCount);
        assert.deepEqual(pause.after.vfx.textureKeys, pause.before.vfx.textureKeys);
      });
      await page.keyboard.press('Escape');
      await page.waitForFunction(time => !window.__godotState.paused && window.__godotState.ultimateTime > time + 0.1, pause.after.ultimateTime);
      pause.resumed = await read();
      await page.waitForFunction(() => !window.__godotState.ultimate);
      pause.final = await read();
      verify('Paused ultimate resumes and completes normally', () => assert.equal(pause.final.enemy.hp, 64));
      // Allow the authored tail effects to finish before checking the arena returns.
      await page.waitForTimeout(650);
      pause.restored = await read();
      await page.screenshot({ path: path.join(out, '16-q-restored-arena.png') });
      verify('Ultimate ends with the arena restored and no cinematic layers left', () => {
        assert.equal(pause.restored.ultimate, false);
        assert.equal(pause.restored.paused, false);
        assert.equal(pause.restored.player.state, 'idle');
        assert.equal(pause.restored.enemy.hp, 64);
        assert.ok(!pause.restored.vfx.textureKeys.some(key => /landscape|mountains|Sphere002/.test(key)));
      });
    } catch (error) {
      pause.error = error.stack || error.message;
      report.failures.push({ description: pause.id, message: error.message });
    }

    report.final = await read();
    report.fps = fpsSummary(report.cases.flatMap(item => item.samples || []));
    report.textureKeysSeen = [...new Set(report.cases.flatMap(item => item.textureKeysSeen || []))];
    verify('No browser or engine errors', () => assert.equal(report.errors.length, 0));
    verify('No failed web asset requests', () => assert.equal(report.httpErrors.length, 0));
    report.passed = report.failures.length === 0;
    report.finishedAt = new Date().toISOString();
    saveReport();
    console.log(JSON.stringify({ passed: report.passed, captures: report.cases.length,
      failures: report.failures, errors: report.errors, fps: report.fps, textureKeys: report.textureKeysSeen }, null, 2));
    assert.ok(report.passed, 'Native ink browser checks failed; see native-ink-report.json');
  } catch (error) {
    report.passed = false;
    report.fatal = error.stack || error.message;
    saveReport();
    throw error;
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
