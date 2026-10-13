import { abilityModifier, intEntry, rulesetInt } from './combat_stats.js';
import { getGffStructType } from './gff.js';
import { effectImmunity } from './effect_immunity.js';
import { itemDamageEffects, itemVersusCondition } from './damage_item_effects.js';

const i8 = n => (n << 24) >> 24;
const i16 = n => (n << 16) >> 16;
const rowAt = (table, index) => table?.orderedRows ? table.orderedRows[index] : table?.rows.get(index);
const field = (row, name) => row?.[Object.keys(row).find(k => k.toLowerCase() === name.toLowerCase())];
const num = (row, name, fallback = 0) => {
  const value = field(row, name);
  return value === undefined || value === '' || value === '****' ? fallback : Number(value);
};
const featSet = (root, pending) => new Set([...(root.FeatList ?? []).map(f => f.Feat), ...pending]);
const classLevel = (root, id) => root.ClassList.find(c => c.Class === id)?.ClassLevel ?? 0;
const sum = values => values.reduce((n, v) => (n + v) | 0, 0);
const divide = (value, divisor) => {
  if (!divisor || (value === -2147483648 && divisor === -1)) throw new Error('Combat rules cause a native integer division fault');
  return Math.trunc(value / divisor);
};

export const equipmentRecords = root => (root.Equip_ItemList ?? []).map((data, index) => ({ data, slot: getGffStructType(data), source: `equipped:${index}` }));

function baseItem(item, rules) {
  if (!item) return null;
  const row = rowAt(rules.baseitems, item.data.BaseItem);
  if (!row) throw new Error(`Combat base item ${item.data.BaseItem} rules are unavailable`);
  return row;
}

export function itemArmorClass(item, rules) {
  if (!item) return 0;
  const base = baseItem(item, rules);
  if (num(base, 'ModelType') === 3) {
    if (!rules.parts_chest) throw new Error('Combat parts_chest rules are unavailable');
    const value = field(rowAt(rules.parts_chest, (item.data.ArmorPart_Torso ?? 0) & 65535), 'ACBonus');
    // ComputeArmorClass reads a float, floorf then ceilf when fraction >= .5.
    const parsed = value === undefined ? Number(rules.parts_chest.defaultValue) : parseFloat(value);
    const f = Number.isFinite(parsed) ? Math.fround(parsed) : 0;
    return Math.trunc(f - Math.floor(f) >= 0.5 ? Math.ceil(f) : Math.floor(f));
  }
  return [14, 56, 57].includes(item.data.BaseItem) ? num(base, 'BaseAC') & 255 : 0;
}

export function cappedDexterityModifier(modifier, chest, rules) {
  const armor = itemArmorClass(chest, rules);
  if (armor <= 0) return modifier;
  if (!rules.armor) throw new Error('Combat armor rules are unavailable');
  const maximum = intEntry(rules.armor, armor, 'dexbonus').value;
  // Native tests the int before narrowing it to signed char; zero is uncapped.
  return maximum > 0 ? Math.min(modifier, i8(maximum)) : modifier;
}

function propertyValue(rules, cost, prop) {
  const table = rules.itemCosts?.get(cost);
  if (!table) throw new Error(`Combat item property cost table ${cost} is unavailable`);
  return intEntry(table, prop.CostValue & 65535, 'Value').value;
}

