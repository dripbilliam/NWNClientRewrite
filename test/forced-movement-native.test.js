import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {queueForcedMove,receiveForcedMove} from '../src/forced_movement.js';
test('forced movement payload and timeout receiver match original event/jump/cancellation observations',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-forced-movement-observations.json',import.meta.url)));
 for(const row of native.rows){
  const c=row.case,calls=[],actor={id:99},point=[1,3,-2];
  if(c.operation==='queue')await queueForcedMove(actor,c.group,88,point,c.target,c.seconds,{
   delta:seconds=>{calls.push(['time',seconds],['day',seconds]);return{day:c.day,time:c.time};},
   event:(day,time,caller,target,id,payload)=>calls.push(['event',day,time,caller,target,id,{...payload,position:[payload.position[0],-payload.position[2],payload.position[1]]}])});
  else{
   const record=(kind,_o,node)=>calls.push([kind,node.actionId,node.groupId,Array.from({length:node.parameterCount},(_,i)=>[node.parameterTypes[i],node.parameterData[i]])]);
   await receiveForcedMove(actor,{type:c.type,group:c.group,areaId:88,position:point,targetId:c.target},{
    cancel:(_o,code,group)=>{calls.push(['cancel',code,group]);return c.cancel;},jumpPoint:(...args)=>record('jumpPoint',...args),jumpObject:(...args)=>record('jumpObject',...args)});
  }
  assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
