// Execute the actual Host closures in a dependency-injected lexical scope.
// No importing/starting the monolithic Host, sockets, assets, keys or engine.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {EventEmitter} from 'node:events';
import {NativeDirectPortal} from './native-direct-portal.mjs';
import {NativeLobby} from './native-lobby.mjs';
import {ServerEndpointPolicy} from './server-endpoint.mjs';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';

const hostFile=new URL('./native-session-host.cjs',import.meta.url),hostBytes=fs.readFileSync(hostFile),host=hostBytes.toString();
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),hostSha256=hash(hostBytes);
function location(marker){const first=host.indexOf(marker);assert.ok(first>=0,'Host source boundary exists: '+marker);assert.equal(host.indexOf(marker,first+marker.length),-1,'Host source boundary is unique: '+marker);return first;}
function between(start,end){const a=location(start),b=location(end);assert.ok(b>a,'Host source declaration order');return host.slice(a,b);}
const descriptor=between('\n const sourceDescriptor=current=>{','\n const creationSelectionCodec='),owners=between('\n const sessionConfigs=new WeakMap()','\n const attach='),attach=between('\n const attach=','\n const createSession='),factory=between('\n const createSession=','\n lobby=new NativeLobby('),portal=between('\n directPortal=new NativeDirectPortal(','\n lobby.inspectServer=');
const disconnectStart=location('disconnect:async options=>{')+'disconnect:'.length,disconnectEnd=location('\n  },save:');
const disconnect='const disconnect='+host.slice(disconnectStart,disconnectEnd+4)+';';
const play=between("  if(message.kind==='lobby-play')","  if(message.kind==='lobby-disconnect')"),leave=between("  if(message.kind==='lobby-disconnect')","  if(message.kind==='lobby-export')"),cancel=between("  if(message.kind==='lobby-cancel-join')","  if(message.kind==='lobby-join')");
const fragmentText=[descriptor,owners,attach,factory,portal,disconnect,play,leave,cancel].join('\n');
const flags=[...new Set(fragmentText.match(/\b[A-Za-z_$][\w$]*Check\b|\bscriptFloatingOwned\b/g))];
const evaluate=vm.compileFunction(`
 const {lobby,policy,report,vault,createInstalledNetworkSession,NativeDirectPortal,nativeClockBridge,worldDeltas,sendForConnection,path,install,userDirectory,cacheDirectory,startup,characterPreviewStore}=deps;
 const ${flags.map(name=>name+'=false').join(',')};
 const ending=false;
 let session=null,setupSession=null,catalogReady=false,rawPending=null,snapshotGeneration=-1,nativeClockOwner=null,nativeClockConnection=-1,directPortal,localDisconnectedAt=0;
 ${descriptor}${owners}${attach}${factory}${portal}
 ${disconnect}
 const command=async message=>{${play}${leave}${cancel}throw Error('Unextracted command');};
 return {createSession,rememberVaultId,retirePresentation,sourceDescriptor,directPortal,disconnect,command,
  initialAttach:(created,connection)=>{attach(created.session,connection);lobby.attach(created.session,connection);directPortal.bind(created.session,connection);},
  stateOf:s=>sessionPersistence.get(s),configOf:s=>sessionConfigs.get(s),
  hostState:()=>({session,setupSession,catalogReady,rawPending,snapshotGeneration,nativeClockOwner,nativeClockConnection})};
`,['deps'],{filename:'actual-native-session-host-closures.cjs'});
const tick=()=>new Promise(resolve=>setImmediate(resolve)),gate=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
async function until(predicate){for(let n=0;n<100;n++){if(predicate())return;await tick();}assert.fail('Actual Host mock boundary did not arrive');}

