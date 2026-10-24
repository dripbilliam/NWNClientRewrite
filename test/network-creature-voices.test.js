import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {playCreatureVoice} from '../src/client_creature_voice.js';
import {NetworkCreatureVoices} from '../src/network_creature_voices.js';
import {NativeEffectSound} from '../src/native_effect_sound.js';
import {NetworkWorld} from '../src/network_world.js';
import {parse2da} from '../src/area.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageWriter} from '../src/native_message.js';
const tick=()=>new Promise(r=>setImmediate(r));

test('creature voice gate, priority, replacement and call order match486 whole original executions',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-voice-observations.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,486);
 for(const {case:c,calls:expected,state:after}of fixture.cases){const calls=[],old={name:'old'},state={soundsetId:c.setId??7,sound:c.old?old:null,delay:77},p={
  demandSet:()=>{if(c.noSet)return null;calls.push(['demand']);return c.demandFailure?null:{};},entry:(_set,code)=>{calls.push(['entry',code]);return{resRef:c.resRef??'voice'};},releaseSet:()=>calls.push(['release']),exists:ref=>{calls.push(['exists',ref,4]);return!c.missingWave;},controlled:()=>{calls.push(['controlled']);return c.controlled;},player:()=>{calls.push(['player']);return c.player;},sizeCategory:()=>{calls.push(['size']);return c.size;},
  destroySound:()=>calls.push(['destroy']),createSound:ref=>{if(c.allocationFailure)return null;calls.push(['create',ref]);return{name:'new'};},sound3d:(_s,v)=>calls.push(['3d',v]),soundPriority:(_s,v)=>calls.push(['priority',v]),position:()=>[1,2,3],updateSound:(_s,v,h)=>calls.push(['position',v,h]),playSound:()=>calls.push(['play'])};
  // Native pointer400 is checked before CRes::Demand.
  if(c.noSet)state.soundsetId=65535;
  playCreatureVoice(state,c.code,c.positional,p);assert.deepEqual(calls,expected,JSON.stringify(c));assert.deepEqual({delay:state.delay,sound:state.sound?.name??null},after);
 }
});

function ssf(entries){const start=40+entries.length*4,bytes=new Uint8Array(start+entries.length*20),v=new DataView(bytes.buffer);bytes.set(new TextEncoder().encode('SSF V1.0'));v.setUint32(8,entries.length,true);v.setUint32(12,40,true);for(const [i,e]of entries.entries()){v.setUint32(40+i*4,start+i*20,true);bytes.set(new TextEncoder().encode(e.resRef),start+i*20);v.setUint32(start+i*20+16,e.strRef??0xffffffff,true);}return bytes;}
function setup({probe=async()=>{},caption=()=>{}}={}){
 const world=new NetworkWorld();world.areaId=0x80000001;world.localObjectId=0xffffffff;const actor={id:world.localObjectId,objectType:5,areaId:world.areaId,appearance:{appearance:0,field8A0:0},replicated:{position:[1,2,3]}};world.registry.addObjectAtPos(actor.id,actor);
 const nodes=[],axis=()=>({value:0}),base=()=>({connect(){},disconnect(){}}),audio={streams:new Set(),listenerState:{position:[0,0,0]},loadBuffer:async()=>({numberOfChannels:1,duration:1,sampleRate:22050})};audio.context={state:'running',destination:{},createGain:()=>({...base(),gain:axis()}),createPanner:()=>({...base(),positionX:axis(),positionY:axis(),positionZ:axis()}),createBufferSource(){const events={},source={...base(),playbackRate:axis(),addEventListener:(k,f)=>events[k]=f,start(){this.started=true;},stop(){this.stopped=true;events.ended?.();}};nodes.push(source);return source;}};audio.update=()=>{for(const s of audio.streams)s.update();};
 const diagnostics=[],captions=[],sets=ssf([{resRef:'cue',strRef:10},{resRef:'',strRef:11},{resRef:'missing'},{resRef:'slow'},{resRef:'fast',strRef:14}]),resolver={getResource:async(name,type)=>{if(type===2017)return new TextEncoder().encode('2DA V2.0\n\nRESREF\n0 installed_set\n');if(type===2060)return sets;if(name==='missing')throw Error('Absent WAV');await probe(name);return new ArrayBuffer(44);}},appearance=parse2da('2DA V2.0\n\nSIZECATEGORY\n0 3\n');
 const voices=new NetworkCreatureVoices({world,resolver,appearance,position:o=>o.replicated.position,soundFactory:o=>new NativeEffectSound(audio,o),caption:async event=>{captions.push(event);await caption(event);},report:(code,message,data)=>diagnostics.push({code,message,data})});return{world,actor,voices,audio,nodes,diagnostics,captions};
}

