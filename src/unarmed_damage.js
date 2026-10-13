import { rulesetInt } from './combat_stats.js';
import { creatureClassLevel } from './combat_weapon.js';
import { creatureSize } from './combat_context.js';

// GetUnarmedDamageDice 0x14040aa70..0x14040ad5d and GetUnarmedDamageDie
// 0x14040ad60..0x14040b3da. Preserve native size/Shou branches, the spelling
// THRESHHOLD, and the separate SDAMAGE keys used for small creatures.
export function unarmedDamageProfile(actor, rules) {
  const rule = (name, value) => rulesetInt(rules, name, value);
  const small = creatureSize(actor, rules) < 3;
  const monkAbilities = actor.stats.combat.finalBreakdown.armor.monkAbilities;
  const monk = monkAbilities ? creatureClassLevel(actor, 5) & 255 : 0;
  const shou = monkAbilities ? creatureClassLevel(actor, 40) & 255 : 0;
  const combined = monk + shou;
  const fourth = () => rule('MONK_DAMAGE_TIER_FOUR_THRESHHOLD', 16);
  let dice = 0, die = 0, shouDice = 0, shouDie = 0;
  if (!monkAbilities) {
    dice = rule('UNARMED_DAMAGE_DICE', 1);
    die = rule(small ? 'UNARMED_SDAMAGE_DIE' : 'UNARMED_DAMAGE_DIE', small ? 2 : 3);
  } else {
    if (small) dice = combined < fourth() ? rule('MONK_DAMAGE_TIER_THREE_SDAMAGE_DICE', 1) : rule('MONK_DAMAGE_TIER_FOUR_SDAMAGE_DICE', 2);
    else dice = rule('MONK_DAMAGE_TIER_DICE', 1);
    if (shou && (small || combined < fourth())) shouDice = small || shou < rule('SHOU_DISCIPLE_DAMAGE_TIER_THREE_THRESHHOLD', 5)
      ? rule('SHOU_DISCIPLE_DAMAGE_TIER_ONE_DICE', 1) : rule('SHOU_DISCIPLE_DAMAGE_TIER_TWO_DICE', 2);
    const thresholds = [rule('MONK_DAMAGE_TIER_ONE_THRESHHOLD', 4), rule('MONK_DAMAGE_TIER_TWO_THRESHHOLD', 8), rule('MONK_DAMAGE_TIER_THREE_THRESHHOLD', 12), fourth()];
    let tier = thresholds.findIndex(threshold => combined < threshold);
    if (tier < 0) tier = 4;
    const tiers = ['ZERO', 'ONE', 'TWO', 'THREE', 'FOUR'];
    die = rule(`MONK_DAMAGE_TIER_${tiers[tier]}_${small ? 'S' : ''}DAMAGE_DIE`, (small ? [4, 6, 8, 10, 6] : [6, 8, 10, 12, 20])[tier]);
    if (shou) {
      const first = rule('SHOU_DISCIPLE_DAMAGE_TIER_ONE_THRESHHOLD', 2), second = rule('SHOU_DISCIPLE_DAMAGE_TIER_TWO_THRESHHOLD', 3);
      const third = rule('SHOU_DISCIPLE_DAMAGE_TIER_THREE_THRESHHOLD', 5);
      const shouTier = shou < first ? 0 : shou < second ? 1 : shou < third ? 2 : 3;
      if (!small || shouTier < 2 || combined < fourth()) shouDie = rule(`SHOU_DISCIPLE_DAMAGE_TIER_${tiers[shouTier]}_${small ? 'S' : ''}DAMAGE_DIE`, (small ? [4, 6, 8, 10] : [6, 8, 10, 6])[shouTier]);
    }
  }
  // At the third Shou tier and below combined Monk tier four the native code
  // forces Shou's die even when the Monk die is larger. Dice remain separate.
  if (die < shouDie || shou >= rule('SHOU_DISCIPLE_DAMAGE_TIER_THREE_THRESHHOLD', 5) && combined < fourth()) die = shouDie;
  return { dice: Math.max(dice, shouDice) & 255, sides: die & 255 };
}
