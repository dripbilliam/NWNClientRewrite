import { intEntry, rulesetInt } from './combat_stats.js';
import { criticalProfile, weaponRule } from './combat_weapon.js';
import { weaponDamageFlags } from './damage_weapon.js';
import { creatureRoot, creatureAlignment } from './creature_rules.js';
import { highestDamageTypeFlag } from './damage_effect.js';

const indexOf = flags => (flags >>> 0) > 1 ? 31 - Math.clz32(flags >>> 0) : 0;
const flagAt = index => (1 << (index & 31)) >>> 0;
const rowCount = table => table.orderedRows?.length ?? table.rows.size;

// GetTotalEffectBonus category 2, 0x140393b01..0x1403952e8. Keep selection
// separate from rolling: selection uses Rank, not cost index or expected dice.
// Generic spell sources and hand-specific damage types have separate stores.
export function selectDamageEffects(effects, rules, { hand, energy = false, versus = null }) {
  const table = rules.iprp_damagecost;
  if (!table) throw new Error('Native damage effect cost rules are unavailable');
  if (!Number.isInteger(hand)) throw new Error('Damage effect attack hand is unavailable');
  const subject = versus ?? { race: 0xffffffff, lawChaos: 0xffffffff, goodEvil: 0xffffffff };
  if (!['race', 'lawChaos', 'goodEvil'].every(key => Number.isInteger(subject[key]))) throw new Error('Damage effect target context is unavailable');
  const specific = [Array(32).fill(-1), Array(32).fill(-1)], generic = [[], []];
  const rank = cost => intEntry(table, cost, 'Rank').value;
  for (const effect of effects) {
    if (![13, 14].includes(effect.type)) continue;
    // CGameEffect::GetInteger returns zero for absent integer slots.
    const at = i => (effect.integers[i] ?? 0) | 0;
    const flags = at(1) >>> 0, sourceHand = at(5), race = at(2), law = at(3), good = at(4);
    if (race !== 28 && (race >>> 0) !== subject.race || law && (law >>> 0) !== subject.lawChaos ||
      good && (good >>> 0) !== subject.goodEvil ||
      sourceHand !== 0 && sourceHand !== hand && !(hand === 6 && [1, 3].includes(sourceHand)) && !(hand === 8 && sourceHand === 7) ||
      Boolean(flags & 7) === Boolean(energy)) continue;
    const sign = effect.type === 13 ? 0 : 1, cost = at(0), index = indexOf(flags);
    if (sourceHand !== 0) {
      if (rank(cost) > rank(specific[sign][index])) specific[sign][index] = cost;
    } else {
      const spell = effect.spellId ?? -1, slots = generic[sign];
      const existing = spell === -1 ? null : slots.find(slot => slot.spell === spell && slot.flags === flags);
      if (existing) { if (rank(cost) > rank(existing.cost)) existing.cost = cost; }
      else if (slots.length < 50) slots.push({ spell, flags, cost });
    }
  }
  return { specific, generic, subject, warnings: [] };
}

// Ammunition is read by the query itself, rather than projected onto the
// creature by ApplyDamageBonus. Its penalty compares raw CostValue indices.
function selectAmmunition(items, rules, attack, selection, energy) {
  if (attack.ranged !== 1) return;
  const weapon = items.find(item => item.slot === 16);
  if (!weapon) return;
  const ammoBase = weaponRule(weapon, rules, 'AmmunitionType') & 255;
  const slot = intEntry(rules.baseitems, ammoBase, 'EquipableSlots').value >>> 0;
  // GetArraySlotFromSlotFlag accepts exactly one of eighteen slot flags.
  if (!slot || slot > 0x20000 || (slot & (slot - 1))) {
    selection.warnings.push({ code: 'combat.inventory-slot-warning', itemId: weapon.id, slot,
      reason: 'Native warning: CNWSInventory::GetItemInSlot() Invalid Slot ID.' });
    return;
  }
  const ammo = items.find(item => item.slot === slot);
  if (!ammo) return;
  const table = rules.iprp_damagecost, { specific, subject } = selection;
  const rank = cost => intEntry(table, cost, 'Rank').value;
  for (const property of [...(ammo.data.PropertiesList ?? []), ...(ammo.temporaryProperties ?? [])]) {
    const type = property.PropertyName, subtype = property.Subtype & 65535, cost = property.CostValue & 65535;
    const damage = type === 21 ? weaponDamageFlags(weapon, rules, weapon.temporaryProperties) : null;
    if (damage) selection.warnings.push(...damage.warnings);
    let index = type === 21 ? indexOf(damage.flags)
      : type === 16 ? subtype : (property.Param1Value ?? 0) & 255;
    if (type !== 21 && index > 2) index -= 2;
    if ((index > 2) !== Boolean(energy)) continue;
    const alignmentGroup = (subject.lawChaos === 2 ? 0 : subject.lawChaos === 3 ? 6 : 3) +
      (subject.goodEvil === 4 ? 0 : subject.goodEvil === 5 ? 2 : 1);
    if (type === 16 || type === 17 && [subject.lawChaos, subject.goodEvil].includes(subtype) ||
      type === 18 && subtype === subject.race || type === 19 && subtype === alignmentGroup) {
      if (rank(cost) > rank(specific[0][index])) specific[0][index] = cost;
    } else if (type === 21 && specific[1][index] < cost) specific[1][index] = cost;
  }
}