// Project equipped properties into the native effect integer layouts. Source
// identity is a canonical item ID in sessions, never a saved BIC ObjectId.
export function equipmentCombatEffects(items, rules, { root = null, initialEffects = [] } = {}) {
  const effects = [], unsupported = [];
  let haste = false;
  for (const item of items) {
    const base = baseItem(item, rules);
    for (const [index, prop] of (item.data.PropertiesList ?? []).entries()) {
      const type = prop.PropertyName, sourceItemId = item.id ?? item.source;
      if (type === 1) {
        const amount = propertyValue(rules, 2, prop);
        if (amount > 0) effects.push({ type: 48, integers: [num(base, 'AC_Enchant') & 255, amount, 28, 0, 0, 4103], sourceItemId });
      } else if ([40, 41, 49, 50].includes(type)) {
        const value = propertyValue(rules, [40, 41].includes(type) ? 1 : 20, prop);
        if (!value) continue;
        if (value < 0) {
          if (!root) throw new Error('Saving throw decrease item property needs creature immunity provider context');
          if (effectImmunity(root, [...initialEffects, ...effects], 25)) continue;
        }
        let save = 0, saveType = 0;
        if ([41, 50].includes(type)) save = ({ 1: 1, 2: 3, 3: 2 })[prop.Subtype] ?? 0;
        else {
          const mapped = rules.iprp_saveelement ? intEntry(rules.iprp_saveelement, prop.Subtype & 65535, 'SavingThrowType') : { found: false };
          saveType = mapped.found ? mapped.value : ({ 0: 0, 1: 6, 3: 12, 4: 11, 5: 3, 6: 13, 7: 8, 8: 4, 9: 7, 11: 1, 12: 10, 13: 2, 14: 9, 15: 5, 16: 14, 17: 15, 18: 18, 19: 19, 20: 16, 21: 17 })[prop.Subtype] ?? 0;
        }
        effects.push({ type: value < 0 ? 27 : 26, integers: [Math.abs(value), save, saveType, 28, 0, 0], sourceItemId });
      } else if (type === 37) {
        const types = ({ 0: [30], 1: [29, 19], 2: [1], 3: [2], 4: [3], 5: [4], 6: [28], 7: [6], 8: [31], 9: [32] })[prop.Subtype] ?? [];
        for (const immunity of types) effects.push({ type: 22, integers: [immunity, 28, 0, 0], sourceItemId });
      } else if (type === 35) {
        if (!haste) {
          const amount = rulesetInt(rules, 'HASTE_DODGE_AC_INCREASE_AMOUNT', 4);
          if (amount > 0) effects.push({ type: 48, integers: [0, amount, 28, 0, 0, 4103], sourceItemId });
          haste = true;
        }
        unsupported.push({ itemId: item.id, slot: item.slot, propertyIndex: index, propertyName: type, reason: 'Haste AC contribution is applied; movement, extra attacks and effect feedback remain unimplemented' });
      } else if ([6, 7, 8, 9, 56, 10].includes(type)) {
        const value = propertyValue(rules, type === 10 ? 20 : 2, prop);
        const amount = type === 10 ? (-value) | 0 : value;
        let attackBlocked = false;
        if (type === 10 && amount > 0) {
          if (!root) throw new Error('Attack decrease item property needs creature immunity provider context');
          attackBlocked = effectImmunity(root, [...initialEffects, ...effects], 20);
        }
        const slotHand = ({ 16: 1, 32: 2, 16384: 3, 32768: 4, 65536: 5, 8: 8 })[item.slot];
        // ApplyAttackPenalty warns but continues with hand 0; ApplyAttackBonus
        // warns and destroys the effect. Keep those native branches distinct.
        const hand = slotHand ?? (type === 10 ? 0 : undefined);
        if (!attackBlocked && amount > 0 && hand !== undefined) {
          const { race, law, good } = itemVersusCondition(prop);
          effects.push({ type: type === 10 ? 11 : 10, integers: [amount, hand, race, law, good], sourceItemId });
          if (num(base, 'WeaponWield') === 8) effects.push({ type: type === 10 ? 11 : 10, integers: [amount, 2, race, law, good], sourceItemId });
          if (slotHand === undefined) unsupported.push({ itemId: item.id, slot: item.slot, propertyIndex: index, propertyName: type, reason: 'Native warning: attack property on an invalid equipment slot; generic attack effect applied' });
        } else if (!attackBlocked && amount > 0) unsupported.push({ itemId: item.id, slot: item.slot, propertyIndex: index, propertyName: type, reason: 'Attack bonus on an invalid equipment slot is discarded' });
        if (type !== 56) {
          const projection = itemDamageEffects(item, prop, rules, { root, effects: [...initialEffects, ...effects] });
          effects.push(...projection.effects);
          for (const reason of projection.warnings) unsupported.push({ itemId: item.id, slot: item.slot, propertyIndex: index, propertyName: type, reason });
        }
      } else if ([16, 17, 18, 19, 21].includes(type)) {
        const projection = itemDamageEffects(item, prop, rules, { root, effects: [...initialEffects, ...effects] });
        effects.push(...projection.effects);
        for (const reason of projection.warnings) unsupported.push({ itemId: item.id, slot: item.slot, propertyIndex: index, propertyName: type, reason });
      } else if (![0, 27, 13].includes(type)) {
        unsupported.push({ itemId: item.id, slot: item.slot, propertyIndex: index, propertyName: type, reason: 'Item property execution is not implemented' });
      }
    }
  }
  return { effects, unsupported };
}

