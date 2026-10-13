import test from 'node:test';
import assert from 'node:assert/strict';
import { getUseRange, isInUseRange } from '../src/use_range.js';
import { PathInformation } from '../src/path_information.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(type=5){
  const area={},actor={id:1,areaId:3,position:[0,0,0],nativePathInfo:new PathInformation(1)};
  const target={id:2,objectType:type,areaId:3,position:[1.5,20,0],chairId:invalid,nativePathInfo:new PathInformation(2)};
  const p={object:id=>id===target.id?target:null,asObject:o=>o,area:o=>o.areaId===3?area:null,lineOfSight:()=>1};return{actor,target,p};
}
test('native use range retains missing-target point and writes base personal space; creature radius/chair use exact float sequence',async()=>{
  const {actor,target,p}=fixture(),original=[9,8,7],out={point:original,range:10};
  assert.equal(await getUseRange(actor,invalid,out,p),0);assert.equal(out.point,original);assert.equal(out.range,actor.nativePathInfo.field4);
  actor.nativePathInfo.field8=.25;target.nativePathInfo.field8=.5;
  assert.equal(await getUseRange(actor,target.id,out,p),1);assert.deepEqual(out.point,target.position);assert.equal(out.range,Math.fround(.75+Math.fround(.3)));
  target.chairId=0x80000004;await getUseRange(actor,target.id,out,p);assert.equal(out.range,Math.fround(.75+Math.fround(.8)));
  target.areaId=invalid;out.point=original;assert.equal(await getUseRange(actor,target.id,out,p),0);assert.equal(out.point,original);
});
test('ordinary use range uses horizontal <=, height-raised LOS and .1 allowance, with pre-LOS position snapshot',async()=>{
  const {actor,target,p}=fixture(),calls=[];p.lineOfSight=(a,from,to,source,id,flag)=>{calls.push([from,to,source,id,flag]);actor.position[0]=100;return 1;};
  assert.equal(await isInUseRange(actor,target.id,0,7,p),1);
  assert.deepEqual(calls,[[[0,1,0],[1.5,21,0],1,2,7]]);
  actor.position=[0,0,0];target.position[0]=2;assert.equal(await isInUseRange(actor,target.id,0,0,p),0);
  actor.position=[0,0,0];p.lineOfSight=()=>0;assert.equal(await isInUseRange(actor,target.id,100,0,p),0);
  target.areaId=invalid;assert.equal(await isInUseRange(actor,target.id,100,0,p),0);
});
test('trigger transition bypasses LOS/range; ordinary trigger/placeable/door require native action-point owners',async()=>{
  const {actor,target,p}=fixture(7);p.transition=()=>1;p.inTrigger=()=>7;p.lineOfSight=()=>assert.fail();
  assert.equal(await isInUseRange(actor,target.id,0,0,p),7);
  const out={point:[0,0,0],range:0};await getUseRange(actor,target.id,out,p);assert.equal(out.range,actor.nativePathInfo.field4);
  p.transition=()=>0;await assert.rejects(getUseRange(actor,target.id,out,p),/triggerPoint/);
  p.triggerPoint=()=>[1,2,3];await getUseRange(actor,target.id,out,p);assert.equal(out.range,Math.fround(actor.nativePathInfo.field4+.5));
  target.objectType=9;await assert.rejects(getUseRange(actor,target.id,out,p),/placeablePoint/);
  p.placeablePoint=()=>[4,5,6];await getUseRange(actor,target.id,out,p);assert.deepEqual(out.point,[4,5,6]);
  target.objectType=10;p.doorPoint=(t,from,flag)=>{assert.deepEqual(from,[0,0,0]);assert.equal(flag,0);return[7,8,9];};p.height=(a,pt)=>{assert.deepEqual(pt,[7,8,9]);return 12;};
  await getUseRange(actor,target.id,out,p);assert.deepEqual(out.point,[7,12,9]);assert.equal(out.range,Math.fround(actor.nativePathInfo.field4+.75));
});
