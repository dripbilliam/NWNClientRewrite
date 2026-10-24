import test from 'node:test';
import assert from 'node:assert/strict';
import {BufferAudioSource} from '../src/buffer_audio_source.js';
import {GameAudio} from '../src/game_audio.js';
import {NetworkPlacedSounds} from '../src/network_placed_sounds.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkFrontend} from '../src/network_frontend.js';
const tick=()=>new Promise(resolve=>setImmediate(resolve)),buffer={duration:.25,numberOfChannels:1,sampleRate:22050};
function output(loadBuffer=async()=>buffer){
 const nodes=[],axis=()=>({value:0}),base=()=>({connect(){},disconnect(){this.disconnected=true;}}),context={state:'running',destination:{},createGain:()=>({...base(),gain:axis()}),createPanner:()=>({...base(),positionX:axis(),positionY:axis(),positionZ:axis()}),createBufferSource(){const handlers={},source={...base(),playbackRate:axis(),addEventListener:(k,f)=>handlers[k]=f,start(){this.started=true;},stop(){this.stopped=true;handlers.ended?.();}};nodes.push(source);return source;}};
 return{streams:new Set(),context,nodes,loadBuffer,listenerState:{position:[0,0,0]},ensureContext:()=>context};
}
const profile={positional:true,loop:true,priority:3,referenceDistance:.5,maxDistance:5};
test('loop sources retain native byte gain/distance, park out of range, resume on approach and use native moving Z sign',async()=>{
 const audio=output(),source=new BufferAudioSource(audio,{objectId:0x80000013});source.configure(profile);source.setResRef('Torch');source.setVolume(97);assert.equal(source.play(),null);await tick();assert.equal(source.play(),250);assert.equal(source.hardwarePlaying(),true);assert.equal(source.record.gain.gain.value,Math.fround(97/255));assert.equal(source.record.panner.refDistance,.5);assert.equal(source.record.panner.maxDistance,5);
 source.setPosition([1,2,3]);assert.equal(source.record.panner.positionZ.value,-3);audio.listenerState.position=[100,100,100];source.update();assert.equal(source.hardwarePlaying(),false);assert.equal(source.status,'parked');audio.listenerState.position=[1,2,3];source.update();assert.equal(source.hardwarePlaying(),true);assert.equal(source.record.panner.positionZ.value,3);assert.equal(source.played,2);
 source.stop();source.update();assert.equal(source.hardwarePlaying(),false);source.dispose();assert.equal(audio.streams.size,0);assert.ok(audio.nodes.every(n=>n.stopped&&n.disconnected));
});
test('suspended and unresolved WAV sources cannot revive after stop, area unload or session disposal',async()=>{
 let release;const promise=new Promise(resolve=>release=resolve),audio=output(()=>promise),source=new BufferAudioSource(audio,{objectId:0xffffffff});source.configure(profile);source.setResRef('slow');assert.equal(source.play(),null);source.dispose();release(buffer);await tick();assert.equal(source.hardwarePlaying(),false);assert.equal(audio.nodes.length,0);
 const next=new BufferAudioSource(audio,{objectId:0x80000001});next.configure({...profile,positional:false});next.setResRef('queued');next.play();await tick();audio.context.state='suspended';assert.equal(next.play(),250);assert.equal(next.hardwarePlaying(),false);next.stop();audio.context.state='running';next.flush();assert.equal(next.hardwarePlaying(),false);next.dispose();assert.equal(audio.streams.size,0);
});
test('native SetResRef stops existing playback and resets pitch even for the same resource; stereo3D returns duration without a voice',async()=>{
 const audio=output(),source=new BufferAudioSource(audio,{objectId:3,random:()=>127});source.configure(profile);source.setResRef('wave');source.setPitchVariance(2);source.play();await tick();source.play();assert.equal(source.pitchVariance,1);assert.equal(source.hardwarePlaying(),true);source.setResRef('wave');assert.equal(source.hardwarePlaying(),false);assert.equal(source.rate,null);source.setPitchVariance(NaN);assert.equal(source.pitchVariance,1);source.dispose();
 const stereo=output(async()=>({...buffer,numberOfChannels:2})),s=new BufferAudioSource(stereo,{objectId:5});s.configure(profile);s.setResRef('stereo');s.play();await tick();assert.equal(s.play(),250);assert.equal(s.hardwarePlaying(),false);assert.equal(s.status,'stereo-3d-rejected');s.dispose();
});
test('missing resources are recorded once per source/reference and return native zero duration',async()=>{
 const records=[],audio=output(async()=>{throw Error('Missing WAV');}),source=new BufferAudioSource(audio,{objectId:0x80000013,onFailure:(error,data)=>records.push({message:error.message,...data})});source.configure(profile);source.setResRef('missing');assert.equal(source.play(),null);await tick();assert.equal(source.play(),0);assert.equal(source.play(),0);assert.deepEqual(records,[{message:'Missing WAV',objectId:0x80000013,resRef:'missing'}]);source.dispose();
});
test('source duration and pitch use original WAV metadata even when Chromium resamples the buffer',async()=>{
 const audio=output(async()=>({...buffer,sampleRate:48000,duration:.999}));audio.bufferTiming=()=>({sampleRate:8000,channels:1,duration:123});const source=new BufferAudioSource(audio,{objectId:7,random:()=>127});source.configure(profile);source.setResRef('resampled');source.setPitchVariance(.2);source.play();await tick();assert.equal(source.play(),123);assert.equal(source.timing.sampleRate,8000);assert.equal(source.rate,(8000+127)/8000);source.dispose();
});
function areaSound(){return{id:0x80000013,position:[0,0,0],refs:['torch'],fields:{'308':1,'30c':1,'310':1,'314':97,'318':0,'31c':3,'320':0,'324':0,'348':0,'34c':0,'350':.5,'354':5,'358':0,'35c':0,'32c':0,'330':0,'334':0}};}
test('area source lifecycle uses canonical sound proxies and frontend server commands without chat or local object allocation',async()=>{
 const world=new NetworkWorld(),sound=areaSound(),area={id:0x80000047,width:1,height:1,tiles:[{fields:{'18':0}}],sounds:[sound]},audio=output(),records=[];world.areaId=area.id;world.time={hour:6,timeOfDay:1};world.registry.addObjectAtPos(area.id,{objectType:4,state:area});world.registry.addObjectAtPos(sound.id,{objectType:16,areaId:area.id,state:sound,nativeSoundHeight:0});const before=JSON.stringify([...world.registry.objects]),placed=new NetworkPlacedSounds({world:()=>world,output:audio,report:(...args)=>records.push(args),now:()=>0});placed.attach(area);placed.update();await tick();placed.update();assert.equal(placed.snapshot().objects[0].source.hardwarePlaying,true);assert.equal(JSON.stringify([...world.registry.objects]),before);
 const front={id:3,world,queue:Promise.resolve(),onAudio:m=>placed.receive(m),onHud:()=>{throw Error('Sound objects must never enter chat');},showError:e=>{throw e;}};
 for(const operation of [3,2,7]){NetworkFrontend.prototype.receive.call(front,{sessionId:3,kind:'message',message:{kind:'sound-object',objectId:sound.id,operation}});await front.queue;if(operation===3)assert.equal(placed.owners.get(sound.id).active,0);if(operation===2){placed.update();assert.equal(placed.owners.get(sound.id).active,1);}}
 assert.equal(world.registry.get(sound.id),undefined);assert.equal(placed.owners.size,0);assert.equal(audio.streams.size,0);assert.deepEqual(records.map(r=>r[0]),['network.placed-sound-mixer-unhandled']);placed.dispose();
});
test('stateful source buffers share the existing GameAudio decode cache',async()=>{
 let reads=0,decodes=0;const context={state:'running',addEventListener(){},async decodeAudioData(){decodes++;return buffer;},close:async()=>{}},audio=new GameAudio({getResource:async()=>{reads++;return new ArrayBuffer(1);}},{getObject:()=>null,getPlayer:()=>null,createContext:()=>context});const [a,b]=await Promise.all([audio.loadBuffer('shared'),audio.loadBuffer('SHARED')]);assert.equal(a,b);assert.equal(reads,1);assert.equal(decodes,1);audio.dispose();
});