test('quick-chat and barks share one native source, preserve silent entries and follow current pose',async()=>{
 const f=setup(),before=structuredClone(f.actor),cursor=[...f.world.registry.nextObjectId];await f.voices.receive({kind:'quick-chat',objectId:f.actor.id,quickChat:0});await tick();f.audio.update();const first=f.voices.actors.get(f.actor.id).sound;assert.equal(first.snapshot().priority,6);assert.equal(first.snapshot().positional,true);assert.deepEqual(first.snapshot().position,[1,2,3]);assert.equal(f.captions.length,1);
 await f.voices.receive({kind:'quick-chat',objectId:f.actor.id,quickChat:1});assert.equal(first.destroyed,false,'Empty SSF sound overrides TLK and keeps prior voice');assert.equal(f.captions.length,2);await f.voices.bark(f.actor.id,0);await tick();f.audio.update();const second=f.voices.actors.get(f.actor.id).sound;assert.equal(first.destroyed,true);assert.deepEqual(second.snapshot().position,[1,2,4.5]);assert.equal(f.audio.streams.size,2);assert.equal(f.captions.length,2,'Combat barks do not manufacture chat text');assert.deepEqual(f.actor,before);assert.deepEqual(f.world.registry.nextObjectId,cursor);
 f.actor.replicated.position=[4,5,6];f.voices.update();assert.deepEqual(second.snapshot().position,[4,5,7.5]);f.voices.dispose();assert.equal(f.audio.streams.size,0);assert.equal(f.voices.actors.size,0);
});

test('newer valid voice wins async races while missing and silent requests preserve pending older valid audio',async()=>{
 for(const kind of ['missing','silent','fast']){let release;const f=setup({probe:name=>name==='slow'?new Promise(r=>release=r):Promise.resolve()});const old=f.voices.bark(f.actor.id,3);await tick();assert.equal(typeof release,'function');await f.voices.receive({kind:'quick-chat',objectId:f.actor.id,quickChat:kind==='missing'?2:kind==='silent'?1:4});release();await old;await tick();f.audio.update();assert.equal(f.voices.actors.get(f.actor.id).sound.resRef,kind==='fast'?'fast':'slow');assert.equal(f.nodes.length,1);if(kind==='missing')assert.equal(f.diagnostics.filter(d=>d.code==='network.voice-wave-unavailable').length,1);f.voices.dispose();}
});

test('canonical object removal, replacement, soundset change and scene disposal invalidate pending audio',async()=>{
 for(const action of ['remove','replace','soundset','dispose']){let release;const f=setup({probe:()=>new Promise(r=>release=r)}),request=f.voices.bark(f.actor.id,0);await tick();if(action==='dispose')f.voices.dispose();else if(action==='soundset')f.actor.appearance.field8A0=65535;else{f.world.registry.delete(f.actor.id);if(action==='replace')f.world.registry.addObjectAtPos(f.actor.id,structuredClone(f.actor));}release();assert.equal(await request,false);await tick();f.audio.update();f.voices.update();assert.equal(f.nodes.length,0);f.voices.dispose();assert.equal(f.audio.streams.size,0);}
});

test('caption failures do not suppress voice playback; remote players and NPC sizes use native priorities',async()=>{
 const f=setup({caption:()=>{throw Error('Missing caption string');}});await f.voices.receive({kind:'quick-chat',objectId:f.actor.id,quickChat:0});await tick();f.audio.update();assert.equal(f.nodes.length,1);assert.ok(f.diagnostics.some(d=>d.code==='network.voice-caption-failed'));
 f.world.localObjectId=0xfffffffe;f.world.players.set(2,{objectId:f.actor.id});await f.voices.bark(f.actor.id,0);assert.equal(f.voices.actors.get(f.actor.id).sound.profile.priority,7);f.world.players.clear();await f.voices.bark(f.actor.id,0);assert.equal(f.voices.actors.get(f.actor.id).sound.profile.priority,15);f.voices.appearance=parse2da('2DA V2.0\n\nSIZECATEGORY\n0 4\n');await f.voices.bark(f.actor.id,0);assert.equal(f.voices.actors.get(f.actor.id).sound.profile.priority,14);f.voices.dispose();
});

test('server26/1 voice envelope consumes canonical OBJECT_ID and BYTE and rejects truncations',()=>{
 const w=new NativeMessageWriter(1);w.create(5,0xffffffff,1);w.writeObjectIdClient(0xffffffff);w.writeByte(255);w.setPrefix(Uint8Array.of(80,26,1));const packet=w.getWriteMessage().data;assert.deepEqual(decodeServerGameMessage(packet),{kind:'voice-play',major:26,minor:1,objectId:0xffffffff,voiceCode:255});for(let n=3;n<packet.length;n++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,n)));assert.equal(decodeServerGameMessage(Uint8Array.of(80,26,2)).kind,'unsupported');
});

test('voice and quick-chat decoders match120 original writer and voice-receiver cases',()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-voice-wire.json',import.meta.url)));assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(native.cases.length,120);
 for(const row of native.cases){const c=row.case;if(c.kind==='voice')assert.deepEqual(row.calls.at(-1),['voice',c.code&255,1]);if(c.format!==1)continue;const message=decodeServerGameMessage(Buffer.from(row.packet,'hex')),lookup=native.cases.find(r=>r.case.kind==='voice'&&r.case.source===c.source&&r.case.code===c.code&&r.case.format===c.format).calls[0][1];
  assert.equal(message.objectId,lookup);if(c.kind==='voice')assert.deepEqual(message,{kind:'voice-play',major:26,minor:1,objectId:lookup,voiceCode:c.code&255});else assert.deepEqual(message,{kind:'quick-chat',major:22,minor:0,objectId:lookup,quickChat:c.code&65535});}
});
