import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {ClientProjectilePresentation,ClientProjectileInbox} from '../src/client_projectile_presentation.js';
import {NativeRandom} from '../src/native_random.js';
import {OBJECT_INVALID,GameObjectArray} from '../src/game_object_array.js';
import {NativeEffectSound} from '../src/native_effect_sound.js';
function fixture({deferred=false,path='homing',distinctModels=false,targetType,targetModelName,soundFactory,projectileSound}={}){
 const server=new GameObjectArray(),actor={objectType:5,position:[1,3,-2],orientation:[1,0,0],areaId:1};server.addInternalObject(actor);let current=[actor],time=0,resolve;
 const row={Proj:'1',ProjType:path,ProjModel:'authored',ProjOrientation:'path',ProjSpwnPoint:'hand',ProjSound:projectileSound??''},rules={spells:{columns:Object.keys(row),orderedRows:[row],defaultValue:'****'}},scene=new THREE.Group(),destroyed=[],diagnostics=[],model={root:new THREE.Group(),resourceName:'authored',model:{animations:[{name:'travel01'},{name:'impact01'}]},animator:{playNative:()=>true,update:()=>{}}};
 const target=targetType?{objectType:targetType,position:[8,3,-9],orientation:[1,0,0],areaId:1}:null,targetRender={userData:{nativeLoadedModelName:targetModelName}},poseNames=[];
 if(target){server.addInternalObject(target);current.push(target);}
 const loading=deferred?new Promise(r=>resolve=r):Promise.resolve(model),models=[],p=new ClientProjectilePresentation({objects:()=>current,renderFor:id=>target&&id===target.id?targetRender:null,rules:()=>rules,now:()=>({day:0,time}),dayLength:()=>1000000,random:new NativeRandom(1),loadModel:()=>{if(deferred)return loading;const loaded=distinctModels&&models.length?{...model,root:new THREE.Group(),animator:{...model.animator}}:model;models.push(loaded);return Promise.resolve(loaded);},destroyModel:m=>{m.root.removeFromParent();destroyed.push(m);},modelFor:()=>model,nodePose:(_model,name,point)=>{poseNames.push(name);if(name==='a01_impact'||name==='tdr02impc'){point.splice(0,3,8,9,5);return 1;}return 0;},orient:()=>{},scene,report:(code,message,data)=>diagnostics.push({code,message,data}),soundFactory,oneShot:()=>{}});
 const entry={source:actor,areaId:1,header:{sourceId:0x80000000,targetId:OBJECT_INVALID,from:[1,2,3],to:[4,5,6],duration:500,appearance:6,spellId:0,path:null}};
 if(target){entry.target=target;entry.header.targetId=(target.id|0x80000000)>>>0;}
 return{server,actor,target,poseNames,p,entry,scene,model,models,destroyed,diagnostics,resolve:()=>resolve(model),setObjects:objects=>current=objects,setTime:t=>time=t};
}

const tick=()=>new Promise(r=>setImmediate(r));
function audioOutput(load=async()=>({duration:1,numberOfChannels:1,sampleRate:22050})){
 const nodes=[],axis=()=>({value:0}),base=()=>({connect(){},disconnect(){}}),audio={streams:new Set(),listenerState:{position:[0,0,0]},loadBuffer:load};
 audio.context={state:'running',destination:{},createGain:()=>({...base(),gain:axis()}),createPanner:()=>({...base(),positionX:axis(),positionY:axis(),positionZ:axis()}),createBufferSource(){const events={},n={...base(),playbackRate:axis(),addEventListener:(k,f)=>events[k]=f,start(){this.started=true;},stop(){this.stopped=true;events.ended?.();}};nodes.push(n);return n;}};audio.nodes=nodes;audio.update=()=>{for(const s of audio.streams)s.update();};return audio;
}

