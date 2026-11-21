import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeLobby,lobbyServerInfo} from './native-lobby.mjs';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};};
const settle=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(inspectServer=async()=>null){
 const peer=new EventEmitter(),sent=[],events=[];peer.sendGameMessage=async bytes=>sent.push([...bytes]);peer.disconnect=async()=>peer.emit('closed');
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{},dispose(){}},resources:{close(){}},language:0,openModule:async()=>({}),decodeMessage:m=>m,localVaultAllowed:false,serverInfo:{moduleName:'Owned baseline',playerCount:1,maximumPlayers:4,pvpSetting:1}});
 session.resolver={};session.resourceResult={ready:true};session.phase='character-selection';
 const lobby=new NativeLobby({listLocal:async()=>[],readLocal:async()=>{throw Error('Unexpected local read');},connect:async()=>{},disconnect:async()=>session.disconnect(),save:async()=>{},publish:message=>events.push(message),inspectServer});
 lobby.connection=1;lobby.endpoint={host:'127.0.0.1',port:5125};lobby.attach(session,1);
 return{session,peer,lobby,sent,events,page:index=>lobby.setPage({connection:lobby.connection,page:index}),player:async(present,id,extra={})=>session.receive({kind:'server-character-player',present,character:{id,firstName:{text:'Other'},lastName:{text:'Player'},portrait:3,classes:[{id:10,level:5}],...extra}})};
}
test('Player List subscribes through the real protocol and forwards received changes without creating world entities',async()=>{
 const f=fixture();await f.page(2);assert.deepEqual(f.sent,[[112,49,1]]);assert.equal(f.lobby.snapshot().players.length,0);
 await f.player(true,7,{credentials:{password:'PRIVATE'},file:'PRIVATE/BIC'});assert.equal(f.lobby.snapshot().players[0].id,7);assert.equal(JSON.stringify(f.lobby.snapshot().players).includes('PRIVATE'),false);
 await f.player(true,7,{classes:[{id:3,level:9}]});assert.equal(f.lobby.snapshot().players.length,1);assert.equal(f.lobby.snapshot().players[0].classes[0].level,9);
 await f.player(true,8);assert.deepEqual(f.lobby.snapshot().players.map(p=>p.id),[7,8]);await f.player(false,7);assert.deepEqual(f.lobby.snapshot().players.map(p=>p.id),[8]);
 assert.equal(f.session.world.registry.objects.size,0);assert.equal(f.lobby.selected,null);assert.equal(f.session.characterSubmitted,undefined);
 await f.page(0);assert.deepEqual(f.sent,[[112,49,1],[112,49,2]]);assert.deepEqual(f.lobby.snapshot().players,[]);
 await f.player(true,99);assert.deepEqual(f.lobby.snapshot().players,[]);await f.page(0);assert.equal(f.sent.length,2);
 await f.page(2);assert.deepEqual(f.lobby.snapshot().players,[]);assert.equal(f.sent.length,3);await f.session.disconnect();
});
test('Server Info publishes whitelisted basic metadata immediately and asynchronously replaces it with owned extended fields',async()=>{
 const gate=deferred(),calls=[],f=fixture(input=>{calls.push(input);return gate.promise;});
 await f.page(1);assert.equal(f.lobby.snapshot().serverInfo.moduleName,'Owned baseline');assert.equal(f.lobby.snapshot().serverInfoPending,true);
 gate.resolve({moduleName:'Owned detailed',serverVersion:'8193.37',extendedReceived:true,advertisement:{private:'PRIVATE'},credentials:'PRIVATE'});await settle();
 assert.equal(calls.length,1);assert.equal(calls[0].session,f.session);assert.deepEqual(calls[0].endpoint,{host:'127.0.0.1',port:5125});
 assert.equal(f.lobby.snapshot().serverInfo.moduleName,'Owned detailed');assert.equal(f.lobby.snapshot().serverInfo.serverVersion,'8193.37');assert.equal(f.lobby.snapshot().serverInfoPending,false);assert.equal(JSON.stringify(f.lobby.snapshot().serverInfo).includes('PRIVATE'),false);
 await f.page(0);await f.page(1);assert.equal(calls.length,1);await f.session.disconnect();
});
test('changing tabs aborts a pending details provider and its late result cannot overwrite the current page',async()=>{
 const gate=deferred();let signal;const f=fixture(input=>{signal=input.signal;return gate.promise;});await f.page(1);await f.page(2);assert.equal(signal.aborted,true);
 gate.resolve({moduleName:'STALE',extendedReceived:true});await settle();assert.equal(f.lobby.snapshot().serverInfo.moduleName,'Owned baseline');assert.equal(f.lobby.snapshot().lobbyPage,2);assert.equal(f.lobby.snapshot().serverInfoPending,false);await f.session.disconnect();
});
test('disconnect and stale attachment retire page ownership without allowing old provider results into a new connection',async()=>{
 const gate=deferred();const f=fixture(()=>gate.promise);await f.page(1);await f.lobby.leave({connection:1,saveCharacter:false});gate.resolve({moduleName:'STALE'});await settle();
 assert.deepEqual(f.lobby.snapshot().serverInfo,{});assert.deepEqual(f.lobby.snapshot().players,[]);assert.equal(f.lobby.snapshot().lobbyPage,0);
 await assert.rejects(f.lobby.setPage({connection:1,page:2}),/old connection/);assert.throws(()=>f.lobby.attach(f.session,1),/Cancelled/);
 for(const page of [-1,3,1.5,'2'])await assert.rejects(f.lobby.setPage({connection:2,page}),/Invalid/);
});
test('Play stops Player List before issuing the original server character admission request',async()=>{
 const f=fixture(),raw={source:17,resref:'hero',firstName:{text:'Hero'},lastName:{text:''},portrait:0,portraitRef:'',classes:[]};
 f.session.serverCharacters=[raw];f.session.characterListGeneration=1;await f.lobby.serverList({generation:1,characters:[raw]},f.session,1);f.lobby.selected='server:17:hero';
 await f.page(2);await f.player(true,7);await f.lobby.play({connection:1,key:'server:17:hero'});
 assert.deepEqual(f.sent.slice(0,2),[[112,49,1],[112,49,2]]);assert.deepEqual(f.sent.at(-1).slice(0,3),[112,2,17]);assert.equal(f.session.characterSubmitted,true);assert.deepEqual(f.lobby.snapshot().players,[]);await f.session.disconnect();
});
test('a failed subscription send is visible and releases the protocol flag so the user can retry',async()=>{
 const f=fixture();let fail=true;f.peer.sendGameMessage=async bytes=>{if(fail){fail=false;throw Error('Owned send failed');}f.sent.push([...bytes]);};
 await f.page(2);assert.equal(f.lobby.snapshot().pageError,'Owned send failed');assert.equal(f.session.lobbyPlayersOpen,false);
 await f.page(2);assert.equal(f.lobby.snapshot().pageError,'');assert.deepEqual(f.sent,[[112,49,1]]);await f.session.disconnect();
});
test('an older failed stop cannot roll back a newer successful Player List start',async()=>{
 const f=fixture(),gate=deferred();await f.session.lobbyPlayers(true);let once=true;f.peer.sendGameMessage=async()=>{if(once){once=false;await gate.promise;}};
 const stop=f.session.lobbyPlayers(false);await f.session.lobbyPlayers(true);gate.reject(Error('Old stop failed'));await assert.rejects(stop,/Old stop/);assert.equal(f.session.lobbyPlayersOpen,true);await f.session.disconnect();
});
test('Server Info never invents unreported status or converts query internals into UI fields',()=>{
 assert.deepEqual(lobbyServerInfo({moduleName:'Owned',serverStatus:null,serverVersion:17,advertisement:{url:'PRIVATE'},playerCount:2}),{moduleName:'Owned',playerCount:2});
});
test('the original server-availability messages, not the client lobby phase, supply the displayed server status',async()=>{
 const f=fixture();assert.equal(f.lobby.snapshot().serverInfo.serverStatus,undefined);
 await f.session.receive({kind:'server-loading'});assert.equal(f.lobby.snapshot().serverInfo.serverStatus,1);
 await f.session.receive({kind:'server-unavailable'});assert.equal(f.lobby.snapshot().serverInfo.serverStatus,0);
 f.session.emit('message',{message:{kind:'server-resources'}});assert.equal(f.lobby.snapshot().serverInfo.serverStatus,2);
 await f.page(1);await settle();assert.equal(f.lobby.snapshot().serverInfo.serverStatus,2);
 await f.lobby.leave({connection:1,saveCharacter:false});assert.equal(f.lobby.snapshot().serverInfo.serverStatus,undefined);
});
