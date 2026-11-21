import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeDirectPortal} from './native-direct-portal.mjs';
import {NativeLobby} from './native-lobby.mjs';
import {ServerEndpointPolicy} from './server-endpoint.mjs';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';
import {portalCharacterRequest} from '../../src/network_portal.js';
import {writeGff,gffRecord} from '../../src/gff_writer.js';

const tick=()=>new Promise(resolve=>setImmediate(resolve));
const gate=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const portal={kind:'portal-activate',host:'127.0.0.1',port:5122,password:'authored-secret',waypoint:'Arrival',seamless:false};
async function until(predicate){for(let n=0;n<100;n++){if(predicate())return;await tick();}assert.fail('Mock boundary did not arrive');}

function fixture(t,options={}){
 const sessions=[],events=[],requests=[],identities=[],resets=[],installs=[];let current,helper;
 const identity=()=>{const value={disposed:false,dispose(){this.disposed=true;},forPortal(password){const clone=identity();clone.authoredPassword=password;identities.push(clone);return clone;}};return value;};
 function make(name,ownedIdentity=identity()){
  const peer=new EventEmitter(),sent=[],connections=[];let disconnects=0,resourcesClosed=0;
  peer.connect=async(_identity,args)=>{connections.push(args);options.onConnect?.(session,args);if(name!=='origin'){if(options.connectGate)await options.connectGate.promise;if(options.connectFailure)throw Error('authored-connect-failure');}return {build:{number:8193,revision:37,postfix:17}};};
  peer.sendGameMessage=async bytes=>sent.push(Uint8Array.from(bytes));
  peer.disconnect=async()=>{if(disconnects++===0)peer.emit('closed');if(name!=='origin'&&options.disconnectGate)await options.disconnectGate.promise;};
  const session=new NetworkGameSession({peer,identity:ownedIdentity,build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{close(){resourcesClosed++;}},language:0,decodeMessage:value=>value,openModule:async()=>({}),loadRules:async()=>({})});
  const row={name,session,peer,sent,connections,identity:ownedIdentity,counts:()=>({disconnects,resourcesClosed})};sessions.push(row);return row;
 }
 const origin=make('origin');current=origin.session;
 const lobby=new NativeLobby({listLocal:async()=>[],connect:async()=>{},publish:()=>{},disconnect:async({targetSession})=>{
  const connection=helper.snapshot().boundConnection??lobby.connection-1;await helper.cancel(targetSession,connection);if(current===targetSession)current=null;await targetSession?.disconnect();
 }});lobby.connection=1;lobby.attach(origin.session,1);
 let nextIndex=0;
 helper=new NativeDirectPortal({lobby,policy:new ServerEndpointPolicy({allowed:options.denied?[]:[{host:'127.0.0.1',port:5122}]}),isCurrent:(s,c)=>current===s&&lobby.connection===c,
  configFor:session=>{options.configRead?.();return options.configFor?options.configFor(session):{name:'Authored account',install:'authored-install',disabledMods:['authored-mod']};},
  prepare:async(args,connection,owned,signal)=>{
   requests.push({args,connection,owned,signal});if(options.prepareGate)await options.prepareGate.promise;if(options.prepareFailure)throw Error('authored-prepare-failure');
   if(options.alias)return {session:options.alias(),metadata:{connectionType:16}};
   const next=make('destination'+(++nextIndex),args.loginIdentity);next.session.loginWaypoint=args.loginWaypoint;options.onPrepared?.(next.session,args,connection,owned,signal);return {session:next.session,metadata:{connectionType:16,name:args.name},expectedServerPublicKey:options.pin};
  },
  retire:async context=>{events.push({stage:'retire',nullLobby:lobby.session===null,current:context.current(),signal:context.signal});await options.onRetire?.(context);if(options.retireGate)await options.retireGate.promise;if(options.retireFailure)throw Error('authored-retire-failure');},
  install:(next,connection)=>{installs.push({session:next.session,connection});if(options.installFailure)throw Error('authored-install-failure');current=next.session;options.onHostAttach?.(next.session,connection);lobby.attach(next.session,connection);if(options.bindInInstall)helper.bind(next.session,connection);if(options.asyncInstall)return Promise.resolve();},
  resetFailed:(s,c,previous)=>{resets.push({session:s,connection:c,previous});options.resetFailed?.(s,c,previous);if(current===s||current===previous)current=null;},
  onEvent:event=>{events.push(event);if(options.badObserver)throw Error('authored-observer-failure');}});
 helper.bind(origin.session,1);
 const ready=session=>{session.phase='playing';session.characterConfirmed=true;session.characterSubmitted=true;session.areaReadySent=true;session.publish();};ready(origin.session);
 const begin=(session=origin.session,changes={})=>session.receive({...portal,...changes});
 const handoff=async(character={kind:'portal-character',source:17,resref:'authored'},session=origin.session)=>{await session.receive(character);await tick();return helper.settled();};
 const replace=(connection=3)=>{const replacement=make('replacement');current=replacement.session;lobby.connection=connection;lobby.attach(current,connection);helper.bind(current,connection);ready(current);return replacement;};
 t.after(async()=>{options.prepareGate?.resolve();options.retireGate?.resolve();options.connectGate?.resolve();options.disconnectGate?.resolve();await helper.dispose();await Promise.allSettled(sessions.map(row=>row.session.disconnect()));assert.ok(sessions.every(row=>row.session.closed));await tick();});
 return {helper,lobby,origin,sessions,events,requests,identities,resets,installs,begin,handoff,replace,ready,current:()=>current};
}

