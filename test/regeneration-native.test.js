import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyRegeneration,updateRegeneration} from '../src/regeneration_effect.js';
import {subtractWorldTimes} from '../src/world_timer.js';
import {EffectRuntime} from '../src/effect_runtime.js';
import {ModuleSession} from '../src/module_session.js';
import {applyHealing,applyResurrection} from '../src/healing_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-regeneration-observations.json',import.meta.url)));
const make=(id,type,creatorId,integers=[],subtype=0)=>({id:BigInt(id).toString(16).padStart(16,'0'),type,creatorId,integers:Array.from({length:8},(_,i)=>integers[i]??0),floats:Array(4).fill(0),strings:Array(6).fill(''),vectors:[[0,0,0],[0,0,0]],objectIds:Array(4).fill(0x7f000000),subtype,durationType:0,duration:0,spellId:-1,casterLevel:-1,bypassImmunity:0,exposed:true,showIcon:1});
const project=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,duration:e.duration,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),bypassImmunity:e.bypassImmunity,integers:e.integers});
test('regeneration constructor/application and strict timed healing match original shared owners',async()=>{
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,399);
 for(const row of oracle.rows){const c=row.case;
  if(c.mode==='constructor'){
   if(c.popFail||c.push===0){assert.equal(row.result,c.popFail?0xfffffd81:0xfffffd82);continue;}
   const session=new ModuleSession(null);session.effects.nextId=101n;assert.deepEqual(project(session.commands.EffectRegenerate([c.amount,c.interval],{self:98})),row.output,JSON.stringify(c));assert.equal(row.result,0);continue;
  }
  const calls=[],actor={id:99},effect=make(77,7,98,c.integers??[4,100,3,500,0,0,0,0],8);Object.assign(effect,{durationType:c.durationType??1,duration:3.25,spellId:11,casterLevel:7,bypassImmunity:13});let id=100;
  const p={asCreature:()=>c.creature===false?null:actor,time:()=>{calls.push(['time']);return c.now??{day:3,time:500};},
   dead:()=>{calls.push(['dead']);return c.dead??0;},currentHP:(_o,n)=>{calls.push(['current',n]);return(c.current??5)<<16>>16;},maximumHP:(_o,n)=>{calls.push(['maximum',n]);return(c.maximum??20)<<16>>16;},
   copyConstruct:(e,icons)=>EffectRuntime.prototype.copyConstruct(e,icons),create:(type,creator,values,subtype)=>make(++id,type,creator,values,subtype),
   apply:(_o,e,loading)=>calls.push(['apply',project(e),loading]),subtractTime:(a,b)=>{calls.push(['subtract',a.day,a.time,b.day,b.time]);return subtractWorldTimes(a,b,c.length??1000000);}};
  const scratch=structuredClone(c.scratch??{day:0,time:0});if(c.mode==='apply')assert.equal(await applyRegeneration(actor,effect,p,c.loading??0),row.result);else await updateRegeneration(actor,effect,c.now??{day:3,time:601},scratch,p);
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(project(effect),row.effect,JSON.stringify(c));if(c.mode==='poll')assert.deepEqual(scratch,row.scratch,JSON.stringify(c));
 }
});
test('world subtraction preserves unsigned wrap, unusual invalid-time behavior and untouched rejected outputs',()=>{
 assert.equal(oracle.clocks.length,675);
 for(const c of oracle.clocks){const value=subtractWorldTimes(c.a,c.b,c.length);if(c.status===0)assert.deepEqual(value,{status:0,day:c.day,time:c.time},JSON.stringify(c));else{assert.deepEqual(value,{status:-2});assert.equal(c.day,0xfeedface);assert.equal(c.time,0xdeadbeef);}}
});
test('healing matches complete original handler arithmetic, feedback, live group scan and recovery dispatch',async()=>{
 assert.equal(oracle.heals.length,462);
 for(const row of oracle.heals){const c=row.case,calls=[],actor={id:99,current:c.current??5},source={id:98};let id=100,dyingCalls=0;
  const e=make(77,7,98,c.integers??[4,100,3,500,0,0,0,0],8);Object.assign(e,{durationType:c.durationType??1,duration:3.25,spellId:11,casterLevel:7,bypassImmunity:13});
  let effects=(c.effects??[]).map(e=>({...e,durationType:e.durationType??0,id:BigInt(e.id).toString(16).padStart(16,'0')}));
  const p={asCreature:()=>c.creature===false?null:actor,asDoor:()=>c.slot==='30'?actor:null,asPlaceable:()=>c.slot==='98'?actor:null,
   dead:()=>{calls.push(['dead']);return c.dead??0;},dying:()=>{calls.push(['dying']);return dyingCalls++===0?c.dying??0:c.dyingAfter??0;},currentHP:()=>actor.current<<16>>16,maximumHP:()=>c.maximum??20,writeHP:(_o,n)=>{actor.current=n;},
   feedback:(o,n,data)=>calls.push(['feedback',o.id,n,data]),creature:()=>c.creator==='self'?actor:c.creator==='missing'?null:source,
   effects:()=>effects,remove:(_o,id)=>{calls.push(['remove',id]);effects=effects.filter(e=>e.id!==id);},
   create:(type,creator,values,subtype)=>make(++id,type,creator,values,subtype),apply:(_o,e,loading)=>calls.push(['apply',project(e),loading]),encumbrance:(_o,n)=>calls.push(['encumbrance',n])};
  const result=await applyHealing(actor,c.nullEffect?null:e,p,c.loading??0);assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.current,row.hp,JSON.stringify(c));assert.deepEqual(effects,row.liveEffects,JSON.stringify(c));
 }
});
test('resurrection restores canonical state and removes temporary type57 groups exactly as original',async()=>{
 assert.equal(oracle.resurrections.length,362);
 for(const row of oracle.resurrections){const c=row.case;
  if(c.mode==='resurrectionConstructor'){const s=new ModuleSession(null);s.effects.nextId=101n;assert.deepEqual(project(s.commands.EffectResurrection([],{self:98})),row.output);assert.equal(row.result,0);continue;}
  const calls=[],actor={id:99,current:c.current??5,nativeRaiseableF4:c.raiseable??1,nativeListening1ec:0,nativeFieldEc:0,nativeField8d4:0};let effects=(c.effects??[]).map(e=>({...e,durationType:e.durationType??0,id:BigInt(e.id).toString(16).padStart(16,'0')}));
  const p={asCreature:()=>c.creature===false?null:actor,currentHP:(_o,n)=>((actor.current+(n===0?c.temporaryHP??0:0))<<16>>16),writeHP:(_o,n)=>{actor.current=n;},
   clearActions:()=>calls.push(['clearActions']),encumbrance:(_o,n)=>calls.push(['encumbrance',n]),ambient:()=>calls.push(['ambient']),floaty:(_o,n)=>calls.push(['floaty',n,99]),client:id=>{calls.push(['client',id]);return c.client?{playerId:77}:null;},destroyDeathGUI:client=>calls.push(['message',client.playerId,36,2,0,0]),
   effects:()=>effects,remove:(_o,id)=>{calls.push(['remove',id]);effects=effects.filter(e=>e.id!==id);}};
  assert.equal(await applyResurrection(actor,{exposed:c.exposed??1},p),row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.current,row.hp,JSON.stringify(c));assert.deepEqual({listening:actor.nativeListening1ec,commandable:actor.nativeFieldEc,flags:actor.nativeField8d4},row.state,JSON.stringify(c));assert.deepEqual(effects,row.liveEffects,JSON.stringify(c));
 }
});
