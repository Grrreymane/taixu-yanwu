'use strict';

// Run after the matching web export, with no competing Godot/browser renderer.
// A disposable browser context uses ordinary keyboard/UI action inputs.
// __godotState is read-only; no debug flags, injected victories, training mode,
// storage edits, clock changes, or state mutation are used to finish the run.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const out = path.resolve(__dirname, '../build/screenshots/presentation-refresh-web');
const report = {
  startedAt: new Date().toISOString(), passed: false,
  storage: 'Fresh disposable browser context; no saved storageState or user profile',
  dialogueRevision: 'user-dialogue-1', checks: [], encounters: [], rewards: [],
  dialogue: [], entrances: [], victories: [], screenshots: [], errors: [], httpErrors: [], warnings: []
};
fs.mkdirSync(out, { recursive: true });
const save = () => fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
function check(label, body) { body(); report.checks.push(label); save(); }
const settledStats = s => ({
  campaign: s.campaign.stats, fight: s.stats, completedRuns: s.campaign.completedRuns,
  bestScore: s.campaign.bestScore, bestRank: s.campaign.bestRank,
  contractWins: s.campaign.contractWins, unlockedTitles: s.campaign.unlockedTitles,
  rewardIds: s.campaign.rewardIds, achievements: s.campaign.achievements,
  winner: s.winner, time: s.time
});
const frozenCombat = s => ({
  time: s.time, countdown: s.stageCountdown,
  player: { hp: s.player.hp, energy: s.player.energy, x: s.player.x, state: s.player.state, stateTime: s.player.stateTime },
  enemies: s.enemies.map(e => ({ id: e.id, hp: e.hp, x: e.x, state: e.state, stateTime: e.stateTime }))
});
const cameraFrame = s => ({ position: s.cinematic.position, target: s.cinematic.target, fov: s.cinematic.fov, roll: s.cinematic.roll });