async function fixture(t,options={}){
 const sessions=[],sent=[],clock=[],saves=[],factoryRequests=[];let api,index=0;
 const report={diagnostics:[],states:[],publicConnections:0};
 const identity=()=>({disposed:false,publicKey:Uint8Array.of(1,2),dispose(){this.disposed=true;},forPortal(){return identity();}});
 const createInstalledNetworkSession=async request=>{
  factoryRequests.push(request);if(options.factoryGate)await options.factoryGate.promise;
  const peer=new EventEmitter(),packets=[],connections=[];let disconnected=false;
  peer.connect=async(_identity,args)=>{connections.push({args,bound:api.directPortal.snapshot().boundConnection,host:api.hostState().session,lobby:lobby.session,clock:api.hostState().nativeClockOwner});if(options.connectFailure)throw Error('authored connect failure');return {build:{number:8193,revision:37,postfix:17}};};
  peer.sendGameMessage=async bytes=>packets.push(Uint8Array.from(bytes));
  peer.disconnect=async()=>{if(!disconnected){disconnected=true;peer.emit('closed');}if(options.disconnectGate)await options.disconnectGate.promise;};
  const session=new NetworkGameSession({peer,identity:request.loginIdentity??identity(),build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{close(){}},language:0,decodeMessage:value=>value,openModule:async()=>({}),loadRules:async()=>({}),persistCharacter:request.persistCharacter});
  const row={session,peer,packets,connections};sessions.push(row);return {session,metadata:{connectionType:16,name:request.name}};
 };
 const lobby=new NativeLobby({listLocal:async()=>[],connect:async()=>{},publish:message=>sent.push(message),disconnect:value=>api.disconnect(value),save:()=>lobby.session.exportCharacter()});lobby.connection=1;
 const nativeClockBridge={attach:(s,c)=>{clock.push({kind:'attach',session:s,connection:c});return {attached:true};},retire:(s,c)=>{assert.notEqual(s,null,'Host must not retire a null clock owner');clock.push({kind:'retire',session:s,connection:c});}};
 const vault={save:async(message,{id})=>{const entered={id,session:api.hostState().session,value:message.authored};saves.push(entered);if(options.saveGate)await options.saveGate.promise;return {id:id??'allocated-'+(++index),name:'Authored save'};}};
 api=evaluate({lobby,policy:new ServerEndpointPolicy({allowed:[{host:'127.0.0.1',port:5122}]}),report,vault,createInstalledNetworkSession,NativeDirectPortal,nativeClockBridge,worldDeltas:{reset(){}},sendForConnection:(connection,value)=>sent.push({...value,connection}),path,install:'authored-base',userDirectory:'authored-user',cacheDirectory:'authored-cache',startup:{settings:{modsDirectory:'wrong-global-mods',disabledMods:['wrong-global']}},characterPreviewStore:{encode(){throw Error('No preview preparation in this test');}}});
 const initial=await api.createSession({install:'authored-install',host:'127.0.0.1',port:5121,name:'Authored account',userDirectory:'session-user',cacheDirectory:'session-cache',modsDirectory:'session-mods',disabledMods:['session-disabled']},1);
 api.initialAttach(initial,1);const ready=s=>{s.phase='playing';s.characterConfirmed=true;s.characterSubmitted=true;s.areaReadySent=true;s.publish();};ready(initial.session);
 const begin=()=>initial.session.receive({kind:'portal-activate',host:'127.0.0.1',port:5122,password:'authored-password',waypoint:'Arrival',seamless:false});
 const release=async()=>{await initial.session.receive({kind:'portal-character',source:17,resref:'authored'});await tick();await api.directPortal.settled();};
 t.after(async()=>{options.factoryGate?.resolve();options.saveGate?.resolve();options.disconnectGate?.resolve();await api.directPortal.dispose();await Promise.allSettled(sessions.map(row=>row.session.disconnect()));await tick();assert.equal(hash(fs.readFileSync(hostFile)),hostSha256,'Read-only Host source unchanged through gate');});
 return {api,lobby,report,initial,sessions,sent,clock,saves,factoryRequests,ready,begin,release};
}

test('actual factory keeps sanitized private config, deferred NUI and per-session source descriptor',async t=>{
 const f=await fixture(t),s=f.initial.session;assert.equal(s.deferNuiResources,true);assert.equal(f.api.stateOf(s).connection,1);assert.equal(f.api.configOf(s).name,'Authored account');assert.equal(Object.hasOwn(f.api.configOf(s),'loginIdentity'),false);assert.equal(Object.hasOwn(f.api.configOf(s),'credentials'),false);
 s.resourceResult={resolved:[]};const descriptor=f.api.sourceDescriptor(s);assert.equal(descriptor.modsDirectory,'session-mods');assert.equal(descriptor.profileDirectory,'session-user');assert.deepEqual([...descriptor.disabledMods],['session-disabled']);assert.equal(f.clock[0].session,s);
});

test('actual install refreshes origin vault identity assigned after prepare and binds before connect',async t=>{
 const options={},f=await fixture(t,options);await f.begin();const destination=f.sessions[1].session;assert.equal(f.api.stateOf(destination).vaultId,null);
 const first=await f.initial.session.persistCharacter({authored:'origin first save'});assert.equal(first.id,'allocated-1');assert.equal(f.api.stateOf(f.initial.session).vaultId,'allocated-1');assert.equal(f.api.stateOf(destination).vaultId,null);
 await f.release();assert.equal(f.api.stateOf(destination).vaultId,'allocated-1');const connection=f.sessions[1].connections[0];assert.equal(connection.bound,2);assert.equal(connection.host,destination);assert.equal(connection.lobby,destination);assert.equal(connection.clock,destination);
 const wait=gate();options.saveGate=wait;const save=destination.persistCharacter({authored:'destination save'});await until(()=>f.saves.length===2);f.lobby.vaultId='later-global-ui-row';wait.resolve();await save;assert.equal(f.saves.at(-1).id,'allocated-1');assert.equal(f.api.stateOf(destination).vaultId,'allocated-1');
});

