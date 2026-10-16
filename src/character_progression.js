import { cloneGff } from './gff.js';
import { ABILITIES, characterStats } from './character.js';
import {rulesetInt} from './combat_stats.js';
import {featAbilityDeltas} from './feat_ability_bonuses.js';

const byte = n => n & 255;
const i16 = n => (n << 16) >> 16;
const value = (v, fallback = 0) => v === undefined || v === '****' ? fallback : Number(v);
const level = root => root.ClassList.reduce((n, c) => n + c.ClassLevel, 0);
const table = (rules, row, field) => rules.classTables?.get(String(row[field]).toLowerCase());
const remove = (list, match) => { const i = list.findIndex(match); if (i >= 0) list.splice(i, 1); };

export function initializeBonusSpellSlots(root) {
  if (!Array.isArray(root?.ClassList)) throw new Error('Character class history is incomplete');
  const missing = new Set(root.ClassList.filter(c => !c.bonusSpellSlots));
  for (const c of missing) c.bonusSpellSlots = Array(10).fill(0);
  for (const item of root.Equip_ItemList ?? []) for (const p of item.PropertiesList ?? []) {
    if (p.PropertyName !== 13) continue;
    const c = root.ClassList.findLast(c => c.Class === p.Subtype), spellLevel = byte(p.CostValue);
    // ApplyBonusSpellOfLevel uses the low byte of CostValue directly; the cost
    // 2DA controls pricing, not the slot level. Each property adds one slot.
    if (missing.has(c) && spellLevel < 10) c.bonusSpellSlots[spellLevel]++;
  }
  return root;
}

export function canLevelUp(stats, rules, { isPC = true, associateType = 0, maximumLevel = 40 } = {}) {
  if ([3, 5, 6, 7, 8].includes(associateType) || stats.level >= maximumLevel || (isPC && stats.level >= 40)) return false;
  return stats.nextXP !== null && stats.xp >= stats.nextXP;
}

function threshold(rules, n) {
  const xp = value(rules?.exptable?.rows.get(n)?.XP, NaN);
  if (!Number.isInteger(xp) || xp < 0 || xp > 0xffffffff) throw new Error(`XP threshold for level ${n + 1} is unavailable`);
  return xp;
}

// ComputeFeatBonuses changes stored ability bytes; class StatGainTable bonuses
// are derived separately by the ability providers. These IDs are native engine
// constants, not class or module-specific choices.
function featAbilities(root, history, direction,rules) {
  const deltas=featAbilityDeltas(history.FeatList??[],direction<0?1:0,{hasFeat:(list,id)=>Number(list.some(entry=>(entry.Feat&65535)===id)),rule:(label,fallback)=>rulesetInt(rules,label,fallback)});
  for(let ability=0;ability<6;ability++)root[ABILITIES[ability]]=byte(root[ABILITIES[ability]]+deltas[ability]);
}

function spellGain(root, c, spellLevel, rules) {
  const row = rules.classes.rows.get(c.Class), ability = ABILITIES.find(a => a.toUpperCase() === row.SpellcastingAbil);
  if (!ability) return 0;
  const stats = characterStats(root, rules), base = byte(stats.baseAbilities[ability]);
  if (base < 10 + spellLevel) return 0;
  // The modifier excludes equipment; equipment spell-slot properties are a
  // separate native provider and cannot be guessed from saved slot counts.
  const modifier = Math.floor((stats.baseAbilities[ability] - 10) / 2);
  let bonus = spellLevel > 0 && modifier >= spellLevel ? Math.floor((modifier - spellLevel + 4) / 4) : 0;
  if (spellLevel > 0 && value(row.PickSchool) && c.School) bonus++;
  const position = root.ClassList.indexOf(c);
  let casterLevel = c.ClassLevel;
  for (const other of root.ClassList) {
    const otherRow = rules.classes.rows.get(other.Class);
    if (other === c || value(otherRow.SpellCaster)) continue;
    const divisor = value(otherRow[value(row.Arcane) ? 'ArcSpellLvlMod' : 'DivSpellLvlMod']);
    if (!divisor) continue;
    // Prestige progression attaches to the highest class of the same magic
    // type; ties favor the later class slot in this native routine.
    if (root.ClassList.some((r, i) => r !== c && r !== other && value(rules.classes.rows.get(r.Class).SpellCaster)
      && value(rules.classes.rows.get(r.Class).Arcane) === value(row.Arcane)
      && (r.ClassLevel > c.ClassLevel || (r.ClassLevel === c.ClassLevel && i > position)))) continue;
    casterLevel += Math.trunc((other.ClassLevel - 1 + divisor) / divisor);
  }
  const gain = table(rules, row, 'SpellGainTable');
  if (!gain) throw new Error(`Missing spell gain rules for class ${c.Class}`);
  if (byte(casterLevel) < 1 || byte(casterLevel) > 40) return 0;
  const gainRow = gain.rows.get(byte(casterLevel) - 1);
  if (spellLevel >= value(gainRow?.NumSpellLevels)) return 0;
  const amount = value(gainRow?.[`SpellLevel${spellLevel}`], 255);
  return amount === 255 ? 0 : byte(amount + bonus);
}

