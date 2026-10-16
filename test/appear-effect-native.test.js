import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {constructAppearEffect,applyAppearEffect,addAppearActions,executeAppearAction} from '../src/appear_effect.js';
import {clearCreatureMovementAction} from '../src/combat_lifecycle.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-appear-observations.json',import.meta.url)));

test('appear constructor, effect admission and queue match original owners',async()=>{
 for(const row of native.constructors){const c=row.case;assert.deepEqual(constructAppearEffect(c.argc?[c.value]:[],99,{create:(type,creator,integers)=>({type,creator,integer:integers[0]})}),row.output);}
 for(const [kind,rows]of [['apply',native.applies],['queue',native.queues]])for(const row of rows){
  const c=row.case,calls=[],actor={objectType:c.type??5,nativeFieldEc:c.commandable,objectActionState:{lastGroup:0}},p={
   queue:(o,id,group,params)=>{calls.push(['queue',id,group,params[0].type,params[0].value]);o.objectActionState.lastGroup=9;},
   interrupt:(_o,group,value)=>calls.push(['interrupt',group,value])};
  const result=kind==='apply'?await applyAppearEffect(actor,{integers:[c.value]},{asCreature:o=>o,clear:()=>calls.push(['clear']),add:(...a)=>addAppearActions(...a,p)}):await addAppearActions(actor,c.value,p);
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('appear action preserves native two-second threshold, speed and idle restoration',async()=>{
 for(const row of native.actions){const c=row.case,calls=[],actor={objectType:c.type,nativeAnimationSpeedDC:2},node={parameterCount:c.count,parameterData:[c.value]};
  const result=await executeAppearAction(actor,node,{elapsed:()=>c.elapsed,asCreature:o=>o.objectType===5?o:null,setAnimation:(_o,id)=>calls.push(['animation',id>>>0])});
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.nativeAnimationSpeedDC,row.speed,JSON.stringify(c));
 }
});
test('appear clear52 uses the native cancellation veto and common lock/time tail',async()=>{
 for(const row of native.clears){const c=row.case,calls=[],actor={lockOrientationId:c.lock,objectActionState:{startDay:10,startTime:2345}},node={actionId:52,nativeField9c:c.ready};
  const result=await clearCreatureMovementAction(actor,node,c.head,{messageAvailable:()=>true,setLock:(o,id)=>{calls.push(['lock',id]);o.lockOrientationId=id;}});
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.lockOrientationId,row.lock,JSON.stringify(c));assert.deepEqual([actor.objectActionState.startDay,actor.objectActionState.startTime],row.started,JSON.stringify(c));
 }
});
