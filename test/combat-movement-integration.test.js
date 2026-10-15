import test from 'node:test';
import assert from 'node:assert/strict';
import { ModuleSession } from '../src/module_session.js';
import { NativeAreaGeometry } from '../src/area_geometry.js';
import { NativeAreaSpatialArray } from '../src/area_spatial.js';
import { NativeIdList } from '../src/native_id_list.js';
import { NativeRandom } from '../src/native_random.js';
import { createCombatRound } from '../src/combat_round.js';
import { parse2da } from '../src/area.js';
import { RESOURCE_TYPE as types } from '../src/resource_archive.js';
import { runtimeDiagnostics } from '../src/runtime_diagnostics.js';
import { addMoveToPointFront } from '../src/movement_actions.js';
import { addObjectAction } from '../src/object_actions.js';

function fixture(walk=1){
  const text='#MAXWALKMESH ASCII\nnode aabb surface\nposition 0 0 0\nverts 4\n-5 -5 0\n5 -5 0\n5 5 0\n-5 5 0\nfaces 2\n0 1 2 0 0 0 0 0\n0 2 3 0 0 0 0 0\nendnode\n';
  const resolver={getResource:async(ref,type)=>new TextEncoder().encode(type===types.SET?'[GENERAL]\nTransition=2.5\n[TILES]\nCount=1\n[TILE0]\nModel=tile\n':type===types.TWO_DA?`2DA V2.0\n\nWalk\n0 ${walk}\n`:text)};
  const s=new ModuleSession(resolver,{runStartupScripts:false});
  s.characterRules={appearance:parse2da('2DA V2.0\n\nPREFATCKDIST HITDIST\n0 1 0.5\n')};
  const area=s.register('area','area',{objects:[],width:2,height:1,tilePlacements:[{Tile_ID:0},{Tile_ID:0}],tilesetResRef:'tiles',resRef:'fixture'});
  area.nativeSpatial=new NativeAreaSpatialArray(s.registry);area.nativeSubareas=new NativeIdList();area.nativeGeometry=new NativeAreaGeometry(area,s.geometryResources,s.registry);
  const actor=s.register('player','actor',{areaId:area.id,position:[4,0,-5],isPC:true,inventory:[],creatureData:{Appearance_Type:0},stats:{currentHP:30},combatRound:createCombatRound()});
  const target=s.register('creature','target',{areaId:area.id,position:[8,0,-5],inventory:[],creatureData:{Appearance_Type:0},stats:{currentHP:30},combatRound:createCombatRound()});
  s.player=actor;s.random=new NativeRandom(1);actor.nativeField700=1;
  for(const o of [actor,target]){area.objects.push(o.id);area.nativeSpatial.insert(o.id);}
  const trigger=s.register('trigger','trigger',{areaId:area.id,position:[4.5,0,-5],geometry:[[4.5,4],[5,4],[5,6],[4.5,6]],scripts:{enter:'enter',exit:'exit'}});
  area.objects.push(trigger.id);area.nativeSpatial.insert(trigger.id);area.nativeSubareas.append(trigger.id);
  return{s,area,actor,target,trigger};
}