export function updateMemorizedSlots(root, rules) {
  initializeBonusSpellSlots(root);
  for (const c of root.ClassList) {
    const row = rules.classes.rows.get(c.Class);
    if (!row) throw new Error(`Missing class rules ${c.Class}`);
    if (!value(row.SpellCaster) || !value(row.MemorizesSpells)) continue;
    for (let l = 0; l < 10; l++) {
      const count = byte(spellGain(root, c, l, rules) + Math.min(255, c.bonusSpellSlots[l]));
      const list = c[`MemorizedList${l}`] ??= [];
      list.length = Math.min(list.length, count);
      while (list.length < count) list.push(null);
    }
  }
}

function spellLevel(c, spell, rules) {
  const row = rules.spells.rows.get(spell);
  return value(row?.[rules.classes.rows.get(c.Class)?.SpellTableColumn], 255);
}

function clearKnownSlots(c, spell, rules) {
  const l = spellLevel(c, spell, rules);
  if (l > 9) return;
  const clear = (n, metamagic) => {
    const slots = c[`MemorizedList${n}`] ?? [];
    for (let i = 0; i < slots.length; i++) if (slots[i]?.Spell === spell && (metamagic === undefined || slots[i].SpellMetaMagic === metamagic)) slots[i] = null;
  };
  clear(l);
  // Observed XOR sequence in 89.8193.37-17, including its unusual masks.
  // Do not replace it with a loop over all possible metamagic flags.
  for (let i = 0; i < 6; i++) {
    const mask = i ^ 2, cost = mask === 1 ? 2 : mask === 2 ? 1 : mask === 4 ? 3 : 0;
    if (l + cost < 10) clear(l + cost, mask);
  }
}

function addKnown(root, c, spell, rules) {
  const l = spellLevel(c, spell, rules);
  if (l > 9) return;
  const row = rules.classes.rows.get(c.Class), list = c[`KnownList${l}`] ??= [];
  if (!value(row.SpellbookRestricted)) {
    if (value(row.MemorizesSpells)) return;
    const known = table(rules, row, 'SpellKnownTable');
    if (!known) throw new Error(`Missing known-spell rules for class ${c.Class}`);
    const gains = table(rules, row, 'SpellGainTable');
    if (c.ClassLevel < 1 || c.ClassLevel > 40 || l >= value(gains?.rows.get(c.ClassLevel - 1)?.NumSpellLevels)) return;
    let count = value(known.rows.get(c.ClassLevel - 1)?.[`SpellLevel${l}`]);
    const preceding = value(known.rows.get(c.ClassLevel - 1)?.[`SpellLevel${l - 1}`]);
    if (l > 0 && preceding === 0) {
      const ability = ABILITIES.find(a => a.toUpperCase() === row.SpellcastingAbil);
      if (!ability || byte(characterStats(root, rules).baseAbilities[ability]) < 10 + l) count = 0;
    }
    if (list.length >= count) return;
  }
  list.push({ Spell: spell });
}

function historySpells(root, c, h, direction, rules) {
  for (let l = 0; l < 10; l++) {
    const removed = h[`${direction < 0 ? 'Known' : 'KnownRemove'}List${l}`] ?? [];
    const added = h[`${direction < 0 ? 'KnownRemove' : 'Known'}List${l}`] ?? [];
    for (const { Spell } of removed) {
      const actual = spellLevel(c, Spell, rules);
      if (actual < 10) remove(c[`KnownList${actual}`] ?? [], s => s.Spell === Spell);
      clearKnownSlots(c, Spell, rules);
    }
    for (const { Spell } of added) addKnown(root, c, Spell, rules);
  }
}

