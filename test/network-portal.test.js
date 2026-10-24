import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {EventEmitter} from 'node:events';
import {NativeMessageWriter} from '../src/native_message.js';
import {encodeGffText} from '../src/gff_text.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {portalEndpoint,portalCharacterRequest} from '../src/network_portal.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkLoginIdentity} from '../electron/network_login_identity.mjs';
import {serverCharacterPlayRequest} from '../src/network_character_selection.js';
import {loginWaypointResponse} from '../src/network_runtime_messages.js';
import {writeGff,gffRecord} from '../src/gff_writer.js';
import {NetworkFrontend} from '../src/network_frontend.js';

const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-portal-v1.json',import.meta.url)));
const packet=(major,minor,write)=>{const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,major,minor));return Uint8Array.from(w.getWriteMessage().data);};
const text=(w,value)=>w.writeStringBytes(encodeGffText(value));
const reference=(resref='yrs',account=true)=>packet(43,3,w=>{text(w,resref);w.writeBool(account);});
const activation=(password='')=>Uint8Array.from(Buffer.from(oracle.cases.find(r=>r.fields.host==='127.0.0.1:5122'&&r.fields.seamless&&r.fields.waypoint==='Arrival'&&r.fields.password===password).packet,'hex'));
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function harness(options={}){
 const peer=new EventEmitter(),sent=[],events=[],diagnostics=[];let resourcesClosed=0,identityDisposed=0,peerClosed=0;
 peer.connect=async()=>({build:{number:8193,revision:37,postfix:17}});peer.sendGameMessage=async bytes=>sent.push(Uint8Array.from(bytes));
 peer.disconnect=async()=>{if(!peerClosed++){peer.emit('closed');}};
 const resources={close:()=>resourcesClosed++};
 const session=new NetworkGameSession({peer,identity:{dispose:()=>identityDisposed++},build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources,language:0,openModule:async()=>({}),loadRules:async()=>({}),onDiagnostic:d=>diagnostics.push(d),...options});
 session.on('message',e=>events.push(e));
 return{peer,sent,session,events,diagnostics,resources,counts:()=>({resourcesClosed,identityDisposed,peerClosed}),deliver:async bytes=>{peer.emit('message',bytes);await session.delivery;await tick();}};
}
function ready(s){s.phase='playing';s.characterConfirmed=true;s.characterSubmitted=true;s.areaReadySent=true;}

test('complete original portal writer and parser agree with replacement, including default port and seamless flag',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,16);
 for(const {packet:hex,fields}of oracle.cases){const p=Uint8Array.from(Buffer.from(hex,'hex')),v=decodeServerGameMessage(p);assert.deepEqual(v,{kind:'portal-activate',...portalEndpoint(fields.host),password:fields.password,waypoint:fields.waypoint,seamless:Boolean(fields.seamless),major:42,minor:1});for(let n=3;n<p.length;n++)assert.throws(()=>decodeServerGameMessage(p.subarray(0,n)));assert.throws(()=>decodeServerGameMessage(Uint8Array.from([...p,0,0])));}
 assert.equal(Buffer.from(portalCharacterRequest()).toString('hex'),oracle.downloadRequest);
 for(const address of ['https://example.org','host:0','host:65536','host:','../host','host\0:5121','host:1:2',''])assert.throws(()=>portalEndpoint(address));
 assert.deepEqual(portalEndpoint('example.org'),{host:'example.org',port:5121});
});

test('portal character reply preserves server-vault type and local BIC, rejecting malformed fields',()=>{
 assert.equal(oracle.characters.length,4);for(const row of oracle.characters){const v=decodeServerGameMessage(Uint8Array.from(Buffer.from(row.packet,'hex')));assert.equal(v.resref,row.resref);assert.equal(v.source,row.accountVault?17:2);}
 for(const account of [false,true]){const p=reference('yrs',account),v=decodeServerGameMessage(p);assert.equal(v.source,account?17:2);assert.equal(v.resref,'yrs');for(let n=3;n<p.length;n++)assert.throws(()=>decodeServerGameMessage(p.subarray(0,n)));}
 assert.throws(()=>decodeServerGameMessage(reference('../escape')));
 const bic=writeGff('BIC ',gffRecord({})),p=packet(43,2,w=>{w.writeBool(false);text(w,'Yrs');w.writeBool(false);text(w,'');w.writeDword(bic.length);w.rawBytes(bic);});
 assert.deepEqual(decodeServerGameMessage(p).data,bic);assert.throws(()=>decodeServerGameMessage(p.subarray(0,-2)));
});

