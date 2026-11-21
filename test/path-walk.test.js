import test from 'node:test';
import assert from 'node:assert/strict';
import { PathInformation } from '../src/path_information.js';
import { NativeIdList } from '../src/native_id_list.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';
import { walkPath,walkDistance,testWalkDistance } from '../src/path_walk.js';

const f=Math.fround;
function fixture(coordinates=[0,0,10,0]){
  const actor={id:0x80000001,position:[0,0,0],orientation:[1,0,0],animationState:2,nativeFrameElapsedD4:100,nativeAcceleration538:1,nativePathInfo:new PathInformation(0x80000001)};
  const path=actor.nativePathInfo;path.field28=invalid;path.allocations.set(0x80,new Float32Array(coordinates));path.raw.setInt32(0x7c,coordinates.length,true);
  const area={id:0x80000002},trace=[];
  const p={area:()=>area,height:()=>0,testDistance:()=>1,crossings:(a,start,end,ids)=>{trace.push(['crossing',start.slice(),end.slice()]);ids.append(0x80000003);},
    rate:()=>2000,closePanels:()=>trace.push(['panels']),updateSubareas:(a,start,end,provided,ids)=>trace.push(['subareas',start,end,provided,[...ids.view()]]),
    setPosition:(a,pos)=>{trace.push(['position',pos]);a.position=pos;},setOrientation:(a,dir)=>{trace.push(['orientation',dir]);a.orientation=dir;},object:()=>null,
    setAnimation:(a,state)=>{trace.push(['animation',state]);a.animationState=state;}};
  p.walkDistance=(...args)=>walkDistance(...args,p);
  return{actor,path,area,p,trace};
}
test('walk traverses ordered waypoints, accumulates crossings, and uses actual tile height for collision checks',async()=>{
  const {actor,path,p,trace}=fixture([0,0,1,0,1,2]);const out={},crossed=new NativeIdList(),tests=[];
  p.height=(a,pos)=>f(pos[0]+f(-pos[2]));p.testDistance=(a,start,end)=>{tests.push([start,end]);return 1;};
  assert.equal(await walkDistance(actor,2,out,crossed,p),0);assert.deepEqual(out.point,[1,2,-1]);assert.deepEqual(out.orientation,[0,0,-1]);
  assert.equal(path.raw.getInt32(0x98,true),4);assert.deepEqual(tests.map(c=>c.map(v=>v[1])),[[0,0],[0,1],[1,2]]);
  assert.deepEqual([...crossed.view()],[0x80000003,0x80000003,0x80000003]);assert.equal(trace.length,3);
});
test('collision cuts path at last position and retains prior orientation, original waypoint cursor, and native raw point',async()=>{
  const {actor,path,p}=fixture();actor.position=[2,3,-4];actor.orientation=[0,0,-1];path.raw.setInt32(0x98,2,true);path.raw.setUint8(0x130,255);
  p.testDistance=()=>0;p.height=()=>7;const out={};assert.equal(await walkDistance(actor,5,out,new NativeIdList(),p),1);
  assert.deepEqual(out.point,[2,7,-4]);assert.deepEqual(out.orientation,[0,0,-1]);assert.equal(path.raw.getInt32(0x98,true),2);
  assert.deepEqual([0x4c,0x50,0x54].map(o=>path.raw.getFloat32(o,true)),[2,4,7]);assert.equal(path.raw.getUint32(0x60,true),0x80000002);
  assert.equal(path.raw.getUint8(0x130),0);assert.equal(path.raw.getInt32(0x134,true),1);
  assert.deepEqual([0x138,0x13c,0x140].map(o=>path.raw.getFloat32(o,true)),[2,4,3]);
});
test('near last two-point route retains facing when travel would reverse it',async()=>{
  const {actor,p}=fixture([0,0,-.5,0]);const out={};assert.equal(await walkDistance(actor,.1,out,new NativeIdList(),p),0);
  assert.equal(out.orientation[0],1);assert.equal(out.point[0],f(-.1));
});
test('native frame walks correct distance and commits panels/subareas/position/orientation in order',async()=>{
  const {actor,p,trace}=fixture();assert.equal(await walkPath(actor,7,p),1);assert.equal(actor.position[0],f(.2));assert.equal(actor.nativeAcceleration538,1);
  assert.deepEqual(trace.slice(-4).map(t=>t[0]),['panels','subareas','position','orientation']);assert.equal(trace.at(-3)[3],1);
  actor.nativeFrameElapsedD4=0;const count=trace.length;assert.equal(await walkPath(actor,7,p),1);assert.equal(trace.length,count);
});
test('slope correction rewalks from saved waypoint cursor and retains accumulated crossings',async()=>{
  const {actor,path,p,trace}=fixture();const distances=[];p.walkDistance=(a,d,out,ids)=>{
    distances.push(d);assert.equal(path.raw.getInt32(0x98,true),0);path.raw.setInt32(0x98,2,true);ids.append(44);
    out.point=[d,d,0];out.orientation=[1,0,0];return 0;};
  assert.equal(await walkPath(actor,7,p),1);assert.equal(distances.length,2);assert.equal(distances[0],f(.2));
  assert.ok(distances[1]<distances[0]);assert.deepEqual(trace.find(t=>t[0]==='subareas')[4],[44,44]);
});
test('completed native walk resets search and returns action completion2 rather than allocator return',async()=>{
  const {actor,path,p}=fixture([0,0,.01,0]);assert.equal(await walkPath(actor,7,p),2);assert.equal(actor.position[0],f(.01));
  assert.equal(path.allocations.has(0x80),false);assert.equal(path.raw.getInt32(0x7c,true),0);assert.equal(actor.animationState,0);
});
test('distance test shrinks temporary creature radius but uses personal space for polygon queries, restores fields on failure',async()=>{
  const {actor,path,area}=fixture();path.field4=.8;path.field28=0x80000009;const saved=path.field8;const trace=[];
  const p={area:()=>area,polygons:(a,start,end,low,high,radius,ignored,hit,flag,excluded,transparent)=>{
    trace.push([low,high,radius,flag,excluded,transparent]);assert.equal(path.field28,invalid);assert.equal(path.field8,f(saved-f(.01)));return 1;},
    creatureLine:()=>1};
  assert.equal(await testWalkDistance(actor,[1,2,-3],[4,4,-6],p),1);assert.deepEqual(trace,[[f(2+f(-.1)),f(4+f(.5+f(.1))),f(.8),1,null,0]]);
  assert.equal(path.field8,saved);assert.equal(path.field28,0x80000009);
  p.polygons=()=>{throw new Error('missing resource');};await assert.rejects(testWalkDistance(actor,[0,0,0],[1,0,0],p),/missing resource/);
  assert.equal(path.field8,saved);assert.equal(path.field28,0x80000009);
});
test('door collision emits native event31 to moving actor only for door animation22',async()=>{
  const {actor,area}=fixture();const events=[];let state=22;
  const p={area:()=>area,polygons:(a,s,e,l,h,r,i,hit)=>{hit.id=55;return 0;},door:()=>({id:55,animationState:state}),
    blockedEvent:(...args)=>events.push(args),creatureLine:()=>assert.fail('polygon first')};
  assert.equal(await testWalkDistance(actor,[0,0,0],[1,0,0],p),0);assert.deepEqual(events,[[55,actor.id,{scriptEvent:31}]]);
  state=23;assert.equal(await testWalkDistance(actor,[0,0,0],[1,0,0],p),0);assert.equal(events.length,1);
});
test('friend bump sees restored radius then rechecks shrunken radius and requires exactly1 for success',async()=>{
  const {actor,path,area}=fixture();const saved=path.field8;let checks=0,recheck=2;
  const p={area:()=>area,polygons:()=>1,creature:()=>({id:55}),creatureLine:(a,s,e,path,segment,bump,hit)=>{
    assert.equal(path.field8,f(saved-f(.01)));checks++;if(hit){hit.id=55;return 0;}return recheck;},
    bumpFriends:()=>{assert.equal(path.field8,saved);return 1;},blockedEvent:()=>assert.fail('successful bump must recheck')};
  assert.equal(await testWalkDistance(actor,[0,0,0],[1,0,0],p),0);recheck=1;assert.equal(await testWalkDistance(actor,[0,0,0],[1,0,0],p),1);
  assert.equal(checks,4);assert.equal(path.field8,saved);
});