(async () => {
  let browser, context, page, deadline;
  let totalActions = 0;
  try {
    browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
    context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page = await context.newPage();
    page.setDefaultTimeout(10000);
    page.on('pageerror', error => report.errors.push(error.message));
    page.on('console', message => {
      if (message.type() === 'error') report.errors.push(message.text());
      if (message.type() === 'warning') report.warnings.push(message.text());
    });
    page.on('response', response => { if (response.status() >= 400) report.httpErrors.push({ status: response.status(), url: response.url() }); });
    page.on('requestfailed', request => report.httpErrors.push({ url: request.url(), failure: request.failure()?.errorText }));
    const read = () => page.evaluate(() => structuredClone(window.__godotState));
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    const remaining = () => Math.max(1, deadline - Date.now());
    const wait = (fn, arg = null, timeout = 15000) => page.waitForFunction(fn, arg, { timeout: Math.min(timeout, remaining()) });
    const release = async () => { await action('move', 0); await action('guard_held', false); };
    const shot = async name => {
      const file = name + '.png';
      await page.screenshot({ path: path.join(out, file), timeout: Math.min(10000, remaining()) });
      report.screenshots.push(file); save(); return file;
    };
    const alive = () => assert.ok(Date.now() < deadline, 'Seven-minute presentation acceptance deadline');
    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/?v=presentation-refresh-1', { timeout: 45000 });
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    deadline = Date.now() + 7 * 60 * 1000;
    report.readyAt = new Date().toISOString();

    async function nextLine() {
      let s = await read();
      if (!s.story.revealed) {
        await action('story_next');
        await wait(() => window.__godotState.story.revealed);
        s = await read();
      }
      const oldIndex = s.story.index;
      await action('story_next');
      await wait(index => !window.__godotState.story.active || window.__godotState.story.index !== index, oldIndex);
    }

    async function recordOpening() {
      const initial = await read();
      const frozen = frozenCombat(initial), camera = cameraFrame(initial);
      assert.equal(initial.story.revision, report.dialogueRevision);
      for (const [index, at] of [[0, 0.7], [1, 1.7], [2, 1.2]]) {
        await wait(({ index, at }) => {
          const s = window.__godotState.story;
          return s.active && s.index === index && s.lineTime >= at;
        }, { index, at });
        const state = await read();
        report.dialogue.push({ scene: state.story.scene, index, text: state.story.text, speaker: state.story.speaker,
          revision: state.story.revision, lineTime: state.story.lineTime, performance: state.story.performance });
        check(`Opening line ${index + 1} keeps combat and its two-person camera fixed`, () => {
          assert.deepEqual(frozenCombat(state), frozen);
          assert.deepEqual(cameraFrame(state), camera);
          assert.equal(state.story.revision, 'user-dialogue-1');
          for (const identity of ['fuhua', 'senti']) {
            const acting = state.story.performance?.[identity];
            assert.ok(acting, `${identity} acting telemetry exists`);
            assert.equal(acting.mode, 'native_full_clip', `${identity} plays complete source clips`);
            assert.equal(acting.skeletalEdits, 0, `${identity} has no authored body overlays`);
            assert.ok(acting.updates > 0);
          }
        });
        await shot(`0${index + 1}-dialogue-line-${index + 1}`);
        if (index < 2) await nextLine();
      }
      check('Senti uses original full-body idle takes without speaker-dependent posing', () => {
        for (const sample of report.dialogue) {
          assert.ok(['native/Idle', 'native/Standby'].includes(sample.performance.senti.sourceClip));
          assert.equal(sample.performance.senti.facialMode, 'source_default');
        }
      });
      await action('story_skip');
      await wait(() => !window.__godotState.story.active);
    }

    async function watchBossEntrance(initial) {
      await release();
      const entry = { stageIndex: initial.campaign.stageIndex, startedAt: Date.now(), firstTime: initial.bossEntrance.time, samples: [], screenshots: [] };
      report.entrances.push(entry);
      assert.equal(initial.campaign.stageIndex, 5, 'Entrance belongs to the sixth, final encounter');
      assert.ok(initial.bossEntrance.time < 0.8, 'Bot observes the complete entrance from its opening');
      const frozen = frozenCombat(initial);
      const targets = [1.3, 3.3];
      while (Date.now() < deadline) {
        const s = await read();
        if (!s.bossEntrance.active) {
          entry.after = { entrance: s.bossEntrance, simulationTime: s.time, countdown: s.stageCountdown, phase: s.campaign.phase };
          check('Boss entrance finishes naturally without skipped time or combat input', () => {
            assert.ok(s.bossEntrance.time >= s.bossEntrance.duration - 0.0001);
            assert.equal(s.campaign.phase, 'fight');
            assert.equal(s.story.active, false);
            assert.equal(entry.screenshots.length, 2);
          });
          await wait(before => {
            const now = window.__godotState;
            return !now.bossEntrance.active && (now.stageCountdown < before.countdown || now.time > before.time);
          }, { countdown: frozen.countdown, time: frozen.time }, 6000);
          const resumed = await read();
          entry.resumed = { time: resumed.time, countdown: resumed.stageCountdown, entrance: resumed.bossEntrance };
          check('Normal encounter countdown and simulation resume after the entrance', () => {
            assert.ok(resumed.stageCountdown < frozen.countdown || resumed.time > frozen.time);
          });
          save(); return;
        }
        assert.deepEqual(frozenCombat(s), frozen, 'Boss show freezes simulation, every HP value, state clocks and encounter countdown');
        entry.samples.push({ time: s.bossEntrance.time, simulationTime: s.time, countdown: s.stageCountdown, hp: s.player.hp,
          bossHp: s.enemy.hp, clip: s.bossEntrance.nativeClip, shot: s.cinematic.shot });
        const target = targets[entry.screenshots.length];
        if (target !== undefined && s.bossEntrance.time >= target) {
          assert.ok(s.bossEntrance.time < target + 0.7, 'Capture observes the intended entrance phase');
          const file = await shot(`boss-entrance-${String(target).replace('.', '-')}`);
          entry.screenshots.push({ targetTime: target, observedTime: s.bossEntrance.time, file });
        }
        await page.waitForTimeout(45);
      }
      throw new Error('Deadline expired during the uninterrupted boss entrance');
    }

    async function fightUntil(stopPhase, limitMs) {
      const end = Math.min(deadline, Date.now() + limitMs);
      let lastStage = -1, encounter = null;
      while (Date.now() < end) {
        alive();
        const s = await read(), p = s.player;
        if (s.bossEntrance?.active) { await watchBossEntrance(s); continue; }
        if (s.campaign.phase === stopPhase) { await release(); return s; }
        assert.notEqual(s.campaign.phase, 'failed', `Normal-input bot lost encounter ${s.campaign.stageIndex + 1}; no state-injection fallback`);
        assert.equal(s.training, false, 'Enemy AI remains enabled');
        assert.equal(s.story.active, false, 'Unexpected dialogue must be handled before combat input');
        if (lastStage !== s.campaign.stageIndex) {
          lastStage = s.campaign.stageIndex;
          encounter = { mode: s.campaign.mode, stage: lastStage + 1, startedAt: Date.now(), actions: {}, startingHp: p.hp };
          report.encounters.push(encounter); save();
        }
        if (s.paused) { await action('pause'); continue; }
        if (s.ended || s.ultimate || s.stageCountdown > 0) { await page.waitForTimeout(55); continue; }
        const live = s.enemies.filter(e => e.hp > 0);
        const nearest = live.reduce((best, e) => !best || Math.abs(e.x - p.x) < Math.abs(best.x - p.x) ? e : best, null);
        if (!nearest) { await page.waitForTimeout(55); continue; }
        const distance = Math.abs(nearest.x - p.x);
        const threat = live.find(e => e.state === 'attack' && !e.attack.hasHit && Math.abs(e.x - p.x) < e.attack.range + 0.3 &&
          e.attack.windup - e.stateTime > 0 && e.attack.windup - e.stateTime < 0.19);
        let command = null, guard = false;
        if (['idle', 'move', 'guard'].includes(p.state)) {
          if (threat) { if (threat.attack.unblockable) command = 'dodge'; else guard = true; }
          else if (p.energy >= 100 && distance < 2.2) command = 'ultimate';
          else if (p.skillCooldown <= 0 && distance < 2.5) command = 'ability';
          else if (distance < 1.7) command = nearest.state === 'guard' ? 'heavy' : 'light';
        } else if (p.state === 'attack' && p.attack.name === 'light' && p.stateTime > 0.1) {
          command = nearest.state === 'guard' ? 'heavy' : 'light';
        }
        await page.evaluate(({ move, guard, command }) => {
          window.__godotAction('move', move);
          window.__godotAction('guard_held', guard);
          if (command) window.__godotAction(command);
        }, { move: distance > 1.3 ? Math.sign(nearest.x - p.x) : 0, guard, command });
        if (command) { encounter.actions[command] = (encounter.actions[command] || 0) + 1; totalActions++; }
        encounter.lastHp = p.hp;
        await page.waitForTimeout(55);
      }
      throw new Error(`Normal-input bot timed out before ${stopPhase}`);
    }

    function selectReward(state) {
      const preferred = state.player.hp < state.player.maxHp * 0.65 ?
        ['breath', 'calm', 'reflection', 'fist', 'swift', 'iron', 'reservoir', 'flow', 'finisher', 'riposte', 'windstep', 'risk'] :
        ['fist', 'swift', 'iron', 'reservoir', 'flow', 'calm', 'reflection', 'breath', 'finisher', 'riposte', 'windstep', 'risk'];
      return state.campaign.rewards.reduce((best, card, index, offers) => preferred.indexOf(card.id) < preferred.indexOf(offers[best].id) ? index : best, 0);
    }

    async function watchVictory(label) {
      let state = await read();
      if (state.story.active) {
        assert.equal(state.story.scene, 'victory');
        assert.equal(state.story.revision, 'user-dialogue-1');
        await action('story_skip');
      }
      await wait(() => window.__godotState.victory.visible);
      state = await read();
      const entry = { label, initial: state.victory, stats: settledStats(state), samples: [] };
      report.victories.push(entry);
      assert.equal(state.winner, 'player');
      assert.equal(state.campaign.phase, 'cleared');
      assert.ok(state.victory.time < 0.8, 'Observe victory from the opening');
      for (const [name, at] of [['arrival', 0.5], ['gesture', 2.8], ['results', state.victory.duration + 0.12]]) {
        await wait(at => window.__godotState.victory.visible && window.__godotState.victory.time >= at, at, 12000);
        const s = await read();
        check(`${label}: ${name} keeps the settled score and battle clock unchanged`, () => assert.deepEqual(settledStats(s), entry.stats));
        entry.samples.push({ name, time: s.victory.time, shot: s.cinematic.shot, actor: s.feel.player,
          file: await shot(`${label}-${name}`) });
      }
      const settled = await read();
      check(`${label}: the complete original victory reaches results`, () => {
        assert.equal(settled.victory.playing, false);
        assert.equal(settled.victory.visible, true);
      });
      await action('victory_replay');
      await wait(plays => window.__godotState.victory.playing && window.__godotState.victory.plays === plays + 1, settled.victory.plays);
      const replay = await read();
      entry.replay = { victory: replay.victory, stats: settledStats(replay) };
      check(`${label}: replay restarts only the show and never rewards or scores twice`, () => {
        assert.ok(replay.victory.time < 0.8);
        assert.deepEqual(settledStats(replay), entry.stats);
      });
      await action('victory_skip');
      await wait(() => window.__godotState.victory.visible && !window.__godotState.victory.playing);
      const afterReplay = await read();
      entry.afterReplay = { victory: afterReplay.victory, stats: settledStats(afterReplay) };
      check(`${label}: replay skip also leaves all statistics intact`, () => assert.deepEqual(entry.stats, entry.afterReplay.stats));
    }

    await action('menu');
    await wait(() => window.__godotState.campaign.phase === 'menu');
    await action('select_style:azure_empyrea');
    await action('select_appearance:default');
    await action('contract:mirror');
    await action('start');
    await wait(() => window.__godotState.story.active && window.__godotState.story.scene === 'intro');
    await recordOpening();
    for (let stage = 0; stage < 5; stage++) {
      const offered = await fightUntil('reward', 90000);
      assert.equal(offered.campaign.stageIndex, stage);
      assert.equal(offered.campaign.rewardIds.length, stage);
      assert.equal(offered.victory.visible, false, 'Intermediate victories still offer upgrades');
      const index = selectReward(offered), selected = offered.campaign.rewards[index];
      const reward = { stage: stage + 1, offered: offered.campaign.rewards, selected, index, hp: offered.player.hp };
      report.rewards.push(reward);
      await page.keyboard.press(String(index + 1));
      await wait(() => window.__godotState.story.active && window.__godotState.story.scene === 'reward');
      await page.waitForTimeout(320);
      const committed = await read();
      reward.dialogue = committed.story;
      check(`Upgrade ${stage + 1} is paid once and opens the approved dialogue`, () => {
        assert.equal(committed.story.revision, 'user-dialogue-1');
        assert.equal(committed.campaign.rewardIds.length, stage + 1);
        assert.equal(committed.campaign.rewardIds[stage], selected.id);
        assert.equal(committed.campaign.stageIndex, stage + 1);
        assert.ok(committed.story.performance?.senti);
      });
      await action('story_skip');
      await wait(() => !window.__godotState.story.active);
    }
    await fightUntil('cleared', 90000);
    const clear = await read();
    check('All six trial encounters are won with five ordinary upgrade selections', () => {
      assert.equal(clear.campaign.stageIndex, 5);
      assert.equal(clear.campaign.rewardIds.length, 5);
      assert.equal(report.rewards.length, 5);
      assert.equal(report.entrances.length, 1);
      assert.equal(clear.winner, 'player');
      assert.equal(clear.training, false);
    });
    await watchVictory('azure-trial');

    // Optional skin check never compromises the required six-stage acceptance.
    if (process.env.GODOT_TEST_SKIN_PRACTICE !== '0' && remaining() > 60000) {
      await action('menu');
      await wait(() => window.__godotState.campaign.phase === 'menu');
      await action('select_appearance:taixu_memory');
      await action('practice');
      await wait(() => window.__godotState.campaign.mode === 'practice' && window.__godotState.campaign.phase === 'fight');
      await fightUntil('cleared', 45000);
      await watchVictory('taixu-practice');
      report.skinPractice = 'passed through normal practice combat and victory';
    } else {
      report.skinPractice = process.env.GODOT_TEST_SKIN_PRACTICE === '0' ? 'disabled by GODOT_TEST_SKIN_PRACTICE=0' : 'not attempted: less than 60 seconds remain after six-stage acceptance';
    }
    check('No browser errors or failed asset loads', () => { assert.deepEqual(report.errors, []); assert.deepEqual(report.httpErrors, []); });
    report.totalCombatActions = totalActions;
    report.passed = true;
    console.log(JSON.stringify({ passed: true, checks: report.checks.length, encounters: report.encounters.length, upgrades: report.rewards.length,
      entrances: report.entrances.length, victories: report.victories.length, output: out }));
  } catch (error) {
    report.failure = error.stack || error.message;
    if (page) {
      try { report.failureState = await page.evaluate(() => structuredClone(window.__godotState)); await page.screenshot({ path: path.join(out, 'failure.png'), timeout: 10000 }); }
      catch (captureError) { report.failureCapture = captureError.message; }
    }
    console.error(error);
    process.exitCode = 1;
  } finally {
    report.completedAt = new Date().toISOString(); save();
    if (context) await context.close();
    if (browser) await browser.close();
  }
})();