test('handoff downloads before disconnect, starts a fresh session and never forwards secrets or stale world state',async()=>{
 const next=harness({loginWaypoint:'Arrival'}),options=[],old=harness({preparePortal:async portal=>{options.push({...portal});return{session:next.session,metadata:{fixture:true}};}});ready(old.session);
 old.session.world.apply({kind:'tlk-overrides',entries:[{strRef:1,text:'Old server'}]});old.session.world.nui.apply({kind:'nui-create',token:7,layout:{},format:1});old.session.resolver={oldServer:true};
 const transfers=[];old.session.on('portal-ready',event=>transfers.push(event));
 await old.deliver(activation('fixture-only'));assert.equal(old.session.phase,'transferring');assert.deepEqual(old.sent,[portalCharacterRequest()]);assert.equal(old.counts().peerClosed,0);assert.equal(transfers.length,0);
 await old.deliver(activation());assert.equal(options.length,1);assert.equal(old.sent.length,1);
 await old.deliver(reference());assert.equal(old.counts().peerClosed,1);assert.equal(old.session.closed,true);assert.equal(transfers.length,1);assert.equal(next.session.closed,false);assert.deepEqual(next.session.portalCharacter,{source:17,resref:'yrs'});assert.equal(next.session.world.tlkOverrides.size,0);assert.equal(next.session.world.nui.windows.size,0);assert.equal(next.session.resolver,undefined);assert.deepEqual(old.counts(),{resourcesClosed:1,identityDisposed:1,peerClosed:1});assert.equal(old.events.length,0);assert.ok(!JSON.stringify(old.diagnostics).includes('fixture-only'));
 const requirements={kind:'server-resources',requirements:{haks:[],customTlk:'',nwmResourceName:'',advertisement:null}};next.session.decodeMessage=m=>m;next.session.resources.findFile=async()=>null;next.session.resourceResult={ready:true};
 // Exercise the production admission branch with an empty resource declaration.
 await next.session.receive(requirements);assert.deepEqual(next.sent[0],serverCharacterPlayRequest({source:17,resref:'yrs'}));assert.equal(next.session.characterSubmitted,true);assert.equal(next.session.serverCharacterListPending,undefined);
 await next.session.receive({kind:'login-waypoint-request'});assert.deepEqual(next.sent.at(-1),loginWaypointResponse('Arrival'));assert.equal(next.session.loginWaypoint,'');await next.session.disconnect();
});

test('cancelling while destination setup is pending disposes its eventual session without logging in',async()=>{
 let resolve;const prepared=new Promise(r=>resolve=r),next=harness(),old=harness({preparePortal:()=>prepared});ready(old.session);
 old.peer.emit('message',activation());await tick();await old.session.disconnect();resolve({session:next.session,metadata:{}});await old.session.delivery;assert.equal(next.session.closed,true);assert.equal(old.sent.length,0);assert.equal(next.sent.length,0);
});

test('missing character and a handoff timeout fail explicitly and dispose the prepared destination',async()=>{
 for(const mode of ['missing','timeout']){const next=harness(),old=harness({preparePortal:async()=>({session:next.session,metadata:{}}),portalTimeoutMs:mode==='timeout'?10:1000});ready(old.session);await old.deliver(activation());if(mode==='missing')old.peer.emit('closed');await new Promise(r=>setTimeout(r,25));assert.equal(old.session.closed,true);assert.equal(next.session.closed,true);assert.equal(old.diagnostics.at(-1).code,'network.portal-failed');}
});

test('portal identity keeps key/community identity while replacing only destination password',()=>{
 const key='ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-ZABCD-EFGHI',old=new NetworkLoginIdentity({cdKey:key,password:'old-password',communityPassword:'community'}),next=old.forPortal('destination-password'),challenge={kind:'challenge',keyChallenge:'key',communityChallenge:'community',passwordChallenge:'password',passwordRequired:true},a=old.respond(challenge),b=next.respond(challenge);
 assert.equal(a.keyResponse,b.keyResponse);assert.equal(a.communityResponse,b.communityResponse);assert.notEqual(a.passwordResponse,b.passwordResponse);old.dispose();assert.equal(next.respond(challenge).keyResponse,b.keyResponse);assert.ok(!JSON.stringify(next).includes('password'));next.dispose();
});

test('local-vault handoff uploads only the downloaded BIC and zeros the transient buffers',async()=>{
 const next=harness({decodeMessage:m=>m}),old=harness({preparePortal:async()=>({session:next.session,metadata:{}})});ready(old.session);await old.deliver(activation());
 const bic=writeGff('BIC ',gffRecord({})),reply=packet(43,2,w=>{w.writeBool(false);text(w,'Yrs');w.writeBool(false);text(w,'');w.writeDword(bic.length);w.rawBytes(bic);});await old.deliver(reply);
 const owned=next.session.character;assert.deepEqual(owned,bic);assert.equal(next.session.portalCharacter,undefined);
 await next.session.receive({kind:'server-resources',requirements:{haks:[],customTlk:'',nwmResourceName:'',advertisement:null}});
 assert.equal(next.sent.length,1);assert.deepEqual([...next.sent[0].subarray(0,3)],[112,2,1]);assert.ok(owned.every(b=>b===0));assert.equal(next.session.character,null);await next.session.disconnect();
});

test('frontend replaces world/text/panels on the new connection and skips old queued work',async()=>{
 let enters=0,exits=0;const frontend=Object.assign(Object.create(NetworkFrontend.prototype),{id:null,queue:Promise.resolve(),canEnter(){},onEnter(){enters++;},onExit(){exits++;},onState(){},bridge:{},status:{},button:{},showError:e=>{throw e;}});
 const state=(sessionId,phase,closed=false)=>frontend.receive({sessionId,kind:'state',state:{phase,closed}});
 state('old','connecting');const oldWorld=frontend.world,oldText=frontend.text;oldWorld.apply({kind:'tlk-overrides',entries:[{strRef:1,text:'Old description'}]});
 frontend.receive({sessionId:'old',kind:'message',message:{kind:'custom-token',id:1,text:'queued old token'}});
 state('old','closed',true);state('new','connecting');await frontend.queue;
 assert.equal(frontend.id,'new');assert.equal(enters,2);assert.equal(exits,0);assert.notEqual(frontend.world,oldWorld);assert.notEqual(frontend.text,oldText);assert.equal(frontend.world.tlkOverrides.size,0);assert.deepEqual(frontend.world.customTokens.records,[]);
 frontend.receive({sessionId:'old',kind:'message',message:{kind:'nui-create',token:4,format:1,layout:{}}});assert.equal(frontend.world.nui.windows.size,0);
});
