// Installed resources stay in memory. This composes real visual rules/models,
// native phases/run clocks/controllers/events and CPU particle vertices. It is
// NOT GPU, native scene-handle lifetime, NCS delivery or campaign acceptance.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import * as THREE from 'three';
import {TGALoader} from 'three/addons/loaders/TGALoader.js';
import {openLocalModule} from './local-module.mjs';
import {parse2da} from '../src/area.js';
import {parseModel} from '../src/model_parser.js';
import {inheritAnimations} from '../src/mdl_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {createModelLight} from '../src/model_light.js';
import {createModelEmitter,ModelParticlePresentation} from '../src/model_particles.js';
import {createVisualSceneRuntime} from '../src/visual_scene_runtime.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {LoopingVisualPresentation} from '../src/looping_visual_presentation.js';

const resolver=await openLocalModule('../FullDecomp/NwnRootInstall','../FullDecomp/NwnRootInstall/data/nwm/Prelude.nwm'),decode=new TextDecoder(),tables={};
for(const [key,name]of [['visuals','visualeffects'],['programs','progfx'],['appearance','appearance']])tables[key]=parse2da(decode.decode(await resolver.getResource(name,2017)));
const record={visualId:206,sourceId:123,bodyPart:0,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}},diagnostics=[],report=(code,message,data)=>diagnostics.push({code,message,data}),sceneRoot=new THREE.Group(),actor={id:123,areaId:1,objectType:5,position:[0,0,0],creatureData:{Appearance_Type:0},nativeLoopingVisuals160:{records:[record]}},target=new THREE.Group();
const host=createModelHierarchy({modelName:'probe_actor',nodes:[['root','NULL',[0,0,0]],['head','root',[0,0,1.5]],['impact','root',[0,0,1]],['headconjure','root',[0,0,1.5]]].map(([name,parent,position])=>({name,parent,position,orientation:[0,0,0,1]}))}).root;host.userData.mdlRoot='probe_actor';target.add(host);sceneRoot.add(target);
const models=[],camera=new THREE.PerspectiveCamera();camera.position.set(3,4,5);const particles=new ModelParticlePresentation({camera,report});
let instance,presentation;const frames=[];
try{
 const createNative=async()=>instance=await createVisualSceneRuntime({actor,record,tables,objects:new Map([[123,actor]]),renderFor:()=>target,player:()=>actor,sceneRoot,report,
  loadAsset:async name=>{
   const model=parseModel(await resolver.getResource(name,2002));await inheritAnimations(model,async resRef=>parseModel(await resolver.getResource(resRef,2002)));const textures=new Map();
   try{for(const bitmap of model.materialNames){const image=new TGALoader().parse(await resolver.getResource(bitmap,3)),texture=new THREE.DataTexture(image.data,image.width,image.height);texture.flipY=image.flipY;textures.set(bitmap.toLowerCase(),texture);}return{model,textures};}
   catch(error){textures.forEach(t=>t.dispose());throw error;}
  },
  createModel:(asset,resourceName)=>{
   const hierarchy=createModelHierarchy(asset.model),root=hierarchy.root;root.userData.mdlRoot=asset.model.modelName;
   for(const node of asset.model.nodes){const parent=hierarchy.nodeGroups.get(node);if(node.type==='light')parent.add(createModelLight(node));else if(node.type==='emitter')parent.add(createModelEmitter(node,asset.textures,asset.model.modelName));}
   const model={root,model:asset.model,resourceName,animator:new ModelAnimator(asset.model,root)};models.push(model);return model;
  },destroyModel:model=>{model.root.removeFromParent();model.root.traverse(o=>{o.geometry?.dispose();o.material?.dispose();});},releaseAsset:asset=>asset.textures.forEach(texture=>texture.dispose()),shadowing:()=>{}});
 presentation=new LoopingVisualPresentation({areaId:1,objects:()=>[actor],object:()=>actor,render:()=>target,tables:async()=>tables,createNative,report});
 presentation.update(0);await Promise.all([...presentation.entries.values()].map(entry=>entry.ready));assert.deepEqual(instance.snapshot().models,['vce_positive']);
 for(let i=0;i<10;i++){presentation.update(.05);particles.update(sceneRoot,.05);}
 assert.equal(models[0].animator.playing,false);assert.equal(particles.snapshot().reduce((sum,p)=>sum+p.active,0),0);
 actor.nativeLoopingVisuals160.records.pop();presentation.update(0);assert.ok(models[0].animator.nativePose);assert.equal(models[0].animator.nativePlayback.runsE0[0].flagsC,1);
 assert.equal(presentation.retiring.size,1);assert.equal(instance.nativeState.attached114,1);
 let maxVertices=0,explosion=false;
 for(let i=0;i<160&&presentation.retiring.size;i++){
  presentation.update(.05);particles.update(sceneRoot,.05);const snapshot=particles.snapshot();maxVertices=Math.max(maxVertices,snapshot.reduce((sum,p)=>sum+p.vertices,0));
  explosion ||= [...particles.entries.values()].some(entry=>entry.e?.active188.records.length>0&&entry.mesh.userData.mdlEmitter.properties.update==='Explosion');
  if(i%5===0||instance.isRetired())frames.push({step:i,visual:instance.snapshot(),particles:snapshot});
 }
 await fs.writeFile('backups/animations/live-native-visual-model-phases.json',JSON.stringify({visualId:206,model:models[0].resourceName,flags:1,maxVertices,explosion,retired:instance.isRetired(),frames,diagnostics,modelDiagnostics:runtimeDiagnostics.records,limits:'Actual installed visual206/vce_positive rules/model/textures remain in memory. Synthetic actor/body and canonical record removal. Actual LoopingVisualPresentation native stop1/update/selection/reattachment/retirement with checked run/controller/event/particle CPU composition. Particles update only through the live world scene root. No GPU, native scene-handle lifetime, NCS delivery or campaign acceptance.'},null,2));
 assert.deepEqual(runtimeDiagnostics.records.filter(v=>v.code==='animation.event-handler-unavailable'),[]);
 assert.deepEqual(diagnostics.filter(v=>v.code==='particle.runtime-unavailable'),[]);
 assert.ok(maxVertices>0);assert.ok(explosion,'Authored Detonate must activate the Explosion emitter');assert.ok(instance.isRetired());assert.equal(presentation.retiring.size,0);assert.equal(particles.snapshot().length,0);assert.deepEqual([actor.id,record.sourceId],[123,123]);
 console.log('REAL VISUAL GEOMETRY CESSATION, NATIVE CONTROLLERS, DETONATE, CPU VERTICES AND RETIREMENT PASS',maxVertices);
}finally{particles.dispose();presentation?.dispose();instance?.dispose();}
