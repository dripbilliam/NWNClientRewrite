import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeFrameChecksum,frameNumberBetween,readReliableFrame,writeReliableFrame} from '../src/network_frames.js';
import {NetworkWindow} from '../src/network_window.js';
import {NetworkMessageAssembler,packetizeUncompressedMessage} from '../src/network_messages.js';
import {decodeServerGameMessage,serverStatusRequest} from '../src/network_game_messages.js';
import {disconnectRequest} from '../src/network_login_packets.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-frame-observations.json',import.meta.url)));
const nativeTime=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-module-time-observations.json',import.meta.url)));
const bytes=hex=>Buffer.from(hex,'hex');
const valid=hex=>{const b=bytes(hex);b[0]=77;b.writeUInt16BE(nativeFrameChecksum(b),1);return b;};

test('frame checksum/header and cyclic interval match original native execution',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 assert.equal(native.crcTable[1],0x77073096);
 // Use the actual constructor's table as the reference for all byte values,
 // rather than rebuilding the same polynomial in the test.
 for(let seed=0;seed<256;seed++){
  const sample=Uint8Array.from({length:20},(_,i)=>(seed+i*37)&255);let crc=0;
  for(let i=3;i<sample.length;i++)crc=(crc>>>8)^native.crcTable[(crc^sample[i])&255];
  assert.equal(nativeFrameChecksum(sample),crc&65535);
 }
 assert.equal(Buffer.from(disconnectRequest()).toString('hex'),native.disconnect.find(c=>c[0]==='send')[1]);
 for(const row of native.sends){
  const actual=writeReliableFrame({kind:row.kind,sequence:row.sequence,expected:row.expected,compression:Boolean(row.compressed),frame:bytes(row.input)});
  assert.equal(Buffer.from(actual).toString('hex'),row.calls.find(c=>c[0]==='send')[1]);
  const parsed=readReliableFrame(actual);assert.equal(parsed.kind,row.kind);assert.equal(parsed.sequence,row.sequence);assert.equal(parsed.acknowledgement,(row.expected-1)&65535);
 }
 for(const row of native.between)assert.equal(Number(frameNumberBetween(row.first,row.candidate,row.end)),row.result,JSON.stringify(row));
});

test('real native server module-time message crosses assembly and native byte/bit decoding',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-transport-v4.json',import.meta.url))),assembler=new NetworkMessageAssembler();
 assert.equal(capture.loginAccepted,true);assert.equal(capture.disconnectRequested,true);
 for(const raw of capture.transport.applicationFrames)assembler.push(readReliableFrame(bytes(raw)).bytes);
 const messages=assembler.drain();assert.equal(messages.length,1);
 const decoded=decodeServerGameMessage(messages[0].bytes.subarray(12));assert.deepEqual(decoded,{kind:'module-time',major:3,minor:3,mask:2,changes:{hour:14}});
 assert.deepEqual(decodeServerGameMessage(Buffer.from([80,2,6])),{kind:'unsupported',major:2,minor:6,length:3});
 assert.throws(()=>decodeServerGameMessage(Buffer.from([80,3,3,0])),/message|stream/);
});

test('all native module-time masks decode original scalar serialization including transition and uint32 year',()=>{
 assert.equal(nativeTime.target,native.target);
 for(const row of nativeTime.cases){
  const {mask,timeOfDay,transition,hour,day,month,year}=row.case,expected={};
  if(mask&1){expected.timeOfDay=timeOfDay;if(timeOfDay===3||timeOfDay===4)expected.transition=transition;}
  for(const [bit,key,value]of [[2,'hour',hour],[4,'day',day],[8,'month',month],[16,'year',year]])if(mask&bit)expected[key]=value;
  assert.deepEqual(decodeServerGameMessage(bytes(row.packet)),{kind:'module-time',major:3,minor:3,mask,changes:expected});
 }
 assert.equal(nativeTime.cases.length,96);
});

test('native receive-window decisions match reorder, duplicate, wrap, ACK and NAK cases',()=>{
 for(const row of native.receives){
  const diagnostics=[],window=new NetworkWindow({onDiagnostic:d=>diagnostics.push(d)});
  Object.assign(window,{expected:row.expected,end:(row.expected+16)&65535,first:row.first,next:row.next});
  for(let i=0;i<((row.next-row.first)&65535);i++)window.outgoing.set((row.first+i)&65535,{frame:Buffer.alloc(12),deadline:0});
  for(const step of row.steps){
   const result=window.receive(valid(step.input),1000);
   assert.equal(Number(result.accepted),step.result,row.name);
   assert.deepEqual(result.send.map(b=>Buffer.from(b).toString('hex')),step.calls.filter(c=>c[0]==='send').map(c=>c[1]),row.name);
   assert.deepEqual(result.delivered.map(f=>f.highPriority?'high':'low'),step.calls.filter(c=>c[0]==='deliver').map(c=>c[1]),row.name);
   assert.deepEqual([window.first,window.next,window.expected,window.end,window.outgoing.size,Number(window.nakEnabled)],
    [step.first,step.next,step.expected,step.end,step.pending,step.nakEnabled],row.name);
  }
 }
});

