import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound, endCombatRound } from '../src/combat_round.js';
import { createAttackData, clearAttackData, clearAllAttacks, clearAllSpecialAttacks, getAttackData } from '../src/combat_attack_data.js';
import { setCreatureAnimation, setCreatureCombatState, setLockOrientation, normalizeOrientation, changeAttackTarget, clearCreatureAttackAction, clearCreatureMovementAction, clearCreatureCombatMode } from '../src/combat_lifecycle.js';
import { createObjectActionState, addObjectAction } from '../src/object_actions.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function actor() {
  const a = { id: 0x80000001, areaId: 0, position: [0, 0, 0], nativeBodyState: 0, chairId: invalid,
    lockOrientationId: invalid, nativeField700: 1, animationState: 9, combatRound: createCombatRound(), objectActionState: createObjectActionState() };
  return a;
}
test('fixed attack records retain identity and signed unset damage through clearing and round end', () => {
  const a = actor(), r = a.combatRound, pool = r.attacks, data = getAttackData(r, 0), damage = data.damage, list = data.lists[0], actions = r.actions;
  assert.equal(pool.length, 50); assert.equal(new Set(pool).size, 50); assert.ok(damage.every(x => x === -1));
  data.targetId = 0; data.group = 5; data.damage[31] = 0xffff; data.damage[0] = 12; list.push({ effect: 1 }); data.strings[0] = 'name';
  data.raw.setUint8(0x79, 0x42); clearAllAttacks(r);
  assert.equal(data.targetId, invalid); assert.equal(data.group, 255); assert.equal(data.raw.getUint8(0x7c), 255);
  assert.equal(data.raw.getUint8(0x79), 0x42, 'unwritten padding is retained');
  assert.equal(data.damage, damage); assert.equal(data.lists[0], list); assert.equal(list.length, 0);
  data.damage[0] = 7; r.started = true;
  endCombatRound(r, a, {}, { processPending() {}, roundEnd() {}, isDead: () => false });
  assert.equal(r.attacks, pool); assert.equal(pool[0], data); assert.equal(r.actions, actions); assert.ok(damage.every(x => x === -1));
});
test('record clamp and special cleanup preserve consumed attacks and wrapped count behavior', () => {
  const r = createCombatRound(), warnings = [];
  assert.equal(getAttackData(r, 500, m => warnings.push(m)), r.attacks[49]); assert.equal(warnings.length, 1);
  assert.throws(() => getAttackData(r, -1), /negative/);
  r.onhandAttacks = 3; r.currentAttack = 1; r.attacks.slice(0, 4).forEach(d => { d.attackType = 9; }); r.specialAttacks.push(9);
  clearAllSpecialAttacks(r); assert.deepEqual(r.attacks.slice(0, 4).map(d => d.attackType), [9, 0, 0, 9]); assert.equal(r.specialAttacks.length, 0);
  r.onhandAttacks = 256; r.currentAttack = 0; clearAllSpecialAttacks(r); assert.equal(r.attacks[0].attackType, 9);
});
test('native idle animation remaps use body/combat state, model letters, and chair gate', () => {
  const a = actor(); setCreatureAnimation(a, 1); assert.equal(a.animationState, 1);
  a.nativeField700 = 0; setCreatureAnimation(a, 1); assert.equal(a.animationState, 0);
  for (const [body, expected] of [[1, 36], [2, 58], [3, 8], [5, 7], [6, 5]]) {
    a.nativeBodyState = body; setCreatureAnimation(a, 0); assert.equal(a.animationState, expected);
  }
  a.nativeBodyState = 4; a.modelType = 'S'; setCreatureAnimation(a, 1); assert.equal(a.animationState, 8);
  a.modelType = 'prefixP'; setCreatureAnimation(a, 0); assert.equal(a.animationState, 6);
  a.chairId = 0; setCreatureAnimation(a, 9); assert.equal(a.animationState, 6);
  a.nativeBodyState = 1; setCreatureAnimation(a, 0); assert.equal(a.animationState, 36);
  a.chairId = invalid; setCreatureAnimation(a, -1); assert.equal(a.animationState, 0, '-1 bypasses body remapping');
});
test('clearing combat state resets attack contents and initiative without ending or unpausing the round', () => {
  const a = actor(), r = a.combatRound; r.started = true; r.paused = true; r.currentAttack = 4; r.actions.push({});
  a.attackActionTargetId = 5; a.attackTargetId = 6; a.nativeAttackTarget724 = 7;
  setCreatureCombatState(a, 1); assert.equal(a.nativeField704, 8000);
  setCreatureCombatState(a, 0); assert.equal(a.nativeField700, 0); assert.equal(a.nativeField744, 100); assert.equal(a.initiativePending, 1);
  assert.equal(a.nativeAttackTarget724, invalid); assert.equal(a.attackActionTargetId, 5); assert.equal(a.attackTargetId, 6);
  assert.equal(r.started, true); assert.equal(r.paused, true); assert.equal(r.currentAttack, 4); assert.equal(r.actions.length, 0);
  setCreatureCombatState(a, 2); assert.equal(a.nativeField700, 2); assert.equal(a.nativeField704, 0);
});
test('orientation unlock faces the previous target in full 3D and retains native near-unit vectors', () => {
  const a = actor(), target = { id: 0, areaId: 0, objectType: 5, position: [3, 12, -4] }, lookup = id => id === 0 ? target : null;
  setLockOrientation(a, 0, lookup); assert.equal(a.lockOrientationId, 0);
  setLockOrientation(a, invalid, lookup); assert.equal(a.lockOrientationId, invalid);
  const factor = Math.fround(Math.sqrt(Math.fround(1 / 169)));
  assert.deepEqual(a.orientation, [Math.fround(3 * factor), Math.fround(12 * factor), -Math.fround(4 * factor)]);
  assert.deepEqual(normalizeOrientation([0, 0, 0]), [1, 0, 0]);
  assert.deepEqual(normalizeOrientation([Math.fround(1.000001), 0, 0]), [Math.fround(1.000001), 0, 0]);
  target.areaId = 1; setLockOrientation(a, 0, lookup); assert.equal(a.lockOrientationId, invalid);
  setLockOrientation(a, 42, lookup); assert.equal(a.lockOrientationId, 42, 'a missing target ID is stored');
  a.chairId = 0; setLockOrientation(a, invalid, lookup); assert.equal(a.lockOrientationId, 42);
});
test('retarget changes executing parameter and following round actions, retaining pinned targets', async () => {
  const a = actor(), r = a.combatRound, node = addObjectAction(a.objectActionState, 12);
  r.actions.push({ nativeActionType: 1, followTarget: 1, targetId: 8 }, { nativeActionType: 1, followTarget: 2, targetId: 8 }, { nativeActionType: 5, followTarget: 1, targetId: 8 });
  await changeAttackTarget(a, node, 0, { setLock: (actor, id) => { actor.lockOrientationId = id; } });
  assert.equal(node.parameterData[0], 0); assert.equal(a.objectActionState.executingTargetId, 0); assert.equal(a.attackActionTargetId, 0);
  assert.deepEqual(r.actions.map(x => x.targetId), [0, 8, 8]);
  await assert.rejects(changeAttackTarget(a, node, invalid, { setLock() {} }), /sticky/);
  assert.equal(a.attackActionTargetId, 0); assert.equal(node.parameterData[0], 0);
  const trace = []; r.started = true;
  await changeAttackTarget(a, node, invalid, { setLock: () => trace.push('lock'), stickyModes: () => 0, clearCombatMode: () => trace.push('mode') });
  assert.deepEqual(trace, ['lock', 'mode']); assert.equal(r.started, true); assert.equal(r.actions.length, 0); assert.equal(a.nativeField700, 1);
});
test('attack cancellation awaits pending work and unlocks after clearing while retaining native round state', async () => {
  const a = actor(), r = a.combatRound, node = addObjectAction(a.objectActionState, 12), trace = [];
  node.nativeField9c = 0; assert.equal(await clearCreatureAttackAction(a, node, true), 0); node.nativeField9c = 1;
  r.started = true; r.currentAttack = 3; r.actions.push({ time: 1 }); a.lockOrientationId = 0;
  a.objectActionState.startDay = 2; a.objectActionState.startTime = 5;
  await clearCreatureAttackAction(a, node, true, { async processPending() { await Promise.resolve(); trace.push(['pending', r.actions.length]); },
    setLock: (actor, id) => { trace.push(['unlock', r.actions.length, id]); actor.lockOrientationId = id; } });
  assert.deepEqual(trace, [['pending', 1], ['unlock', 0, invalid]]); assert.equal(r.started, true); assert.equal(r.currentAttack, 3);
  assert.equal(a.objectActionState.startDay, 0); assert.equal(a.objectActionState.startTime, 0);
  const unknown = { ...node, actionId: 15 }; await assert.rejects(clearCreatureAttackAction(a, unknown, false, {}), /action 15/);
});
test('forced mode clear removes only its unlocked activity and preflights defensive casting/stance hooks', async () => {
  const a = actor(); a.combatMode = 2; a.activities = 0x1400; a.lockedActivities = 0;
  await clearCreatureCombatMode(a); assert.equal(a.combatMode, 0); assert.equal(a.activities, 0x1000);
  a.combatMode = 2; a.activities = 0x1400; a.lockedActivities = 0x400;
  await clearCreatureCombatMode(a); assert.equal(a.combatMode, 0); assert.equal(a.activities, 0x1400);
  a.combatMode = 9; a.activities = 0x40000; a.lockedActivities = 0;
  await assert.rejects(clearCreatureCombatMode(a), /defensive casting/); assert.equal(a.combatMode, 9); assert.equal(a.activities, 0x40000);
  let cleared = false; await clearCreatureCombatMode(a, { defensiveCasting: (a, enabled) => { assert.equal(enabled, false); cleared = true; } });
  assert.equal(cleared, true); assert.equal(a.activities, 0);
  a.combatMode = 11; a.activities = 0x100000; a.effects = [{ type: 95, id: '1' }];
  await assert.rejects(clearCreatureCombatMode(a), /stance/); assert.equal(a.activities, 0x100000);
  await clearCreatureCombatMode(a, { removeEffect: (a, id) => { assert.equal(id, '1'); a.effects.length = 0; } });
  assert.equal(a.combatMode, 0); assert.equal(a.activities, 0); assert.equal(a.effects.length, 0);
});

