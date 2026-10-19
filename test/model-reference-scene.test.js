import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {ModelReferenceScene} from '../src/model_reference_scene.js';
import {loadModelReferenceAssets,releaseModelReferenceAssets} from '../src/model_reference_assets.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
const node=(name,parent='NULL',type='dummy',ref)=>({name,parent,type,position:[0,0,0],orientation:[0,0,0,1],scale:1,properties:ref?{refmodel:ref,reattachable:1}:{} });
const model=(name,nodes)=>({modelName:name,nodes,animations:[]});
function fixture(){
 const a=model('a',[node('a'),node('anchor1','a','reference','b'),node('anchor2','a','reference','b')]),b=model('b',[node('b'),node('nested','b','reference','c')]),c=model('c',[node('c')]);a.nodes[1].position=[2,0,0];a.nodes[1].scale=3;
 const sources=new Map([['a',a],['b',b],['c',c]]),sceneRoot=new THREE.Group(),instances=[],destroyed=[],released=[],reads=[];
 const create=(asset,name)=>{const {root}=createModelHierarchy(asset.model);root.userData.mdlRoot=asset.model.modelName;const handle={root,model:asset.model,resourceName:name,animator:new ModelAnimator(asset.model,root)};instances.push(handle);if(asset.model.nodes.some(n=>n.type==='reference'))handle.references=new ModelReferenceScene({owner:handle,asset,sceneRoot,createModel:create,destroyModel:destroy});return handle;};
 const destroy=handle=>{handle.references?.dispose();handle.root.removeFromParent();destroyed.push(handle);};
 const load=async key=>{reads.push(key);if(!sources.has(key))throw Error('Missing child '+key);return{model:sources.get(key)};},release=asset=>released.push(asset.model.modelName);
 return{a,b,c,sources,sceneRoot,instances,destroyed,released,reads,create,destroy,load,release};
}
test('prefetched shared resources create distinct child instances, follow animated anchors without inheriting scale and clean nested ownership',async()=>{
 const f=fixture(),asset=await loadModelReferenceAssets('a',f),owner=f.create(asset,'a');f.sceneRoot.add(owner.root);owner.root.position.set(4,1,-2);owner.references.update(.1);
 assert.deepEqual(f.reads,['a','b','c']);assert.equal(f.instances.length,5);const [first,second]=owner.references.models;assert.notEqual(first,second);assert.notEqual(first.references.models[0],second.references.models[0]);
 assert.deepEqual(first.root.position.toArray(),[6,1,-2]);assert.deepEqual(first.root.scale.toArray(),[1,1,1]);
 const anchor=owner.root.getObjectByName('anchor1');anchor.position.y=5;owner.references.update(.1);assert.deepEqual(first.root.position.toArray(),[6,6,-2]);assert.deepEqual(first.references.models[0].root.position.toArray(),[6,6,-2]);
 f.destroy(owner);assert.equal(f.destroyed.length,5);assert.equal(new Set(f.destroyed).size,5);assert.equal(f.sceneRoot.children.length,0);owner.references.dispose();assert.equal(f.destroyed.length,5);
 releaseModelReferenceAssets(asset,f.release);assert.deepEqual(f.released,['c','b','a']);
});
test('missing and cyclic reference resources release all acquired assets without instantiating gameplay objects',async()=>{
 for(const kind of ['missing','cycle']){const f=fixture();f.b.nodes[1].properties.refmodel=kind==='cycle'?'a':'absent';await assert.rejects(loadModelReferenceAssets('a',f),kind==='cycle'?/cycle/:/Missing child/);assert.deepEqual(f.released,['a','b']);assert.equal(f.instances.length,0);}
});
test('native reference reattachment points the owner toward an external model and can restore authored anchors',async()=>{
 const f=fixture(),asset=await loadModelReferenceAssets('a',f),owner=f.create(asset,'a'),target=f.create(asset.references.get('b').references.get('c'),'c');f.sceneRoot.add(owner.root,target.root);target.root.position.set(7,3,-5);
 owner.references.reattach(target,'root');owner.references.update(0);
 const forward=new THREE.Vector3(0,1,0).applyQuaternion(owner.root.quaternion).normalize();assert.ok(forward.distanceTo(new THREE.Vector3(7,3,-5).normalize())<1e-5);
 for(const child of owner.references.models)assert.deepEqual(child.root.position.toArray(),[7,3,-5]);
 target.root.position.x+=2;owner.references.update(.1);for(const child of owner.references.models)assert.deepEqual(child.root.position.toArray(),[9,3,-5]);
 owner.references.reattach(null,null);owner.references.update(0);for(const part of [owner.references.parts.children38[0],owner.references.parts.children38[1]])assert.ok(part.model68.root.position.distanceTo(part.group.getWorldPosition(new THREE.Vector3()))<1e-5);
 f.destroy(owner);f.destroy(target);assert.equal(f.sceneRoot.children.length,0);
});
