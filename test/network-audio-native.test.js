import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {nativeAudioListener,nativeAudioResRef,nativeScriptSoundCue,nativeOneShotSoundCue,NetworkAudioPresentation} from '../src/native_audio.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {decodeGffText,encodeGffText} from '../src/gff_text.js';
import {GameAudio} from '../src/game_audio.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkFrontend} from '../src/network_frontend.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-audio-observations.json',import.meta.url)));
const bits=n=>{const b=Buffer.alloc(4);b.writeFloatLE(n);return b.toString('hex');};
test('native9/7 writer packets are sound commands, never chat, with exact canonical source IDs',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,218);
 for(const c of oracle.cases.filter(c=>c.kind==='wire'&&c.format===1))for(const hex of c.packets){
  const packet=Buffer.from(hex,'hex'),decoded=decodeServerGameMessage(packet);
  assert.equal(decoded.kind,'script-sound');assert.equal(decoded.sound,decodeGffText(Buffer.from(c.textHex,'hex')));assert.equal(decoded.objectId,c.objectId===0x7f000000?c.objectId:(c.objectId|0x80000000)>>>0);assert.equal(decoded.text,undefined);
  for(let n=3;n<packet.length;n++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,n)));
  assert.throws(()=>decodeServerGameMessage(Buffer.concat([packet,Buffer.of(0,0)])));
 }
});
test('bounded original client branch preserves16-byte case-sensitive ResRef, position, priority8 and zero delay',()=>{
 for(const c of oracle.cases.filter(c=>c.kind==='client-branch')){
  const text=decodeGffText(Buffer.from(c.textHex,'hex')),native=c.calls[0],ref=nativeAudioResRef(text),cue=nativeScriptSoundCue(text,c.positional?c.position:null);
  assert.equal(Buffer.from(encodeGffText(ref)).toString('hex'),native.resRefHex);
  if(!ref){assert.equal(cue,null);continue;}
  assert.equal(cue.resRef,ref);assert.deepEqual(cue.position??null,native.position);assert.equal(cue.nativeSource.positional,native.positional);assert.equal(cue.nativeSource.priority,native.priority);assert.equal(native.delay,0);assert.equal(native.volume,0);assert.equal(cue.nativeSource.volume,127);
 }
});
test('complete original listener coordinator matches float32 position and quaternion orientation, including missing scene gates',()=>{
 for(const {case:c,calls}of oracle.cases.filter(c=>c.kind==='listener')){
  const actual=nativeAudioListener(c.actor?c.player:null,c.scene&&c.hasCamera?c.camera:null,c.quaternion);
  if(!calls.length){assert.equal(actual,null);continue;}
  for(const [key,expected]of [['position',calls[0].value],['forward',calls[1].forward],['up',calls[1].up]])assert.deepEqual(actual[key].map(bits),expected.map(bits),JSON.stringify(c)+' '+key);
 }
});
test('complete original3D wrapper adds native height and preserves caller-selected priorities and optional volume',()=>{
 for(const c of oracle.cases.filter(c=>c.kind==='wrapper')){
  const cue=nativeOneShotSoundCue({resRef:'generic_sound',position:c.position,height:c.height,priority:c.priority,volume:c.volume}),native=c.calls[0];
  assert.deepEqual(cue.position.map(bits),native.position.map(bits));assert.equal(cue.nativeSource.priority,native.priority);assert.equal(cue.nativeSource.volume,native.volume||127);
 }
 assert.equal(nativeOneShotSoundCue({resRef:'cue',delay:1}).nativeSource.delay,1);assert.throws(()=>nativeOneShotSoundCue({resRef:'cue',delay:-1}));assert.throws(()=>nativeAudioResRef(undefined));
});
function context(){
 const sources=[],gains=[],panners=[],axis=()=>({value:0}),node=()=>({connect(){},disconnect(){this.disconnected=true;}}),listener=Object.fromEntries(['position','forward','up'].flatMap(prefix=>[...'XYZ'].map(a=>[prefix+a,axis()])));
 const ctx={state:'running',destination:{},listener,sources,gains,panners,channels:1,addEventListener(){},async resume(){ctx.state='running';},async close(){ctx.state='closed';},async decodeAudioData(){return{numberOfChannels:ctx.channels,sampleRate:22050,duration:.1};},createGain(){const gain={...node(),gain:axis()};gains.push(gain);return gain;},createPanner(){const panner={...node(),...Object.fromEntries([...'XYZ'].map(a=>['position'+a,axis()]))};panners.push(panner);return panner;},createBufferSource(){const handlers={},source={...node(),addEventListener:(k,fn)=>handlers[k]=fn,start(){this.started=true;},stop(){this.stopped=true;handlers.ended?.();}};sources.push(source);return source;}};return ctx;
}
test('native one-shots use explicit positional self-cues, source gain, linear range, fixed origin and listener orientation',async()=>{
 const ctx=context(),actor={id:0xffffffff,position:[0,0,0]},audio=new GameAudio({getResource:async()=>new ArrayBuffer(1)},{getObject:()=>actor,getPlayer:()=>actor,getListener:()=>nativeAudioListener([0,0,0],[0,0,0],[1,0,0,0]),createContext:()=>ctx});
 const cue={...nativeScriptSoundCue('self',[3,4,0]),objectId:actor.id};await audio.play(cue);
 assert.equal(audio.state.played,1);assert.equal(ctx.panners.length,1);assert.equal(ctx.gains[0].gain.value,Math.fround(127/255));assert.equal(ctx.panners[0].distanceModel,'linear');assert.equal(ctx.panners[0].maxDistance,20);assert.equal(ctx.panners[0].refDistance,1);
 actor.position=[9,9,9];audio.update();assert.deepEqual(['X','Y','Z'].map(a=>ctx.panners[0]['position'+a].value),[3,4,0]);assert.equal(ctx.listener.upY.value,1);assert.equal(ctx.listener.forwardZ.value,-1);
 await audio.play({...nativeScriptSoundCue('far',[0,0,50]),objectId:2});assert.equal(audio.state.played,1);
 ctx.channels=2;await audio.play({...nativeScriptSoundCue('stereo',[0,0,0]),objectId:2});assert.equal(audio.state.played,1);
 await audio.play({...nativeScriptSoundCue('centered'),objectId:2});assert.equal(audio.state.played,2);assert.equal(ctx.panners.length,1);assert.equal(ctx.gains.at(-1).gain.value,1);
 audio.dispose();assert.ok(ctx.sources.every(s=>s.stopped));assert.ok(ctx.gains.every(g=>g.disconnected));
});
test('audio scope cancellation rejects delayed and suspended cues from an old area or disconnected session',async()=>{
 let release;const resource=new Promise(resolve=>release=resolve),ctx=context(),world=new NetworkWorld();world.areaId=0x80000004;world.registry.addObjectAtPos(0xffffffff,{objectType:5,areaId:world.areaId,replicated:{position:[0,0,0]}});
 const output=new GameAudio({getResource:()=>resource},{getObject:id=>world.registry.get(id),getPlayer:()=>({id:0xffffffff}),getListener:()=>nativeAudioListener([0,0,0],[0,0,0],[1,0,0,0]),createContext:()=>ctx}),sound=new NetworkAudioPresentation({world:()=>world,output});
 sound.receive({kind:'script-sound',objectId:0xffffffff,sound:'slow'});sound.areaChanged();release(new ArrayBuffer(1));await output.cache.get('slow');await new Promise(resolve=>setImmediate(resolve));assert.equal(output.state.played,0);
 ctx.state='suspended';sound.receive({kind:'script-sound',objectId:0xffffffff,sound:'pending'});await new Promise(resolve=>setImmediate(resolve));assert.equal(output.pending.length,1);sound.areaChanged();await output.unlock();assert.equal(output.state.played,0);assert.equal(output.pending.length,0);
 sound.dispose();output.dispose();assert.equal(output.active.size,0);
});
test('production frontend routes sound separately from chat without constructing or changing canonical objects',async()=>{
 const world=new NetworkWorld();world.areaId=0x80000004;world.registry.addObjectAtPos(0xffffffff,{objectType:5,areaId:world.areaId,replicated:{position:[1,2,3]}});const before=JSON.stringify([...world.registry.objects]),played=[],reports=[],sound=new NetworkAudioPresentation({world:()=>world,output:{play:cue=>played.push(cue)},report:code=>reports.push(code)}),front={id:3,world,queue:Promise.resolve(),onAudio:message=>sound.receive(message),onHud:()=>{throw new Error('Sound must never become a chat row');},showError:error=>{throw error;}};
 NetworkFrontend.prototype.receive.call(front,{sessionId:3,kind:'message',message:{kind:'script-sound',objectId:0xffffffff,sound:'authoritative'}});await front.queue;assert.equal(played.length,1);assert.deepEqual(played[0].position,[1,2,3]);assert.equal(played[0].objectId,0xffffffff);
 for(const id of [0x7f000000,0x80000123])sound.receive({kind:'script-sound',objectId:id,sound:'missing'});assert.equal(played.length,1);assert.equal(JSON.stringify([...world.registry.objects]),before);assert.deepEqual(reports,['network.audio-mixer-settings-unimplemented']);
});
