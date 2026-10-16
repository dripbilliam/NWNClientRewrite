import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {visualLocalPoseServices,visualMainModel} from '../src/visual_scene_pose.js';
import {attachType4Visual} from '../src/visual_type4.js';

function node(name,parent,position){return{name,parent,position,orientation:[0,0,0,1],orientationFormat:'quaternion',scale:1};}
test('native Type4 scene attachment reads local head fields, aliases the physical root and retains placement across omitted animation channels',()=>{
 const body={modelName:'body',nodes:[node('authored_body_root','NULL',[0,0,0]),node('torso','authored_body_root',[10,20,30]),node('headconjure','torso',[.1,.2,.3])],animations:[]};
 const host=createModelHierarchy(body).root;host.userData.mdlRoot='body';const render=new THREE.Group();render.add(host);render.rotation.y=.7;render.position.set(3,4,5);
 const model={modelName:'glow',nodes:[node('authored_glow_root','NULL',[7,8,9])],animations:[{name:'duration',length:1,tracks:[]}]};
 const root=createModelHierarchy(model).root;root.userData.mdlRoot='glow';const animator=new ModelAnimator(model,root),effect={target54:123,proceduralB8:{root,animator}},services=visualLocalPoseServices();
 const p={...services,clientObject:()=>({}),renderObject:()=>render,prefixViewA0:()=>null,prefixView28:()=>null,view58:()=>({}),view1406ac1a0:()=>null};
 attachType4Visual(effect,p);assert.equal(root.parent,host.children[0]);
 const physical=root.children[0],expected=[Math.fround(.1),Math.fround(Math.fround(.3)+.5),-Math.fround(Math.fround(.2)+.75)];
 assert.deepEqual(physical.position.toArray(),expected);animator.playNative('duration');animator.update(.1);assert.deepEqual(physical.position.toArray(),expected);
 assert.equal(visualMainModel(render).root,host);assert.equal(visualMainModel(host).root,host);
 // A global/accumulated head transform would include the torso's10/20/30.
 assert.ok(Math.abs(physical.position.x)<1);assert.equal(root.position.length(),0);
});

test('native missing head-node output uses zero/identity plus the authored creature offsets',()=>{
 const model={modelName:'sample',nodes:[node('sample_root','NULL',[0,0,0])],animations:[]},host=createModelHierarchy(model).root;host.userData.mdlRoot='sample';
 const root=createModelHierarchy(model).root;root.userData.mdlRoot='sample';const e={target54:123,proceduralB8:{root}},services=visualLocalPoseServices();
 attachType4Visual(e,{...services,clientObject:()=>({}),renderObject:()=>host,prefixViewA0:()=>null,prefixView28:()=>null,view58:()=>({}),view1406ac1a0:()=>null});
 assert.deepEqual(root.children[0].position.toArray(),[0,.5,-.75]);
 assert.throws(()=>services.setParent(e.proceduralB8,{root:host},'root',3),/orientation behavior/);
});

test('scene attachment copies anchor world position/orientation without inheriting scale; mode3 preserves current orientation each frame',()=>{
 const data={modelName:'sample',nodes:[node('physical_root','NULL',[0,0,0])],animations:[]},sceneRoot=new THREE.Group(),actor=new THREE.Group(),host=createModelHierarchy(data).root;host.userData.mdlRoot='sample';actor.add(host);sceneRoot.add(actor);
 actor.position.set(2,3,4);actor.rotation.y=.6;actor.scale.setScalar(2);
 const physical=host.children[0];physical.position.set(.5,.25,-.5);
 const root=createModelHierarchy(data).root;root.userData.mdlRoot='sample';root.scale.setScalar(1.25);const effect={root},services=visualLocalPoseServices({sceneRoot});
 services.setParent(effect,{root:host},'root',3);
 assert.equal(root.parent,sceneRoot);assert.ok(root.position.distanceTo(physical.getWorldPosition(new THREE.Vector3()))<1e-12);assert.ok(root.quaternion.angleTo(physical.getWorldQuaternion(new THREE.Quaternion()))<1e-7);assert.deepEqual(root.scale.toArray(),[1.25,1.25,1.25]);
 // Match native global root reset while retaining position. Own scale remains
 // separate from the copied Gob position/orientation fields.
 const pose=services.nodePose(effect,'root');services.setNodePose(effect,'root',pose.position,[1,0,0,0]);
 assert.ok(root.children[0].getWorldQuaternion(new THREE.Quaternion()).angleTo(new THREE.Quaternion())<1e-7);
 const retained=root.quaternion.clone();actor.position.x+=3;actor.rotation.y=1.2;services.updateAttachments();
 assert.ok(root.position.distanceTo(physical.getWorldPosition(new THREE.Vector3()))<1e-12);assert.ok(root.quaternion.angleTo(retained)<1e-7);
 root.quaternion.setFromAxisAngle(new THREE.Vector3(0,1,0),-.4);const changed=root.quaternion.clone();services.updateAttachments();assert.ok(root.quaternion.angleTo(changed)<1e-7);
 services.setParent(effect,{root:host},'root',0);actor.rotation.y=-.8;services.updateAttachments();assert.ok(root.quaternion.angleTo(physical.getWorldQuaternion(new THREE.Quaternion()))<1e-7);
 services.forgetAttachment(effect);const before=root.position.clone();actor.position.x+=5;services.updateAttachments();assert.deepEqual(root.position.toArray(),before.toArray());
});

test('global node setters retain missing output defaults and persist omitted local channels under the world adapter',()=>{
 const data={modelName:'sample',nodes:[node('physical_root','NULL',[.2,.3,.4])],animations:[{name:'duration',length:1,tracks:[]}]},sceneRoot=new THREE.Group(),host=createModelHierarchy(data).root;host.userData.mdlRoot='sample';sceneRoot.add(host);host.rotation.y=.4;host.position.set(3,4,5);
 const root=createModelHierarchy(data).root;root.userData.mdlRoot='sample';const model={root,animator:new ModelAnimator(data,root)},services=visualLocalPoseServices({sceneRoot});services.setParent(model,{root:host},'root',0);
 assert.deepEqual(services.nodePose(model,'missing'),{position:[0,0,0],quaternion:[1,0,0,0]});assert.equal(services.setNodePose(model,'missing',[1,2,3],[1,0,0,0]),0);
 services.setNodePose(model,'root',[7,8,9],[1,0,0,0]);const p=root.children[0].getWorldPosition(new THREE.Vector3());assert.ok(p.distanceTo(new THREE.Vector3(7,9,-8))<2e-6);
 const local=root.children[0].position.clone();model.animator.playNative('duration');model.animator.update(.25);assert.deepEqual(root.children[0].position.toArray(),local.toArray());
 sceneRoot.scale.setScalar(2);assert.throws(()=>services.updateAttachments(),/identity world transform/);
});
