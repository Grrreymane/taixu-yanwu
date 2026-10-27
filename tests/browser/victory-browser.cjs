'use strict';

// Normal keyboard, HUD and the existing action bridge only. Game state is read-only.
const { chromium } = require('<LOCAL_USER>/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const out = path.resolve(__dirname, '../../build/screenshots', process.env.GODOT_TEST_OUTPUT || 'victory');
const report = { checks: [], failures: [], errors: [], warnings: [], milestones: [] };
function check(label, body) {
  try { body(); report.checks.push({ label, passed: true }); }
  catch (error) { report.checks.push({ label, passed: false }); report.failures.push({ label, message: error.message }); }
}
function save() {
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'victory-report.json'), JSON.stringify(report, null, 2));
}

(async () => {
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist'] });
  let page;
  try {
    page = await browser.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
    page.setDefaultTimeout(10000);
    page.on('pageerror', error => report.errors.push(error.message));
    page.on('console', message => {
      if (message.type() === 'error') report.errors.push(message.text());
      else if (message.type() === 'warning') report.warnings.push(message.text());
    });
    page.on('response', response => { if (response.status() >= 400) report.errors.push(`${response.status()} ${response.url()}`); });
    await page.goto(process.env.GODOT_TEST_URL || 'http://127.0.0.1:4187/');
    await page.waitForFunction(() => window.__godotState?.ready, null, { timeout: 90000 });
    const began = Date.now();
    const deadline = began + 115000;
    const read = () => page.evaluate(() => structuredClone(window.__godotState));
    const action = (name, value) => page.evaluate(({ name, value }) => window.__godotAction(name, value), { name, value });
    const shot = name => page.screenshot({ path: path.join(out, name + '.png') });
    const release = async () => { await action('move', 0); await action('guard_held', false); };
    const stats = state => state.campaign.stats;
    const wait = (predicate, arg) => page.waitForFunction(predicate, arg);
    async function mark(name) {
      const state = await read();
      report.milestones.push({ name, wallSeconds: (Date.now() - began) / 1000, victory: state.victory, campaign: state.campaign, music: state.music, player: state.player, feel: state.feel });
      save(); return state;
    }
    async function button(name) {
      const viewport = page.viewportSize();
      const scale = Math.min(viewport.width / 1280, viewport.height / 800);
      const w = viewport.width / scale, h = viewport.height / scale;
      const panelX = w - 600, panelY = (h - 570) / 2 + 12;
      const positions = {
        music: [w - 125, 51], skip: [w - 175, h - 71], resume: [w - 220, (h - 192) / 2 + 140],
        again: [panelX + 151, panelY + 476], other: [panelX + 410, panelY + 476],
        menu: [panelX + 151, panelY + 532.5], replay: [panelX + 410, panelY + 532.5],
      };
      assert.ok(positions[name], `Known HUD button ${name}`);
      await page.mouse.click(positions[name][0] * scale, positions[name][1] * scale);
    }
    async function fightUntil(targetPhase, limitMs) {
      const until = Math.min(deadline, Date.now() + limitMs);
      while (Date.now() < until) {
        const state = await read(), player = state.player;
        if (state.campaign.phase === targetPhase) { await release(); return state; }
        if (state.campaign.phase === 'failed') throw new Error(`Normal inputs lost ${state.campaign.mode} at stage ${state.campaign.stageIndex + 1}`);
        if (state.paused) { await page.keyboard.press('Escape'); continue; }
        if (state.ended || state.ultimate || state.stageCountdown > 0) { await page.waitForTimeout(55); continue; }
        const live = (state.enemies || [state.enemy]).filter(enemy => enemy.hp > 0);
        const nearest = live.reduce((best, enemy) => !best || Math.abs(enemy.x - player.x) < Math.abs(best.x - player.x) ? enemy : best, null);
        if (!nearest) { await page.waitForTimeout(55); continue; }
        const distance = Math.abs(nearest.x - player.x);
        const threat = live.find(enemy => enemy.state === 'attack' && !enemy.attack.hasHit && Math.abs(enemy.x - player.x) < enemy.attack.range + 0.3 && enemy.attack.windup - enemy.stateTime > 0 && enemy.attack.windup - enemy.stateTime < 0.19);
        let command = null, guard = false;
        if (['idle', 'move', 'guard'].includes(player.state)) {
          if (threat) { if (threat.attack.unblockable) command = 'dodge'; else guard = true; }
          else if (player.energy >= 100 && distance < 2.2) command = 'ultimate';
          else if (player.skillCooldown <= 0 && distance < 2.5) command = 'ability';
          else if (distance < 1.7) command = nearest.state === 'guard' ? 'heavy' : 'light';
        } else if (player.state === 'attack' && player.attack.name === 'light' && player.stateTime > 0.1) {
          command = nearest.state === 'guard' ? 'heavy' : 'light';
        }
        await page.evaluate(({ move, guard, command }) => {
          window.__godotAction('move', move); window.__godotAction('guard_held', guard);
          if (command) window.__godotAction(command);
        }, { move: distance > 1.3 ? Math.sign(nearest.x - player.x) : 0, guard, command });
        await page.waitForTimeout(55);
      }
      throw new Error(`Timed out fighting normally toward ${targetPhase}`);
    }
    async function winPractice(label) {
      const state = await fightUntil('cleared', 30000);
      await wait(() => window.__godotState.victory?.visible);
      check(label, () => { assert.equal(state.winner, 'player'); assert.equal(state.campaign.mode, 'practice'); assert.equal(state.training, false); });
      return mark(label);
    }
    async function skipWithButton() {
      if ((await read()).victory.playing) await button('skip');
      await wait(() => window.__godotState.victory.visible && !window.__godotState.victory.playing);
    }

    await action('practice');
    await wait(() => window.__godotState.campaign.mode === 'practice' && window.__godotState.campaign.phase === 'fight');
    const first = await winPractice('Practice victory comes from a real fight with enemy AI enabled');
    check('Winning starts exactly one presentation after campaign statistics settle', () => {
      assert.equal(first.victory.playing, true); assert.equal(first.victory.duration, 4.4);
      assert.equal(first.ended, true); assert.ok(first.victory.time < 0.7); assert.ok(stats(first).kills > 0);
    });
    await shot('01-victory-arrival-1280');
    await wait(() => window.__godotState.victory.time > 1.7);
    await shot('02-victory-portrait-1280');
    await page.keyboard.press('Escape');
    await wait(() => window.__godotState.victory.paused);
    await page.waitForTimeout(140);
    const pauseA = await read();
    await page.waitForTimeout(280);
    const pauseB = await read();
    await shot('03-victory-paused-1280');
    check('ESC freezes presentation time, original pose, camera and settled statistics', () => {
      assert.equal(pauseA.victory.time, pauseB.victory.time); assert.equal(pauseA.time, pauseB.time);
      assert.deepEqual(pauseA.feel.player, pauseB.feel.player);
      assert.deepEqual(pauseA.feel.cameraPosition, pauseB.feel.cameraPosition);
      assert.deepEqual(stats(pauseA), stats(pauseB));
    });
    await button('resume');
    await wait(() => !window.__godotState.victory.paused);
    const enabled = (await read()).music.enabled;
    await button('music');
    await wait(enabled => window.__godotState.music.enabled !== enabled, enabled);
    await button('music');
    await wait(enabled => window.__godotState.music.enabled === enabled, enabled);
    check('The visible music button toggles without restarting the show', () => assert.equal((pauseB.victory.plays), first.victory.plays));
    await page.keyboard.press('Enter');
    await wait(() => window.__godotState.victory.visible && !window.__godotState.victory.playing);
    const settled = await mark('Enter skips to results');
    check('Enter is consumed by skip and does not also restart practice', () => {
      assert.equal(settled.campaign.phase, 'cleared'); assert.equal(settled.ended, true);
      assert.equal(settled.victory.plays, first.victory.plays); assert.deepEqual(stats(settled), stats(first));
    });
    await shot('04-results-1280');
    await button('replay');
    await wait(plays => window.__godotState.victory.playing && window.__godotState.victory.plays === plays + 1, first.victory.plays);
    const replay = await mark('Replay starts the same original winner animation');
    check('Replay resets only the presentation and preserves the score', () => {
      assert.ok(replay.victory.time < 0.7); assert.equal(replay.campaign.phase, 'cleared');
      assert.deepEqual(stats(replay), stats(first)); assert.equal(replay.time, first.time);
    });
    await page.setViewportSize({ width: 960, height: 540 });
    await wait(() => window.__godotState.victory.time > 1.6);
    await shot('05-victory-portrait-960');
    await skipWithButton();
    await page.waitForTimeout(140);
    await shot('06-results-960');
    const compact = await mark('Small viewport results');
    check('The compact view and HUD skip preserve all results', () => assert.deepEqual(stats(compact), stats(first)));

    await button('again');
    await wait(() => { const state = window.__godotState; return state.campaign.phase === 'fight' && state.campaign.mode === 'practice' && !state.victory.visible && !state.ended; });
    const restarted = await mark('Result button restarts practice');
    check('Restart clears victory, score accumulation and the old camera mode', () => {
      assert.equal(restarted.victory.time, 0); assert.equal(restarted.player.hp, 100);
      assert.equal(stats(restarted).kills, 0); assert.equal(restarted.feel.player.motion === 'victory', false);
    });
    await winPractice('A second normal practice fight can also reach victory');
    await skipWithButton(); await button('menu');
    await wait(() => window.__godotState.campaign.phase === 'menu' && !window.__godotState.victory.visible);
    const menu = await mark('Victory result returns to the home screen');
    check('Returning home clears presentation state and preserves music preference', () => {
      assert.equal(menu.victory.time, 0); assert.equal(menu.started, false); assert.equal(menu.music.enabled, enabled);
    });
    await shot('07-home-after-victory-960');
    await action('practice');
    await winPractice('A fresh practice win remains available after returning home');
    await skipWithButton(); await button('other');
    await wait(() => { const state = window.__godotState; return state.campaign.mode === 'trial' && state.campaign.phase === 'fight' && !state.victory.visible; });
    const trial = await mark('Start trial button changes mode');
    check('The practice results secondary button starts a fresh trial', () => {
      assert.equal(trial.campaign.stageIndex, 0); assert.equal(trial.training, false); assert.equal(stats(trial).kills, 0);
    });
    await page.setViewportSize({ width: 1280, height: 800 });
    const reward = await fightUntil('reward', 40000);
    check('Winning an intermediate trial fight opens rewards without a victory show', () => {
      assert.equal(reward.campaign.stageIndex, 0); assert.equal(reward.victory.visible, false);
      assert.equal(reward.campaign.rewards.length, 3);
    });
    await shot('08-intermediate-reward-1280'); await mark('First trial reward remains separate');
    check('No browser or engine errors', () => assert.deepEqual(report.errors, []));
    report.wallSecondsAfterReady = (Date.now() - began) / 1000;
    report.passed = report.failures.length === 0;
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failures: report.failures, errors: report.errors, wallSeconds: report.wallSecondsAfterReady }, null, 2));
    assert.ok(report.passed, 'See victory-report.json');
  } catch (error) {
    report.passed = false; report.fatal = error.stack;
    if (page) {
      try { report.failureState = await page.evaluate(() => window.__godotState); await page.screenshot({ path: path.join(out, 'failure.png') }); } catch (_) { /* Preserve the original failure. */ }
    }
    throw error;
  } finally { save(); await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
