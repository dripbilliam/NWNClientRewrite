import { OBJECT_INVALID } from './game_object_array.js';

// SetRoundPaused 0x140379c70; SetPauseTimer 0x140379c30.
export function setRoundPaused(round, paused, owner) {
  paused |= 0;
  round.paused = paused === 0 ? false : paused === 1 ? true : paused;
  round.pausedBy = owner >>> 0;
  if (!paused && round.infinitePause) round.infinitePause = false;
}
export function setPauseTimer(round, duration, infinite = 0) {
  duration |= 0; infinite |= 0;
  if (infinite) { round.infinitePause = infinite; round.pauseTimer = 0; }
  else round.pauseTimer = round.pauseTimer > 0 ? (round.pauseTimer + duration) | 0 : duration;
}
// CheckActionLength 0x140375430: exact-one state tests and i32 wrap.
export function checkActionLength(round, ownerId, duration) {
  if (Number(round.paused) === 1 && (round.pausedBy >>> 0) !== (ownerId >>> 0)) return false;
  const available = (((((round.length | 0) - (round.overlap | 0)) | 0) - (round.timer | 0)) | 0) + 1000 | 0;
  return Number(round.started) !== 1 || (duration | 0) <= available;
}

// CheckActionLengthAtTime140375470..1403754c9. Unlike CheckActionLength,
// another owner's finite pause can expire before the proposed reaction.
export function checkActionLengthAtTime(round, ownerId, duration, delay) {
  const arrival=((round.timer|0)+(delay|0))|0,expiry=((round.timer|0)+(round.pauseTimer|0))|0;
  if(Number(round.paused)===1&&(round.pausedBy>>>0)!==(ownerId>>>0)&&arrival<expiry)return false;
  const available=((((((round.length|0)-(round.overlap|0))|0)-(round.timer|0))|0)-(delay|0)+1000)|0;
  return Number(round.started)!==1||available>=(duration|0);
}

// GetActionPending/GetAction 0x140375de0/140375da0. GetAction removes the
// head even when it is too early. The caller must check pending first.
export const actionPending = round => Boolean(round.actions[0] && round.actions[0].time <= round.timer);
export function getRoundAction(round) {
  const action = round.actions.shift();
  return action && action.time <= round.timer ? action : null;
}

// IncrementTimer 0x140376df0. Only a due spell anywhere in the list or a due
// attack at the HEAD delays the end of an overrun round.
export function incrementRoundTimer(round, milliseconds) {
  round.timer = (round.timer + milliseconds) | 0;
  if (Number(round.started) !== 1 || round.timer <= round.length) return false;
  if (round.actions.some(a => a.time <= round.timer && a.nativeActionType === 2)) return false;
  return !(actionPending(round) && round.actions[0].nativeActionType === 1);
}

// AnimationStationary 0x14048e320: native state numbers, not MDL clip names.
export function animationStationary(state) {
  state &= 65535;
  const offset = (state - 78) & 65535;
  return !((state - 2 & 65535) <= 2 || offset <= 9 && (0x3c3 >>> offset & 1));
}

// UpdateCombatRoundTimer 0x1403a76b0, also inlined in AIUpdate 0x14037be20.
// EndRound may run direct scripts; wait before querying life/animation again.
export async function updateRoundTimer(actor, milliseconds, { endRound, isDead, isDying, setAnimation } = {}) {
  if (!Number.isInteger(milliseconds)) throw new Error('Native AI update interval is unavailable');
  const round = actor.combatRound;
  if (!round) return;
  const increment = async amount => {
    if (incrementRoundTimer(round, amount)) {
      if (typeof endRound !== 'function') throw new Error('Combat round end lifecycle is unavailable');
      await endRound(actor);
    }
  };
  if (Number(round.paused) !== 1) { await increment(milliseconds); return; }
  const remaining = (round.pauseTimer - milliseconds) | 0;
  if (remaining >= 0) {
    if (!round.infinitePause) round.pauseTimer = Math.max(0, remaining);
    return;
  }
  if (round.infinitePause) return;
  setRoundPaused(round, 0, OBJECT_INVALID);
  await increment((-remaining) | 0);
  if (typeof isDead !== 'function' || typeof isDying !== 'function') throw new Error('Combat pause life-state providers are unavailable');
  if (isDead(actor) || isDying(actor) || !animationStationary(actor.animationState)) return;
  if (typeof setAnimation !== 'function') throw new Error('Combat pause animation provider is unavailable');
  await setAnimation(actor, 1);
}