function* bonusSteps(actor, target, rules, items, random, options) {
  const { attack, energy = false, maximize = false, offhand = false, limit = 100 } = options;
  if (!attack || !Number.isInteger(attack.weaponAttackType) || !Number.isInteger(attack.ranged) || !Number.isInteger(limit))
    throw new Error('Native damage effect attack/limit state is unavailable');
  if (target?.objectType === 7 && options.versus === undefined) throw new Error('Damage effect trap creator context is unavailable');
  const versus = options.versus ?? (target?.objectType === 5 ? creatureAlignment(creatureRoot(target)) : null);
  const selection = selectDamageEffects(options.effects ?? [...(actor.itemCombatEffects?.effects ?? []), ...(actor.effects ?? [])], rules,
    { hand: attack.weaponAttackType & 255 || (offhand ? 2 : 1), energy, versus });
  selectAmmunition(items, rules, attack, selection, energy);
  const critical = options.critical ?? [3, 10].includes(attack.result);
  const multiplier = critical ? criticalProfile(actor, items, rules, offhand).multiplier : 1;
  const table = rules.iprp_damagecost;
  const roll = cost => {
    const dice = intEntry(table, cost, 'NumDice').value, die = intEntry(table, cost, 'Die').value;
    if (maximize) return Math.imul(dice ? Math.imul(dice, die) : die, multiplier);
    let amount = 0;
    for (let i = 0; i < multiplier; i++) amount = (amount + (dice ? random.dice(dice & 255, die & 255) : die)) | 0;
    return amount;
  };
  const positive = selection.specific[0].some((cost, index) => cost !== -1 && index > 2) || selection.generic[0].some(slot => indexOf(slot.flags) > 2);
  const negative = selection.specific[1].some((cost, index) => cost !== -1 && index > 2) || selection.generic[1].some(slot => indexOf(slot.flags) > 2);
  // Validate required mutation providers before consuming any dice.
  if (energy && positive && target && [options.immunity, options.resistance].some(fn => typeof fn !== 'function') ||
    energy && (negative || positive && !maximize) && typeof options.addDamage !== 'function')
    throw new Error('Native energy damage mitigation/attack-record providers are unavailable');
  let increase = 0, decrease = 0;
  const entries = [];
  function* apply(cost, flags, sign, generic) {
    let amount = roll(cost);
    const energyComponent = energy && indexOf(flags) > 2;
    if (energyComponent && sign === 0 && target) {
      // Native legacy generic path uses the last specific-loop flag (bit 31),
      // unless FIX_EFFECTDAMAGEINCREASE_BYPASSING_DR_AND_DI is enabled.
      const mitigationFlags = generic && !rulesetInt(rules, 'FIX_EFFECTDAMAGEINCREASE_BYPASSING_DR_AND_DI', 0) ? 0x80000000 : flags;
      const context = { simulation: Number(maximize), combat: 1, baseWeapon: 0, ranged: attack.ranged };
      amount = yield { type: 'immunity', args: [amount, mitigationFlags, context] };
      amount = yield { type: 'resistance', args: [amount, mitigationFlags, context] };
    }
    if (energyComponent && (sign === 1 || !maximize)) yield { type: 'addDamage', args: [flags, sign ? (-amount) | 0 : amount] };
    entries.push({ cost, flags, sign, generic, amount });
    if (!sign) increase = (increase + amount) | 0;
    // Generic energy penalties only update the attack record, not the return.
    else if (!energy || !generic) decrease = (decrease + amount) | 0;
  }
  for (let index = 0; index < 32; index++) for (let sign = 0; sign < 2; sign++) {
    const cost = selection.specific[sign][index];
    if (cost !== -1) yield* apply(cost, flagAt(index), sign, false);
  }
  for (let index = 0; index < 50; index++) for (let sign = 0; sign < 2; sign++) {
    const slot = selection.generic[sign][index];
    if (slot) yield* apply(slot.cost, slot.flags, sign, true);
  }
  return { increase, decrease, total: (Math.min(increase, limit) - Math.min(decrease, limit)) | 0, entries, selection };
}

export function damageEffectBonus(actor, target, rules, items, random, options) {
  const steps = bonusSteps(actor, target, rules, items, random, options);
  let next = steps.next();
  while (!next.done) {
    const { type, args } = next.value, result = options[type](...args);
    if (result?.then) throw new Error('Async damage query needs damageEffectBonusAsync');
    next = steps.next(result);
  }
  return next.value;
}

export async function damageEffectBonusAsync(actor, target, rules, items, random, options) {
  const steps = bonusSteps(actor, target, rules, items, random, options);
  let next = steps.next();
  while (!next.done) {
    const { type, args } = next.value;
    next = steps.next(await options[type](...args));
  }
  return next.value;
}

export function damageBonusEffectIntegers(cost, flags = 8, rules) {
  if (!rules?.iprp_damagecost) throw new Error('Native damage effect constructor cost rules are unavailable');
  cost |= 0; flags |= 0;
  if (cost < 1 || cost >= rowCount(rules.iprp_damagecost)) cost = 0;
  if (flags < 0 || (flags >>> 0) > highestDamageTypeFlag(rules.damagetypes?.orderedRows?.length)) flags = 8;
  return [cost, flags, 28];
}
