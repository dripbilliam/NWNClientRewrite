import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {Group,PerspectiveCamera,Vector3} from 'three';
import {GameCamera} from '../src/game_camera.js';import {NetworkPlayerCamera} from '../src/network_camera.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';import {parse2da} from '../src/area.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-camera-attachment-observations.json',import.meta.url)));
const keys=['clampYaw','minYaw','maxYaw','clampPitch','minPitch','maxPitch','clampDist','minDist','maxDist'];
test('original full attachment and Follow constructor agree across target types, modes, height, cached pose and locks',()=>{
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,216);
 for(const row of fixture.rows){const c=row.case;assert.equal(row.calls[0].id,c.targetId,'target ID survives native app-manager thunks');
  if(!row.follow.created){assert.equal(row.targetId,c.oldTarget??0x7f000000);continue;}
  const s=new GameCamera();s.mode=c.mode??1;s.locks.pitch=Boolean(c.pitchLocked);s.locks.distance=Boolean(c.distanceLocked);const cache=c.cached??[12.75,35.125,42.5];s.rememberedPose={distance:cache[0],yaw:cache[1],pitch:cache[2]};
  s.attach({position:c.position??[2,3,.5],height:c.height??1.75,creature:c.creature??true,findClearView:Boolean(c.findClear)});
  for(const key of ['distance','yaw','pitch','spring','focus','offset'])assert.deepEqual(s[key],row.follow[key],JSON.stringify({c,key}));assert.deepEqual(keys.map(k=>s[k]),row.follow.clamps);assert.equal(s.findClearView,Boolean(row.findClear));
 }
});
test('native attachment sender bodies preserve canonical client IDs and BOOL fields',()=>{
 assert.equal(fixture.packets.length,10);for(const row of fixture.packets){const bytes=Uint8Array.from([80,16,10,...Buffer.from(row.body,'hex')]),message=decodeServerGameMessage(bytes),expected=row.targetId===0x7f000000?row.targetId:(row.targetId|0x80000000)>>>0;assert.deepEqual(message,{kind:'camera-attach',major:16,minor:10,objectId:expected,findClearView:row.findClear});assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,6)));}
});
function setup(){
 const self=0xffffffff,target=0x80000008,area=0x80000001,reports=[],registry=new Map([[self,{id:self,areaId:area,objectType:5,appearance:{appearance:0},replicated:{position:[1,2,0],orientation:[-1,0,0],animation:4}}],[target,{id:target,areaId:area,objectType:5,appearance:{appearance:1},replicated:{position:[10,12,0],orientation:[0,1,0],animation:4}}]]),world={localObjectId:self,areaId:area,registry};
 const objects=new Map();for(const [id,o]of registry){const wrapper=new Group(),p=o.replicated.position;wrapper.position.set(p[0],p[2],-p[1]);objects.set(id,{wrapper});}
 const presentation={objects,tables:{appearance:parse2da('2DA V2.0\n\nHEIGHT\n0 1.75\n1 3.0\n')},motion:{objects:new Map()}},p=new NetworkPlayerCamera({report:(...r)=>reports.push(r)}),camera=new PerspectiveCamera(),controls={target:new Vector3()};p.update(world,presentation,camera,controls,.016);
 return{p,world,presentation,camera,controls,reports,self,target};
}
test('attachment follows rendered target without changing control or canonical state and reverts on destruction',()=>{
 const f=setup(),{p,world,presentation,camera,controls,self,target}=f,before=structuredClone([...world.registry.values()]);
 assert.ok(p.attach({objectId:target,findClearView:false},world,presentation));p.update(world,presentation,camera,controls,.016);assert.equal(p.targetId,target);assert.equal(p.controlledId,self);assert.equal(p.controller.height,2.5);
 presentation.objects.get(target).wrapper.position.x+=1;p.update(world,presentation,camera,controls,.016);assert.equal(p.anchor[0],11);assert.deepEqual([...world.registry.values()],before);assert.equal(world.localObjectId,self);
 world.registry.get(target).replicationRemoved=true;presentation.objects.delete(target);p.update(world,presentation,camera,controls,.016);assert.equal(p.attachmentId,null);assert.equal(p.targetId,self);assert.equal(p.controller.height,1.25);
});
test('known target model replacement waits without losing attachment, and invalid/other-area targets are ignored with diagnostics',()=>{
 const {p,world,presentation,camera,controls,target,reports}=setup();p.attach({objectId:target,findClearView:false},world,presentation);const binding=presentation.objects.get(target);presentation.objects.delete(target);
 assert.equal(p.update(world,presentation,camera,controls,.016),false);assert.equal(p.attachmentId,target);assert.equal(p.waitingForTarget,true);presentation.objects.set(target,binding);p.update(world,presentation,camera,controls,.016);assert.equal(p.waitingForTarget,false);
 assert.equal(p.attach({objectId:0x80000077,findClearView:false},world,presentation),false);assert.equal(p.attachmentId,target);assert.equal(reports.at(-1)[0],'network.camera-attachment-unavailable');
 world.registry.get(target).areaId++;assert.equal(p.attach({objectId:target,findClearView:false},world,presentation),false);p.update(world,presentation,camera,controls,.016);assert.equal(p.attachmentId,null);
});
test('native mode steering and mode height still use the controlled PC while position follows the attachment',()=>{
 const {p,world,presentation,camera,controls,target}=setup();p.attach({objectId:target,findClearView:false},world,presentation);p.receive({kind:'camera-mode',mode:0},world,presentation);p.update(world,presentation,camera,controls,.1);assert.equal(p.controller.height,1.75);assert.ok(p.controller.yaw>0&&p.controller.yaw<20,'controlled creature faces90; remote creature faces0');assert.equal(p.targetId,target);
});
test('missing clear-view geometry is diagnosed once and cannot permanently stall normal camera updates',()=>{
 const {p,world,presentation,camera,controls,target,reports}=setup();assert.ok(p.attach({objectId:target,findClearView:true},world,presentation));const remembered=structuredClone(p.controller.rememberedPose);p.update(world,presentation,camera,controls,.016);assert.deepEqual(p.controller.rememberedPose,remembered);assert.equal(reports.at(-1)[0],'network.camera-clear-view-unavailable');assert.equal(p.controller.findClearView,false);p.update(world,presentation,camera,controls,.016);assert.equal(reports.length,1);
 p.reset([2,0,-3]);assert.equal(p.attachmentId,null);assert.equal(p.controller.findClearView,false);assert.equal(p.targetId,null);
});
test('area entry waits for the PC render object, clears an old attachment, retains camera commands and runs clear-view once',()=>{
 const {p,world,presentation,camera,controls,target,self}=setup();p.attach({objectId:target,findClearView:false},world,presentation);p.receive({kind:'camera-limits',limits:{minPitch:10,maxPitch:80,minDist:2,maxDist:30}},world,presentation);p.receive({kind:'camera-store'},world,presentation);p.receive({kind:'camera-lock',axis:'yaw',locked:true},world,presentation);
 const saved=structuredClone(p.controller.savedCamera),limits={...p.controller.rawLimits};p.enterArea([4,0,-5]);assert.equal(p.attachmentId,null);const binding=presentation.objects.get(self);presentation.objects.delete(self);assert.equal(p.update(world,presentation,camera,controls,.016),false);assert.equal(p.pendingEntryAttach,true);
 presentation.root=new Group();presentation.objects.set(self,binding);p.update(world,presentation,camera,controls,.016);assert.equal(p.pendingEntryAttach,false);assert.equal(p.targetId,self);assert.equal(p.controller.findClearView,false);assert.equal(p.controller.clearViewResult.queries,1);assert.deepEqual(p.controller.rawLimits,limits);assert.deepEqual(p.controller.savedCamera,saved);assert.equal(p.controller.locks.yaw,true);
 p.reset();assert.equal(p.pendingEntryAttach,false);assert.equal(p.controller.savedCamera,null);assert.equal(p.controller.locks.yaw,false);
});
