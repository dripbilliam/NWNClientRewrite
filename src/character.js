import { parseGff, getGffStructType } from './gff.js';
import { parse2da, resolveCreatureModels } from './area.js';
import { decodeResourceText, RESOURCE_TYPE } from './resource_archive.js';
import { OBJECT_INVALID } from './game_object_array.js';
import { abilityModifier, baseCombatStats, rulesetDuplicates } from './combat_stats.js';
import { finalCombatStats, equipmentRecords } from './combat_modifiers.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { creatureMaxHitPoints, restoredCreatureHitPoints } from './creature_hit_points.js';
import {abilityEffectBonus,nativeAbilityScore} from './ability_effect.js';

export const ABILITIES = ['Str', 'Dex', 'Con', 'Int', 'Wis', 'Cha'];
export const EQUIPMENT_SLOTS = ['Head', 'Chest', 'Boots', 'Arms', 'Right hand', 'Left hand', 'Cloak', 'Left ring', 'Right ring', 'Neck', 'Belt', 'Arrows', 'Bullets', 'Bolts', 'Creature weapon 1', 'Creature weapon 2', 'Creature weapon 3', 'Creature armor'];
const number = (value, fallback = 0) => value === undefined || value === '****' ? fallback : Number(value);
const i16 = n => (n << 16) >> 16;
const i8 = n => (n << 24) >> 24;

export function importedObjectIds(player, root, items) {
  const ids = new Map();
  const add = (oldId, newId) => {
    if (!Number.isInteger(oldId) || oldId < 0 || oldId > 0xffffffff || oldId === OBJECT_INVALID) return;
    ids.set(oldId, ids.has(oldId) ? OBJECT_INVALID : newId);
  };
  add(root.ObjectId, player.id);
  for (const item of items) add(item.authored.ObjectId, item.id);
  return ids;
}

export function parseCharacter(bytes) {
  const root = parseGff(bytes, 'BIC ').root;
  validateCharacter(root);
  return root;
}

export function validateCharacter(root) {
  if (root.IsDM) throw new Error('DM character import requires a DM session');
  if (root.PM_IsPolymorphed || root.EffectList?.length) throw new Error('Importing polymorphed characters or saved active effects is not implemented');
  if (!root.IsPC) throw new Error('The BIC is not a player character');
  for (const field of [...ABILITIES, 'Race', 'Appearance_Type', 'Gender', 'Experience']) {
    if (!Number.isInteger(root[field]) || root[field] < 0) throw new Error(`Invalid character ${field}`);
  }
  if (!Array.isArray(root.ClassList) || !root.ClassList.length || root.ClassList.length > 8) throw new Error('Invalid character class list');
  const classes = new Set(); let level = 0;
  for (const entry of root.ClassList) {
    if (!Number.isInteger(entry.Class) || entry.Class < 0 || entry.Class > 254 || classes.has(entry.Class) || !Number.isInteger(entry.ClassLevel) || entry.ClassLevel < 1 || entry.ClassLevel > 255) throw new Error('Invalid character class entry');
    classes.add(entry.Class); level += entry.ClassLevel;
  }
  if (level > 255 || root.Experience > 0xffffffff || ABILITIES.some(f => root[f] > 255)) throw new Error('Character stats exceed native field ranges');
  for (const field of ['HitPoints', 'CurrentHitPoints']) if (!Number.isInteger(root[field]) || root[field] < -32768 || root[field] > 32767) throw new Error(`Invalid character ${field}`);
  if ((root.LvlStatList ?? []).length < level) throw new Error('Player character level history is incomplete');
  if (root.LvlStatList.some(x => !Number.isInteger(x.LvlStatHitDie) || x.LvlStatHitDie < 0 || x.LvlStatHitDie > 255)) throw new Error('Invalid character level hit die');
  const equipment = new Set();
  for (const item of root.Equip_ItemList ?? []) {
    const mask = getGffStructType(item);
    if (!Number.isInteger(mask) || !mask || mask > 0x20000 || (mask & (mask - 1)) || equipment.has(mask)) throw new Error('Invalid or duplicate equipment slot');
    equipment.add(mask);
  }
}

