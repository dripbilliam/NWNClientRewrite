import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parse2da} from '../src/area.js';
import {EffectRuntime} from '../src/effect_runtime.js';
import {ModuleSession} from '../src/module_session.js';
import {applyNegativeLevel,removeNegativeLevel,classNegativeLevels,setClassNegativeLevels,creatureLevel,totalNegativeLevels,penalizedClassLevel} from '../src/negative_level_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-negative-level-observations.json',import.meta.url)));
const make=(id,type,creatorId,integers=[],subtype=0)=>({id:BigInt(id).toString(16).padStart(16,'0'),type,creatorId,integers:Array.from({length:8},(_,i)=>integers[i]??0),floats:Array(4).fill(0),strings:Array(6).fill(''),vectors:[[0,0,0],[0,0,0]],objectIds:Array(4).fill(0x7f000000),subtype,durationType:0,duration:0,spellId:-1,casterLevel:-1,bypassImmunity:0,exposed:true,showIcon:1});
const project=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,duration:e.duration,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),bypassImmunity:e.bypassImmunity,integers:e.integers});
const actor=(id,records)=>({id,creatureData:{ClassList:records.map(c=>({Class:c.type??4,ClassLevel:c.level??3,skillPenaltyByte:c.penalty??0}))}});
const records=o=>o.creatureData.ClassList.map(c=>({type:c.Class,level:c.ClassLevel,penalty:c.skillPenaltyByte}));
test('negative-level constructors and complete apply/remove handlers match original linked penalties, class selection, caster HP and lethal event',async()=>{
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,2691);
 for(const row of oracle.rows){const c=row.case;
  if(c.mode==='constructor'){
   if(c.popFail||c.push===0){assert.equal(row.result,c.popFail?0xfffffd81:0xfffffd82);continue;}
   const s=new ModuleSession(null);s.characterRules={ruleset:parse2da(`2DA V2.0\n\nLabel Value\n0 MAX_NEGATIVE_LEVELS ${c.maximum??100}`)};s.effects.nextId=101n;
   const value=s.commands.EffectNegativeLevel(c.argc===1?[c.amount??1]:[c.amount??1,c.bonus??0],{self:99});assert.deepEqual(project(value),row.output,JSON.stringify(c));assert.equal(row.result,0);continue;
  }
  const o=actor(99,c.classes??[{type:4,level:3,penalty:0}]),other=actor(98,c.sourceClasses??[{type:10,level:9,penalty:0}]),source=c.source==='self'?o:c.source==='missing'?null:other,calls=[];let id=100;
  const e=make(77,82,c.source==='self'?99:98,[c.amount??1,c.bonus??0],c.subtype??8);Object.assign(e,{durationType:c.durationType??1,duration:3.25,spellId:11,casterLevel:7,bypassImmunity:c.bypass??0});
  const p={asCreature:()=>c.creature===false?null:o,dead:()=>{calls.push(['dead']);return c.dead??0;},creature:id=>{calls.push(['creature',id]);return source;},
   rule:(name,fallback)=>{const value=name==='MAX_NEGATIVE_LEVELS'?c.maximum??100:c.bonusRule??5;calls.push(['rule',name,fallback,value]);return value;},
   immunity:(_o,n,s,flag)=>{calls.push(['immunity',n,s?.id??null,flag]);return c.immunity??0;},feedback:(o,n,data)=>calls.push(['feedback',o.id,n,data]),
   create:(type,creator,values,subtype)=>make(++id,type,creator,values,subtype),copyConstruct:(e,icons)=>EffectRuntime.prototype.copyConstruct(e,icons),apply:(o,e,loading)=>calls.push(['apply',o.id,project(e),loading]),
   classCount:o=>o.creatureData.ClassList.length&255,classLevel:(o,index,a,b)=>{calls.push(['classLevel',index,a,b]);return penalizedClassLevel(o,index);},
   classNegativeLevels:(o,index)=>{calls.push(['classNegative',index]);return classNegativeLevels(o,index);},
   updateMemorizedSlots:o=>calls.push(['updateSlots',o.id,records(o)]),warning:message=>calls.push(['warning',message]),
   level:(o,penalty)=>{calls.push(['level',o.id,penalty]);return creatureLevel(o,penalty,p.warning);},
   enqueue:(o,n,e)=>calls.push(['event',n,e.creatorId,o.id,project(e)])};
  p.setClassNegativeLevels=(o,index,value)=>{calls.push(['setNegative',index&255,value&255]);return setClassNegativeLevels(o,index,value,p);};
  const result=await(c.mode==='apply'?applyNegativeLevel(o,e,p,c.loading??0):removeNegativeLevel(o,e,p));
  assert.deepEqual({result,calls,effect:project(e),classes:records(o)},{result:row.result,calls:row.calls,effect:row.effect,classes:row.classes},JSON.stringify(c));
 }
});
test('canonical class-negative-level setters/getters and total level match original BYTE wrap, invalid index and slot refresh',()=>{
 assert.equal(oracle.supports.length,424);
 for(const row of oracle.supports){const c=row.case,o=actor(99,c.classes??[{type:4,level:3,penalty:0}]),calls=[],p={warning:message=>calls.push(['warning',message]),updateMemorizedSlots:o=>calls.push(['updateSlots',99,records(o)])};let result;
  if(c.mode==='set'){calls.push(['setNegative',c.index&255,c.value&255]);setClassNegativeLevels(o,c.index,c.value,p);result=null;}
  else if(c.mode==='get'){calls.push(['classNegative',c.index&255]);result=classNegativeLevels(o,c.index);}
  else if(c.mode==='total')result=totalNegativeLevels(o);
  else{calls.push(['level',99,c.penalty]);result=creatureLevel(o,c.penalty,p.warning);}
  // Native BYTE-return leaves leave upper EAX bits unspecified. Only the
  // decoded BYTE return is meaningful for GetClassNegativeLevels/GetLevel.
  assert.equal(result,['get','level'].includes(c.mode)?row.result&255:row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(records(o),row.classes,JSON.stringify(c));
 }
});
