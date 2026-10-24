import {ABILITIES} from './character.js';
import {rows,cell,num,classTable,creationFeatListAllows,creationSpellOptions} from './character_creation.js';
import {parse2da} from './area.js';
import {decodeResourceText,RESOURCE_TYPE} from './resource_archive.js';
import {abilityModifier,rulesetInt} from './combat_stats.js';
import {featAbilityDeltas} from './feat_ability_bonuses.js';
const at=(t,id)=>rows(t)[id],valid=v=>v!==undefined&&v!==''&&v!=='****';
// The wizard needs progression rules, not the complete combat/item ruleset.
// Bound concurrent IPC reads; custom servers can define hundreds of classes.
export async function loadLevelUpRules(resolver){
 const read=async name=>parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));
 const r=Object.fromEntries(await Promise.all(['racialtypes','classes','skills','feat','spells','ruleset','exptable','masterfeats','hen_familiar','hen_companion','spellschools','domains'].map(async name=>{
  try{return[name,await read(name)];}catch(error){if(!['spellschools','domains'].includes(name))throw error;return[name,null];}
 })));
 const names=[...new Set(rows(r.classes).flatMap(row=>['StatGainTable','SpellGainTable','SpellKnownTable','AttackBonusTable','SavingThrowTable','SkillsTable','FeatsTable','BonusFeatsTable'].map(field=>String(cell(row,field)??'****').toLowerCase())).filter(name=>name&&name!=='****'))];
 r.classTables=new Map();let next=0;
 await Promise.all(Array.from({length:Math.min(12,names.length)},async()=>{while(next<names.length){const name=names[next++];r.classTables.set(name,await read(name));}}));
 return r;
}
export const levelUpTotal=s=>s.classes.reduce((n,c)=>n+c.level,0);
export const levelUpClassLevel=(s,id)=>s.classes.find(c=>c.id===id)?.level??0;
export function initialLevelUpDraft(s,classId){const c=s.classes.find(c=>c.id===classId);return{classId,ability:6,skills:Array(s.skills.length).fill(0),feats:[],known:{},removed:{},domains:[...(c?.domains??[])],school:c?.school??0,fieldE34:s.fieldE34,fieldE48:s.fieldE48,fieldE30:s.fieldE30,fieldE38:s.fieldE38};}
export function levelUpAbilities(s,d,r){
 const deltas=featAbilityDeltas(d.feats.map(f=>({Feat:f.id})),0,{hasFeat:(list,id)=>Number(list.some(f=>f.Feat===id)),rule:(label,fallback)=>rulesetInt(r,label,fallback)});
 return Object.fromEntries(ABILITIES.map((a,i)=>{let gain=0;for(const c of s.classes){const table=classTable(r,at(r.classes,c.id),'StatGainTable');for(let l=0;l<c.level;l++)gain+=num(at(table,l),a);}gain+=num(at(classTable(r,at(r.classes,d.classId),'StatGainTable'),levelUpClassLevel(s,d.classId)),a);return[a,s.baseAbilities[i]+num(at(r.racialtypes,s.race),a+'Adjust')+gain+(d.ability===i?1:0)+deltas[i]];}));
}
//418b80 adds the race's per-level modifier after max(1,class base+modifier).
// Existing ranks are the server's unmodified GetSkillRank(...,1), not the
// character-sheet totals, which contain equipment/ability/effect adjustments.
export function levelUpSkillBudget(s,d,r){const race=at(r.racialtypes,s.race),key=cell(race,'SkillPointModifierAbility'),a=ABILITIES.find(a=>a.toUpperCase()===String(key).toUpperCase())??ABILITIES[Number(key)],score=a?levelUpAbilities(s,d,r)[a]:10;return s.fieldDC6+Math.max(1,num(at(r.classes,d.classId),'SkillPointBase')+abilityModifier(score,r))+num(race,'ExtraSkillPointsPerLevel');}
export function levelUpSkillRule(s,d,r,id){const skill=at(r.skills,id),entry=rows(classTable(r,at(r.classes,d.classId),'SkillsTable')).find(row=>num(row,'SkillIndex',-1)===id),classSkill=Boolean(entry&&num(entry,'ClassSkill'));return{allowed:Boolean(skill&&(entry||num(skill,'AllClassesCanUse'))),classSkill,cost:classSkill?1:2,max:Math.floor((levelUpTotal(s)+4)/(classSkill?1:2))};}
export function levelUpSkillBalance(s,d,r){return levelUpSkillBudget(s,d,r)-d.skills.reduce((n,rank,id)=>n+rank*levelUpSkillRule(s,d,r,id).cost,0);}
export function levelUpGrantedFeats(s,d,r){const cls=at(r.classes,d.classId),level=levelUpClassLevel(s,d.classId)+1,feats=rows(classTable(r,cls,'FeatsTable')).filter(row=>num(row,'List',-1)===3&&num(row,'GrantedOnLevel',-1)===level).map(row=>num(row,'FeatIndex',-1));if(levelUpTotal(s)===20)feats.push(1001);if(level===1&&num(cls,'PickDomains'))for(const domain of d.domains)feats.push(num(at(r.domains,domain),'GrantedFeat',-1));return[...new Set(feats.filter(id=>id>=0&&at(r.feat,id)&&!s.feats.includes(id)))];}
export function levelUpFeatSlots(s,d,r){const race=at(r.racialtypes,s.race),every=num(race,'NormalFeatEveryNthLevel',3),next=levelUpTotal(s)+1;return{normal:every&&next%every===0?num(race,'NumberNormalFeatsEveryNthLevel',1):0,bonus:num(at(classTable(r,at(r.classes,d.classId),'BonusFeatsTable'),levelUpClassLevel(s,d.classId)),'Bonus')};}
export function levelUpFeatRequirement(s,d,r,id,chosen=d.feats){
 const feat=at(r.feat,id),cls=at(r.classes,d.classId),owned=new Set([...s.feats,...levelUpGrantedFeats(s,d,r),...chosen.map(f=>f.id)]),has=n=>owned.has(n),abilities=levelUpAbilities(s,{...d,feats:chosen},r),level=levelUpTotal(s)+1,classLevel=levelUpClassLevel(s,d.classId)+1;
 if(!feat||!valid(cell(feat,'FEAT')))return'Invalid feat';if(has(id))return'Already acquired';
 const granted=rows(classTable(r,cls,'FeatsTable')).find(row=>num(row,'FeatIndex',-1)===id),grantLevel=num(granted,'GrantedOnLevel',255);if(grantLevel!==255&&grantLevel>classLevel)return'Class level requirement';
 for(const a of ABILITIES)if(abilities[a]<num(feat,'MIN'+a.toUpperCase()))return`${a} ${num(feat,'MIN'+a.toUpperCase())} required`;
 const levels=s.classes.map(c=>({...c}));const c=levels.find(c=>c.id===d.classId);if(c)c.level++;else levels.push({id:d.classId,level:1});
 let bab=0,fort=abilityModifier(abilities.Con,r);for(const c of levels){const row=at(r.classes,c.id);bab+=num(at(classTable(r,row,'AttackBonusTable'),Math.min(c.level,20)-1),'BAB');fort+=num(at(classTable(r,row,'SavingThrowTable'),Math.min(c.level,20)-1),'FortSave');}
 if(bab<num(feat,'MINATTACKBONUS'))return'Base attack requirement';
 const minClass=num(feat,'MinLevelClass',255);if(level<num(feat,'MinLevel')||num(feat,'MaxLevel')>0&&level>num(feat,'MaxLevel')||num(feat,'MinLevel')>0&&minClass!==255&&(levels.find(c=>c.id===minClass)?.level??0)<num(feat,'MinLevel'))return'Level requirement';
 if(fort<num(feat,'MinFortSave'))return'Fortitude requirement';if(num(feat,'PreReqEpic')&&!has(1001))return'Epic character required';
 for(const key of ['PREREQFEAT1','PREREQFEAT2']){const n=num(feat,key,-1);if(n>=0&&n!==65535&&!has(n))return'Prerequisite feat required';}
 const or=Array.from({length:5},(_,i)=>num(feat,'OrReqFeat'+i,-1)).filter(n=>n>=0&&n!==65535);if(or.length&&!or.some(has))return'Prerequisite feat required';
 for(const suffix of['','2']){const id=num(feat,'REQSKILL'+suffix,-1);if(id>=0&&id!==65535&&((s.skills[id]??0)+(d.skills[id]??0)<num(feat,'ReqSkillMinRanks'+suffix)||!levelUpSkillRule(s,d,r,id).allowed))return'Skill ranks required';}
 const spell=num(feat,'MINSPELLLVL');if(spell&&!levels.some(c=>{const row=at(r.classes,c.id),key=ABILITIES.find(a=>a.toUpperCase()===cell(row,'SpellcastingAbil'));return num(row,'SpellCaster')&&key&&abilities[key]>=10+spell&&num(at(classTable(r,row,'SpellGainTable'),c.level-1),'SpellLevel'+spell,255)<255;}))return'Spellcasting level required';return null;
}
export const levelUpFeatAllows=(d,r,id,kind)=>creationFeatListAllows(d,r,id,kind)&&!num(at(r.feat,id),'HideFromLevelUp');
export function levelUpSpellOptions(s,d,r,l){const position=s.classes.findIndex(c=>c.id===d.classId),known=s.spellbooks[position]?.known??[];return creationSpellOptions(d,r,l).filter(spell=>!known.includes(spell.id)||(d.removed[l]??[]).includes(spell.id));}
export function levelUpSpellCount(s,d,r,l){const cls=at(r.classes,d.classId),current=levelUpClassLevel(s,d.classId),next=current+1,gain=at(classTable(r,cls,'SpellGainTable'),next-1);if(!num(cls,'SpellCaster')||num(cls,'SkipSpellSelection')||!num(cls,'SpellbookRestricted')||l>=num(gain,'NumSpellLevels'))return 0;
 if(num(cls,'LearnScroll'))return current===0?(l===0?levelUpSpellOptions(s,d,r,0).length:l===1?3+Math.max(0,abilityModifier(levelUpAbilities(s,d,r).Int,r)):0):l===0?0:2;
 const table=classTable(r,cls,'SpellKnownTable'),position=s.classes.findIndex(c=>c.id===d.classId),known=s.spellbooks[position]?.known??[],column=cell(cls,'SpellTableColumn'),count=known.filter(id=>num(at(r.spells,id),column,255)===l).length;return Math.max(0,num(at(table,next-1),'SpellLevel'+l)-count)+(d.removed[l]?.length??0);
}
export function levelUpErrors(s,d,r){const errors=[],cls=at(r.classes,d.classId);if((levelUpTotal(s)+1)%4===0&&d.ability===6)errors.push('Choose an ability increase');if(levelUpSkillBalance(s,d,r)<0)errors.push('Too many skill points spent');for(const[id,change]of d.skills.entries()){const rule=levelUpSkillRule(s,d,r,id);if(!Number.isInteger(change)||change<0||change>127||change&&(!rule.allowed||s.skills[id]+change>rule.max))errors.push('Invalid skill ranks');}
 const slots=levelUpFeatSlots(s,d,r),chosen=[];for(const f of d.feats){if(!levelUpFeatAllows(d,r,f.id,f.kind)||levelUpFeatRequirement(s,d,r,f.id,chosen))errors.push('Invalid feat selection');chosen.push(f);}for(const kind of ['normal','bonus'])if(d.feats.filter(f=>f.kind===kind).length!==slots[kind])errors.push('Choose every available feat');
 if(num(cls,'PickDomains')&&(d.domains.length!==2||new Set(d.domains).size!==2))errors.push('Choose two different domains');
 // Scroll-learning classes choose a shared pool of new spells across levels.
 if(num(cls,'LearnScroll')&&levelUpClassLevel(s,d.classId)>0){const total=Object.values(d.known).reduce((n,list)=>n+list.length,0);if(total!==2)errors.push('Choose two new spells');}
 else for(let l=0;l<10;l++)if((d.known[l]?.length??0)!==levelUpSpellCount(s,d,r,l))errors.push(`Choose level ${l} spells`);
 for(let l=0;l<10;l++){const allowed=new Set(levelUpSpellOptions(s,d,r,l).map(s=>s.id)),chosen=d.known[l]??[];if(new Set(chosen).size!==chosen.length||chosen.some(id=>!allowed.has(id)))errors.push('Invalid spell selection');}return[...new Set(errors)];
}
export function levelUpProposal(s,d,r){const errors=levelUpErrors(s,d,r);if(errors.length)throw Error(errors.join('; '));return{...structuredClone(d),hitDie:d.hitDie,skillPoints:levelUpSkillBalance(s,d,r),feats:[...levelUpGrantedFeats(s,d,r),...d.feats.map(f=>f.id)]};}
