import { setRoundPaused, setPauseTimer, checkActionLength } from './combat_timing.js';
import { decrementRoundLength } from './combat_round.js';
import { attackResultDoesDamage } from './combat_strike.js';
import { NativeRandom } from './native_random.js';

// MSVC rand at 140c7ed00 stores the state in __acrt_getptd()+28.
// RollDice 1402ad6a2 and ResolveMeleeAnimations 1403e634b call the SAME
// function. Live resolution must share its stream with dice on this thread.
// This explicit-seed helper remains useful for isolated animation tests.
export class CombatAnimationRandom extends NativeRandom {
  constructor(seed) {
    if (!Number.isInteger(seed)) throw new Error('Native combat animation RNG seed is unavailable');
    super(seed);
  }
}
function integer(value, name) {
  if (!Number.isInteger(value)) throw new Error(`Native melee animation ${name} is unavailable`);
  return value | 0;
}
// ResolveMeleeAnimations 0x1403e6280. This writes attack/reaction metadata
// and defender pause timing. Actual model clip selection is a separate layer.
export async function resolveMeleeAnimations(actor, index, count, target, duration, record, providers = {}) {
  if (!target) return;
  index = integer(index, 'group index'); count = integer(count, 'group count'); duration = integer(duration, 'duration');
  const animation = integer(target.animationState, 'target state');
  const offset = (animation - 15) >>> 0, locked = offset < 57 && (0x18040000000003fn >> BigInt(offset) & 1n) !== 0n;
  const creature = target.objectType === 5;
  if (creature) integer(target.creatureState, 'target creature state');
  if (!locked && record.result === 4) {
    if (typeof providers.animationRandom?.next !== 'function' || typeof providers.getLock !== 'function' || typeof providers.rangedEquipped !== 'function')
      throw new Error('Native melee miss animation providers are unavailable');
  }
  record.animationDuration = duration;
  if (locked) { record.reactionAnimation = 1; return; }
  let reactionDelay = 0;
  if (record.result === 2) { record.reactionAnimation = 12; reactionDelay = Math.trunc(duration / 2); }
  else if (record.result === 4) {
    const draw = integer(await providers.animationRandom.next(), 'random draw');
    if (draw % 2 === 0 && (integer(await providers.getLock(target), 'target orientation lock') >>> 0) === (actor.id >>> 0) && creature &&
        integer(await providers.rangedEquipped(target), 'target ranged state') === 0) record.reactionAnimation = 12;
    else record.reactionAnimation = !creature || (target.creatureState & 255) === 8 ? 1 : 11;
  }
  if (attackResultDoesDamage(record.result)) { record.reactionAnimation = 14; reactionDelay = Math.trunc(duration / 2); }
  if (!creature) return;
  if (!target.combatRound) throw new Error('Native defender combat round is unavailable');
  if (!checkActionLength(target.combatRound, actor.id, duration) || (target.creatureState & 255) === 8) {
    record.reactionAnimation = 1; return;
  }
  record.reactionDelay = reactionDelay; record.attackDuration = duration;
  setRoundPaused(target.combatRound, 1, actor.id);
  const pause = count > 1 && index < count - 1 ? Math.trunc(duration / 2) : duration;
  setPauseTimer(target.combatRound, pause); decrementRoundLength(target.combatRound, pause);
}
