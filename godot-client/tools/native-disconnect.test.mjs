import {test} from 'node:test';
import assert from 'node:assert/strict';
import dgram from 'node:dgram';
import {EventEmitter,once} from 'node:events';
import {NativeLobby} from './native-lobby.mjs';
import {NativeCommandPump} from './native-command-pump.mjs';
import {NetworkPeer} from '../../electron/network_peer.mjs';
import {queryNetworkServer} from '../../electron/server_browser.mjs';
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
const turn=()=>new Promise(r=>setImmediate(r));
const bounded=async promise=>{let timer;try{return await Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Cancellation did not complete within one second')),1000);})]);}finally{clearTimeout(timer);}};

test('the production command pump cancels a blocked preparation without waiting, and ignores late attachment',async()=>{
 const gate=deferred(),entered=deferred(),errors=[],closed=[];let lobby,signal;
 lobby=new NativeLobby({listLocal:async()=>[],publish:()=>{},connect:async(connection,details,options)=>{signal=options.signal;entered.resolve();await gate.promise;if(connection!==lobby.connection){closed.push(connection);return;}const session=new EventEmitter();session.phase='character-selection';lobby.attach(session,connection);},disconnect:async()=>{}});
 const pump=new NativeCommandPump(message=>message.kind==='lobby-join'?lobby.join(message):lobby.cancelJoin(message),e=>errors.push(e));
 const join=pump.push({kind:'lobby-join',connection:0});await entered.promise;
 await bounded(pump.push({kind:'lobby-cancel-join',connection:1}));await bounded(join);
 assert.equal(signal.aborted,true);assert.equal(lobby.connection,2);assert.equal(lobby.phase,'menu');assert.equal(lobby.snapshot().canJoin,true);
 gate.resolve();await turn();assert.deepEqual(closed,[1]);assert.equal(lobby.session,null);assert.deepEqual(errors,[]);
});

test('disconnect preempts a pending character upload and its completion cannot affect a fresh login',async()=>{
 const gate=deferred(),target=new EventEmitter(),fresh=new EventEmitter(),disconnected=[];target.phase='character-selection';target.localVaultAllowed=true;target.selectCharacter=()=>gate.promise;
 let next=target,lobby;
 lobby=new NativeLobby({listLocal:async()=>[{key:'pc',source:'installed'}],readLocal:async()=>Uint8Array.of(1),publish:()=>{},connect:async connection=>lobby.attach(next,connection),disconnect:async options=>{disconnected.push(options.targetSession);options.targetSession.closed=true;}});
 await lobby.join({connection:0});lobby.selected='pc';const playing=lobby.play({connection:1,key:'pc'});await turn();assert.equal(lobby.busy,true);
 await bounded(lobby.leave({connection:1,saveCharacter:false}));next=fresh;fresh.phase='character-selection';await lobby.join({connection:2});
 gate.resolve();await playing;assert.equal(lobby.session,fresh);assert.equal(lobby.connection,3);assert.equal(lobby.busy,false);assert.deepEqual(disconnected,[target]);
});

test('server info cancellation closes the real loopback UDP request immediately',async t=>{
 const socket=dgram.createSocket('udp4');socket.bind(0,'127.0.0.1');await once(socket,'listening');t.after(()=>socket.close());
 const controller=new AbortController(),packet=once(socket,'message');
 const query=queryNetworkServer({host:'127.0.0.1',port:socket.address().port,timeout:45000,signal:controller.signal});
 const rejection=assert.rejects(query,/User cancelled/);await packet;controller.abort(Error('User cancelled'));await bounded(rejection);
});

test('disconnect interrupts the real peer while crypto/login preparation is blocked',async()=>{
 const gate=deferred(),entered=deferred();let closes=0;
 const peer=new NetworkPeer({crypto:{applicationId:async()=>{entered.resolve();return gate.promise;},close:()=>closes++},onDiagnostic:()=>{}});
 const connecting=peer.connect({}, {host:'127.0.0.1',port:51999,timeout:45000,metadata:{}});
 const rejection=assert.rejects(connecting,/connection failed/);await entered.promise;await bounded(peer.disconnect());assert.equal(peer.closed,true);assert.equal(closes,1);
 gate.resolve('test');await rejection;assert.equal(closes,1);
});
