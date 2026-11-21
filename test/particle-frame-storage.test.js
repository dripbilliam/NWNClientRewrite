import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {createModelEmitter,ModelParticlePresentation} from '../src/model_particles.js';
import {buildParticleVertexBatch} from '../src/particle_vertex_batch.js';

function fixture(reuseFrameState,render='Normal',update='Fountain'){
 const root=new THREE.Group(),camera=new THREE.PerspectiveCamera(),texture=new THREE.Texture(),template=new THREE.Group();template.userData.mdlRoot='storage-fixture';
 const node=new THREE.Group();template.add(node);node.add(createModelEmitter({name:'storage-emitter',properties:{texture:'fixture',update,render,blend:'Normal',birthrate:17,lifeexp:.7,sizestart:.3,sizeend:.8,colorstart:[.8,.3,.2],colorend:[.1,.2,.8],alphastart:.7,alphaend:.1,xgrid:2,ygrid:2,velocity:.8,randvel:.3,mass:.1,spread:.4,fps:4,framestart:0,frameend:3}},new Map([['fixture',texture]]),'storage-fixture'));
 root.add(template.clone(true),template.clone(true));const records=[],presentation=new ModelParticlePresentation({camera,reuseFrameState,seed:123,report:(...row)=>records.push(row)});
 return{root,camera,template,presentation,records};
}
function state(f){return{random:{...f.presentation.random},entries:[...f.presentation.entries.values()].map(e=>({failed:e.failed,frames:e.frames,drawCount:e.drawCount,cpu:e.e?structuredClone(e.e):null,visible:e.mesh.visible,range:{...e.mesh.geometry.drawRange},attributes:Object.fromEntries(Object.entries(e.mesh.geometry.attributes).map(([k,v])=>[k,{array:v.array.slice(),version:v.version,ranges:structuredClone(v.updateRanges)}]))})),records:f.records};}
for(const render of ['Normal','Billboard_to_Local_Z','Billboard_to_World_Z','Linked','Aligned_to_World_Z','Aligned_to_Particle_Dir','Motion_Blur'])test('storage reuse retains simulation/RNG/vertex bytes across live edits: '+render,()=>{
 const a=fixture(false,render),b=fixture(true,render);
 try{for(let frame=0;frame<90;frame++){
  for(const f of [a,b]){
   f.camera.rotation.set(frame*.01,frame*.03,-frame*.02);
   for(const [i,model]of f.root.children.entries()){model.position.set(i*3+frame*.02,Math.sin(frame*.1),-i);model.rotation.y=frame*.02;model.scale.setScalar(frame<30?1:1.3);const p=model.children[0].userData.mdlEmitterProperties??=structuredClone(model.children[0].children[0].userData.mdlEmitter.properties);p.birthrate=frame>55?0:17+i;p.colorstart[0]=frame*.001;p.lifeexp=frame<40?.7:1.1;}
   if(frame===10)f.root.add(f.template.clone(true));if(frame===20){const first=f.root.children[0];f.root.remove(first);f.root.add(first);}if(frame===35)f.root.children[1].removeFromParent();if(frame===45)f.root.children[0].visible=false;if(frame===60)f.presentation.reuseFrameState=!f.presentation.reuseFrameState;if(frame===70)f.presentation.reuseFrameState=!f.presentation.reuseFrameState;
   f.presentation.update(f.root,[.01,.016,.033,.05][frame%4]);
  }
  assert.deepEqual(state(b),state(a),'frame '+frame);
 }}finally{a.presentation.dispose();b.presentation.dispose();}
});
test('storage reuse follows failed-entry retirement and a replaced scene root',()=>{
 const a=fixture(false),b=fixture(true);
 try{for(const f of [a,b]){const bad=f.template.clone(true);bad.children[0].children[0].userData.mdlEmitter.properties.chunkname='unsupported';f.root.add(bad);f.presentation.update(f.root,.1);bad.removeFromParent();f.presentation.update(f.root,.1);const next=new THREE.Group();next.add(f.template.clone(true));f.root=next;f.presentation.update(next,.1);}assert.deepEqual(state(b),state(a));assert.equal(b.presentation.entries.size,1);}finally{a.presentation.dispose();b.presentation.dispose();}
});
for(const update of ['Explosion','Single','Lightning'])test('storage reuse retains burst/detonation/empty-target state: '+update,()=>{
 const a=fixture(false,update==='Lightning'?'Linked':'Normal',update),b=fixture(true,update==='Lightning'?'Linked':'Normal',update);
 try{for(let frame=0;frame<35;frame++){
  for(const f of [a,b]){if(frame%11===0)for(const root of f.root.children)root.children[0].children[0].userData.mdlPendingDetonate=true;f.presentation.update(f.root,.033);}
  assert.deepEqual(state(b),state(a),'frame '+frame);
 }}finally{a.presentation.dispose();b.presentation.dispose();}
});
test('storage reuse retains dense asynchronous vertex snapshots and in-flight retirement',async()=>{
 const a=fixture(false),b=fixture(true);
 try{for(const f of [a,b]){f.presentation.minWorkerParticles=0;f.presentation.vertexPool=()=>pool;}
  const pool={size:2,closed:false,run:async(_kind,payload)=>buildParticleVertexBatch(payload)};
  for(let frame=0;frame<30;frame++){
   for(const f of [a,b]){f.presentation.update(f.root,.033);if(frame===15){f.root.children[0].removeFromParent();f.presentation.update(f.root,.01);}}
   await Promise.all([a.presentation.vertexPreparation?.work,b.presentation.vertexPreparation?.work]);assert.deepEqual(state(b),state(a),'worker frame '+frame);
  }
 }finally{a.presentation.dispose();b.presentation.dispose();}
});