test('move cancellation distinguishes message availability, nonzero head and exact-one time reset', async () => {
  for(const [message,head,animation,time] of [[true,0,9,5],[false,1,9,0],[true,1,1,0],[true,2,1,5]]){
    const a=actor(),node=addObjectAction(a.objectActionState,1),trace=[];
    a.lockOrientationId=0;a.objectActionState.startDay=2;a.objectActionState.startTime=5;
    const cache=a.combatRound.actions;cache.push({nativeActionType:1});
    assert.equal(await clearCreatureMovementAction(a,node,head,{
      messageAvailable:()=>message,setLock:(o,id)=>{trace.push([o.animationState,id]);o.lockOrientationId=id;}
    }),1);
    assert.equal(a.animationState,animation);assert.equal(a.objectActionState.startTime,time);
    assert.deepEqual(trace,[[animation,invalid]]);assert.equal(cache.length,1,'per-move cleanup does not clear attacks');
  }
});

test('auxiliary movement cancellation preserves animation and protected nodes have no provider calls',async()=>{
  for(const id of [17,19,30,45]){
    const a=actor(),node=addObjectAction(a.objectActionState,id);
    assert.equal(await clearCreatureMovementAction(a,node,1,{messageAvailable:()=>true,setLock(){throw new Error('already unlocked');}}),1);
    assert.equal(a.animationState,9);
    node.nativeField9c=0;assert.equal(await clearCreatureMovementAction(a,node,1),0);
  }
});
