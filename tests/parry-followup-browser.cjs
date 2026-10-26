'use strict';

// Real enemy attacks, keyboard L and the same action bridge used by the UI.
// __godotState is read-only. Only this test's observer state is written.
// Run after exporting the matching parryFollowup/riposteReadyAt implementation.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const out = path.resolve(__dirname, '../build/screenshots/parry-followup');
const report = {
  startedAt: new Date().toISOString(),
  method: 'Normal menu/practice/training/movement inputs; enemy AI creates the attack. Keyboard L catches it. An in-page observer dispatches normal follow-up actions without changing game state.',
  contract: {
    handoffSimSeconds: 0.075,
    followupWindowSimSeconds: 1.0,
    buffer: 'One slot, last valid input wins; no pose transition during hitstop.',
    delayedCommands: { heavy: 0.12, ability: 0.18 },
    telemetryNote: 'State publishes about every 100ms. Immediate-J cases retry only if the first observed parry has already left hitstop; this timing miss is recorded.',
    screenshotNote: 'Screenshots are asynchronous visual references and may land after the named event. Handoff, contact and frozen-pose assertions use recorded events/feelFrames, never screenshot capture timing.',
  },
  checks: [], failures: [], errors: [], httpErrors: [], cases: [],
};

function save() {
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
}
function check(label, fn) {
  try { fn(); report.checks.push({ label, passed: true }); }
  catch (error) {
    report.checks.push({ label, passed: false });
    report.failures.push({ label, message: error.message });
  }
}
const modes = [
  { id: 'azure', style: 'azure_empyrea', stance: 'punch' },
  { id: 'phoenix-punch', style: 'fenghuang', stance: 'punch' },
  { id: 'phoenix-kick', style: 'fenghuang', stance: 'kick' },
];

