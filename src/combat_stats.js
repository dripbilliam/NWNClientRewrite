// Native 89.8193.37-17 base providers. These are not attack resolution or final
// saving throws; effect/item/context modifiers belong to separate providers.
const i8 = n => (n << 24) >> 24;
const ordered = table => table.orderedRows ?? [...table.rows.values()];
const rowAt = (table, index) => table.orderedRows ? table.orderedRows[index] : table.rows.get(index);
const field = (row, name) => row?.[Object.keys(row).find(key => key.toLowerCase() === name.toLowerCase())];
const empty = value => value === undefined || value === '' || value === '****';
const resourceDecoder = new TextDecoder('windows-1252');
const byteByCharacter = new Map(Array.from({ length: 256 }, (_, byte) => [resourceDecoder.decode(Uint8Array.of(byte)), byte]));
const rulesetCache = new WeakMap();

export function rulesetHash(label) {
  let hash = 0xcbf29ce484222325n;
  for (const character of label) {
    const byte = byteByCharacter.get(character);
    if (byte === undefined) throw new Error('Ruleset label cannot be encoded as a native resource string');
    // The target hashes signed char values, then narrows multiplication to u64.
    hash = BigInt.asUintN(64, (hash ^ BigInt(i8(byte))) * 0x100000001b3n);
  }
  return hash;
}

