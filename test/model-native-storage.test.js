import test from 'node:test';
import assert from 'node:assert/strict';
import {parseBinaryMdl} from '../src/binary_mdl.js';
import {parseBinaryAnimations} from '../src/mdl_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {animateModelHierarchy} from '../src/model_animation_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {visualLocalPoseServices} from '../src/visual_scene_pose.js';
import {sampleModelVector} from '../src/model_controller_sample.js';

function fixture(){
 const buffer=new ArrayBuffer(4096),data=new DataView(buffer),bytes=new Uint8Array(buffer),base=12;
 const u32=(at,v)=>data.setUint32(at,v,true),f32=(at,v)=>data.setFloat32(at,v,true),string=(at,v)=>bytes.set(new TextEncoder().encode(v),at);
 u32(4,4084);string(20,'sample');u32(84,232);u32(88,3);f32(base+164,1);string(base+168,'NULL');
 const node=(relative,id,name,children=0,count=0)=>{const at=base+relative;u32(at+28,id);string(at+32,name);u32(at+72,children);u32(at+76,count);u32(at+108,1);};
 node(232,17,'root',600,2);node(344,21,'same');node(456,22,'same');u32(base+600,344);u32(base+604,456);
 u32(base+120,640);u32(base+124,1);u32(base+640,700);const animation=base+700;string(animation+8,'duration');u32(animation+72,920);u32(animation+76,3);f32(animation+112,1);string(animation+120,'root');
 node(920,17,'root',1280,2);node(1032,21,'same');node(1144,22,'same');u32(base+1280,1144);u32(base+1284,1032);
 const animated=base+1032;u32(animated+84,1500);u32(animated+88,3);u32(animated+96,1600);u32(animated+100,12);
 for(const [i,type,rows,time,value,columns]of [[0,8,2,0,2,3],[1,20,1,0,8,4],[2,400,65535,10,12,2]]){const at=base+1500+i*12;u32(at,type);data.setUint16(at+4,rows,true);data.setUint16(at+6,time,true);data.setUint16(at+8,value,true);data.setUint8(at+10,columns);data.setUint8(at+11,0xa5);}
 [0,1,0,0,0,2,4,6,0,0,0,2].forEach((v,i)=>f32(base+1600+i*4,v));
 const physical=base+232;u32(physical+84,1800);u32(physical+88,1);u32(physical+96,1900);u32(physical+100,4);u32(base+1800,8);data.setUint16(base+1804,1,true);data.setUint16(base+1808,1,true);data.setUint8(base+1810,3);[0,3,4,5].forEach((v,i)=>f32(base+1900+i*4,v));
 return buffer;
}

test('binary resources retain runtime IDs, physical child order and original controller/value storage alongside decoded tracks',()=>{
 const model=parseBinaryMdl(fixture()),clip=model.animations[0];
 assert.equal(model.nativeRoot,model.nodes[0].nativeNode);assert.deepEqual(model.nativeRoot.children68.map(n=>n.id34),[21,22]);
 assert.deepEqual(clip.nativeRoot.children68.map(n=>n.id34),[22,21]);
 const node=clip.nativeRoot.children68[1];assert.deepEqual(node.controllers78.map(c=>c.displacement0),[16,28,424]);
 assert.deepEqual(node.controllers78[2],{displacement0:424,rows4:65535,timeIndex6:10,valueIndex8:12,columnsA:2,paddingB:165});
 assert.deepEqual(node.values88,[0,1,0,0,0,2,4,6,0,0,0,2]);
 assert.deepEqual(clip.tracks.find(t=>t.property==='orientation').frames[0].value,[0,0,0,1]);assert.equal(node.values88.at(-1),2);
 const hierarchy=createModelHierarchy(model);assert.deepEqual([...hierarchy.nodeGroups.values()].map(n=>n.userData.mdlNodeId34),[17,21,22]);
 const parts=model.nodes.map(n=>({id30:n.nativeNode.id34,dirty60:0,childCount40:0,children38:[]}));parts[0].children38=parts.slice(1);parts[0].childCount40=2;
 const visited=[];animateModelHierarchy(parts[0],clip.nativeRoot,0,.5,1,{depth:0},{control:node=>visited.push(node.id34),light:()=>null});assert.deepEqual(visited,[17,21,22]);
});