for(const render of ['Normal','Billboard_to_Local_Z','Billboard_to_World_Z','Linked','Aligned_to_World_Z','Aligned_to_Particle_Dir','Motion_Blur'])test('unchanged pose samples retain full state and vertex bytes: '+render,()=>{const a=fixture(true,render),b=fixture(true,render);b.presentation.reusePoseSamples=true;let reused=0;try{for(let frame=0;frame<90;frame++){for(const f of [a,b]){if(frame%7===0){for(const [i,model]of f.root.children.entries()){model.position.set(i+frame*.02,Math.sin(frame*.1),-.2*i);model.rotation.y=frame*.02;model.scale.setScalar(frame<35?1:-1.2);}f.camera.rotation.y=frame*.02;}if(frame===10)f.root.add(f.template.clone(true));if(frame===20)f.root.children[0].removeFromParent();if(frame===45)f.presentation.reusePoseSamples=false;if(frame===55&&f===b)f.presentation.reusePoseSamples=true;f.presentation.update(f.root,.033);}reused+=b.presentation.poseSnapshot().reused;assert.deepEqual(state(b),state(a),'frame '+frame);}assert.ok(reused>100);}finally{a.presentation.dispose();b.presentation.dispose();}});
test('persistent pose values are isolated from callers and unknown decomposition stays live',()=>{const f=fixture(true),object=new THREE.Object3D();f.presentation.reusePoseSamples=true;try{const first=f.presentation.worldPose(object);first.value.position[0]=999;first.value.quaternion[0]=999;f.presentation.poseCache=new WeakMap();const next=f.presentation.worldPose(object);assert.equal(next.value.position[0],0);assert.notEqual(next.value.quaternion[0],999);assert.ok(f.presentation.poseSnapshot().reused>0);let calls=0;const decompose=object.matrixWorld.decompose;object.matrixWorld.decompose=function(...args){calls++;return decompose.apply(this,args);};for(let i=0;i<2;i++){f.presentation.poseCache=new WeakMap();f.presentation.worldPose(object);}assert.equal(calls,2);}finally{f.presentation.dispose();}});

for(const render of ['Normal','Billboard_to_Local_Z','Billboard_to_World_Z','Linked','Aligned_to_World_Z','Aligned_to_Particle_Dir','Motion_Blur'])test('shared pose ancestry retains full simulation and vertex state: '+render,()=>{const a=fixture(true,render),b=fixture(true,render);b.presentation.reusePoseAncestors=true;let reused=0;try{for(let frame=0;frame<80;frame++){for(const f of [a,b]){f.root.position.x=frame*.03;f.root.rotation.y=frame*.02;f.camera.rotation.x=frame*.01;for(const [i,root]of f.root.children.entries()){root.scale.set(1,frame<30?1:-1.2,.8);root.position.z=i*.7+frame*.01;}if(frame===10)f.root.add(f.template.clone(true));if(frame===20){const first=f.root.children[0];f.root.remove(first);f.root.add(first);}if(frame===35)f.root.children[1].removeFromParent();if(frame===50)f.presentation.reusePoseAncestors=false;if(frame===60&&f===b)f.presentation.reusePoseAncestors=true;f.presentation.update(f.root,.033);}reused+=b.presentation.poseSnapshot().ancestors.reused;assert.deepEqual(state(b),state(a),'frame '+frame);}assert.ok(reused>30);}finally{a.presentation.dispose();b.presentation.dispose();}});
test('unknown ancestry writers preserve invocation order and terminate scoped reuse',()=>{const a=fixture(true),b=fixture(true);b.presentation.reusePoseAncestors=true;const calls=[[],[]];try{for(const [index,f]of [a,b].entries()){const before=f.root.updateMatrix;f.root.updateMatrix=function(){calls[index].push('root');return before.call(this);};f.presentation.update(f.root,.033);}assert.deepEqual(calls[1],calls[0]);assert.deepEqual(state(b),state(a));assert.equal(b.presentation.poseSnapshot().ancestors.fallback,true);}finally{a.presentation.dispose();b.presentation.dispose();}});
