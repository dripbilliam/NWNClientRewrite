import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {GameObjectArray,OBJECT_INVALID} from '../src/game_object_array.js';
import {ClientProjectilePresentation} from '../src/client_projectile_presentation.js';
import {visualLocalPoseServices} from '../src/visual_scene_pose.js';
import {NativeRandom} from '../src/native_random.js';
function fixture({missingPart=false}={}){
 const scene=new THREE.Group(),poses=visualLocalPoseServices({sceneRoot:scene}),server=new GameObjectArray(),actor={objectType:5,position:[0,0,0],orientation:[1,0,0]},target={objectType:9,position:[10,2,-8],orientation:[1,0,0]};server.addInternalObject(actor);server.addInternalObject(target);
 const wrapper=new THREE.Group(),body=new THREE.Group(),physical=new THREE.Group(),anchor=new THREE.Group();wrapper.position.set(...target.position);wrapper.userData.nativeLoadedModelName='plc_a01';body.userData.mdlRoot='different_internal_model';physical.userData={mdlNode:'different_internal_root',mdlModel:'different_internal_model'};anchor.userData={mdlNode:missingPart?'other_part':'a01_impact',mdlModel:'different_internal_model'};anchor.position.set(.4,1.2,-.3);physical.add(anchor);body.add(physical);wrapper.add(body);scene.add(wrapper);
 const root=new THREE.Group(),part=new THREE.Group();root.userData.mdlRoot='projectile';part.userData={mdlNode:'authored_root',mdlModel:'projectile'};root.add(part);
 const model={root,resourceName:'authored',animator:{bindings:new Map(),playNative:()=>1,update:()=>{}}},destroyed=[],forgotten=[],diagnostics=[],row={Proj:'1',ProjType:'homing',ProjModel:'authored',ProjOrientation:'path'},rules={spells:{columns:Object.keys(row),orderedRows:[row],defaultValue:'****'}};let time=0;
 const p=new ClientProjectilePresentation({objects:()=>server.objects.values(),renderFor:id=>id===target.id?wrapper:null,rules:()=>rules,now:()=>({day:0,time}),dayLength:()=>1000000,random:new NativeRandom(1),loadModel:async()=>model,destroyModel:m=>{destroyed.push(m);m.root.removeFromParent();},modelFor:r=>poses.modelHandle(r),nodePose:(...args)=>poses.nodePoseInto(...args),orient:()=>{},scene,report:(code,message,data)=>diagnostics.push({code,message,data}),oneShot:()=>{},impactAttachment:{attach:(...args)=>poses.setParent(...args),setNodePose:(...args)=>poses.setNodePose(...args),forget:m=>{forgotten.push(m);poses.forgetAttachment(m);},updateAttachments:()=>poses.updateAttachments()}});
 const entry={source:actor,target,header:{sourceId:(actor.id|0x80000000)>>>0,targetId:(target.id|0x80000000)>>>0,from:[0,0,0],to:[10,8,2],duration:100,appearance:6,spellId:0,path:null}};
 return{p,entry,model,target,wrapper,anchor,server,destroyed,forgotten,diagnostics,setTime:t=>time=t};
}
const world=o=>{o.updateWorldMatrix(true,false);return o.getWorldPosition(new THREE.Vector3());};
test('native body impact attaches to the authored part, follows a moving target and reclaims its attachment/model/client ID',async()=>{
 const f=fixture(),ids=[...f.server.nextObjectId];await f.p.receive(f.entry);const s=[...f.p.active][0];s.impactDuration=200;
 f.setTime(100);f.p.update(.1);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.equal(s.phase,1);assert.equal(s.node,null);assert.ok(f.p.events.some(e=>e.kind==='impactAttach'&&e.part==='a01_impact'&&e.attached));assert.ok(world(f.model.root).distanceTo(world(f.anchor))<1e-5);
 const before=world(f.model.root).clone();f.wrapper.position.x+=5;f.setTime(150);f.p.update(.05);assert.ok(Math.abs(world(f.model.root).x-before.x-5)<1e-5);assert.ok(world(f.model.root).distanceTo(world(f.anchor))<1e-5);
 f.setTime(350);f.p.update(.2);assert.equal(s.destroyed,true);assert.equal(f.model.root.parent,null);assert.deepEqual(f.destroyed,[f.model]);assert.deepEqual(f.forgotten,[f.model]);assert.equal(f.p.objects.get(s.id),undefined);assert.equal(f.server.get(f.target.id),f.target);assert.deepEqual(f.server.nextObjectId,ids);f.p.dispose();
});
test('nonzero native client flag28 clears impact duration and skips model parenting',async()=>{
 const f=fixture();await f.p.receive(f.entry);f.p.objects.get(f.entry.header.targetId).nativeField28=1;const s=[...f.p.active][0];s.impactDuration=200;
 f.setTime(100);f.p.update(.1);assert.equal(f.p.stats.failed,0);assert.equal(s.impactDuration,0);assert.equal(s.remaining,0);assert.equal(f.p.events.some(e=>e.kind==='impactAttach'),false);f.setTime(101);f.p.update(.001);assert.equal(s.destroyed,true);f.p.dispose();
});
test('missing authored impact anchor retains a diagnostic while original pose/duration/cleanup continue',async()=>{
 const f=fixture({missingPart:true});await f.p.receive(f.entry);const s=[...f.p.active][0];f.setTime(100);f.p.update(.1);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.ok(f.diagnostics.some(d=>d.code==='visual.projectile-impact-anchor-unavailable'));assert.equal(s.remaining,1);f.setTime(101);f.p.update(.001);assert.equal(s.destroyed,true);assert.deepEqual(f.destroyed,[f.model]);f.p.dispose();
});
