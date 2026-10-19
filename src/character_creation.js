import { ABILITIES, loadCharacterRules, parseCharacter } from './character.js';
import { parse2da } from './area.js';
import { RESOURCE_TYPE, decodeResourceText } from './resource_archive.js';
import { abilityModifier, rulesetInt } from './combat_stats.js';
import { parseGff } from './gff.js';
import { gffField as f, gffRecord as record, typedGff, writeGff, encodeGffText } from './gff_writer.js';
import { spellGainWithBonus } from './spell_book.js';

export const rows = table => (table?.orderedRows ?? [...(table?.rows?.values() ?? [])]);
export const cell = (row, key) => row?.[Object.keys(row).find(k => k.toLowerCase() === key.toLowerCase())];
export const num = (row, key, fallback = 0) => { const v = cell(row,key); return v === undefined || v === '****' || v === '' ? fallback : Number(v); };
const present = value => value && value !== '****';
const at = (table,id) => rows(table)[id];
export const classTable = (rules, cls, name) => rules.classTables.get(String(cell(cls,name)).toLowerCase());
const cfg = (rules,key,fallback) => rulesetInt(rules,`CHARGEN_${key}`,fallback);

export async function loadCreationRules(resolver) {
  const rules = await loadCharacterRules(resolver);
  rules.creationTables = new Map();
  const load = async name => {
    name = name.toLowerCase();
    if (!rules.creationTables.has(name)) rules.creationTables.set(name,parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA))));
    return rules.creationTables.get(name);
  };
  for (const name of ['packages','portraits','soundset','hen_familiar','hen_companion','chargenclothes']) rules[name] = await load(name);
  for (const race of rows(rules.racialtypes)) if (present(race.FeatsTable)) await load(race.FeatsTable);
  // Preferences/equipment belong to the selected active package, including HAK overrides.
  rules.loadCreationTable = load;
  rules.creationResolver = resolver;
  rules.creationPaletteSizes={};
  for(const [key,name]of [['skin','pal_skin01'],['hair','pal_hair01'],['tattoo1','pal_tattoo01'],['tattoo2','pal_tattoo01']]){
    const bytes=await resolver.getResource(name,RESOURCE_TYPE.TGA);if(bytes.byteLength<18)throw new Error(`Creation palette ${name} is truncated`);rules.creationPaletteSizes[key]=new DataView(bytes).getUint16(14,true);
  }
  return rules;
}

// CNWClass::GetIsAlignmentAllowed 140299900. The native arguments are
// good/evil (4/5/1) and law/chaos (2/3/1); restriction bits are not an enum.
export function creationAlignmentAllowed(cls, goodEvil, lawChaos) {
  const mask=num(cls,'AlignRestrict'), axes=num(cls,'AlignRstrctType');
  const ge = goodEvil < 31 ? 5 : goodEvil > 69 ? 4 : 1;
  const lc = lawChaos < 31 ? 3 : lawChaos > 69 ? 2 : 1;
  const matches = Boolean((axes&2) && (mask & (ge===5?16:ge===4?8:1)) || (axes&1) && (mask & (lc===2?2:lc===3?4:1)));
  return num(cls,'InvertRestrict') ? matches : !matches;
}

export function abilityPointCost(score,rules) {
  const min=cfg(rules,'BASE_ABILITY_MIN',8),max=cfg(rules,'BASE_ABILITY_MAX',18);
  if (!Number.isInteger(score)||score<min||score>max) return Infinity;
  let cost=0;
  for(let n=min+1;n<=score;n++) cost += n>cfg(rules,'ABILITY_COST_INCREMENT4',255)?4:n>cfg(rules,'ABILITY_COST_INCREMENT3',16)?3:n>cfg(rules,'ABILITY_COST_INCREMENT2',14)?2:1;
  return cost;
}