test('actual Session portal protocol releases source before scoped install/connect and keeps character reference private',async t=>{
 const f=fixture(t,{bindInInstall:true,pin:Uint8Array.of(1,2,3)});f.origin.session.world.tlkOverrides.set(1,'old-server');await f.begin();
 assert.deepEqual(f.origin.sent,[portalCharacterRequest()]);assert.equal(f.origin.session.closed,false);assert.equal(f.installs.length,0);
 await f.handoff();const next=f.sessions[1];assert.equal(f.origin.session.closed,true);assert.equal(f.origin.session.portalHandoffReady,true);assert.equal(f.origin.identity.disposed,true);
 assert.equal(next.connections.length,1);assert.equal(next.connections[0].host,'127.0.0.1');assert.equal(next.connections[0].port,5122);assert.equal(next.connections[0].metadata.connectionType,16);assert.deepEqual(next.connections[0].expectedServerPublicKey,Uint8Array.of(1,2,3));
 assert.deepEqual(next.session.portalCharacter,{source:17,resref:'authored'});assert.equal(next.session.world.tlkOverrides.size,0);assert.equal(next.session.loginWaypoint,'Arrival');assert.equal(f.lobby.connection,2);assert.equal(f.lobby.session,next.session);assert.equal(f.lobby.portalDestinationConnection,null);
 assert.deepEqual(f.events.filter(v=>v.stage==='retire').map(v=>[v.nullLobby,v.current]),[[true,true]]);assert.equal(f.helper.snapshot().connected,1);assert.ok(!JSON.stringify(f.events).includes('authored-secret'));
 const copy=f.helper.snapshot();copy.connected=999;assert.equal(f.helper.snapshot().connected,1);
});

test('actual local-BIC branch copies only downloaded character and wipes the input buffer',async t=>{
 const f=fixture(t);await f.begin();const bytes=writeGff('BIC ',gffRecord({})),before=Uint8Array.from(bytes);await f.handoff({kind:'portal-character',data:bytes});
 assert.ok(bytes.every(v=>v===0));assert.deepEqual(f.sessions[1].session.character,before);assert.equal(f.sessions[1].session.characterUploadSubtype,1);
});

test('endpoint policy rejects before config, factory or identity clone',async t=>{
 let reads=0;const f=fixture(t,{denied:true,configRead:()=>reads++});await assert.rejects(f.origin.session.portalTransfer.prepare(portal),/not enabled/);assert.equal(reads,0);assert.equal(f.requests.length,0);assert.equal(f.identities.length,0);assert.equal(f.helper.snapshot().pending,false);
});

test('native seamless fallback, explicit waypoint and empty arrival are preserved',async t=>{
 for(const [seamless,waypoint,expected]of [[true,'','*PAUL_WAS_HERE*'],[false,'',''],[true,'Named','Named']]){
  const f=fixture(t);await f.origin.session.portalTransfer.prepare({...portal,seamless,waypoint});assert.equal(f.requests[0].args.loginWaypoint,expected);assert.equal(f.requests[0].args.name,'Authored account');assert.equal(f.requests[0].args.loginIdentity,f.identities[0]);await f.helper.cancel(f.origin.session,1);
 }
});