// GetTotalEffectBonus has fifty source slots per sign. Effects from one spell
// keep the strongest value; unsourced spell -1 receives a fresh slot each time.
function sourceTotal(effects, items, itemSources = false) {
  const slots = [];
  for (const effect of effects) {
    const amount = effect.integers[0] | 0;
    const itemSource = itemSources ? effect.sourceItemId ?? (items.some(i => i.id !== undefined && i.id === effect.creatorId) ? effect.creatorId : undefined) : undefined;
    const spell = effect.spellId ?? -1;
    const key = itemSource === undefined ? spell === -1 ? Symbol() : `spell:${spell}` : `item:${itemSource}`;
    const existing = slots.find(slot => slot.key === key);
    if (existing) existing.amount = Math.max(existing.amount, amount);
    else if (slots.length < 50) slots.push({ key, amount });
  }
  return sum(slots.map(s => s.amount));
}

function matchesSubject(integers, raceIndex, target = null) {
  return (integers[raceIndex] === 28 || integers[raceIndex] === (target?.race??-1)) &&
    (!integers[raceIndex + 1] || integers[raceIndex + 1] === (target?.lawChaos??-1)) &&
    (!integers[raceIndex + 2] || integers[raceIndex + 2] === (target?.goodEvil??-1));
}

// GetTotalEffectBonus category 5, 0x140395d23..0x140396237. Skill
// effect layouts differ from attack/save layouts: skill at 0, amount at 1.
export function skillEffectBonus(effects,items,skill,{target=null,limit=50}={}) {
  const qualifying=effects.filter(e=>[55,56].includes(e.type)&&(e.integers[0]===255||e.integers[0]===(skill&255))&&matchesSubject(e.integers,2,target));
  // Native apply handlers admit zero, but reject negative skill magnitudes.
  // Do not let unsupported imported negative records occupy sentinel slots.
  for(const e of qualifying)if(!Number.isInteger(e.integers[1])||e.integers[1]<0)throw new Error('Native skill effect magnitude is unavailable');
  const project=e=>({...e,integers:[e.integers[1]]});
  const increase=Math.min(limit,sourceTotal(qualifying.filter(e=>e.type===55).map(project),items,true));
  const decrease=Math.min(limit,sourceTotal(qualifying.filter(e=>e.type===56).map(project),items,true));
  return{increase,decrease,total:(increase-decrease)|0};
}