export function initialCreationDraft(rules) {
  const raceId=rows(rules.racialtypes).findIndex(r=>num(r,'PlayerRace')!==0);
  const classId=rows(rules.classes).findIndex(c=>num(c,'PlayerClass')!==0&&!present(c.PreReqTable));
  const d={gender:0,raceId,classId,goodEvil:50,lawChaos:50,abilities:Object.fromEntries(ABILITIES.map(a=>[a,cfg(rules,'BASE_ABILITY_MIN',8)])),
    skills:{},feats:[],known:{},memorized:{},domains:[],school:0,packageId:num(at(rules.classes,classId),'Package'),
    firstName:'',lastName:'',subrace:'',deity:'',biography:'',age:num(at(rules.racialtypes,raceId),'AGE',18),
    phenotype:0,head:1,clothes:0,skin:0,hair:0,tattoo1:0,tattoo2:0,portrait:'',soundset:0,familiar:0,familiarName:'',companion:0,companionName:''};
  const alignment=ALIGNMENTS.find(a=>creationAlignmentAllowed(at(rules.classes,classId),a.goodEvil,a.lawChaos));
  if(alignment)Object.assign(d,{goodEvil:alignment.goodEvil,lawChaos:alignment.lawChaos});
  return d;
}

export const ALIGNMENTS = ['Lawful Good','Neutral Good','Chaotic Good','Lawful Neutral','True Neutral','Chaotic Neutral','Lawful Evil','Neutral Evil','Chaotic Evil']
  .map((label,id)=>({id,label,goodEvil:[85,50,15][Math.floor(id/3)],lawChaos:[85,50,15][id%3]}));

export function creationAbilities(d,rules) {
  const race=at(rules.racialtypes,d.raceId),cls=at(rules.classes,d.classId),gain=at(classTable(rules,cls,'StatGainTable'),0);
  return Object.fromEntries(ABILITIES.map(a=>[a,d.abilities[a]+num(race,`${a}Adjust`)+num(gain,a)]));
}
export function initializeCreationAbilities(d,rules){
  const cls=at(rules.classes,d.classId),min=cfg(rules,'BASE_ABILITY_MIN',8);d.abilities=Object.fromEntries(ABILITIES.map(a=>[a,min]));
  const primary=num(cls,'SpellCaster')?ABILITIES.find(a=>a.toUpperCase()===String(cell(cls,'SpellcastingAbil')).toUpperCase()):null;
  if(primary)d.abilities[primary]+=Math.max(0,cfg(rules,'BASE_ABILITY_MIN_PRIMARY',11)-creationAbilities(d,rules)[primary]);
}
export function creationAbilityCanDecrease(d,rules,ability){
  const cls=at(rules.classes,d.classId),primary=num(cls,'SpellCaster')&&String(cell(cls,'SpellcastingAbil')).toUpperCase()===ability.toUpperCase();
  return d.abilities[ability]>cfg(rules,'BASE_ABILITY_MIN',8)&&(!primary||creationAbilities(d,rules)[ability]>cfg(rules,'BASE_ABILITY_MIN_PRIMARY',11));
}
export function creationPointBalance(d,rules){return num(at(rules.racialtypes,d.raceId),'AbilitiesPointBuyNumber',30)-ABILITIES.reduce((n,a)=>n+abilityPointCost(d.abilities[a],rules),0);}

// ValidateLevelUp 140418b80 first-level branch 140418dca..140418edb.
export function creationSkillBudget(d,rules){
  const race=at(rules.racialtypes,d.raceId),cls=at(rules.classes,d.classId),key=cell(race,'SkillPointModifierAbility'),ability=ABILITIES.find(a=>a.toUpperCase()===String(key).toUpperCase())??ABILITIES[Number(key)];
  const score=ability?creationAbilities(d,rules)[ability]:cfg(rules,'ABILITY_NEUTRAL_VALUE',10);
  return (Math.max(1,num(cls,'SkillPointBase')+abilityModifier(score,rules))+num(race,'ExtraSkillPointsPerLevel'))*num(race,'FirstLevelSkillPointsMultiplier',4);
}
export function creationSkillRule(d,rules,id){
  const skill=at(rules.skills,id),cls=at(rules.classes,d.classId),entry=rows(classTable(rules,cls,'SkillsTable')).find(r=>num(r,'SkillIndex',-1)===id);
  const allowed=Boolean(skill&&(num(skill,'AllClassesCanUse')||entry));
  const classSkill=Boolean(entry&&num(entry,'ClassSkill'));
  return{allowed,classSkill,cost:classSkill?1:2,max:Math.floor((1+cfg(rules,'SKILL_MAX_LEVEL_1_BONUS',3))/(classSkill?1:2))};
}
export function creationSkillBalance(d,rules){return creationSkillBudget(d,rules)-Object.entries(d.skills).reduce((n,[id,r])=>n+r*creationSkillRule(d,rules,Number(id)).cost,0);}