test('pending factory is fenced immediately and its late Session is disposed without connect',async t=>{
 const pending=gate(),f=fixture(t,{prepareGate:pending});const work=f.begin();await until(()=>f.requests.length===1);assert.equal(await f.helper.cancel(f.origin.session,1),true);assert.equal(f.requests[0].signal.aborted,true);pending.resolve();await work;
 assert.equal(f.sessions[1].session.closed,true);assert.equal(f.sessions[1].connections.length,0);assert.equal(f.installs.length,0);assert.equal(f.helper.snapshot().pending,false);
});

test('null-lobby cancellation disposes destination and late retirement cannot replace a new login',async t=>{
 const pending=gate(),f=fixture(t,{retireGate:pending});await f.begin();const handoff=f.handoff().catch(()=>{});await until(()=>f.helper.snapshot().phase==='retiring');assert.equal(f.lobby.session,null);
 assert.equal(await f.helper.cancel(null,2),true);assert.equal(f.sessions[1].session.closed,true);const newer=f.replace();pending.resolve();await handoff;
 assert.equal(f.lobby.session,newer.session);assert.equal(f.current(),newer.session);assert.equal(f.sessions[1].connections.length,0);assert.equal(f.installs.length,0);assert.equal(f.resets.length,0);
});

test('actual lobby Cancel during connect keeps late connect completion from reviving it',async t=>{
 const pending=gate(),f=fixture(t,{connectGate:pending});await f.begin();const handoff=f.handoff().catch(()=>{});await until(()=>f.helper.snapshot().phase==='connecting');assert.equal(f.lobby.snapshot().canCancelJoin,true);
 // The Host validates/cancels the current transfer before Lobby.leave advances
 // its connection. The later disconnect callback cannot revive that token.
 assert.equal(await f.helper.cancel(f.lobby.session,2),true);await f.lobby.cancelJoin({connection:2});assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.sessions[1].session.closed,true);pending.resolve();await handoff;assert.equal(f.helper.snapshot().connected,0);assert.equal(f.lobby.session,null);assert.equal(f.resets.length,0);
});

test('connect failure after Session closes still clears the exact transfer latch',async t=>{
 const f=fixture(t,{connectFailure:true});await f.begin();await f.handoff().catch(()=>{});await until(()=>!f.helper.snapshot().pending);
 assert.equal(f.lobby.phase,'menu');assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.lobby.transferring,false);assert.equal(f.resets.length,1);assert.equal(f.helper.snapshot().failed,1);
});

test('failed factory disposes its cloned identity and protocol closes origin normally',async t=>{
 const f=fixture(t,{prepareFailure:true});await f.begin();await tick();assert.equal(f.identities[0].disposed,true);assert.equal(f.origin.session.closed,true);assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.helper.snapshot().pending,false);
});

test('retirement/install failures close destination and recover the same lobby only',async t=>{
 for(const failure of ['retireFailure','installFailure']){const f=fixture(t,{[failure]:true});await f.begin();await f.handoff().catch(()=>{});assert.equal(f.sessions[1].session.closed,true);assert.equal(f.lobby.phase,'menu');assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.resets.length,1);}
});

test('unowned ready event and stale Cancel cannot dispose or reset another Session',async t=>{
 const f=fixture(t);await f.begin();const foreign=new EventEmitter();foreign.closed=false;foreign.disconnect=async()=>{foreign.closed=true;};
 await assert.rejects(f.helper.adopt(f.origin.session,{session:foreign}),/Unowned/);assert.equal(foreign.closed,false);assert.equal(await f.helper.cancel(foreign,1),false);assert.equal(await f.helper.cancel(null,1),false);assert.equal(f.helper.snapshot().pending,true);
 await f.handoff();assert.equal(await f.helper.cancel(f.origin.session,1),false);assert.equal(f.lobby.session,f.sessions[1].session);
});

