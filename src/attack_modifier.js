import { abilityModifier, intEntry, rulesetInt, rulesetFloat } from './combat_stats.js';
import { attackEffectBonus, equipmentCombatEffects } from './combat_modifiers.js';
import { alignmentSubject, creatureSize, sizeModifier } from './combat_context.js';
import { creatureRoot, creatureAlignment } from './creature_rules.js';
import { currentAttackWeapon, weaponRule, usesMonkAttackTables, creatureClassLevel } from './combat_weapon.js';
import { nativeDistanceSquared } from './nearest_objects.js';

const i8 = n => (n << 24) >> 24;
const has = (object, feat) => object.stats.feats.includes(feat);
const ruleBonus = (object, rules, feat, label, fallback, owns=has) => owns(object, feat) ? rulesetInt(rules, label, fallback) : 0;

export function enchantArrowBonus(object, rules) {
  for (let tier = 20; tier >= 1; tier--) if (has(object, tier <= 5 ? 444 + tier : 1039 + tier)) return rulesetInt(rules, `PRESTIGE_ENCHANT_ARROW_${tier}_BONUS`, tier);
  return 0;
}

export function favoredEnemyBonus(attacker, target, rules) {
  if (!target) return 0;
  const race = creatureRoot(target).Race;
  // LoadRaceInfo 0x1402aa660..0x1402aa79d, jump table 0x1402ac058.
  // A present FavoredEnemyFeat column replaces these native defaults, including
  // clearing a race's feat when its cell is empty/unreadable.
  const defaults = [261, 262, 263, 265, 264, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 65535, 65535, 284, 285, 286];
  const entry = intEntry(rules.racialtypes, race, 'FavoredEnemyFeat');
  const override = rules.racialtypes.columns?.some(c => c.toLowerCase() === 'favoredenemyfeat');
  const feat = override ? entry.found ? entry.value & 65535 : 65535 : defaults[race] ?? 65535;
  if (feat === 65535) return 0;
  const root = creatureRoot(attacker);
  if (!root.IsPC) return has(attacker, feat) ? Math.trunc((attacker.stats.level & 255) / 5) + 1 : 0;
  const acquired = (root.LvlStatList ?? []).find(h => h.FeatList?.some(f => f.Feat === feat));
  if (!acquired) return 0;
  const levels = root.ClassList.find(c => c.Class === acquired.LvlStatClass)?.ClassLevel;
  if (levels === undefined) return 0;
  return acquired.LvlStatClass === 32 ? (levels >> 2) + 1 : Math.trunc(levels / 5) + 1;
}

export function specialAttackBonus(attacker, target, rules, items, targetItems, attackType) {
  const rule = (key, fallback) => rulesetInt(rules, key, fallback);
  if (attackType === 39) return creatureClassLevel(attacker, 5) ? 0 : rule('STUNNING_FIST_TO_HIT_MODIFIER', -4);
  if ([9, 16].includes(attackType)) {
    const right = items.find(i => i.slot === 16), other = targetItems.find(i => i.slot === 16);
    const size = target && right && other ? rule('DISARM_WEAPON_SIZE_MODIFIER', 4) * ((weaponRule(right, rules, 'WeaponSize') & 255) - (weaponRule(other, rules, 'WeaponSize') & 255)) : 0;
    return size + rule(attackType === 9 ? 'DISARM_TO_HIT_MODIFIER' : 'IMPROVED_DISARM_TO_HIT_MODIFIER', attackType === 9 ? -6 : -4);
  }
  if ([17, 23].includes(attackType)) return target ? rule('KNOCKDOWN_TO_HIT_MODIFIER', -4) : 0;
  if (attackType === 31) return rule('SAP_TO_HIT_MODIFIER', -4);
  if ([301, 472].includes(attackType)) {
    if (!target) return 0;
    const alignment = creatureAlignment(creatureRoot(target));
    return alignment.goodEvil === (attackType === 301 ? 5 : 4) ? abilityModifier(attacker.stats.equippedAbilities.Cha, rules) : 0;
  }
  if ([65000, 65001].includes(attackType)) return rule('CALLED_SHOT_TO_HIT_MODIFIER', -4);
  if (attackType === 65002) return ruleBonus(attacker, rules, 224, 'OPPORTUNIST_TO_HIT_MODIFIER', 4);
  return 0;
}

