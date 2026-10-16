import {creatureRoot} from './creature_rules.js';
import {nativeClassLevel} from './spell_caster_level.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native negative-level ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native negative-level provider ${n} is unavailable`);return p[n](...args);};
const classes=o=>{const list=creatureRoot(o)?.ClassList;if(!Array.isArray(list))throw new Error('Native negative-level class storage is unavailable');return list.slice(0,list.length&255);};
// GetClassNegativeLevels1403fa5b0 and SetClassNegativeLevels140415490 use the
// existing live class BYTE25e, already consumed by skills/caster-level/DC.
export function classNegativeLevels(actor,index){const c=classes(actor)[integer(index,'class index')&255];return c?integer(c.skillPenaltyByte,'class penalty')&255:0;}
export function setClassNegativeLevels(actor,index,value,p){
 index=integer(index,'class index')&255;value=integer(value,'class penalty')&255;
 if(index>=classes(actor).length)call(p,'warning','nMultiClass < m_nNumMultiClasses');
 const c=classes(actor)[index];if(c){c.skillPenaltyByte=value;call(p,'updateMemorizedSlots',actor);}
}
// GetLevel1404035c0 and GetTotalNegativeLevels14040a960, valid canonical
// creature/stat ownership. Total level narrows BYTE; total penalties do not.
export function creatureLevel(actor,penalty,warning=()=>{}){
 const list=classes(actor);if(!list.length)warning('Your character has no class! What are you doing?');
 return classes(actor).reduce((sum,c)=>sum+Math.max(0,(integer(c.ClassLevel,'class level')&255)-(integer(penalty,'penalty flag')!==0?(integer(c.skillPenaltyByte,'class penalty')&255):0)),0)&255;
}
export function totalNegativeLevels(actor){return classes(actor).reduce((sum,c)=>sum+(integer(c.skillPenaltyByte,'class penalty')&255),0)|0;}
export const penalizedClassLevel=(actor,index)=>nativeClassLevel(actor,index,1,0,{});
// Complete OnApplyNegativeLevel14042f500. Loading does NOT bypass immunity,
// child creation, caster HP grant or class reassignment. Keep those oddities.
export async function applyNegativeLevel(actor,effect,p,loading=0){
 if(loading!==0&&actor&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
 if(integer(effect.integers[0],'amount')>integer(call(p,'rule','MAX_NEGATIVE_LEVELS',100),'maximum rule'))return 1;
 if(!call(p,'asCreature',actor))return 0;
 const source=call(p,'creature',effect.creatorId>>>0);
 if(integer(effect.bypassImmunity,'immunity override')===0&&await call(p,'immunity',actor,29,source,1)!==0){
  const data={objectIds:[actor.id>>>0]};if(source)await call(p,'feedback',source,131,structuredClone(data));await call(p,'feedback',actor,131,data);return 1;
 }
 for(const [type,selector,fields]of [[11,0,{1:0,2:28}],[27,0,{1:0,3:28}],[56,1,{0:255,2:28}],[67,0,{}]]){
  const child=call(p,'copyConstruct',effect,Number(type===67));child.type=type;child.integers[selector]=type===67?50:integer(effect.integers[0],'amount');
  for(const [index,value]of Object.entries(fields))child.integers[index]=value;
  await call(p,'apply',actor,child,loading);
 }
 let highest=0,selected=0;
 for(let index=0;index<call(p,'classCount',actor);index++){
  const level=integer(call(p,'classLevel',actor,index,1,0),'class level')&255;
  if(level>highest){selected=index;highest=integer(call(p,'classLevel',actor,index,1,0),'class level')&255;}
 }
 if(source&&integer(effect.integers[1],'bonus HP flag')!==0){
  const child=call(p,'create',15,effect.creatorId,[],0);child.subtype=(integer(child.subtype,'new subtype')&0xffc7)|(integer(effect.subtype,'source subtype')&56);
  child.integers[0]=Math.imul(integer(call(p,'rule','BONUS_HP_PER_LEVEL_DRAINED',5),'bonus HP rule'),integer(effect.integers[0],'amount'));child.durationType=1;
  child.duration=Math.fround(Math.fround(integer(call(p,'level',source,0),'source level')&255)*6);await call(p,'apply',source,child,loading);
 }
 if(highest>0){
  const current=integer(call(p,'classNegativeLevels',actor,selected),'current class penalty')&255;
  await call(p,'setClassNegativeLevels',actor,selected,(current+integer(effect.integers[0],'amount'))&255);effect.integers[1]=selected;
  if((integer(call(p,'level',actor,1),'remaining level')&255)===0){const death=call(p,'create',19,effect.creatorId,[1,1],0);death.durationType=0;await call(p,'enqueue',actor,5,death);}
 }
 return 0;
}
// Complete OnRemoveNegativeLevel140437bc0. BYTE underflow deliberately wraps;
// native has no saturation or attempt to redistribute the earlier drain.
export async function removeNegativeLevel(actor,effect,p){
 if(call(p,'asCreature',actor)){const index=integer(effect.integers[1],'class slot')&255,current=integer(call(p,'classNegativeLevels',actor,index),'current class penalty')&255;
  await call(p,'setClassNegativeLevels',actor,index,(current-integer(effect.integers[0],'amount'))&255);
 }
 return 1;
}
