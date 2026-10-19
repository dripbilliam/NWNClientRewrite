import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {spellClassInfo} from './spell_book.js';
import {saveCreatureClassInfo} from './creature_class_save.js';

// Adapter for SaveStats/SaveCreature. creatureData owns mutable base state;
// nativeTalentClasses/featUsePool/nativeSpellLikeAbilities own live resources.
// This is only the class-info portion of a UTC/BIC, not a complete export.
export function saveLiveCreatureClassInfo(session,o,root){
  if(o?.objectType!==5)throw new Error('Native SaveClassInfo requires a creature');
  const data=creatureRoot(o),rules=session.characterRules;
  if(!data||!rules?.classes||!rules.skills)throw new Error('Native SaveClassInfo live creature/rules are unavailable');
  const history=(data.LvlStatList??[]).map(h=>({
    source:h,LvlStatAbility:h.LvlStatAbility??6,LvlStatHitDie:h.LvlStatHitDie??0,
    LvlStatClass:h.LvlStatClass??0,EpicLevel:Number((h.EpicLevel??0)!==0),SkillPoints:h.SkillPoints,
  }));
  return saveCreatureClassInfo({
    classes:()=>data.ClassList?.map(c=>({...c,School:c.School??0,Domain1:c.Domain1??0,Domain2:c.Domain2??1})),
    classDefinition:id=>Object.fromEntries(['PickSchool','PickDomains','MemorizesSpells','Arcane','MinAssociateLevel'].map(name=>{
      const entry=intEntry(rules.classes,id,name);
      // These cells have no constructor initializer in CNWClass2992e0.
      if(!entry.found)throw new Error(`Native SaveClassInfo class ${id} ${name} is uninitialized`);
      return[name,name==='MinAssociateLevel'?entry.value&255:Number(entry.value!==0)];
    })),
    perDay:(i,l)=>spellClassInfo(o,i)?.perDay?.[l],known:(i,l)=>spellClassInfo(o,i)?.known?.[l],memorized:(i,l)=>spellClassInfo(o,i)?.memorized?.[l],
    histories:()=>history,isPC:()=>o.nativeStatsIsPCb0,
    totalLevel:()=>{if(!data.ClassList?.length)session.spellBook.warning(o,'GetLevel');return data.ClassList.reduce((sum,c)=>sum+(c.ClassLevel&255),0)&255;},
    historySpells:(h,p,l)=>(h.source[`${p}${l}`]??[]).map(e=>e.Spell),historySkill:(h,i)=>h.source.SkillList?.[i]?.Rank??0,
    historyFeats:h=>(h.source.FeatList??[]).map(e=>e.Feat),
    associate:name=>({type:data[`${name}Type`],name:data[`${name}Name`]??''}),
    skillPoints:()=>data.SkillPoints??0,skillCount:()=>rules.skills.orderedRows?.length??rules.skills.rows.size,
    skillRank:(i,t,b)=>session.combat.skill(o,i,t,b),feats:()=>(data.FeatList??[]).map(e=>e.Feat),
    featRemainingUses:id=>session.combat.remainingUses(o,id),abilities:()=>o.nativeSpellLikeAbilities,
    warning:message=>session.spellBook.warning(o,message),
  },root);
}