// GetAttackModifierVersus 0x1403f5d20..0x1403f8e0c. This query consumes
// offhand/extra-attack counters, so a UI preview must use a cloned round.
export function attackModifierVersus(attacker, target, rules, items, { round, attack, targetItems = [], areaFlags = 0,
  visibility, attackerInvisible, flanking, targetMeleeReach, targetBlind=Boolean(target?.blind), targetRanged=Boolean(target?.rangeWeaponEquipped), hasFeat, limit = 20 } = {}) {
  if (!round || !attack) throw new Error('Native combat round/attack state is unavailable');
  if (target && (!visibility || typeof visibility.seen !== 'boolean' || typeof attackerInvisible !== 'boolean' || typeof flanking !== 'boolean')) throw new Error('Attack perception/flanking state is unavailable');
  const root = creatureRoot(attacker), size = creatureSize(attacker, rules), hand = attack.weaponAttackType;
  const has=(o,id)=>hasFeat?hasFeat(o,id)!==0:o.stats.feats.includes(id);
  const weapon = currentAttackWeapon(items, rules, hand), ranged = Boolean(attack.ranged), type = attack.attackType & 65535;
  const rule = (key, fallback) => rulesetInt(rules, key, fallback);
  const bonus = (feat, key, fallback) => ruleBonus(attacker, rules, feat, key, fallback,has);
  const parts = { base: attacker.stats.combat.baseAttackBonus, iteration: 0, dualWield: 0, size: sizeModifier(size, 'ATTACK', rules), mode: 0,
    special: specialAttackBonus(attacker, target, rules, items, targetItems, type), nature: 0, prowess: bonus(584, 'EPIC_PROWESS_ATTACK_BONUS', 1),
    weaponMaster: 0, bane: 0, goodAim: 0, sling: 0, arrows: 0, training: 0, ability: 0, focus: 0, epicFocus: 0, effects: 0,
    blind: 0, invisible: 0, unseen: 0, prone: 0, moving: 0, stunned: 0, flanking: 0, rangedInMelee: 0, pointBlank: 0, enemyAttack: 0 };
  const step = rule('MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER', 5);
  if (hand === 2) { parts.iteration = (-step * round.offhandTaken) | 0; round.offhandTaken++; }
  else if ([6, 8].includes(hand)) {
    if (![867, 868, 391].includes(type)) parts.iteration = (-step * round.extraTaken) | 0;
    round.extraTaken++;
  } else if (![65002, 6, 391].includes(type)) parts.iteration = (-(usesMonkAttackTables(attacker, items, rules) ? rule('MULTIPLE_ATTACKS_BAB_PENALTY_MULTIPLIER_MONK', 3) : step) * (round.currentAttack & 255)) | 0;
  const right = items.find(i => i.slot === 16), other = items.find(i => i.slot === 32) ?? (weaponRule(right, rules, 'WeaponWield') === 8 ? right : null);
  if (other && (hand === 2 || hand === 1 && weaponRule(other, rules, 'WeaponType'))) {
    parts.dualWield = rule(hand === 2 ? 'OFFHAND_NORMAL_OFFHAND_ATTACK_PENALTY' : 'ONHAND_NORMAL_OFFHAND_ATTACK_PENALTY', hand === 2 ? -10 : -6);
    const difference = i8(weaponRule(other, rules, 'WeaponSize')) - size;
    if ((difference >= -2 && difference <= 1 ? difference : -10) < 0 || weaponRule(other, rules, 'WeaponWield') === 8) parts.dualWield += rule('LIGHT_OFFHAND_WEAPON_BONUS', 2);
    if (hand === 2) parts.dualWield += bonus(1, 'AMBIDEXTERITY_BONUS', 4);
    parts.dualWield += bonus(41, 'TWO_WEAPON_FIGHTING_BONUS', 2);
  }
  const mode = { 2: ['POWER_ATTACK_TO_HIT_MODIFIER', -5], 3: ['IMPROVED_POWER_ATTACK_TO_HIT_MODIFIER', -10],
    5: ['FLURRY_OF_BLOWS_TO_HIT_MODIFIER', -2], 6: ['RAPID_SHOT_TO_HIT_MODIFIER', -2], 7: ['EXPERTISE_TO_HIT_MODIFIER', -5], 8: ['IMPROVED_EXPERTISE_TO_HIT_MODIFIER', -10] }[attacker.combatMode];
  if (mode) parts.mode = rule(...mode);
  if (areaFlags & 4 && !(areaFlags & 3)) parts.nature = bonus(198, 'NATURE_SENSE_TO_HIT_MODIFIER', 2);
  if (weapon && has(attacker, weaponRule(weapon, rules, 'WeaponOfChoiceFeat', 65535) & 65535)) {
    parts.weaponMaster = Number(has(attacker, 884));
    if (has(attacker, 1071)) parts.weaponMaster += Math.trunc((creatureClassLevel(attacker, 33) - 10) / 3);
  }
  if (target && favoredEnemyBonus(attacker, target, rules) > 0) parts.bane = bonus(855, 'EPIC_BANE_OF_ENEMIES_ATTACK_BONUS', 2);
  if (ranged && weaponRule(weapon, rules, 'WeaponWield') === 11) parts.goodAim = bonus(250, 'GOOD_AIM_MODIFIER', 1);
  if (ranged && root.Race === 3 && right?.data.BaseItem === 61) parts.sling = 1;
  if (attack.ranged === 1 && [8, 11].includes(weapon?.data.BaseItem)) parts.arrows = enchantArrowBonus(attacker, rules);
  if (target && [[232, 12], [231, 14], [242, 15]].some(([feat, race]) => has(attacker, feat) && creatureRoot(target).Race === race)) parts.training = rule('OFFENSIVE_TRAINING_MODIFIER', 1);
  const str = abilityModifier(attacker.stats.equippedAbilities.Str, rules), dex = abilityModifier(attacker.stats.equippedAbilities.Dex, rules), wis = abilityModifier(attacker.stats.equippedAbilities.Wis, rules);
  const finesse = has(attacker, 42) && (!weapon || weaponRule(weapon, rules, 'WeaponFinesseMinimumCreatureSize') > 0 && size >= weaponRule(weapon, rules, 'WeaponFinesseMinimumCreatureSize'));
  parts.ability = ranged ? has(attacker, 412) && wis > dex ? wis : dex : finesse && dex > str ? dex : str;
  parts.focus = bonus(weapon ? weaponRule(weapon, rules, 'WeaponFocusFeat', 65535) & 65535 : 100, 'WEAPON_FOCUS_BONUS', 1);
  parts.epicFocus = bonus(weapon ? weaponRule(weapon, rules, 'EpicWeaponFocusFeat', 65535) & 65535 : 630, 'EPIC_WEAPON_FOCUS_BONUS', 2);
  const effects = [...(attacker.itemCombatEffects ?? equipmentCombatEffects(items, rules, { root })).effects, ...(attacker.effects ?? [])];
  parts.effects = attackEffectBonus(effects, items, hand, { target: target ? alignmentSubject(target) : null, limit }).total;
  if (target) {
    if (!Number.isInteger(target.animationState) || !Number.isInteger(target.creatureState)) throw new Error('Attack target animation/state is unavailable');
    if (targetBlind && (ranged || !has(target, 408))) parts.blind = rule('BLIND_TARGET_BONUS', 2);
    if (attackerInvisible && (ranged || !has(target, 408))) parts.invisible = rule('INVISIBILITY_ATTACK_BONUS', 2);
    if (visibility.present === false || !visibility.seen) parts.unseen = rule('NOSIGHT_TARGET_PENALTY', -4);
    const animation = target.animationState >>> 0;
    if (animation < 37 && (0x13000000a0n >> BigInt(animation)) & 1n) parts.prone = rule(ranged ? 'PRONE_RANGED_TARGET_BONUS' : 'PRONE_MELEE_TARGET_BONUS', ranged ? -4 : 4);
    if (ranged && [4, 86, 87].includes(animation)) parts.moving = -rule('MOVING_TARGET_PENALTY', 2);
    if (target.creatureState === 6) parts.stunned = rule('STUNNED_TARGET_BONUS', 2);
    const distance = nativeDistanceSquared(attacker.position, target.position);
    const flankRange = rulesetFloat(rules, 'MAX_RANGED_FLANK_ATTACK_DISTANCE', 10);
    if (flanking && (attack.ranged !== 1 || distance <= Math.fround(flankRange * flankRange))) parts.flanking = rule('FLANK_ATTACK_BONUS', 2);
    if (ranged) {
      if (has(attacker, 27)) {
        const range = rulesetFloat(rules, 'POINT_BLANK_SHOT_MAX_RANGE', 5);
        if (distance <= Math.fround(range * range)) parts.pointBlank = rule('POINT_BLANK_SHOT_ATTACK_BONUS', 1);
      } else {
        if (!Number.isFinite(targetMeleeReach)) throw new Error('Ranged attack target melee reach is unavailable');
        if (distance <= Math.fround(targetMeleeReach * targetMeleeReach) && !targetRanged) parts.rangedInMelee = -rule('RANGED_ATTACK_IN_MELEE_RANGE', 4);
      }
    }
    parts.enemyAttack = i8(target.enemyAttackBonus ?? 0);
  }
  return { total: Object.values(parts).reduce((n, value) => (n + value) | 0, 0), parts };
}
