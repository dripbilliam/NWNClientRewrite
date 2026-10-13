import { getAttackData } from './combat_attack_data.js';
import { rulesetInt } from './combat_stats.js';
import { nativeDistanceSquared } from './nearest_objects.js';

const totalAttacks = r => { const sum = (r.onhandAttacks+r.offhandAttacks+r.additionalAttacks+r.bonusEffectAttacks)|0;return sum>1?sum&255:1; };
// ResolveSituationalModifiers 0x1403ebc40..1403ebdfa. A ranged attack's
// full XYZ distance gate precedes status, level and PC/familiar checks.
export function resolveSituationalModifiers(actor,target,data,rules) {
  if (target.objectType !== 5) return;
  if (data.ranged !== 0) {
    if (![actor,target].every(o=>o.position?.length===3&&o.position.every(Number.isFinite))) throw new Error('Native coup-de-grace positions are unavailable');
    const range = rulesetInt(rules,'MAX_RANGED_COUP_DE_GRACE',10);
    if (Math.fround(Math.imul(range,range)) < nativeDistanceSquared(actor.position,target.position)) return;
  }
  if (!Number.isInteger(target.creatureState)) throw new Error('Native coup-de-grace creature status is unavailable');
  if (((target.creatureState-8)&255)<2) {
    if (!Number.isInteger(target.stats?.level)) throw new Error('Native coup-de-grace target level is unavailable');
    if ((target.stats.level&255)<=rulesetInt(rules,'COUP_DE_GRACE_LEVEL_LIMIT',4)&&!target.isPC&&!target.isPossessedFamiliar) data.coupDeGrace=1;
  }
}
// ResolveCachedSpecialAttacks 0x1403e45f0..1403e4719. Both independent
// ushort queues feed the first unused record, not necessarily currentAttack.
export function resolveCachedSpecialAttacks(actor,warning) {
  const round=actor.combatRound;
  if (!Array.isArray(round.specialAttacks)||!Array.isArray(round.specialAttackParameters)) throw new Error('Native special attack queues are unavailable');
  if (!round.specialAttacks.length) return;
  let index=round.currentAttack&255;
  if(index>=totalAttacks(round))return;
  while(getAttackData(round,index,warning).attackType!==0) { if(!round.specialAttacks.length||++index>=totalAttacks(round))return; }
  // Native can read stale allocated storage after a mismatched queue. Local
  // arrays cannot reproduce that memory access safely; retain both queues.
  if(!Number.isInteger(round.specialAttacks[0])||!Number.isInteger(round.specialAttackParameters[0])) throw new Error('Native special attack queue head data is unavailable');
  const data=getAttackData(round,index,warning);data.attackType=round.specialAttacks[0];data.specialParameter=round.specialAttackParameters[0];
  round.specialAttacks.shift();if(round.specialAttackParameters.length)round.specialAttackParameters.shift();
}
