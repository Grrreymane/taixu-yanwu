'use strict';

// Run after the matching export, with no competing Godot/browser GPU process.
// A disposable context receives ordinary UI actions, pointer clicks and keys.
// __godotState is read-only: no clock, actor, storage or campaign-state injection.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const revision = 'user-dialogue-1';
const sentiOpeningDuration = 4.2333336;
const sentiStandbyDuration = 2.0;
const out = path.resolve(__dirname, '../build/screenshots/native-dialogue-web');
const report = {
  startedAt: new Date().toISOString(), passed: false, dialogueRevision: revision,
  storage: 'Fresh disposable browser context; no user profile, storageState, saved cookies or persistent profile',
  scope: 'Three real player appearances, two viewports, uninterrupted source clips across dialogue clicks, camera continuity and ordinary Escape return to battle',
  checks: [], cases: [], screenshots: [], errors: [], warnings: [], httpErrors: []
};
fs.mkdirSync(out, { recursive: true });
const save = () => fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
function check(label, body) { body(); report.checks.push(label); save(); }
const frame = s => ({ position: s.cinematic.position, target: s.cinematic.target, fov: s.cinematic.fov, roll: s.cinematic.roll, shot: s.cinematic.shot });
const battle = s => ({
  time: s.time, countdown: s.stageCountdown, phase: s.campaign.phase, stage: s.campaign.stageIndex,
  player: { hp: s.player.hp, energy: s.player.energy, x: s.player.x, state: s.player.state, stateTime: s.player.stateTime },
  enemies: s.enemies.map(e => ({ id: e.id, hp: e.hp, x: e.x, state: e.state, stateTime: e.stateTime }))
});

function nativeContract(state, label) {
  assert.equal(state.story.active, true, `${label}: still in actual dialogue`);
  assert.equal(state.story.revision, revision, `${label}: approved wording stays unchanged`);
  for (const identity of ['fuhua', 'senti']) {
    const acting = state.story.performance?.[identity];
    assert.ok(acting, `${label}: ${identity} telemetry exists`);
    assert.equal(acting.mode, 'native_full_clip', `${label}: ${identity} uses one full source clip`);
    assert.ok(typeof acting.sourceClip === 'string' && acting.sourceClip.length > 0, `${label}: source clip named`);
    assert.ok(Number.isFinite(acting.duration) && acting.duration > 0, `${label}: clip duration valid`);
    assert.ok(Number.isFinite(acting.sourceTime) && acting.sourceTime >= 0 && acting.sourceTime <= acting.duration + 0.0001, `${label}: sample stays inside its clip`);
    assert.equal(acting.skeletalEdits, 0, `${label}: no hand-authored skeletal edits`);
    assert.ok(typeof acting.facialMode === 'string' && acting.facialMode.length > 0, `${label}: facial source identified`);
    assert.ok(acting.updates > 0, `${label}: native animation is being sampled`);
    if (identity === 'senti') {
      const opening = state.story.time < sentiOpeningDuration;
      const expectedClip = opening ? 'native/Idle' : 'native/Standby';
      const expectedDuration = opening ? sentiOpeningDuration : sentiStandbyDuration;
      const expectedTime = opening ? state.story.time : (state.story.time - sentiOpeningDuration) % sentiStandbyDuration;
      assert.equal(acting.sourceClip, expectedClip, `${label}: Senti follows the original one-shot Idle then Standby sequence`);
      assert.ok(Math.abs(acting.duration - expectedDuration) < 0.00001, `${label}: Senti source duration is untrimmed`);
      assert.ok(Math.abs(acting.sourceTime - expectedTime) < 0.0001, `${label}: Senti samples the sequence's continuous source clock`);
    }
  }
}

function continuous(before, after, label) {
  nativeContract(after, label);
  assert.deepEqual(frame(after), frame(before), `${label}: no camera movement on click`);
  assert.deepEqual(battle(after), battle(before), `${label}: no battle/countdown advancement`);
  const elapsed = after.story.time - before.story.time;
  assert.ok(elapsed >= -0.00001, `${label}: continuous story clock never restarts`);
  for (const identity of ['fuhua', 'senti']) {
    const a = before.story.performance[identity], b = after.story.performance[identity];
    assert.equal(b.facialMode, a.facialMode, `${label}: facial provenance does not change with speaker`);
    assert.ok(b.updates >= a.updates, `${label}: sampling count never restarts`);
    // C6's complete one-shot Idle hands off to Standby on the story clock.
    // A click that straddles that boundary must allow the intended clip change,
    // not modulo the new frame against the previous clip's 4.233-second span.
    if (identity === 'senti') {
      const sameStage = (before.story.time < sentiOpeningDuration) === (after.story.time < sentiOpeningDuration);
      if (sameStage) assert.equal(b.sourceClip, a.sourceClip, `${label}: speaker change cannot replace Senti's current full clip`);
      else {
        assert.equal(a.sourceClip, 'native/Idle');
        assert.equal(b.sourceClip, 'native/Standby');
      }
    } else {
      assert.equal(b.sourceClip, a.sourceClip, `${label}: speaker changes cannot replace ${identity}'s clip`);
      assert.equal(b.duration, a.duration, `${label}: full clip duration is not shortened for the line`);
    }
    const expected = identity === 'senti'
      ? (after.story.time < sentiOpeningDuration ? after.story.time : (after.story.time - sentiOpeningDuration) % sentiStandbyDuration)
      : (a.sourceTime + elapsed) % a.duration;
    const difference = Math.abs(b.sourceTime - expected);
    const wrappedDifference = Math.min(difference, Math.abs(difference - b.duration));
    assert.ok(wrappedDifference < 0.035, `${label}: ${identity} clip follows elapsed clock across clicks/wraps (${wrappedDifference}s error)`);
  }
}

