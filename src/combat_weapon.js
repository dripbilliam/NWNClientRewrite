import { intEntry, rulesetInt } from './combat_stats.js';
import { creatureRoot } from './creature_rules.js';
import { getBlind } from './perception.js';

export function weaponRule(item, rules, column, fallback = 0) {
  if (!item) return fallback;
  const entry = intEntry(rules.baseitems, item.data.BaseItem, column);
  return entry.found ? entry.value : fallback;
}

export function attackWeapon(items, rules, offhand = false) {
  const right = items.find(i => i.slot === 16);
  return offhand ? items.find(i => i.slot === 32) ?? (weaponRule(right, rules, 'WeaponWield') === 8 ? right : null) : right ?? null;
}

// GetCurrentAttackWeapon 0x1403760a0: doubles choose main-hand before the
// left slot, whereas the critical getters above check the left slot first.
export function currentAttackWeapon(items, rules, hand, selectHand) {
  // Native zero invokes GetWeaponAttackType; natural weapons consume RNG.
  // Zero is not the unarmed/no-item sentinel and must never silently return null.
  if(hand===0){
    if(typeof selectHand!=='function')throw new Error('Native current weapon selection query is unavailable');
    hand=selectHand();if(!Number.isInteger(hand))throw new Error('Native current weapon selection result is unavailable');
  }
  const right = items.find(i => i.slot === 16);
  if ([1, 6].includes(hand)) return right ?? null;
  if (hand === 2) return weaponRule(right, rules, 'WeaponWield') === 8 ? right : items.find(i => i.slot === 32) ?? null;
  return items.find(i => i.slot === ({ 3: 16384, 4: 32768, 5: 65536, 7: 8, 8: 8 })[hand]) ?? null;
}

export function criticalProfile(object, items, rules, offhand = false) {
  const item = attackWeapon(items, rules, offhand), feats = new Set(object.stats.feats);
  const threat = item ? weaponRule(item, rules, 'CritThreat') & 255 : 1;
  const keenItem = item ?? items.find(i => i.slot === 8);
  let extra = keenItem?.data.PropertiesList?.some(p => p.PropertyName === 43) ? threat : 0;
  const choice = item && feats.has(weaponRule(item, rules, 'WeaponOfChoiceFeat', 65535) & 65535);
  if (choice && feats.has(885)) extra = (extra + rulesetInt(rules, 'KI_CRITICAL_BONUS', 2)) & 255;
  if (feats.has(item ? weaponRule(item, rules, 'WeaponImprovedCriticalFeat', 65535) & 65535 : 62)) extra = (extra + threat) & 255;
  const multiplier = item ? (weaponRule(item, rules, 'CritHitMult') & 255) + (choice && feats.has(883) ? 1 : 0) : 2;
  return { threat: 21 - extra - threat, multiplier };
}

export function usesMonkAttackTables(object, items, rules, unarmedOnly = false) {
  if (!object.stats.combat.finalBreakdown.armor.monkAbilities) return false;
  const right = items.find(i => i.slot === 16), left = items.find(i => i.slot === 32);
  if (unarmedOnly) return !right;
  return !right || weaponRule(right, rules, 'IsMonkWeapon') === 1 && (!left || weaponRule(left, rules, 'IsMonkWeapon') !== 0);
}

export function attacksPerRound(object, items, rules) {
  const bab = object.stats.combat.baseAttackBonusWithoutEpic;
  const monk = usesMonkAttackTables(object, items, rules);
  const value = monk ? bab + 2 < 18 ? Math.trunc((bab + 2) / 3) : 6 : bab + 4 < 30 ? Math.trunc((bab + 4) / 5) : 6;
  return value === 0 ? 1 : value & 255;
}

// GetFlatFooted 0x1403e3910. The visibility-update flags are independent of
// the per-opponent visible-list node. They must come from world perception.
export function isFlatFooted(object) {
  if (!Number.isInteger(object.perceptionUpdateFlags) || !Number.isInteger(object.creatureState) || !Number.isInteger(object.creatureAnimation)) throw new Error('Creature perception/animation state is unavailable');
  if (object.creatureState === 6 || (object.perceptionUpdateFlags & 6) !== 6 && object.combatMode !== 11) return true;
  if (object.stats.feats.includes(226)) return false;
  if (getBlind(object)!==0) return true;
  const animation = object.creatureAnimation & 255;
  return animation < 33 && Boolean((0x1ffffbc01n >> BigInt(animation)) & 1n);
}

export const creatureClassLevel = (object, id) => creatureRoot(object).ClassList.find(c => c.Class === id)?.ClassLevel ?? 0;