test('native retained value pools cannot extend from model data into unrelated raw resource storage',()=>{
 const body=fixture(),data=new DataView(body);data.setUint32(12+232+96,4090,true);assert.throws(()=>parseBinaryMdl(body),/exceeds file size|exceeds model data/);
 const animation=fixture();new DataView(animation).setUint32(12+1032+96,4090,true);assert.throws(()=>parseBinaryAnimations(animation),/exceeds model data/);
});

test('binary native playback admits loop/blend flags and dispatches duplicate-named physical children by ID',()=>{
 const model=parseBinaryMdl(fixture()),{root,nodeGroups}=createModelHierarchy(model),animator=new ModelAnimator(model,root);
 animator.playNative('duration',{flags:0});animator.update(.25);
 const actual=animator.nativePose.read(animator.nativePose.byObject.get(nodeGroups.get(model.nodes[1])),16,3),node=model.animations[0].nativeRoot.children68[1],expected=[0,0,0];sampleModelVector(node.controllers78[0],animator.time,node,expected,1);
 assert.deepEqual(actual,expected);assert.deepEqual(nodeGroups.get(model.nodes[1]).position.toArray(),[actual[0],actual[2],-actual[1]]);
 assert.deepEqual(nodeGroups.get(model.nodes[2]).position.toArray(),[0,0,-0]);
 assert.equal(animator.nativePlayback.runsE0[0].flagsC,0);animator.update(1);assert.ok(animator.time<1);assert.equal(animator.playing,true);
 // A new one-shot run blends from the current Part fields and preserves the
 // shared native run clock, instead of resetting all omitted channels.
 animator.playNative('duration',{flags:1});animator.update(.125);assert.equal(animator.nativePlayback.runsE0[0].flagsC,1);
 assert.throws(()=>animator.playNative('duration',{flags:256}),/motion-controller/);
});

test('manual local pose gate survives lazy native initialization and suppresses that part while children keep animating',()=>{
 const model=parseBinaryMdl(fixture()),clip=model.animations[0],channelNode=clip.nativeRoot.children68[1];
 clip.nativeRoot.controllers78=[channelNode.controllers78[0]];clip.nativeRoot.controllerCount80=1;clip.nativeRoot.values88=channelNode.values88;
 const {root,nodeGroups}=createModelHierarchy(model);root.userData.mdlRoot=model.modelName;const animator=new ModelAnimator(model,root),sceneModel={root,animator},poses=visualLocalPoseServices();
 poses.setLocalNodePose(sceneModel,'root',[7,8,9],[1,0,0,0]);animator.playNative('duration',{flags:0});animator.update(.25);
 assert.deepEqual(nodeGroups.get(model.nodes[0]).position.toArray(),[7,9,-8]);assert.equal(animator.nativePose.partRoot.dirty60,1);
 assert.ok(nodeGroups.get(model.nodes[1]).position.length()>0);
 poses.setLocalNodePose(sceneModel,'root',[1,2,3],[1,0,0,0]);animator.update(.25);assert.deepEqual(nodeGroups.get(model.nodes[0]).position.toArray(),[1,3,-2]);
});

test('native current/stop/restart commands retain Part channel state and run identity without resetting to resource defaults',()=>{
 const model=parseBinaryMdl(fixture());model.animations.push({...model.animations[0],name:'restart',transition:1});const {root,nodeGroups}=createModelHierarchy(model),animator=new ModelAnimator(model,root);
 animator.playNative('duration',{flags:0});animator.update(.25);const pose=animator.nativePose,run=animator.nativePlayback.runsE0[0],part=pose.byObject.get(nodeGroups.get(model.nodes[1])),position=pose.read(part,16,3);
 assert.equal(animator.playNative('current',{flags:3}),true);assert.equal(animator.nativePlayback.runsE0[0],run);assert.equal(animator.nativePose,pose);
 assert.equal(animator.playNative(null,{flags:0}),true);assert.equal(animator.nativePlayback.runsE0.length,0);assert.equal(animator.nativePose,pose);
 animator.playNative('restart',{flags:0});animator.update(0);
 assert.deepEqual(pose.read(part,16,3),position);assert.equal(animator.playNative('absent',{flags:0}),false);assert.equal(animator.nativePose,pose);
});
