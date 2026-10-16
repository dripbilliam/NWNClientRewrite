import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {parse2da} from '../src/area.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {createVisualSceneRuntime} from '../src/visual_scene_runtime.js';
import {nativeStringEntry} from '../src/spell_metadata.js';
import {LoopingVisualPresentation} from '../src/looping_visual_presentation.js';
import {VisualPhaseRuntime,createVisualPhaseState} from '../src/visual_phase_runtime.js';

function model(name){return{modelName:name,nodes:[{name:'authored_root',parent:'NULL',position:[0,0,0],orientation:[0,0,0,1],orientationFormat:'quaternion',scale:1}],animations:[{name:'glow',length:2,tracks:[]}]};}
function root(data){const r=createModelHierarchy(data).root;r.userData.mdlRoot=data.modelName;return r;}
async function fixture(delivery){
 const actor={id:123,objectType:5,position:[2,3,4],creatureData:{Appearance_Type:0}},record={visualId:0,sourceId:123,bodyPart:0,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}};
 if(delivery)record.delivery=delivery;
 const tables={visuals:parse2da('2DA V2.0\n\nProgFX_Impact ProgFX_Duration ProgFX_Cessation\n0 0 1 2\n'),programs:parse2da('2DA V2.0\n\nType Param1 Param2 Param3 Param4 Param5 Param6 Param7\n0 4 glow 1 0 0 0 0 effect\n1 4 glow 1 0 0 0 0 effect\n2 4 glow -1 0 0 0 0 effect\n'),appearance:parse2da('2DA V2.0\n\nSIZECATEGORY\n0 3\n')};
 const sceneRoot=new THREE.Group(),scene=new THREE.Group();sceneRoot.add(scene);scene.add(root(model('body')));const calls=[],diagnostics=[];
 const instance=await createVisualSceneRuntime({actor,record,tables,objects:new Map([[123,actor]]),renderFor:()=>scene,player:()=>actor,sceneRoot,
  loadAsset:async name=>{calls.push(['load',name]);return model(name);},createModel:(asset,name)=>{calls.push(['create',name]);const r=root(asset);return{root:r,model:asset,resourceName:name,animator:new ModelAnimator(asset,r)};},
  destroyModel:m=>{calls.push(['destroy',m]);m.root.removeFromParent();},releaseAsset:a=>calls.push(['release',a]),shadowing:()=>{},report:(...args)=>diagnostics.push(args)});
 return{actor,record,instance,calls,diagnostics,sceneRoot,scene};
}

test('body replacement reattaches an existing live visual without restarting its phases or animator',async()=>{
 const f=await fixture();f.actor.nativeLoopingVisuals160={records:[f.record]};f.actor.areaId=7;
 const p=new LoopingVisualPresentation({areaId:7,objects:()=>[f.actor],object:()=>f.actor,render:()=>f.scene,tables:async()=>({}),createNative:async()=>f.instance,report:()=>{}});
 p.update(0);await p.entries.get(f.record).ready;p.update(.25);
 const state=f.instance.nativeState,effect=state.proceduralB8,phase=state.programPhaseFa,time=effect.animator.time,remaining=state.programRemainingCc,old=f.scene.children[0];
 old.removeFromParent();const body=root(model('new_body'));body.position.set(5,6,7);f.scene.add(body);p.rebindModel(f.actor);
 assert.equal(state.proceduralB8,effect);assert.equal(state.programPhaseFa,phase);assert.equal(effect.animator.time,time);assert.equal(state.programRemainingCc,remaining);
 assert.deepEqual(effect.root.position.toArray(),[5,6,7]);f.scene.position.set(9,10,11);p.update(.01);assert.deepEqual(effect.root.position.toArray(),[14,16,18]);
 assert.equal(f.calls.filter(c=>c[0]==='create').length,1);assert.equal(f.calls.filter(c=>c[0]==='destroy').length,0);assert.equal(p.entries.get(f.record).record,f.record);assert.equal(state.target54,f.actor.id);p.dispose();
});

test('shared scene phases prefetch once, instantiate at native phase boundaries and reuse Type4 duration for cessation',async()=>{
 const f=await fixture(),v=f.instance,s=v.nativeState;
 assert.deepEqual(f.calls,[['load','effect']]);assert.equal(s.proceduralB8,null);
 v.attach();const impact=s.proceduralB8;assert.equal(s.programPhaseFa,1);assert.equal(s.attached114,0);assert.equal(impact.animator.clip.name,'glow');
 v.attachModels();assert.equal(s.attached114,1);v.update(.5);assert.equal(s.programRemainingCc,500);assert.ok(impact.animator.time>0);
 v.update(.5);const duration=s.proceduralB8;assert.notEqual(duration,impact);assert.equal(s.programPhaseFa,2);assert.equal(f.calls.filter(c=>c[0]==='destroy').length,1);
 v.update(.25);const time=duration.animator.time;v.stop(1);
 assert.equal(s.programPhaseFa,3);assert.equal(s.closedEc,1);assert.equal(s.finishedF4,1);assert.equal(s.attached114,0);assert.equal(s.proceduralB8,duration);assert.equal(duration.animator.time,time);assert.equal(v.isRetired(),false);
 v.update(.999);assert.equal(s.programPhaseFa,3);v.update(.001);assert.equal(s.programPhaseFa,0);assert.equal(v.isRetired(),true);
 v.dispose();v.dispose();assert.equal(f.calls.filter(c=>c[0]==='destroy').length,2);assert.equal(f.calls.filter(c=>c[0]==='release').length,1);
 assert.deepEqual([s.target54,s.source58,f.actor.id,f.record.sourceId],[123,123,123,123]);
 assert.equal(f.diagnostics.some(c=>c[0].endsWith('-failed')),false);
});

