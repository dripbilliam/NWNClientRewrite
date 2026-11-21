import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import {prepareVisualModelTransfer} from './export-visual-model.mjs';
import {prepareVisualRigTransfer} from './export-rigs.mjs';
import {prepareGodotRoom} from './export-room.mjs';
import {createVisualModelFixture} from './visual-model-fixture.mjs';
import {createVisualModelStaging} from './staging-visual-model.mjs';
import {createModelHierarchy} from '../../src/model_hierarchy.js';
import {ModelAnimator} from '../../src/model_animation.js';
import {modelReferenceSceneForRoot} from '../../src/model_reference_scene.js';

test('visual-only resource retains skin, clips, physical reference ownership and no gameplay identity',()=>{
 const f=createVisualModelFixture({flags:3});
 try{
  const before=f.scene.children.slice(),poses=f.scene.children.map(root=>root.matrixWorld.toArray()),transfer=prepareVisualModelTransfer(f),entry=transfer.rigs.data.entities[0];
  assert.equal(entry.id,0);assert.equal(entry.models.length,2);assert.equal(entry.models[0].root,0);assert.equal(entry.animationSource,-1);assert.deepEqual(entry.clipMap,{});assert.equal(transfer.rigs.data.counts.skinMeshes,1);
  assert.equal(entry.attachments[0].flags,3);assert.deepEqual(entry.attachments[0].scale,[2,2,2]);assert.equal(entry.models[1].partNames[0],'child_base');
  const prepared=prepareGodotRoom({...f,inventory:[],entities:[],rigTransfer:transfer.rigs,particleTransfer:transfer.particles,includeCamera:false});
  assert.equal(prepared.manifest.meshes.length,3);assert.ok(prepared.manifest.meshes.every(row=>row.objectId===0));assert.deepEqual(prepared.manifest.entities,[]);prepared.dispose();
  assert.deepEqual(f.scene.children,before);assert.deepEqual(f.scene.children.map(root=>root.matrixWorld.toArray()),poses);
 }finally{f.close();}
});

test('unrelated models, outside references, repeated owners and transformed resource scenes are rejected',()=>{
 for(const change of [f=>f.scene.add(new T.Group()),f=>f.child.root.removeFromParent(),f=>f.model.references.models.push(f.model),f=>f.scene.position.x=2]){
  const f=createVisualModelFixture();try{change(f);assert.throws(()=>prepareVisualModelTransfer(f),/owned|repeated|identity/);}finally{if(f.model.references.models.at(-1)===f.model)f.model.references.models.pop();f.close();}
 }
});

test('visual root alias retains physical root identity when node storage is out of hierarchy order',()=>{
 const node=(name,parentIndex)=>({name,parentIndex,parent:'ignored',type:'dummy',position:[0,0,0],orientation:[0,0,0,1],scale:1});
 const model={modelName:'authored_order',animations:[],nodes:[node('duplicate',1),node('duplicate',2),node('actual_root',-1)]};
 const {root,nodeGroups}=createModelHierarchy(model);root.userData.mdlRoot=model.modelName;const scene=new T.Scene();scene.add(root);
 const transfer=prepareVisualRigTransfer({scene,models:[{root,model,animator:new ModelAnimator(model,root)}]}),entry=transfer.data.entities[0].models[0];
 assert.equal(entry.rootPart,2);assert.ok(entry.parts[1]<entry.parts[0]);assert.equal(transfer.nodeBinding(nodeGroups.get(model.nodes[2])).rigNode,entry.parts[2]);
});

