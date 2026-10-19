import {gffField as field,gffRecord as record} from './gff_writer.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native SaveClassInfo ${name} is unavailable`);return v|0;};
const byte=(v,name)=>integer(v,name)&255;
const word=(v,name)=>integer(v,name)&65535;
const array=(v,name)=>{if(!Array.isArray(v))throw new Error(`Native SaveClassInfo ${name} is unavailable`);return v;};
const list=(parent,name)=>{const entries=[];parent.fields[name]=field(15,entries);return entries;};
const put=(parent,name,type,value)=>{parent.fields[name]=field(type,value);};
const element=(entries,type)=>{const node=record({},type);entries.push(node);return node;};

// CNWSCreatureStats::SaveClassInfo140413880..1404145d8 (two native ranges).
// Providers expose owned live storage, never the original resource snapshot.
// The native BYTE/WORD cursors are retained. Nonterminating corrupt counts
// are diagnosed rather than silently clamped into a successful save.
export async function saveCreatureClassInfo(p,root=record({})){
  const classes=()=>array(p.classes(),'class storage'),count=()=>classes().length&255;
  const classList=list(root,'ClassList');let familiar=false,companion=false;
  for(let index=0;index<count();index++){
    const c=classes()[index],id=byte(c.Class,'class ID'),definition=p.classDefinition(id);
    if(!definition)throw new Error('Native SaveClassInfo class definition is unavailable');
    const node=element(classList,2);
    put(node,'Class',5,id);put(node,'ClassLevel',3,byte(c.ClassLevel,'class level'));
    if(integer(definition.PickSchool,'PickSchool')!==0)put(node,'School',0,index<8?byte(c.School,'school'):0);
    if(integer(definition.PickDomains,'PickDomains')!==0){
      for(const name of ['Domain1','Domain2']){
        if(index>=8)p.warning?.(`Get${name}`);
        put(node,name,0,index<8?byte(c[name],name):0);
      }
    }
    if(integer(definition.MemorizesSpells,'MemorizesSpells')===0){
      const days=list(node,'SpellsPerDayList');
      for(let level=0;level<10;level++)put(element(days,0x4567),'NumSpellsLeft',0,byte(p.perDay(index,level),'per-day uses'));
    }
    for(let level=0;level<10;level++){
      const known=array(p.known(index,level),'known spell storage'),n=(known.length<<16)>>16;
      if(n<=0)continue;
      if(n>255)throw new Error('Native SaveClassInfo known-spell cursor would wrap');
      const spells=list(node,`KnownList${level}`);
      for(let cursor=0;cursor<n;cursor++)put(element(spells,3),'Spell',2,word(known[cursor],'known spell'));
    }
    for(let level=0;level<10;level++){
      const slots=array(p.memorized(index,level),'memorized spell storage'),n=slots.length&255;
      const id=slot=>slot?integer(slot.id,'memorized spell')>>>0:0xffffffff;
      let found=false;for(let cursor=0;cursor<n;cursor++)if(id(slots[cursor])!==0xffffffff){found=true;break;}
      if(!found)continue;
      const spells=list(node,`MemorizedList${level}`);
      for(let cursor=0;cursor<n;cursor++){
        const slot=slots[cursor],spell=id(slot);if(spell===0xffffffff)continue;
        const entry=element(spells,3);put(entry,'Spell',2,spell&65535);
        put(entry,'Ready',0,byte(slot.ready,'memorized readiness'));
        if(integer(slot.domain,'memorized domain flag')!==0)put(entry,'DomainSpell',0,1);
        // GetMemorizedSpellInSlotMetaType special-cases class index254.
        put(entry,'SpellMetaMagic',0,index===254?0:byte(slot.metamagic,'memorized metamagic'));
      }
    }
    if(byte(definition.MinAssociateLevel,'MinAssociateLevel')!==255){
      if(integer(definition.Arcane,'Arcane')!==0)familiar=true;else companion=true;
    }
  }
  const histories=()=>array(p.histories(),'level-history storage');
  if(histories().length>1||integer(p.isPC(),'PC flag')!==0){
    const levels=list(root,'LvlStatList');
    // GetLevel re-reads the actor's current stats class levels each iteration.
    for(let index=0;index<byte(p.totalLevel(),'total level');index++){
      const h=histories()[index];if(!h)throw new Error('Native SaveClassInfo level-history record is unavailable');
      const node=element(levels,0);
      if(index!==0){const ability=byte(h.LvlStatAbility,'level ability');if(ability!==6)put(node,'LvlStatAbility',0,ability);}
      for(const name of ['LvlStatHitDie','LvlStatClass','EpicLevel'])put(node,name,0,byte(h[name],name));
      for(let level=0;level<10;level++)for(const prefix of ['KnownList','KnownRemoveList']){
        const known=array(p.historySpells(h,prefix,level),'level-history spells'),n=known.length&255;
        if(!n)continue;const entries=list(node,`${prefix}${level}`);
        for(let cursor=0;cursor<n;cursor++)put(element(entries,0),'Spell',2,word(known[cursor],'level-history spell'));
      }
      put(node,'SkillPoints',2,word(h.SkillPoints,'level skill points'));
      const skills=list(node,'SkillList');
      for(let skill=0;skill<byte(p.skillCount(),'skill count');skill++)put(element(skills,0),'Rank',0,byte(p.historySkill(h,skill),'level skill change'));
      const feats=list(node,'FeatList'),owned=array(p.historyFeats(h),'level feats'),n=owned.length&65535;
      for(let cursor=0;cursor<n;cursor++)put(element(feats,0),'Feat',2,word(owned[cursor],'level feat'));
    }
  }
  for(const [enabled,name]of [[familiar,'Familiar'],[companion,'Companion']])if(enabled){
    const associate=p.associate(name);put(root,`${name}Type`,5,integer(associate.type,`${name} type`));
    if(typeof associate.name!=='string')throw new Error(`Native SaveClassInfo ${name} name is unavailable`);
    put(root,`${name}Name`,10,associate.name);
  }
  put(root,'SkillPoints',2,word(p.skillPoints(),'skill points'));
  const skills=list(root,'SkillList');
  for(let skill=0;skill<byte(p.skillCount(),'skill count');skill++)put(element(skills,0),'Rank',0,byte(await p.skillRank(skill,null,1),'base skill rank'));
  const permanent=()=>array(p.feats(),'permanent feat storage');
  if(permanent().length>0){
    const feats=list(root,'FeatList');
    for(let cursor=0;cursor<permanent().length;cursor++){
      if(cursor>65535)throw new Error('Native SaveClassInfo permanent-feat cursor would wrap');
      const id=word(permanent()[cursor],'permanent feat'),uses=byte(await p.featRemainingUses(id),'feat uses'),node=element(feats,1);
      put(node,'Feat',2,id);if(uses!==100)put(node,'Uses',0,uses);
    }
  }
  const abilities=()=>array(p.abilities(),'special ability storage');
  if(abilities().length>0){
    const entries=list(root,'SpecAbilityList');
    for(let cursor=0;cursor<abilities().length;cursor++){
      const ability=abilities()[cursor],node=element(entries,4);
      put(node,'Spell',2,word(ability.id,'special ability spell'));put(node,'SpellFlags',0,byte(ability.remaining,'special ability uses'));
      put(node,'SpellCasterLevel',0,byte(ability.casterLevel,'special ability caster level'));
    }
  }
  return root;
}
