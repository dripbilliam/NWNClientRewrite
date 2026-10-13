import { rulesetInt } from './combat_stats.js';
import { creatureClassLevel } from './combat_weapon.js';

// Pure local-simulation plans, not network messages or committed object state.
// The runtime must execute operations in order against the same live effect
// handles, using immediate native removal rather than NWScript RemoveEffect.
const integer = (effect, index) => effect.integers[index] | 0;
const applicable = (effect, ranged) => integer(effect, 3) === 0 || ranged !== 0 && integer(effect, 3) === 1;
const has = (target, feat) => target.stats.feats.includes(feat);
const physicalFlags = 4103;
const remainingDamage = (amount, reduction) => Math.max(0, (amount - reduction) | 0);
const feedback = (target, attacker, combat, code, amount, budget) => ({ type: 'feedback', code,
  targetId: target.id, attackerId: attacker?.id, route: combat === 1 && attacker ? 'attack' : 'direct',
  amount, ...(budget === undefined ? {} : { remaining: budget }) });

function consumeBudget(effect, amount, capacity, simulation, finiteNegative = false) {
  const budget = effect ? integer(effect, 2) : 0, operations = [];
  let absorbed = capacity;
  const finite = finiteNegative ? budget !== 0 : budget > 0;
  if (finite) {
    const used = Math.min(amount, capacity), next = (budget - used) | 0;
    if (next < 1) {
      absorbed = budget;
      if (!simulation) operations.push({ type: 'removeEffect', effectId: effect.id, immediate: true });
    } else if (!simulation) operations.push({ type: 'effectInteger', effectId: effect.id, index: 2, value: next });
  }
  const used = Math.min(amount, absorbed);
  const next = (budget - used) | 0;
  return { absorbed, budget, reported: budget && next < 1 ? budget : used,
    next: budget ? Math.max(0, next) : undefined, operations };
}

// CNWSObject::DoDamageReduction 0x140491950..0x140492611.
export function damageReduction(target, effects, rules, amount, power, {
  simulation = 0, combat = 0, ranged = 0, attacker = null
} = {}) {
  amount |= 0; power &= 255;
  let selected = null, capacity = 0, threshold = 0;
  for (const effect of effects) if (effect.type === 12 && power < integer(effect, 1) &&
    applicable(effect, ranged) && capacity < integer(effect, 0)) {
    selected = effect; capacity = integer(effect, 0); threshold = integer(effect, 1);
  }
  let innate = 0, innatePresent = false, perfectPower = 0;
  if (target.objectType === 5) {
    if (has(target, 1067)) {
      innate = rulesetInt(rules, 'EPIC_BARBARIAN_DAMAGE_REDUCTION', 5);
      const extra = creatureClassLevel(target, 0) - 23;
      if (extra > 2) innate = (innate + Math.floor(extra / 3)) | 0;
      if (innate > 0) innatePresent = true; else innate = 0;
    } else for (const [feat, tier] of [[334, 4], [333, 3], [332, 2], [196, 1]]) if (has(target, feat)) {
      const value = rulesetInt(rules, `BARBARIAN_DAMAGE_REDUCTION_LEVEL_${tier}`, tier);
      if (value > 0) { innate = value; innatePresent = true; }
      break;
    }
    if (has(target, 948)) {
      let value = rulesetInt(rules, 'DWARVEN_DEFENDER_DAMAGE_REDUCTION', 3);
      const extra = creatureClassLevel(target, 36) - 6;
      if (extra > 3) value = (value + Math.trunc(extra / 4) * 3) | 0;
      innate = (innate + value) | 0; innatePresent = true;
    }
    if (has(target, 216) && innate < rulesetInt(rules, 'PERFECT_SELF_DAMAGE_REDUCTION', 20) &&
      power < rulesetInt(rules, 'PERFECT_SELF_DAMAGE_REDUCTION_POWER', 1)) {
      innate = rulesetInt(rules, 'PERFECT_SELF_DAMAGE_REDUCTION', 20);
      perfectPower = rulesetInt(rules, 'PERFECT_SELF_DAMAGE_REDUCTION_POWER', 1); innatePresent = true;
    }
    for (const [feat, value] of [[494, 9], [493, 6], [492, 3]]) if (has(target, feat)) {
      innate = (innate + rulesetInt(rules, `EPIC_DAMAGE_REDUCTION_${value}`, value)) | 0;
      innatePresent = true; break;
    }
    if (innatePresent && (power >= threshold || perfectPower > 0 && power >= perfectPower && innate < 1 || capacity <= innate)) {
      return { amount: remainingDamage(amount, innate), source: 'innate', capacity: innate,
        operations: simulation ? [] : [feedback(target, attacker, combat, 64, Math.min(amount, innate))] };
    }
  }
  const budget = consumeBudget(selected, amount, capacity, simulation, true);
  if (power >= threshold) return { amount, source: null, capacity: 0, operations: [] };
  if (!simulation) budget.operations.push(feedback(target, attacker, combat, budget.budget ? 67 : 64,
    budget.reported, budget.next));
  return { amount: remainingDamage(amount, budget.absorbed), source: selected?.id ?? null,
    capacity: budget.absorbed, operations: budget.operations };
}