test('late factory and captured old callback cannot match a rebound same-session scope',async t=>{
 const pending=gate(),f=fixture(t,{prepareGate:pending});const staleReady=f.origin.session.listeners('portal-ready')[0],oldPrepare=f.origin.session.portalTransfer.prepare;
 const first=oldPrepare(portal);await until(()=>f.requests.length===1);await f.helper.cancel(f.origin.session,1);f.helper.bind(f.origin.session,1);const second=f.origin.session.portalTransfer.prepare(portal);await until(()=>f.requests.length===2);pending.resolve();await assert.rejects(first,/Cancelled/);const next=await second;
 staleReady({...next,host:portal.host,port:portal.port});await tick();assert.equal(f.installs.length,0);assert.equal(f.helper.snapshot().pending,true);assert.equal(f.sessions[1].session.closed,true);assert.equal(f.sessions[2].session.closed,false);await assert.rejects(oldPrepare(portal),/Retired/);
});

test('late old connect completion cannot clear a newer prepared job or reset its owner',async t=>{
 const pending=gate(),f=fixture(t,{connectGate:pending});await f.begin();const old=f.handoff().catch(()=>{});await until(()=>f.helper.snapshot().phase==='connecting');const replacement=f.replace();await replacement.session.portalTransfer.prepare(portal);
 pending.resolve();await old;assert.equal(f.helper.snapshot().phase,'prepared');assert.equal(f.helper.snapshot().pending,true);assert.equal(f.current(),replacement.session);assert.equal(f.resets.length,0);assert.equal(f.sessions[1].session.closed,true);
});

test('consecutive native handoffs advance owners without retaining prior bindings',async t=>{
 const f=fixture(t);await f.begin();await f.handoff();const middle=f.sessions[1].session;f.ready(middle);await f.begin(middle,{waypoint:'Return'});await f.handoff({kind:'portal-character',source:2,resref:'returned'},middle);
 assert.equal(f.lobby.connection,3);assert.equal(f.lobby.session,f.sessions[2].session);assert.equal(f.sessions[2].session.loginWaypoint,'Return');assert.equal(f.helper.snapshot().connected,2);assert.equal(f.origin.session.listenerCount('portal-ready'),0);assert.equal(middle.listenerCount('portal-ready'),0);
});

test('factory cannot alias current origin or a separately current replacement',async t=>{
 let current;const f=fixture(t,{alias:()=>current});current=f.origin.session;await assert.rejects(f.origin.session.portalTransfer.prepare(portal),/fresh detached/);assert.equal(f.origin.session.closed,false);
});

test('commit callbacks must be synchronous; failed diagnostics cannot own a transfer',async t=>{
 const bad=fixture(t,{asyncInstall:true});await bad.begin();await bad.handoff().catch(()=>{});assert.equal(bad.sessions[1].connections.length,0);assert.equal(bad.lobby.phase,'menu');
 const good=fixture(t,{badObserver:true});await good.begin();await good.handoff();assert.equal(good.helper.snapshot().connected,1);
});

test('serial exhaustion rejects before factory and dispose detaches and blocks preparation',async t=>{
 const f=fixture(t);f.lobby.connection=Number.MAX_SAFE_INTEGER;f.lobby.attach(f.origin.session,f.lobby.connection);f.helper.bind(f.origin.session,f.lobby.connection);await assert.rejects(f.origin.session.portalTransfer.prepare(portal),/serial exhausted/);assert.equal(f.requests.length,0);assert.equal(f.helper.snapshot().pending,false);
 await f.helper.dispose();assert.equal(f.origin.session.listenerCount('portal-ready'),0);assert.equal(f.helper.snapshot().closed,true);assert.throws(()=>f.helper.bind(f.origin.session,f.lobby.connection),/current lobby owner/);await assert.rejects(f.origin.session.portalTransfer.prepare(portal),/Retired/);
});

test('premature/duplicate prepare or ready cannot release the live origin or double connect',async t=>{
 const f=fixture(t);const next=await f.origin.session.portalTransfer.prepare(portal);await assert.rejects(f.origin.session.portalTransfer.prepare(portal),/busy/);await assert.rejects(f.helper.adopt(f.origin.session,next),/not released/);
 assert.equal(f.origin.session.closed,false);assert.equal(f.lobby.session,f.origin.session);assert.equal(f.resets.length,0);assert.equal(f.installs.length,0);
 f.origin.session.portalHandoffReady=true;f.origin.session.finish();const first=f.helper.adopt(f.origin.session,{...next,host:'invalid.example',port:1,metadata:{forged:true}}),second=f.helper.adopt(f.origin.session,next);assert.equal(first,second);await first;
 assert.equal(f.sessions[1].connections.length,1);assert.equal(f.sessions[1].connections[0].host,'127.0.0.1');assert.equal(f.sessions[1].connections[0].metadata.forged,undefined);
});