test('forced scene cleanup releases current model and data once without requiring cessation',async()=>{
 const f=await fixture();f.instance.attach();f.instance.dispose();f.instance.dispose();assert.equal(f.instance.nativeState.proceduralB8,null);
 assert.equal(f.calls.filter(c=>c[0]==='destroy').length,1);assert.equal(f.calls.filter(c=>c[0]==='release').length,1);
});

test('decoded one-shot delivery uses instant loader semantics and naturally retires without a canonical effect or Stop1',async()=>{
 const f=await fixture({instant:1,sourcePart:0,targetPart:0,point:[1,2,3]});f.actor.areaId=7;f.actor.nativeLoopingVisuals160={records:[]};const binding={};
 const p=new LoopingVisualPresentation({areaId:7,objects:()=>[f.actor],object:()=>f.actor,render:()=>binding,tables:async()=>({}),createNative:async()=>f.instance,report:()=>{}});
 assert.equal(p.addTransient(f.actor,f.record),1);await Promise.all([...p.entries.values()].map(e=>e.ready));
 assert.equal(f.instance.nativeState.durationFc,0);assert.deepEqual(f.instance.nativeState.programsD0,[0,65535,65535]);assert.equal(p.snapshot()[0].transient,true);
 p.update(.5);assert.equal(p.entries.size,1);p.update(.5);assert.equal(p.entries.size,0);assert.equal(p.retiring.size,0);
 assert.equal(f.instance.nativeState.closedEc,0);assert.deepEqual(f.actor.nativeLoopingVisuals160.records,[]);assert.equal(f.calls.filter(c=>c[0]==='destroy').length,1);
 p.dispose();assert.equal(f.calls.filter(c=>c[0]==='release').length,1);
});

test('string query failure retains default output independently of its success flag',()=>{
 const table=parse2da('2DA V2.0\nDEFAULT: fallback\n\nName\n0 actual\n1 ****\n');
 assert.deepEqual(nativeStringEntry(table,0,'name'),{found:true,value:'actual'});
 assert.deepEqual(nativeStringEntry(table,1,'Name'),{found:false,value:''});
 assert.deepEqual(nativeStringEntry(table,2,'Name'),{found:false,value:'fallback'});
 assert.deepEqual(nativeStringEntry(table,0,'Missing'),{found:false,value:'fallback'});
});

test('full loader presenter admits impact-only phase data and retains cessation until the native predicate clears',async()=>{
 const f=await fixture();f.actor.areaId=7;f.actor.nativeLoopingVisuals160={records:[f.record]};const binding={},errors=[];
 const presenter=new LoopingVisualPresentation({areaId:7,objects:()=>[f.actor],object:()=>f.actor,render:()=>binding,tables:async()=>({}),
  createNative:async()=>f.instance,create:()=>{throw new Error('Duration-only admission must not run');},report:(...args)=>errors.push(args)});
 presenter.update(0);await Promise.all([...presenter.entries.values()].map(e=>e.ready));
 assert.equal(presenter.snapshot()[0].programId,0);assert.equal(presenter.snapshot()[0].attached,true);
 presenter.update(1);assert.equal(presenter.snapshot()[0].programId,1);
 f.actor.nativeLoopingVisuals160.records.length=0;presenter.update(0);assert.equal(presenter.entries.size,0);assert.equal(presenter.retiring.size,1);assert.equal(presenter.snapshot()[0].programId,2);
 presenter.update(.5);assert.equal(presenter.retiring.size,1);presenter.update(.5);assert.equal(presenter.retiring.size,0);
 assert.equal(f.calls.filter(c=>c[0]==='destroy').length,2);assert.deepEqual(errors,[]);presenter.dispose();
});

test('removed asynchronous native scene is disposed before any phase starts',async()=>{
 const f=await fixture();f.actor.nativeLoopingVisuals160={records:[f.record]};const binding={};let complete;
 const presenter=new LoopingVisualPresentation({objects:()=>[f.actor],object:()=>f.actor,render:()=>binding,tables:async()=>({}),createNative:()=>new Promise(resolve=>complete=resolve),report:()=>{}});
 presenter.update(0);const pending=[...presenter.entries.values()][0].ready;await Promise.resolve();
 f.actor.nativeLoopingVisuals160.records.length=0;presenter.update(0);complete(f.instance);await pending;
 assert.equal(f.calls.some(c=>c[0]==='create'),false);assert.equal(f.calls.filter(c=>c[0]==='release').length,1);presenter.dispose();
});

test('phase destructor destroys sound before models and controller storage and rejects non-DWORD time',()=>{
 const state=createVisualPhaseState(),calls=[];state.sound118={};state.proceduralB8={};state.models88[1]={};state.controllers128={};
 const runtime=new VisualPhaseRuntime(state,{destroySound:()=>calls.push('sound'),setParent:()=>{},setScene:()=>{},destroyModel:()=>calls.push('model'),destroyControllers:()=>calls.push('controllers')});
 for(const delta of [-1,NaN,Infinity,.5,0x100000000])assert.throws(()=>runtime.updateMilliseconds(delta),/DWORD/);
 runtime.dispose();runtime.dispose();assert.deepEqual(calls,['sound','model','model','controllers']);
});