export function creationGrantedFeats(d,rules){
  const race=at(rules.racialtypes,d.raceId),cls=at(rules.classes,d.classId);
  const result=rows(rules.creationTables.get(String(race?.FeatsTable).toLowerCase())).map(r=>num(r,'FeatIndex',-1));
  // List=3 is granted. List=0/1/2 may have a GrantedOnLevel cell, but
  // IsGrantedFeat14029a130 deliberately does not grant those rows.
  result.push(...rows(classTable(rules,cls,'FeatsTable')).filter(r=>num(r,'List',-1)===3&&num(r,'GrantedOnLevel',-1)===1).map(r=>num(r,'FeatIndex',-1)));
  if(num(cls,'PickDomains')) for(const id of d.domains)result.push(num(at(rules.domains,id),'GrantedFeat',-1));
  return[...new Set(result.filter(id=>id>=0&&at(rules.feat,id)&&present(cell(at(rules.feat,id),'Feat'))))];
}
export function creationFeatSlots(d,rules){
  const race=at(rules.racialtypes,d.raceId),cls=at(rules.classes,d.classId);
  return{normal:num(race,'NumberNormalFeatsEveryNthLevel',1)+num(race,'ExtraFeatsAtFirstLevel'),bonus:num(at(classTable(rules,cls,'BonusFeatsTable'),0),'Bonus')};
}

export function creationFeatListAllows(d,rules,id,kind){
  const feat=at(rules.feat,id),cls=at(rules.classes,d.classId),entry=rows(classTable(rules,cls,'FeatsTable')).find(r=>num(r,'FeatIndex',-1)===id);
  if(!feat||!present(cell(feat,'Feat')))return false;
  const list=num(entry,'List',-1);
  return kind==='bonus'?list===1||list===2:Boolean(list===0||list===1||num(feat,'AllClassesCanUse')&&list!==2);
}

// Shared first-level view of FeatRequirementsMet1403f2a40 and the
// AfterLevelUp variant. Prerequisites see racial/class ability adjustments,
// purchased ranks, automatic grants and choices made in earlier slots.
export function creationFeatRequirements(d,rules,id,owned=creationGrantedFeats(d,rules)){
  const feat=at(rules.feat,id),cls=at(rules.classes,d.classId),abilities=creationAbilities(d,rules),has=n=>owned.includes(n);
  if(!feat||!present(cell(feat,'Feat')))return 'Invalid feat';
  if(has(id)&&!num(feat,'GainMultiple'))return 'Already acquired';
  for(const a of ABILITIES)if(abilities[a]<num(feat,`MIN${a.toUpperCase()}`))return `${a} ${num(feat,`MIN${a.toUpperCase()}`)} required`;
  const bab=num(at(classTable(rules,cls,'AttackBonusTable'),0),'BAB');
  if(bab<num(feat,'MINATTACKBONUS'))return `Base attack ${num(feat,'MINATTACKBONUS')} required`;
  if(num(feat,'MinLevel')>1||num(feat,'MaxLevel')>0&&num(feat,'MaxLevel')<1)return 'Level requirement';
  const minClass=num(feat,'MinLevelClass',255);if(num(feat,'MinLevel')>0&&minClass!==255&&minClass!==d.classId)return 'Class requirement';
  const fort=num(at(classTable(rules,cls,'SavingThrowTable'),0),'FortSave')+abilityModifier(abilities.Con,rules);
  if(fort<num(feat,'MinFortSave'))return 'Fortitude requirement';
  if(num(feat,'PreReqEpic')&&!has(1001))return 'Epic character required';
  for(const key of ['PREREQFEAT1','PREREQFEAT2']){const n=num(feat,key,-1);if(n>=0&&n!==65535&&!has(n))return `Feat ${n} required`;}
  const ors=Array.from({length:5},(_,i)=>num(feat,`OrReqFeat${i}`,-1)).filter(n=>n>=0&&n!==65535);
  if(ors.length&&!ors.some(has))return 'Prerequisite feat required';
  for(const suffix of ['','2']){const skill=num(feat,`REQSKILL${suffix}`,-1);if(skill>=0&&skill!==65535&&(!creationSkillRule(d,rules,skill).allowed||(d.skills[skill]??0)<num(feat,`ReqSkillMinRanks${suffix}`)))return 'Skill ranks required';}
  const spellLevel=num(feat,'MINSPELLLVL');
  if(spellLevel>0){const ability=ABILITIES.find(a=>a.toUpperCase()===cell(cls,'SpellcastingAbil')),gain=at(classTable(rules,cls,'SpellGainTable'),0);
    if(!num(cls,'SpellCaster')||!ability||abilities[ability]<10+spellLevel||num(gain,`SpellLevel${spellLevel}`,-1)<0)return 'Spellcasting level required';}
  return null;
}