test('a closed prepared destination recovers after real origin release without connecting',async t=>{
 const f=fixture(t);const next=await f.origin.session.portalTransfer.prepare(portal);await next.session.disconnect();f.origin.session.portalHandoffReady=true;f.origin.session.finish();await assert.rejects(f.helper.adopt(f.origin.session,next),/Retired/);
 assert.equal(f.lobby.phase,'menu');assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.installs.length,0);assert.equal(f.sessions[1].connections.length,0);
});

test('owned transport cleanup failure remains explicit in detached counters',async t=>{
 const f=fixture(t);const next=await f.origin.session.portalTransfer.prepare(portal);next.session.peer.disconnect=async()=>{throw Error('authored-disconnect-failure');};await f.helper.cancel(f.origin.session,1);
 assert.equal(next.session.closed,true);assert.equal(f.helper.snapshot().cleanupFailures,1);assert.equal(f.helper.snapshot().pending,false);
});

test('old-origin Cancel is stale after the connection advances into null-lobby retirement',async t=>{
 const pending=gate(),f=fixture(t,{retireGate:pending});await f.begin();const work=f.handoff().catch(()=>{});await until(()=>f.helper.snapshot().phase==='retiring');assert.equal(f.lobby.connection,2);assert.equal(f.lobby.session,null);
 assert.equal(await f.helper.cancel(f.origin.session,1),false);assert.equal(f.helper.snapshot().phase,'retiring');assert.equal(f.sessions[1].session.closed,false);
 assert.equal(await f.helper.cancel(null,2),true);pending.resolve();await work;
});

test('Host-shaped synchronous install publishes exact Host/Lobby/binding before peer connect',async t=>{
 const handles={clock:null,raw:null,connection:1},order=[],observed=[];let f;
 f=fixture(t,{onRetire:async context=>{order.push('retire');if(!context.current()||context.signal.aborted)return;if(handles.clock===context.previous)handles.clock=null;if(handles.raw===context.previous)handles.raw=null;},onHostAttach:(s,c)=>{order.push('host-attach');handles.clock=s;handles.raw=s;handles.connection=c;},onConnect:s=>observed.push({host:f.current()===s,lobby:f.lobby.session===s,bound:f.helper.snapshot().boundConnection,clock:handles.clock===s,raw:handles.raw===s})});
 handles.clock=handles.raw=f.origin.session;await f.begin();await f.handoff();
 assert.deepEqual(order,['retire','host-attach']);assert.deepEqual(observed,[{host:true,lobby:true,bound:2,clock:true,raw:true}]);assert.equal(f.lobby.phase,'resources');assert.equal(f.lobby.snapshot().canCancelJoin,true);assert.equal(f.lobby.snapshot().canJoin,false);
});

test('Host-shaped WeakMap config/persistence/vault identity belong to each factory Session',async t=>{
 const configs=new WeakMap(),bindings=new WeakMap(),persistence=new WeakMap(),saved=[];let saveWait=null,f;
 const sanitize=value=>Object.freeze({name:value.name,install:value.install,disabledMods:Object.freeze([...value.disabledMods])});
 f=fixture(t,{configFor:s=>configs.get(s),onPrepared:(s,args,c)=>{
  configs.set(s,sanitize(args));bindings.set(s,c);const inherited={...persistence.get(f.current())};persistence.set(s,inherited);
  s.persistCharacter=async message=>{if(f.current()!==s||f.lobby.connection!==c||s.closed)throw Error('retired persistence owner');const capturedVaultId=inherited.vaultId,wait=saveWait;if(wait)await wait.promise;if(f.current()!==s||f.lobby.connection!==c||s.closed)throw Error('retired persistence owner');saved.push({session:s,connection:c,value:message.authored,vaultId:capturedVaultId});return {connection:c};};
 }});
 configs.set(f.origin.session,sanitize({name:'Captured account',install:'captured-install',disabledMods:['captured-mod']}));bindings.set(f.origin.session,1);persistence.set(f.origin.session,{vaultId:'captured-source-vault'});f.lobby.vaultId='captured-source-vault';
 await f.begin();await f.handoff();const second=f.sessions[1].session;assert.equal(f.lobby.vaultId,null);f.lobby.vaultId='unrelated-global-vault';assert.deepEqual(Object.keys(configs.get(second)),['name','install','disabledMods']);assert.equal(f.requests[0].args.name,'Captured account');assert.equal(bindings.get(second),2);await second.persistCharacter({authored:'first'});
 saveWait=gate();const retiredSave=second.persistCharacter({authored:'must-not-save'});await tick();f.ready(second);await f.begin(second);await f.handoff({kind:'portal-character',source:17,resref:'again'},second);const third=f.sessions[2].session;
 const release=saveWait;saveWait=null;release.resolve();await assert.rejects(retiredSave,/retired persistence/);await third.persistCharacter({authored:'third'});
 assert.deepEqual(saved.map(v=>[v.connection,v.value,v.vaultId]),[[2,'first','captured-source-vault'],[3,'third','captured-source-vault']]);assert.equal(saved[1].session,third);assert.equal(bindings.get(third),3);assert.equal(f.requests[1].args.name,'Captured account');assert.notEqual(f.requests[0].args.loginIdentity,f.requests[1].args.loginIdentity);
});

