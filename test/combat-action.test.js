import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound } from '../src/combat_round.js';
import { createRoundAction, addRoundAction, attackGroupPause, dispatchAttackRoundAction } from '../src/combat_action.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

function actor() { return { id: 0x80000001, animationState: 1, combatRound: createCombatRound() }; }
function providers(trace) {
  return {
    setAnimation(a, value) { trace.push(['animation', value]); a.animationState = value; },
    face(a, target) { trace.push(['face', target, a.combatRound.pauseTimer]); },
    resolveAttack(a, target, count, duration) { trace.push(['resolve', target, count, duration]); a.combatRound.currentAttack += count; }
  };
}

test('round action insertion is stable for equal timestamps; grouped pause uses native float32 conversion', () => {
  const r = createCombatRound(), a = createRoundAction(1, 2, { time: 10 }), b = createRoundAction(3, 3, { time: 10 });
  addRoundAction(r, a); addRoundAction(r, b); addRoundAction(r, createRoundAction(5, 4, { time: 9 }));
  assert.deepEqual(r.actions.map(a => a.targetId), [4, 2, 3]); assert.equal(a.followTarget, 1);
  assert.equal(attackGroupPause(857, 2), 1285); assert.equal(attackGroupPause(857, 3), 1714);
  assert.equal(attackGroupPause(857, 1), 857); assert.equal(attackGroupPause(0x7fffffff, 2), -2147483648);
});

test('attack dispatch sets animation then pause then facing, preserving action count/duration and canonical target IDs', async () => {
  const a = actor(), r = a.combatRound, trace = [];
  r.actions.push(createRoundAction(1, 7, { animation: 9, duration: 857, count: 2 }));
  r.pauseTimer = 100;
  const result = await dispatchAttackRoundAction(a, 0, true, providers(trace));
  assert.deepEqual(trace, [['animation', 9], ['face', 0, 1385], ['resolve', 0, 2, 857]]);
  assert.equal(result.targetId, 0); assert.equal(r.pausedBy, a.id); assert.equal(r.paused, true);
  assert.equal(r.actions.length, 0); assert.equal(r.currentAttack, 2);
});

test('pinned targets and pending retarget use distinct native gates; pending canonical zero is not invalid', async () => {
  const a = actor(), r = a.combatRound, trace = [], hooks = providers(trace);
  r.actions.push(createRoundAction(1, 7, { followTarget: 0, animation: 9, duration: 100, count: 1 }));
  r.newAttackTargetId = 0;
  hooks.changeTarget = async (actor, target) => { trace.push(['change', target, actor.combatRound.pauseTimer]); };
  await dispatchAttackRoundAction(a, 9, false, hooks);
  assert.equal(a.attackActionTargetId, 7); assert.equal(a.attackTargetChanged, 1);
  assert.equal(r.newAttackTargetId, OBJECT_INVALID);
  assert.deepEqual(trace, [['animation', 9], ['change', 0, 100], ['face', 0, 100], ['resolve', 0, 1, 100]]);
});

test('missing strike providers preserve queued actions and do not mutate animation or pause', async () => {
  const a = actor(), r = a.combatRound, trace = [];
  r.actions.push(createRoundAction(1, 7, { animation: 9, duration: 100, count: 1 }));
  const hooks = providers(trace); delete hooks.resolveAttack;
  await assert.rejects(dispatchAttackRoundAction(a, 7, true, hooks), /resolveAttack/);
  assert.equal(r.actions.length, 1); assert.equal(r.paused, false); assert.equal(r.pauseTimer, 0);
  assert.equal(a.animationState, 1); assert.deepEqual(trace, []);
});

test('invalid target cancels a due action, paused/future actions wait, and pauses can dispatch without a strike resolver', async () => {
  const a = actor(), r = a.combatRound;
  r.actions.push(createRoundAction(1, 7));
  assert.equal((await dispatchAttackRoundAction(a, 7, false)).status, 'cancelled'); assert.equal(r.actions.length, 0);
  r.actions.push(createRoundAction(3, 7, { time: 1, duration: 80 }));
  assert.equal((await dispatchAttackRoundAction(a, 7, true)).status, 'waiting'); r.timer = 1;
  assert.equal((await dispatchAttackRoundAction(a, 7, true)).status, 'dispatched'); assert.equal(r.pauseTimer, 80);
  r.actions.push(createRoundAction(1, 7));
  assert.equal((await dispatchAttackRoundAction(a, 7, true)).status, 'waiting'); assert.equal(r.actions.length, 1);
});

test('combat steps keep current target, equipment recomputes only on native success one, and skipped offhand advances counters', async () => {
  const a = actor(), r = a.combatRound, trace = [];
  r.actions.push(createRoundAction(5, 9, { duration: 500 }));
  await dispatchAttackRoundAction(a, 7, true, { combatStep(a, approach, duration, target) { trace.push([approach, duration, target]); } });
  assert.deepEqual(trace, [[false, 500, 7]]); r.paused = false;
  for (const success of [0, 1, 2]) {
    r.actions.push(createRoundAction(6, 9, { duration: 5 }));
    await dispatchAttackRoundAction(a, 7, true, { equipment: () => success, recomputeRound() { trace.push('recompute'); } }); r.paused = false;
  }
  assert.equal(trace.filter(v => v === 'recompute').length, 1);
  r.currentAttack = 49; r.actions.push(createRoundAction(8, 7));
  const result = await dispatchAttackRoundAction(a, 7, true, { weaponAttackType: () => 2, skipOffhand() { trace.push('offhand'); } });
  assert.equal(r.offhandTaken, 1); assert.equal(r.currentAttack, 50); assert.match(result.warning, /really high/);
  r.currentAttack = 255; r.actions.push(createRoundAction(8, 7));
  await dispatchAttackRoundAction(a, 7, true, { weaponAttackType: () => 1, skipOffhand() { assert.fail(); } });
  assert.equal(r.currentAttack, 0);
});