export function savingThrowEffectBonus(root, effects, items, save, { saveType = 0, target = null, limit = 20, pendingFeats = [] } = {}) {
  const filtered = effects.filter(e => [26, 27].includes(e.type) && (!e.integers[1] || e.integers[1] === save) &&
    (!e.integers[2] || e.integers[2] === saveType) && matchesSubject(e.integers, 3, target));
  const increase = Math.min(limit, sourceTotal(filtered.filter(e => e.type === 26), items, true));
  const decrease = Math.min(limit, sourceTotal(filtered.filter(e => e.type === 27), items, true));
  // Sacred Defense is added AFTER the bonus cap, to every save query.
  const sacredDefense = featSet(root, pendingFeats).has(904) && classLevel(root, 32) > 1 ? Math.trunc(classLevel(root, 32) / 2) : 0;
  return { increase, decrease, sacredDefense, total: (increase + sacredDefense - decrease) | 0 };
}

export function attackEffectBonus(effects, items, hand, { touch = false, limit = 20, target = null } = {}) {
  const generic = [], specificUp = [], specificDown = [];
  for (const e of effects) {
    if (![10, 11].includes(e.type) || !matchesSubject(e.integers, 2, target)) continue;
    const attack = e.integers[1];
    if (!attack) generic.push(e);
    else if (attack === hand || (hand === 6 && [1, 3].includes(attack)) || (hand === 8 && attack === 7)) {
      (e.type === 10 ? specificUp : specificDown).push(e.integers[0]);
    }
  }
  const increase = (sourceTotal(generic.filter(e => e.type === 10), items) + (touch ? 0 : Math.max(0, ...specificUp))) | 0;
  const decrease = (sourceTotal(generic.filter(e => e.type === 11), items) + Math.max(0, ...specificDown)) | 0;
  return { increase: Math.min(limit, increase), decrease: Math.min(limit, decrease), total: Math.min(limit, increase) - Math.min(limit, decrease) };
}

export function armorEffectCache(effects) {
  const up = [0, 0, 0, 0, 0], down = [...up];
  for (const e of effects) {
    if (![48, 49].includes(e.type)) continue;
    const [category, amount, race, law, good, damage] = e.integers;
    if (race !== 28 || law || good || damage !== 4103 || category < 0 || category > 4) continue;
    const list = e.type === 48 ? up : down;
    if (!category) list[0] = i8(list[0] + amount);
    else if (list[category] < amount) list[category] = i8(amount);
  }
  return { up, down };
}

export function armorClass(root, rules, modifiers, items, effects, { pendingFeats = [], acCache } = {}) {
  const feats = featSet(root, pendingFeats), chest = items.find(i => i.slot === 2), left = items.find(i => i.slot === 32);
  const computedArmor = itemArmorClass(chest, rules), armorBase = i8(computedArmor), shieldBase = i8(itemArmorClass(left, rules));
  const monk = classLevel(root, 5), shou = classLevel(root, 40);
  const monkAbilities = Boolean((monk || shou) && computedArmor < 4 && (computedArmor < 1 || shou) && ![14, 56, 57].includes(left?.data.BaseItem));
  const monkWisdom = monkAbilities && feats.has(260) ? Math.max(0, modifiers.Wis) : 0;
  const monkLevels = monkAbilities ? Math.trunc(monk / 5) : 0;
  const dwarvenDefender = Math.trunc(classLevel(root, 39) / 3);
  const armorSkin = feats.has(490) ? rulesetInt(rules, 'EPIC_ARMOR_SKIN_NATURAL_AC_BONUS', 2) : 0;
  const classGains = root.ClassList.map(c => {
    const row = rowAt(rules.classes, c.Class), name = field(row, 'StatGainTable');
    const table = rules.classTables.get(String(name).toLowerCase());
    if (!table) return 0;
    if (c.ClassLevel > 60) throw new Error('Native natural AC gain beyond the 60-entry class table is not supported');
    return i8(sum(Array.from({ length: c.ClassLevel }, (_, index) => intEntry(table, index, 'NaturalAC').value)));
  });
  const naturalBase = i8(i8(root.NaturalAC ?? 0) + sum(classGains) + dwarvenDefender + armorSkin + monkWisdom + monkLevels);
  const dexterity = cappedDexterityModifier(modifiers.Dex, chest, rules);
  const ranks = Math.min(127, Math.max(-127, i8(root.SkillList?.[21]?.Rank ?? 0)));
  const tumble = ranks > 0 ? i8(divide(ranks, rulesetInt(rules, 'TUMBLE_NUM_RANKS_PER_AC_BONUS', 5))) : 0;
  const cache = acCache ?? armorEffectCache(effects), { up, down } = cache;
  const dodge = i8(Math.min(up[0] - down[0], rulesetInt(rules, 'MAX_AC_DODGE_MOD', 20)));
  const components = { armor: i8(armorBase + up[2] - down[2]), shield: i8(shieldBase + up[3] - down[3]),
    deflection: i8(up[4] - down[4]), natural: i8(naturalBase + up[1] - down[1]), dodge, tumble, dexterity };
  // CNWSCreature::GetArmorClass / NWScript GetAC: no size, mode or opponent.
  return { total: i16(10 + sum(Object.values(components))), components, cache,
    natural: { authored: i8(root.NaturalAC ?? 0), classGains, dwarvenDefender, armorSkin, monkWisdom, monkLevels }, monkAbilities };
}

