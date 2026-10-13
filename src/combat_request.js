import { OBJECT_INVALID } from './game_object_array.js';

// CNWSCreature::AddAttackActions 0x14037d180..14037d534. This is the
// request boundary, not the combat-round action list or a network message.
// Providers must supply the native AI/perception/action-manager operations.
// actor.nativeField700 retains an unnamed field until its semantics are mapped.
const callbacks = ['computeAIState', 'feedback', 'visibilityFlags', 'getObject',
  'asCreature', 'aiReaction', 'isDM', 'getDead', 'clearActions', 'actionManager',
  'enqueueAction', 'getCreature', 'broadcastAssociateCommand', 'broadcastBattleCry',
  'broadcastCombatState', 'resolveInitiative', 'getDoor', 'doorFieldFC', 'enqueueDoorEvent'];

export async function addAttackRequest(actor, targetId, passive, clear, front, providers = {}) {
  if (!Number.isInteger(targetId)) throw new Error('Native attack request target is unavailable');
  for (const name of callbacks) if (typeof providers[name] !== 'function')
    throw new Error(`Native attack request provider ${name} is unavailable`);
  if (typeof providers.random?.next !== 'function') throw new Error('Native attack request RNG is unavailable');
  targetId >>>= 0; passive |= 0; clear |= 0; front |= 0;
  await providers.computeAIState(actor);
  actor.attackActionTargetId = OBJECT_INVALID; // +728
  actor.nativeAttackTarget724 = OBJECT_INVALID; // +724, distinct from GetAttackTarget +738
  if (!(typeof actor.commandable === 'boolean' || Number.isInteger(actor.commandable)) || !Number.isInteger(actor.creatureState))
    throw new Error('Native attack request AI state is unavailable');
  if (Number(actor.commandable) === 0) return 0;
  if ((actor.creatureState & 255) === 5) { await providers.feedback(actor, 7); return 0; }
  const flags = await providers.visibilityFlags(actor, targetId);
  if (flags !== null && !Number.isInteger(flags)) throw new Error('Native attack visibility flags are unavailable');
  if (flags !== null && (flags & 12) === 4) return 0;
  if (targetId !== OBJECT_INVALID) {
    const object = await providers.getObject(targetId), creature = object && await providers.asCreature(object);
    if (creature) {
      const reaction = await providers.aiReaction(actor, targetId);
      if (!Number.isInteger(reaction)) throw new Error('Native attack AI reaction is unavailable');
      if ((reaction & 255) === 1) { await providers.feedback(actor, 187); return 0; }
      const dm = await providers.isDM(creature);
      if (!Number.isInteger(dm)) throw new Error('Native attack target DM state is unavailable');
      if (dm !== 0 && !actor.isPC && !actor.isPossessedFamiliar) return 0;
      const dead = await providers.getDead(creature);
      if (!Number.isInteger(dead)) throw new Error('Native attack target dead state is unavailable');
      if (dead === 1) return 0;
    }
  }
  if (!Number.isInteger(actor.creatureAnimation) || !Number.isInteger(actor.currentAITargetId))
    throw new Error('Native attack request current AI action is unavailable');
  if ((actor.creatureAnimation & 255) !== 2 || (actor.currentAITargetId >>> 0) !== targetId) {
    if (clear) await providers.clearActions(actor);
    if (targetId !== OBJECT_INVALID) {
      if (!Number.isInteger(actor.nativeField700)) throw new Error('Native battle-cry gate field +700 is unavailable');
      await providers.actionManager(actor, 4);
      // Native AddAction/AddActionToFront(12, 65535, type 3, uint32 target).
      await providers.enqueueAction(actor, 12, 65535, 3, targetId, front !== 0);
      const creature = await providers.getCreature(targetId);
      if (creature && (creature.isPC || creature.isPossessedFamiliar)) {
        creature.attackTargetId = actor.id >>> 0;
        await providers.broadcastAssociateCommand(creature, -16);
      }
      const divisor = actor.nativeField700 === 0 && (actor.isPC || actor.isPossessedFamiliar) ? 2 : 10;
      if (providers.random.next() % divisor === 0) await providers.broadcastBattleCry(actor);
      await providers.broadcastCombatState(actor);
      if (creature) await providers.resolveInitiative(actor);
      if (actor.attackActionTargetId === OBJECT_INVALID) actor.attackActionTargetId = targetId;
      actor.passiveAttack = passive; // +708, native int retained
    }
  }
  const door = await providers.getDoor(targetId);
  if (door && await providers.doorFieldFC(door) === 1)
    await providers.enqueueDoorEvent(actor.id >>> 0, targetId, 34, 0);
  return 1;
}
