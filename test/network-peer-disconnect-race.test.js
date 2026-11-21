import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkPeer} from '../electron/network_peer.mjs';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NativeLobby} from '../godot-client/tools/native-lobby.mjs';
import {NetworkWindow} from '../src/network_window.js';
import {readReliableFrame,writeReliableFrame} from '../src/network_frames.js';
import {packetizeUncompressedMessage} from '../src/network_messages.js';

// Authored admitted state at the protocol-owner boundary. No connect(), DNS,
// socket, native crypto helper, profile, key or original-server operation.
function admittedPeer(){
 const diagnostics=[],sent=[];
 let closed=0,resets=0,closedEvents=0;
 const peer=new NetworkPeer({
  crypto:{close(){closed++;},async reset(){resets++;}},
  onDiagnostic:value=>diagnostics.push(value),
 });
 peer.login={phase:'admitted'};
 peer.window={enqueue(){throw Error('A cancelled queued game send must not reach the reliable window');}};
 peer.send=async bytes=>sent.push([...bytes]);
 peer.on('closed',()=>closedEvents++);
 return {peer,diagnostics,sent,counts:()=>({closed,resets,closedEvents})};
}
const deferred=()=>{let resolve;const promise=new Promise(done=>resolve=done);return{promise,resolve};};
const turn=()=>new Promise(resolve=>setImmediate(resolve));

test('an idle admitted peer disconnects once through its normal cleanup path',async()=>{
 const f=admittedPeer();
 await f.peer.disconnect();
 await f.peer.disconnect();
 assert.equal(f.peer.closed,true);
 assert.deepEqual(f.counts(),{closed:1,resets:1,closedEvents:1});
 assert.equal(f.sent.length,1);
 assert.equal(f.diagnostics.length,0);
});

test('disconnect cancels a not-yet-started admitted game send without rejecting cleanup',async()=>{
 const f=admittedPeer();
 // Both public operations are invoked synchronously, before the serial-lane
 // microtask starts. The queued request may reject after cancellation; normal
 // connection cleanup must still settle successfully and close exactly once.
 const request=f.peer.sendGameMessage(Uint8Array.of(112,1,0));
 const cleanup=f.peer.disconnect();
 const [requestResult,cleanupResult]=await Promise.allSettled([request,cleanup]);
 assert.equal(requestResult.status,'rejected');
 assert.equal(f.peer.closed,true);
 assert.equal(f.counts().closed,1);
 assert.equal(f.counts().closedEvents,1);
 assert.equal(cleanupResult.status,'fulfilled',
  `Normal disconnect rejected after queued-send cancellation: ${cleanupResult.reason?.message}`);
 assert.deepEqual(f.diagnostics,[],
  'A locally cancelled queued request must not be diagnosed as peer protocol failure');
 assert.equal(f.sent.length,1,'Only the disconnect packet is sent');
 assert.equal(f.counts().resets,1);
});

test('closing rejects further queued requests while repeated disconnect shares one cleanup',async()=>{
 const f=admittedPeer();
 const first=f.peer.sendGameMessage(Uint8Array.of(112,1,0));
 const second=f.peer.sendGameMessage(Uint8Array.of(112,1,0));
 const firstCleanup=f.peer.disconnect(),secondCleanup=f.peer.disconnect();
 assert.strictEqual(firstCleanup,secondCleanup);
 await assert.rejects(f.peer.sendGameMessage(Uint8Array.of(112,1,0)),/not ready/);
 const settled=await Promise.allSettled([first,second,firstCleanup,secondCleanup]);
 assert.deepEqual(settled.map(value=>value.status),['rejected','rejected','fulfilled','fulfilled']);
 await f.peer.disconnect();
 assert.deepEqual(f.counts(),{closed:1,resets:1,closedEvents:1});
 assert.equal(f.sent.length,1);
 assert.deepEqual(f.diagnostics,[]);
});