(async () => {
  let browser, context, page;
  try {
    browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
    context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    page = await context.newPage();
    page.setDefaultTimeout(12000);
    page.on('pageerror', e => report.errors.push(e.message));
    page.on('console', m => {
      if (m.type() === 'error') report.errors.push(m.text());
      if (m.type() === 'warning') report.warnings.push(m.text());
    });
    page.on('response', r => { if (r.status() >= 400) report.httpErrors.push({ url: r.url(), status: r.status() }); });
    page.on('requestfailed', r => report.httpErrors.push({ url: r.url(), failure: r.failure()?.errorText || 'request failed' }));
    const read = () => page.evaluate(() => structuredClone(window.__godotState));
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    const wait = (fn, arg = null, timeout = 15000) => page.waitForFunction(fn, arg, { timeout });
    const shot = async name => {
      const filename = name + '.png';
      await page.screenshot({ path: path.join(out, filename), timeout: 15000 });
      report.screenshots.push(filename); save(); return filename;
    };
    const nextClick = async (button = true) => {
      const { width, height } = page.viewportSize();
      const scale = Math.max(0.4, Math.min(1.8, width / 1280, height / 800));
      await page.mouse.click(button ? width - 171.5 * scale : width * 0.5, button ? height - 50.5 * scale : height - 126 * scale);
    };

    async function advance(entry, useButton) {
      let before = await read();
      if (!before.story.revealed) {
        await nextClick(false);
        // The typewriter may finish between a telemetry read and a real click.
        // Accept that ordinary click advancing exactly one line; never send a
        // second click that would silently skip the following line.
        await wait(index => {
          const s = window.__godotState.story;
          return s.active && ((s.index === index && s.revealed) || s.index === index + 1);
        }, before.story.index);
        const afterReveal = await read();
        if (afterReveal.story.index === before.story.index + 1) {
          check(`${entry.id} line ${before.story.index + 1}: click at reveal completion keeps native playback and camera`, () => continuous(before, afterReveal, 'advance at typewriter completion'));
          entry.clicks.push({ kind: 'advance', typewriterFinishedBeforeClick: true, speakerChanged: before.story.speaker !== afterReveal.story.speaker,
            before: before.story, after: afterReveal.story, cameraBefore: frame(before), cameraAfter: frame(afterReveal) });
          return;
        }
        check(`${entry.id} line ${before.story.index + 1}: text reveal preserves native playback and camera`, () => continuous(before, afterReveal, 'reveal'));
        entry.clicks.push({ kind: 'reveal', before: before.story, after: afterReveal.story, cameraBefore: frame(before), cameraAfter: frame(afterReveal) });
        before = afterReveal;
      }
      await nextClick(useButton);
      await wait(index => window.__godotState.story.active && window.__godotState.story.index === index + 1, before.story.index);
      const after = await read();
      check(`${entry.id} line ${before.story.index + 1}: speaker/line advance preserves the same full native clips`, () => continuous(before, after, 'advance'));
      entry.clicks.push({ kind: 'advance', speakerChanged: before.story.speaker !== after.story.speaker,
        before: before.story, after: after.story, cameraBefore: frame(before), cameraAfter: frame(after) });
    }

    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/?v=native-dialogue-1', { timeout: 45000 });
    await wait(() => window.__godotState?.ready, null, 90000);
    report.readyAt = new Date().toISOString();
    const selections = [
      { style: 'azure_empyrea', appearance: 'default' },
      { style: 'azure_empyrea', appearance: 'taixu_memory' },
      { style: 'fenghuang', appearance: 'default' }
    ];
    for (const selection of selections) {
      for (const viewport of [{ width: 1440, height: 900 }, { width: 960, height: 540 }]) {
        const entry = { id: `${selection.style}-${selection.appearance}-${viewport.width}x${viewport.height}`, selection, viewport, samples: [], clicks: [] };
        report.cases.push(entry); save();
        await action('menu');
        await wait(() => window.__godotState.campaign.phase === 'menu' && !window.__godotState.story.active);
        await page.setViewportSize(viewport);
        await action('select_style:' + selection.style);
        await wait(style => window.__godotState.fighter.styleId === style, selection.style);
        await action('select_appearance:' + selection.appearance);
        await wait(appearance => window.__godotState.fighter.appearanceId === appearance, selection.appearance);
        await action('contract:mirror');
        await action('start');
        await wait(() => window.__godotState.story.active && window.__godotState.story.scene === 'intro' && window.__godotState.story.performance?.senti?.updates > 0);
        const initial = await read();
        entry.initial = { story: initial.story, battle: battle(initial), camera: frame(initial), fighter: initial.fighter };
        check(`${entry.id}: actual chosen model enters original-clip dialogue`, () => {
          nativeContract(initial, entry.id);
          assert.equal(initial.fighter.styleId, selection.style);
          assert.equal(initial.fighter.appearanceId, selection.appearance);
          assert.equal(initial.story.actors, 2);
          assert.equal(initial.story.index, 0);
          assert.ok(initial.story.total >= 4, 'Need multiple real lines and a remaining line for Escape skip');
          assert.equal(initial.cinematic.shot, 'dialogue_two_shot');
        });

        for (const [index, target] of [[0, 0.75], [1, 2.5], [2, 5.05]]) {
          await wait(({ index, target }) => {
            const s = window.__godotState.story;
            return s.active && s.index === index && s.time >= target;
          }, { index, target });
          const state = await read();
          check(`${entry.id}: native clip and camera remain continuous at line ${index + 1}`, () => continuous(initial, state, 'elapsed native playback'));
          entry.samples.push({ index, targetClock: target, observedClock: state.story.time, speaker: state.story.speaker,
            text: state.story.text, performance: state.story.performance, camera: frame(state), screenshot: await shot(`${entry.id}-line-${index + 1}`) });
          if (index < 2) await advance(entry, index === 0);
        }
        check(`${entry.id}: both native clips really advance across multiple source times`, () => {
          assert.equal(entry.samples.length, 3);
          assert.ok(entry.clicks.filter(c => c.kind === 'advance').length >= 2);
          assert.ok(entry.clicks.some(c => c.speakerChanged), 'At least one actual speaker change is exercised');
          assert.ok(entry.samples.some(s => s.performance.senti.sourceClip === 'native/Idle'), 'Original complete Idle is observed');
          assert.equal(entry.samples.at(-1).performance.senti.sourceClip, 'native/Standby', 'Original Idle finishes naturally before the looping Standby sample');
          for (const identity of ['fuhua', 'senti']) {
            assert.ok(new Set(entry.samples.map(s => s.performance[identity].sourceTime.toFixed(4))).size >= 2, `${identity}: distinct source frames sampled`);
            assert.ok(entry.samples.at(-1).performance[identity].updates > entry.samples[0].performance[identity].updates, `${identity}: samples keep updating`);
          }
        });
        const beforeSkip = await read();
        await page.keyboard.press('Escape');
        await wait(() => !window.__godotState.story.active && window.__godotState.cinematic.shot === 'battle');
        const resumed = await read();
        entry.afterSkip = { story: resumed.story, camera: frame(resumed), battle: battle(resumed) };
        check(`${entry.id}: ordinary Escape returns from dialogue to battle`, () => {
          assert.equal(resumed.story.active, false);
          assert.equal(resumed.campaign.phase, 'fight');
          assert.equal(resumed.cinematic.fov, 34);
          assert.equal(resumed.player.hp, beforeSkip.player.hp);
          assert.ok(resumed.stageCountdown < beforeSkip.stageCountdown || resumed.time > beforeSkip.time, 'Normal encounter clock resumes');
        });
        await wait(before => !window.__godotState.story.active && window.__godotState.stageCountdown <= 0 && window.__godotState.time > before, beforeSkip.time, 8000);
        const live = await read();
        entry.liveBattle = { time: live.time, countdown: live.stageCountdown, camera: frame(live), phase: live.campaign.phase };
        check(`${entry.id}: countdown reaches live normal combat`, () => {
          assert.equal(live.stageCountdown, 0);
          assert.ok(live.time > beforeSkip.time);
          assert.equal(live.training, false);
        });
        save();
      }
    }
    await action('menu');
    check('All six appearance/viewport cases complete without browser or asset errors', () => {
      assert.equal(report.cases.length, 6);
      assert.equal(report.screenshots.length, 18);
      assert.deepEqual(report.errors, []);
      assert.deepEqual(report.httpErrors, []);
    });
    report.passed = true;
    console.log(JSON.stringify({ passed: true, checks: report.checks.length, cases: report.cases.length, screenshots: report.screenshots.length, output: out }));
  } catch (error) {
    report.failure = error.stack || error.message;
    if (page) {
      try {
        report.failureState = await page.evaluate(() => structuredClone(window.__godotState));
        await page.screenshot({ path: path.join(out, 'failure.png'), timeout: 10000 });
      } catch (captureError) { report.failureCapture = captureError.message; }
    }
    console.error(error);
    process.exitCode = 1;
  } finally {
    report.completedAt = new Date().toISOString(); save();
    if (context) await context.close();
    if (browser) await browser.close();
  }
})();
