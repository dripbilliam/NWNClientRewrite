import test from 'node:test';import assert from 'node:assert/strict';
import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
import {EventEmitter} from 'node:events';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {MovementTimingRecording,MovementReplayClock,movementInput,validMovementEvent} from './native-movement-recording.mjs';
import {selectGeneration} from './native-loading-selection.mjs';
const replay=fileURLToPath(new URL('./replay-native-loading.mjs',import.meta.url));
const input={kind:'drive',connection:1,generation:2,areaId:123,actorId:456,lifetime:3,requestId:7,operation:'drive',position:[1,2],heading:900,flags:3,transmit:true,movementTrace:{native_ticks_us:1000,native_frame:42,keyboard:{flags:3},state:{position:[1,2,3],render:[1,2,3]}}};
test('movement projection rejects bad requests and detaches allowed values without saving login fields',()=>{
 assert.equal(movementInput({kind:'hello',token:'private-marker'}),null);
 assert.equal(movementInput({...input,heading:3600}),null);assert.equal(movementInput({...input,flags:0}),null);
 assert.equal(movementInput({...input,connection:-1}),null);assert.equal(movementInput({...input,position:[NaN,0]}),null);
 const value=movementInput({...input,credentials:{cdKey:'private-marker'}});assert(!('credentials'in value));
 value.position[0]=99;value.movementTrace.state.render[0]=99;assert.equal(input.position[0],1);assert.equal(input.movementTrace.state.render[0],1);
});
test('capture retains bidirectional timing/drive replies, excludes authentication and preserves the peer return value',async()=>{
 const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-movement-recording-test-'));
 await fs.mkdir(path.join(directory,'catalog-1'));await fs.writeFile(path.join(directory,'catalog-1/manifest.json'),JSON.stringify({version:2,complete:true,resources:{},availability:{}}));
 const r=new MovementTimingRecording(directory),peer=new EventEmitter(),calls=[],result=Promise.resolve('sent');
 peer.sendGameMessage=function(bytes,...options){calls.push({self:this,bytes,options});return result;};
 const current={peer,phase:'character',areaGeneration:2,world:{areaId:123},closed:false};r.attach(current,1);r.attach(current,1);
 peer.emit('message',Buffer.from([80,2,1,17]));assert.equal(peer.sendGameMessage(Buffer.from([112,6,29,1])),result);
 current.phase='playing';peer.emit('message',Buffer.from([80,5,1,9]));peer.emit('message',Buffer.from([112,5,1,9]));
 assert.equal(peer.sendGameMessage(Buffer.from([112,6,29,2]),'unchanged'),result);
 peer.sendGameMessage(Buffer.from([112,2,1,18]));peer.sendGameMessage(Buffer.from([112,13,1,19]));
 assert.equal(calls.length,4);assert(calls.every(x=>x.self===peer));assert.equal(calls[1].options[0],'unchanged');assert.equal(peer.listenerCount('message'),1);
 assert.equal(r.input({...input,password:'private-marker'}),true);assert.equal(r.dispatch(input),true);
 assert.equal(r.movementSample({kind:'movement-sample',connection:1,generation:2,areaId:123,actorId:456,lifetime:3,native_ticks_us:2000,native_frame:43,state:{position:[1,2,3]},credentials:{cdKey:'private-marker'}}),true);
 r.frame({kind:'setup'},JSON.stringify({kind:'setup',connection:1,recordingDirectory:path.join(directory,'catalog-1'),resourceSources:{}}));
 for(const kind of ['drive-ack','native-clock-protocol'])assert.equal(r.frame({kind},JSON.stringify({kind,connection:1,generation:2,areaId:123})),true);
 const done=await r.close();assert.equal(done.complete,true);assert.equal(done.metadata.movementTiming,true);
 const text=await fs.readFile(path.join(directory,'timeline.jsonl'),'utf8');assert(!text.includes('private-marker'));
 const rows=text.trim().split('\n').map(JSON.parse),packets=rows.filter(r=>r.kind==='network-game-packet');
 assert.equal(packets.length,2);assert.deepEqual(packets.map(r=>r.value.direction),['received','sent']);
 for(const row of rows.filter(r=>['movement-input','movement-dispatch','movement-sample','network-game-packet'].includes(r.kind)))assert(validMovementEvent(row.kind,row.value));
 const verified=spawnSync(process.execPath,[replay,'--capture='+directory,'--verify-only'],{encoding:'utf8'});assert.equal(verified.status,0,verified.stderr);assert.equal(JSON.parse(verified.stdout).networkConnections,0);
 const bad={...packets[0].value,sha256:'0'.repeat(64)};assert.equal(validMovementEvent('network-game-packet',bad),false);
});
test('timed replay preserves network gaps after slow loading and reports later lateness',()=>{
 const clock=new MovementReplayClock(),gate={kind:'acknowledgement',at:100,value:{kind:'catalog-ready'}},first={kind:'movement-input',at:300},second={kind:'frame',at:475};
 assert.equal(clock.ready(gate,99),false);clock.consume(gate,1100);assert.equal(clock.snapshot().loadingShiftMs,1000);
 assert.equal(clock.ready(first,1299),false);assert.equal(clock.ready(first,1300),true);clock.consume(first,1300);
 assert.equal(clock.ready(second,1474),false);assert.equal(clock.ready(second,1475),true);
 clock.consume(second,1600);assert.equal(clock.snapshot().loadingShiftMs,1000);assert.equal(clock.snapshot().eventsOver25msLate,2);
 const deltaAck={kind:'acknowledgement',at:500,value:{kind:'raw-world-accepted'}};clock.consume(deltaAck,1700);assert.equal(clock.snapshot().loadingShiftMs,1000);
});
test('area selection excludes inputs, native samples and network packets from other scopes',()=>{
 const records=[{kind:'frame',at:0,value:{kind:'setup',connection:1}},...['movement-input','movement-sample','network-game-packet'].map((kind,i)=>({kind,at:1+i,value:{connection:1,generation:1}})),{kind:'frame',at:10,value:{kind:'raw-world-begin',connection:1,generation:2,data:{bridgeMode:'full'}}},{kind:'movement-input',at:11,value:input},{kind:'movement-sample',at:12,value:{connection:1,generation:1}},{kind:'network-game-packet',at:13,value:{connection:2,generation:2}}];
 const selected=selectGeneration(records,2);assert.equal(selected.filter(r=>r.kind==='movement-input').length,1);assert(!selected.some(r=>r.kind==='movement-sample'||r.kind==='network-game-packet'));assert.equal(selected.at(-1).at,1);
});