export function creationSpellOptions(d,rules,level){
  const cls=at(rules.classes,d.classId),opposition=cell(at(rules.spellschools,d.school),'Opposition'),opposed=present(opposition)?cell(at(rules.spellschools,Number(opposition)),'Letter'):null;
  return rows(rules.spells).flatMap((r,id)=>num(r,cell(cls,'SpellTableColumn'),255)===level&&present(r.Name)&&num(r,'UserType',1)===1&&(!present(r.Master)||num(r,'Master',-1)===id)&&(!num(cls,'PickSchool')||!opposed||r.School!==opposed)?[{id,row:r}]:[]);
}
export function creationSpellCount(d,rules,level){
  const cls=at(rules.classes,d.classId),gain=at(classTable(rules,cls,'SpellGainTable'),0),known=at(classTable(rules,cls,'SpellKnownTable'),0);
  if(!num(cls,'SpellCaster')||num(cls,'SkipSpellSelection')||level>=num(gain,'NumSpellLevels'))return 0;
  if(!num(cls,'SpellbookRestricted'))return 0;
  if(num(cls,'LearnScroll'))return level===0?creationSpellOptions(d,rules,0).length:level===1?3+Math.max(0,abilityModifier(creationAbilities(d,rules).Int,rules)):0;
  return num(known,`SpellLevel${level}`);
}

export function creationSpellSlots(d,rules,level){
  const cls=at(rules.classes,d.classId);if(!num(cls,'SpellCaster'))return 0;
  const values=creationAbilities(d,rules),actor={authored:{ClassList:[{Class:d.classId,ClassLevel:1,School:d.school}]}};
  return spellGainWithBonus(actor,0,level,rules,{
    abilityScore:(_o,index)=>values[ABILITIES[index]],abilityBonus:()=>0,abilityModifier:(_o,index)=>abilityModifier(values[ABILITIES[index]],rules),
    arcaneClass:()=>num(cls,'Arcane'),classSpellGain:(_id,_level,l)=>{const gain=at(classTable(rules,cls,'SpellGainTable'),0);return l<num(gain,'NumSpellLevels')?num(gain,`SpellLevel${l}`,255):255;}
  });
}
export function creationPreparedOptions(d,rules,level,domain=false){
  if(domain)return[...new Set(d.domains.map(id=>num(at(rules.domains,id),`Level_${level}`,-1)).filter(id=>id>=0&&at(rules.spells,id)))];
  const cls=at(rules.classes,d.classId),options=creationSpellOptions(d,rules,level).map(s=>s.id);
  return num(cls,'SpellbookRestricted')?options.filter(id=>(d.known[level]??[]).includes(id)):options;
}

