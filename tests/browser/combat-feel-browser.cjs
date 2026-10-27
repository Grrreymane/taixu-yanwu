'use strict';

// Normal keyboard / UI-bridge inputs only. Game state and per-frame telemetry
// are observed, never rewritten. Run after the matching web export is ready.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const out = path.resolve(__dirname, '../../build/screenshots/combat-feel');
const report = { startedAt: new Date().toISOString(), checks: [], failures: [], errors: [], httpErrors: [], cases: [] };

function save() {
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'combat-feel-report.json'), JSON.stringify(report, null, 2));
}
function check(description, assertion) {
  try { assertion(); report.checks.push({ description, passed: true }); }
  catch (error) { report.failures.push({ description, message: error.message }); report.checks.push({ description, passed: false }); }
}
function peak(frames, field) { return Math.max(0, ...frames.map(frame => Number(frame[field]) || 0)); }
function motion(presentation) { return presentation?.motion || presentation?.currentMotion || ''; }

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(12000);
    page.on('pageerror', error => report.errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') report.errors.push(message.text()); });
    page.on('response', response => { if (response.status() >= 400) report.httpErrors.push({ url: response.url(), status: response.status() }); });
    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    await page.locator('canvas').click({ position: { x: 700, y: 400 } });
    await page.evaluate(() => {
      window.__feelProbe = { active: false, frames: new Map(), events: [], tail: [], snapshots: [], stamp: '' };
      setInterval(() => {
        const p = window.__feelProbe, s = window.__godotState;
        if (!p.active || !s) return;
        for (const frame of s.feelFrames || []) {
          if (frame.frame > p.startFrame) p.frames.set(frame.frame, JSON.parse(JSON.stringify(frame)));
        }
        const list = (s.events || []).map(event => JSON.stringify(event));
        let overlap = Math.min(p.tail.length, list.length);
        while (overlap > 0 && !p.tail.slice(-overlap).every((event, i) => event === list[i])) overlap--;
        p.events.push(...list.slice(overlap).map(event => JSON.parse(event)));
        p.tail = list;
        const stamp = JSON.stringify([s.time, s.paused, s.player.state, s.player.stateTime, s.feel]);
        if (stamp !== p.stamp) {
          p.snapshots.push(JSON.parse(JSON.stringify({ wallMs: performance.now(), time: s.time, fps: s.fps,
            player: s.player, enemy: s.enemy, feel: s.feel, vfx: s.vfx, paused: s.paused, hitStop: s.hitStop })));
          p.stamp = stamp;
        }
      }, 20);
    });
    const read = () => page.evaluate(() => JSON.parse(JSON.stringify(window.__godotState)));
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    const shot = name => page.screenshot({ path: path.join(out, name + '.png') });
    const record = () => page.evaluate(() => {
      const p = window.__feelProbe;
      p.frames.clear(); p.events = []; p.snapshots = []; p.stamp = '';
      p.tail = (window.__godotState.events || []).map(event => JSON.stringify(event));
      p.startFrame = Math.max(-1, ...(window.__godotState.feelFrames || []).map(frame => frame.frame));
      p.active = true;
    });
    const collect = () => page.evaluate(() => ({
      frames: [...window.__feelProbe.frames.values()].sort((a, b) => a.frame - b.frame),
      events: window.__feelProbe.events, snapshots: window.__feelProbe.snapshots
    }));
    const waitEvent = (type, side = 'player', timeout = 12000) => page.waitForFunction(({ type, side }) =>
      window.__feelProbe.events.some(event => event.type === type && event.side === side), { type, side }, { timeout });
    const waitIdle = () => page.waitForFunction(() => window.__godotState.player.state === 'idle' && !window.__godotState.ultimate);
    async function release() {
      for (const key of ['a', 'd', 'l']) await page.keyboard.up(key);
      await action('move', 0); await action('guard_held', false);
    }
    async function resetPractice(near = true) {
      await release();
      await page.evaluate(() => { window.__feelProbe.active = false; });
      await action('practice');
      await page.waitForFunction(() => {
        const s = window.__godotState;
        return s.started && !s.paused && s.campaign.mode === 'practice' && s.time < 0.5 && s.enemy.hp === s.enemy.maxHp &&
          s.player.state === 'idle' && Math.abs(s.player.x + 1.65) < 0.05;
      });
      if (!(await read()).training) { await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training); }
      if (near) {
        await page.keyboard.down('d');
        try { await page.waitForFunction(() => Math.abs(window.__godotState.enemy.x - window.__godotState.player.x) < 1.15); }
        finally { await page.keyboard.up('d'); }
      }
      await waitIdle();
      await page.waitForTimeout(250);
      await record();
      return read();
    }
    async function run(name, body) {
      console.log('CHECK', name);
      const item = { name }; report.cases.push(item);
      try { await body(item); }
      catch (error) { item.error = error.stack || error.message; report.failures.push({ description: name, message: error.message }); }
      item.observations = await collect();
      save();
      return item;
    }
    function verifyContactFreeze(item) {
      const frames = item.observations.frames;
      const frozenPairs = frames.slice(1).map((frame, i) => [frames[i], frame]).filter(([a, b]) =>
        b.frame === a.frame + 1 && a.hitStop > 0 && b.hitStop > 0 && Math.abs(a.simDelta) < 0.000001 && Math.abs(b.simDelta) < 0.000001 &&
        a.playerMotion === b.playerMotion && a.enemyMotion === b.enemyMotion);
      check(item.name + ': contact stop is observable at frame resolution', () => assert.ok(frozenPairs.length > 0));
      check(item.name + ': model poses and effects stay frozen during contact stop', () => {
        assert.ok(frozenPairs.length > 0);
        for (const [a, b] of frozenPairs) {
          assert.ok(Math.abs(b.fxDelta) < 0.000001);
          assert.ok(Math.abs(b.playerSourceTime - a.playerSourceTime) < 0.000001);
          assert.ok(Math.abs(b.enemySourceTime - a.enemySourceTime) < 0.000001);
        }
      });
    }

    await run('held guard and release', async item => {
      // Inspect the actual close-combat spacing, including both fighters.
      item.idle = await resetPractice(); await shot('01-idle');
      await page.keyboard.down('l');
      await page.waitForFunction(() => window.__godotState.player.state === 'guard');
      await page.waitForTimeout(400); item.held = await read(); await shot('02-held-guard');
      await page.waitForTimeout(400); item.stillHeld = await read();
      await page.keyboard.up('l'); await waitIdle(); await page.waitForTimeout(150);
      item.released = await read(); await shot('03-guard-released');
      check('Holding L sustains defense without losing health', () => {
        assert.equal(item.held.player.state, 'guard'); assert.equal(item.stillHeld.player.state, 'guard');
        assert.equal(item.held.player.hp, item.idle.player.hp);
      });
      check('Guard is an explicit rendered motion and releasing L returns to idle', () => {
        assert.equal(motion(item.held.feel?.player), 'guard');
        assert.ok(item.held.feel.player.guardWeight > 0.8, 'Guard pose is actually blended onto the skeleton');
        assert.equal(item.released.player.state, 'idle');
        assert.equal(motion(item.released.feel?.player), 'idle');
      });
    });

    await run('normal block recoil', async item => {
      item.initial = await resetPractice();
      await page.keyboard.down('l'); await page.waitForTimeout(400);
      await page.keyboard.press('t'); await page.waitForFunction(() => !window.__godotState.training);
      await waitEvent('block'); item.contact = await read(); await shot('04-block-contact');
      await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training);
      await page.waitForTimeout(220); item.recovery = await read();
      await page.keyboard.up('l'); await waitIdle();
      check('A normal block prevents health damage and adds posture pressure', () => {
        assert.equal(item.contact.player.hp, item.initial.player.hp);
        assert.ok(item.contact.player.posture > item.initial.player.posture);
      });
      // Impact freezes the contact frame; recoil displacement follows the stop.
      check('A normal block has physical backward displacement after contact stop', () => assert.ok(item.recovery.player.x < item.initial.player.x - 0.005));
    });

    await run('timed parry', async item => {
      item.attempts = [];
      for (let attempt = 0; attempt < 4; attempt++) {
        const initial = await resetPractice();
        await page.keyboard.press('t'); await page.waitForFunction(() => !window.__godotState.training);
        await page.waitForFunction(() => {
          const e = window.__godotState.enemy;
          return e.state === 'attack' && !e.attack.hasHit && e.attack.windup - e.stateTime > 0.12;
        });
        const windup = await read();
        const remaining = windup.enemy.attack.windup - windup.enemy.stateTime;
        // Only schedule the ordinary L key against an observed enemy tell.
        const lead = [0.10, 0.08, 0.12, 0.06][attempt];
        await page.waitForTimeout(Math.max(0, (remaining - lead) * 1000));
        await page.keyboard.down('l');
        try { await waitEvent('parry', 'player', 1800); }
        catch (_) { /* Retry from a normal restart if browser scheduling missed the window. */ }
        const result = await read(), observed = await collect();
        item.attempts.push({ remaining, lead, initialHp: initial.player.hp, resultHp: result.player.hp,
          events: observed.events, feel: result.feel });
        if (observed.events.some(event => event.type === 'parry' && event.side === 'player')) {
          item.contact = result; await shot('05-perfect-parry');
          await page.keyboard.press('t'); await page.waitForFunction(() => window.__godotState.training);
          await page.keyboard.up('l');
          break;
        }
      }
      check('A normally timed L input produces a perfect parry', () => assert.ok(item.contact));
      if (item.contact) check('Parry protects health and puts the attacker in recoil', () => {
        assert.equal(item.contact.player.hp, 100);
        assert.equal(item.contact.enemy.state, 'stagger');
      });
    });

    const combo = await run('J three-hit contact rhythm', async item => {
      item.initial = await resetPractice();
      await page.keyboard.press('j');
      for (let index = 0; index < 2; index++) {
        await page.waitForFunction(index => {
          const p = window.__godotState.player;
          return p.state === 'attack' && p.attack.comboIndex === index && p.stateTime > 0.08;
        }, index);
        await page.keyboard.press('j');
      }
      await waitEvent('hit');
      await page.waitForFunction(() => window.__feelProbe.events.filter(event => event.type === 'hit' && event.side === 'player').length >= 3);
      item.contact = await read(); await shot('06-combo-finisher');
      await waitIdle(); await page.waitForTimeout(120); item.final = await read();
    });
    check('J connects three distinct combo stages through normal buffered inputs', () => {
      const hits = combo.observations.events.filter(event => event.type === 'hit' && event.side === 'player');
      assert.deepEqual(hits.map(event => event.combo), [0, 1, 2]);
      assert.equal(combo.initial.enemy.hp - combo.final.enemy.hp, hits.reduce((sum, event) => sum + event.damage, 0));
    });
    verifyContactFreeze(combo);

    const heavy = await run('K heavy contact', async item => {
      item.initial = await resetPractice();
      await page.keyboard.press('k'); await waitEvent('hit');
      item.contact = await read(); await shot('07-heavy-contact');
      await waitIdle(); await page.waitForTimeout(120); item.final = await read();
    });
    verifyContactFreeze(heavy);
    check('Heavy contact has stronger camera feedback and stop than the first light hit', () => {
      const hits = combo.observations.events.filter(event => event.type === 'hit' && event.side === 'player');
      assert.ok(hits.length >= 2);
      const firstFrames = combo.observations.frames.filter(frame => frame.simTime >= hits[0].time - 0.02 && frame.simTime < hits[1].time - 0.04);
      assert.ok(peak(heavy.observations.frames, 'hitStop') > peak(firstFrames, 'hitStop'));
      assert.ok(peak(heavy.observations.frames, 'cameraKick') > peak(firstFrames, 'cameraKick'));
    });

    for (const key of ['j', 'k']) {
      const miss = await run(key.toUpperCase() + ' empty swing', async item => {
        item.initial = await resetPractice(false);
        await page.keyboard.press(key);
        await page.waitForFunction(() => window.__godotState.player.state === 'attack');
        await waitIdle(); await page.waitForTimeout(120); item.final = await read();
      });
      check(key.toUpperCase() + ' empty swing causes no contact, health loss or camera kick', () => {
        assert.equal(miss.final.enemy.hp, miss.initial.enemy.hp);
        assert.equal(miss.observations.events.filter(event => ['hit', 'block', 'parry'].includes(event.type)).length, 0);
        assert.ok(peak(miss.observations.frames, 'cameraKick') < 0.000001);
        assert.ok(peak(miss.observations.frames, 'hitStop') < 0.000001);
      });
    }

    await run('pause during an attack', async item => {
      await resetPractice(); await page.keyboard.press('k');
      await page.waitForFunction(() => window.__godotState.player.state === 'attack' && window.__godotState.player.stateTime > 0.12);
      await page.keyboard.press('Escape'); await page.waitForFunction(() => window.__godotState.paused);
      item.before = await read(); await page.waitForTimeout(300); item.after = await read(); await shot('08-paused');
      check('Pause freezes combat, actor pose, VFX age and camera impulse', () => {
        assert.equal(item.after.time, item.before.time);
        assert.equal(item.after.player.stateTime, item.before.player.stateTime);
        assert.equal(item.after.vfx.nativeTime, item.before.vfx.nativeTime);
        assert.deepEqual(item.after.feel.player, item.before.feel.player);
        assert.equal(item.after.feel.cameraKick, item.before.feel.cameraKick);
        assert.deepEqual(item.after.feel.cameraPosition, item.before.feel.cameraPosition);
      });
      await page.keyboard.press('Escape'); await page.waitForFunction(() => !window.__godotState.paused);
      await waitIdle(); item.resumed = await read();
      check('An attack interrupted by pause resumes and connects', () => assert.ok(item.resumed.enemy.hp < 100));
    });

    await run('first trial encounter', async item => {
      await release(); await action('menu');
      await page.waitForFunction(() => window.__godotState.campaign.phase === 'menu');
      await page.keyboard.press('Enter');
      await page.waitForFunction(() => window.__godotState.campaign.mode === 'trial' && window.__godotState.stageCountdown <= 0);
      await record();
      const deadline = Date.now() + 60000;
      while (Date.now() < deadline) {
        const s = await read();
        if (s.campaign.phase !== 'fight') break;
        if (s.ultimate) { await page.waitForTimeout(60); continue; }
        const p = s.player, e = s.enemies.filter(foe => foe.hp > 0).sort((a, b) => Math.abs(a.x - p.x) - Math.abs(b.x - p.x))[0];
        if (!e) { await page.waitForTimeout(70); continue; }
        const distance = Math.abs(e.x - p.x), moving = distance > 1.2 ? Math.sign(e.x - p.x) : 0;
        let command = null;
        if (['idle', 'move', 'guard'].includes(p.state)) {
          if (p.energy >= 100 && distance < 1.8) command = 'ultimate';
          else if (p.skillCooldown <= 0 && distance < 2.2) command = 'ability';
          else if (distance < 1.7) command = e.state === 'guard' ? 'heavy' : 'light';
        } else if (p.state === 'attack' && p.attack.name === 'light' && p.stateTime > 0.10) command = 'light';
        await action('move', moving);
        if (command) await action(command);
        await page.waitForTimeout(60);
      }
      await release(); item.final = await read(); await shot('09-first-trial-reward');
      check('A live first encounter completes normally and opens real rewards', () => {
        assert.equal(item.final.training, false);
        assert.equal(item.final.campaign.phase, 'reward');
        assert.equal(item.final.campaign.stageIndex, 0);
        assert.equal(item.final.campaign.rewards.length, 3);
        assert.ok(item.final.player.hp > 0);
      });
    });

    check('No browser / engine errors or failed assets', () => { assert.equal(report.errors.length, 0); assert.equal(report.httpErrors.length, 0); });
    report.passed = report.failures.length === 0; report.finishedAt = new Date().toISOString(); save();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, errors: report.errors, failures: report.failures }, null, 2));
    assert.ok(report.passed, 'See combat-feel-report.json for failures');
  } catch (error) { report.fatal = error.stack || error.message; report.passed = false; save(); throw error; }
  finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
