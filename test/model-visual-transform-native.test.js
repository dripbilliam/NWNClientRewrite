import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import * as THREE from 'three';
import {assignModelVisualTransforms,adjustedVisualPose,ModelVisualTransforms,networkVisualTransformBytes} from '../src/model_visual_transform.js';
const load=name=>JSON.parse(fs.readFileSync(new URL('../backups/animations/'+name,import.meta.url)));
const scopes=load('native-client-visual-transforms-v1.json'),poses=load('native-gob-adjusted-pose-v1.json');
test('model scope assignment/reset matches all original tree, alias and BYTE lookup cases',()=>{
 assert.equal(scopes.scopes.length,87);
 for(const row of scopes.scopes){const trace=[],units=new Map(row.available.map(k=>[k,{key:k}])),current=assignModelVisualTransforms({entries:row.keys.map(key=>({key,value:{id:key+1000}}))},row.previous,{root:units.get(255),lookup:key=>{trace.push(['lookup',key]);return units.get(key);},assign:(unit,leaf)=>trace.push(['assign',unit.key,leaf.identity?'identity':leaf.id])});assert.deepEqual(trace,row.trace);assert.deepEqual(current,row.scopes);}
});
test('adjusted model pose matches 120 original quaternion/translation/uniform-scale cases',()=>{
 assert.equal(poses.cases.length,120);
 for(const row of poses.cases){const pose=adjustedVisualPose(row.position,row.quaternion,{rotation:row.rotation,translation:row.translation,scale:row.scale},row.baseScale);
  for(const[key,expected]of [['position',row.adjustedPosition],['quaternion',row.adjustedQuaternion]])pose[key].forEach((v,i)=>assert.ok(Math.abs(v-expected[i])<3e-6,JSON.stringify({row,key,pose})));assert.equal(pose.scale,row.adjustedScale);
 }
});
const clock=()=>({clock:()=>0n,worldTimer:()=>null});
const leaf=(scale=1)=>({channels:[scale,1,1,0,0,0,0,0,0,1].map(value=>({value}))});
test('render units own independent state, clear transforms and preserve canonical parent pose',()=>{
 const parent=new THREE.Group(),group=new THREE.Group();parent.position.set(7,8,9);parent.add(group);
 const state=new ModelVisualTransforms({providers:clock()}),unit=state.unit(group);state.root=unit;state.lookup=scope=>scope===255?unit:null;
 state.sync({entries:[{key:0,value:leaf(.25)}]});assert.equal(group.scale.x,.25);assert.deepEqual(parent.position.toArray(),[7,8,9]);
 state.sync({entries:[]});assert.equal(group.scale.x,1);
 const bytes=networkVisualTransformBytes(leaf(.5),clock());bytes[0]=23;assert.equal(unit.bytes[0],0);
 state.dispose();
});