export async function loadCharacterRules(resolver) {
  const tables = Object.fromEntries(await Promise.all(['racialtypes', 'classes', 'skills', 'feat', 'spells', 'baseitems', 'exptable', 'appearance', 'gender', 'phenotype', 'iprp_costtable', 'epicattacks', 'epicsaves', 'ruleset', 'armor', 'parts_chest', 'iprp_saveelement', 'damagetypes', 'iprp_monstcost', 'iprp_damagecost', 'diffsettings', 'creaturespeed'].map(async name => [name, parse2da(decodeResourceText(await resolver.getResource(name, RESOURCE_TYPE.TWO_DA)))])));
  for (const label of rulesetDuplicates(tables)) runtimeDiagnostics.record('rules.duplicate-ruleset-entry', `Duplicate ruleset.2da entry: ${label}`, { resource: 'ruleset', label });
  // Load2DArrays 0x1402b59bb..1402b5ab8 frees a failed optional table;
  // SavingThrowRoll then uses the native legacy immunity switch.
  try { tables.savingthrowtypes = parse2da(decodeResourceText(await resolver.getResource('savingthrowtypes', RESOURCE_TYPE.TWO_DA))); }
  catch(error) {
    tables.savingthrowtypes = null;
    runtimeDiagnostics.record('rules.optional-table-unavailable', `savingthrowtypes.2da: ${error.message}`, { resource:'savingthrowtypes', outcome:'Native legacy save-immunity fallback selected', stack:error.stack });
  }
  try { tables.excitedduration=parse2da(decodeResourceText(await resolver.getResource('excitedduration',RESOURCE_TYPE.TWO_DA))); }
  catch(error){tables.excitedduration=null;runtimeDiagnostics.record('rules.optional-table-unavailable',`excitedduration.2da: ${error.message}`,{resource:'excitedduration',outcome:'SetExcitedState is unavailable',stack:error.stack});}
  try { tables.damagehitvisual=parse2da(decodeResourceText(await resolver.getResource('damagehitvisual',RESOURCE_TYPE.TWO_DA))); }
  catch(error){tables.damagehitvisual=null;runtimeDiagnostics.record('rules.optional-table-unavailable',`damagehitvisual.2da: ${error.message}`,{resource:'damagehitvisual',outcome:'Native on-hit visual lookup is unavailable',stack:error.stack});}
  try { tables.repadjust=parse2da(decodeResourceText(await resolver.getResource('repadjust',RESOURCE_TYPE.TWO_DA))); }
  catch(error){tables.repadjust=null;runtimeDiagnostics.record('rules.optional-table-unavailable',`repadjust.2da: ${error.message}`,{resource:'repadjust',outcome:'Native combat reputation adjustments are unavailable',stack:error.stack});}
  try { tables.ranges=parse2da(decodeResourceText(await resolver.getResource('ranges',RESOURCE_TYPE.TWO_DA))); }
  catch(error){tables.ranges=null;runtimeDiagnostics.record('rules.optional-table-unavailable',`ranges.2da: ${error.message}`,{resource:'ranges',outcome:'Native perception range initialization is unavailable',stack:error.stack});}
  try { tables.xptable=parse2da(decodeResourceText(await resolver.getResource('xptable',RESOURCE_TYPE.TWO_DA))); }
  catch(error){tables.xptable=null;runtimeDiagnostics.record('rules.optional-table-unavailable',`XPTable.2da: ${error.message}`,{resource:'xptable',outcome:'Native death experience lookup is unavailable',stack:error.stack});}
  try { tables.visualeffects=parse2da(decodeResourceText(await resolver.getResource('visualeffects',RESOURCE_TYPE.TWO_DA))); }
  catch(error){tables.visualeffects=null;runtimeDiagnostics.record('rules.optional-table-unavailable',`visualeffects.2da: ${error.message}`,{resource:'visualeffects',outcome:'Native death visual preservation lookup is unavailable',stack:error.stack});}
  for(const name of ['encumbrance','iprp_weightinc','itemprops','itempropdef','iprp_meleecost','iprp_spells','iprp_onhitspell','spellschools','domains','usemagicdevice','fractionalcr','encdifficulty','poison','disease','restduration']){
    try{tables[name]=parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));}
    catch(error){tables[name]=null;runtimeDiagnostics.record('rules.optional-table-unavailable',`${name}.2da: ${error.message}`,{resource:name,outcome:'Native dependent rule table is unavailable',stack:error.stack});}
  }
  tables.abilityCosts = new Map();
  tables.itemCosts = new Map();
  for (const id of [1, 2, 20, 21]) {
    const name = tables.iprp_costtable.rows.get(id)?.Name;
    if (!name || name === '****') throw new Error(`Missing ability item property cost table ${id}`);
    const table = parse2da(decodeResourceText(await resolver.getResource(name, RESOURCE_TYPE.TWO_DA)));
    tables.itemCosts.set(id, table);
    if ([1, 21].includes(id)) tables.abilityCosts.set(id, table);
  }
  tables.gains = new Map();
  tables.classTables = new Map();
  for (const row of tables.classes.rows.values()) {
    for (const field of ['StatGainTable', 'SpellGainTable', 'SpellKnownTable', 'AttackBonusTable', 'SavingThrowTable', 'SkillsTable', 'FeatsTable', 'BonusFeatsTable', 'PreReqTable']) {
      const name = String(row[field] ?? '****').toLowerCase();
      if (name !== '****' && !tables.classTables.has(name)) tables.classTables.set(name, parse2da(decodeResourceText(await resolver.getResource(name, RESOURCE_TYPE.TWO_DA))));
      if (field === 'StatGainTable' && name !== '****') tables.gains.set(name, tables.classTables.get(name));
    }
  }
  return tables;
}