test('live combat step combines real tile/canonical collision, event10 membership, position alias and spatial ordering',async()=>{
  const {s,area,actor,target,trigger}=fixture(),alias=actor.position,calls=[];
  actor.nativePathInfo.field28=123;
  assert.equal((await s.combat.combatStep(actor,2,500,target.id)).moved,true);
  assert.equal(actor.position,alias);assert.deepEqual(actor.position,[Math.fround(4+Math.fround(0.8)),0,-5]);
  assert.equal(actor.nativePathInfo.field28,123);assert.equal(area.nativePathInfo280,actor.nativePathInfo);
  assert.deepEqual([...area.nativeSpatial.view()],[trigger.id,actor.id,target.id]);
  assert.deepEqual([...actor.nativeSubareaMembership.view()],[trigger.id]);
  assert.equal(trigger.eventObjects.entering,undefined);
  assert.equal(s.scheduler.events.length,1);assert.equal(s.scheduler.events[0].event.eventId,10);
  s.scheduler.beforePump=()=>{};s.program=async name=>({name});s.vm={run:async(program,self)=>calls.push([program.name,self,s.commands.GetEnteringObject([], {self})])};
  await s.scheduler.pump();assert.deepEqual(calls,[['enter',trigger.id,actor.id]]);
  assert.equal(s.random.draws,0);
});
test('live combat movement rejects denied surfaces and visible third creatures without emitting trigger events',async()=>{
  for(const mode of ['surface','creature']){
    const {s,area,actor,target}=fixture(mode==='surface'?0:1);
    if(mode==='creature'){
      const other=s.register('creature','blocker',{areaId:area.id,position:[4.7,0,-5],inventory:[],stats:{currentHP:30},combatRound:createCombatRound()});
      area.objects.push(other.id);area.nativeSpatial.insert(other.id);actor.perception.set(other.id,1);
    }
    assert.equal((await s.combat.combatStep(actor,2,500,target.id)).moved,false);
    assert.deepEqual(actor.position,[4,0,-5]);assert.equal(s.scheduler.events.length,0);assert.equal(actor.nativeSubareaMembership.count,0);
    assert.equal(actor.combatRound.paused,false);assert.equal(actor.animationState,1);
  }
});
test('live orbital step loads geometry before RNG; unavailable resources leave path and position intact',async()=>{
  const {s,actor,target}=fixture();target.position=[5.5,0,-5];
  s.geometryResources.resolver.getResource=async()=>{throw new Error('Missing WOK input');};
  const before=runtimeDiagnostics.records.length,field28=actor.nativePathInfo.field28;
  await assert.rejects(s.combat.combatStep(actor,1,500,target.id),/Missing WOK/);
  assert.equal(s.random.draws,0);assert.equal(actor.nativePathInfo.field28,field28);assert.deepEqual(actor.position,[4,0,-5]);
  assert.ok(runtimeDiagnostics.records.slice(before).some(r=>r.context?.objectId===actor.id));
});
test('live orbital math performs an actual clear step with native target height and no explicit-step RNG',async()=>{
  const {s,area,actor,target}=fixture();area.nativeSubareas.setSize(0);target.position=[6,0,-5];
  assert.equal((await s.combat.combatStep(actor,4,500,target.id)).moved,true);
  assert.equal(actor.position[1],target.position[1]);assert.notEqual(actor.position[2],-5);assert.equal(s.random.draws,0);
});
test('unavailable trap event is recorded at dispatch with canonical target while movement membership commits',async()=>{
  const {s,actor,target,trigger}=fixture();trigger.authored={TrapFlag:1};
  await s.combat.combatStep(actor,2,500,target.id);s.scheduler.beforePump=()=>{};
  const before=runtimeDiagnostics.records.length;await s.scheduler.pump();
  assert.equal(trigger.eventObjects.entering,actor.id);assert.deepEqual([...actor.nativeSubareaMembership.view()],[trigger.id]);
  assert.ok(runtimeDiagnostics.records.slice(before).some(r=>r.context?.objectId===trigger.id&&r.message.includes('enterTrap')));
});
test('live action1 walks on real tiles through canonical queue, height, subareas and persistent spatial storage',async()=>{
  const {s,area,actor}=fixture(),positionAlias=actor.position;
  s.characterRules.creaturespeed=parse2da('2DA V2.0\n\nWALKRATE RUNRATE\n0 2 4\n');
  actor.nativeFrameElapsedD4=100;actor.nativeField700=0;
  const before=runtimeDiagnostics.records.length;
  await addMoveToPointFront(actor,9,[6,0,-5],area.id,0x7f000000,0,0,0,0,0,0,0,0,0,{setLock:(...args)=>s.combat.setLock(...args)});
  const node=actor.objectActionState.list.head.action;
  await s.combat.runActions(actor,1,1000);
  assert.equal(actor.objectActionState.list.head.action,node);assert.ok(actor.position[0]>4&&actor.position[0]<6);
  assert.equal(actor.position,positionAlias);assert.equal(actor.animationState,2);assert.equal(area.nativePathInfo280,actor.nativePathInfo);
  for(let i=0;i<20&&actor.objectActionState.list.count;i++)await s.combat.runActions(actor,1,1100+i*100);
  assert.equal(actor.objectActionState.list.count,0);assert.equal(actor.position[0],6);assert.equal(actor.position[1],0);
  assert.equal(actor.animationState,0);assert.equal(s.random.draws,0);
  // AIActionMoveToPoint's within-.0001 snap branch completes independently
  // of WalkUpdateLocation's endpoint reset, retaining its completed path cache.
  assert.equal(actor.nativePathInfo.allocations.size,2);assert.equal(actor.nativePathInfo.raw.getInt32(0x78,true),1);
  assert.ok(runtimeDiagnostics.records.slice(before).every(r=>r.severity!=='error'));
});
test('unavailable path-node input preserves live move action identity and reports requesting canonical actor',async()=>{
  const {s,area,actor}=fixture(0);actor.nativeFrameElapsedD4=100;
  s.module={nativePathfindingLevel464:2};
  await addMoveToPointFront(actor,9,[6,0,-5],area.id,0x7f000000,0,0,0,0,0,0,0,0,0,{setLock:(...args)=>s.combat.setLock(...args)});
  const node=actor.objectActionState.list.head.action,before=runtimeDiagnostics.records.length;
  await assert.rejects(s.combat.runActions(actor,1,1000),/tile path node information/);
  assert.equal(actor.objectActionState.list.head.action,node);assert.deepEqual(actor.position,[4,0,-5]);assert.equal(s.random.draws,0);
  assert.ok(runtimeDiagnostics.records.slice(before).some(r=>r.context?.objectId===actor.id&&r.message.includes('tile path node information')));
});