export function creationPortraits(d,rules){return rows(rules.portraits).flatMap((r,id)=>present(r.BaseResRef)&&num(r,'Plot')===0&&num(r,'Sex',4)===d.gender?[{id,row:r,resref:`po_${r.BaseResRef}`.toLowerCase()}]:[]);}
export function creationVoices(d,rules){return rows(rules.soundset).flatMap((r,id)=>num(r,'TYPE',-1)===0&&num(r,'GENDER',-1)===d.gender?[{id,row:r}]:[]);}
export function creationPhenotypes(rules){return rows(rules.phenotype).flatMap((row,id)=>cfg(rules,'ENABLED_PHENOTYPES',5)&(1<<id)?[{id,row}]:[]);}
// InitializeClothesVariations1408e8410: exact optional class, race, gender
// cells and a two-letter alignment (true neutral is TN).
export function creationClothes(d,rules){
  const alignment=(d.lawChaos>69?'L':d.lawChaos<31?'C':'N')+(d.goodEvil>69?'G':d.goodEvil<31?'E':'N'),code=alignment==='NN'?'TN':alignment;
  return rows(rules.chargenclothes).flatMap((row,id)=>present(row.ItemResRef)&&(!present(row.ClassRestrict)||Number(row.ClassRestrict)===d.classId)&&(!present(row.RaceRestrict)||Number(row.RaceRestrict)===d.raceId)&&(!present(row.GenderRestrict)||Number(row.GenderRestrict)===d.gender)&&(!present(row.AlignmentRestrict)||row.AlignmentRestrict===code)?[{id,row}]:[]);
}

export function creationHeadModels(d,rules){
  const race=at(rules.racialtypes,d.raceId),appearance=at(rules.appearance,num(race,'Appearance')),gender=at(rules.gender,d.gender),prefix=`p${gender?.GENDER}${appearance?.RACE}${d.phenotype}_head`.toLowerCase();
  const resolver=rules.creationResolver,keys=[...resolver.key.resources.keys(),...resolver.module.entries.keys(),...resolver.haks.flatMap(h=>[...h.entries.keys()])];
  return[...new Set(keys.filter(k=>k.startsWith(prefix)&&k.endsWith(`:${RESOURCE_TYPE.MDL}`)).map(k=>Number(k.slice(prefix.length,k.lastIndexOf(':')))).filter(n=>n>0&&n<=255))].sort((a,b)=>a-b);
}

