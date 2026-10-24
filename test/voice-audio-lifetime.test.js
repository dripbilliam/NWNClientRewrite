import test from 'node:test';
import assert from 'node:assert/strict';
import {GameAudio} from '../src/game_audio.js';
function context(){
 const sources=[],node=()=>({positionX:{value:0},positionY:{value:0},positionZ:{value:0},connect(){},disconnect(){}}),ctx={state:'suspended',destination:{},listener:node(),sources,
  addEventListener(){},resume:async()=>{ctx.state='running';},close:async()=>{},decodeAudioData:async()=>({numberOfChannels:1,sampleRate:22050,duration:1}),createPanner:node,
  createBufferSource:()=>{const listeners=new Map(),source={connect(){},disconnect(){},addEventListener:(k,fn)=>listeners.set(k,fn),started:0,stopped:0,
   start(){this.started++;},stop(){this.stopped++;listeners.get('ended')?.();}};sources.push(source);return source;}};return ctx;
}
test('voice output starts on the first unlock and replaces only its canonical actor voice channel',async()=>{
 const actor={id:99,position:[0,0,0]},objects=new Map([[99,actor]]),ctx=context(),audio=new GameAudio({getResource:async()=>new ArrayBuffer(1)},{getObject:id=>objects.get(id),getPlayer:()=>actor,createContext:()=>ctx});
 await audio.unlock();assert.equal(ctx.state,'running');
 const event={objectId:99,position:[0,0,0],resRef:'first',channel:'voice',replace:true};await audio.play(event);await audio.play({...event,resRef:'second'});
 assert.equal(ctx.sources[0].stopped,1);assert.equal(audio.active.size,1);
 await audio.play({objectId:99,position:[0,0,0],resRef:'effect'});assert.equal(audio.active.size,2);
 objects.delete(99);audio.update();assert.equal(audio.active.size,1);assert.equal(ctx.sources[1].stopped,1);assert.equal(ctx.sources[2].stopped,0);audio.dispose();
});
test('slow voice decoding cannot resurrect an older cue or an already destroyed actor',async()=>{
 let slowResolve,deadResolve;const slow=new Promise(r=>slowResolve=r),dead=new Promise(r=>deadResolve=r),actor={id:99,position:[0,0,0]},objects=new Map([[99,actor]]),ctx=context(),
  audio=new GameAudio({getResource:ref=>ref==='slow'?slow:ref==='dead'?dead:Promise.resolve(new ArrayBuffer(1))},{getObject:id=>objects.get(id),getPlayer:()=>actor,createContext:()=>ctx});
 await audio.unlock();const e={objectId:99,position:[0,0,0],channel:'voice',replace:true},old=audio.play({...e,resRef:'slow'});
 await audio.play({...e,resRef:'fast'});slowResolve(new ArrayBuffer(1));await old;assert.equal(audio.state.played,1);assert.equal(audio.state.last.resRef,'fast');
 const pending=audio.play({...e,resRef:'dead'});objects.delete(99);deadResolve(new ArrayBuffer(1));await pending;assert.equal(audio.state.played,1);audio.update();assert.equal(audio.active.size,0);audio.dispose();
});

test('a GUI cue queued before character admission stays centered after the player ID changes',async()=>{
 let player={id:0x7f000000};const ctx=context(),audio=new GameAudio({getResource:async()=>new ArrayBuffer(1)},{getObject:()=>null,getPlayer:()=>player,createContext:()=>ctx});
 await audio.play({objectId:player.id,resRef:'gui_journaladd',channel:'gui'});assert.equal(audio.pending.length,1);player={id:0xfffffffd,position:[8,9,0]};
 await audio.unlock();assert.equal(audio.state.played,1);assert.equal(audio.active.size,1);assert.equal([...audio.active][0].panner,undefined);assert.doesNotThrow(()=>audio.update());audio.dispose();
});