function hardness(target) {
  if (![9, 10].includes(target.objectType)) return 0;
  if (!Number.isInteger(target.hardness)) throw new Error('Door/placeable damage hardness is unavailable');
  return target.hardness & 255;
}

// GetMaximumDamageResistanceVsDamageFlag 0x140495710..0x1404958e3.
export function maximumDamageResistance(target, effects, flags, ranged = 0) {
  let selected = null, amount = 0;
  for (const effect of effects) if (effect.type === 2 && applicable(effect, ranged) &&
    (flags & integer(effect, 0)) && amount < integer(effect, 1)) {
    amount = integer(effect, 1); selected = effect;
  }
  if ((flags & physicalFlags) && amount <= hardness(target)) return { amount: hardness(target), effect: null };
  return { amount, effect: selected };
}

function innateResistance(target, flags, rules) {
  // Native branch priority for combined flags is cold, acid, fire, electrical,
  // sonic. It does not sum feats for all flags, or choose their minimum.
  const group = [[32, 428, 543], [16, 427, 533], [256, 429, 553], [128, 430, 563], [2048, 431, 573]]
    .find(([flag]) => flags & flag);
  if (!group) return { amount: 0, present: false };
  let amount = has(target, group[1]) ? Math.max(0, rulesetInt(rules, 'RESISTANCE_TO_ENERGY', 5)) : 0;
  const present = amount > 0;
  // Custom rules can make a higher tier weaker. Native walks descending tiers
  // until the first value stronger than the ordinary feat, not the global max.
  for (let tier = 10; tier > 0; tier--) if (has(target, group[2] + tier - 1)) {
    const value = rulesetInt(rules, `EPIC_ENERGY_RESISTANCE_AMOUNT_${tier}`, tier * 10);
    if (amount < value) return { amount: value, present: true };
  }
  return { amount, present };
}

// CNWSObject::DoDamageResistance 0x140492620..0x140494648.
export function damageResistance(target, effects, rules, amount, flags, {
  simulation = 0, combat = 0, baseWeapon = 0, ranged = 0, attacker = null
} = {}) {
  amount |= 0; flags >>>= 0;
  const operations = [];
  let innate = 0;
  if (target.objectType === 5) {
    const feat = innateResistance(target, flags, rules);
    innate = feat.amount;
    if (feat.present) {
      // Unlike reduction, this native stage emits feedback during simulation.
      operations.push(feedback(target, attacker, combat, 63, Math.min(amount, innate)));
      amount = remainingDamage(amount, innate);
    }
  }
  if (amount === 0) return { amount: 0, innate, source: null, capacity: 0, operations };
  let selected = null, capacity = 0;
  const physicalCount = [1, 2, 4].filter(flag => flags & flag).length;
  if (effects.length && baseWeapon && physicalCount > 1) {
    let minimum = 9999999;
    for (const flag of [1, 2, 4]) if (flags & flag) {
      const value = maximumDamageResistance(target, effects, flag, ranged);
      if (value.amount < minimum) { minimum = value.amount; selected = value.effect; }
    }
    capacity = minimum === 9999999 ? 0 : minimum;
  } else {
    for (const effect of effects) if (effect.type === 2 && applicable(effect, ranged) &&
      (flags & integer(effect, 0)) && capacity < integer(effect, 1)) {
      capacity = integer(effect, 1); selected = effect;
    }
  }
  if ((flags & physicalFlags) && capacity <= hardness(target)) { capacity = hardness(target); selected = null; }
  if (!capacity) return { amount, innate, source: null, capacity: 0, operations };
  const budget = consumeBudget(selected, amount, capacity, simulation);
  operations.push(...budget.operations);
  if (!simulation) operations.push(feedback(target, attacker, combat, budget.budget ? 66 : 63,
    budget.reported, budget.next));
  return { amount: remainingDamage(amount, budget.absorbed), innate, source: selected?.id ?? null,
    capacity: budget.absorbed, operations };
}