export function creationErrors(d,rules){
  const errors=[],race=at(rules.racialtypes,d.raceId),cls=at(rules.classes,d.classId);
  if(!race||!num(race,'PlayerRace'))errors.push('Select a playable race');
  if(!cls||!num(cls,'PlayerClass')||present(cls.PreReqTable))errors.push('Select an available first-level class');
  if(!ALIGNMENTS.some(a=>a.goodEvil===d.goodEvil&&a.lawChaos===d.lawChaos)||!creationAlignmentAllowed(cls,d.goodEvil,d.lawChaos))errors.push('Alignment is not allowed for this class');
  if(creationPointBalance(d,rules)!==0)errors.push('Spend all ability points');
  const primary=num(cls,'SpellCaster')?ABILITIES.find(a=>a.toUpperCase()===String(cls?.SpellcastingAbil).toUpperCase()):null;
  if(primary&&creationAbilities(d,rules)[primary]<cfg(rules,'BASE_ABILITY_MIN_PRIMARY',11))errors.push(`${primary} must be at least ${cfg(rules,'BASE_ABILITY_MIN_PRIMARY',11)}`);
  if(creationSkillBalance(d,rules)<0)errors.push('Too many skill points spent');
  for(const[id,rank]of Object.entries(d.skills)){const s=creationSkillRule(d,rules,Number(id));if(!Number.isInteger(rank)||rank<0||rank>s.max||rank&&!s.allowed)errors.push(`Invalid skill ${id} ranks`);}
  const slots=creationFeatSlots(d,rules),owned=creationGrantedFeats(d,rules),counts={normal:0,bonus:0};
  for(const choice of d.feats){if(!Object.hasOwn(counts,choice.kind)||!creationFeatListAllows(d,rules,choice.id,choice.kind)){errors.push('Invalid feat selection');continue;}counts[choice.kind]++;const reason=creationFeatRequirements(d,rules,choice.id,owned);if(reason)errors.push(`Feat ${choice.id}: ${reason}`);owned.push(choice.id);}
  if(counts.normal!==slots.normal||counts.bonus!==slots.bonus)errors.push('Select every available feat');
  if(num(cls,'PickDomains')&&(d.domains.length!==2||new Set(d.domains).size!==2||d.domains.some(id=>!at(rules.domains,id))))errors.push('Choose two different domains');
  if(num(cls,'PickSchool')&&!at(rules.spellschools,d.school))errors.push('Choose a spell school');
  for(let l=0;l<10;l++){const selected=d.known[l]??[],count=creationSpellCount(d,rules,l),allowed=new Set(creationSpellOptions(d,rules,l).map(s=>s.id));if(selected.length!==count||new Set(selected).size!==selected.length||selected.some(id=>!allowed.has(id)))errors.push(`Choose ${count} valid level ${l} spells`);}
  for(const [level,prepared]of Object.entries(d.memorized)){const l=Number(level),slots=creationSpellSlots(d,rules,l);if(!num(cls,'MemorizesSpells')||l<0||l>9||!Array.isArray(prepared)||prepared.length>slots)errors.push('Invalid prepared spell slots');else for(const [slot,id]of prepared.entries()){if(id===null||id===undefined)continue;const domain=Boolean(num(cls,'PickDomains')&&l>0&&slot===slots-1);if(!creationPreparedOptions(d,rules,l,domain).includes(id))errors.push(`Invalid prepared level ${l} spell`);}}
  if(!d.firstName.trim())errors.push('Enter a first name');
  for(const name of ['firstName','lastName','subrace','deity','biography','familiarName','companionName'])try{const bytes=encodeGffText(d[name]);if(name!=='biography'&&bytes.length>32)errors.push(`${name} is too long`);}catch(e){errors.push(e.message);}
  if(!Number.isInteger(d.age)||d.age<1||d.age>0x7fffffff)errors.push('Enter a valid age');
  if(!creationPortraits(d,rules).some(p=>p.resref===d.portrait))errors.push('Choose a portrait');
  if(!creationVoices(d,rules).some(v=>v.id===d.soundset))errors.push('Choose a voice');
  if(!creationPhenotypes(rules).some(p=>p.id===d.phenotype))errors.push('Choose a body type');
  if(!creationHeadModels(d,rules).includes(d.head))errors.push('Choose an available head');
  if(!creationClothes(d,rules).some(c=>c.id===d.clothes))errors.push('Choose available clothing');
  for(const k of ['skin','hair','tattoo1','tattoo2'])if(!Number.isInteger(d[k])||d[k]<0||d[k]>=Math.min(256,rules.creationPaletteSizes?.[k]??176))errors.push(`Invalid ${k} colour`);
  const pkg=at(rules.packages,d.packageId);if(!pkg||num(pkg,'ClassID',-1)!==d.classId||!num(pkg,'PlayerClass'))errors.push('Choose a class package');
  if(owned.includes(303)&&(!at(rules.hen_familiar,d.familiar)||!d.familiarName.trim()))errors.push('Choose and name a familiar');
  if(owned.includes(199)&&(!at(rules.hen_companion,d.companion)||!d.companionName.trim()))errors.push('Choose and name an animal companion');
  return [...new Set(errors)];
}

