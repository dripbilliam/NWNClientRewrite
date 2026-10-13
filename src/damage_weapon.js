import { rulesetInt } from './combat_stats.js';
import { weaponRule, currentAttackWeapon, usesMonkAttackTables } from './combat_weapon.js';

// CNWSItem::GetDamageFlags 0x140468800..0x140468bb3. Warning descriptors
// belong in the persistent diagnostic journal when used by a session.
export function weaponDamageFlags(item, rules, temporaryProperties = []) {
  if (!item) return { flags: 1, warnings: [] }; // Creature's unarmed fallback.
  if (!rules.baseitems) throw new Error('Weapon damage base-item rules are unavailable');
  const row = rules.baseitems.orderedRows ? rules.baseitems.orderedRows[item.data.BaseItem] : rules.baseitems.rows.get(item.data.BaseItem);
  if (!row) return { flags: 0, warnings: [] };
  const type = weaponRule(item, rules, 'WeaponType') & 255;
  let flags = ({ 1: 2, 2: 1, 3: 4, 4: 6, 5: 3 })[type];
  if (flags === undefined) return { flags: 4, warnings: [{ code: 'combat.weapon-type-warning', itemId: item.id,
    baseItem: item.data.BaseItem, reason: 'Native warning: weapon has no weapon type; slashing flags returned' }] };
  const propertyType = weaponRule(item, rules, 'RangedWeapon') & 255 ? 34 : 33;
  const property = [...(item.data.PropertiesList ?? []), ...temporaryProperties].find(p => p.PropertyName === propertyType);
  if (property) flags |= ({ 0: 1, 1: 2, 2: 4 })[property.Subtype & 65535] ?? 0;
  return { flags, warnings: [] };
}

export function attackDamageFlags(items, rules, attack, { resolvedHand, temporaryProperties } = {}) {
  if (!Number.isInteger(attack?.weaponAttackType)) throw new Error('Damage weapon attack state is unavailable');
  const hand = attack.weaponAttackType || resolvedHand;
  if (!Number.isInteger(hand) || !hand) throw new Error('Current native weapon attack selection is unavailable');
  const item = currentAttackWeapon(items, rules, hand);
  return weaponDamageFlags(item, rules, temporaryProperties);
}

// GetWeaponPower 0x140396770..0x140396aa7. The target's race and simple
// alignments are queried separately; trap targets use their creator creature.
// `versus` is that resolved context, or null when native has no creature.
export function weaponPower(effects, attackHand, offhand, versus, limit) {
  if (!Number.isInteger(attackHand) || !Number.isInteger(limit)) throw new Error('Weapon power attack/limit state is unavailable');
  const hand = attackHand & 255 || (offhand ? 2 : 1);
  const context = versus ?? { race: 0xffffffff, lawChaos: 0xffffffff, goodEvil: 0xffffffff };
  if (!['race', 'lawChaos', 'goodEvil'].every(key => Number.isInteger(context[key]))) throw new Error('Weapon power target context is unavailable');
  let power = 0;
  for (const effect of effects) if (effect.type === 10) {
    const [amount, sourceHand, race, law, good] = effect.integers.map(n => n | 0);
    const matchesHand = sourceHand === hand || hand === 6 && [1, 3].includes(sourceHand) || hand === 8 && sourceHand === 7;
    if (sourceHand !== 0 && matchesHand && (race === 28 || (race >>> 0) === context.race) &&
      (!law || (law >>> 0) === context.lawChaos) && (!good || (good >>> 0) === context.goodEvil) && power < amount) power = amount;
  }
  if ([3, 4, 5].includes(hand)) for (const effect of effects) if (effect.type === 12 && power < (effect.integers[1] | 0)) power = effect.integers[1] | 0;
  // Native queries the limit only with a nonempty effect list. A negative
  // custom limit therefore changes zero only when at least one effect exists.
  return effects.length ? Math.min(power, limit | 0) : 0;
}

// CalculateDamagePower 0x140385610..0x14038606b. Enhancement beyond +6 skips
// the script's special DAMAGE_POWER_ENERGY index. Ki/arrow adjustments occur
// after that skip, before the final unsigned-byte return.
export function calculateDamagePower(actor, items, rules, attack, power) {
  if (!Number.isInteger(power) || !Number.isInteger(attack?.ranged)) throw new Error('Damage power providers are unavailable');
  power |= 0;
  if (power > 6) power = (power + 1) | 0;
  if (usesMonkAttackTables(actor, items, rules, true)) {
    for (const [feat, tier] of [[698, 5], [697, 4], [344, 3], [343, 2], [213, 1]]) if (actor.stats.feats.includes(feat)) {
      const value = rulesetInt(rules, `KI_STRIKE_LEVEL_${tier}`, tier);
      if (power < value) power = value;
      break;
    }
  }
  if (attack.ranged === 1 && [8, 11].includes(items.find(i => i.slot === 16)?.data.BaseItem)) {
    for (let tier = 20; tier > 0; tier--) {
      const value = rulesetInt(rules, `PRESTIGE_ENCHANT_ARROW_${tier}_BONUS`, tier);
      const feat = tier > 5 ? 1039 + tier : 444 + tier;
      if (power < value && actor.stats.feats.includes(feat)) { power = value; break; }
    }
  }
  return power & 255;
}
