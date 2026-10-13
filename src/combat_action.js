import { OBJECT_INVALID } from './game_object_array.js';
import { actionPending, getRoundAction, setRoundPaused, setPauseTimer } from './combat_timing.js';

// CNWSCombatRoundAction constructor 0x140373fc0. Mapped scalar fields;
// these are internal objects, not network action packets.
export function createRoundAction(nativeActionType, targetId = OBJECT_INVALID, fields = {}) {
  return { time: 0, animation: 0, duration: 0, count: 0, followTarget: 1,
    nativeActionType, targetId, ...fields };
}
// AddAction 0x140374280 inserts before STRICTLY later times. Ties retain
// insertion order, including different native action types.
export function addRoundAction(round, action) {
  const index = round.actions.findIndex(existing => action.time < existing.time);
  if (index < 0) round.actions.push(action); else round.actions.splice(index, 0, action);
}
const f = Math.fround;
const cvtt = value => Number.isFinite(value) && value >= -2147483648 && value < 2147483648 ? Math.trunc(value) : -2147483648;
export function attackGroupPause(duration, count) {
  duration |= 0; count |= 0;
  return count > 1 ? cvtt(f(f(f((count + 1) | 0) * f(0.5)) * f(duration))) : duration;
}

// AIActionAttackObject 0x1403dcd50, action switch only. Caller
// must establish native target/perception/range eligibility before dispatch.
// Missing providers fail before dequeuing, animation, RNG or pause mutation.
export async function dispatchAttackRoundAction(actor, currentTargetId, targetValid, providers = {}) {
  if (!Number.isInteger(currentTargetId) || typeof targetValid !== 'boolean') throw new Error('Native attack target eligibility is unavailable');
  const round = actor.combatRound;
  const zeroWarning = "Native warning: CurrentAttack == 0! This is really really bad. Grab Brenon right away!";
  if (!round) return { status: 'waiting' };
  if (round.paused || !actionPending(round)) return { status: 'waiting',
    ...(actor.animationState === 9 && (round.currentAttack & 255) === 0 ? { warning: zeroWarning } : {}) };
  const head = round.actions[0], cancelled = !targetValid && round.newAttackTargetId === OBJECT_INVALID;
  const type = cancelled ? 0 : head.nativeActionType;
  const required = type === 1 ? ['setAnimation', 'face', 'resolveAttack'] : [4, 5].includes(type) ? ['combatStep']
    : [6, 7].includes(type) ? ['equipment', 'recomputeRound'] : type === 8 ? ['weaponAttackType', 'skipOffhand'] : [];
  if (type === 1 && round.newAttackTargetId !== OBJECT_INVALID) required.push('changeTarget');
  for (const name of required) if (typeof providers[name] !== 'function') throw new Error(`Native combat action provider ${name} is unavailable`);
  await providers.preflightRoundAction?.(actor,head,type,currentTargetId);
  const action = getRoundAction(round);
  if (!action) return { status: 'waiting' };
  let targetId = currentTargetId;
  if (type === 1) {
    await providers.setAnimation(actor, action.animation & 65535);
    if (action.targetId !== currentTargetId && action.followTarget !== 1) {
      actor.attackActionTargetId = action.targetId; targetId = action.targetId;
    }
    setRoundPaused(round, 1, actor.id);
    setPauseTimer(round, attackGroupPause(action.duration, action.count));
    if (round.newAttackTargetId !== OBJECT_INVALID) {
      targetId = round.newAttackTargetId; actor.attackTargetChanged = 1;
      await providers.changeTarget(actor, targetId);
      round.newAttackTargetId = OBJECT_INVALID;
    }
    await providers.face(actor, targetId);
    await providers.resolveAttack(actor, targetId, action.count | 0, action.duration | 0);
  } else if ([3, 6, 7].includes(type)) {
    setRoundPaused(round, 1, actor.id); setPauseTimer(round, action.duration);
    if (type !== 3 && await providers.equipment(actor, action) === 1) await providers.recomputeRound(actor);
  } else if ([4, 5].includes(type)) {
    setRoundPaused(round, 1, actor.id);
    await providers.combatStep(actor, type === 4, action.duration | 0, currentTargetId);
  } else if (type === 8) {
    if ((await providers.weaponAttackType(actor) & 255) === 2) {
      await providers.skipOffhand(actor);
      round.offhandTaken = (round.offhandTaken + 1) | 0;
    }
    round.currentAttack = (round.currentAttack + 1) & 255;
    if (round.currentAttack > 49) return { status: 'dispatched', action, targetId,
      warning: "Native warning: Error! Attempting to set a really high current attack value... We're screwed!!" };
  } else if (!cancelled) {
    return { status: 'unhandled', action, warning: 'Native warning: Error! Case not handled by combat action!' };
  }
  return { status: cancelled ? 'cancelled' : 'dispatched', action, targetId,
    ...(type === 1 && actor.animationState === 9 && (round.currentAttack & 255) === 0 ? { warning: zeroWarning } : {}) };
}