test('invalid frame headers/checksums diagnose once and preserve window/owned bytes',()=>{
 const diagnostics=[],window=new NetworkWindow({onDiagnostic:d=>diagnostics.push(d)}),frame=writeReliableFrame({frame:new Uint8Array(16),sequence:1});
 const corrupt=Uint8Array.from(frame);corrupt[15]^=128;assert.equal(window.receive(corrupt,100).accepted,false);assert.equal(window.incoming.size,0);assert.equal(window.lastReceived,0);
 assert.equal(diagnostics.length,1);assert.equal(window.receive(frame,101).accepted,true);frame.fill(0);
 assert.equal(window.incoming.get(1).sequence,1);assert.equal(window.incoming.get(1).bytes[0],77);
 for(let size=0;size<12;size++)assert.throws(()=>readReliableFrame(frame.subarray(0,size)),/envelope/);
});

test('full outgoing window waits for acknowledged capacity; retransmission preserves sequence',()=>{
 const window=new NetworkWindow(),frame=Buffer.alloc(13);frame[12]=123;
 const sent=[];for(let n=0;n<17;n++)sent.push(...window.enqueue(frame,1000));frame.fill(0);
 assert.equal(sent.length,16);assert.equal(window.queued.length,1);assert.equal(readReliableFrame(sent[0]).bytes[12],123);
 assert.equal(window.poll(4500).length,1); // ACK timer expires; resend requires strictly later time.
 const retry=window.poll(4501);assert.equal(retry.length,1);assert.equal(readReliableFrame(retry[0]).sequence,0);
 const ack=writeReliableFrame({kind:1,expected:2});const result=window.receive(ack,4502);
 assert.deepEqual(result.acknowledged,[0,1]);assert.equal(result.send.length,1);assert.equal(readReliableFrame(result.send[0]).sequence,16);assert.equal(window.queued.length,0);
});

test('packed and fragmented message assembly matches the unchanged original coordinator',()=>{
 for(const row of native.assembly){
  const diagnostics=[],assembler=new NetworkMessageAssembler({onDiagnostic:d=>diagnostics.push(d)});
  for(const raw of row.frames)assembler.push(bytes(raw));
  assert.deepEqual(assembler.drain().map(m=>Buffer.from(m.bytes).toString('hex')),row.calls.filter(c=>c[0]==='message').map(c=>c[2]),row.name);
  assert.equal(assembler.queues[row.high?'high':'low'].length,row.remaining,row.name);assert.equal(diagnostics.length,0,row.name);
 }
 const diagnostics=[],assembler=new NetworkMessageAssembler({onDiagnostic:d=>diagnostics.push(d)}),bad=Buffer.alloc(12);assembler.push(bad);assert.equal(assembler.drain().length,0);assert.equal(diagnostics.length,1);
 const first=bytes(native.assembly[0].frames[0]),low=Buffer.from(first);low[7]=0;assembler.push(low);assembler.push(first);
 assert.deepEqual(assembler.drain().map(m=>m.priority),['high','low']);
});

test('outgoing message packetization matches original small/full/fragment boundary packets',()=>{
 for(const row of native.packetization){
  const expected=row.calls.filter(c=>c[0]==='queue').map(c=>c[3]);if(row.pending)expected.push(row.pending);
  assert.deepEqual(packetizeUncompressedMessage(bytes(row.payload)).map(b=>Buffer.from(b).toString('hex')),expected,`length ${row.payload.length/2}`);
 }
 assert.deepEqual([...serverStatusRequest()],[112,1,0]); // Native dispatch checks lowercase p.
 const response=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-transport-v9.json',import.meta.url)));
 assert.equal(response.transport.serverStatusRequested,true);assert.ok(response.packets.some(p=>p.direction==='in'&&p.tag==='M'&&p.frame.acknowledgement===0));
 assert.deepEqual(response.transport.messages,[{kind:'unsupported',major:1,minor:3,length:28}]);
});
