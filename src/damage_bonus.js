import { abilityModifier, rulesetInt, rulesetFloat } from './combat_stats.js';
import { creatureRoot } from './creature_rules.js';
import { creatureSize } from './combat_context.js';
import { creatureClassLevel, currentAttackWeapon, weaponRule } from './combat_weapon.js';
import { enchantArrowBonus, favoredEnemyBonus } from './attack_modifier.js';
import { nativeDistanceSquared } from './nearest_objects.js';
import {mightyStrengthBonus,scaledStrengthBonus} from './nominal_damage_bonus.js';

const has = (actor, feat) => actor.stats.feats.includes(feat);
const f32 = Math.fround;

// ResolveSpecialAttackDamageBonus 0x140413030..0x140413648.
export function specialAttackDamageBonus(actor, target, rules, attackType) {
  const root = creatureRoot(actor);
  if (attackType === 39) return root.ClassList.some(c => c.Class === 5) ? 0 : rulesetInt(rules, 'STUNNING_FIST_DAMAGE_MODIFIER', -4);
  if (![301, 472].includes(attackType) || !target) return 0;
  const alignment = creatureRoot(target).GoodEvil;
  if (!Number.isInteger(alignment)) throw new Error('Smite damage target alignment is unavailable');
  if (attackType === 301 ? alignment > 30 : alignment < 70) return 0;
  if (attackType === 472 && !root.ClassList.some(c => c.Class === 31)) return 0;
  let multiplier = 1;
  for (let tier = 10; tier >= 1; tier--) if (has(actor, 823 + tier)) {
    multiplier = rulesetInt(rules, `EPIC_GREAT_SMITING_${tier}`, tier + 1); break;
  }
  const levels = attackType === 301 ? creatureClassLevel(actor, 6) + creatureClassLevel(actor, 32) : creatureClassLevel(actor, 31);
  return Math.imul(levels, multiplier);
}

// GetDamageBonus 0x1403fd4b0..0x1403fee1a. The bonus is calculated once;
// GetDamageRoll adds it repeatedly on a critical. Random bonuses must not be
// rerolled for each critical multiplier.
export function damageBonus(actor, target, rules, items, random, { attack, offhand = false, selectHand }) {
  if (!attack || !['weaponAttackType', 'ranged', 'attackType'].every(field => Number.isInteger(attack[field]))) throw new Error('Damage attack state is unavailable');
  const right = items.find(i => i.slot === 16), weapon = currentAttackWeapon(items, rules, attack.weaponAttackType,selectHand);
  const str = abilityModifier(actor.stats.equippedAbilities.Str, rules);
  const ranged = attack.ranged !== 0;
  const parts = { strength: 0, pointBlank: 0, arrows: 0, favoredEnemy: 0, bane: 0, mode: 0, dirtyFighting: 0, specialization: 0, epicSpecialization: 0, special: 0 };
  if (offhand) parts.strength = str > 0 ? scaledStrengthBonus(str,rulesetFloat(rules, 'OFFHAND_WEAPON_STRENGTH_MODIFIER', 0.5)) : str;
  else if (right && !ranged && (weaponRule(right, rules, 'WeaponSize') & 255) - creatureSize(actor, rules) === 1 && weaponRule(right, rules, 'WeaponWield') !== 8) {
    parts.strength = str > 0 ? scaledStrengthBonus(str,rulesetFloat(rules, 'TWO_HANDED_WEAPON_STRENGTH_MODIFIER', 1.5)) : str;
  } else {
    if (!right || weaponRule(right, rules, 'WeaponWield') === 11 && right.data.BaseItem !== 59 || !ranged) parts.strength = str;
    else if (attack.ranged === 1) {
      if (![6, 7, 59].includes(right.data.BaseItem) && str < 0) parts.strength = str;
      const mighty = right.data.PropertiesList?.find(p => p.PropertyName === 45);
      if (mighty) parts.strength = mightyStrengthBonus(str,mighty.CostValue);
    }
  }
  if (ranged && has(actor, 27) && target) {
    const range = rulesetFloat(rules, 'POINT_BLANK_SHOT_MAX_RANGE', 5);
    if (nativeDistanceSquared(actor.position, target.position) <= f32(range * range)) parts.pointBlank = rulesetInt(rules, 'POINT_BLANK_SHOT_DAMAGE_BONUS', 1);
  }
  if (ranged && [8, 11].includes(weapon?.data.BaseItem)) parts.arrows = enchantArrowBonus(actor, rules);
  parts.favoredEnemy = favoredEnemyBonus(actor, target, rules);
  if (parts.favoredEnemy > 0 && has(actor, 855)) parts.bane = random.dice(rulesetInt(rules, 'EPIC_BANE_OF_ENEMIES_DAMAGE_DICE', 2), rulesetInt(rules, 'EPIC_BANE_OF_ENEMIES_DAMAGE_DIE', 6));
  if (actor.combatMode === 2) parts.mode = rulesetInt(rules, 'POWER_ATTACK_DAMAGE_MODIFIER', 5);
  if (actor.combatMode === 3) parts.mode = rulesetInt(rules, 'IMPROVED_POWER_ATTACK_DAMAGE_MODIFIER', 10);
  if (actor.combatMode === 10) parts.dirtyFighting = random.dice(1, rulesetInt(rules, 'DIRTY_FIGHTING_BONUS_DICE', 4));
  if (has(actor, weaponRule(weapon, rules, 'WeaponSpecializationFeat', weapon ? 65535 : 138) & 65535)) parts.specialization = rulesetInt(rules, 'WEAPON_SPECIALIZATION_BONUS', 2);
  if (has(actor, weaponRule(weapon, rules, 'EpicWeaponSpecializationFeat', weapon ? 65535 : 668) & 65535)) parts.epicSpecialization = rulesetInt(rules, 'EPIC_WEAPON_SPECIALIZATION_BONUS', 4);
  parts.special = specialAttackDamageBonus(actor, target, rules, attack.attackType & 65535);
  return { total: Object.values(parts).reduce((total, value) => (total + value) | 0, 0), parts };
}