test('native projectile AI creates one moving 3D loop and destroys it at impact without changing server objects',async()=>{
 const audio=audioOutput(),f=fixture({projectileSound:'authored_loop',soundFactory:options=>new NativeEffectSound(audio,options)}),before=structuredClone(f.actor),cursor=[...f.server.nextObjectId];await f.p.receive(f.entry);assert.equal(audio.streams.size,0,'Sound is created by native AI, not receive/model loading');
 f.p.update(0);const state=[...f.p.active][0],sound=state.sound;await tick();audio.update();assert.equal(audio.nodes.length,1);assert.equal(sound.snapshot().priority,12);assert.equal(sound.snapshot().positional,true);assert.equal(sound.snapshot().loop,true);assert.equal(sound.snapshot().objectId,OBJECT_INVALID);assert.equal(sound.snapshot().channel,'projectile-loop');
 f.setTime(250);f.p.update(.25);audio.update();assert.deepEqual(sound.snapshot().position,[...state.position.slice(0,2),Math.fround(state.position[2]+1.5)]);assert.equal(sound.source.record.panner.positionZ.value,-sound.source.position[2]);assert.equal(audio.nodes.length,1);
 f.setTime(500);f.p.update(.25);assert.equal(state.sound,null);assert.equal(sound.destroyed,true);assert.equal(audio.streams.size,0);assert.equal(audio.nodes[0].stopped,true);assert.equal(f.p.stats.soundCreated,1);assert.equal(f.p.stats.soundPlayRequests,1);assert.equal(f.p.stats.soundStopped,1);assert.equal(f.p.stats.soundDestroyed,1);assert.equal(f.p.events.find(e=>e.kind==='loopSoundStop').sound.played,1);
 f.setTime(502);f.p.update(.002);f.p.dispose();assert.equal(f.p.stats.soundDestroyed,1);assert.deepEqual(f.actor,before);assert.deepEqual(f.server.nextObjectId,cursor);assert.ok(!f.diagnostics.some(d=>d.code==='visual.projectile-loop-audio-unimplemented'));
});

test('area disposal releases a pending projectile loop and late decode cannot restart it',async()=>{
 let finish;const audio=audioOutput(()=>new Promise(r=>finish=r)),f=fixture({projectileSound:'late_loop',soundFactory:o=>new NativeEffectSound(audio,o)});await f.p.receive(f.entry);f.p.update(0);const sound=[...f.p.active][0].sound;assert.equal(sound.pending,true);f.p.dispose();assert.equal(sound.destroyed,true);assert.equal(audio.streams.size,0);assert.equal(f.p.stats.soundDestroyed,1);
 finish({duration:1,numberOfChannels:1,sampleRate:22050});await tick();audio.update();assert.equal(audio.nodes.length,0);assert.equal(f.p.active.size,0);
});

test('native multi-projectile path owns independent loops and absent WAV output does not stop projectile resolution',async()=>{
 const audio=audioOutput(),f=fixture({distinctModels:true,projectileSound:'multi_loop',soundFactory:o=>new NativeEffectSound(audio,o)});f.entry.header.appearance=7;f.entry.header.path=4;const side=f.p.p.randomState.angleSide;
 try{await f.p.receive(f.entry);f.p.update(0);await tick();audio.update();assert.equal(audio.nodes.length,5);assert.equal(f.p.stats.soundCreated,5);f.p.update(0);assert.equal(f.p.stats.soundPlayRequests,5);f.setTime(500);f.p.update(.5);assert.equal(f.p.stats.soundDestroyed,5);assert.equal(audio.streams.size,0);}finally{f.p.dispose();f.p.p.randomState.angleSide=side;}
 const failures=[],missing=audioOutput(async()=>{throw Error('Missing authored WAV');}),g=fixture({projectileSound:'missing_loop',soundFactory:o=>new NativeEffectSound(missing,{...o,onFailure:e=>failures.push(e.message)})});await g.p.receive(g.entry);g.p.update(0);await tick();missing.update();missing.update();assert.deepEqual(failures,['Missing authored WAV']);assert.equal(missing.nodes.length,0);g.setTime(500);g.p.update(.5);g.setTime(502);g.p.update(.002);assert.equal(g.p.stats.failed,0);assert.equal(g.p.stats.impacts,1);assert.equal(missing.streams.size,0);g.p.dispose();
});