test('actual invalid Play/Cancel/disconnect prevalidation cannot poison persistence or detach',async t=>{
 const f=await fixture(t),s=f.initial.session;f.api.stateOf(s).vaultId='private-original';f.lobby.vaultId=null;f.lobby.locals.set('foreign',{key:'foreign',source:'vault',vaultId:'must-not-overwrite'});
 await assert.rejects(f.api.command({kind:'lobby-play',connection:1,key:'foreign'}),/unavailable/);assert.equal(f.api.stateOf(s).vaultId,'private-original');
 await assert.rejects(f.api.command({kind:'lobby-cancel-join',connection:1}),/No connection/);await assert.rejects(f.api.command({kind:'lobby-disconnect',connection:1,saveCharacter:'invalid'}),/Invalid disconnect/);
 assert.equal(f.api.directPortal.snapshot().boundConnection,1);assert.equal(f.api.hostState().session,s);assert.equal(s.closed,false);assert.equal(f.api.stateOf(s).vaultId,'private-original');
});

test('actual normal leave captures vault identity before detach and permits final detached save',async t=>{
 const f=await fixture(t),s=f.initial.session;f.lobby.vaultId='selected-vault';s.exportCharacter=()=>s.persistCharacter({authored:'save on leave'});
 await f.api.command({kind:'lobby-disconnect',connection:1,saveCharacter:true});assert.equal(f.lobby.connection,2);assert.equal(f.saves[0].id,'selected-vault');assert.equal(f.saves[0].session,null);assert.equal(f.api.hostState().session,null);assert.equal(s.closed,true);assert.equal(f.lobby.snapshot().canJoin,true);
 assert.ok(f.sent.some(message=>message.kind==='session-reset'&&message.connection===2));assert.equal(f.clock.filter(v=>v.kind==='retire').length,1);
});

test('actual command cancel enters Lobby barrier before delayed destination cleanup',async t=>{
 const pending=gate(),f=await fixture(t,{disconnectGate:pending});await f.begin();
 // Origin release also uses this mock peer gate; lift it for the portal handoff.
 pending.resolve();await f.release();const destination=f.sessions[1].session,delay=gate(),disconnect=destination.peer.disconnect;destination.peer.disconnect=async()=>{await disconnect();await delay.promise;};
 const work=f.api.command({kind:'lobby-cancel-join',connection:2});await until(()=>destination.closed);assert.equal(f.lobby.connection,3);assert.equal(f.lobby.busy,true);assert.equal(f.lobby.snapshot().canJoin,false);delay.resolve();await work;assert.equal(f.lobby.snapshot().canJoin,true);
});

test('actual attach guards late origin messages/state and retire never targets null owner',async t=>{
 const f=await fixture(t);await f.begin();await f.release();const before=f.sent.length,states=f.report.states.length;
 f.initial.session.emit('state',{phase:'playing'});f.initial.session.emit('message',{message:{kind:'server-speech',channel:1,text:'late'},areaGeneration:0});assert.equal(f.sent.length,before);assert.equal(f.report.states.length,states);
 const destination=f.sessions[1].session;f.api.retirePresentation(f.initial.session,2);assert.equal(f.api.hostState().session,destination);f.api.retirePresentation(destination,2);f.api.retirePresentation(null,2);assert.equal(f.clock.some(value=>value.session===null),false);
});

test('actual failed destination uses scoped synchronous reset and leaves a joinable Lobby',async t=>{
 const f=await fixture(t,{connectFailure:true});await f.begin();await f.release().catch(()=>{});assert.equal(f.lobby.phase,'menu');assert.equal(f.lobby.snapshot().canJoin,true);assert.equal(f.api.hostState().session,null);assert.equal(f.sessions[1].session.closed,true);
});

test('actual factory rejects retired ownership before publishing private context',async t=>{
 const f=await fixture(t);await assert.rejects(f.api.createSession({install:'authored',name:'retired'},2,{owned:()=>false}),/Cancelled native session/);const rejected=f.sessions.at(-1).session;assert.equal(rejected.closed,true);assert.equal(f.api.stateOf(rejected),undefined);assert.equal(f.api.configOf(rejected),undefined);assert.equal(f.api.hostState().session,f.initial.session);
});

test('actual Host closure source identity is retained',()=>{assert.equal(hash(fs.readFileSync(hostFile)),hostSha256);assert.equal(hostSha256.length,64);});
