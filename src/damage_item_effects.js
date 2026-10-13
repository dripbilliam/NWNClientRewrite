import { intEntry } from './combat_stats.js';
import { weaponRule } from './combat_weapon.js';
import { weaponDamageFlags } from './damage_weapon.js';
import { effectImmunity } from './effect_immunity.js';

export function itemVersusCondition(property) {
  const condition = { race: 28, law: 0, good: 0 }, subtype = property.Subtype & 65535;
  if ([7, 17].includes(property.PropertyName)) {
    if ([1, 2, 3].includes(subtype)) condition.law = subtype;
    else if ([4, 5].includes(subtype)) condition.good = subtype;
  } else if ([8, 18].includes(property.PropertyName)) condition.race = subtype;
  else if ([9, 19].includes(property.PropertyName) && subtype < 9) {
    condition.law = [2, 1, 3][Math.trunc(subtype / 3)];
    condition.good = [4, 1, 5][subtype % 3];
  }
  return condition;
}

// ApplyDamageBonus 0x14046ece0; ApplyEnhancementBonus 0x14046fee0;
// ApplyEnhancementPenalty 0x140470780. Equipment mutation/icon linkage are
// separate lifecycle providers. This builds the query's native integer data.
export function itemDamageEffects(item, property, rules, { root, effects = [] } = {}) {
  const type = property.PropertyName;
  if (![6, 7, 8, 9, 10, 16, 17, 18, 19, 21].includes(type)) return { effects: [], warnings: [] };
  if ([16, 17, 18, 19].includes(type) && item.data.BaseItem < 28 && (0x0a100000 >>> item.data.BaseItem & 1))
    return { effects: [], warnings: [] }; // Ammunition is handled by the query.
  const decrease = [10, 21].includes(type);
  let cost = property.CostValue & 65535, amount = cost, flags;
  const warnings = [];
  if ([6, 7, 8, 9, 10, 21].includes(type)) {
    const table = rules.itemCosts?.get(decrease ? 20 : 2);
    if (!table) throw new Error('Native enhancement cost rules are unavailable');
    amount = intEntry(table, cost, 'Value').value;
    if (decrease) amount = (-amount) | 0;
    if (!amount) return { effects: [], warnings: [] };
    cost = amount;
    // Bonus values above +5 search the active damage cost table for a fixed
    // matching amount. Penalties keep their native direct cost index.
    if (!decrease && amount > 5 && rules.iprp_damagecost) {
      const table = rules.iprp_damagecost, count = table.orderedRows?.length ?? table.rows.size;
      for (let i = 0; i < count; i++) if (intEntry(table, i, 'NumDice').value === 0 && intEntry(table, i, 'Die').value === amount) { cost = i; break; }
    }
    const damage = weaponDamageFlags(item, rules, item.temporaryProperties);
    flags = damage.flags; warnings.push(...damage.warnings.map(w => w.reason));
  } else {
    if (!cost) return { effects: [], warnings: [] };
    let index = type === 16 ? property.Subtype & 65535 : (property.Param1Value ?? 0) & 255;
    if (index > 2) index -= 2;
    flags = (1 << (index & 31)) >>> 0;
  }
  const hand = ({ 16: 1, 32: 2, 16384: 3, 32768: 4, 65536: 5, 8: 7 })[item.slot];
  if (hand === undefined) warnings.push('Native warning: damage property on an invalid equipment slot');
  // Enhancement penalties warn and retain a generic hand; increases discard.
  if (hand === undefined && !decrease) return { effects: [], warnings };
  if (decrease) {
    if (!root) throw new Error('Damage decrease item property needs creature immunity context');
    if (effectImmunity(root, effects, 21)) return { effects: [], warnings };
  }
  const { race, law, good } = itemVersusCondition(property);
  const effect = { type: decrease ? 14 : 13, integers: [cost, flags | 0, race, law, good, hand ?? 0],
    creatorId: item.id, sourceItemId: item.id ?? item.source, spellId: -1, durationType: 3 };
  // Native double weapons apply an offhand copy before the original record.
  return { effects: weaponRule(item, rules, 'WeaponWield') === 8
    ? [{ ...effect, integers: [...effect.integers.slice(0, 5), 2] }, effect] : [effect], warnings };
}
