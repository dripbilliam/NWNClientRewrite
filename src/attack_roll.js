import { rulesetInt } from './combat_stats.js';

export const ATTACK_RESULT = Object.freeze({ HIT: 1, PARRIED: 2, CRITICAL: 3, MISS: 4, COUP_DE_GRACE: 7, CONCEALED: 8, MISS_CHANCE: 9 });

// ResolveAttackRoll 0x1403e4100..0x1403e45e9. Modifier queries and defensive
// resolution are callbacks because those queries mutate round state. Do not
// precompute them before the first d20: their random draw order matters.
export function resolveAttackRoll(random, { modifier, armorClass, criticalThreat, resolveDefense,
  resolveSneakAndDeath = () => {}, coupDeGrace = false, parry = null, criticalImmune = false,
  easyPreventsCritical = false, rules = {} }) {
  if (typeof resolveDefense !== 'function') throw new Error('Attack defensive effect resolution is unavailable');
  const first = random.dice(1, 20), attackModifier = modifier(), ac = armorClass();
  resolveSneakAndDeath();
  const record = { roll: first, modifier: attackModifier, armorClass: ac, confirmation: 0, threatened: false, missedBy: 0 };
  if (coupDeGrace) return { ...record, roll: 20, result: ATTACK_RESULT.COUP_DE_GRACE };
  const total = (first + attackModifier) | 0;
  const defense = resolveDefense(total >= ac);
  if (defense) return { ...record, ...defense };
  if (first !== 20 && parry?.eligible && parry.remaining > 0) {
    const check = random.dice(1, 20) + parry.rank;
    parry.remaining = (parry.remaining - 1) & 255;
    if (check >= total) {
      const riposte = check - rulesetInt(rules, 'PARRY_RIPOSTE_DIFFERENCE', 10) >= total;
      if (riposte) parry.onRiposte?.();
      return { ...record, parryRoll: check, riposte, result: ATTACK_RESULT.PARRIED };
    }
    parry.onFailed?.();
  }
  if (first === 1 || first !== 20 && total < ac) return { ...record, result: ATTACK_RESULT.MISS, missedBy: first === 1 ? 1 : Math.abs(total - ac) & 255 };
  if (first >= criticalThreat()) {
    record.threatened = true; record.confirmation = random.dice(1, 20);
    // Confirmation uses total only. The native branch gives neither natural
    // 1 nor natural 20 special treatment on this second roll.
    if (record.confirmation + attackModifier >= ac && !criticalImmune && !easyPreventsCritical) return { ...record, result: ATTACK_RESULT.CRITICAL };
  }
  return { ...record, result: ATTACK_RESULT.HIT };
}

// ResolveDefensiveEffects compares d100 STRICTLY below the chance; equal
// chances choose the attacker's miss-chance result. Blind Fight rerolls only
// failures and does so for ranged attacks too in this target build.
export function resolveConcealment(random, { missChance = 0, concealment = 0, blindFight = false }) {
  const chance = Math.max(missChance, concealment);
  if (chance <= 0) return null;
  let roll = random.dice(1, 100);
  if (roll >= chance) return null;
  if (blindFight) { roll = random.dice(1, 100); if (roll >= chance) return null; }
  return { result: missChance >= concealment ? ATTACK_RESULT.MISS_CHANCE : ATTACK_RESULT.CONCEALED, missedBy: 1, concealmentChance: chance & 255 };
}
