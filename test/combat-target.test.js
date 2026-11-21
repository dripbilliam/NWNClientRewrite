import test from 'node:test';
import assert from 'node:assert/strict';
import { attackClearLine, nearestEnemy, newCombatTarget } from '../src/combat_target.js';
import { PathInformation } from '../src/path_information.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture() {
  const area = {}, actor = { id:0x80000001,position:[0,0,0],nativePathInfo:new PathInformation(0x80000001),objectType:5 };
  const objects = new Map([[actor.id,actor]]), ids = [actor.id], trace = [];
  const add=(id,position,radius=0.6)=>{const o={id,position,objectType:5,nativePathInfo:new PathInformation(id),flags:1,reaction:2};o.nativePathInfo.field8=radius;objects.set(id,o);return o;};
  const p={area:()=>area,areaIds:()=>ids,object:id=>objects.get(id),asObject:o=>o,asCreature:o=>o.objectType===5?o:null,
    reaction:(o,id)=>{trace.push(['reaction',id]);return objects.get(id).reaction;},dead:o=>o.dead??0,dying:o=>o.dying??0,
    visibility:(o,id)=>{trace.push(['visibility',id]);return objects.get(id).flags;},clearLine:(o,id)=>{trace.push(['clear',id]);return objects.get(id).clear??1;}};
  return{actor,area,objects,ids,trace,add,p};
}
test('nearest enemy walks left before right, keeps strict clearance ties and excludes canonical IDs',async()=>{
  const t=fixture(),left=t.add(0x80000002,[-2,0,0]),right=t.add(0x80000003,[2,0,0]);t.ids.splice(0,1,left.id,t.actor.id,right.id);
  assert.equal(await nearestEnemy(t.actor,10,invalid,1,1,t.p),left.id);
  assert.deepEqual(t.trace.filter(e=>e[0]==='clear'),[['clear',left.id],['clear',right.id]]);
  assert.equal(await nearestEnemy(t.actor,10,left.id,1,1,t.p),right.id);
  assert.equal(await nearestEnemy(t.actor,Math.fround(Math.fround(2-t.actor.nativePathInfo.field8)-right.nativePathInfo.field8),left.id,1,1,t.p),invalid);
});
test('nearest enemy uses 3D surface clearance rather than center distance and rejects unseen/dead/dying/blocked candidates',async()=>{
  const t=fixture(),close=t.add(2,[2,0,0],0.1),wide=t.add(3,[3,0,0],2),up=t.add(4,[0,8,0],0.6);
  t.ids.push(up.id,close.id,wide.id);assert.equal(await nearestEnemy(t.actor,20,invalid,1,1,t.p),wide.id);
  wide.flags=2;close.dead=1;up.dying=1;assert.equal(await nearestEnemy(t.actor,20,invalid,1,1,t.p),invalid);
  close.dead=0;close.clear=0;assert.equal(await nearestEnemy(t.actor,20,invalid,1,1,t.p),invalid);
  assert.equal(await nearestEnemy(t.actor,20,invalid,0,0,t.p),wide.id);
  assert.ok(t.trace.some(e=>e[0]==='visibility'&&e[1]===wide.id));
});
test('nearest enemy shrinks X window after processing the outlying object; missing/excluded objects do not stop a direction',async()=>{
  const t=fixture(),near=t.add(2,[1,0,0]),boundary=t.add(3,[20,0,0]),beyond=t.add(4,[21,0,0],40);
  boundary.objectType=9;t.ids.push(near.id,99,boundary.id,beyond.id);
  assert.equal(await nearestEnemy(t.actor,30,invalid,1,0,t.p),near.id);
  assert.ok(!t.trace.some(e=>e[1]===beyond.id));
  // Skipping an excluded boundary does not run its early-break position test.
  assert.equal(await nearestEnemy(t.actor,30,boundary.id,1,0,t.p),beyond.id);
  t.ids.splice(t.ids.indexOf(t.actor.id),1);assert.equal(await nearestEnemy(t.actor,30,invalid,1,0,t.p),invalid);
});
test('new target applies strict full 3D short-ranged reach using pre-call position snapshots',async()=>{
  const t=fixture(),target=t.add(2,[3,0,0]),trace=[];
  const p={...t.p,nearestEnemy:(...args)=>{trace.push(args.slice(1));return target.id;},maximumRange:(o,id,force,short)=>{trace.push([id,force,short]);return 3;}};
  assert.equal(await newCombatTarget(t.actor,0x80000003,p),null);
  assert.deepEqual(trace,[[invalid,0,1],[13,0x80000003,1,1],[target.id,0,1]]);
  target.position=[0,2,0];p.maximumRange=(o,id)=>{if(id!==invalid)target.position[1]=50;return 3;};
  assert.equal(await newCombatTarget(t.actor,invalid,p),target);
});
test('attack-clear-line raises native heights, restores path on failure and returns native collision result',async()=>{
  const t=fixture(),target=t.add(2,[4,2,-3]),path=t.actor.nativePathInfo;path.field28=123;
  const input=[-10000000,-10000000,-10000000],before=path.field8,calls=[];
  const p={...t.p,ranged:()=>0,lineOfSight:(a,from,to,source,id,flag)=>{calls.push([from,to,source,id,flag]);return 1;},
    creatureLine:(a,from,to,p,...args)=>{assert.deepEqual(from,[0,0]);assert.deepEqual(to,[4,-3]);assert.equal(p.field8,Math.fround(.01));assert.equal(p.field28,target.id);assert.deepEqual(args,[1,0,null,1]);return 7;}};
  assert.equal(await attackClearLine(t.actor,target.id,input,t.area,p),7);
  assert.deepEqual(input,[-10000000,-10000000,-10000000]);assert.deepEqual(calls,[[[0,1,0],[4,3,-3],t.actor.id,target.id,0]]);
  assert.equal(path.field8,before);assert.equal(path.field28,123);
  p.creatureLine=()=>{throw new Error('collision input missing');};await assert.rejects(attackClearLine(t.actor,target.id,target.position,t.area,p),/collision input/);
  assert.equal(path.field8,before);assert.equal(path.field28,123);
  p.ranged=()=>1;assert.equal(await attackClearLine(t.actor,target.id,target.position,t.area,p),1);
  p.lineOfSight=()=>0;assert.equal(await attackClearLine(t.actor,target.id,target.position,t.area,p),0);
});
