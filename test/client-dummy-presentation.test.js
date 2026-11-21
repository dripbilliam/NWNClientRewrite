import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {GameObjectArray} from '../src/game_object_array.js';
import {ClientProjectilePresentation} from '../src/client_projectile_presentation.js';
import {visualLocalPoseServices} from '../src/visual_scene_pose.js';
import {NativeRandom} from '../src/native_random.js';
function fixture({deferred=false,failDummy=false}={}){
 const server=new GameObjectArray(),actor={objectType:5,position:[0,0,0],orientation:[1,0,0]};server.addInternalObject(actor);const scene=new THREE.Group(),poses=visualLocalPoseServices({sceneRoot:scene}),models=[],destroyed=[],diagnostics=[];let time=0,resolve;
 const loaded=name=>{const root=new THREE.Group(),physical=new THREE.Group(),impact=new THREE.Group();root.userData.mdlRoot=name;physical.userData={mdlNode:name,mdlModel:name};impact.userData={mdlNode:'Impact',mdlModel:name};physical.add(impact);root.add(physical);const m={root,resourceName:name,animator:{bindings:new Map(),playNative:()=>1,update:()=>{}}};models.push(m);return m;},pending=deferred?new Promise(r=>resolve=r):null;
 const row={Proj:'1',ProjType:'homing',ProjModel:'authored'},rules={spells:{columns:Object.keys(row),orderedRows:[row],defaultValue:'****'}},p=new ClientProjectilePresentation({objects:()=>server.objects.values(),renderFor:()=>null,playerId:()=>0x80000000,rules:()=>rules,now:()=>({day:0,time}),dayLength:()=>1000000,random:new NativeRandom(1),loadModel:async name=>{if(name==='c_dummy'){if(failDummy)throw new Error('Expected missing c_dummy test resource');if(pending)await pending;}return loaded(name);},destroyModel:m=>{destroyed.push(m);m.root.removeFromParent();},modelFor:r=>poses.modelHandle(r),nodePose:(...args)=>poses.nodePoseInto(...args),orient:()=>{},scene,report:(code,message,data)=>diagnostics.push({code,message,data}),oneShot:()=>{},impactAttachment:{attach:(...args)=>poses.setParent(...args),setNodePose:(...args)=>poses.setNodePose(...args),forget:m=>poses.forgetAttachment(m),updateAttachments:()=>poses.updateAttachments()}});
 const entry={source:actor,header:{sourceId:0x80000000,targetId:0x80000999,from:[0,0,0],to:[4,5,6],duration:500,appearance:6,spellId:0,path:null}};
 return{p,server,actor,entry,scene,models,destroyed,diagnostics,setTime:t=>time=t,resolve:()=>resolve()};
}
test('missing target gets a separate internal c_dummy, real projectile attachment, exact expiry and canonical ID preservation',async()=>{
 const f=fixture(),cursor=[...f.server.nextObjectId];await f.p.receive(f.entry);const dummy=[...f.p.dummies.ai][0],projectile=[...f.p.active][0];
 assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.equal(dummy.id,0);assert.equal(projectile.id,1);assert.equal(projectile.targetId,dummy.id);assert.equal(dummy.appearance,201);assert.equal(dummy.model.resourceName,'c_dummy');assert.equal(dummy.temporary,1);assert.equal(dummy.duration,1000);assert.deepEqual(dummy.position,[4,5,6]);assert.equal(f.scene.children.length,2);assert.equal(f.server.get(0),f.actor);assert.deepEqual(f.server.nextObjectId,cursor);
 f.setTime(500);f.p.update(.5);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.ok(f.p.events.some(e=>e.kind==='impactAttach'&&e.attached));f.setTime(501);f.p.update(.001);assert.equal(projectile.destroyed,true);assert.equal(dummy.destroyed,false);
 f.setTime(999);f.p.update(.498);assert.equal(dummy.destroyed,false);f.setTime(1000);f.p.update(.001);assert.equal(dummy.destroyed,true);assert.equal(f.p.objects.get(dummy.id),undefined);assert.equal(f.scene.children.length,0);assert.equal(new Set(f.destroyed).size,2);assert.deepEqual(f.p.dummies.stats,{created:1,registered:1,destroyed:1,failed:0});assert.deepEqual(f.server.nextObjectId,cursor);f.p.dispose();
});
test('a new canonical object with the missing numeric ID cannot replace an already allocated internal dummy target',async()=>{
 const f=fixture({deferred:true}),pending=f.p.receive(f.entry);f.server.addObjectAtPos(0x999,{objectType:5,position:[30,0,0],orientation:[1,0,0]});f.resolve();await pending;const dummy=[...f.p.dummies.ai][0],projectile=[...f.p.active][0];assert.equal(projectile.targetId,dummy.id);assert.notEqual(f.p.objects.get(0x80000999),dummy);assert.deepEqual(dummy.position,[4,5,6]);f.p.dispose();assert.equal(f.scene.children.length,0);
});
test('late c_dummy load after area disposal cannot register or resurrect a temporary target or projectile',async()=>{
 const f=fixture({deferred:true}),pending=f.p.receive(f.entry);assert.equal(f.p.dummies.owned.size,1);f.p.dispose();f.resolve();await pending;assert.equal(f.p.dummies.owned.size,0);assert.equal(f.p.dummies.ai.size,0);assert.equal(f.p.active.size,0);assert.equal(f.scene.children.length,0);assert.equal(f.models.length,1);assert.deepEqual(f.destroyed,f.models);assert.equal(f.p.objects.array.objects.size,1);assert.equal(f.server.get(0),f.actor);
});
test('failed c_dummy model is diagnosed and unregistered allocation reclaimed while the projectile keeps its requested target ID',async()=>{
 const f=fixture({failDummy:true});await f.p.receive(f.entry);assert.equal(f.p.stats.failed,0);assert.equal(f.p.active.size,1);assert.equal([...f.p.active][0].targetId,f.entry.header.targetId);assert.equal(f.p.dummies.owned.size,0);assert.equal(f.p.dummies.ai.size,0);assert.ok(f.diagnostics.some(d=>d.code==='visual.projectile-dummy-model-failed'));assert.ok(f.diagnostics.some(d=>d.code==='visual.projectile-dummy-unregistered'));f.p.dispose();assert.equal(f.scene.children.length,0);
});