export function recommendAbilities(d,rules){
  const cls=at(rules.classes,d.classId),min=cfg(rules,'BASE_ABILITY_MIN',8);d.abilities=Object.fromEntries(ABILITIES.map(a=>[a,min]));
  // Active class preferences supply targets; fit them within the active race's budget.
  const ordered=[...ABILITIES].sort((a,b)=>num(cls,b)-num(cls,a));
  let changed=true;while(changed){changed=false;for(const a of ordered){const next=d.abilities[a]+1,delta=abilityPointCost(next,rules)-abilityPointCost(next-1,rules);if(next<=num(cls,a,min)&&delta<=creationPointBalance(d,rules)){d.abilities[a]=next;changed=true;}}}
  while(creationPointBalance(d,rules)>0){const a=ordered.find(a=>abilityPointCost(d.abilities[a]+1,rules)-abilityPointCost(d.abilities[a],rules)<=creationPointBalance(d,rules));if(!a)break;d.abilities[a]++;}
}
export async function recommendCreation(d,rules){
  const pkg=at(rules.packages,d.packageId),cls=at(rules.classes,d.classId);
  const preference=async(field,column)=>present(pkg?.[field])?rows(await rules.loadCreationTable(pkg[field])).map(r=>num(r,column,-1)).filter(n=>n>=0):[];
  recommendAbilities(d,rules);
  if(num(cls,'PickDomains'))d.domains=[num(pkg,'Domain1',0),num(pkg,'Domain2',1)];
  if(num(cls,'PickSchool'))d.school=num(pkg,'School');
  const skillOrder=[...new Set([...await preference('SkillPref2DA','SkillIndex'),...rows(rules.skills).map((_,i)=>i)])];
  d.skills={};for(const id of skillOrder){const s=creationSkillRule(d,rules,id);if(!s.allowed||num(at(rules.skills,id),'HideFromLevelUp'))continue;d.skills[id]=Math.min(s.max,Math.floor(creationSkillBalance(d,rules)/s.cost));}
  d.feats=[];const featOrder=[...new Set([...await preference('FeatPref2DA','FeatIndex'),...rows(rules.feat).map((_,i)=>i)])],slots=creationFeatSlots(d,rules);
  // Fill constrained class bonus slots first, retaining explicit slot attribution.
  for(const kind of ['bonus','normal'])for(let i=0;i<slots[kind];i++){const owned=[...creationGrantedFeats(d,rules),...d.feats.map(f=>f.id)],id=featOrder.find(id=>creationFeatListAllows(d,rules,id,kind)&&!creationFeatRequirements(d,rules,id,owned));if(id!==undefined)d.feats.push({id,kind});}
  const spellOrder=await preference('SpellPref2DA','SpellIndex');
  d.known={};for(let l=0;l<10;l++){const options=creationSpellOptions(d,rules,l).map(s=>s.id);d.known[l]=[...new Set([...spellOrder.filter(id=>options.includes(id)),...options])].slice(0,creationSpellCount(d,rules,l));}
  d.memorized={};if(num(cls,'MemorizesSpells'))for(let l=0;l<10;l++){const count=creationSpellSlots(d,rules,l);d.memorized[l]=Array.from({length:count},(_,slot)=>{const options=creationPreparedOptions(d,rules,l,Boolean(num(cls,'PickDomains')&&l>0&&slot===count-1)),ordered=[...new Set([...spellOrder.filter(id=>options.includes(id)),...options])];return ordered[slot%ordered.length]??null;});}
  d.portrait=creationPortraits(d,rules).find(p=>num(p.row,'Race',-1)===d.raceId)?.resref??creationPortraits(d,rules)[0]?.resref??'';
  d.soundset=creationVoices(d,rules)[0]?.id??0;
  d.head=creationHeadModels(d,rules)[0]??1;
  d.clothes=creationClothes(d,rules)[0]?.id??0;
  d.familiar=num(pkg,'Associate');d.companion=num(pkg,'Associate');d.familiarName||='Familiar';d.companionName||='Companion';
}

