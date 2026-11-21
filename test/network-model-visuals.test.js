import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {networkModelVisuals} from '../src/network_model_visuals.js';
import {ModelVisualTransforms} from '../src/model_visual_transform.js';
import {ModelAnimator} from '../src/model_animation.js';
import {visualMainModel} from '../src/visual_scene_pose.js';
const leaf=(scale=1,speed=1)=>({channels:[scale,1,1,0,0,0,0,0,0,speed].map(value=>({value}))});
const input=(...entries)=>({entries:entries.map(([key,value])=>({key,value}))});
test('network root/head/held component transforms retain IDs and independent model owners',()=>{
 const root=new THREE.Group(),head=new THREE.Group(),body=new THREE.Group(),anchor=new THREE.Group();body.userData.mdlRoot='body';body.add(anchor);anchor.add(head);root.add(body);
 const heldRoot=new THREE.Group(),pieces=[255,254,253].map(nativeVisualScope=>({root:new THREE.Group(),nativeVisualScope}));pieces.forEach(p=>heldRoot.add(p.root));
 const object={id:7,objectType:5,replicated:{position:[1,2,3],visualTransform:input([0,leaf(.25)],[254,leaf(2)],[245,leaf(3)])},appearance:{equipment:[{id:8,item:{visualTransform:input([0,leaf(.5)])}}]}},binding={wrapper:root,models:[{root:body},{root:head,nativeVisualScope:254},...pieces],held:[{root:heldRoot,pieces,itemId:8,right:1,scale:2}]};
 const state=networkModelVisuals({report:()=>{}},object,binding),before=structuredClone(object);state.sync(object);state.update();
 assert.deepEqual(object,before);assert.equal(state.root.group.scale.x,.25);assert.equal(state.state.lookup(254).group.scale.x,2);
 assert.equal(state.state.lookup(255),state.root);assert.equal(state.state.lookup(245).scale,3);
 // Parent creature scope245 selects the right-hand native item component253.
 // Its own item map is applied after the creature map, as a separate context.
 assert.equal(heldRoot.scale.x,.5);assert.equal(visualMainModel(root).root,body);
 object.replicated.visualTransform=input();state.sync(object);state.update();assert.equal(state.root.scale,1);assert.equal(state.state.lookup(254).scale,1);assert.equal(state.state.lookup(245).scale,1);assert.equal(heldRoot.scale.x,2);
 state.dispose();
});
test('timed curves advance synchronously and animation speed is sampled at playback',()=>{
 let ticks=0n;const providers={clock:()=>ticks,worldTimer:()=>null},group=new THREE.Group(),model={modelName:'fixture',nodes:[],animations:[{name:'move',length:1,tracks:[],events:[]}]},animator=new ModelAnimator(model,new THREE.Group());
 const state=new ModelVisualTransforms({providers}),unit=state.unit(group,[animator]);state.root=unit;state.lookup=scope=>scope===255?unit:null;
 const transform=leaf(.25,2);transform.channels[0]={value:1.25,target:.25,type:0,duration:1,parameter:1,progress:0};state.sync(input([0,transform]));
 assert.equal(group.scale.x,.25);ticks=500000n;state.update();assert.equal(group.scale.x,.75);
 animator.play('move');animator.update(.1);assert.equal(animator.time,.2);
 state.sync(input([0,leaf(1,0)]));animator.update(.1);assert.equal(animator.time,.4);animator.play('move');animator.update(.1);assert.equal(animator.time,0);
 state.sync(input([0,leaf(1,-1)]));animator.play('move');animator.update(.25);assert.equal(animator.time,.75);
 state.sync(input([0,leaf(1,2)]));animator.playNative('move',{speed:.5,flags:3});assert.equal(animator.nativePlayback.runsE0[0].speed8,1);
 state.dispose();assert.equal(animator.nativeVisualSpeedProvider,undefined);
});
