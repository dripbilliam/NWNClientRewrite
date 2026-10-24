import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeDelayedSounds,nativeSoundDelayDue} from '../src/native_delayed_sound.js';
import {GameAudio} from '../src/game_audio.js';
import {nativeOneShotSoundCue} from '../src/native_audio.js';
test('delay expiration matches248 original setter/bounded render cases including zero and uint32 wrap',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-sound-delay-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,248);
 for(const row of oracle.cases){const c=row.case;if(row.kind==='due')assert.equal(nativeSoundDelayDue(c.now,c.start,c.delay),row.due,JSON.stringify(c));else if(c.enabled){assert.deepEqual(row.state,{delay:c.delay,start:c.start,status:3,listed:true});assert.deepEqual(row.calls,c.oneShot?[['timer'],['head']]:[['warning'],['timer'],['head']]);}else assert.deepEqual(row.state,{delay:0,start:0,status:0,listed:false});}
});
test('delayed native queue preserves head insertion and discards stale scopes before playback',()=>{
 let now=1000,current=true;const played=[],queue=new NativeDelayedSounds({now:()=>now,play:e=>played.push(e.resRef)}),cue=resRef=>({resRef,current:()=>current,nativeSource:{priority:13}});queue.add(cue('old'),229);queue.add(cue('new'),229);now=1228;queue.update();assert.deepEqual(played,[]);now=1229;queue.update();assert.deepEqual(played,['new','old']);queue.add(cue('stale'),100);current=false;queue.update();assert.deepEqual(queue.snapshot(),[]);queue.add(cue('cleared'),100);queue.clear();assert.deepEqual(queue.snapshot(),[]);
});
test('GameAudio delays resource demand, captures native cue state and cannot resurrect stale or disposed sounds',async()=>{
 let now=0,current=true,reads=0,starts=0;const node=()=>({connect(){},disconnect(){}}),ctx={state:'running',destination:{},addEventListener(){},close:async()=>{},decodeAudioData:async()=>({numberOfChannels:1,duration:1,sampleRate:44100}),createGain:()=>({...node(),gain:{value:0}}),createBufferSource:()=>({...node(),addEventListener(){},start(){starts++;},stop(){}})},audio=new GameAudio({getResource:async()=>{reads++;return new ArrayBuffer(1);}},{getObject:()=>null,getPlayer:()=>null,createContext:()=>ctx,milliseconds:()=>now});
 const event={...nativeOneShotSoundCue({resRef:'swing',delay:229,priority:13}),objectId:7,current:()=>current};await audio.play(event);event.resRef='mutated';assert.equal(reads,0);assert.equal(audio.delayedSounds()[0].resRef,'swing');now=228;audio.update();assert.equal(reads,0);now=229;audio.update();await new Promise(r=>setImmediate(r));assert.equal(reads,1);assert.equal(starts,1);assert.equal(audio.state.last.resRef,'swing');assert.deepEqual(audio.delayedSounds(),[]);
 await audio.play({...event,resRef:'stale'});current=false;now=1000;audio.update();assert.equal(reads,1);current=true;await audio.play({...event,resRef:'disposed'});audio.dispose();now=2000;audio.update();assert.equal(reads,1);assert.deepEqual(audio.delayedSounds(),[]);
});
