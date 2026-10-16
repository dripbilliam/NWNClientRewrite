import { intEntry, rulesetInt } from './combat_stats.js';
import { creatureRoot } from './creature_rules.js';
import {bonusFeats} from './bonus_feat_effect.js';

const integer = (value, name) => {
  if (!Number.isInteger(value)) throw new Error(`Native feat ${name} is unavailable`);
  return value | 0;
};
const u16 = value => integer(value, 'ID') & 65535;
const byte = value => integer(value, 'byte') & 255;
const infos = new WeakMap();

// LoadFeatInfo 1402a8800, CNWFeat ctor 1402a1180, GetFeat 1402a3bd0.
// The Feat cell being present marks a row valid. IDs index physical rows;
// the cell's value and the textual row label do not remap that index.
export function featInfo(rules, id) {
  const table = rules.feat;
  if (!table) throw new Error('Native feat table is unavailable');
  if (!infos.has(table)) {
    const count = (table.orderedRows?.length ?? table.rows.size) & 65535;
    infos.set(table, Array.from({ length: count }, (_, index) => {
      if (!intEntry(table, index, 'Feat').found) return null;
      const uses = intEntry(table, index, 'UsesPerDay'), next = intEntry(table, index, 'SUCCESSOR');
      return { uses: uses.found ? uses.value & 255 : 0, successor: next.found ? next.value & 65535 : 65535 };
    }));
  }
  return infos.get(table)[u16(id)] ?? null;
}

// HasFeat 14040b900. The bonus list is supplied separately from GFF.
// Ranger grants are conditional on current chest armor, not permanent feats.
export function hasNativeFeat(object, id, armorClass) {
  id = u16(id);
  const root = creatureRoot(object);
  if (!root) throw new Error('Native feat ownership is unavailable');
  if ((root.FeatList ?? []).some(entry => u16(entry.Feat) === id) || bonusFeats(object).some(feat => u16(feat) === id)) return 1;
  if (id !== 1 && id !== 41) return 0;
  if (!(root.ClassList ?? []).slice(0, (root.ClassList?.length ?? 0) & 255).some(entry => byte(entry.Class) === 7)) return 0;
  if (typeof armorClass !== 'function') throw new Error('Native Ranger feat armor provider is unavailable');
  return integer(armorClass(object), 'chest armor class') < 4 ? 1 : 0;
}

// Canonical stats +10/+18/+1c own pointers to four-byte records:
// ushort feat +0, byte SPENT uses +2. Padding is not a serialized field.
export class FeatUsePool {
  constructor() { this.records = []; this.capacity = 0; }
  bounded() {
    if (this.records.length > 65535) throw new Error('Native feat pool would loop after its ushort index wraps');
  }
  find(id) {
    this.bounded(); id = u16(id);
    for (const record of this.records) {
      if (!(record instanceof DataView) || record.byteLength !== 4) throw new Error('Native feat pool record is unavailable');
      if (record.getUint16(0, true) === id) return record;
    }
    return null;
  }
  append(id, spent = 0) {
    if (this.records.length >= 65535) throw new Error('Native feat pool ushort traversal limit exceeded');
    if (this.records.length === this.capacity) this.capacity = this.capacity ? this.capacity * 2 : 16;
    const record = new DataView(new ArrayBuffer(4));
    record.setUint16(0, u16(id), true); record.setUint8(2, byte(spent)); this.records.push(record);
    return record;
  }
  decrement(id) {
    this.bounded(); id = u16(id);
    for (const record of this.records) {
      if (!(record instanceof DataView) || record.byteLength !== 4) throw new Error('Native feat pool record is unavailable');
      if (record.getUint16(0, true) === id) record.setUint8(2, record.getUint8(2) + 1);
    }
  }
  increment(id) {
    this.bounded(); id = u16(id);
    for (const record of this.records) {
      if (!(record instanceof DataView) || record.byteLength !== 4) throw new Error('Native feat pool record is unavailable');
      if (record.getUint16(0, true) === id && record.getUint8(2) !== 0) record.setUint8(2, record.getUint8(2) - 1);
    }
  }
  reset() {
    this.bounded();
    for (const record of this.records) {
      if (record === null) continue; // ResetFeatRemainingUses alone skips NULL.
      if (!(record instanceof DataView) || record.byteLength !== 4) throw new Error('Native feat pool record is unavailable');
      record.setUint8(2, 0);
    }
  }
  remove(id) {
    id = u16(id);
    // RemoveFeat uses a SIGNED short tail index, unlike the other scans.
    for (let index = (this.records.length - 1) << 16 >> 16; index >= 0; index--) {
      const record = this.records[index];
      if (!(record instanceof DataView) || record.byteLength !== 4) throw new Error('Native feat pool record is unavailable');
      if (record.getUint16(0, true) === id) { this.records.splice(index, 1); return; }
    }
  }
}

