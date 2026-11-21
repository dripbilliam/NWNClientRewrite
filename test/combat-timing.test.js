import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound } from '../src/combat_round.js';
import { setRoundPaused, setPauseTimer, actionPending, getRoundAction, incrementRoundTimer, animationStationary, updateRoundTimer } from '../src/combat_timing.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

function actor() { return { animationState: 9, combatRound: createCombatRound() }; }
const hooks = { isDead: () => false, isDying: () => false, setAnimation: (a, state) => { a.animationState = state; } };

test('native pause equality waits; overshoot resumes only the remaining interval and retains the old pause value', async () => {
  const a = actor(), r = a.combatRound;
  setRoundPaused(r, 1, 0x80000001); setPauseTimer(r, 1000);
  await updateRoundTimer(a, 1000, hooks);
  assert.equal(r.paused, true); assert.equal(r.pauseTimer, 0); assert.equal(r.timer, 0); assert.equal(a.animationState, 9);
  await updateRoundTimer(a, 1, hooks);
  assert.equal(r.paused, false); assert.equal(r.pausedBy, OBJECT_INVALID); assert.equal(r.timer, 1); assert.equal(a.animationState, 1);
  setRoundPaused(r, 1, 0); setPauseTimer(r, 1000); a.animationState = 9;
  await updateRoundTimer(a, 1500, hooks);
  assert.equal(r.timer, 501); assert.equal(r.pauseTimer, 1000, 'Overshoot branch never decrements the stored pause timer');
  setPauseTimer(r, 200); assert.equal(r.pauseTimer, 1200);
});

test('positive pause timers accumulate, infinite flags persist until explicit unpause, arithmetic narrows to int32', async () => {
  const a = actor(), r = a.combatRound;
  setPauseTimer(r, 30); setPauseTimer(r, 50); assert.equal(r.pauseTimer, 80);
  setPauseTimer(r, 200, 2); setRoundPaused(r, 1, 123);
  await updateRoundTimer(a, 1000, hooks); assert.equal(r.timer, 0); assert.equal(r.infinitePause, 2); assert.equal(r.pauseTimer, 0);
  setPauseTimer(r, 50); assert.equal(r.infinitePause, 2, 'Finite SetPauseTimer does not clear an existing infinite flag');
  setRoundPaused(r, 0, 0); assert.equal(r.infinitePause, false); assert.equal(r.pauseTimer, 50);
  r.pauseTimer = 0x7fffffff; setPauseTimer(r, 1); assert.equal(r.pauseTimer, -2147483648);
  setPauseTimer(r, 20); assert.equal(r.pauseTimer, 20);
  setRoundPaused(r, 2, 5); await updateRoundTimer(a, 10, hooks); assert.equal(r.timer, 10, 'AI timer tests paused == 1');
});

test('overrun ends strictly past the round length, with different spell and head-attack retention gates', () => {
  const r = createCombatRound(); r.started = true; r.length = 1000;
  assert.equal(incrementRoundTimer(r, 1000), false);
  r.actions = [{ nativeActionType: 5, time: 0 }, { nativeActionType: 2, time: 1001 }];
  assert.equal(incrementRoundTimer(r, 1), false, 'A due spell anywhere prevents end');
  r.actions[1].time = 5000; assert.equal(incrementRoundTimer(r, 0), true);
  r.actions = [{ nativeActionType: 1, time: 1000 }]; assert.equal(incrementRoundTimer(r, 0), false);
  r.actions.unshift({ nativeActionType: 5, time: 0 }); assert.equal(incrementRoundTimer(r, 0), true, 'A non-head attack does not prevent end');
  r.started = false; assert.equal(incrementRoundTimer(r, 1), false);
  r.timer = 0x7fffffff; assert.equal(incrementRoundTimer(r, 1), false); assert.equal(r.timer, -2147483648);
});

test('round action due checks include equality, but GetAction removes even a premature head', () => {
  const r = createCombatRound(), one = { time: 10 }, two = { time: 10 };
  r.actions.push(one, two); r.timer = 9;
  assert.equal(actionPending(r), false); assert.equal(getRoundAction(r), null); assert.deepEqual(r.actions, [two]);
  r.timer = 10; assert.equal(actionPending(r), true); assert.equal(getRoundAction(r), two); assert.equal(getRoundAction(r), null);
});

test('pause resume awaits round end scripts and requeries life state before restoring animation', async () => {
  const a = actor(), r = a.combatRound, trace = [];
  r.started = true; r.length = 10; setRoundPaused(r, 1, 2); setPauseTimer(r, 5);
  await updateRoundTimer(a, 20, { ...hooks,
    async endRound() { trace.push('script'); await Promise.resolve(); a.dead = true; trace.push('finished'); },
    isDead: () => { trace.push('dead'); return a.dead; }, setAnimation() { assert.fail('Dead actor must not restore idle'); } });
  assert.deepEqual(trace, ['script', 'finished', 'dead']); assert.equal(a.animationState, 9);
});

test('animation stationary gate excludes native movement states with ushort wrapping', () => {
  for (const state of [2, 3, 4, 78, 79, 84, 85, 86, 87]) assert.equal(animationStationary(state), false);
  for (const state of [0, 1, 9, 80, 81, 82, 83, 88, 99]) assert.equal(animationStationary(state), true);
  assert.equal(animationStationary(65538), false);
});
