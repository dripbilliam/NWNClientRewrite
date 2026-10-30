import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkPeer} from '../electron/network_peer.mjs';
import fs from 'node:fs';
import {writeReliableFrame,readReliableFrame} from '../src/network_frames.js';

test('authenticated validation keepalives cannot admit a player or deliver game data',async()=>{
 const diagnostics=[],sent=[],peer=new NetworkPeer({crypto:{close(){}},onDiagnostic:d=>diagnostics.push(d)});
 peer.cipher={decode:async bytes=>bytes.subarray(1)};
 peer.login={phase:'validate',exchange:{},receive:async()=>({accepted:false})};
 peer.send=async bytes=>sent.push(bytes);
 let messages=0;peer.on('message',()=>messages++);
 await peer.receive(Uint8Array.of(73,...writeReliableFrame({kind:1})));
 assert.equal(sent.length,1);assert.equal(readReliableFrame(sent[0]).kind,1);
 assert.equal(peer.window,undefined);assert.equal(peer.login.phase,'validate');assert.equal(messages,0);
 assert.deepEqual(diagnostics,[]);
 const data=new Uint8Array(13);data[12]=112;
 await peer.receive(Uint8Array.of(73,...writeReliableFrame({kind:0,frame:data})));
 assert.equal(sent.length,1);assert.equal(messages,0);
 const corrupt=writeReliableFrame({kind:1});corrupt[2]^=1;
 await assert.rejects(peer.receive(Uint8Array.of(73,...corrupt)),/checksum/);
 await peer.disconnect();
});

test('cancelling during asynchronous endpoint resolution releases the peer exactly once',async()=>{
 let closed=0;const diagnostics=[],peer=new NetworkPeer({crypto:{close:()=>closed++},onDiagnostic:d=>diagnostics.push(d)}),events=[];peer.on('closed',e=>events.push(e));
 const connection=peer.connect({}, {host:'localhost',metadata:{}});await peer.disconnect();await assert.rejects(connection,/connection failed/);await peer.disconnect();
 assert.equal(closed,1);assert.equal(events.length,1);assert.equal(peer.snapshot().phase,'closed');assert.equal(peer.snapshot().admitted,false);if(peer.socket)assert.throws(()=>peer.socket.address());assert.deepEqual(diagnostics,[]);
});

test('requests before admission fail without destroying an otherwise unused connection owner',async()=>{
 let closed=0;const peer=new NetworkPeer({crypto:{close:()=>closed++},onDiagnostic:()=>{}});
 await assert.rejects(peer.sendGameMessage(Uint8Array.of(112,1,0)),/not ready/);assert.equal(peer.closed,false);assert.equal(closed,0);
 assert.throws(()=>peer.sendGameMessage(Uint8Array.of(80,1,0)),/Invalid/);await peer.disconnect();assert.equal(closed,1);
});

test('real native-server captures verify persistent peer admission, player state and clean reconnection',()=>{
 for(const version of [1,2]){
  const report=JSON.parse(fs.readFileSync(new URL(`../backups/animations/local-network-peer-v${version}.json`,import.meta.url)));
  assert.equal(report.loginAccepted,true);assert.equal(report.failure,undefined);assert.equal(report.disconnectRequested,true);assert.equal(report.peer.closed,true);assert.equal(report.peer.admitted,false);
  assert.equal(report.transport.resources.ready,true);assert.equal(report.transport.character.confirmed,true);assert.equal(report.transport.world.localObjectId,0xffffffff);assert.equal(report.transport.world.objects,33);
  const updates=report.transport.messages.filter(m=>m.kind==='object-updates');assert.ok(updates.length>=3);assert.ok(updates.every(m=>m.complete));
  const states=updates.flatMap(m=>m.records.filter(r=>r.action==='player-state'));assert.ok(states.length>=2);assert.equal(states.find(r=>r.state.knownSpellChanges).state.knownSpellChanges[0].added.length,43);
  assert.equal(report.diagnostics.some(d=>/invalid|failed|object-record-unhandled/.test(d.code)),false);
  assert.ok(report.packets.some(p=>p.direction==='out'&&p.tag==='BNDM'&&!p.encrypted));assert.ok(report.packets.some(p=>p.tag==='M'&&p.encrypted));
 }
});

test('admitted peer retains the server disconnect reason through cleanup',async()=>{
 const diagnostics=[],events=[],peer=new NetworkPeer({crypto:{close(){}},onDiagnostic:d=>diagnostics.push(d)});peer.window={};peer.on('closed',e=>events.push(e));
 await peer.receive(Uint8Array.of(66,78,68,80,0xd4,0x28,0,0,4,0,84,101,115,116));
 assert.deepEqual(events,[{failed:false,reason:{strRef:10452,text:'Test'}}]);assert.equal(diagnostics[0].text,'Test');assert.equal(peer.closed,true);
});