const owned = (object, id, p) => integer(p.hasFeat(object, id), 'ownership');
function classLevel(object, id) {
  const list = creatureRoot(object)?.ClassList;
  if (!Array.isArray(list)) throw new Error('Native feat class list is unavailable');
  const entry = list.slice(0, list.length & 255).find(entry => byte(entry.Class) === id);
  return entry ? byte(entry.ClassLevel) : null;
}
function levels(object) {
  const list = creatureRoot(object)?.ClassList;
  if (!Array.isArray(list)) throw new Error('Native feat class list is unavailable');
  return list.slice(0, list.length & 255).reduce((sum, entry) => sum + byte(entry.ClassLevel), 0) & 255;
}

// GetHighestLevelOfFeat 1404029b0 keeps the last OWNED successor, even when
// intervening feats are not owned. A cycle is diagnosed rather than hung.
export function highestFeat(object, id, rules, p) {
  let last = 65535; const visited = new Set(); id = u16(id);
  while (true) {
    if (visited.has(id)) throw new Error('Native feat successor cycle is unsupported');
    visited.add(id);
    const lookup = id === 65000 || id === 65001 ? 5 : id, info = featInfo(rules, lookup);
    if (!info) return last;
    if (owned(object, lookup, p) !== 0) last = id;
    id = info.successor;
  }
}

// Shared native maximum arithmetic in Remaining 1404012f0 and Total
// 140401c70. Byte narrowing occurs BEFORE comparison with spent uses/cap100.
function maximum(object, id, info, rules, p) {
  let uses = info.uses;
  const has = feat => owned(object, feat, p), rule = (label, fallback) => rulesetInt(rules, label, fallback);
  if (id === 257 || id >= 355 && id <= 373) {
    if (has(423) !== 0) uses += rule('EXTRA_MUSIC_BONUS_USES', 4);
    const bard = classLevel(object, 1); if (bard > 20) uses += bard - 20;
  } else if (id === 39) {
    uses = classLevel(object, 5) ?? ((levels(object) + 3) >>> 2);
    if (has(410) === 1) uses += rule('FEAT_EXTRA_STUNNING_ATTACK_USES', 3);
  } else if (id === 294) {
    if (typeof p.charismaModifier !== 'function') throw new Error('Native feat Charisma modifier is unavailable');
    uses = rule('TURN_UNDEAD_BASE_USES_PER_DAY', 3) + (integer(p.charismaModifier(object), 'Charisma modifier') << 24 >> 24);
    if (has(13) !== 0) uses += rule('FEAT_EXTRA_TURNING_BONUS_TURNS', 6);
  } else if (id === 301 || id === 472) {
    if (has(910) !== 0) uses += rule('EXTRA_SMITING_BONUS_USES', 2);
  } else if ([304,340,341,342].includes(id)) {
    if (has(1069) !== 0) return { unlimited: true };
  } else if ([305,335,336,337,338,339].includes(id)) {
    if (has(1068) !== 0) return { unlimited: true };
  } else if (id === 331) {
    uses += Math.trunc(((classLevel(object, 0) ?? 0) - 20) / 4);
  } else if (id >= 441 && id <= 444) {
    const harper = classLevel(object, 28), threshold = id - 435;
    if (harper >= threshold) uses += Math.trunc((harper - threshold) / 3) + 1;
  } else if (id === 882) {
    const weaponMaster = classLevel(object, 33); if (weaponMaster !== null) uses *= weaponMaster;
  } else if (id === 893) {
    uses += Math.trunc(((classLevel(object, 34) ?? 0) - 10) / 3);
  } else if ([898,900,901,902,903].includes(id)) {
    if (has(({898:1062,900:1063,901:1064,902:1066,903:1065})[id]) !== 0) return { unlimited: true };
  } else if (id === 947) {
    const defender = classLevel(object, 36); if (defender !== null) uses = (defender + 1) >>> 1;
  }
  return { uses: uses & 255, unlimited: false };
}

