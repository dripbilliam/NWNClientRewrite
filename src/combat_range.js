import { intEntry } from './combat_stats.js';
import { creatureRoot } from './creature_rules.js';
import { nativeDistanceSquared } from './nearest_objects.js';

const f = Math.fround;
function floatCell(table, index, name) {
  if (!table) throw new Error('Native combat range rules are unavailable');
  const row = table.orderedRows ? table.orderedRows[index] : table.rows.get(index);
  const value = row?.[Object.keys(row).find(k => k.toLowerCase() === name.toLowerCase())];
  if (value === undefined || value === '****' || value === '') return null;
  const parsed = parseFloat(value);
  if (!Number.isFinite(parsed)) throw new Error(`Native combat range float ${name} is unsupported`);
  return f(parsed);
}
const appearance = object => creatureRoot(object).Appearance_Type & 65535;

// DesiredAttackRange 0x14038a610. BaseItem +0x3c is PrefAttackDist, verified
// through Load 0x14029dfa0. Appearance caches: PREFATCKDIST and weaponscale.
export function desiredAttackRange(actor, target, rules, items, forceCreatureRange = false) {
  const weapon = items.find(i => i.slot === 16), warnings = [];
  let distance;
  if (forceCreatureRange || !weapon || ((weapon.data.BaseItem - 69) >>> 0) < 4) {
    distance = floatCell(rules.appearance, appearance(actor), 'PREFATCKDIST');
  } else {
    distance = floatCell(rules.baseitems, weapon.data.BaseItem, 'PrefAttackDist');
    if (typeof actor.modelType !== 'string') throw new Error('Native attack-range MODELTYPE is unavailable');
    if (actor.modelType.includes('P') || actor.modelType.includes('F'))
      distance = distance === null ? null : f(distance * (floatCell(rules.appearance, appearance(actor), 'weaponscale') ?? 1));
  }
  // Missing values with no established deterministic native output fail
  // explicitly. Never replace unknown native reach with a guessed radius.
  if (distance === null) throw new Error('Native preferred attack distance is unavailable');
  if (!forceCreatureRange && distance <= 0) warnings.push('Native warning: Desired Attack Range returned 0.0 meters... invalid item?');
  if (target?.objectType === 5) distance = f(distance + (floatCell(rules.appearance, appearance(target), 'HITDIST') ?? f(0.5)));
  return { distance, warnings };
}

// MaxAttackRange 0x1403997d0: ammunition type, not RangedWeapon, selects
// the 40/20 metre branch. Melee maximum is desired reach +1.5 metres.
export function maximumAttackRange(actor, target, rules, items, { forceCreatureRange = false, shortRanged = false } = {}) {
  const weapon = items.find(i => i.slot === 16);
  if (weapon && (intEntry(rules.baseitems, weapon.data.BaseItem, 'AmmunitionType').value & 255))
    return { distance: shortRanged ? 20 : 40, warnings: [] };
  const result = desiredAttackRange(actor, target, rules, items, forceCreatureRange);
  return { ...result, distance: f(result.distance + f(1.5)) };
}

// AIActionAttackObject 0x1403dd870: full 3D distance and float32 0.01 slack.
// This is only the geometric gate; perception/LOS/path checks are separate.
export function withinMaximumAttackRange(actor, target, maximum) {
  const reach = f(f(maximum) + f(0.01));
  return actor.areaId === target.areaId && nativeDistanceSquared(actor.position, target.position) <= f(reach * reach);
}
