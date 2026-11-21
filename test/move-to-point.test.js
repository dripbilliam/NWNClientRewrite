import test from 'node:test';
import assert from 'node:assert/strict';
import { executeMoveToPoint,deleteMatchingMoveFollowup } from '../src/move_to_point.js';
import { addMoveToPointFront } from '../src/movement_actions.js';
import { createObjectActionState,addObjectAction,actionParameter } from '../src/object_actions.js';
import { PathInformation } from '../src/path_information.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

const f=Math.fround;
async function fixture(flags=1){
  const actor={id:0x80000001,areaId:0x80000002,position:[0,0,0],orientation:[1,0,0],nativeField76c:0,nativeMovementFlags8d4:65535,
    objectActionState:createObjectActionState(),nativePathInfo:new PathInformation(0x80000001)},area={id:actor.areaId},trace=[];
  const p={dead:()=>0,dying:()=>0,client:()=>null,setLock:()=>{},object:()=>null,area:o=>area,hasModule:()=>true,
    plot:(path,budget)=>{trace.push(['plot',budget]);return 2;},setAnimation:(o,state)=>trace.push(['animation',state]),activityManager:(o,request)=>trace.push(['activity',request]),
    walk:(o,group)=>{trace.push(['walk',group]);return 1;},useRange:(o,id,out)=>{out.range=1.5;return 1;},inUseRange:()=>0};
  await addMoveToPointFront(actor,7,[10,2,-3],area.id,invalid,1,1.5,0,0,0,0,0,0,0,p);
  const node=actor.objectActionState.list.shift();node.parameterData[5]=flags;
  return{actor,area,path:actor.nativePathInfo,node,p,trace};
}
test('native movement plots before client/target lookup, initializes native path fields then walks in same group',async()=>{
  const {actor,area,path,node,p,trace}=await fixture();p.client=()=>{assert.equal(trace.length,1);return null;};
  assert.equal(await executeMoveToPoint(actor,node,p),1);
  assert.deepEqual(trace,[['plot',1000],['plot',1000],['animation',4],['activity',8],['walk',7]]);
  assert.deepEqual([0x4c,0x50,0x54].map(o=>path.raw.getFloat32(o,true)),[10,3,2]);assert.equal(path.raw.getUint32(0x60,true),area.id);
  assert.equal(path.field24,actor.id);assert.equal(path.field28,invalid);assert.equal(path.raw.getInt32(0,true),0);
  assert.equal(path.raw.getInt32(0x5c,true),15);assert.equal(path.raw.getInt32(0x98,true),0);
});
test('client tracking forces run but exact field76c==1 forces walk; flags client-path bit is independent',async()=>{
  const {actor,path,node,p,trace}=await fixture(2);node.parameterData[4]=0x80000005|0;p.client=()=>({});
  assert.equal(await executeMoveToPoint(actor,node,p),1);assert.ok(trace.some(t=>t[0]==='animation'&&t[1]===4));assert.equal(path.raw.getInt32(0,true),1);
  trace.length=0;actor.nativeField76c=1;assert.equal(await executeMoveToPoint(actor,node,p),1);assert.ok(trace.some(t=>t[0]==='animation'&&t[1]===2));
});
test('in-range creature resets search without walking; offset flags invalidate tracking before use queries',async()=>{
  const {actor,path,node,p,trace}=await fixture();const target={id:0x80000005,objectType:5,position:[10,2,-3],orientation:[1,0,0]};
  node.parameterData[4]=target.id|0;p.object=()=>target;p.inUseRange=(o,id,extra,transparent)=>{assert.equal(id,target.id);assert.equal(extra,f(-f(.1)));assert.equal(transparent,0);return 1;};
  assert.equal(await executeMoveToPoint(actor,node,p),2);assert.deepEqual(trace,[['plot',1000],['animation',0]]);assert.equal(path.allocations.size,0);
  trace.length=0;node.parameterData[5]=49;p.inUseRange=(o,id)=>{assert.equal(id,invalid);return 0;};assert.equal(await executeMoveToPoint(actor,node,p),1);
  assert.equal(path.field28,invalid);
});
test('moved creature retarget requires native safe-location output, compares strict improvement and preserves flags/group',async()=>{
  const {actor,node,p}=await fixture(1|128|8);const target={id:0x80000005,objectType:5,position:[20,2,-3],orientation:[1,0,0]};node.parameterData[4]=target.id|0;
  p.object=()=>target;await assert.rejects(executeMoveToPoint(actor,node,p),/provider safeLocation/);assert.equal(actor.objectActionState.list.count,0);
  p.safeLocation=(area,point,radius,path,flag,out)=>{assert.equal(radius,20);assert.equal(flag,1);out.point=[19,2,-3];};
  assert.equal(await executeMoveToPoint(actor,node,p),2);const replacement=actor.objectActionState.list.head.action;
  assert.equal(replacement.groupId,7);assert.equal(actionParameter(replacement,4),target.id);assert.equal(actionParameter(replacement,5),137);
  assert.deepEqual([0,1,2].map(i=>actionParameter(replacement,i)),[19,3,2]);
});
test('target without area uses stored canonical movement goal/area without preview position substitution',async()=>{
  const {actor,node,p}=await fixture();const target={id:0x80000005,objectType:5,nativeMovementAreaId:0x80000008,nativeMovementGoal:[8,4,-6]};
  node.parameterData[4]=target.id|0;p.object=()=>target;p.area=o=>o===target?null:{id:actor.areaId};
  assert.equal(await executeMoveToPoint(actor,node,p),2);const replacement=actor.objectActionState.list.head.action;
  assert.deepEqual([0,1,2,3,4].map(i=>actionParameter(replacement,i)),[8,6,4,0x80000008,target.id]);
});
test('native path failure inserts client-selected retry wait, stores sequence byte/current goal and returns3',async()=>{
  const {actor,node,path,p,trace}=await fixture(3);p.plot=()=>3;p.client=()=>({});node.parameterData[7]=513;
  p.terminateClientPath=(o,sequence)=>trace.push(['terminate',sequence]);assert.equal(await executeMoveToPoint(actor,node,p),3);
  assert.equal(path.raw.getUint32(0x20,true),1);assert.deepEqual([0x4c,0x50,0x54].map(o=>path.raw.getFloat32(o,true)),[0,-0,0]);
  const wait=actor.objectActionState.list.head.action;assert.equal(wait.actionId,30);assert.equal(wait.groupId,7);assert.equal(actionParameter(wait,0),f(.1));
  assert.deepEqual(trace,[['animation',0],['terminate',513]]);
});
test('movement-disabled, dead, no-area and exact-location branches retain distinct native results/ordering',async()=>{
  const {actor,node,p,trace}=await fixture();actor.nativeMovementFlags8d4=0;assert.equal(await executeMoveToPoint(actor,node,p),3);assert.deepEqual(trace,[['plot',1000],['animation',1]]);
  trace.length=0;p.dead=()=>1;assert.equal(await executeMoveToPoint(actor,node,p),3);assert.deepEqual(trace,[]);
  p.dead=()=>0;actor.nativeMovementFlags8d4=2;p.area=()=>null;assert.equal(await executeMoveToPoint(actor,node,p),1);
  p.area=()=>({id:actor.areaId});actor.position=[10,0,-3];p.safePoint=()=>0;trace.length=0;
  assert.equal(await executeMoveToPoint(actor,node,p),2);assert.deepEqual(trace,[['plot',1000],['animation',1]]);assert.deepEqual(actor.position,[10,0,-3]);
});
test('door closed event31 stays pending; open event30 removes only matching group/target followup and resets route owners',async()=>{
  const {actor,node,path,p,trace}=await fixture(513);const door={id:0x80000005,objectType:10};node.parameterData[4]=door.id|0;
  p.object=()=>door;p.clickable=()=>1;p.inUseRange=()=>1;p.openState=()=>0;
  p.blockedEvent=(...args)=>trace.push(['blocked',...args]);assert.equal(await executeMoveToPoint(actor,node,p),1);assert.deepEqual(trace.at(-1),['blocked',door.id,actor.id,{scriptEvent:31}]);
  const followup=addObjectAction(actor.objectActionState,17,7,[{type:3,value:door.id}]);addObjectAction(actor.objectActionState,12,7,[{type:3,value:door.id}]);
  path.allocations.set(0x80,new Float32Array(4));path.allocations.set(0x190,new Uint8Array(8));p.openState=()=>1;p.useEvent=(...args)=>trace.push(['use',...args]);
  assert.equal(await executeMoveToPoint(actor,node,p),2);assert.equal(actor.objectActionState.list.count,1);assert.equal(actor.objectActionState.list.head.action.actionId,12);assert.equal(path.allocations.size,0);
  assert.ok(trace.some(t=>t[0]==='use'&&t[1]===actor.id&&t[2]===door.id));
});
test('matching followup uses full uint32 target and never removes a different group',async()=>{
  const {actor}=await fixture();const node=addObjectAction(actor.objectActionState,17,8,[{type:3,value:0x80000005}]);
  await deleteMatchingMoveFollowup(actor,0x80000005,7);assert.equal(actor.objectActionState.list.head.action,node);
  await deleteMatchingMoveFollowup(actor,0x80000005,8);assert.equal(actor.objectActionState.list.count,0);
});
