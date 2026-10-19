import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {openLocalModule} from './local-module.mjs';
import {loadCharacterRules} from '../src/character.js';
import {parseModel} from '../src/model_parser.js';
import {inheritAnimations} from '../src/mdl_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {loadModelReferenceAssets,releaseModelReferenceAssets} from '../src/model_reference_assets.js';
import {ModelReferenceScene} from '../src/model_reference_scene.js';
import {visualLocalPoseServices} from '../src/visual_scene_pose.js';
import {ClientProjectilePresentation} from '../src/client_projectile_presentation.js';
import {clientProjectileSpell} from '../src/client_projectile_runtime.js';
import {clientProjectileModelQuaternion} from '../src/client_projectile_orientation.js';
import {GameObjectArray,OBJECT_INVALID} from '../src/game_object_array.js';
import {NativeRandom} from '../src/native_random.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-linked-projectile-v1.json',report={cases:[],limits:'Active installed spells/MDLs and real Three/ModelAnimator/native pose services; synthetic client message and canonical c_dummy target. Path10 uses native appearance7 override when not authored by that spell. No substitute for absent ref resource. Headless trajectories/lifetime, not rendered pixels/network/campaign.'};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),rules=await loadCharacterRules(resolver),spells=rules.spells.orderedRows.map((_r,id)=>clientProjectileSpell(rules,id)).filter(s=>s?.useProjectile&&s.model),linked=spells.filter(s=>s.projectilePath===7),ordinary=spells.find(s=>s.projectilePath===1);assert.ok(linked.length);assert.ok(ordinary);
 for(const choice of [...linked.map(spell=>({spell,path:7})),{spell:ordinary,path:10}])for(const targetPresent of [false,true]){
  const registry=new GameObjectArray(),target=targetPresent?{objectType:5,position:[5,0,-6],orientation:[1,0,0],areaId:1}:null;if(target)registry.addInternalObject(target);const ids=registry.nextObjectId.slice(),scene=new THREE.Group(),poses=visualLocalPoseServices({sceneRoot:scene}),models=[],destroyed=[],diagnostics=[],references=[];let time=0,presentation;
  const load=name=>loadModelReferenceAssets(name,{load:async key=>{const model=parseModel(await resolver.getResource(key,2002));await inheritAnimations(model,async n=>parseModel(await resolver.getResource(n,2002)));return{model};},release:()=>{}});
  const destroy=model=>{model.references?.dispose();model.root.removeFromParent();destroyed.push(model);};
  const create=(asset,name)=>{const {root}=createModelHierarchy(asset.model);root.userData.mdlRoot=asset.model.modelName;const model={root,model:asset.model,resourceName:name,asset,animator:new ModelAnimator(asset.model,root)};models.push(model);if(asset.model.nodes.some(n=>n.type==='reference')){model.references=new ModelReferenceScene({owner:model,asset,sceneRoot:scene,createModel:create,destroyModel:destroy});references.push(model.references);}return model;};
  const targetModel=target?create(await load('c_dummy'),'c_dummy'):null;if(targetModel){targetModel.root.position.set(...target.position);scene.add(targetModel.root);}
  const basis=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),inverse=basis.clone().invert();
  presentation=new ClientProjectilePresentation({objects:()=>registry.objects.values(),renderFor:id=>target&&id===target.id?targetModel.root:null,rules:()=>rules,now:()=>({day:0,time}),dayLength:()=>7200000,random:new NativeRandom(77),scene,report:(code,message,data)=>diagnostics.push({code,message,data}),oneShot:()=>{},
   loadModel:async name=>create(await load(name),name),destroyModel:destroy,prepareAuxiliaryModel:async resource=>{
    let asset;try{asset=await load(resource);}catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;diagnostics.push({code:'probe.auxiliary-resource-missing',resource});return null;}
    const owned=new Set();let released=false;const drop=model=>{if(owned.delete(model))destroy(model);};
    return{create:alias=>{assert.equal(released,false);const model=create(asset,resource);model.alias=alias;owned.add(model);return model;},destroy:drop,release:()=>{if(released)return;released=true;for(const model of [...owned])drop(model);releaseModelReferenceAssets(asset,()=>{});}};
   },
   modelFor:root=>poses.modelHandle(root),nodePose:(...args)=>poses.nodePoseInto(...args),orient:(m,v)=>{const q=clientProjectileModelQuaternion(v);if(q)m.root.quaternion.copy(basis).multiply(new THREE.Quaternion(q[1],q[2],q[3],q[0])).multiply(inverse);},
   impactAttachment:{attach:(...args)=>poses.setParent(...args),setNodePose:(...args)=>poses.setNodePose(...args),forget:m=>poses.forgetAttachment(m),updateAttachments:()=>poses.updateAttachments()}});
  try{
   await presentation.receive({source:null,target,areaId:1,header:{sourceId:OBJECT_INVALID,targetId:target?(target.id|0x80000000)>>>0:OBJECT_INVALID,from:[0,0,0],to:[5,6,0],duration:500,appearance:7,spellId:choice.spell.id,path:choice.path}});assert.equal(presentation.stats.failed,0,JSON.stringify(diagnostics));assert.equal(presentation.active.size,1);
   const snapshots=[structuredClone(presentation.snapshot())];for(const t of [100,300,500,502]){time=t;presentation.update(.1);for(const r of references)if(!r.owner.referenceParent)r.update(.1);snapshots.push(structuredClone(presentation.snapshot()));}
   assert.equal(presentation.stats.failed,0,JSON.stringify(diagnostics));assert.equal(presentation.active.size,0);assert.equal(presentation.stats.destroyed,1);assert.deepEqual(registry.nextObjectId,ids);
   report.cases.push({spellId:choice.spell.id,resource:choice.spell.model,path:choice.path,targetPresent,snapshots,diagnostics});
  }finally{presentation.dispose();if(targetModel)destroy(targetModel);for(const asset of new Set(models.map(m=>m.asset)))releaseModelReferenceAssets(asset,()=>{});}
  assert.equal(scene.children.length,0);assert.equal(new Set(destroyed).size,models.length);
 }
 report.validation='PASS';
}catch(error){report.validation='FAIL';report.error=error.stack;process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,cases:report.cases.length,error:report.error}));
