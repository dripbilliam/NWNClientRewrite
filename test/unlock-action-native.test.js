import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {addUnlockAction,executeUnlockAction} from '../src/unlock_actions.js';
import {createObjectActionState,createObjectAction,setActionParameter} from '../src/object_actions.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-unlock-action-observations.json',import.meta.url)));
test('native unlock append groups/parameters and noncreature action gates/events match original instructions',async()=>{
 assert.equal(data.rows.length,266);
 for(const row of data.rows){const c=row.case,trace=[],actor={id:99,objectType:10,nativeFieldEc:c.commandable??1,objectActionState:createObjectActionState()};let result;
  if(c.mode==='add'){
   actor.objectActionState.nextGroup=c.group??0;result=addUnlockAction(actor,c.targetId??123,c.item??0x7f000000,c.property??0);
   for(const a of actor.objectActionState.list)trace.push(['append',{actionId:a.actionId,group:a.groupId,count:a.parameterCount,flag:a.nativeField9c,types:[...a.parameterTypes],data:a.parameterData}]);
   assert.equal(actor.objectActionState.nextGroup,row.group,JSON.stringify(c));assert.equal(actor.objectActionState.lastGroup,row.lastGroup,JSON.stringify(c));
  }else{
   const target={id:c.self===false?100:99,objectType:c.kind==='placeable'?9:c.kind==='other'?5:10,locked:c.locked??1},node=createObjectAction(38,0);setActionParameter(node,0,3,target.id);setActionParameter(node,1,3,c.item??0x7f000000);
   result=await executeUnlockAction(actor,node,{dead:()=>{trace.push(['dead']);return c.dead??0;},dying:()=>{trace.push(['dying']);return c.dying??0;},item:id=>{trace.push(['item',id]);return null;},object:id=>{trace.push(['object',id]);return c.target===false?null:target;},asWorld:()=>c.world===false?null:target,door:o=>o.objectType===10?o:null,placeable:o=>o.objectType===9?o:null,locked:o=>o.locked,keyRequired:()=>c.key??0,unlock:o=>{o.locked=0;},event:(a,t,type)=>trace.push(['event',a.id,t.id,10,type]),creatureAction:()=>assert.fail('Creature owner must remain separate')});assert.equal(target.locked,row.locked,JSON.stringify(c));
  }
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