test('disconnect preserves every in-flight reliable fragment before its release packet',async()=>{
 const f=admittedPeer(),entered=deferred(),release=deferred();
 f.peer.window=new NetworkWindow({now:0,onDiagnostic:value=>f.diagnostics.push(value)});
 let completed=0;
 f.peer.send=async bytes=>{
  f.sent.push([...bytes]);
  if(f.sent.length===1){entered.resolve();await release.promise;}
  completed++;
 };
 const payload=new Uint8Array(2000).fill(17);payload.set([112,1,0]);
 const request=f.peer.sendGameMessage(payload);
 await entered.promise;
 const cleanup=f.peer.disconnect();
 let cleanupFinished=false;void cleanup.then(()=>cleanupFinished=true);
 await turn();
 assert.equal(cleanupFinished,false);
 assert.equal(f.peer.closed,false);
 assert.equal(f.sent.length,1);
 release.resolve();
 assert.equal(await request,undefined,'Successful public send return remains unchanged');
 await cleanup;
 const expected=packetizeUncompressedMessage(payload);
 assert.equal(expected.length,3);
 assert.equal(f.sent.length,expected.length+1);
 for(let index=0;index<expected.length;index++){
  const wire=Uint8Array.from(f.sent[index]),frame=readReliableFrame(wire);
  assert.equal(frame.kind,0);assert.equal(frame.sequence,index);
  assert.deepEqual(wire,writeReliableFrame({sequence:index,frame:expected[index]}));
 }
 assert.equal(Buffer.from(f.sent.at(-1)).subarray(0,4).toString('ascii'),'BNDM');
 assert.equal(completed,4);
 assert.deepEqual(f.counts(),{closed:1,resets:1,closedEvents:1});
 assert.deepEqual(f.diagnostics,[]);
});

test('in-flight transport failure remains fatal and cannot be hidden as local cancellation',async()=>{
 const f=admittedPeer(),entered=deferred(),release=deferred();
 f.peer.window=new NetworkWindow({now:0,onDiagnostic:value=>f.diagnostics.push(value)});
 f.peer.send=async bytes=>{f.sent.push([...bytes]);entered.resolve();await release.promise;throw Error('Mock transport failed');};
 const request=f.peer.sendGameMessage(Uint8Array.of(112,1,0));
 await entered.promise;
 const cleanup=f.peer.disconnect();
 const results=Promise.allSettled([request,cleanup]);release.resolve();
 const [requestResult,cleanupResult]=await results;
 assert.equal(requestResult.status,'rejected');assert.match(requestResult.reason.message,/Mock transport failed/);
 assert.equal(cleanupResult.status,'rejected');
 assert.deepEqual(f.counts(),{closed:1,resets:0,closedEvents:1});
 assert.equal(f.sent.length,1,'No packet is sent after the failed in-flight transport closes');
 assert.deepEqual(f.diagnostics.map(value=>value.code),['network.peer-failed']);
 await f.peer.disconnect();assert.equal(f.counts().closed,1);
});

test('a disconnect-packet failure still rejects and closes exactly once',async()=>{
 const f=admittedPeer();
 f.peer.send=async()=>{throw Error('Mock release packet failed');};
 await assert.rejects(f.peer.disconnect(),/Mock release packet failed/);
 assert.deepEqual(f.counts(),{closed:1,resets:0,closedEvents:1});
 await f.peer.disconnect();assert.equal(f.counts().closed,1);
});

test('Session and Lobby cancellation no longer publish the queued-send cleanup error',async()=>{
 const f=admittedPeer(),disposals={resources:0,identity:0,build:0};
 const session=new NetworkGameSession({peer:f.peer,language:0,
  identity:{dispose(){disposals.identity++;}},build:{dispose(){disposals.build++;}},
  resources:{close(){disposals.resources++;}},openModule:async()=>null});
 session.phase='playing';
 let lobby;
 lobby=new NativeLobby({listLocal:async()=>[],publish:()=>{},
  connect:async connection=>lobby.attach(session,connection),
  disconnect:({targetSession})=>targetSession.disconnect()});
 await lobby.join({connection:0});
 const release=deferred();
 const preceding=f.peer.enqueue(()=>release.promise);
 const request=f.peer.sendGameMessage(Uint8Array.of(112,1,0));
 const leaving=lobby.leave({connection:lobby.connection,saveCharacter:false});
 await turn();release.resolve();await preceding;
 const [requestResult]=await Promise.allSettled([request,leaving]);
 assert.equal(requestResult.status,'rejected');
 assert.equal(session.closed,true);assert.equal(lobby.session,null);
 assert.equal(lobby.phase,'menu');assert.equal(lobby.busy,false);assert.equal(lobby.error,'');
 assert.equal(lobby.snapshot().canJoin,true);
 assert.deepEqual(disposals,{resources:1,identity:1,build:1});
 assert.deepEqual(f.counts(),{closed:1,resets:1,closedEvents:1});
 assert.deepEqual(f.diagnostics,[]);
});