const tick=()=>new Promise(resolve=>setImmediate(resolve));
function stagingFixture(){
 let resolveAsset,resolveExport,disposed=0,created=0,request;
 const model={modelName:'authored',nodes:[],animations:[]},asset={model},frontend={world:{areaId:7},areaGeneration:2};
 const assetWait=new Promise(resolve=>resolveAsset=resolve),exportWait=new Promise(resolve=>resolveExport=resolve);
 const owner={closed:false,visuals:{asset:()=>assetWait},instantiate(){created++;return{root:new T.Group(),dispose(){disposed++;}};}};
 let presenter=owner;
 const run=createVisualModelStaging({presentation:()=>presenter,frontend,exporter:async value=>{request=value;return exportWait;}});
 return{owner,frontend,run,resolveAsset:()=>resolveAsset(asset),resolveExport,replace:()=>presenter={},get created(){return created;},get disposed(){return disposed;},get request(){return request;}};
}
test('model preparation never enters canonical instances and cleans up after successful export',async()=>{
 const f=stagingFixture(),work=f.run('AUTHORED');f.resolveAsset();await tick();assert.equal(f.request.model.resourceName,'authored');assert.equal(f.request.scene.children.length,1);f.resolveExport({manifest:{kind:'visual-model'}});assert.equal((await work).manifest.kind,'visual-model');assert.equal(f.created,1);assert.equal(f.disposed,1);assert.equal(f.request.scene.children.length,0);
});

test('same-scope concurrent and repeated resource exports share stable metadata; a new world prepares a new copy',async()=>{
 const f=stagingFixture(),first=f.run('AUTHORED'),second=f.run('authored');f.resolveAsset();await tick();assert.equal(f.created,1);
 const payload={manifest:{kind:'visual-model',particles:{emitters:[{id:482}]}}};f.resolveExport(payload);
 assert.equal(await first,payload);assert.equal(await second,payload);assert.equal(await f.run('authored'),payload);assert.equal(f.created,1);assert.equal(f.disposed,1);
 f.frontend.world={areaId:7};assert.equal(await f.run('authored'),payload);assert.equal(f.created,2);assert.equal(f.disposed,2);
});
test('retired area, replaced presenter and disconnected owner cannot publish late visual assets',async()=>{
 for(const phase of ['asset','export'])for(const retire of [f=>f.frontend.areaGeneration++,f=>f.frontend.world.areaId++,f=>f.frontend.world={areaId:7},f=>f.owner.closed=true,f=>f.replace()]){
  const f=stagingFixture(),work=f.run('authored');if(phase==='export'){f.resolveAsset();await tick();}retire(f);f.resolveAsset();f.resolveExport({manifest:{}});assert.equal(await work,null);assert.equal(f.disposed,phase==='export'?1:0);
 }
});
test('current exporter failures are visible and still release privately created models',async()=>{
 const f=stagingFixture();await assert.rejects(f.run('../outside'),/name/);assert.equal(f.created,0);
 const owner={visuals:{asset:async()=>({model:{nodes:[]}})},instantiate:()=>({root:new T.Group(),dispose:()=>owner.disposed=true})};
 const run=createVisualModelStaging({presentation:()=>owner,frontend:{world:{areaId:1},areaGeneration:1},exporter:async()=>{throw Error('authored failure');}});
 await assert.rejects(run('authored'),/authored failure/);assert.equal(owner.disposed,true);
});

test('staging uses the original reference owner and releases every recursively created model on export failure',async()=>{
 const child={modelName:'authored_child',animations:[],nodes:[{name:'child',parent:'NULL',type:'dummy',position:[0,0,0],orientation:[0,0,0,1],scale:1}]};
 const source={modelName:'authored',animations:[],nodes:[{...child.nodes[0],name:'base'},{...child.nodes[0],name:'reference',parent:'base',type:'reference',properties:{refmodel:'authored_child',reattachable:1}}]};
 const asset={model:source,references:new Map([['authored_child',{model:child}]])},created=[],disposed=[];
 const owner={visuals:{asset:async()=>asset},instantiate(value){const {root}=createModelHierarchy(value.model);root.userData.mdlRoot=value.model.modelName;const instance={root,animator:new ModelAnimator(value.model,root),dispose:()=>disposed.push(instance)};created.push(instance);return instance;}};
 const run=createVisualModelStaging({presentation:()=>owner,frontend:{world:{areaId:1},areaGeneration:1},exporter:async context=>{
  assert.equal(modelReferenceSceneForRoot(context.model.root),context.model.references);assert.equal(prepareVisualModelTransfer(context).rigs.data.counts.models,2);throw Error('after referenced child');
 }});
 await assert.rejects(run('authored'),/after referenced child/);assert.equal(created.length,2);assert.equal(disposed.length,2);assert.equal(new Set(disposed).size,2);assert.ok(created.every(instance=>instance.root.parent===null));assert.equal(modelReferenceSceneForRoot(created[0].root),null);
});
