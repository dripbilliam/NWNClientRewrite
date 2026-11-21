import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyTimeStop,removeTimeStop,applyTimeStopImmunity,removeTimeStopImmunity} from '../src/time_stop_effect.js';
import {ModuleSession} from '../src/module_session.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-time-stop-observations.json',import.meta.url)));

test('Time Stop and immunity constructors/handlers match the complete original owners and ordered side effects',async()=>{
 assert.equal(capture.rows.length,2057);
 for(const row of capture.rows){
  const c=row.case,calls=[],effect={type:64,duration:Math.fround(c.duration??1)},actor={id:c.id??0xf0000001},effects=(c.effects??[]).map(r=>r.self?effect:{type:r.type});let pauses=0;
  effects.forEach((e,i)=>{e.expiryDay=77;let time=88;Object.defineProperty(e,'expiryTime',{enumerable:true,get:()=>time,set:value=>{time=value;calls.push(['expiry',e===effect?'self':String(i),e.expiryDay,value]);}});if(c.effects[i].self)e.type=c.effects[i].type;});
  const p={pauseState:()=>{const value=(c.pause??[0])[Math.min(pauses++,(c.pause??[0]).length-1)];calls.push(['pause',value&255]);return value;},
   addExclusion:(id,mask)=>calls.push(['add',id,mask]),removeExclusion:(id,mask)=>calls.push(['remove',id,mask]),togglePause:mask=>calls.push(['toggle',mask]),
   worldTimer:()=>{calls.push(['worldTimer']);return{secondsPerDay:(c.length??7200000)/1000,dayLength:c.length??7200000};},
   activeTimer:id=>{calls.push(['activeTimer',id]);return{time:()=>{calls.push(['time']);return{day:c.now?.[0]??7,time:c.now?.[1]??100};}};},
   effects:()=>effects,asCreature:()=>{calls.push(['creature']);return c.creature===false?null:actor;},isDM:()=>{calls.push(['dm']);return c.dm??0;}};
  if(c.mode==='constructor'){
   const s=new ModuleSession(null),e=s.commands.EffectTimeStop([],{self:actor.id});
   assert.deepEqual({type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,integers:e.integers},row.output);continue;
  }
  const run=()=>({apply:applyTimeStop,remove:removeTimeStop,immunityApply:applyTimeStopImmunity,immunityRemove:removeTimeStopImmunity}[c.mode])(actor,effect,p,c.loading??0);
  if(row.addStatus===0xfffffffe&&row.calls.some(c=>c[0]==='expiry')){
   await assert.rejects(run,/recast expiry is unwritten/);assert.deepEqual(calls,row.calls.filter(c=>c[0]!=='expiry'));assert.deepEqual(effects.map(e=>[e.expiryDay,e.expiryTime]),[[77,88]]);assert.deepEqual(row.expiries,[[0xa5a5a5a5,0xa5a5a5a5]]);continue;
  }
  assert.equal(await run(),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(effects.map(e=>[e.expiryDay,e.expiryTime]),row.expiries,JSON.stringify(c));
 }
});