export function characterStats(root, rules, { currentHP: liveHP, items = equipmentRecords(root), abilityProjectionItems=items,effects = [], areaFlags = 0, limits, acCache, possessedFamiliar = false, itemCombatEffects,abilityItem,bonusFeats=[],actor } = {}) {
  const classes = root.ClassList.map(c => ({ id: c.Class, level: c.ClassLevel }));
  const level = classes.reduce((n, c) => n + c.level, 0);
  const race = rules.racialtypes.rows.get(root.Race);
  if (!race || classes.some(c => !rules.classes.rows.has(c.id))) throw new Error('Character race or class missing from module rules');
  const parts={};
  const baseAbilities = Object.fromEntries(ABILITIES.map(field => {
    let gain = 0;
    for (const c of classes) {
      const table = rules.gains.get(String(rules.classes.rows.get(c.id).StatGainTable).toLowerCase());
      // Native GetAbilityGainForLevel sums levels 1..N, returning a signed byte.
      let classGain = 0;
      for (let l = 1; table && l <= c.level; l++) classGain += number(table.rows.get(l - 1)?.[field.toUpperCase()]);
      gain += i8(classGain);
    }
    parts[field]={base:root[field],race:number(race[`${field}Adjust`]),gain:Math.max(-128,Math.min(127,gain))};
    return [field, root[field] + parts[field].race + parts[field].gain];
  }));
  const equippedBonuses = equipmentAbilityBonuses(items.map(item => item.data), rules);
  const abilityEffects=[...equipmentAbilityEffects(abilityProjectionItems,rules),...effects.filter(e=>[36,37].includes(e.type))].sort((a,b)=>a.type-b.type),abilityBonuses={};
  const equippedAbilities=Object.fromEntries(ABILITIES.map((field,index)=>{
    const bonus=abilityEffectBonus(abilityEffects,index,{item:abilityItem??(id=>items.find(i=>i.id===id)??null),bonusLimit:()=>limits?.abilityBonus??12,penaltyLimit:()=>limits?.abilityPenalty??30}).total;
    abilityBonuses[field]=bonus;const p=parts[field];return[field,nativeAbilityScore(p.base,p.race,p.gain,bonus)];
  }));
  const con = abilityModifier(equippedAbilities.Con, rules);
  const feats = new Set([...(root.FeatList ?? []).map(f => f.Feat),...bonusFeats]);
  const maxHP = creatureMaxHitPoints(root, con, rules, { possessedFamiliar,bonusFeats });
  // ReadStatsFromGff restores PC current HP by adding maxHP - saved base HP.
  const currentHP = liveHP === undefined ? restoredCreatureHitPoints(root, maxHP, con) : i16(liveHP);
  const nextXP = number(rules.exptable.rows.get(level)?.XP, null);
  const combat = rules.epicattacks || rules.epicsaves
    ? baseCombatStats(root, rules, { charismaModifier: abilityModifier(equippedAbilities.Cha, rules),pendingFeats:bonusFeats }) : null;
  if (combat && rules.armor && rules.parts_chest && rules.itemCosts) Object.assign(combat,
    finalCombatStats(root, rules, equippedAbilities, combat, { items, effects, areaFlags, limits, acCache, itemCombatEffects,pendingFeats:bonusFeats,actor }));
  return { classes, level, baseAbilities, equippedBonuses,abilityBonuses, equippedAbilities, combat, maxHP, currentHP, xp: root.Experience >>> 0, gold: root.Gold ?? 0,
    race: root.Race, gender: root.Gender, subrace: root.Subrace ?? '', feats: [...feats], skills: (root.SkillList ?? []).map(s => s.Rank), skillPoints: root.SkillPoints ?? 0,
    nextXP, canLevelUp: level < 40 && nextXP !== null && root.Experience >= nextXP,
    // Saved combat snapshots are retained in authored data, not used as live rules.
    limitations: ['Ability effect aggregation is applied; broader item property execution remains pending.',
      combat?.saves ? 'Displayed armor class, melee/ranged bonuses and saving throw modifiers are available. Bonuses against particular attackers, save rolls and combat resolution remain pending.'
        : combat ? 'Base attack and base saves are available. Final combat rules are unavailable.' : 'Combat stat rules are unavailable.'] };
}

