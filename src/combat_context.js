import { rulesetInt, intEntry } from './combat_stats.js';
import { equipmentCombatEffects, itemArmorClass } from './combat_modifiers.js';
import { OBJECT_INVALID } from './game_object_array.js';
import { creatureRoot as source, creatureAlignment } from './creature_rules.js';

const i8 = n => (n << 24) >> 24;
const i16 = n => (n << 16) >> 16;
const has = (object, feat) => object.stats.feats.includes(feat);

export function alignmentSubject(object) {
  return creatureAlignment(source(object));
}

export function creatureSize(object, rules) {
  const entry = intEntry(rules.appearance, source(object).Appearance_Type, 'SIZECATEGORY');
  if (!entry.found) throw new Error('Creature size rules are unavailable');
  return entry.value;
}

export function sizeModifier(size, kind, rules) {
  const contract = { 1: [`CREATURE_SIZE_TINY_${kind}_BONUS`, 2], 2: [`CREATURE_SIZE_SMALL_${kind}_BONUS`, 1],
    4: [`CREATURE_SIZE_LARGE_${kind}_PENALTY`, -1], 5: [`CREATURE_SIZE_HUGE_${kind}_PENALTY`, -2] }[size];
  return contract ? rulesetInt(rules, ...contract) : 0;
}

// CNWSCreatureStats::GetArmorClassVersus 0x1403f47f0..0x1403f5d16.
// Visibility/flat-footed/invisibility are explicit inputs from the world state;
// missing perception must not silently make every creature see every attacker.
export function armorClassVersus(defender, attacker, rules, items, { touch = false, ranged = false,
  attackType = 0, damageFlags = 4103, flatFooted, visibility = null, attackerInvisible = false,hasFeat } = {}) {
  if (typeof flatFooted !== 'boolean') throw new Error('Combat flat-footed state is unavailable');
  if (attacker && (!visibility || typeof visibility.seen !== 'boolean')) throw new Error('Combat visibility state is unavailable');
  const root = source(defender), ac = defender.stats.combat.finalBreakdown.armor;
  const has=(o,id)=>hasFeat?hasFeat(o,id)!==0:o.stats.feats.includes(id);
  const rule = (name, fallback) => rulesetInt(rules, name, fallback);
  const chest = items.find(i => i.slot === 2), shield = items.find(i => i.slot === 32);
  const natural = ac.natural;
  const naturalBase = touch ? i8(natural.monkWisdom + natural.monkLevels) : i8(natural.authored + natural.classGains.reduce((a, b) => a + b, 0) + natural.dwarvenDefender + natural.armorSkin + natural.monkWisdom + natural.monkLevels);
  const parts = { base: 10, size: sizeModifier(creatureSize(defender, rules), 'AC', rules), naturalBase,
    armorBase: touch ? 0 : i8(itemArmorClass(chest, rules)), shieldBase: touch ? 0 : i8(itemArmorClass(shield, rules)),
    dexterity: 0, dodge: 0, tumble: 0, dodgeFeat: 0, mobility: 0, defensiveTraining: 0, mode: 0, conditionalDodge: 0, categoryEffects: 0 };
  const { up, down } = defender.acCache ?? ac.cache;
  const blindFight = has(defender, 408), dex = ac.components.dexterity;
  if (flatFooted || attacker && attackerInvisible && !blindFight) parts.dexterity = flatFooted ? Math.min(0, dex) : 0;
  else if (attacker && visibility.present !== false && (visibility.seen || blindFight && !ranged)) {
    parts.dexterity = dex;
    parts.dodge = i8(Math.min(up[0] - down[0], rule('MAX_AC_DODGE_MOD', 20)));
    if (attackType === 65002 && has(defender, 26)) parts.mobility = rule('MOBILITY_DODGE_BONUS', 4);
    if (has(defender, 10)) {
      defender.combatRound ??= {};
      if (defender.combatRound.dodgeTargetId === undefined || defender.combatRound.dodgeTargetId === OBJECT_INVALID) defender.combatRound.dodgeTargetId = attacker.id;
      if (defender.combatRound.dodgeTargetId === attacker.id) parts.dodgeFeat = ac.monkAbilities
        ? has(defender, 1031) ? rule('SHOU_DISCIPLE_DODGE_AC_BONUS_3', 3)
          : has(defender, 489) ? rule('SHOU_DISCIPLE_DODGE_AC_BONUS_2', 2) : rule('DODGE_AC_BONUS', 1)
        : rule('DODGE_AC_BONUS', 1);
    }
    const rank = Math.min(127, Math.max(-127, i8(root.SkillList?.[21]?.Rank ?? 0)));
    if (rank > 0) {
      const divisor = rule('TUMBLE_NUM_RANKS_PER_AC_BONUS', 5);
      if (!divisor) throw new Error('Tumble AC rules cause a native integer division fault');
      parts.tumble = Math.trunc(rank / divisor) & 255;
    }
  }
  if ((has(defender, 195) || has(defender, 949)) && dex > 0) parts.dexterity = dex;
  if (attacker && has(defender, 233) && source(attacker).Race === 18) parts.defensiveTraining = rule('DEFENSIVE_TRAINING_MODIFIER', 4);
  parts.mode = defender.combatMode === 7 ? rule('EXPERTISE_AC_BONUS', 5) : defender.combatMode === 8 ? rule('IMPROVED_EXPERTISE_AC_BONUS', 10) : 0;
  const positive = [...up], negative = [...down];
  if (touch) for (const index of [1, 2, 3]) positive[index] = negative[index] = 0;
  if (attacker) {
    const subject = alignmentSubject(attacker);
    const effects = [...(defender.itemCombatEffects ?? equipmentCombatEffects(items, rules, { root })).effects, ...(defender.effects ?? [])];
    for (const effect of effects) {
      if (![48, 49].includes(effect.type)) continue;
      const [category, amount, race, law, good, damage] = effect.integers;
      if (race === 28 && !law && !good && damage === 4103) continue;
      if (race !== 28 && race !== subject.race || law && law !== subject.lawChaos || good && good !== subject.goodEvil || damage !== 4103 && !(damageFlags & damage)) continue;
      if (!category) parts.conditionalDodge += effect.type === 48 ? amount : -amount;
      else if (effect.type === 48 && (category === 4 || !touch)) positive[category] = Math.max(positive[category], amount);
      else if (effect.type === 49 && !touch) {
        if (category <= 3) negative[category] = Math.max(negative[category], amount);
        // Target assembly 0x1403f5950..0x1403f5960 tests SHIELD category
        // again for conditional deflection penalties. Preserve this quirk.
        if (category === 3) negative[4] = Math.max(negative[4], amount);
      }
    }
  }
  parts.categoryEffects = positive[4] - negative[4];
  if (!touch) for (const category of [1, 2, 3]) parts.categoryEffects += positive[category] - negative[category];
  return { total: i16(Object.values(parts).reduce((a, b) => a + b, 0)), parts };
}