test('Host-shaped async retirement never clears replacement clock/raw handles after cancellation',async t=>{
 const wait=gate(),handles={clock:null,raw:null},observed=[];let f;
 f=fixture(t,{onRetire:async context=>{
  if(context.current()&&!context.signal.aborted){if(handles.clock===context.previous)handles.clock=null;if(handles.raw===context.previous)handles.raw=null;}
  await wait.promise;observed.push(context.current()&&!context.signal.aborted);
  if(!context.current()||context.signal.aborted)return;
  if(handles.clock===context.previous)handles.clock=null;if(handles.raw===context.previous)handles.raw=null;
 }});
 handles.clock=handles.raw=f.origin.session;await f.begin();const work=f.handoff().catch(()=>{});await until(()=>f.helper.snapshot().phase==='retiring');assert.equal(handles.clock,null);assert.equal(handles.raw,null);
 await f.helper.cancel(null,2);const replacement=f.replace();handles.clock=handles.raw=replacement.session;wait.resolve();await work;
 assert.deepEqual(observed,[false]);assert.equal(handles.clock,replacement.session);assert.equal(handles.raw,replacement.session);assert.equal(f.installs.length,0);assert.equal(f.resets.length,0);
});

test('Host-shaped Cancel starts Lobby busy barrier before awaiting peer cleanup',async t=>{
 const pending=gate(),f=fixture(t,{disconnectGate:pending});await f.begin();await f.handoff();
 const message={connection:2};f.lobby.requireOwner(message);const cleanup=f.helper.cancel(f.lobby.session,message.connection),leaving=f.lobby.cancelJoin(message);
 await until(()=>f.sessions[1].session.closed);assert.equal(f.lobby.connection,3);assert.equal(f.lobby.busy,true);assert.equal(f.lobby.snapshot().canJoin,false);assert.equal(f.lobby.cancelling,true);
 await assert.rejects(f.lobby.join({connection:3,details:{}}),/Disconnect/);pending.resolve();await Promise.all([cleanup,leaving]);assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.lobby.cancelling,false);assert.equal(f.lobby.session,null);
});

test('Host-shaped synchronous failure reset receives exact target/origin and destination connection',async t=>{
 const handles={clock:null,raw:null},observed=[];let f;
 const reset=(s,c,previous)=>{
  const admitted=f.lobby.connection===c&&(f.current()===s||f.current()===previous);observed.push({connection:c,admitted});if(!admitted)return;
  if(handles.clock===s||handles.clock===previous)handles.clock=null;if(handles.raw===s||handles.raw===previous)handles.raw=null;
 };
 f=fixture(t,{connectFailure:true,onHostAttach:s=>{handles.clock=handles.raw=s;},resetFailed:reset});handles.clock=handles.raw=f.origin.session;
 await f.begin();await f.handoff().catch(()=>{});assert.deepEqual(observed,[{connection:2,admitted:true}]);assert.equal(handles.clock,null);assert.equal(handles.raw,null);assert.equal(f.lobby.phase,'menu');
 const replacement=f.replace();handles.clock=handles.raw=replacement.session;reset(f.sessions[1].session,2,f.origin.session);
 assert.deepEqual(observed.at(-1),{connection:2,admitted:false});assert.equal(handles.clock,replacement.session);assert.equal(handles.raw,replacement.session);
});
