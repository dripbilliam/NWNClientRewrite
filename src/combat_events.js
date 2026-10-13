import { OBJECT_INVALID } from './game_object_array.js';

const required = ['creature', 'broadcastAttack', 'equippedItem', 'setLastHostile', 'broadcastState',
  'removeInvisibility', 'associateCommand', 'initiative', 'isDead', 'runAttacked', 'associateScripts', 'requestAttack'];
// VM commands 0x140529b60 / 0x140529cb0 translate internal mode/feat IDs,
// and both gate the history on current combat state (+700).
export function scriptLastAttackMode(object) {
  if (object?.objectType !== 5 || object.nativeField700 === 0) return OBJECT_INVALID;
  if (!Number.isInteger(object.nativeField700) || !Number.isInteger(object.lastAttackMode)) throw new Error('Native last attack mode is unavailable');
  return ({ 1: 1, 2: 2, 3: 3, 5: 4, 6: 5, 7: 6, 8: 7, 9: 8, 10: 9, 11: 10 })[object.lastAttackMode & 255] ?? 0;
}
export function scriptLastAttackType(object) {
  if (object?.objectType !== 5 || object.nativeField700 === 0) return 0;
  if (!Number.isInteger(object.nativeField700) || !Number.isInteger(object.lastAttackType)) throw new Error('Native last attack type is unavailable');
  return ({ 65000: 1, 65001: 2, 31: 3, 9: 4, 16: 5, 23: 6, 17: 7, 39: 8, 204: 9, 866: 9, 899: 9, 30: 10 })[object.lastAttackType & 65535] ?? 0;
}
// CNWSCreature::EventHandler event 15, 0x14038eaa7..0x14038edb0.
// Last-attacker/script attribution belongs to the receiver, even for misses.
// Auto-retaliation is only the dead/possessed-script-suppressed branch here;
// ordinary OnAttacked scripts drive their own action requests.
export async function receiveAttackEvent(target, callerId, data, providers = {}) {
  for (const name of required) if (typeof providers[name] !== 'function') throw new Error(`Native attack event provider ${name} is unavailable`);
  if (!Number.isInteger(callerId)) throw new Error('Native attack event caller ID is unavailable');
  callerId >>>= 0;
  await providers.preflight?.(target, callerId, data);
  const caller = await providers.creature(callerId);
  let weapon = null;
  if (data) {
    await providers.broadcastAttack(target, caller, data);
    target.lastAttackType = data.attackType & 65535; target.lastAttackMode = data.combatMode & 255;
    if (caller) {
      const slot = ({ 1: 16, 6: 16, 2: 32, 7: 8, 8: 8, 3: 16384, 4: 32768, 5: 65536 })[data.weaponAttackType & 255];
      if (slot !== undefined) weapon = await providers.equippedItem(caller, slot);
    }
  }
  target.lastAttackerId = callerId;
  await providers.setLastHostile(target, callerId);
  if (caller) {
    await providers.broadcastState(caller); await providers.removeInvisibility(caller);
    caller.lastWeaponUsedId = weapon?.id ?? OBJECT_INVALID;
    if (caller.isPC || caller.isPossessedFamiliar) await providers.associateCommand(caller, -15);
  }
  await providers.broadcastState(target); await providers.initiative(target);
  const scriptsEnabled = !target.isPossessedFamiliar || await providers.associateScripts() !== 0;
  if (scriptsEnabled && !await providers.isDead(target)) {
    if (!target.isPC || target.scripts?.attacked !== 'default') await providers.runAttacked(target);
    return;
  }
  const noTargets = [target.nativeAttackTarget724, target.attackActionTargetId, target.spellActionTargetId]
    .every(id => id === OBJECT_INVALID);
  if ((noTargets || Number(target.combatRound.started) === 0) && target.animationState === 0)
    await providers.requestAttack(target, callerId, 1, 1, 0);
}
