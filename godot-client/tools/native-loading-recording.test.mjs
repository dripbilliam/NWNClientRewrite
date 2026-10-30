import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {NativeLoadingRecording,ackKey} from './native-loading-recording.mjs';
import {selectGeneration} from './native-loading-selection.mjs';
const replay=fileURLToPath(new URL('./replay-native-loading.mjs',import.meta.url));
async function fixture(){const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-loading-timeline-test-'));await fs.mkdir(path.join(directory,'catalog-1'));await fs.writeFile(path.join(directory,'catalog-1/manifest.json'),JSON.stringify({version:2,complete:true,availability:{},resources:{}}));return directory;}
function frame(recorder,value){return recorder.frame(value,JSON.stringify(value)+'\n');}
test('native presentation timeline preserves order/acks and seals privately without recording login or outgoing commands',async()=>{
 const directory=await fixture();const r=new NativeLoadingRecording(directory);
 assert.equal(frame(r,{kind:'hello',token:'private-handshake-token'}),false);assert.equal(frame(r,{kind:'lobby',credentials:{cdKey:'private-test-marker'}}),false);assert.equal(r.acknowledgement({kind:'walk',position:[1,2,3]}),false);
 frame(r,{kind:'session-reset',connection:1});frame(r,{kind:'setup',connection:1,install:'local',recordingDirectory:path.join(directory,'catalog-1'),resourceSources:{profileDirectory:'private-profile',customTlk:{name:'custom',path:'private-path'}}});r.acknowledgement({kind:'catalog-ready',connection:1});
 frame(r,{kind:'raw-world-begin',connection:1,generation:1,serial:1,count:0,data:{}});frame(r,{kind:'raw-world-end',connection:1,generation:1,serial:1});r.acknowledgement({kind:'raw-world-accepted',connection:1,generation:1,serial:1});
 frame(r,{kind:'ui-protocol',connection:1,generation:1,message:{kind:'nui-create',token:17,credentials:{cdKey:'private-test-marker'}}});r.view({connection:1,position:[1,2,3],size:[1280,800]});r.baseline({fps:10,frame_profile:{enabled:true}});
 const done=await r.close({run:'authored',cdKey:'private-test-marker'});assert.equal(done.complete,true);assert.equal(done.events,9);assert.equal(done.catalogs.length,1);
 const text=await fs.readFile(path.join(directory,'timeline.jsonl'),'utf8');assert(!text.includes('private-test-marker'));assert(!text.includes('private-handshake-token'));assert(!text.includes('private-profile'));assert(!text.includes('private-path'));
 const rows=text.trim().split('\n').map(JSON.parse);assert.equal(rows[6].value.message.token,17);assert.equal(rows[1].value.resourceSources.recordedCatalog,'catalog-1');assert.equal(ackKey(rows[5].value),ackKey({kind:'raw-world-accepted',connection:1,generation:1,serial:1}));
 const verified=spawnSync(process.execPath,[replay,'--capture='+directory,'--verify-only'],{encoding:'utf8'});assert.equal(verified.status,0,verified.stderr);assert.equal(JSON.parse(verified.stdout).networkConnections,0);
 await fs.appendFile(path.join(directory,'timeline.jsonl'),' ');const corrupt=spawnSync(process.execPath,[replay,'--capture='+directory,'--verify-only'],{encoding:'utf8'});assert.notEqual(corrupt.status,0);assert.match(corrupt.stderr,/checksum/);
});
test('missing native resource seal and writer overflow remain explicitly incomplete',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-loading-incomplete-test-'));const r=new NativeLoadingRecording(directory);frame(r,{kind:'setup',connection:1,recordingDirectory:path.join(directory,'catalog-1'),resourceSources:{}});assert.equal((await r.close()).complete,false);
 const other=await fixture();const bounded=new NativeLoadingRecording(other,{maximumQueued:1});assert.equal(frame(bounded,{kind:'session-reset',connection:1}),false);const result=await bounded.close();assert.equal(result.complete,false);assert.match(result.failure,/bound|No native/);
});
test('one cold area starts with setup/UI state and its own full snapshot, never earlier worlds or next-generation deltas',()=>{
 const frame=(kind,generation,at,extra={})=>({kind:'frame',at,value:{kind,generation,connection:1,...extra}});
 const records=[frame('session-reset',null,0),frame('setup',null,1),frame('ui-protocol',1,2,{message:{kind:'nui-create',token:7}}),frame('ui-protocol',1,3,{message:{kind:'server-speech',text:'old chat'}}),frame('raw-world-begin',1,4,{data:{bridgeMode:'full'}}),frame('raw-world-begin',2,100,{data:{bridgeMode:'full'}}),frame('raw-world-chunk',2,101),frame('raw-world-end',2,102),{kind:'acknowledgement',at:103,value:{kind:'raw-world-accepted',connection:1,generation:2}},frame('raw-world-begin',3,200,{data:{bridgeMode:'full'}})];
 const rows=selectGeneration(records,2);assert.equal(rows[0].value.kind,'session-reset');assert.equal(rows[1].value.kind,'setup');assert.equal(rows[2].value.kind,'catalog-ready');assert.equal(rows[3].value.message.token,7);assert(!rows.some(r=>r.value.message?.kind==='server-speech'));assert(!rows.some(r=>r.value.kind==='raw-world-begin'&&r.value.generation!==2));assert.equal(rows.at(-1).value.generation,2);assert.equal(rows.at(-1).at,3);assert.throws(()=>selectGeneration(records,4),/no full entry/);
});
