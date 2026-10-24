import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {StreamingAudio,streamingAudioPayload} from '../src/streaming_audio.js';
import {NetworkAmbientPresentation,resolveAmbientTrack} from '../src/network_ambient_presentation.js';
import {NetworkFrontend} from '../src/network_frontend.js';
import {NetworkWorld} from '../src/network_world.js';
import {NativeAmbientOwner} from '../src/native_ambient.js';
import {parse2da} from '../src/area.js';
const tick=()=>new Promise(resolve=>setImmediate(resolve));
const bmu=()=>Buffer.concat([Buffer.from('BMU V1.0'),Buffer.from([0x49,0x44,0x33,1])]);
function output(){
 const gain={value:0,cancelScheduledValues(){},setValueAtTime(v){this.value=v;},linearRampToValueAtTime(v,end){this.target=v;this.end=end;}};
 const ctx={state:'running',currentTime:0,destination:{},createGain:()=>({gain,connect(){},disconnect(){this.disconnected=true;}}),createMediaElementSource:()=>({connect(){},disconnect(){this.disconnected=true;}})};
 return{streams:new Set(),context:ctx,ensureContext:()=>ctx};
}
function streamOptions(extra={}){return{getResource:async()=>({type:8,bytes:bmu()}),createMedia:()=>({loop:false,handlers:{},addEventListener(k,f){this.handlers[k]=f;},play:async()=>{},pause(){this.paused=true;},removeAttribute(){},load(){}}),createUrl:()=> 'blob:owned-fixture',revokeUrl(){},...extra};}
test('installed audio type preference includes archives and bounded loose inventory without permitting server paths',async()=>{
 const tmpRoot=path.resolve(os.tmpdir()),dir=await fs.mkdtemp(path.join(tmpRoot,'nwn-owned-audio-'));
 try{
  const mus=path.join(dir,'data/mus'),amb=path.join(dir,'data/amb');await fs.mkdir(mus,{recursive:true});await fs.mkdir(amb,{recursive:true});await fs.writeFile(path.join(mus,'CaseRef.BMU'),bmu());await fs.writeFile(path.join(amb,'CaseRef.WAV'),Buffer.of(4));
  const files=new Map(),resolver={hasResource:(ref,type)=>files.has(type),getResource:async(ref,type)=>files.get(type)},resources=installedNetworkResources({install:dir});
  let got=await resources.audioResource(resolver,'caseref',4);assert.equal(got.type,8);assert.deepEqual(Buffer.from(got.bytes),bmu());
  files.set(8,Buffer.of(8));got=await resources.audioResource(resolver,'caseref',4);assert.deepEqual(got.bytes,Buffer.of(8));
  assert.deepEqual(Buffer.from(await resources.waveResource(resolver,'caseref')),Buffer.of(4),'ordinary source WAV never selects a neighboring BMU');
  files.delete(8);files.set(4,Buffer.of(44));got=await resources.audioResource(resolver,'caseref',4);assert.equal(got.type,8,'native preferred type takes precedence even over an archive WAV');
  await assert.rejects(resources.audioResource(resolver,'other',8),/unavailable/);
  for(const [ref,type]of [['../caseref',8],['C:\\caseref',4],['a/b',4],['a'.repeat(17),8],['caseref',2002]])await assert.rejects(resources.audioResource(resolver,ref,type),/Invalid/);
 }finally{const absolute=path.resolve(dir);assert.ok(absolute.startsWith(tmpRoot+path.sep)&&path.basename(absolute).startsWith('nwn-owned-audio-'));await fs.rm(absolute,{recursive:true,force:true});}
});
test('BMU adapter strips only the native header and leaves encoded data for the streaming decoder',()=>{
 assert.deepEqual([...streamingAudioPayload(bmu(),8).bytes],[0x49,0x44,0x33,1]);assert.equal(streamingAudioPayload(bmu(),8).mime,'audio/mpeg');assert.throws(()=>streamingAudioPayload(Buffer.of(1,2,3),8),/BMU/);assert.throws(()=>streamingAudioPayload(bmu(),2002));
});
test('streaming adapter cancels stale resources, queues suspended output, preserves fade and releases every owned URL/node',async()=>{
 const audio=output();let release;const pending=new Promise(resolve=>release=resolve),revoked=[];
 const stream=new StreamingAudio(audio,streamOptions({getResource:()=>pending,revokeUrl:url=>revoked.push(url)}));assert.equal(stream.play('OldTrack',8),1);stream.stop();release({type:8,bytes:bmu()});await tick();assert.equal(stream.loaded,0);
 audio.context.state='suspended';stream.play('NewTrack',8);await tick();assert.equal(stream.status,'queued');assert.equal(stream.isPlaying(),true);assert.equal(stream.started,0);stream.setVolume(48);assert.equal(stream.gain.gain.value,Math.fround(48/127));audio.context.state='running';stream.flush();await tick();assert.equal(stream.status,'playing');assert.equal(stream.file(),'newtrack');assert.equal(stream.started,1);
 stream.fadeAndStop(800);assert.equal(stream.status,'fading');assert.equal(stream.fade.end,.8);stream.fadeAndStop(10000);assert.equal(stream.fade.end,.8,'native ignores replacement fade while already fading');audio.context.currentTime=.81;stream.update();assert.equal(stream.isPlaying(),false);assert.deepEqual(revoked,['blob:owned-fixture']);stream.dispose();assert.equal(audio.streams.size,0);
});
test('browser autoplay rejection remains pending until unlock, decoder failure reports and old callbacks cannot revive a disposed stream',async()=>{
 const audio=output(),reports=[];let permitted=false;
 const stream=new StreamingAudio(audio,streamOptions({onFailure:(error,data)=>reports.push({message:error.message,...data}),createMedia:()=>({...streamOptions().createMedia(),play:async()=>{if(!permitted)throw Object.assign(new Error('gesture'),{name:'NotAllowedError'});}})}));stream.play('Track',8);await tick();assert.equal(stream.status,'queued');permitted=true;stream.flush();await tick();assert.equal(stream.started,0);stream.flush(true);await tick();assert.equal(stream.started,1);const old=stream.media;stream.dispose();old.handlers.error();assert.equal(reports.length,0);
 const failed=new StreamingAudio(audio,streamOptions({getResource:async()=>({type:8,bytes:Buffer.of(0)}),onFailure:(error,data)=>reports.push({message:error.message,...data})}));failed.play('Broken',8);await tick();assert.equal(failed.status,'failed');assert.equal(failed.isPlaying(),false);assert.equal(reports.length,1);assert.equal(reports[0].resRef,'broken');failed.dispose();
});
test('2DA resolution uses physical row indices and native empty cells, including custom row labels',()=>{
 const table=parse2da('2DA V2.0\n\nResource Stinger1 Stinger2 Stinger3\n99 custom_music sting_a **** sting_c\n7 **** **** **** ****\n');assert.deepEqual(resolveAmbientTrack(table,0,true),{resource:'CUSTOM_MUSIC',stingers:['STING_A','','STING_C']});assert.equal(resolveAmbientTrack(table,99,true).resource,'');assert.equal(resolveAmbientTrack(table,1,false).resource,'');
});
test('locale-specific resource names are diagnosed as unverified instead of expanded by Unicode casing',()=>{
 const table=parse2da('2DA V2.0\n\nResource\n0 straße\n');assert.throws(()=>resolveAmbientTrack(table,0,true),/locale-specific/);
});
test('area presentation replays server commands in order, disposes old area streams and does not await stream resources',async()=>{
 const audio=output(),streams=[],reports=[],table=Buffer.from('2DA V2.0\n\nResource Stinger1 Stinger2 Stinger3\n0 custom_track **** **** ****\n'),area=id=>({id,ambient:{'10':0,'14':0,'1c':0,'24':0,'28':0},time:{timeOfDay:3}}),createStream=(_audio,options)=>{const s={...options,playing:false,calls:[],isPlaying(){return this.playing;},file:()=>'',setVolume(v){this.calls.push(['volume',v]);},play(ref,type){this.calls.push(['play',ref,type]);this.playing=true;return 1;},fadeAndStop(v){this.calls.push(['fade',v]);},dispose(){this.disposed=true;},snapshot(){return{disposed:this.disposed};}};streams.push(s);return s;};
 let release;const pending=new Promise(resolve=>release=resolve),p=new NetworkAmbientPresentation({output:audio,getResource:()=>{throw Error('No audio IO should block attach');},report:(...r)=>reports.push(r),createStream});const old=p.attach(area(1),{getResource:()=>pending});p.receive({kind:'ambient-command',operation:2,value:90000});const next=p.attach(area(2),{getResource:async()=>table});p.receive({kind:'ambient-command',operation:2,value:12345});await next;release(table);await old;assert.equal(p.areaId,2);assert.equal(p.owner.delay,12345);assert.equal(streams.length,2);assert.deepEqual(reports.map(r=>r[0]),['network.ambient-mixer-clock-unimplemented']);p.detach();assert.ok(streams.every(s=>s.disposed));
});
test('frontend audio controls do not create chat, canonical objects or competing gameplay state',async()=>{
 const world=new NetworkWorld(),before=JSON.stringify(world.snapshot()),received=[],front={id:3,world,queue:Promise.resolve(),onAudio:m=>received.push(m),onHud:()=>{throw Error('Audio must never enter chat');},showError:e=>{throw e;}};
 NetworkFrontend.prototype.receive.call(front,{sessionId:3,kind:'message',message:{kind:'ambient-command',operation:2,value:2000}});await front.queue;assert.equal(received.length,1);assert.equal(JSON.stringify(world.snapshot()),before);assert.equal(world.registry.objects.size,0);
});
test('stream completion uses the native repeat delay while ambient failure remains latched until a track change',()=>{
 let playing=false,started=0;const stream={isPlaying:()=>playing,play(){playing=true;started++;return 1;},file:()=>'',setVolume(){},fadeAndStop(){},dispose(){}};
 const owner=new NativeAmbientOwner({state:{c:90000,'20':0},resolve:()=>({resource:'track'}),streams:{music:stream,ambient:{...stream,isPlaying:()=>true}}});owner.start();assert.equal(started,1);playing=false;owner.frame(1000);owner.frame(90999);assert.equal(started,1);owner.frame(91000);assert.equal(started,2);
});
