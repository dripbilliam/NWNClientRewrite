import test from 'node:test';
import assert from 'node:assert/strict';
import { receiveAttackEvent, scriptLastAttackMode, scriptLastAttackType } from '../src/combat_events.js';
import { createAttackData } from '../src/combat_attack_data.js';
import { createCombatRound } from '../src/combat_round.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture() {
  const target = { id: 0, isPC: false, scripts: { attacked: 'custom' }, nativeAttackTarget724: invalid,
    attackActionTargetId: invalid, spellActionTargetId: invalid, animationState: 0, combatRound: createCombatRound() };
  const caller = { id: 1, isPC: true }, data = createAttackData(), trace = [];
  data.attackType = 65002; data.combatMode = 2; data.weaponAttackType = 2; data.result = 4;
  const providers = { creature: id => id === caller.id ? caller : null,
    broadcastAttack: (t, a, d) => trace.push(['attack', t.id, a.id, d.result]), equippedItem: (a, slot) => { trace.push(['slot', slot]); return { id: 7 }; },
    setLastHostile: (t, id) => trace.push(['hostile', id]), broadcastState: a => trace.push(['state', a.id]),
    removeInvisibility: a => trace.push(['remove', a.id]), associateCommand: (a, code) => trace.push(['associate', code]),
    initiative: a => trace.push(['initiative', a.id]), isDead: () => 0, runAttacked: a => trace.push(['script', a.id, a.lastAttackerId]),
    associateScripts: () => 0, requestAttack: (a, id, ...args) => trace.push(['request', id, ...args]) };
  return { target, caller, data, providers, trace };
}
test('attack delivery attributes misses, chooses caller weapon slot and runs direct receiver script after initiative', async () => {
  const { target, caller, data, providers, trace } = fixture();
  await receiveAttackEvent(target, caller.id, data, providers);
  assert.deepEqual(trace, [['attack', 0, 1, 4], ['slot', 32], ['hostile', 1], ['state', 1], ['remove', 1], ['associate', -15], ['state', 0], ['initiative', 0], ['script', 0, 1]]);
  assert.equal(target.lastAttackType, 65002); assert.equal(target.lastAttackMode, 2); assert.equal(caller.lastWeaponUsedId, 7);
});
test('ordinary PC default handler does not retaliate; suppressed familiar and dead branches follow the native retry gate', async () => {
  const { target, caller, data, providers, trace } = fixture(); target.isPC = true; target.scripts.attacked = 'default';
  await receiveAttackEvent(target, caller.id, data, providers); assert.equal(trace.some(e => ['script', 'request'].includes(e[0])), false);
  target.isPC = false; target.isPossessedFamiliar = true; trace.length = 0;
  await receiveAttackEvent(target, caller.id, data, providers); assert.deepEqual(trace.at(-1), ['request', 1, 1, 1, 0]);
  target.combatRound.started = true; target.attackActionTargetId = 4; trace.length = 0;
  await receiveAttackEvent(target, caller.id, data, providers); assert.equal(trace.some(e => e[0] === 'request'), false);
  target.isPossessedFamiliar = false; target.combatRound.started = false; providers.isDead = () => 1; trace.length = 0;
  await receiveAttackEvent(target, caller.id, data, providers); assert.deepEqual(trace.at(-1), ['request', 1, 1, 1, 0]);
});
test('null attack data still sets caller attribution; missing event providers fail before state changes', async () => {
  const { target, caller, providers, trace } = fixture();
  await assert.rejects(receiveAttackEvent(target, caller.id, null, {}), /creature/); assert.equal(target.lastAttackerId, undefined);
  await receiveAttackEvent(target, caller.id, null, providers); assert.equal(target.lastAttackerId, 1);
  assert.equal(target.lastAttackType, undefined); assert.equal(caller.lastWeaponUsedId, invalid); assert.equal(trace.some(e => ['attack', 'slot'].includes(e[0])), false);
});
test('script attack-history getters translate native IDs and respect distinct inactive defaults', () => {
  const a = { objectType: 5, nativeField700: 0, lastAttackType: 39, lastAttackMode: 11 };
  assert.equal(scriptLastAttackMode(a), invalid); assert.equal(scriptLastAttackType(a), 0);
  a.nativeField700 = 1; assert.equal(scriptLastAttackMode(a), 10); assert.equal(scriptLastAttackType(a), 8);
  a.lastAttackMode = 4; a.lastAttackType = 65002; assert.equal(scriptLastAttackMode(a), 0); assert.equal(scriptLastAttackType(a), 0);
  a.lastAttackType = 65001; assert.equal(scriptLastAttackType(a), 2);
  assert.equal(scriptLastAttackMode(null), invalid); assert.equal(scriptLastAttackType({ objectType: 9 }), 0);
});
