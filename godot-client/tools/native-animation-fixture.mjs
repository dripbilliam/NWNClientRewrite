// Only authored geometry, texture and numeric controller records are written.
import fs from 'node:fs/promises';
import * as T from 'three';
import {createModelHierarchy} from '../../src/model_hierarchy.js';
import {ModelAnimator} from '../../src/model_animation.js';
import {prepareVisualModelTransfer} from './export-visual-model.mjs';
import {prepareGodotRoom} from './export-room.mjs';

const controller=(displacement0,columnsA,frames)=>({displacement0,columnsA,frames});
function rawNode(id34,flags98,channels=[],children68=[]){
 const values88=[],controllers78=[];
 for(const channel of channels){
  const timeIndex6=values88.length;values88.push(...channel.frames.map(frame=>frame[0]));
  const valueIndex8=values88.length;values88.push(...channel.frames.flatMap(frame=>frame.slice(1)));
  controllers78.push({displacement0:channel.displacement0,columnsA:channel.columnsA,rows4:channel.frames.length,timeIndex6,valueIndex8});
 }
 return{id34,flags98,values88:Float32Array.from(values88),controllers78,controllerCount80:controllers78.length,children68,childCount70:children68.length};
}
const defaults=(position=[0,0,0],scale=1)=>[controller(16,3,[[0,...position]]),controller(28,4,[[0,0,0,0,1]]),controller(44,1,[[0,scale]])];
function fixture(){
 const meshNode=rawNode(2,33,[...defaults(),controller(128,3,[[0,0,0,0]]),controller(168,1,[[0,1]])]);
 const emitterNode=rawNode(1,5,[...defaults([1,0,0]),controller(116,1,[[0,12]]),controller(220,1,[[0,1]]),controller(136,3,[[0,1,.5,.25]])]);
 const nativeRoot=rawNode(0,1,defaults(),[emitterNode,meshNode]);
 const animations=['impact','duration','cessation'].map((name,index)=>({name,length:1,transition:.2,tracks:[],events:[{time:0,name:'zero'},{time:.25,name:'Detonate'},{time:1,name:'end'}],nativeRoot:
  rawNode(0,1,[controller(16,3,[[0,index,0,0],[1,index+1,.5,0]])],[
   rawNode(1,5,[controller(16,3,[[0,1,0,0],[1,1,1+index,0]]),controller(116,1,[[0,10+index],[1,20+index]]),controller(220,1,[[0,index+1],[1,index+2]]),controller(136,3,[[0,1,0,0],[1,0,1,index*.25]])]),
   rawNode(2,33,[controller(28,4,[[0,0,0,0,1],[1,0,0,Math.SQRT1_2,Math.SQRT1_2]]),controller(168,1,[[0,1],[1,.2+index*.1]]),controller(128,3,[[0,0,0,0],[1,.3,.2,.1]])])
  ])}));
 const properties={update:'Explosion',velocity:1,birthrate:12,colorstart:[1,.5,.25]};
 const model={modelName:'authored_native',nativeRoot,animations,nodes:[
  {name:'root',parent:'NULL',parentIndex:-1,type:'dummy',position:[0,0,0],orientation:[0,0,0,1],scale:1,nativeNode:nativeRoot},
  {name:'emitter',parent:'root',parentIndex:0,type:'emitter',position:[1,0,0],orientation:[0,0,0,1],scale:1,properties,nativeNode:emitterNode},
  {name:'box',parent:'root',parentIndex:0,type:'trimesh',position:[0,0,0],orientation:[0,0,0,1],scale:1,nativeNode:meshNode}
 ]};
 const {root,nodeGroups}=createModelHierarchy(model),scene=new T.Scene(),camera=new T.PerspectiveCamera();scene.add(root);root.userData.mdlRoot=model.modelName;
 const mesh=new T.Mesh(new T.BoxGeometry(1,1,1),new T.MeshLambertMaterial({color:0x88aaff}));nodeGroups.get(model.nodes[2]).add(mesh);
 const animator=new ModelAnimator(model,root),instance={root,model,animator};
 return{scene,camera,model:instance,animator,close:()=>{scene.clear();mesh.geometry.dispose();mesh.material.dispose();}};
}
const operations=[{play:['impact',1,1,0]},...Array.from({length:4},()=>({delta:.05})),{play:['duration',1,8,0]},...Array.from({length:4},()=>({delta:.08})),{play:['cessation',1,33,0]},...Array.from({length:12},()=>({delta:.09})),{play:['duration',-1,8,0]},...Array.from({length:4},()=>({delta:.07})),{play:['duration',.5,72,.4]},...Array.from({length:4},()=>({delta:.12})),{play:['current',1,128,0]},{delta:.1},{play:[null,1,0,0]},{delta:.1}];
function encode(value){
 if(typeof value==='number'){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);return{$f64:bytes.toString('hex')};}
 if(Array.isArray(value))return value.map(encode);
 if(value&&typeof value==='object')return Object.fromEntries(Object.entries(value).map(([key,row])=>[key,encode(row)]));
 return value;
}
export function nativeAnimationOracle(){
 const f=fixture(),transfer=prepareVisualModelTransfer(f),prepared=prepareGodotRoom({...f,inventory:[],entities:[],includeCamera:false,rigTransfer:transfer.rigs,particleTransfer:transfer.particles});
 prepared.manifest.kind='visual-model';prepared.manifest.modelResources=['authored_native'];
 const meshes=prepared.scene.children.filter(c=>c.isMesh).map(c=>({name:c.name,position:Array.from(c.geometry.attributes.position.array),normal:Array.from(c.geometry.attributes.normal.array),uv:Array.from(c.geometry.attributes.uv?.array??[]),index:c.geometry.index?Array.from(c.geometry.index.array):null,matrix:c.matrix.toArray()}));
 const events=[];f.animator.eventDispatcher.add('*',(_owner,name)=>events.push(name));const frames=[];
 for(const operation of operations){
  let result=null;if(operation.play){const [name,speed,flags,time]=operation.play;result=f.animator.playNative(name,{speed,flags,time});}else f.animator.update(operation.delta);
  const pose=f.animator.nativePose;
  frames.push({operation,result,events:events.slice(),parts:pose?.parts.map(part=>({position:pose.read(part,16,3),quaternion:pose.read(part,28,4),scale:pose.read(part,44,1),...(part.source.type==='trimesh'?{alpha:pose.read(part,168,1),selfillum:pose.read(part,128,3)}:{}),...(part.source.type==='emitter'?{birthrate:pose.read(part,116,1),velocity:pose.read(part,220,1),colorstart:pose.read(part,136,3)}:{})}))??[],runs:f.animator.nativePlayback.runsE0.map(run=>({name:run.clip0.name,time:run.time14,weight:run.weight18,flags:run.flagsC,done:run.done24})),local:f.model.model.nodes.map(node=>{const part=f.animator.nativePose.parts.find(part=>part.source===node);return{position:part.object.position.toArray(),quaternion:part.object.quaternion.toArray(),scale:part.object.scale.toArray()};})});
 }
 const result={metadata:prepared.manifest,meshes,frames:encode(frames),scope:'Authored native run/controller/geometry oracle from existing original-derived JS owners; no installed assets'};prepared.dispose();f.close();return result;
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/native-animation-fixture.mjs')){
 const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);if(!output)throw Error('Provide an unused --output');await fs.writeFile(output,JSON.stringify(nativeAnimationOracle())+'\n',{flag:'wx'});console.log(JSON.stringify({output,frames:operations.length}));
}
