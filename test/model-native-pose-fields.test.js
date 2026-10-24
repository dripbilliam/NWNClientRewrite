import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {createModelLight} from '../src/model_light.js';

function native(id34,flags98,channels=[]){
 const values88=[0,1],controllers78=channels.map(([displacement0,a,b])=>{const valueIndex8=values88.length;values88.push(...a,...b);return{displacement0,valueIndex8,columnsA:a.length,rows4:2,timeIndex6:0};});
 return{id34,flags98,values88,controllers78,controllerCount80:controllers78.length,children68:[],childCount70:0};
}
function fixture(){
 const nodes=[native(1,1),native(2,5,[[116,[4],[8]],[136,[.2,.4,.8],[.8,.4,.2]],[548,[1],[1]]]),native(3,3,[[104,[.1,.2,.3],[.4,.5,.6]],[116,[3],[6]]]),native(4,33,[[168,[0],[1]],[128,[.1,.2,.3],[.7,.6,.5]]])];
 nodes[0].children68=nodes.slice(1);nodes[0].childCount70=3;
 const source=nodes.map((nativeNode,i)=>({name:['root','emitter','light','mesh'][i],type:['dummy','emitter','light','trimesh'][i],parentIndex:i?0:-1,parent:i?'root':'NULL',position:[0,0,0],orientation:[0,0,0,1],nativeNode,properties:i===2?{color:[.1,.2,.3],radius:3,isdynamic:1}:{}}));
 const omitted=native(1,1);omitted.children68=[nodes[1]];omitted.childCount70=1;
 const model={modelName:'fields',nodes:source,nativeRoot:nodes[0],animations:[{name:'duration',length:1,transition:.5,tracks:[],nativeRoot:nodes[0]},{name:'omitted',length:1,transition:0,tracks:[],nativeRoot:omitted}]};
 const instantiate=()=>{const {root,nodeGroups}=createModelHierarchy(model),light=createModelLight(source[2]),mesh=new THREE.Mesh(new THREE.BoxGeometry(),new THREE.MeshLambertMaterial());mesh.material.userData.mdlOpacityDriven=true;nodeGroups.get(source[2]).add(light);nodeGroups.get(source[3]).add(mesh);const animator=new ModelAnimator(model,root);return{root,nodeGroups,light,material:mesh.material,animator};};
 return{model,source,instantiate};
}

test('native blended Part fields reach emitter parameters, raw light channels and mesh opacity without cross-instance or omitted-channel resets',()=>{
 const f=fixture(),a=f.instantiate(),b=f.instantiate();a.animator.playNative('duration',{flags:0});a.animator.update(.25);
 const pose=a.animator.nativePose,emitter=a.nodeGroups.get(f.source[1]),emitterPart=pose.byObject.get(emitter),lightPart=pose.byObject.get(a.nodeGroups.get(f.source[2]));
 assert.equal(emitter.userData.mdlEmitterProperties.birthrate,pose.read(emitterPart,116,1)[0]);assert.ok(emitter.userData.mdlEmitterProperties.birthrate>4&&emitter.userData.mdlEmitterProperties.birthrate<8);
 assert.deepEqual(a.light.userData.mdlLight.color,pose.read(lightPart,104,3));assert.equal(a.light.userData.mdlLight.radius,pose.read(lightPart,116,1)[0]);
 assert.equal(a.material.opacity,pose.read(pose.byObject.get(a.nodeGroups.get(f.source[3])),168,1)[0]);assert.equal(a.material.transparent,true);assert.equal(a.material.depthWrite,false);
 assert.deepEqual(a.material.emissive,new THREE.Color().setRGB(...pose.read(pose.byObject.get(a.nodeGroups.get(f.source[3])),128,3),THREE.SRGBColorSpace));
 // Float controller writes at224 overlap the three native BYTE percentage
 // fields. Mirror those bytes instead of inventing three float properties.
 assert.deepEqual(['percentstart','percentmid','percentend'].map(k=>emitter.userData.mdlEmitterProperties[k]),[0,0,128]);
 assert.equal(b.material.opacity,1);assert.deepEqual(b.light.userData.mdlLight.color,[.1,.2,.3]);assert.deepEqual(f.source[1].properties,{});
 const opacity=a.material.opacity,color=[...a.light.userData.mdlLight.color],emissive=a.material.emissive.clone();a.animator.playNative('omitted',{flags:0});a.animator.update(.1);
 assert.equal(a.material.opacity,opacity);assert.deepEqual(a.light.userData.mdlLight.color,color);assert.deepEqual(a.material.emissive,emissive);assert.equal(b.material.emissive.getHex(),0);
 for(const item of [a,b]){item.material.dispose();item.root.traverse(o=>o.geometry?.dispose());}
});