function compiledRuleset(table) {
  if (rulesetCache.has(table)) return rulesetCache.get(table);
  const values = new Map(), floats = new Map(), duplicates = [];
  for (const row of ordered(table)) {
    const label = field(row, 'Label'), value = field(row, 'Value');
    if (empty(label) || empty(value)) continue;
    const hash = rulesetHash(label);
    if (values.has(hash)) duplicates.push(label);
    values.set(hash, atoi(value));
    // LoadRulesetInfo 0x1402ac449 calls atof, then cvtsd2ss at 0x1402ac451.
    const match = String(value).match(/^\s*[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/);
    floats.set(hash, Math.fround(match ? Number(match[0]) : 0));
  }
  const compiled = { values, floats, duplicates };
  // Native rule caches also remain fixed until the table is reloaded.
  rulesetCache.set(table, compiled);
  return compiled;
}

export const rulesetDuplicates = rules => rules.ruleset ? compiledRuleset(rules.ruleset).duplicates : [];

function atoi(value) {
  const match = String(value ?? '').match(/^\s*([+-]?\d+)/);
  return match ? Number(match[1]) | 0 : 0;
}

// GetINTEntry supports hexadecimal cells. The table default uses atoi instead.
export function intEntry(table, index, column) {
  const row = rowAt(table, index), value = field(row, column);
  if (!row || value === undefined) return { found: false, value: atoi(table.defaultValue) };
  if (empty(value)) return { found: false, value: 0 };
  return { found: true, value: /^0x[\da-f]+/i.test(value) ? parseInt(value, 16) | 0 : atoi(value) };
}

export function rulesetInt(rules, label, fallback) {
  if (!rules.ruleset) return fallback;
  // Native cache keys are FNV-1a u64, with the last nonempty duplicate winning.
  return compiledRuleset(rules.ruleset).values.get(rulesetHash(label)) ?? fallback;
}

export function rulesetFloat(rules, label, fallback) {
  return rules.ruleset ? compiledRuleset(rules.ruleset).floats.get(rulesetHash(label)) ?? Math.fround(fallback) : Math.fround(fallback);
}

export function abilityModifier(score, rules) {
  const neutral = rulesetInt(rules, 'CHARGEN_ABILITY_NEUTRAL_VALUE', 10);
  const increment = rulesetInt(rules, 'CHARGEN_ABILITY_MODIFIER_INCREMENT', 2);
  let difference = ((score & 255) - neutral) | 0;
  if ((score & 255) < neutral && neutral % 2 === 0) difference = (difference - 1) | 0;
  if (!increment || (difference === -2147483648 && increment === -1)) throw new Error('Ability modifier rules cause a native integer division fault');
  return i8(Math.trunc(difference / increment));
}

export function preEpicClassLevels(root) {
  const total = root.ClassList.reduce((sum, c) => sum + c.ClassLevel, 0) & 255;
  const history = root.LvlStatList ?? [];
  if (history.length === total) {
    // CNWLevelStats initializes class and epic flag to zero; older BICs omit
    // EpicLevel. ReadStatsFromGff preserves those constructor defaults.
    for (const h of history) if (!Number.isInteger(h.LvlStatClass ?? 0) || !Number.isInteger(h.EpicLevel ?? 0)) throw new Error('Invalid combat level history attribution');
    return root.ClassList.map(c => history.filter(h => ((h.LvlStatClass ?? 0) & 255) === c.Class && (h.EpicLevel ?? 0) === 0).length);
  }
  let allocated = 0;
  return root.ClassList.map(c => {
    const count = Math.min(c.ClassLevel, 20 - allocated); allocated += count;
    return count;
  });
}

function tableBonus(table, levels, column, requireFound = false) {
  if (!table) throw new Error(`Combat ${column} table is unavailable`);
  const level = levels & 255;
  if (level < 1 || level > 60) return 0;
  const entry = intEntry(table, level - 1, column);
  // LoadAttackBonusTable zeroes unsuccessful cells; save/epic loaders keep the
  // GetINTEntry output even on failure (including out-of-range table defaults).
  return (requireFound && !entry.found ? 0 : entry.value) & 255;
}

const SAVE_FEATS = {
  fortitude: [[14, 'GREAT_FORTITUDE_SAVE_BONUS', 2], [248, 'LUCKY_SAVE_BONUS', 1], [388, 'STRONG_SOUL_SAVE_BONUS', 1], [583, 'EPIC_FORTITUDE_SAVE_BONUS', 4]],
  reflex: [[24, 'LIGHTNING_REFLEXES_SAVE_BONUS', 2], [248, 'LUCKY_SAVE_BONUS', 1], [386, 'SNAKE_BLOOD_REFLEX_BONUS', 1], [585, 'EPIC_REFLEXES_REFLEX_BONUS', 4]],
  will: [[22, 'IRON_WILL_SAVE_BONUS', 2], [248, 'LUCKY_SAVE_BONUS', 1], [380, 'BULLHEADED_WILL_SAVE_BONUS', 1], [388, 'STRONG_SOUL_SAVE_BONUS', 1], [695, 'EPIC_WILL_SAVE_BONUS', 4]]
};
const SAVE_COLUMNS = { fortitude: 'FortSave', reflex: 'RefSave', will: 'WillSave' };

export function baseCombatStats(root, rules, { charismaModifier, pendingFeats = [], overrideBaseAttackBonus = 0 } = {}) {
  if (!rules.classTables || !rules.epicattacks || !rules.epicsaves || !rules.ruleset) throw new Error('Combat rules are not loaded');
  if (!Number.isInteger(charismaModifier) || charismaModifier < -128 || charismaModifier > 127) throw new Error('Combat requires the live signed-byte Charisma modifier');
  if (!Number.isInteger(overrideBaseAttackBonus) || overrideBaseAttackBonus < 0 || overrideBaseAttackBonus > 255) throw new Error('Invalid runtime base attack override');
  const preEpic = preEpicClassLevels(root);
  const contributions = root.ClassList.map((c, index) => {
    const row = rowAt(rules.classes, c.Class);
    if (!row) throw new Error(`Combat class ${c.Class} rules are unavailable`);
    const get = name => rules.classTables.get(String(row[name]).toLowerCase());
    const attack = get('AttackBonusTable'), saves = get('SavingThrowTable'), levels = preEpic[index];
    return { classId: c.Class, preEpicLevels: levels, attack: tableBonus(attack, levels, 'BAB', true),
      saves: Object.fromEntries(Object.entries(SAVE_COLUMNS).map(([name, column]) => [name, tableBonus(saves, levels, column)])) };
  });
  const epicLevels = Math.max(0, (root.ClassList.reduce((sum, c) => sum + c.ClassLevel, 0) & 255) - 20);
  const classAttack = contributions.reduce((sum, c) => sum + c.attack, 0);
  const epicAttack = tableBonus(rules.epicattacks, epicLevels, 'BAB');
  const feats = new Set([...(root.FeatList ?? []).map(f => f.Feat), ...pendingFeats]);
  const divineGrace = feats.has(217) ? Math.max(0, charismaModifier) : 0;
  const saveBreakdown = Object.fromEntries(Object.entries(SAVE_COLUMNS).map(([name, column]) => {
    const classBonus = i8(contributions.reduce((sum, c) => sum + c.saves[name], 0));
    const epicBonus = tableBonus(rules.epicsaves, epicLevels, column);
    const featBonuses = SAVE_FEATS[name].filter(([feat]) => feats.has(feat)).map(([feat, label, fallback]) => ({ feat, value: rulesetInt(rules, label, fallback) }));
    return [name, { classBonus, epicBonus, divineGrace, featBonuses,
      total: i8(classBonus + epicBonus + divineGrace + featBonuses.reduce((sum, f) => sum + f.value, 0)) }];
  }));
  return { baseAttackBonus: overrideBaseAttackBonus || classAttack + epicAttack,
    baseAttackBonusWithoutEpic: overrideBaseAttackBonus || classAttack,
    baseSaves: Object.fromEntries(Object.entries(saveBreakdown).map(([name, breakdown]) => [name, breakdown.total])),
    breakdown: { classes: contributions, epicLevels, epicAttack, overrideBaseAttackBonus, saves: saveBreakdown } };
}
