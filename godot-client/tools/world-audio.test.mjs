import {test} from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';
import {WorldAudio,worldAudioChannels} from './world-audio.mjs';import {voiceWave} from './native-audio-fixture.mjs';import {isolateAudio} from './isolate-audio.mjs';import {SilentAudio} from './silent-audio.mjs';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(){
 const actor={id:1,objectType:5,areaId:7,replicated:{position:[1,2,3]}},world={areaId:7,registry:new Map([[1,actor]])},session={world,areaGeneration:2},sent=[],report={},diagnostics=[];let ready=true,reads=0;
 const scope=()=>ready?{connection:1,areaId:7,generation:session.areaGeneration,transferId:3}:null;
 const owner=new WorldAudio({session,connection:1,active:()=>true,ready:scope,getResource:async()=>{reads++;return voiceWave();},send:value=>sent.push(value),diagnose:(...args)=>diagnostics.push(args),report});
 return{owner,world,actor,session,sent,report,diagnostics,ready:v=>ready=v,reads:()=>reads,request:(resourceId=1,name='sample')=>({...scope(),resourceId,name})};
}
test('world sound resources retain original bytes/channels and share bounded cached preparation without writing audio assets',async()=>{
 const f=fixture();await f.owner.request(f.request());await f.owner.request(f.request(2));assert.equal(f.reads(),1);
 assert.deepEqual(f.sent.map(v=>v.kind),['world-audio-begin','world-audio-chunk','world-audio-commit','world-audio-begin','world-audio-chunk','world-audio-commit']);
 const start=f.sent[0];assert.equal(start.channels,1);assert.equal(start.codec,'pcm16');assert.equal(start.name,'sample');assert.equal(start.connection,1);assert.equal(start.transferId,3);assert.equal(f.report.resources.length,2);
 await f.owner.close();assert.equal(f.report.pending,0);assert.equal(f.report.scopes[0].cachedBytes,0);assert.equal(f.report.scopes[0].closed,true);
});
test('late audio IO is retired on area/world/ticket replacement and cannot cross native ownership boundaries',async()=>{
 for(const retire of[f=>f.session.areaGeneration++,f=>f.session.world={...f.world},f=>{f.ready(false);f.session.areaGeneration++;},f=>f.session.closed=true]){
  const f=fixture();let resolve;f.owner.getResource=()=>new Promise(r=>resolve=r);const work=f.owner.request(f.request());await turn();retire(f);f.owner.follow();resolve(voiceWave());await work;assert.equal(f.sent.length,0);await f.owner.close();assert.equal(f.report.pending,0);assert.ok(f.report.scopes.every(v=>v.closed&&v.cachedBytes===0));
 }
});
test('audio IDs are immutable per world; malformed/stale names and scope do not perform resource IO',async()=>{
 const f=fixture();await f.owner.request({...f.request(),transferId:2});assert.equal(f.reads(),0);await assert.rejects(f.owner.request(f.request(1,'../bad')),/resource/);await f.owner.request(f.request());await assert.rejects(f.owner.request(f.request(1,'different')),/immutable/);await f.owner.close();
});
test('original script sound source gates use canonical proxies and send fixed original positions without mutating gameplay',async()=>{
 const f=fixture(),before=structuredClone([...f.world.registry]);f.owner.receive({kind:'script-sound',objectId:1,sound:'original'});const cue=f.sent.at(-1);
 assert.equal(cue.kind,'world-audio-cue');assert.deepEqual(cue.cue.position,[1,2,3]);assert.equal(cue.cue.nativeSource.priority,8);assert.equal(cue.cue.nativeSource.volume,127);assert.equal(cue.cue.nativeSource.fixedPosition,true);assert.deepEqual([...f.world.registry],before);
 f.owner.receive({kind:'script-sound',objectId:0x7f000000,sound:'missing'});f.actor.replicationRemoved=true;f.owner.receive({kind:'script-sound',objectId:1,sound:'removed'});assert.equal(f.sent.length,1);await f.owner.close();
});
test('world format channel identification preserves PCM/BMU mono-stereo rules and rejects unknown compressed metadata',()=>{
 assert.equal(worldAudioChannels({channels:2}),2);assert.equal(worldAudioChannels({codec:'mp3',sourceTiming:{channels:1}}),1);
 const frame=Buffer.alloc(417);frame.writeUInt32BE(0xfffb90c0);assert.equal(worldAudioChannels({codec:'mp3',data:Buffer.concat([frame,frame])}),1);
 frame.writeUInt32BE(0xfffb9000);assert.equal(worldAudioChannels({codec:'mp3',data:Buffer.concat([frame,frame])}),2);
 assert.throws(()=>worldAudioChannels({codec:'mp3',data:Buffer.from('ID3invalid')}));assert.throws(()=>worldAudioChannels({codec:'ogg',data:Buffer.from('OggSinvalid')}));
});
test('isolated browser resource staging cannot create an AudioContext or duplicate native world playback',async()=>{
 const original=await fs.readFile('src/main.js','utf8'),changed=isolateAudio(original);assert.ok(changed.includes('networkGuiAudio=new SilentAudio('));assert.ok(changed.includes('onAudio:_message=>{},'));assert.throws(()=>isolateAudio(changed),/boundary/);assert.equal(await fs.readFile('src/main.js','utf8'),original);
 let contexts=0;const audio=new SilentAudio({}, {createContext:()=>{contexts++;throw Error('Unexpected AudioContext');}});await audio.unlock();await audio.play({resRef:'anything'});assert.equal(await audio.loadBuffer('anything'),null);assert.equal(audio.effectSound({}),null);audio.dispose();assert.equal(contexts,0);
});