(async () => {
  save();
  const browser = await chromium.launch({
    channel: 'msedge', headless: true,
    args: ['--enable-webgl', '--ignore-gpu-blocklist'],
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(12000);
    page.on('pageerror', error => report.errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') report.errors.push(message.text()); });
    page.on('response', response => {
      if (response.status() >= 400) report.httpErrors.push({ url: response.url(), status: response.status() });
    });
    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    await page.locator('canvas').click({ position: { x: 720, y: 400 } });
    const read = () => page.evaluate(() => structuredClone(window.__godotState));
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    const wait = (predicate, arg, timeout = 12000) => page.waitForFunction(predicate, arg, { timeout });
    const shot = async (item, suffix) => {
      const filename = `${item.id}-${suffix}.png`;
      await page.screenshot({ path: path.join(out, filename) });
      item.screenshots.push(filename);
    };
    const release = async () => {
      for (const key of ['a', 'd', 'l', 'j', 'k', 'e']) await page.keyboard.up(key);
      await action('move', 0);
      await action('guard_held', false);
    };

    await page.evaluate(() => {
      const probe = window.__parryFollowupProbe = {
        active: false, plan: null, events: [], tail: [], frames: new Map(),
        snapshots: [], startFrame: -1, lastFrame: -1, inputs: [],
      };
      const copy = value => structuredClone(value);
      const sample = s => ({
        wallMs: performance.now(), time: s.time, hitStop: s.hitStop, paused: s.paused,
        player: copy(s.player), enemy: copy(s.enemy), feel: copy(s.feel),
        training: s.training, vfx: copy(s.vfx),
      });
      const send = (command, reason, s) => {
        probe.inputs.push({ command, reason, wallMs: performance.now(), simTime: s.time,
          hitStop: s.hitStop, state: s.player.state, stateTime: s.player.stateTime,
          attack: copy(s.player.attack), riposteReadyAt: s.player.riposteReadyAt });
        window.__godotAction(command);
      };
      probe.timer = setInterval(() => {
        const s = window.__godotState, p = probe.plan;
        if (!probe.active || !s || !p) return;
        for (const frame of s.feelFrames || []) {
          if (frame.frame > probe.startFrame) probe.frames.set(frame.frame, copy(frame));
        }
        const latestFrame = s.feelFrames?.at(-1)?.frame ?? -1;
        if (latestFrame !== probe.lastFrame) {
          probe.snapshots.push(sample(s));
          probe.lastFrame = latestFrame;
        }
        const serialized = (s.events || []).map(event => JSON.stringify(event));
        let overlap = Math.min(probe.tail.length, serialized.length);
        while (overlap > 0 && !probe.tail.slice(-overlap).every((event, i) => event === serialized[i])) overlap--;
        const fresh = serialized.slice(overlap).map(event => JSON.parse(event));
        probe.tail = serialized;
        for (const event of fresh) {
          probe.events.push(event);
          if (!p.parry && event.type === 'parry' && event.side === 'player') {
            p.parry = copy(event);
            p.parryObserved = sample(s);
            if (p.immediate) {
              if (!(s.hitStop > 0)) p.missedStop = true;
              else {
                // Consecutive actions are ordinary UI actions. The optional
                // J->K case checks last-intent replacement, not queue stacking.
                for (const command of p.commands) send(command, 'observed-parry-hitstop', s);
                p.dispatched = true;
              }
            }
          }
          if (!p.parry) continue;
          if (event.type === 'attack' && event.side === 'player' && event.time >= p.parry.time) {
            p.attacks.push(copy(event));
            if (!p.firstAttack) {
              p.firstAttack = copy(event);
              p.firstAttackObserved = sample(s);
            }
          }
          if (event.type === 'hit' && event.side === 'player' && p.firstAttack && event.time >= p.firstAttack.time) {
            p.hits.push(copy(event));
            if (p.chain && p.hits.length < 3) {
              send('light', `confirmed-contact-${p.hits.length}`, s);
            } else {
              p.contactsComplete = true;
              p.completedObserved = sample(s);
            }
          }
        }
        if (p.parry && !p.immediate && !p.dispatched && s.time >= p.parry.time + p.delay) {
          send(p.commands[0], 'delayed-after-parry', s);
          p.dispatched = true;
        }
      }, 4);
    });
    const stop = () => page.evaluate(() => { window.__parryFollowupProbe.active = false; });
    const collect = () => page.evaluate(() => {
      const p = window.__parryFollowupProbe;
      return structuredClone({ plan: p.plan, inputs: p.inputs, events: p.events,
        frames: [...p.frames.values()].sort((a, b) => a.frame - b.frame), snapshots: p.snapshots });
    });
    async function prepare(mode) {
      await stop();
      await release();
      await action('menu');
      await wait(() => window.__godotState.campaign.phase === 'menu');
      await action('select_style:' + mode.style);
      await wait(style => window.__godotState.fighter.styleId === style, mode.style);
      await action('practice');
      await wait(() => {
        const s = window.__godotState;
        return s.started && !s.paused && s.campaign.mode === 'practice' &&
          s.campaign.phase === 'fight' && s.time < 0.7 && s.enemy.hp === s.enemy.maxHp;
      });
      if (!(await read()).training) await action('training');
      await wait(() => window.__godotState.training);
      if ((await read()).player.stance !== mode.stance && mode.style === 'fenghuang') {
        // Change stance safely at initial long range; wait out its real cooldown.
        await page.keyboard.press('e');
        await wait(stance => {
          const p = window.__godotState.player;
          return p.stance === stance && p.state === 'idle' && p.skillCooldown <= 0;
        }, mode.stance);
      }
      await action('move', 1);
      try { await wait(() => Math.abs(window.__godotState.enemy.x - window.__godotState.player.x) < 1.20); }
      finally { await action('move', 0); }
      await wait(() => window.__godotState.player.state === 'idle');
      await page.waitForTimeout(160);
      return read();
    }
    async function arm(config) {
      await page.evaluate(config => {
        const p = window.__parryFollowupProbe, s = window.__godotState;
        p.plan = { ...config, parry: null, firstAttack: null, attacks: [], hits: [],
          dispatched: false, missedStop: false, contactsComplete: false };
        p.events = []; p.inputs = []; p.snapshots = []; p.frames.clear();
        p.tail = (s.events || []).map(event => JSON.stringify(event));
        p.startFrame = Math.max(-1, ...(s.feelFrames || []).map(frame => frame.frame));
        p.lastFrame = -1;
        p.active = true;
      }, config);
    }
    async function catchParry(item, mode, config) {
      item.attempts = [];
      const leads = [0.09, 0.075, 0.11, 0.055];
      for (let attempt = 0; attempt < leads.length; attempt++) {
        const initial = await prepare(mode);
        await arm(config);
        await page.keyboard.press('t'); // Real AI starts; no forced enemy state.
        await wait(() => !window.__godotState.training);
        await wait(() => {
          const s = window.__godotState, e = s.enemy;
          return e.state === 'attack' && !e.attack.hasHit && !e.attack.unblockable &&
            e.attack.windup - e.stateTime > 0.14 &&
            Math.abs(e.x - s.player.x) < e.attack.range;
        });
        const tell = await read();
        const remaining = tell.enemy.attack.windup - tell.enemy.stateTime;
        await page.waitForTimeout(Math.max(0, (remaining - leads[attempt]) * 1000));
        await page.keyboard.down('l');
        try {
          await wait(() => window.__parryFollowupProbe.plan?.parry, null, 1800);
        } catch (_) { /* A missed ordinary L timing may retry, never fake parry. */ }
        const observation = await collect();
        item.attempts.push({ attempt: attempt + 1, lead: leads[attempt], remaining,
          initialHp: initial.player.hp, tell: tell.enemy, observation });
        if (observation.plan.parry && !observation.plan.missedStop) {
          item.initial = initial;
          return true;
        }
        await page.keyboard.up('l');
      }
      return false;
    }

    function verify(item, mode, config) {
      const { plan, inputs, frames, snapshots, events } = item.observations;
      const prefix = item.id + ': ';
      check(prefix + 'real AI attack is caught by L without losing HP', () => {
        assert.ok(events.some(event => event.type === 'attack' && event.side === 'enemy' && event.time <= plan.parry.time));
        assert.equal(plan.parryObserved.training, false);
        assert.equal(plan.parryObserved.player.hp, item.initial.player.hp);
        assert.equal(plan.parryObserved.enemy.state, 'stagger');
      });
      check(prefix + 'follow-up state is exported with the 75ms simulated handoff', () => {
        const ready = plan.parryObserved.player.riposteReadyAt;
        assert.equal(typeof ready, 'number', 'Matching export must expose riposteReadyAt');
        assert.ok(Math.abs(ready - plan.parry.time - 0.075) < 0.002);
        assert.ok(plan.firstAttack.parryFollowup === true, 'Attack event must identify an actual parry follow-up');
        assert.ok(plan.firstAttack.time >= ready - 0.002, 'No attack starts before the handoff');
        assert.ok(plan.firstAttack.time < plan.parry.time + 0.60, 'No long dead period after a valid input');
      });
      check(prefix + 'the buffered or delayed command starts the intended native action', () => {
        const first = plan.firstAttack;
        if (config.chain) {
          assert.equal(first.name, mode.style === 'fenghuang' ? 'heavy' : 'light');
          if (mode.style === 'fenghuang') assert.equal(first.motion, 'counter_' + mode.stance);
          assert.ok(first.windup <= (mode.style === 'fenghuang' ? 0.19 : 0.16) + 0.001);
        } else {
          assert.equal(first.name, config.commands.at(-1));
          assert.ok(first.windup <= (first.name === 'heavy' ? 0.28 : 0.30) + 0.001);
        }
        assert.equal(first.combo, 0);
      });
      if (config.immediate) {
        check(prefix + 'input really occurs inside the observed successful hitstop', () => {
          const queued = inputs.filter(input => input.reason === 'observed-parry-hitstop');
          assert.deepEqual(queued.map(input => input.command), config.commands);
          for (const input of queued) assert.ok(input.hitStop > 0 && input.state === 'guard');
          assert.equal(plan.parryObserved.player.state, 'guard');
        });
        check(prefix + 'parry pose stays frozen before follow-up attack handoff', () => {
          const frozen = frames.filter(frame => frame.simTime >= plan.parry.time - 0.002 &&
            frame.simTime < plan.firstAttack.time && frame.hitStop > 0 && Math.abs(frame.simDelta) < 1e-7);
          const pairs = frozen.slice(1).map((b, i) => [frozen[i], b]).filter(([a, b]) => b.frame === a.frame + 1);
          assert.ok(pairs.length > 0, 'Need consecutive actual frozen frames');
          for (const [a, b] of pairs) {
            assert.equal(a.playerMotion, b.playerMotion);
            assert.ok(Math.abs(a.playerSourceTime - b.playerSourceTime) < 1e-6);
            assert.ok(Math.abs(a.playerDefenseTime - b.playerDefenseTime) < 1e-6);
            assert.ok(Math.abs(b.fxDelta) < 1e-7);
          }
        });
      } else {
        check(prefix + 'late K/E still uses the reserved parry follow-up window', () => {
          assert.equal(inputs[0].reason, 'delayed-after-parry');
          assert.ok(inputs[0].simTime - plan.parry.time >= config.delay - 0.002);
          assert.ok(inputs[0].simTime - plan.parry.time < 0.65);
          assert.equal(plan.hits[0].targetId, plan.parry.targetId);
        });
      }
      check(prefix + 'only actual attack contact deals damage', () => {
        for (let index = 0; index < plan.hits.length; index++) {
          const attack = plan.attacks[index], hit = plan.hits[index];
          assert.ok(attack, 'Each hit must have its own attack');
          assert.ok(hit.time >= attack.time + attack.windup - 0.025, 'Hit must not precede its windup');
          assert.ok(hit.damage > 0);
        }
        assert.equal(item.initial.enemy.hp - item.final.enemy.hp, plan.hits.reduce((sum, hit) => sum + hit.damage, 0));
      });
      if (config.chain) {
        check(prefix + 'J after confirmed counter contact reaches second and third strikes', () => {
          assert.deepEqual(plan.attacks.map(attack => attack.combo), [0, 1, 2]);
          assert.deepEqual(plan.hits.map(hit => hit.combo), [0, 1, 2]);
          assert.equal(plan.attacks[1].name, 'light');
          assert.equal(plan.attacks[2].name, 'light');
          if (mode.style === 'fenghuang') {
            assert.equal(plan.attacks[1].motion, mode.stance === 'kick' ? 'kick_light1' : 'light1',
              'Counter continuation must use the alternate first strike, not replay the counter/light2 source clip');
          }
          assert.deepEqual(inputs.filter(input => input.reason.startsWith('confirmed-contact')).map(input => input.command), ['light', 'light']);
          assert.ok(snapshots.some(s => s.player.state === 'attack'), 'Actual rendered actor receives attack states');
        });
      } else {
        check(prefix + 'single-slot handoff does not replay an older command after recovery', () => {
          assert.equal(plan.attacks.length, 1);
          assert.equal(plan.hits.length, 1);
          assert.ok(['idle', 'guard', 'move'].includes(item.final.player.state));
          if (config.commands.length > 1) assert.equal(plan.attacks[0].name, config.commands.at(-1));
        });
      }
      if (config.commands.at(-1) === 'ability' && mode.style === 'fenghuang') {
        check(prefix + 'E performs the real stance switch and its own follow-up action', () => {
          const next = mode.stance === 'punch' ? 'kick' : 'punch';
          assert.equal(plan.firstAttack.motion, 'switch_' + next);
          assert.equal(item.final.player.stance, next);
          assert.ok(events.some(event => event.type === 'stanceChange' && event.stance === next));
        });
      }
    }

    const configs = [
      { suffix: 'J-chain', commands: ['light'], immediate: true, delay: 0, chain: true },
      { suffix: 'late-K', commands: ['heavy'], immediate: false, delay: 0.12, chain: false },
      { suffix: 'late-E', commands: ['ability'], immediate: false, delay: 0.18, chain: false },
    ];
    for (const mode of modes) {
      const cases = mode.id === 'azure' ? [...configs, {
        suffix: 'J-then-K-single-slot', commands: ['light', 'heavy'], immediate: true, delay: 0, chain: false,
      }] : configs;
      for (const config of cases) {
        const item = { id: mode.id + '-' + config.suffix, mode, config, screenshots: [] };
        report.cases.push(item);
        console.log('CHECK', item.id);
        try {
          assert.ok(await catchParry(item, mode, config), 'Four normal timing attempts did not produce an observable eligible parry');
          await shot(item, '01-handoff');
          await wait(() => window.__parryFollowupProbe.plan?.firstAttack, null, 4000);
          item.followup = await read();
          await shot(item, '02-followup');
          await wait(() => window.__parryFollowupProbe.plan?.contactsComplete, null, 6500);
          await shot(item, '03-confirmed-contact');
          // End the real exchange using the ordinary training toggle; then
          // observe recovery long enough to catch duplicate queued attacks.
          if (!(await read()).training) await action('training');
          await page.keyboard.up('l');
          await action('guard_held', false);
          await wait(() => ['idle', 'guard', 'move'].includes(window.__godotState.player.state));
          const recoveryTime = (await read()).time;
          await wait(time => window.__godotState.time >= time + 0.35, recoveryTime);
          item.final = await read();
          item.observations = await collect();
          verify(item, mode, config);
        } catch (error) {
          item.error = error.stack || error.message;
          report.failures.push({ label: item.id, message: error.message });
          item.observations = await collect();
          try { await shot(item, 'failure'); } catch (_) {}
        } finally {
          await stop();
          await release();
          save();
        }
      }
    }
    await action('menu');
    check('all ten planned mode/input cases were exercised', () => assert.equal(report.cases.length, 10));
    check('no browser, engine or failed-resource errors', () => {
      assert.deepEqual(report.errors, []);
      assert.deepEqual(report.httpErrors, []);
    });
    await page.evaluate(() => clearInterval(window.__parryFollowupProbe.timer));
    report.passed = report.failures.length === 0;
    report.finishedAt = new Date().toISOString();
    save();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length,
      cases: report.cases.length, failures: report.failures }, null, 2));
    assert.ok(report.passed, 'See build/screenshots/parry-followup/report.json');
  } catch (error) {
    report.passed = false;
    report.fatal = error.stack || error.message;
    save();
    throw error;
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
