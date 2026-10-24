import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeEffectSound,effectSoundProviders} from '../src/native_effect_sound.js';
import {createAreaVisualState,startAreaVisualEffect,updateAreaVisualEffect} from '../src/area_visual_effect.js';
import {createVisualPhaseState,VisualPhaseRuntime} from '../src/visual_phase_runtime.js';
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function output(load=async()=>({duration:.25,numberOfChannels:1,sampleRate:22050})){
 const nodes=[],axis=()=>({value:0}),base=()=>({connect(){},disconnect(){}}),audio={streams:new Set(),listenerState:{position:[0,0,0]},loadBuffer:load};
 audio.context={state:'running',destination:{},createGain:()=>({...base(),gain:axis()}),createPanner:()=>({...base(),positionX:axis(),positionY:axis(),positionZ:axis()}),createBufferSource(){const events={},n={...base(),playbackRate:axis(),addEventListener:(k,f)=>events[k]=f,start(){this.started=true;},stop(){this.stopped=true;events.ended?.();}};nodes.push(n);return n;}};
 audio.nodes=nodes;return audio;
}
const configure=s=>{s.setting('setting1401d9e90',1);s.setting('setting1401da060',11);s.setting('setting1401d9f90',1);};
test('effect source keeps native constructor/phase settings, byte gain, native pose and ownership',async()=>{
 const audio=output(),s=new NativeEffectSound(audio,{resRef:'fx_loop',objectId:0xffffffff});configure(s);s.play();await tick();s.update();assert.equal(audio.nodes.length,1);const r=s.source.record;
 assert.equal(r.source.loop,true);assert.equal(r.gain.gain.value,Math.fround(127/255));assert.equal(r.panner.refDistance,1);assert.equal(r.panner.maxDistance,20);assert.equal(s.snapshot().priority,11);
 s.setPosition([2,3,4],1.5);assert.deepEqual(s.source.position,[2,3,5.5]);assert.equal(r.panner.positionZ.value,-5.5);
 s.stop();assert.equal(r.source.stopped,true);assert.equal(s.source.hardwarePlaying(),false);s.play();assert.equal(audio.nodes.length,2);s.dispose();s.dispose();assert.equal(audio.streams.size,0);
});
test('late WAV decode cannot revive a stopped or destroyed effect; missing/empty resources retain lifecycle',async()=>{
 for(const action of ['stop','dispose']){let done;const audio=output(()=>new Promise(r=>done=r)),s=new NativeEffectSound(audio,{resRef:'late'});configure(s);s.play();s[action]();done({duration:1,numberOfChannels:1,sampleRate:22050});await tick();s.update();assert.equal(audio.nodes.length,0);s.dispose();assert.equal(audio.streams.size,0);}
 const failures=[],audio=output(async()=>{throw Error('Absent WAV');}),s=new NativeEffectSound(audio,{resRef:'missing',onFailure:e=>failures.push(e.message)});configure(s);s.play();await tick();s.update();s.update();assert.deepEqual(failures,['Absent WAV']);assert.equal(audio.nodes.length,0);s.dispose();
 const empty=new NativeEffectSound(audio,{resRef:''});configure(empty);empty.play();empty.update();assert.equal(empty.pending,false);empty.dispose();assert.equal(audio.streams.size,0);
});
test('suspended output and range parking preserve one requested loop without repeated decoding/restarts',async()=>{
 const audio=output(),s=new NativeEffectSound(audio,{resRef:'loop'});configure(s);audio.context.state='suspended';s.play();await tick();s.update();assert.equal(audio.nodes.length,0);audio.context.state='running';s.source.update();assert.equal(audio.nodes.length,1);
 s.setPosition([30,0,0]);s.source.update();assert.equal(s.source.status,'parked');audio.listenerState.position=[29,0,0];s.source.update();assert.equal(audio.nodes.length,2);s.update();s.update();assert.equal(audio.nodes.length,2);s.dispose();
});
test('area visual native impact/duration/cessation sequence drives and destroys real output at its own phase boundaries',async()=>{
 const audio=output(),sounds=effectSoundProviders(resRef=>new NativeEffectSound(audio,{resRef}),()=>assert.fail('factory missing')),e=createAreaVisualState({day:0,time:0});e.visual180=3;e.position=[1,2,3];e.model={};let now=0;
 const p={...sounds,string:(_id,key)=>({found:true,value:key==='SoundDuration'?'loop':'cue'}),oneShot(){},animationLength:()=>10,play(){},speed40:()=>1,sound3d:(s,v)=>sounds.soundSetting(s,'setting1401d9e90',v),soundPriority:(s,v)=>sounds.soundSetting(s,'setting1401da060',v),soundLooping:(s,v)=>sounds.soundSetting(s,'setting1401d9f90',v),now:()=>({day:0,time:now}),difference:(a,b)=>({time:a.time-b.time})};
 startAreaVisualEffect(e,1,p);assert.equal(audio.streams.size,0);now=10;updateAreaVisualEffect(e,p);const source=e.sound170;assert.ok(source);assert.equal(e.phase184,2);await tick();source.update();assert.equal(source.source.hardwarePlaying(),true);
 now=11;updateAreaVisualEffect(e,p);assert.deepEqual(source.source.position,[1,2,4.5]);startAreaVisualEffect(e,3,p);assert.equal(e.sound170,null);assert.equal(source.destroyed,true);assert.equal(audio.streams.size,0);
});
test('visual phase destruction releases pending sound before its platform decode resolves',async()=>{
 let done;const audio=output(()=>new Promise(r=>done=r)),s=new NativeEffectSound(audio,{resRef:'pending'});configure(s);s.play();const e=createVisualPhaseState();e.sound118=s;const services=effectSoundProviders(null,()=>{}),runtime=new VisualPhaseRuntime(e,{...services,destroyControllers(){}});runtime.dispose();done({duration:1,numberOfChannels:1,sampleRate:22050});await tick();s.update();assert.equal(audio.nodes.length,0);assert.equal(audio.streams.size,0);
});