export function attackBonuses(root, rules, modifiers, items, effects, base, { pendingFeats = [], areaFlags = 0, size, touch = false, includeBase = true, limit = 20 } = {}) {
  const feats = featSet(root, pendingFeats);
  const constant = (id, label, fallback) => feats.has(id) ? rulesetInt(rules, label, fallback) : 0;
  const right = items.find(i => i.slot === 16), left = items.find(i => i.slot === 32);
  const weaponFocus = item => constant(item ? num(baseItem(item, rules), 'WeaponFocusFeat', 65535) & 65535 : 100, 'WEAPON_FOCUS_BONUS', 1);
  const epicFocus = item => constant(item ? num(baseItem(item, rules), 'EpicWeaponFocusFeat', 65535) & 65535 : 630, 'EPIC_WEAPON_FOCUS_BONUS', 2);
  const melee = offhand => {
    const double = right && num(baseItem(right, rules), 'WeaponWield') === 8;
    const item = offhand ? left ?? (double ? right : null) : right;
    const row = baseItem(item, rules);
    const finesse = feats.has(42) && (!item || (num(row, 'WeaponFinesseMinimumCreatureSize') > 0 && size >= num(row, 'WeaponFinesseMinimumCreatureSize')));
    const ability = !touch && finesse && modifiers.Dex > modifiers.Str ? modifiers.Dex : modifiers.Str;
    const effect = includeBase ? attackEffectBonus(effects, items, offhand ? 2 : 1, { touch, limit }).total : 0;
    let total = ability + (includeBase ? base.baseAttackBonus + effect : 0);
    if (item && num(row, 'RangedWeapon')) return touch ? total : 0;
    if (!touch || !item) total += weaponFocus(item) + epicFocus(item);
    if ((areaFlags & 4) && !(areaFlags & 3)) total += constant(198, 'NATURE_SENSE_TO_HIT_MODIFIER', 2);
    total += constant(584, 'EPIC_PROWESS_ATTACK_BONUS', 1);
    if (touch) return total;
    if (item && feats.has(num(row, 'WeaponOfChoiceFeat', 65535) & 65535)) {
      if (feats.has(884)) total++;
      if (feats.has(1071)) total += Math.trunc((classLevel(root, 33) - 10) / 3);
    }
    const other = left ?? (double ? right : null), otherRow = baseItem(other, rules);
    if (other && (offhand || num(otherRow, 'WeaponType'))) {
      total += rulesetInt(rules, offhand ? 'OFFHAND_NORMAL_OFFHAND_ATTACK_PENALTY' : 'ONHAND_NORMAL_OFFHAND_ATTACK_PENALTY', offhand ? -10 : -6);
      const difference = i8(num(otherRow, 'WeaponSize')) - size;
      const relative = difference >= -2 && difference <= 1 ? difference : -10;
      if (relative < 0 || num(otherRow, 'WeaponWield') === 8) total += rulesetInt(rules, 'LIGHT_OFFHAND_WEAPON_BONUS', 2);
      if (offhand) total += constant(1, 'AMBIDEXTERITY_BONUS', 4);
      total += constant(41, 'TWO_WEAPON_FIGHTING_BONUS', 2);
    }
    return total | 0;
  };
  const row = baseItem(right, rules);
  let ranged = 0;
  if (!right || touch || num(row, 'RangedWeapon')) {
    ranged = (!touch && feats.has(412) && modifiers.Wis > modifiers.Dex ? modifiers.Wis : modifiers.Dex) +
      (includeBase ? base.baseAttackBonus + attackEffectBonus(effects, items, 1, { touch, limit }).total : 0);
    if (!touch) {
      let enchant = 0;
      for (let tier = 20; tier >= 1; tier--) if (feats.has(tier <= 5 ? 444 + tier : 1039 + tier)) {
        enchant = rulesetInt(rules, `PRESTIGE_ENCHANT_ARROW_${tier}_BONUS`, tier); break;
      }
      ranged += enchant + weaponFocus(right) + epicFocus(right);
      if (right && num(row, 'WeaponWield') === 11) ranged += constant(250, 'GOOD_AIM_MODIFIER', 1);
      if (root.Race === 3 && right?.data.BaseItem === 61) ranged++;
    }
  }
  return { melee: melee(false), offhand: melee(true), ranged: ranged | 0 };
}

