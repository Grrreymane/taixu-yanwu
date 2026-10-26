'use strict';

// Run only after the matching web export is ready. All writes to the game are
// ordinary UI/keyboard actions; telemetry is read-only. A fresh browser context
// keeps trial records in a disposable profile, never the user's browser save.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const revision = process.env.GODOT_DIALOGUE_REVISION || 'user-dialogue-1';
const out = path.resolve(__dirname, '../build/screenshots/' + revision);
const report = { startedAt: new Date().toISOString(), passed: false, storage: 'fresh disposable browser context; no storageState saved', checks: [], rounds: [], errors: [], httpErrors: [] };
const stats = ['maxHp', 'damageMultiplier', 'energyGain', 'postureMultiplier', 'skillCooldownScale', 'parryHeal', 'riposteBonus', 'dodgeRefund', 'finisherEnergy'];
const pickStats = p => Object.fromEntries(stats.map(key => [key, Number(p[key] || 0)]));
const save = () => { fs.mkdirSync(out, { recursive: true }); fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2)); };
function check(label, fn) { fn(); report.checks.push(label); save(); }
function close(actual, expected, label) { assert.ok(Math.abs(actual - expected) < 0.00001, `${label}: expected ${expected}, got ${actual}`); }

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
  const page = await context.newPage();
  const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
  const read = () => page.evaluate(() => JSON.parse(JSON.stringify(window.__godotState)));
  const wait = (fn, arg = null, timeout = 15000) => page.waitForFunction(fn, arg, { timeout });
  const shot = async name => { const file = name + '.png'; await page.screenshot({ path: path.join(out, file) }); return file; };
  const release = async () => { await action('move', 0); await action('guard_held', false); };
  const frame = s => ({position:s.cinematic.position,target:s.cinematic.target,fov:s.cinematic.fov,roll:s.cinematic.roll});
  const nextClick = async (button = true) => {
    const {width,height}=page.viewportSize();
    const scale=Math.max(0.4,Math.min(1.8,Math.min(width/1280,height/800)));
    await page.mouse.click(button ? width-171.5*scale : width*0.5,button ? height-50.5*scale : height-126*scale);
  };
  page.on('pageerror', e => report.errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') report.errors.push(m.text()); });
  page.on('response', r => { if (r.status() >= 400) report.httpErrors.push({ url: r.url(), status: r.status() }); });
  page.on('requestfailed', r => report.httpErrors.push({ url: r.url(), failure: r.failure()?.errorText || 'request failed' }));

  function verifyChoice(s, selected) {
    assert.equal(s.story.active, true);
    assert.equal(s.story.scene, 'reward');
    assert.equal(s.story.choice.latestId, selected.id);
    assert.deepEqual(s.story.choice.rewardIds, s.campaign.rewardIds);
    assert.deepEqual(s.campaign.rewardIds, [selected.id]);
    assert.equal(s.story.choice.choiceCount, 1);
    assert.equal(s.campaign.boons.length, 1);
    assert.equal(s.campaign.stageIndex, 1);
    assert.equal(typeof s.story.choice.routeId, 'string');
    assert.ok(s.story.choice.routeId.length > 0);
    assert.equal(typeof s.story.choice.comboId, 'string');
  }

  function verifySinglePayment(initial, selected, now) {
    const expected = { ...initial };
    switch (selected.id) {
      case 'fist': expected.damageMultiplier *= 1.16; break;
      case 'flow': expected.energyGain *= 1.25; break;
      case 'breath': expected.maxHp += 20; break;
      case 'iron': expected.postureMultiplier *= 1.30; break;
      case 'swift': expected.skillCooldownScale = Math.max(0.4, expected.skillCooldownScale * 0.82); break;
      case 'reflection': expected.parryHeal += 6; break;
      case 'riposte': expected.riposteBonus += 0.30; break;
      case 'windstep': expected.dodgeRefund += 1.5; break;
      case 'finisher': expected.finisherEnergy += 10; break;
      case 'reservoir': expected.energyGain *= 1.15; expected.skillCooldownScale = Math.max(0.4, expected.skillCooldownScale * 0.90); break;
      case 'risk': expected.damageMultiplier *= 1.26; expected.maxHp = Math.max(1, expected.maxHp - 16); break;
      case 'calm': expected.maxHp += 12; expected.parryHeal += 3; break;
      default: assert.fail('Unknown reward effect needs a browser assertion: ' + selected.id);
    }
    for (const key of stats) close(Number(now.player[key] || 0), expected[key], selected.id + ' applied once: ' + key);
  }

  async function beatFirstEncounter(round) {
    const start = Date.now();
    while (Date.now() - start < 100000) {
      const s = await read(), c = s.campaign, p = s.player;
      assert.equal(c.stageIndex, 0, 'The bot only plays the first encounter');
      if (c.phase === 'reward') { await release(); round.fightSeconds = (Date.now() - start) / 1000; return s; }
      assert.notEqual(c.phase, 'failed', 'Normal-input first-fight bot must survive');
      assert.equal(s.story.active, false, 'No unexpected story interrupts the first fight');
      if (s.stageCountdown > 0 || s.ended || s.ultimate) { await page.waitForTimeout(55); continue; }
      const live = s.enemies.filter(e => e.hp > 0);
      const nearest = live.reduce((best, e) => !best || Math.abs(e.x - p.x) < Math.abs(best.x - p.x) ? e : best, null);
      if (!nearest) { await page.waitForTimeout(55); continue; }
      const distance = Math.abs(nearest.x - p.x), direction = Math.sign(nearest.x - p.x);
      const threat = live.find(e => e.state === 'attack' && !e.attack.hasHit && Math.abs(e.x - p.x) < e.attack.range + 0.3 && e.attack.windup - e.stateTime > 0 && e.attack.windup - e.stateTime < 0.19);
      let command = null, guard = false;
      if (['idle', 'move', 'guard'].includes(p.state)) {
        if (threat) { if (threat.attack.unblockable) command = 'dodge'; else guard = true; }
        else if (p.energy >= 100) command = 'ultimate';
        else if (p.skillCooldown <= 0 && distance < 2.5) command = 'ability';
        else if (distance < 1.7) command = nearest.state === 'guard' ? 'heavy' : 'light';
      } else if (p.state === 'attack' && p.attack.name === 'light' && p.stateTime > 0.1) {
        command = nearest.state === 'guard' ? 'heavy' : 'light';
      }
      await page.evaluate(({ move, guard, command }) => {
        window.__godotAction('move', move);
        window.__godotAction('guard_held', guard);
        if (command) window.__godotAction(command);
      }, { move: distance > 1.3 ? direction : 0, guard, command });
      if (command) round.actions[command] = (round.actions[command] || 0) + 1;
      await page.waitForTimeout(65);
    }
    throw new Error('Normal-input bot timed out before the first reward');
  }

  async function collectRewardDialogue(round, selected, selectedIndex) {
    const seen = new Set();
    const stableFrame=frame(await read());
    round.dialogueFrame=stableFrame;
    while (true) {
      let s = await read();
      verifyChoice(s, selected);
      assert.equal(s.story.revision, revision, 'Web build contains the expected dialogue revision');
      assert.deepEqual(frame(s),stableFrame,'Every dialogue line keeps the same two-person camera');
      if (!s.story.revealed) { await nextClick(false); await wait(() => window.__godotState.story.revealed); s = await read(); }
      assert.deepEqual(frame(s),stableFrame,'Clicking to reveal text cannot move or zoom the camera');
      assert.ok(!seen.has(s.story.index), 'Each reward dialogue line is collected once');
      seen.add(s.story.index);
      round.lines.push({ index: s.story.index, speaker: s.story.speaker, text: s.story.text, title: s.story.title });
      assert.ok(s.story.text.trim().length > 0);
      if(s.story.text.length > (round.longestRewardText || '').length){
        round.longestRewardText=s.story.text;
        round.longestRewardScreenshot=await shot(`round-${round.number}-longest-reward-line`);
      }
      if (s.story.index === 0) {
        check(`Round ${round.number}: selected reward name is visible in the story heading`, () => assert.ok(s.story.title.includes(selected.title), `${selected.title} missing from ${s.story.title}`));
        round.dialogueScreenshot = await shot(`round-${round.number}-reward-dialogue-${round.viewport.width}x${round.viewport.height}`);
      }
      if (s.story.index === s.story.total - 1) {
        round.beforeLastLine = s;
        // The last line is deliberately kept open. Repeated reward buttons and
        // fight commands must neither pay again nor leak queued attacks.
        for (let n = 0; n < 3; n++) await action('reward_' + selectedIndex);
        await action('light'); await action('heavy'); await action('ability'); await action('ultimate');
        await action('move', 1); await action('guard_held', true);
        await page.keyboard.press('j'); await page.keyboard.press('k'); await page.keyboard.press('e');
        await page.waitForTimeout(650);
        const frozen = await read(); round.frozenLastLine = frozen;
        check(`Round ${round.number}: last line freezes combat and countdown while dialogue remains live`, () => {
          for (const key of ['time', 'stageCountdown']) close(frozen[key], s[key], key + ' frozen');
          for (const key of ['hp', 'energy', 'x', 'stateTime']) close(frozen.player[key], s.player[key], 'player.' + key + ' frozen');
          assert.equal(frozen.player.state, s.player.state);
          assert.equal(frozen.story.index, s.story.index);
          assert.ok(frozen.story.time > s.story.time);
        });
        check(`Round ${round.number}: repeated reward input cannot add a second card or apply stats again`, () => {
          verifyChoice(frozen, selected);
          assert.deepEqual(pickStats(frozen.player), pickStats(s.player));
          assert.deepEqual(frozen.campaign.boons, s.campaign.boons);
        });
        round.lastLineScreenshot = await shot(`round-${round.number}-last-line-frozen`);
        await release();
        await nextClick();
        await wait(() => !window.__godotState.story.active);
        break;
      }
      const index = s.story.index;
      await nextClick();
      await wait(index => window.__godotState.story.index !== index || !window.__godotState.story.active, index);
    }
    check(`Round ${round.number}: every reward line was read without skipping`, () => assert.equal(round.lines.length, round.beforeLastLine.story.total));
    report.checks.push(`Round ${round.number}: actual text/continue clicks keep camera fixed across all speakers`);
    const resumed = await read();
    round.countdownSamples = [{ wallMs: 0, time: resumed.time, countdown: resumed.stageCountdown, scene: resumed.story.scene, active: resumed.story.active }];
    assert.ok(resumed.stageCountdown > 0, 'The next fight starts through its normal countdown');
    await action('reward_' + selectedIndex);
    const start = Date.now();
    let after = resumed;
    while (Date.now() - start < 4500) {
      await page.waitForTimeout(70); after = await read();
      round.countdownSamples.push({ wallMs: Date.now() - start, time: after.time, countdown: after.stageCountdown, scene: after.story.scene, active: after.story.active });
      assert.equal(after.story.active, false, 'No legacy stage_2 or duplicate reward scene may appear');
      assert.equal(after.campaign.stageIndex, 1);
      assert.deepEqual(after.campaign.rewardIds, [selected.id]);
      if (after.stageCountdown <= 0 && after.time > 0.15) break;
    }
    check(`Round ${round.number}: only one choice scene, countdown resumes, and the next encounter becomes live`, () => {
      assert.equal(after.campaign.phase, 'fight');
      assert.equal(after.stageCountdown, 0);
      assert.ok(after.time > resumed.time);
      assert.deepEqual(pickStats(after.player), pickStats(resumed.player));
      assert.equal(after.player.attack?.name || '', '', 'Ignored dialogue attack did not leak into the next encounter');
    });
    round.afterDialogue = after;
  }

  try {
    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/?v=' + revision);
    await wait(() => window.__godotState?.ready, null, 90000);
    await action('menu');
    await wait(() => window.__godotState.campaign.phase === 'menu');
    await action('select_style:azure_empyrea');
    let firstRewardId = null;
    for (const number of [1, 2]) {
      const viewport = number === 1 ? { width: 1440, height: 900 } : { width: 960, height: 540 };
      const round = { number, viewport, actions: {}, lines: [] }; report.rounds.push(round);
      await page.setViewportSize(viewport);
      await action('contract:mirror');
      await wait(() => window.__godotState.campaign.contractId === 'mirror');
      await action('start');
      await wait(() => window.__godotState.story.active && window.__godotState.story.scene === 'intro');
      const intro = await read(); round.intro = intro.story;
      assert.equal(intro.story.revision,revision,'Current dialogue revision is actually loaded');
      check(`Round ${number}: same mirror contract starts with empty choice history`, () => {
        assert.equal(intro.campaign.contractId, 'mirror');
        assert.deepEqual(intro.campaign.rewardIds, []);
        assert.equal(intro.campaign.boons.length, 0);
        assert.equal(intro.story.choice.choiceCount, 0);
        assert.deepEqual(intro.story.choice.rewardIds, []);
        assert.equal(intro.campaign.stageIndex, 0);
      });
      round.initialStats = pickStats(intro.player);
      const openingFrame=frame(intro);
      if(!intro.story.revealed){ await nextClick(false); await wait(()=>__godotState.story.revealed); }
      assert.deepEqual(frame(await read()),openingFrame,'Opening reveal keeps camera fixed');
      const openingIndex=(await read()).story.index;
      await nextClick();await wait(index=>__godotState.story.index>index,openingIndex);
      assert.deepEqual(frame(await read()),openingFrame,'Opening speaker change keeps camera fixed');
      round.openingScreenshot=await shot(`round-${number}-opening-speaker-change`);
      // Read the entire longer opening, including its longest line, at both sizes.
      round.openingLines=[intro.story.text];
      while((await read()).story.active){
        let current=await read();
        if(!current.story.revealed){await nextClick(false);await wait(()=>__godotState.story.revealed);current=await read();}
        assert.deepEqual(frame(current),openingFrame,'Full opening keeps its two-person composition');
        round.openingLines.push(current.story.text);
        if(current.story.text.length > (round.longestOpeningText || '').length){
          round.longestOpeningText=current.story.text;
          round.longestOpeningScreenshot=await shot(`round-${number}-longest-opening-line`);
        }
        const index=current.story.index;
        await nextClick();
        await wait(index=>!__godotState.story.active || __godotState.story.index!==index,index);
      }
      check(`Round ${number}: every rewritten opening line completes through actual clicks`,()=>assert.equal(round.openingLines.length,intro.story.total));
      await wait(() => !window.__godotState.story.active && window.__godotState.stageCountdown <= 0);
      const offered = await beatFirstEncounter(round);
      round.offered = offered.campaign.rewards;
      assert.ok(round.offered.length >= 2, 'At least two actual offered rewards allow a different second choice');
      const selectedIndex = number === 1 ? 0 : round.offered.findIndex(r => r.id !== firstRewardId);
      assert.ok(selectedIndex >= 0);
      const selected = round.offered[selectedIndex]; round.selected = selected; round.selectedIndex = selectedIndex;
      if (number === 1) firstRewardId = selected.id;
      else assert.notEqual(selected.id, firstRewardId);
      round.offerScreenshot = await shot(`round-${number}-reward-offer`);
      // Keyboard 1/2/3 is the real reward UI input; no reward/seed/state mutation.
      await page.keyboard.press(String(selectedIndex + 1));
      await wait(() => window.__godotState.story.active && window.__godotState.story.scene === 'reward');
      const committed = await read(); round.committedChoice = committed.story.choice;
      check(`Round ${number}: selected card is committed once and drives the immediate reward scene`, () => { verifyChoice(committed, selected); verifySinglePayment(round.initialStats, selected, committed); });
      await collectRewardDialogue(round, selected, selectedIndex);
      await action('menu');
      await wait(() => window.__godotState.campaign.phase === 'menu' && !window.__godotState.story.active);
      save();
    }
    check('Different first upgrades under the same contract produce different complete dialogue text', () => {
      assert.notEqual(report.rounds[0].selected.id, report.rounds[1].selected.id);
      assert.notDeepEqual(report.rounds[0].lines.map(x => x.text), report.rounds[1].lines.map(x => x.text));
      assert.equal(report.rounds[1].committedChoice.choiceCount, 1);
      assert.deepEqual(report.rounds[1].committedChoice.rewardIds, [report.rounds[1].selected.id]);
    });
    check('No browser errors or failed asset requests', () => { assert.deepEqual(report.errors, []); assert.deepEqual(report.httpErrors, []); });
    report.passed = true;
    console.log(`PASS: ${report.checks.length} checks; ${report.rounds.map(r => r.selected.id).join(' versus ')}; two complete reward scenes.`);
  } catch (error) {
    report.failure = error.stack || error.message;
    try { report.failureState = await read(); report.failureScreenshot = await shot('failure'); } catch (_) { /* preserve original failure */ }
    console.error(error); process.exitCode = 1;
  } finally {
    report.completedAt = new Date().toISOString(); save();
    await context.close(); await browser.close();
  }
})();