export function equipmentAbilityEffects(items,rules){
  const effects=[];
  for(const [index,item] of items.entries())for(const prop of item.data.PropertiesList??[]){
    if(![0,27].includes(prop.PropertyName)||prop.Subtype<0||prop.Subtype>5)continue;
    const table=rules.abilityCosts?.get(prop.PropertyName===0?1:21),row=table?.rows.get(prop.CostValue);
    if(!row||!Number.isFinite(Number(row.Value)))throw new Error('Unknown equipment ability modifier cost value');
    const amount=Math.max(0,Number(row.Value))|0;
    effects.push({type:prop.PropertyName===0?36:37,integers:[prop.Subtype,amount],sourceItemId:item.id??item.source??`equipment:${index}`,spellId:-1});
  }
  return effects;
}

export function equipmentAbilityBonuses(items, rules) {
  const bonuses = Object.fromEntries(ABILITIES.map(f => [f, 0])), penalties = { ...bonuses };
  // Native keeps the highest increase and decrease for each source item;
  // aggregates across items, then independently caps increases/decreases.
  for (const item of items) {
    const up = { ...bonuses }, down = { ...penalties };
    for (const f of ABILITIES) { up[f] = 0; down[f] = 0; }
    for (const prop of item.PropertiesList ?? []) {
      if (![0, 27].includes(prop.PropertyName) || prop.Subtype > 5 || prop.Subtype < 0) continue;
      const table = rules.abilityCosts?.get(prop.PropertyName === 0 ? 1 : 21);
      const row = table?.rows.get(prop.CostValue);
      if (!row || !Number.isFinite(Number(row.Value))) throw new Error('Unknown equipment ability modifier cost value');
      const field = ABILITIES[prop.Subtype], amount = Math.max(0, Number(row.Value));
      const group = prop.PropertyName === 0 ? up : down; group[field] = Math.max(group[field], amount);
    }
    for (const f of ABILITIES) { bonuses[f] += up[f]; penalties[f] += down[f]; }
  }
  return Object.fromEntries(ABILITIES.map(f => [f, Math.min(12, bonuses[f]) - Math.min(30, penalties[f])]));
}

export function experienceAward(stats, amount, rules) {
  if ((amount | 0) <= 0) return 0;
  if (stats.classes.length < 2) return amount >>> 0;
  const race = rules.racialtypes.rows.get(stats.race);
  let favored = number(race?.Favored, 255);
  if (favored === 255) {
    // Native excludes classes with a nonempty prerequisite table, then keeps
    // the first highest-level class. With none, class position zero survives.
    let best = stats.classes[0], level = 0;
    for (const c of stats.classes) if (c.level > level && (!rules.classes.rows.get(c.id)?.PreReqTable || rules.classes.rows.get(c.id).PreReqTable === '****')) { best = c; level = c.level; }
    favored = best.id;
  }
  const eligible = stats.classes.filter(c => c.id !== favored && number(rules.classes.rows.get(c.id)?.XPPenalty) === 1);
  const highest = Math.max(0, ...eligible.map(c => c.level));
  const penalties = eligible.filter(c => highest - c.level > 1).length;
  return Math.trunc(amount * (1 - penalties * 0.2)) >>> 0;
}

export function playerAppearance(root,{items}={}) {
  const result = { ...root, XPosition: 0, YPosition: 0, ZPosition: 0, XOrientation: 0, YOrientation: 1 };
  const armor = items===undefined?(root.Equip_ItemList ?? []).find(i => getGffStructType(i) === 2):items.find(i=>i.slot===2)?.data;
  if (armor) {
    for (const [key, value] of Object.entries(armor)) if (key.startsWith('ArmorPart_')) result[key.replace('ArmorPart_', 'BodyPart_')] = value;
    for (const material of ['Metal1', 'Metal2', 'Cloth1', 'Cloth2', 'Leather1', 'Leather2']) result[`Color_${material}`] = armor[`${material}Color`] ?? 0;
    result.ArmorPart_RFoot = armor.ArmorPart_RFoot ?? root.ArmorPart_RFoot;
  }
  result.BodyPart_RFoot ??= root.ArmorPart_RFoot;
  return result;
}

export function resolvePlayerModels(root, rules,options) {
  return resolveCreatureModels(playerAppearance(root,options), -1, { appearance: rules.appearance, racialTypes: rules.racialtypes, gender: rules.gender, phenotype: rules.phenotype });
}