export function finalCombatStats(root, rules, abilities, base, { items = equipmentRecords(root), effects = [], pendingFeats = [], areaFlags = 0, limits = {}, acCache, itemCombatEffects } = {}) {
  if (!rules.baseitems || !rules.armor || !rules.parts_chest || !rules.itemCosts) throw new Error('Final combat rules are not loaded');
  const modifiers = Object.fromEntries(Object.entries(abilities).map(([key, value]) => [key, abilityModifier(value, rules)]));
  const projected = itemCombatEffects ?? equipmentCombatEffects(items, rules, { root }), allEffects = [...projected.effects, ...effects];
  const feats = featSet(root, pendingFeats);
  const luck = feats.has(382) ? rulesetInt(rules, 'LUCKOFHEROES_SAVE_BONUS', 1) : 0;
  // Dark Blessing adds signed CHA, including negatives; Divine Grace differs.
  const darkBlessing = feats.has(473) ? modifiers.Cha : 0;
  const savesBreakdown = Object.fromEntries(Object.entries({ fortitude: ['Con', 1, 'fortbonus'], reflex: ['Dex', 2, 'refbonus'], will: ['Wis', 3, 'willbonus'] }).map(([name, [ability, save, fieldName]]) => {
    const effect = savingThrowEffectBonus(root, allEffects, items, save, { limit: limits.saves ?? 20, pendingFeats });
    const authored = i8(root[fieldName] ?? 0), abilityBonus = modifiers[ability];
    return [name, { base: base.baseSaves[name], ability: abilityBonus, authored, luck, darkBlessing, effect,
      total: i8(base.baseSaves[name] + abilityBonus + authored + luck + darkBlessing + effect.total) }];
  }));
  const size = num(rowAt(rules.appearance, root.Appearance_Type), 'SIZECATEGORY', 3);
  const ac = armorClass(root, rules, modifiers, items, allEffects, { pendingFeats, acCache });
  const attack = attackBonuses(root, rules, modifiers, items, allEffects, base, { pendingFeats, areaFlags, size, limit: limits.attack ?? 20 });
  return { armorClass: ac.total, attackBonuses: attack, saves: Object.fromEntries(Object.entries(savesBreakdown).map(([name, value]) => [name, value.total])),
    finalBreakdown: { armor: ac, saves: savesBreakdown }, unsupportedItemProperties: projected.unsupported };
}
