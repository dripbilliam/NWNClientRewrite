import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {openLocalModule} from './local-module.mjs';
import {parseModel} from '../src/model_parser.js';
import {inheritAnimations} from '../src/mdl_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {loadModelReferenceAssets,releaseModelReferenceAssets} from '../src/model_reference_assets.js';
import {ModelReferenceScene} from '../src/model_reference_scene.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-model-reference-ownership-v1.json',reattach=process.argv.includes('--reattach'),inventory=JSON.parse(await fs.readFile('backups/animations/installed-model-reference-inventory-v1.json','utf8')),report={models:[],limits:'Unchanged active MDLs, inherited clips, real ModelAnimator and Three hierarchy/attachment. Headless pose/ownership checks; no mesh pixels, native entire graph/cache/scene-loop or campaign parity claim.'};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`);
 for(const entry of inventory.models){
  const sceneRoot=new THREE.Group(),instances=[],destroyed=[],released=[];
  const asset=await loadModelReferenceAssets(entry.name,{load:async name=>{const model=parseModel(await resolver.getResource(name,2002));await inheritAnimations(model,async n=>parseModel(await resolver.getResource(n,2002)));return{model};},release:asset=>released.push(asset.model.modelName)});
  const destroy=model=>{model.references?.dispose();model.root.removeFromParent();destroyed.push(model);};
  const create=(asset,name)=>{const {root}=createModelHierarchy(asset.model);root.userData.mdlRoot=asset.model.modelName;const model={root,model:asset.model,resourceName:name,animator:new ModelAnimator(asset.model,root)};instances.push(model);if(asset.model.nodes.some(n=>n.type==='reference'))model.references=new ModelReferenceScene({owner:model,asset,sceneRoot,createModel:create,destroyModel:destroy});return model;};
  const owner=create(asset,entry.name);sceneRoot.add(owner.root);owner.root.position.set(2,3,-4);owner.root.rotation.y=.7;owner.root.scale.setScalar(2);
  const clip=owner.model.animations.find(a=>a.name==='conjure01')??owner.model.animations.find(a=>a.name==='cast01')??owner.model.animations[0];if(clip)assert.equal(owner.animator.playNative(clip.name,{speed:1,flags:0,time:0}),true);
  const frames=[];
  for(const delta of [.1,.2,.4]){
   owner.animator.update(delta);owner.references.update(delta);owner.root.position.x+=delta;owner.references.update(0);
   const children=[];const visit=part=>{if(part.model68){const anchor=part.group.getWorldPosition(new THREE.Vector3()),actual=part.model68.root.getWorldPosition(new THREE.Vector3());assert.ok(anchor.distanceTo(actual)<1e-5);assert.deepEqual(part.model68.root.scale.toArray(),[1,1,1]);children.push({part:part.node.name,resource:part.model68.resourceName,position:actual.toArray()});}for(const child of part.children38)visit(child);};visit(owner.references.parts);frames.push({time:owner.animator.time,children});
  }
  let reattachment=null;
  if(reattach){
   const childAsset=[...asset.references.values()][0],target=create(childAsset,childAsset.model.modelName);sceneRoot.add(target.root);target.root.position.set(7,-2,5);const before=owner.root.quaternion.toArray(),eligible=entry.references.filter(r=>r.reattachable!==0).length;
   owner.references.reattach(target,'root');owner.references.update(0);
   const visit=part=>{if(part.node.type==='reference'&&part.header8.reattachableE0!==0)assert.ok(part.model68.root.position.distanceTo(target.root.position)<1e-5);for(const child of part.children38)visit(child);};visit(owner.references.parts);
   if(!eligible)assert.deepEqual(owner.root.quaternion.toArray(),before);
   target.root.position.x+=2;owner.references.update(.1);visit(owner.references.parts);
   reattachment={eligible,before,after:owner.root.quaternion.toArray()};owner.references.reattach(null,null);owner.references.update(0);
   const restored=part=>{if(part.node.type==='reference')assert.ok(part.model68.root.position.distanceTo(part.group.getWorldPosition(new THREE.Vector3()))<1e-5);for(const child of part.children38)restored(child);};restored(owner.references.parts);destroy(target);
  }
  assert.equal(owner.references.models.length,entry.references.length);assert.equal(new Set(owner.references.models).size,entry.references.length);destroy(owner);assert.equal(new Set(destroyed).size,instances.length);assert.equal(sceneRoot.children.length,0);releaseModelReferenceAssets(asset,a=>released.push(a.model.modelName));
  report.models.push({name:entry.name,clip:clip?.name??null,instances:instances.length,destroyed:destroyed.length,released,frames,reattachment});
 }
 report.validation='PASS';assert.equal(report.models.length,12);
}catch(error){report.validation='FAIL';report.error=error.stack;process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,models:report.models.length,instances:report.models.reduce((n,m)=>n+m.instances,0),error:report.error}));