function applyHistory(root, history, direction, rules, stats) {
  const oldLevel = level(root);
  let c = root.ClassList.find(c => c.Class === history.LvlStatClass);
  if (!c && direction > 0 && root.ClassList.length < 8) { c = { Class: history.LvlStatClass, ClassLevel: 0, skillPenaltyByte: 0, School: 0, Domain1: 0, Domain2: 0, bonusSpellSlots: Array(10).fill(0) }; root.ClassList.push(c); }
  if (!c || (direction < 0 && c.ClassLevel === 0) || !Number.isInteger(history.LvlStatHitDie) || history.LvlStatHitDie < 0 || history.LvlStatHitDie > 255) throw new Error('Character level history does not match live classes');
  const oldClassLevel = c.ClassLevel;
  c.ClassLevel = byte(c.ClassLevel + direction);
  // SetClassLevel updates slots BEFORE ability/feat changes in both routines.
  updateMemorizedSlots(root, rules);
  root.HitPoints = i16(root.HitPoints + direction * history.LvlStatHitDie);
  if (history.LvlStatAbility >= 0 && history.LvlStatAbility < 6) {
    const a = ABILITIES[history.LvlStatAbility]; root[a] = byte(root[a] + direction);
  }
  const skills = root.SkillList ??= [];
  for (let i = 0; i < (rules.skills.rows.size & 255); i++) {
    const change = history.SkillList?.[i]?.Rank ?? 0;
    if (change) { skills[i] ??= { Rank: 0 }; skills[i].Rank = byte(skills[i].Rank + direction * change); }
  }
  const previous = direction < 0 ? root.LvlStatList[oldLevel - 2] : history;
  if (previous) root.SkillPoints = (previous.SkillPoints ?? 0) & 65535;
  const feats = root.FeatList ??= [];
  for (const f of history.FeatList ?? []) {
    if (direction < 0) remove(feats, entry => entry.Feat === f.Feat);
    else if (rules.feat.rows.has(f.Feat) && !feats.some(entry => entry.Feat === f.Feat)) feats.push({ Feat: f.Feat });
  }
  featAbilities(root, history, direction,rules);
  historySpells(root, c, history, direction, rules);
  if (direction < 0) {
    if (oldClassLevel < 10) c[`MemorizedList${oldClassLevel}`]?.fill(null);
    if (!c.ClassLevel && root.ClassList.at(-1) === c) root.ClassList.pop();
    root.LvlStatList.splice(oldLevel - 1, 1);
  } else if (level(root) > 20) history.EpicLevel = 1;
  const next = characterStats(root, rules, { currentHP: stats.currentHP });
  // LevelDown clamps signed-short HP to 1, even for a dying/dead PC. LevelUp
  // adds the max-HP delta only when GetDead is false, with no clamp.
  next.currentHP = direction < 0 ? Math.max(1, i16(stats.currentHP + next.maxHP - stats.maxHP))
    : stats.currentHP <= -10 ? stats.currentHP : i16(stats.currentHP + next.maxHP - stats.maxHP);
  root.CurrentHitPoints = next.currentHP;
  return next;
}

// Prepare changes on an isolated GFF clone so unsupported/corrupt rules cannot
// leave half-updated XP, classes, history or UI data in the canonical object.
export function reconcileExperience(source, stats, xp, rules, options = {}) {
  const direction = ((xp >>> 0) - (stats.xp >>> 0)) | 0;
  let current = { ...stats, xp: xp >>> 0 }, root = null, changes = [];
  const data = () => root ??= initializeBonusSpellSlots(cloneGff(source));
  const minimum = Math.max(1, options.minimumLevel ?? 1);
  if (direction < 0) {
    while (current.level > minimum && xp < threshold(rules, current.level - 1)) {
      const h = data().LvlStatList?.[current.level - 1];
      if (!h) throw new Error('Character level history is incomplete');
      current = applyHistory(root, h, -1, rules, current); changes.push(-1);
      current.xp = xp >>> 0;
    }
  } else if (direction > 0) {
    while (canLevelUp(current, rules, options) && (root ?? source).LvlStatList?.length > current.level) {
      const h = data().LvlStatList[current.level];
      if (!h) break;
      current = applyHistory(root, h, 1, rules, current); changes.push(1);
      current.xp = xp >>> 0;
    }
  }
  if (root) root.Experience = xp >>> 0;
  current.canLevelUp = canLevelUp(current, rules, options);
  return { root, stats: current, changes, delta: direction };
}
