import {intEntry} from './combat_stats.js';
import {creatureRoot} from './creature_rules.js';
import {bonusFeats} from './bonus_feat_effect.js';
import {featInfo} from './feat_uses.js';
import {featActivationInfo,featActivationSpell} from './use_feat.js';
import {nativeStringEntry} from './spell_metadata.js';
import {OBJECT_INVALID} from './game_object_array.js';

// This is a local projection of the native client's class/normal/bonus pools.
// Native replicated client storage and its update protocol remain separate.
export function featRadialProviders(actor,target,rules,p,{alwaysSubradial=false,assignment=false}={}){
 const root=creatureRoot(actor),classes=root.ClassList;
 if(!Array.isArray(classes))throw new Error('Native class ability class storage is unavailable');
 const classCache=new Map(),rows=t=>t.orderedRows??[...t.rows.values()];
 const feat=id=>{
  const info=featActivationInfo(rules,id);if(!info)return null;
  const next=intEntry(rules.feat,id&65535,'SUCCESSOR');
  return {...info,successor:next.found?next.value:-1,nameRef:intEntry(rules.feat,id&65535,'FEAT').value,
   icon:nativeStringEntry(rules.feat,id&65535,'ICON').value.slice(0,16)};
 };
 return {controlled:true,assignment,self:target?.id===actor.id,targetId:target?.id??OBJECT_INVALID,
  // Local simulation projects the corresponding native client boolean.
  defensiveStance:Number(actor.combatMode===11),familiar:p.familiar??null,
  classCount:()=>classes.length,classType:index=>classes[index].Class&255,
  classDomain:(index,n)=>(classes[index][n===0?'Domain1':'Domain2']??n)&255,
  classInfo:type=>{
   type&=255;if(type>=rows(rules.classes).length)return null;
   if(!classCache.has(type)){
    const name=nativeStringEntry(rules.classes,type,'FeatsTable').value.toLowerCase(),table=rules.classTables?.get(name);
    if(!table)throw new Error(`Native class feat table ${name||'(empty)'} is unavailable`);
    // LoadFeatsTable14029a9a0 shrinks its WORD loop bound when a feat is
    // invalid and does not advance the destination record in that branch.
    // Any untouched allocation read remains explicit rather than invented.
    let count=rows(table).length&65535,cursor=0;const storage=Array(count);
    for(let index=0;index<count;index++){
     const id=intEntry(table,index,'FeatIndex').value&65535;storage[cursor]={id,onMenu:0};
     if(!featInfo(rules,id)){count--;continue;}
     storage[cursor++]={id,onMenu:intEntry(table,index,'OnMenu').value};
    }
    classCache.set(type,{featCount:count,storage});
   }
   return classCache.get(type);
  },
  classFeat:(cls,index)=>{
   index&=65535;if(index>=cls.featCount)return null;
   const value=cls.storage[index];if(!value)throw new Error('Native class feat menu reads uninitialized loader storage');return value;
  },
  domain:id=>{
   if(!rules.domains)throw new Error('Native class ability domain table is unavailable');
   id&=65535;if(id>=(rows(rules.domains).length&255)||!intEntry(rules.domains,id,'Name').found)return null;
   // Domain ctor14029c540 initializes valid1/castable0/featFFFF.
   const granted=intEntry(rules.domains,id,'GrantedFeat'),castable=intEntry(rules.domains,id,'CastableFeat');
   return {featId:granted.found?granted.value&65535:65535,castable:castable.found?castable.value:0};
  },
  owns:id=>(root.FeatList??[]).some(f=>(f.Feat&65535)===(id&65535))||bonusFeats(actor).some(f=>(f&65535)===(id&65535)),
  grouped:()=>classes.length>3||alwaysSubradial,feat,
  spell:id=>{const value=featActivationSpell(rules,id);return value?{...value,nameRef:intEntry(rules.spells,id,'Name').value,icon:nativeStringEntry(rules.spells,id,'IconResRef').value.slice(0,16)}:null;},
  remaining:id=>p.remaining(id),warning:message=>p.warning(message)};
}
