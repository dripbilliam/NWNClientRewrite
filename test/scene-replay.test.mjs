import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
import {PerspectiveCamera,Vector3} from 'three';
import {SceneCapture} from '../electron/scene_capture.mjs';import {SceneReplay} from '../electron/scene_replay.mjs';import {SceneReplayRequests} from '../electron/scene_replay_requests.mjs';
import {SceneCaptureSupplement} from '../electron/scene_capture_supplement.mjs';
import {SceneReplayCamera} from '../scripts/performance-candidates/scene-replay-camera.mjs';import {transformSceneReplay} from '../scripts/performance-queue/scene-replay-transform.mjs';
const view=(x=0)=>({areaId:0x80000001,position:[x,2,3],target:[x,0,0],quaternion:[0,0,0,1],buffer:[800,600],fov:45,near:.1,far:500});
async function fixture(work,{bootstrap=true}={}){
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-scene-replay-test-'));let clock=0;
 const capture=new SceneCapture({directory,now:()=>clock}),context=capture.contextFor({});
 try{
  if(bootstrap)capture.event(context,{kind:'state',state:{phase:'connecting',resourcesReady:false}});
  clock=5;capture.message(context,{message:{kind:'module-time',changes:{hour:3},data:new Float32Array([2.5])},areaGeneration:0});
  clock=10;capture.event(context,{kind:'state',state:{phase:'playing',resourcesReady:true}});capture.view(context,view());
  capture.resource(context,'model',2002,new Uint8Array([7,8]));capture.resource(context,'bitmap',3,new Uint8Array([4]));capture.texture(context,'bitmap',3);capture.miss(context,'missing',3,'RESOURCE_NOT_FOUND');
  const sealed=await capture.close();await work(sealed.directory);
 }finally{
  await capture.close();const real=await fs.realpath(directory);assert.equal(path.dirname(real).toLowerCase(),(await fs.realpath(os.tmpdir())).toLowerCase());assert.ok(path.basename(real).startsWith('nwn-scene-replay-test-'));await fs.rm(real,{recursive:true,force:true});
 }
}
test('replay retains arrival timing, typed arrays and owned message copies without waiting for consumer work',async()=>fixture(async directory=>{
 const replay=await SceneReplay.open(directory),got=[];
 assert.equal(replay.advance(0,e=>got.push(e)),false);assert.equal(got[0].state.phase,'connecting');
 assert.equal(replay.advance(4,e=>got.push(e)),false);assert.equal(got.length,1);
 replay.advance(5,e=>{got.push(e);e.message.changes.hour=99;return new Promise(()=>{});});
 assert.equal(got[1].sessionId,'replay-context-1');assert.ok(got[1].message.data instanceof Float32Array);assert.equal(replay.records[1].event.message.changes.hour,3);
 assert.equal(replay.advance(10,e=>got.push(e)),true);assert.equal(got.length,3);assert.equal(got[2].state.phase,'playing');assert.throws(()=>replay.advance(9,()=>{}),/monotonically/);
}));
test('bootstrap omissions and checksum damage are rejected before any replay dispatch',async()=>{
 await fixture(async directory=>{await assert.rejects(SceneReplay.open(directory),/bootstrap/);},{bootstrap:false});
 await fixture(async directory=>{const file=path.join(directory,'events.bin'),bytes=await fs.readFile(file);bytes[bytes.length-1]^=1;await fs.writeFile(file,bytes);await assert.rejects(SceneReplay.open(directory));});
});
test('replay resources preserve expected misses, reject uncaptured reads and never share caller buffers',async()=>fixture(async directory=>{
 const replay=await SceneReplay.open(directory),requests=new SceneReplayRequests(replay),id='replay-context-1';
 replay.advance(0,()=>{});await assert.rejects(requests.request('resource',[id,'not-yet-requestable',3]),/unavailable at this point/);assert.equal(replay.archive.unrecorded.size,0);replay.advance(10,()=>{});
 const first=await requests.request('resource',[id,'model',2002]);new Uint8Array(first)[0]=99;assert.deepEqual(new Uint8Array(await requests.request('resource',[id,'model',2002])),new Uint8Array([7,8]));
 assert.equal((await requests.request('texture',[id,'bitmap'])).type,3);
 await assert.rejects(requests.request('resource',[id,'missing',3]),e=>e.code==='RESOURCE_NOT_FOUND');await assert.rejects(requests.request('resource',[id,'uncaptured',3]),e=>e.code==='CAPTURE_MISSING');assert.equal(replay.archive.unrecorded.size,1);
 await assert.rejects(requests.request('resource',['wrong-owner','model',2002]),/session/);
 await assert.rejects(requests.request('action',['connect',{host:'should-never-resolve'}]),e=>e.code==='REPLAY_READ_ONLY');assert.equal(replay.rejectedActions.get('connect'),1);
 assert.equal(await requests.request('area-ready',[id,1]),true);assert.equal(replay.acknowledgements.length,1);
}));
test('missing text stays a failed completeness gate even in explicitly exploratory rendering',async()=>fixture(async directory=>{
 const replay=await SceneReplay.open(directory),strict=new SceneReplayRequests(replay),exploratory=new SceneReplayRequests(replay,{allowTextGaps:true}),args=['replay-context-1',42,0];
 replay.advance(10,()=>{});
 await assert.rejects(strict.request('talk',args),e=>e.code==='CAPTURE_MISSING');assert.equal((await exploratory.request('talk',args)).text,'[Unrecorded string 42]');assert.equal(exploratory.textGaps.size,1);
 await assert.rejects(exploratory.request('audio',['replay-context-1','uncaptured',4]),e=>e.code==='CAPTURE_MISSING');assert.equal(replay.archive.unrecorded.size,1);
}));
test('recorded camera interpolation holds final pose, respects areas and takes quaternion shortest path',()=>{
 const a=view(),b=view(10);b.quaternion=[0,0,0,-1];const controller=new SceneReplayCamera([{at:100,view:a},{at:200,view:b}]),camera=new PerspectiveCamera(),controls={target:new Vector3()};
 assert.equal(controller.apply(50,0x80000002,camera,controls),false);
 controller.apply(150,a.areaId,camera,controls);assert.equal(camera.position.x,5);assert.equal(controls.target.x,5);assert.ok(Math.abs(camera.quaternion.w)>.999);
 controller.apply(300,a.areaId,camera,controls);assert.equal(camera.position.x,10);assert.throws(()=>controller.apply(299,a.areaId,camera,controls),/backwards/);
});
test('isolated renderer transform overrides camera before lighting without changing production source',async()=>{
 const source=await fs.readFile(new URL('../src/main.js',import.meta.url),'utf8'),result=transformSceneReplay(source);assert.ok(result.code.includes('window.sceneReplayForTest='));
 assert.ok(result.code.indexOf('if(Number.isFinite(qaReplayStarted))')<result.code.indexOf('const cameraAndAudioUpdated=performance.now()'));assert.ok(!source.includes('qaReplayCamera'));assert.throws(()=>transformSceneReplay(source.replace('const cameraAndAudioUpdated=performance.now();','')),/hook drift/);
});
function talkTable(text){const raw=Buffer.from(text,'latin1'),bytes=Buffer.alloc(60+raw.length);bytes.write('TLK V3.0',0,'ascii');bytes.writeUInt32LE(1,12);bytes.writeUInt32LE(60,16);bytes.writeUInt32LE(7,20);bytes.write('sound',24,'ascii');bytes.writeUInt32LE(raw.length,52);bytes.writeUInt32LE(0x3f800000,56);raw.copy(bytes,60);return bytes;}
test('a frozen supplement resolves gaps without replacing captured keys or expected misses, and resolves base/custom TLK records',async()=>fixture(async directory=>{
 const replay=await SceneReplay.open(directory),capture=new SceneCapture({directory:path.dirname(directory)}),id='context-1';
 try{
  capture.resource(id,'model',2002,new Uint8Array([99]));capture.resource(id,'missing',3,new Uint8Array([99]));capture.resource(id,'additional',3,new Uint8Array([5]));capture.texture(id,'additional',3);capture.resource(id,'music',8,new Uint8Array([6]));capture.resource(id,'__talk_main',2018,talkTable('Base'));capture.resource(id,'__talk_custom',2018,talkTable('Custom'));
  const sealed=await capture.close();await fs.writeFile(path.join(sealed.directory,'source.json'),JSON.stringify({version:1,parentEventsSha256:replay.archive.manifest.eventsSha256}));
  const supplement=await SceneCaptureSupplement.open(sealed.directory,replay.archive);replay.archive=SceneCaptureSupplement.combine(replay.archive,[supplement]);replay.advance(10,()=>{});const requests=new SceneReplayRequests(replay),session='replay-context-1';
  assert.deepEqual(new Uint8Array(await requests.request('resource',[session,'model',2002])),new Uint8Array([7,8]));await assert.rejects(requests.request('resource',[session,'missing',3]),e=>e.code==='RESOURCE_NOT_FOUND');
  assert.deepEqual(new Uint8Array((await requests.request('texture',[session,'additional'])).bytes),new Uint8Array([5]));assert.equal((await requests.request('audio',[session,'music',4])).type,8);
  assert.deepEqual(await requests.request('talk',[session,0,0]),{status:1,text:'Base',sound:'sound',durationBits:0x3f800000,gender:0});assert.equal((await requests.request('talk',[session,0x01000000,0])).text,'Custom');assert.equal(requests.textGaps.size,0);
  assert.equal(replay.archive.unrecorded.size,0);assert.ok(replay.archive.supplementHits.has('context-1:additional:texture'));
  const foreign=await SceneReplay.open(directory);foreign.archive.manifest.eventsSha256='f'.repeat(64);await assert.rejects(SceneCaptureSupplement.open(sealed.directory,foreign.archive),/another scene/);
 }finally{await capture.close();}
}));
