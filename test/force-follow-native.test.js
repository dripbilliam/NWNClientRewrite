import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptForceFollow,executeForceFollow,checkForceFollow} from '../src/force_follow.js';
import {createObjectActionState,addObjectAction,createObjectAction,setActionParameter} from '../src/object_actions.js';
import {clearCreatureMovementAction} from '../src/combat_lifecycle.js';
test('follow command and recurring action owners match original queue/cast/movement observations',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-force-follow-observations.json',import.meta.url)));
 for(const row of native.rows.filter(r=>r.case.operation!=='clear')){
  const c=row.case,actor={objectType:5,objectActionState:createObjectActionState(),nativeFieldEc:c.commandable??1},calls=[],list=actor.objectActionState.list,insert=list.insert.bind(list);
  list.insert=(node,front)=>{calls.push([front?'front':'back',node.actionId,node.groupId,Array.from({length:node.parameterCount},(_,i)=>[node.parameterTypes[i],node.parameterData[i]])]);return insert(node,front);};
  const floatBits=v=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,v,true);return d.getInt32(0,true);};
  if(c.operation==='command')scriptForceFollow(c.exists?actor:null,100,c.argc>1?c.distance:0,c.argc>2?c.flags:0);
  else{
   const node=createObjectAction(c.operation==='follow'?55:58,17);for(const [i,type,value]of [[0,3,100],[1,1,c.run],[2,2,floatBits(c.distance)],[3,1,c.flags]])setActionParameter(node,i,type,value);node.parameterCount=c.count??4;
   if(c.operation==='follow')assert.equal(await executeForceFollow(actor,node,{
    object:id=>{calls.push(['object',id]);return c.exists?{}:null;},asObject:()=>{calls.push(['asObject']);return c.asObject?{position:[1,3,-2],areaId:88}:null;},
    moveFront:(_o,group,point,...args)=>calls.push(['moveFront',group,[point[0],-point[2],point[1]],...args])}),row.result);
   else assert.equal(checkForceFollow(actor,node),row.result);
  }
  // AddAction allocation/group ownership is independently verified. Apply that
  // same shared lower owner to the captured native calls for resolved groups.
  const expectedState=createObjectActionState(),expected=row.calls.filter(v=>v[0]!=='creature').map(call=>{
   if(!['front','back'].includes(call[0]))return call;
   const n=addObjectAction(expectedState,call[1],call[2],call[3].map(([type,value])=>({type,value})),call[0]==='front');return[call[0],call[1],n.groupId,call[3]];});
  assert.deepEqual(calls,expected,JSON.stringify(c));
 }
});

test('follow cancellation preserves native interruptibility, orientation and exact-one timer reset',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-force-follow-observations.json',import.meta.url)));
 for(const row of native.rows.filter(r=>r.case.operation==='clear')){
  const c=row.case,calls=[],actor={lockOrientationId:c.lock,objectActionState:{startDay:10,startTime:2345}},node={actionId:c.action,nativeField9c:c.ready};
  assert.equal(await clearCreatureMovementAction(actor,node,c.head,{messageAvailable:()=>{calls.push(['message']);return c.message;},setLock:(o,id)=>{calls.push(['lock',id]);o.lockOrientationId=id;}}),row.result);
  assert.deepEqual(calls,row.calls);assert.equal(actor.lockOrientationId,row.lock);assert.deepEqual([actor.objectActionState.startDay,actor.objectActionState.startTime],row.started);
 }
});