const list=(entries,type)=>f(15,entries.map(e=>record(e,type)));
export async function createCharacterBic(d,rules){
  const errors=creationErrors(d,rules);if(errors.length)throw new Error(errors.join('\n'));
  const cls=at(rules.classes,d.classId),race=at(rules.racialtypes,d.raceId),pkg=at(rules.packages,d.packageId),hp=num(cls,'HitDie');
  const feats=[...creationGrantedFeats(d,rules),...d.feats.map(e=>e.id)],skillEntries=rows(rules.skills).map((_,id)=>({Rank:f(0,d.skills[id]??0)})),featEntries=feats.map(id=>({Feat:f(2,id)}));
  // ReadStatsFromGff uses typed INT/SHORT readers. BYTE/WORD fields with the
  // same numeric values are rejected and fall back to the native defaults.
  const c={Class:f(5,d.classId),ClassLevel:f(3,1),School:f(0,d.school),Domain1:f(0,d.domains[0]??0),Domain2:f(0,d.domains[1]??0)};
  const history={LvlStatHitDie:f(0,hp),LvlStatClass:f(0,d.classId),EpicLevel:f(0,0),SkillPoints:f(2,creationSkillBalance(d,rules)),SkillList:list(skillEntries,0),FeatList:list(featEntries,0)};
  for(let level=0;level<10;level++){
    const known=(d.known[level]??[]).map(id=>({Spell:f(2,id)}));
    if(known.length){c[`KnownList${level}`]=list(known,3);history[`KnownList${level}`]=list(known,0);}
    const count=creationSpellSlots(d,rules,level);
    if(num(cls,'MemorizesSpells')&&count){
      c[`MemorizedList${level}`]=list(Array.from({length:count},(_,slot)=>{const id=d.memorized[level]?.[slot];return{Spell:f(2,id??65535),Ready:f(0,id===null||id===undefined?0:1),SpellMetaMagic:f(0,0),...(num(cls,'PickDomains')&&level>0&&slot===count-1?{DomainSpell:f(0,1)}:{})};}),3);
    }
  }
  if(num(cls,'SpellCaster')&&!num(cls,'MemorizesSpells'))c.SpellsPerDayList=list(Array.from({length:10},(_,l)=>({NumSpellsLeft:f(0,creationSpellSlots(d,rules,l))})),0x4567);
  const fields={FirstName:f(12,d.firstName.trim()),LastName:f(12,d.lastName.trim()),Description:f(12,d.biography),IsPC:f(0,1),IsDM:f(0,0),
    Gender:f(0,d.gender),Race:f(0,d.raceId),Age:f(5,d.age),Subrace:f(10,d.subrace),Deity:f(10,d.deity),StartingPackage:f(0,d.packageId),
    Tag:f(10,''),Conversation:f(11,''),Interruptable:f(0,1),Disarmable:f(0,1),IsCommandable:f(0,1),IsDestroyable:f(0,1),IsRaiseable:f(0,1),
    Experience:f(4,0),Gold:f(4,num(pkg,'Gold')),HitPoints:f(3,hp),CurrentHitPoints:f(3,hp),MaxHitPoints:f(3,hp),NaturalAC:f(0,0),
    GoodEvil:f(0,d.goodEvil),LawfulChaotic:f(0,d.lawChaos),FactionID:f(2,0),Appearance_Type:f(2,num(race,'Appearance')),Appearance_Head:f(0,d.head),
    Phenotype:f(5,d.phenotype),Color_Skin:f(0,d.skin),Color_Hair:f(0,d.hair),Color_Tattoo1:f(0,d.tattoo1),Color_Tattoo2:f(0,d.tattoo2),
    SoundSetFile:f(2,d.soundset),Portrait:f(11,d.portrait),MovementRate:f(0,0),XPosition:f(8,0),YPosition:f(8,0),ZPosition:f(8,0),XOrientation:f(8,0),YOrientation:f(8,1),
    SkillPoints:f(2,creationSkillBalance(d,rules)),SkillList:list(skillEntries,0),FeatList:list(featEntries,1),ClassList:f(15,[record(c,2)]),LvlStatList:f(15,[record(history,0)]),
    FamiliarType:f(5,d.familiar),FamiliarName:f(10,d.familiarName),CompanionType:f(5,d.companion),CompanionName:f(10,d.companionName)};
  for(const a of ABILITIES)fields[a]=f(0,d.abilities[a]);
  for(const part of ['Neck','Torso','Pelvis','LBicep','LFArm','LHand','LThigh','LShin','LFoot','RBicep','RFArm','RHand','RThigh','RShin'])fields[`BodyPart_${part}`]=f(0,1);
  fields.ArmorPart_RFoot=f(0,1);
  // Use active UTI resources, never copy a high-level BIC/preset's possessions.
  const items=[];
  if(present(pkg.Equip2DA))for(const entry of rows(await rules.loadCreationTable(pkg.Equip2DA))){
    if(!present(entry.Label))continue;
    const item=typedGff(parseGff(await rules.creationResolver.getResource(entry.Label,RESOURCE_TYPE.UTI),'UTI ').root,0);
    delete item.fields.ObjectId;item.fields.Identified=f(0,1);items.push(item);
  }
  const clothes=at(rules.chargenclothes,d.clothes),equipped=typedGff(parseGff(await rules.creationResolver.getResource(clothes.ItemResRef,RESOURCE_TYPE.UTI),'UTI ').root,2);
  delete equipped.fields.ObjectId;equipped.fields.Identified=f(0,1);
  fields.ItemList=f(15,items);fields.Equip_ItemList=f(15,[equipped]);
  const bytes=writeGff('BIC ',record(fields));parseCharacter(bytes);return bytes;
}
