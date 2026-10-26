'use strict';

// Browser coverage for the authored ultimate camera. Every gameplay operation
// uses normal keys or the existing UI bridge; camera/game telemetry is read-only.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const releaseOnly = process.env.GODOT_CAMERA_RELEASE_ONLY === '1';
const out = path.resolve(__dirname, '../build/screenshots', process.env.GODOT_TEST_OUTPUT || 'ultimate-camera');
const report = { startedAt: new Date().toISOString(), checks: [], failures: [], errors: [], httpErrors: [], cases: [] };
const moments = releaseOnly ? [1.9] : [0.2, 0.55, 1.0, 1.5, 1.9, 2.4, 2.7, 3.15];

function save() {
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'ultimate-camera-report.json'), JSON.stringify(report, null, 2));
}
function check(description, assertion) {
  try { assertion(); report.checks.push({ description, passed: true }); }
  catch (error) { report.checks.push({ description, passed: false }); report.failures.push({ description, message: error.message }); }
}
function xyz(value) {
  return Array.isArray(value) ? value : [value?.x, value?.y, value?.z];
}
function validateCamera(state) {
  const c = state.cinematic;
  assert.ok(c && typeof c.shot === 'string', 'Authored camera shot is exposed');
  assert.ok(Number.isFinite(c.fov) && c.fov > 5 && c.fov < 130, 'FOV is finite and usable');
  assert.ok(Number.isFinite(c.roll));
  for (const value of [...xyz(c.position), ...xyz(c.target)]) assert.ok(Number.isFinite(value));
  const position = xyz(c.position), target = xyz(c.target);
  assert.ok(Math.hypot(...position.map((value, i) => value - target[i])) > 0.3, 'Camera is outside its focus point');
  for (const fighter of [state.player, ...state.enemies]) {
    if (fighter.hp <= 0) continue;
    assert.ok(Math.hypot(position[0] - fighter.x, position[1] - 1.4, position[2]) > 0.75, 'Camera stays outside the fighter torso');
  }
}

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(15000);
    page.on('pageerror', error => report.errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') report.errors.push(message.text()); });
    page.on('response', response => { if (response.status() >= 400) report.httpErrors.push({ status: response.status(), url: response.url() }); });
    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    await page.locator('canvas').click({ position: { x: 700, y: 400 } });
    await page.evaluate(() => {
      window.__cameraProbe = { active: false, samples: [], events: [], tail: [], stamp: '' };
      window.__cameraRead = () => {
        const s = window.__godotState;
        return JSON.parse(JSON.stringify({ wallMs: performance.now(), time: s.time, fps: s.fps,
          player: s.player, enemy: s.enemy, enemies: s.enemies, ultimate: s.ultimate, ultimateTime: s.ultimateTime,
          started: s.started, paused: s.paused, ended: s.ended, training: s.training, stageCountdown: s.stageCountdown,
          campaign: s.campaign, cinematic: s.cinematic, feel: s.feel, vfx: s.vfx }));
      };
      setInterval(() => {
        const p = window.__cameraProbe;
        if (!p.active) return;
        const s = window.__cameraRead();
        const stamp = JSON.stringify([s.time, s.paused, s.ultimateTime, s.cinematic, s.player.state]);
        if (stamp !== p.stamp) { p.samples.push(s); p.stamp = stamp; }
        const events = (window.__godotState.events || []).map(event => JSON.stringify(event));
        let overlap = Math.min(p.tail.length, events.length);
        while (overlap > 0 && !p.tail.slice(-overlap).every((event, i) => event === events[i])) overlap--;
        p.events.push(...events.slice(overlap).map(event => JSON.parse(event)));
        p.tail = events;
      }, 20);
    });
    const read = () => page.evaluate(() => window.__cameraRead());
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    const shot = name => page.screenshot({ path: path.join(out, name + '.png') });
    const waitMoment = time => page.waitForFunction(time => window.__godotState.ultimate && window.__godotState.ultimateTime >= time, time);
    const waitIdle = () => page.waitForFunction(() => window.__godotState.player.state === 'idle' && !window.__godotState.ultimate);
    const record = () => page.evaluate(() => {
      const p = window.__cameraProbe;
      p.samples = []; p.events = []; p.stamp = '';
      p.tail = (window.__godotState.events || []).map(event => JSON.stringify(event)); p.active = true;
    });
    const collect = () => page.evaluate(() => ({ samples: window.__cameraProbe.samples, events: window.__cameraProbe.events }));
    async function release() {
      for (const key of ['a', 'd', 'l']) await page.keyboard.up(key);
      await action('move', 0); await action('guard_held', false);
    }
    async function approach() {
      const s = await read();
      const key = s.enemy.x > s.player.x ? 'd' : 'a';
      await page.keyboard.down(key);
      try { await page.waitForFunction(() => Math.abs(window.__godotState.enemy.x - window.__godotState.player.x) < 1.15); }
      finally { await page.keyboard.up(key); }
      await waitIdle();
    }
    async function practice() {
      await release(); await page.evaluate(() => { window.__cameraProbe.active = false; });
      await action('practice');
      await page.waitForFunction(() => {
        const s = window.__godotState;
        return s.started && s.campaign.mode === 'practice' && !s.paused && !s.ultimate && s.time < 0.5 &&
          s.enemy.hp === 100 && Math.abs(s.player.x + 1.65) < 0.05;
      });
      if (!(await read()).training) { await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training); }
      await approach();
      await page.waitForTimeout(250);
      return read();
    }
    async function capture(item, time, name) {
      await waitMoment(time);
      const before = await read(), began = Date.now();
      await shot(name);
      const after = await read();
      const sample = { name, targetTime: time, actualTime: before.ultimateTime, screenshotMs: Date.now() - began, before, after };
      item.captures.push(sample);
      check(name + ': finite, non-intersecting cinematic camera', () => validateCamera(before));
      check(name + ': camera is active during the full ultimate', () => assert.equal(before.cinematic.active, true));
      return sample;
    }
    async function finish(item, name, baselineFov, expectPracticeSurvival = false) {
      await page.waitForFunction(() => !window.__godotState.ultimate);
      item.end = await read();
      await page.waitForFunction(() => !window.__godotState.cinematic?.active && !window.__godotState.cinematic?.returning);
      await page.waitForTimeout(250);
      item.restored = await read();
      if (name) await shot(name);
      item.observations = await collect();
      check(item.name + ': battle camera and FOV return', () => {
        validateCamera(item.restored);
        assert.equal(item.restored.ultimate, false);
        assert.equal(item.restored.cinematic.active, false);
        assert.equal(item.restored.cinematic.returning, false);
        assert.ok(Math.abs(item.restored.cinematic.fov - baselineFov) < 0.2);
        assert.ok(Math.abs(item.restored.cinematic.roll) < 0.002);
      });
      if (expectPracticeSurvival) check(item.name + ': original four contacts and damage remain unchanged', () => {
        assert.equal(item.restored.enemy.hp, 64);
        assert.equal(item.observations.events.filter(event => event.type === 'ultHit' && event.side === 'player').length, 4);
      });
      const ultEvent = item.observations.events.find(event => event.type === 'ultimate');
      check(item.name + ': authored combat duration remains 3.3 seconds', () => assert.equal(ultEvent?.duration, 3.3));
    }
    async function run(name, body) {
      console.log('CAMERA', name);
      const item = { name, captures: [] }; report.cases.push(item);
      try { await body(item); }
      catch (error) { item.error = error.stack || error.message; report.failures.push({ description: name, message: error.message }); }
      if (!item.observations) item.observations = await collect();
      save(); return item;
    }

    for (const time of moments) {
      const label = 'right-' + time.toFixed(2).replace('.', '');
      await run(label, async item => {
        item.initial = await practice();
        await record(); await page.keyboard.press('q');
        const sample = await capture(item, time, label);
        check(label + ': normal right-facing setup', () => assert.equal(sample.before.player.facing, 1));
        await finish(item, time === moments[moments.length - 1] ? 'right-restored' : '', item.initial.cinematic.fov, true);
      });
    }

    if (!releaseOnly) await run('pause and resume', async item => {
      item.initial = await practice(); await record(); await page.keyboard.press('q'); await waitMoment(1.0);
      await page.keyboard.press('Escape'); await page.waitForFunction(() => window.__godotState.paused);
      item.beforePause = await read(); await page.waitForTimeout(300); item.afterPause = await read(); await shot('pause-frozen');
      check('Pause freezes cinematic transform, target, FOV and roll', () => {
        for (const key of ['position', 'target', 'fov', 'roll', 'shot']) assert.deepEqual(item.afterPause.cinematic[key], item.beforePause.cinematic[key]);
        assert.equal(item.afterPause.ultimateTime, item.beforePause.ultimateTime);
        assert.equal(item.afterPause.vfx.nativeTime, item.beforePause.vfx.nativeTime);
        assert.deepEqual(item.afterPause.feel.player, item.beforePause.feel.player);
      });
      await page.keyboard.press('Escape'); await page.waitForFunction(() => !window.__godotState.paused);
      await finish(item, 'pause-resumed-arena', item.initial.cinematic.fov, true);
      const startX = item.restored.player.x;
      await page.keyboard.down('d'); await page.waitForTimeout(160); await page.keyboard.up('d');
      await waitIdle(); item.afterMovement = await read();
      check('Normal movement works after camera restoration', () => assert.ok(item.afterMovement.player.x > startX + 0.1));
    });

    await run('left-facing second encounter', async item => {
      await release(); await action('menu'); await page.waitForFunction(() => window.__godotState.campaign.phase === 'menu');
      await page.keyboard.press('Enter');
      await page.waitForFunction(() => window.__godotState.campaign.mode === 'trial' && window.__godotState.stageCountdown <= 0);
      const deadline = Date.now() + 60000;
      while (Date.now() < deadline) {
        const s = await read();
        if (s.campaign.phase !== 'fight') break;
        const p = s.player, e = s.enemy, distance = Math.abs(e.x - p.x);
        await action('move', distance > 1.1 ? Math.sign(e.x - p.x) : 0);
        let command = null;
        if (['idle', 'move', 'guard'].includes(p.state)) {
          if (p.skillCooldown <= 0 && distance < 2.0) command = 'ability';
          else if (distance < 1.7) command = e.state === 'guard' ? 'heavy' : 'light';
        } else if (p.state === 'attack' && p.attack.name === 'light' && p.stateTime > 0.09) command = 'light';
        if (command) await action(command);
        await page.waitForTimeout(60);
      }
      await release(); item.firstReward = await read();
      assert.equal(item.firstReward.campaign.phase, 'reward', 'First encounter clears without spending ultimate SP');
      assert.equal(item.firstReward.player.energy, 100);
      // The second encounter naturally starts with the nearest opponent on the left.
      await page.keyboard.press('2');
      await page.waitForFunction(() => {
        const s = window.__godotState;
        return s.campaign.stageIndex === 1 && s.stageCountdown <= 0 && s.enemy.x < s.player.x;
      });
      item.initial = await read();
      await record(); await page.keyboard.press('q');
      for (const time of (releaseOnly ? [1.9] : [0.55, 1.5, 2.4, 3.15])) {
        const sample = await capture(item, time, 'left-' + time.toFixed(2).replace('.', ''));
        check('Left-facing phase ' + time + ' uses the actual left target', () => assert.equal(sample.before.player.facing, -1));
      }
      await finish(item, 'left-restored', item.initial.cinematic.fov);
      check('Left-facing ultimate leaves a live multi-enemy fight', () => {
        assert.equal(item.restored.training, false);
        assert.equal(item.restored.campaign.phase, 'fight');
        assert.ok(item.restored.enemies.filter(enemy => enemy.hp > 0).length >= 1);
      });
    });

    if (!releaseOnly) await run('right boundary and lethal ultimate', async item => {
      item.initial = await practice(); item.pushes = [];
      // Six ordinary heavy strikes push the 100-HP dummy toward the boundary,
      // leaving enough HP to trigger a genuine lethal cinematic without edits.
      for (let strike = 0; strike < 6; strike++) {
        await approach(); await page.keyboard.press('k');
        await page.waitForFunction(() => window.__godotState.player.state === 'attack');
        await waitIdle(); await page.waitForTimeout(150);
        item.pushes.push(await read());
      }
      const edge = await read();
      assert.ok(edge.enemy.hp > 0 && edge.enemy.x > 4.7, 'Normal heavy attacks create an actual edge encounter');
      await approach(); item.atEdge = await read(); await shot('edge-before');
      await record(); await page.keyboard.press('q');
      for (const time of [0.2, 1.0, 1.9, 2.7, 3.15]) await capture(item, time, 'edge-' + time.toFixed(2).replace('.', ''));
      await finish(item, 'edge-restored', item.initial.cinematic.fov);
      check('A lethal edge ultimate completes before victory handling', () => {
        assert.equal(item.restored.enemy.hp, 0);
        assert.equal(item.restored.ended, true);
        assert.ok(item.observations.samples.some(sample => sample.ultimate && sample.ultimateTime >= 3.15));
      });
    });

    check('No browser / engine errors or failed web assets', () => { assert.equal(report.errors.length, 0); assert.equal(report.httpErrors.length, 0); });
    report.passed = report.failures.length === 0; report.finishedAt = new Date().toISOString(); save();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, errors: report.errors, failures: report.failures }, null, 2));
    assert.ok(report.passed, 'See ultimate-camera-report.json for details');
  } catch (error) { report.fatal = error.stack || error.message; report.passed = false; save(); throw error; }
  finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