test('live ClearAllActions cancels an approach group, respects protected records and resets the owned path',async()=>{
  const {s,area,actor}=fixture();actor.commandable=1;actor.animationState=4;
  await addMoveToPointFront(actor,9,[6,0,-5],area.id,0x7f000000,0,0,0,0,0,0,0,0,0,{setLock:(...args)=>s.combat.setLock(...args)});
  for(const id of [19,17,30,12])addObjectAction(actor.objectActionState,id,9);
  const protectedNode=addObjectAction(actor.objectActionState,30,10);protectedNode.nativeField9c=0;
  actor.objectActionState.startDay=2;actor.objectActionState.startTime=5;
  actor.nativePathInfo.allocations.set(0x80,new Float32Array([4,5,6,5]));actor.nativePathInfo.raw.setInt32(0x7c,4,true);
  await s.combat.clearActions(actor);
  assert.deepEqual([...actor.objectActionState.list],[protectedNode]);assert.equal(actor.animationState,1);
  assert.equal(actor.objectActionState.startDay,0);assert.equal(actor.nativePathInfo.allocations.size,0);
  assert.equal(s.random.draws,0);
});

test('live move uses native grid search around a perceived blocking creature on real tiles',async()=>{
  const {s,area,actor}=fixture();s.module={nativePathfindingLevel464:2};
  s.characterRules.creaturespeed=parse2da('2DA V2.0\n\nWALKRATE RUNRATE\n0 2 4\n');
  actor.nativeFrameElapsedD4=100;actor.nativeField700=0;actor.nativePathInfo.field4=.3;actor.nativePathInfo.field8=.3;
  const blocker=s.register('creature','grid-blocker',{areaId:area.id,position:[5.5,0,-5],inventory:[],stats:{currentHP:30},combatRound:createCombatRound()});
  blocker.nativePathInfo.field4=.3;blocker.nativePathInfo.field8=.3;
  const drawsAfterConstruction=s.random.draws;
  area.objects.push(blocker.id);area.nativeSpatial.insert(blocker.id);actor.perception.set(blocker.id,1);
  await addMoveToPointFront(actor,9,[7,0,-5],area.id,0x7f000000,0,0,0,0,0,0,0,0,0,{setLock:(...args)=>s.combat.setLock(...args)});
  const visited=[];
  for(let n=0;n<80&&actor.objectActionState.list.count;n++){
    await s.combat.runActions(actor,1,1000+n*100);visited.push(actor.position.slice());
  }
  assert.equal(actor.objectActionState.list.count,0);assert.equal(actor.position[0],7);assert.equal(actor.position[2],-5);
  assert.ok(visited.some(point=>Math.abs(point[2]+5)>.3),'route must pass around the creature');
  assert.equal(s.nativeAIFieldAC,1);assert.equal(s.random.draws,drawsAfterConstruction);
  assert.deepEqual(blocker.position,[5.5,0,-5]);
});