export function featUses(object, id, rules, p, remaining = true) {
  if (typeof p?.hasFeat !== 'function') throw new Error('Native feat ownership provider is unavailable');
  let info; id = u16(id); const visited = new Set();
  while (true) {
    if (visited.has(id)) throw new Error('Native feat-use alias cycle is unsupported');
    visited.add(id); info = featInfo(rules, id);
    if (!info) { p.warning?.(`GetFeat${remaining ? 'Remaining' : 'Total'}Uses: Invalid Feat ${id}`); return 0; }
    if (remaining) {
      if (typeof p.isDM !== 'function') throw new Error('Native feat DM query is unavailable');
      if (integer(p.isDM(object), 'DM flag') !== 0) return 100;
    }
    if (owned(object, id, p) === 0) return 0;
    if (!(object.featUsePool instanceof FeatUsePool)) throw new Error('Native feat-use pool is unavailable');
    const record = object.featUsePool.find(id);
    if (!record) return 100;
    if (id === 871) {
      id = highestFeat(object, 257, rules, p); if (id === 65535) return 0;
      remaining = true; // GetFeatTotalUses(871) ALSO calls RemainingUses.
      continue;
    }
    const limit = maximum(object, id, info, rules, p);
    if (limit.unlimited) return 100;
    const spent = remaining ? record.getUint8(2) : 0;
    return limit.uses < spent ? 0 : Math.min(100, (limit.uses - spent) & 255);
  }
}

export function setFeatRemainingUses(object, id, count, rules, p) {
  if (!(object.featUsePool instanceof FeatUsePool)) throw new Error('Native feat-use pool is unavailable');
  id = u16(id); count = byte(count);
  const record = object.featUsePool.find(id), total = featUses(object, id, rules, p, false);
  const spent = total < count ? 0 : total - count;
  if (record) record.setUint8(2, spent); else object.featUsePool.append(id, spent);
}

export function addNativeFeat(object, id, rules, p) {
  id = u16(id); const info = featInfo(rules, id);
  if (!info) { p.warning?.(`AddFeat: Invalid Feat ${id}`); return; }
  const root = creatureRoot(object), list = root.FeatList ??= [];
  if (!list.some(entry => u16(entry.Feat) === id)) list.push({ Feat: id });
  if (object.stats?.feats && !object.stats.feats.includes(id)) object.stats.feats.push(id);
  if (!(object.featUsePool instanceof FeatUsePool)) throw new Error('Native feat-use pool is unavailable');
  if (info.uses !== 0 && !object.featUsePool.find(id)) object.featUsePool.append(id);
}

export function removeNativeFeat(object, id) {
  id = u16(id);
  const list = creatureRoot(object)?.FeatList;
  if (!Array.isArray(list)) throw new Error('Native feat ownership is unavailable');
  const index = list.findIndex(entry => u16(entry.Feat) === id); if (index >= 0) list.splice(index, 1);
  if (object.stats?.feats&&!bonusFeats(object).some(feat=>u16(feat)===id)) { const index = object.stats.feats.indexOf(id); if (index >= 0) object.stats.feats.splice(index, 1); }
  if (!(object.featUsePool instanceof FeatUsePool)) throw new Error('Native feat-use pool is unavailable');
  object.featUsePool.remove(id);
}

// ReadStatsFromGff 1404117ae..140411906: AddFeat FIRST, then restore the
// optional BYTE Uses cell as REMAINING, defaulting missing cells to fresh.
export function initializeFeatUses(object, rules, p) {
  if (object.featUsePool) throw new Error('Native feat-use pool is already initialized');
  const list = creatureRoot(object)?.FeatList ?? [];
  if (list.length > 65535) throw new Error('Native serialized feat list would wrap its ushort traversal');
  object.featUsePool = new FeatUsePool();
  for (const entry of [...list]) {
    if (entry.Feat !== undefined) addNativeFeat(object, entry.Feat, rules, p);
    if (entry.Uses !== undefined) setFeatRemainingUses(object, entry.Feat ?? 0, entry.Uses, rules, p);
  }
  return object.featUsePool;
}
