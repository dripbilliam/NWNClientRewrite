import { OBJECT_INVALID } from './game_object_array.js';
import { clearAllAttacks, clearAllSpecialAttacks, updateRoundAttackTargets } from './combat_attack_data.js';

const f = Math.fround;
function integer(value, name) {
  if (!Number.isInteger(value)) throw new Error(`Native ${name} is unavailable`);
  return value | 0;
}
// SetAnimation 0x1403a2bb0. Idle requests are remapped by body state and
// combat state; a seated actor permits only animation 36 to be stored.
export function setCreatureAnimation(actor, requested) {
  let animation = integer(requested, 'animation state');
  const chair = integer(actor.chairId, 'creature chair ID') >>> 0;
  if ((animation >>> 0) < 2) {
    const body = integer(actor.nativeBodyState, 'body state') & 255;
    animation = new Map([[1, 36], [2, 58], [3, 8], [4, 6], [5, 7], [6, 5]]).get(body)
      ?? Number(integer(actor.nativeField700, 'combat state') !== 0);
  } else if (animation === -1) animation = 0;
  if (animation === 6) {
    if (typeof actor.modelType !== 'string') throw new Error('Native animation MODELTYPE is unavailable');
    if (!actor.modelType.includes('P') && !actor.modelType.includes('F')) animation = 8;
  }
  if (chair === OBJECT_INVALID || animation === 36) actor.animationState = animation;
  return actor.animationState;
}
// SetCombatState 0x1403a2f60. Clearing state does not call EndCombatRound.
export function setCreatureCombatState(actor, state) {
  state = integer(state, 'combat state');
  if (state === 1) actor.nativeField704 = 8000;
  else if (state === 0) {
    actor.nativeField704 = 0; actor.nativeField744 = 100; actor.initiativePending = 1;
    if (actor.combatRound) {
      actor.combatRound.actions.length = 0; clearAllAttacks(actor.combatRound);
      actor.nativeAttackTarget724 = OBJECT_INVALID;
    }
  }
  actor.nativeField700 = state;
}
// SetCombatMode(0,1) 0x1403d8c50 + SetActivity 0x1403a2650. Clearing a
// single combat bit does not clear other modes. Locked activity bits veto
// that bit change, while SetCombatMode still stores mode zero.
export async function clearCreatureCombatMode(actor, providers = {}) {
  const mode = integer(actor.combatMode, 'combat mode') & 255;
  const mask = ({ 1: 0x1000, 2: 0x400, 3: 0x800, 4: 0x2000, 5: 0x4000, 6: 0x8000,
    7: 0x10000, 8: 0x20000, 9: 0x40000, 10: 0x80000, 11: 0x100000 })[mode];
  if (mask !== undefined) {
    const activities = integer(actor.activities, 'activity mask') >>> 0;
    const locked = integer(actor.lockedActivities, 'locked activity mask') >>> 0;
    if ((locked & mask) !== mask && (activities & mask) !== 0) {
      if (mode === 9 && typeof providers.defensiveCasting !== 'function') throw new Error('Native defensive casting cleanup is unavailable');
      const effect = mode === 11 ? actor.effects?.find(effect => effect.type === 95) : null;
      if (effect && typeof providers.removeEffect !== 'function') throw new Error('Native defensive stance effect cleanup is unavailable');
      actor.activities = (activities & ~mask) >>> 0;
      if (mode === 9) await providers.defensiveCasting(actor, false);
      if (effect) await providers.removeEffect(actor, effect.id);
    }
  } else if (mode !== 0) providers.warning?.('Native warning: Attempted to unset an unknown combat mode');
  actor.combatMode = 0;
}
// Vector normalize 0x140230920 uses sqrtf(1 / squared length). Inputs here
// are replacement coordinates [native x, native z, -native y].
export function normalizeOrientation(vector) {
  const [x, z, negativeY] = vector.map(f), y = f(-negativeY);
  const squared = f(f(f(x * x) + f(y * y)) + f(z * z));
  if (squared === 1 || squared >= f(0.99999) && squared <= f(1.00001)) return [x, z, negativeY];
  if (squared === 0) return [1, 0, 0];
  const factor = f(Math.sqrt(f(1 / squared)));
  return [f(x * factor), f(z * factor), f(-f(y * factor))];
}
// SetLockOrientationToObject 0x1403a3320. Missing IDs are stored; existing
// objects in another area are rejected. Unlocking faces the previous target.
export function setLockOrientation(actor, targetId, getObject) {
  targetId = integer(targetId, 'orientation target ID') >>> 0;
  if ((integer(actor.chairId, 'creature chair ID') >>> 0) !== OBJECT_INVALID) return;
  const previous = integer(actor.lockOrientationId, 'orientation lock ID') >>> 0;
  if (typeof getObject !== 'function') throw new Error('Native orientation object lookup is unavailable');
  if (targetId === OBJECT_INVALID && previous !== OBJECT_INVALID && previous !== (actor.id >>> 0)) {
    const target = getObject(previous);
    if (target && target.objectType > 4) {
      if (![actor, target].every(object => Array.isArray(object.position) && object.position.length === 3 && object.position.every(Number.isFinite)))
        throw new Error('Native orientation position is unavailable');
      actor.orientation = normalizeOrientation(target.position.map((value, i) => f(f(value) - f(actor.position[i]))));
    }
  } else {
    const target = getObject(targetId);
    if (target && target.objectType > 4 && target.areaId !== actor.areaId) return;
  }
  actor.lockOrientationId = targetId;
}
// ChangeAttackTarget 0x1403e2530. The owner supplies sticky mode cleanup;
// unsupported cleanup fails before target/queue mutation.
export async function changeAttackTarget(actor, node, targetId, providers = {}) {
  targetId = integer(targetId, 'attack target ID') >>> 0;
  if (!node || !actor.objectActionState) throw new Error('Native executing attack action is unavailable');
  if (typeof providers.setLock !== 'function') throw new Error('Native orientation lock provider is unavailable');
  let sticky;
  if (targetId === OBJECT_INVALID) {
    if (typeof providers.stickyModes !== 'function') throw new Error('Native sticky combat mode setting is unavailable');
    sticky = integer(await providers.stickyModes(), 'sticky combat mode setting');
    if (sticky === 0 && typeof providers.clearCombatMode !== 'function') throw new Error('Native combat mode cleanup is unavailable');
    // Preflight all potentially unavailable work before altering a live ID.
    await providers.preflight?.(actor);
    setCreatureAnimation({ ...actor }, 0);
    if (sticky === 0) await providers.preflightClearCombatMode?.(actor);
  }
  actor.nativeAttackTarget724 = OBJECT_INVALID; actor.attackActionTargetId = targetId;
  actor.attackTargetPosition = [0, 0, 0]; node.parameterData[0] = targetId | 0;
  actor.objectActionState.executingTargetId = targetId;
  await providers.setLock(actor, targetId);
  if (targetId !== OBJECT_INVALID) updateRoundAttackTargets(actor.combatRound, targetId);
  else {
    if (sticky === 0) await providers.clearCombatMode(actor);
    setCreatureAnimation(actor, 0); clearAllSpecialAttacks(actor.combatRound, providers.warning);
    actor.combatRound.actions.length = 0; clearAllAttacks(actor.combatRound);
  }
}
// ClearAction 0x1403870b0: attack branch + shared tail. Other action types
// have separate engine/client hooks and are deliberately not discarded here.
export async function clearCreatureAttackAction(actor, node, isHead, providers = {}) {
  if (node.nativeField9c === 0) return 0;
  if (node.actionId !== 12) throw new Error(`Native cancellation of action ${node.actionId} is unavailable`);
  if (typeof providers.processPending !== 'function' || typeof providers.setLock !== 'function')
    throw new Error('Native attack cancellation providers are unavailable');
  await providers.preflight?.(actor);
  setCreatureAnimation({ ...actor }, 0);
  integer(actor.lockOrientationId, 'orientation lock ID');
  actor.nativeAttackTarget724 = OBJECT_INVALID; actor.attackActionTargetId = OBJECT_INVALID;
  setCreatureAnimation(actor, 0);
  await providers.processPending(actor);
  actor.combatRound.actions.length = 0; clearAllAttacks(actor.combatRound);
  if ((integer(actor.lockOrientationId, 'orientation lock ID') >>> 0) !== OBJECT_INVALID)
    await providers.setLock(actor, OBJECT_INVALID);
  if (Number(isHead) === 1) actor.objectActionState.startDay = actor.objectActionState.startTime = 0;
  return 1;
}

// ClearAction1403870b0: movement/check/wait actions have no private cleanup.
// They take the shared tail; ClearAllActions owns the subsequent path reset.
// Message availability, rather than client ownership, gates stopping a head
// move. Head != 0 stops movement, but only head == 1 resets the time pair.
export async function clearCreatureMovementAction(actor, node, isHead, providers = {}) {
  if (node.nativeField9c === 0) return 0;
  if (![1,17,19,30].includes(node.actionId))
    throw new Error(`Native cancellation of action ${node.actionId} is unavailable`);
  if (typeof providers.messageAvailable !== 'function' || typeof providers.setLock !== 'function')
    throw new Error('Native movement cancellation providers are unavailable');
  const message = await providers.messageAvailable();
  if (message && node.actionId === 1 && Number(isHead) !== 0) setCreatureAnimation(actor, 0);
  if ((integer(actor.lockOrientationId, 'orientation lock ID') >>> 0) !== OBJECT_INVALID)
    await providers.setLock(actor, OBJECT_INVALID);
  if (Number(isHead) === 1) actor.objectActionState.startDay = actor.objectActionState.startTime = 0;
  return 1;
}
