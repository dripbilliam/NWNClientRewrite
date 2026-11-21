import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {ClientProjectilePresentation} from '../src/client_projectile_presentation.js';
import {GameObjectArray,OBJECT_INVALID} from '../src/game_object_array.js';
import {NativeRandom} from '../src/native_random.js';
function fixture({path=7,endpoint=true,deferred=false}={}){
 const registry=new GameObjectArray(),source={objectType:5,position:[1,0,-1],orientation:[1,0,0],areaId:1};registry.addInternalObject(source);const scene=new THREE.Group(),models=[],deleted=[],diagnostics=[],references=[],factoryModels=[];let time=0,resolve,released=0,preparing=false;
 const factory={create:alias=>{const model={root:new THREE.Group(),resourceName:'ref',alias};factoryModels.push(model);return model;},destroy:model=>{deleted.push(model);model.root.removeFromParent();},release:()=>released++};
 const row={Proj:'1',ProjType:'linked',ProjModel:'linkedmodel',ProjOrientation:'none',ProjSpwnPoint:'root'},rules={spells:{columns:Object.keys(row),orderedRows:[row],defaultValue:'****'}},prepare=deferred?new Promise(r=>resolve=r):Promise.resolve(endpoint?factory:null);
 const p=new ClientProjectilePresentation({objects:()=>registry.objects.values(),renderFor:()=>null,rules:()=>rules,now:()=>({day:0,time}),dayLength:()=>100000,random:new NativeRandom(77),scene,report:(code,message)=>diagnostics.push({code,message}),oneShot:()=>{},
  loadModel:async()=>{const model={root:new THREE.Group(),resourceName:'linkedmodel',model:{nodes:[{type:'dummy'}],animations:[]},animator:{playNative:()=>true,update:()=>{}},references:{reattach:(target,name)=>references.push({target,name})}};models.push(model);return model;},prepareAuxiliaryModel:()=>{preparing=true;return prepare;},destroyModel:model=>{deleted.push(model);model.root.removeFromParent();},modelFor:()=>null,nodePose:()=>0,orient:()=>{}});
 const entry={source,areaId:1,header:{sourceId:0x80000000,targetId:OBJECT_INVALID,from:[1,1,0],to:[4,5,6],duration:500,appearance:7,spellId:0,path}};
 return{p,entry,registry,models,deleted,references,factoryModels,diagnostics,scene,get preparing(){return preparing;},get released(){return released;},resolve:()=>resolve(factory),time:t=>time=t};
}
test('linked/random-linked renderer owns its separate endpoint through impact and deletes it before the projectile model',async()=>{
 for(const path of [7,10]){
  const f=fixture({path}),before=[...f.registry.nextObjectId];await f.p.receive(f.entry);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));const state=[...f.p.active][0];assert.ok(state.auxiliaryModel);assert.equal(f.references.length,1);assert.equal(f.references[0].target,state.auxiliaryModel);assert.equal(f.references[0].name,'root');
  if(path===7){assert.deepEqual(state.velocity,[0,0,0]);assert.deepEqual(state.auxiliaryModel.root.position.toArray(),[4,6,-5]);assert.equal(state.auxiliaryModel.root.parent,null);}
  else{assert.deepEqual(state.auxiliaryModel.root.position.toArray(),[1,1,-1]);assert.ok(Math.abs(state.model.root.position.y-Math.fround(1+Math.fround(.01)))<1e-8);assert.equal(state.auxiliaryModel.root.parent,f.scene);}
  f.time(500);f.p.update(.5);f.time(502);f.p.update(.002);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.equal(f.p.active.size,0);assert.deepEqual(f.deleted,[f.factoryModels[0],f.models[0]]);assert.equal(f.released,1);assert.equal(f.scene.children.length,0);assert.deepEqual(f.registry.nextObjectId,before);f.p.dispose();assert.equal(f.released,1);
 }
});
test('native endpoint allocation failure retains the projectile rather than inventing an endpoint model',async()=>{
 for(const path of [7,10]){const f=fixture({path,endpoint:false});await f.p.receive(f.entry);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));const state=[...f.p.active][0];assert.equal(state.auxiliaryModel,null);assert.equal(f.references.length,0);f.p.dispose();assert.equal(f.deleted.length,1);}
});
test('late endpoint prefetch after area disposal releases its assets without resurrecting or double-deleting the main model',async()=>{
 const f=fixture({deferred:true}),pending=f.p.receive(f.entry);while(!f.preparing)await new Promise(r=>setTimeout(r,0));f.p.dispose();f.resolve();await pending;assert.equal(f.p.active.size,0);assert.equal(f.scene.children.length,0);assert.equal(f.deleted.length,1);assert.equal(f.released,1);assert.equal(f.factoryModels.length,0);
});