test('door/placeable loaded resource prefixes drive actual path attachment queries and velocity',async()=>{
 for(const [targetType,targetModelName,node]of [[9,'plc_a01','a01_impact'],[10,'tdr02','tdr02impc']]){
  const f=fixture({targetType,targetModelName}),before=[...f.server.nextObjectId];
  try{await f.p.receive(f.entry);f.p.update(0);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));const state=[...f.p.active][0];assert.equal(state.impactNode,node);assert.ok(f.poseNames.includes(node));assert.deepEqual(state.velocity,[14,14,2]);assert.deepEqual(f.server.nextObjectId,before);assert.equal(f.server.get(f.target.id),f.target);}
  finally{f.p.dispose();}
 }
});

test('a projectile model without animation clips still travels, impacts and expires through native stage ownership',async()=>{
 const f=fixture({path:'accelerating'});f.model.animator=null;f.model.model.animations=[];
 try{await f.p.receive(f.entry);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.equal(f.scene.children.length,1);f.setTime(500);f.p.update(.5);f.setTime(502);f.p.update(.002);assert.equal(f.p.stats.impacts,1);assert.equal(f.p.stats.destroyed,1);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.equal(f.scene.children.length,0);assert.ok(f.diagnostics.some(d=>d.code==='visual.projectile-clip-unavailable'));assert.equal(f.diagnostics.some(d=>/failed/.test(d.code)),false);}finally{f.p.dispose();}
});
test('native path4 override creates five independent client models with shared CRT draw order and reclaims every transient',async()=>{
 const f=fixture({distinctModels:true}),initialSide=f.p.p.randomState.angleSide;f.entry.header.appearance=7;f.entry.header.path=4;
 try{
  await f.p.receive(f.entry);assert.equal(f.p.stats.failed,0,JSON.stringify(f.diagnostics));assert.equal(f.p.stats.spawned,5);assert.equal(f.p.random.draws,15);assert.equal(f.scene.children.length,5);assert.equal(new Set(f.models).size,5);assert.equal(f.p.p.randomState.angleSide,initialSide===0?1:0);
  f.setTime(500);f.p.update(.5);assert.equal(f.p.stats.impacts,5);f.setTime(502);f.p.update(.002);assert.equal(f.p.stats.destroyed,5);assert.equal(f.p.active.size,0);assert.equal(f.scene.children.length,0);assert.equal(new Set(f.destroyed).size,5);assert.equal(f.server.nextObjectId[0],1);
 }finally{f.p.p.randomState.angleSide=initialSide;f.p.dispose();}
});
test('burst override uses four CRT draws and the high-ballistic path crosses its external-animation reset node',async()=>{
 const burst=fixture(),initialSide=burst.p.p.randomState.angleSide;burst.entry.header.appearance=7;burst.entry.header.path=9;
 try{await burst.p.receive(burst.entry);assert.equal(burst.p.stats.failed,0,JSON.stringify(burst.diagnostics));assert.equal(burst.p.random.draws,4);assert.equal(burst.p.active.size,1);}finally{burst.p.dispose();burst.p.p.randomState.angleSide=initialSide;}
 const high=fixture({path:'highballistic'});await high.p.receive(high.entry);assert.equal(high.p.stats.failed,0);high.setTime(300);high.p.update(.3);assert.equal(high.p.stats.failed,0,JSON.stringify(high.diagnostics));assert.equal(high.model.externalAnimationHeader.counter,4);
 high.setTime(600);high.p.update(.3);high.setTime(602);high.p.update(.002);assert.equal(high.p.active.size,0);assert.equal(high.p.stats.destroyed,1);
});
test('live path/AI stages reclaim client object, scene and model while leaving the authoritative registry untouched',async()=>{
 const f=fixture(),before=[...f.server.nextObjectId];await f.p.receive(f.entry);assert.equal(f.p.stats.loaded,1);assert.equal(f.scene.children.length,1);assert.equal(f.actor.id,0);assert.deepEqual(f.server.nextObjectId,before);
 f.setTime(500);f.p.update(.5);assert.equal(f.p.stats.impacts,1);assert.equal(f.p.snapshot().active[0].stage,2);f.setTime(502);f.p.update(.002);
 assert.equal(f.p.active.size,0);assert.equal(f.scene.children.length,0);assert.deepEqual(f.destroyed,[f.model]);assert.equal(f.p.objects.get(0),undefined);assert.equal(f.server.get(0),f.actor);assert.deepEqual(f.server.nextObjectId,before);
});
test('late asset load cannot resurrect a projectile after area disposal',async()=>{
 const f=fixture({deferred:true}),pending=f.p.receive(f.entry);assert.equal(f.p.active.size,1);f.p.dispose();f.resolve();await pending;
 assert.equal(f.p.active.size,0);assert.equal(f.scene.children.length,0);assert.deepEqual(f.destroyed,[f.model]);assert.equal(f.p.stats.destroyed,1);
});
test('a late ranged rules load cannot register a projectile after its area is disposed',async()=>{
 const f=fixture();let release;f.p.p.rangedMetadata=async()=>{await new Promise(r=>release=r);return f.p.disposed?null:{ammunition:1,model:'authored'};};f.entry.header.appearance=0;f.entry.header.baseItem=8;const pending=f.p.receive(f.entry);f.p.dispose();release();await pending;assert.equal(f.p.stats.spawned,0);assert.equal(f.p.active.size,0);assert.equal(f.scene.children.length,0);
});
test('async asset load rejects a replaced canonical object even when its numeric ID matches',async()=>{
 const f=fixture({deferred:true}),pending=f.p.receive(f.entry);f.setObjects([{...f.actor}]);f.resolve();await pending;
 assert.equal(f.p.active.size,0);assert.equal(f.scene.children.length,0);assert.equal(f.p.stats.destroyed,1);assert.ok(f.diagnostics.some(d=>d.code==='visual.projectile-target-stale'));
});
test('an unavailable linked endpoint adapter produces a durable failure and releases the projectile model',async()=>{
 const f=fixture({path:'linked'});await f.p.receive(f.entry);assert.equal(f.p.stats.failed,1);assert.equal(f.p.active.size,0);assert.equal(f.destroyed.length,1);assert.ok(f.diagnostics.some(d=>d.code==='visual.projectile-receiver-failed'&&d.message.includes('auxiliary-model adapter')));
});
test('projectile inbox snapshots identity and discards old area delivery without reading a new target from the same ID',()=>{
 const f=fixture(),diagnostics=[],received=[],session={player:f.actor,registry:f.server},inbox=new ClientProjectileInbox({session:()=>session,report:code=>diagnostics.push(code)});
 inbox.receive({type:'safeProjectile',recipientId:f.actor.id,data:{sourceId:f.actor.id,targetId:OBJECT_INVALID,from:[1,2,3],to:[4,5,6],duration:500,appearance:6,flags:0}});f.server.delete(f.actor.id);f.server.addObjectAtPos(f.actor.id,{...f.actor});
 inbox.flush({session,objects:{registry:f.server,areaId:1},presentation:{receive:e=>received.push(e)}});assert.equal(received.length,0);assert.deepEqual(diagnostics,['visual.projectile-message-stale']);
});

test('projectile inbox forwards absent source/target to native fallback instead of treating deletion as ID reuse',()=>{
 const f=fixture(),diagnostics=[],received=[],session={player:f.actor,registry:f.server},inbox=new ClientProjectileInbox({session:()=>session,report:code=>diagnostics.push(code)});
 const target={objectType:5};f.server.addInternalObject(target);inbox.receive({type:'safeProjectile',recipientId:f.actor.id,data:{sourceId:f.actor.id,targetId:target.id,from:[1,2,3],to:[4,5,6],duration:500,appearance:6,flags:0}});f.server.delete(f.actor.id);f.server.delete(target.id);
 inbox.flush({session,objects:{registry:f.server,areaId:1},presentation:{receive:e=>received.push(e)}});assert.equal(received.length,1);assert.equal(received[0].target,target);assert.deepEqual(diagnostics,[]);
});
