import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeMessageReader} from '../src/native_message.js';
import {journalGuiEventRequest,NativeJournalEvents} from '../src/network_journal_events.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};};
function fields(bytes,position=true){
 assert.deepEqual([...bytes.subarray(0,3)],[112,53,1]);const reader=new NativeMessageReader(1),body=bytes.subarray(3);assert.equal(reader.setReadMessage(body,body.length,0xffffffff,1),1);
 const value={event:reader.readWord(),selection:reader.readWord(),target:reader.readObjectIdClient()};if(position)value.position=[reader.readFloat(),reader.readFloat(),reader.readFloat()];
 assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);return value;
}
const labels=sent=>sent.map(packet=>packet[1]===28?'subscription'+packet[2]:'GUI'+fields(packet).event);
function harness(){
 const events=new NativeJournalEvents(),scope={world:{},peer:{},actor:{},areaId:55,areaGeneration:1},sent=[];let current=true;
 const io={assertCurrent(){if(!current)throw Error('Retired fixture scope');},async send(packet){sent.push(packet);}};
 const request=(open,journalLifetime=1,extra={})=>events.transition({open,journalLifetime,includePosition:true,scope,...extra},io);
 return{events,scope,sent,io,request,retire(){current=false;}};
}
test('journal GUI10/11 have original zero selection, invalid target and versioned zero XYZ',()=>{
 for(const open of [false,true])for(const includePosition of [false,true])assert.deepEqual(fields(journalGuiEventRequest({open,includePosition}),includePosition),{event:open?10:11,selection:0,target:0x7f000000,...(includePosition?{position:[0,0,0]}:{})});
 for(const open of [undefined,null,0,1,'true'])assert.throws(()=>journalGuiEventRequest({open,includePosition:true}));
 for(const includePosition of [undefined,null,0,1,'true'])assert.throws(()=>journalGuiEventRequest({open:true,includePosition}));
});
test('one logical lifetime emits ordered pairs; duplicates and closed-owner replay cannot notify twice',async()=>{
 const h=harness();assert.deepEqual(await h.request(true),{sent:true});assert.deepEqual(await h.request(true),{sent:false,duplicate:true});assert.deepEqual(await h.request(false),{sent:true});assert.deepEqual(await h.request(false),{sent:false,duplicate:true});
 await assert.rejects(h.request(true),/retired/);await h.request(true,2);await assert.rejects(h.request(false,1),/retired/);await h.request(false,2);
 assert.deepEqual(labels(h.sent),['subscription10','GUI10','GUI11','subscription11','subscription10','GUI10','GUI11','subscription11']);
});
test('rapid accepted close and reopen serialize complete original pairs without crossing owners',async()=>{
 const h=harness(),gate=deferred();h.io.send=async packet=>{h.sent.push(packet);if(h.sent.length===1)await gate.promise;};
 const first=h.request(true),close=h.request(false),next=h.request(true,2),last=h.request(false,2);await turn();assert.equal(h.sent.length,1);gate.resolve();await Promise.all([first,close,next,last]);
 assert.deepEqual(labels(h.sent),['subscription10','GUI10','GUI11','subscription11','subscription10','GUI10','GUI11','subscription11']);
});
test('disconnect/cancel after an awaited send suppresses its remaining packet and never disconnects a peer',async()=>{
 const h=harness(),gate=deferred();h.io.send=async packet=>{h.sent.push(packet);await gate.promise;};const pending=h.request(true);await turn();h.retire();gate.resolve();await assert.rejects(pending,/Retired/);assert.deepEqual(labels(h.sent),['subscription10']);
});
test('new scope with reused IDs starts immediately and cannot inherit the old owner tail',async()=>{
 const h=harness(),gate=deferred();h.io.send=async packet=>{h.sent.push(packet);if(h.sent.length===1)await gate.promise;};const old=h.request(true);await turn();
 const scope={...h.scope,actor:{}};await h.request(true,1,{scope});gate.resolve();await assert.rejects(old,/retired/);
 assert.deepEqual(labels(h.sent),['subscription10','subscription10','GUI10']);
});
test('a reset superseding an unclosed logical owner cancels the old pending GUI tail',async()=>{
 const h=harness(),gate=deferred();h.io.send=async packet=>{h.sent.push(packet);if(h.sent.length===1)await gate.promise;};const old=h.request(true);await turn();const next=h.request(true,3);gate.resolve();await assert.rejects(old,/retired/);await next;assert.deepEqual(labels(h.sent),['subscription10','subscription10','GUI10']);
});
test('malformed/missing lifetimes and queue saturation are bounded without automatic retry',async()=>{
 const h=harness();for(const id of [undefined,null,false,0,-1,1.5,'1',NaN,Number.MAX_SAFE_INTEGER+1])await assert.rejects(h.events.transition({open:true,journalLifetime:id,includePosition:true,scope:h.scope},h.io),/lifetime/);
 const gate=deferred();h.io.send=async packet=>{h.sent.push(packet);await gate.promise;};const pending=[];for(let id=1;id<=32;id++){pending.push(h.request(true,id));pending.push(h.request(false,id));}
 await assert.rejects(h.request(true,33),/queue is full/);gate.resolve();await Promise.all(pending);assert.equal(h.sent.length,128);
});
test('send failure affects the observer request and does not retry or mutate its scope',async()=>{
 const h=harness(),before={...h.scope};let sends=0;h.io.send=async()=>{sends++;throw Error('Authored transport failure');};await assert.rejects(h.request(true),/transport failure/);await turn();assert.equal(sends,1);assert.deepEqual(h.scope,before);
});
test('the fixed pending cap also covers retained slow scopes, rather than multiplying per scope',async()=>{
 const h=harness(),gate=deferred(),pending=[];h.io.send=async packet=>{h.sent.push(packet);await gate.promise;};
 for(let index=0;index<64;index++){pending.push(h.request(true,1,{scope:{...h.scope,actor:{}}}));await turn();}
 await assert.rejects(h.request(true,1,{scope:{...h.scope,actor:{}}}),/queue is full/);
 const completed=Promise.allSettled(pending);gate.resolve();assert.ok((await completed).every(row=>row.status==='rejected'));assert.equal(h.sent.length,64);
 await h.request(true,2);assert.equal(h.sent.length,66);
});
function sessionHarness(){
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async packet=>sent.push(Uint8Array.from(packet));peer.disconnect=async()=>peer.emit('closed');
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:2},dispose(){}},resources:{},language:0,openModule:async()=>null});
 const actor={id:0xffffffce,areaId:0x80000001,objectType:5};session.phase='playing';session.areaReadySent=true;session.areaGeneration=2;session.world.areaId=actor.areaId;session.world.localObjectId=actor.id;session.world.registry.addObjectAtPos(actor.id,actor);
 const request={areaId:actor.areaId,areaGeneration:2,actorId:actor.id,panel:'journal',open:true,journalLifetime:1};return{session,actor,peer,sent,request};
}
test('the real session keeps legacy subscription-only callers and the existing packet bytes',async()=>{
 const h=sessionHarness(),legacy={...h.request};delete legacy.journalLifetime;await h.session.hudPanel(legacy);await h.session.hudPanel({...legacy,open:false});assert.deepEqual(h.sent.map(p=>[...p]),[[112,28,10],[112,28,11]]);await h.session.disconnect();
});
test('the real session sends native lifetime pairs for both build formats and preserves raw actor data',async()=>{
 const h=sessionHarness(),before=structuredClone(h.actor);
 for(const revision of [34,35]){
  h.session.serverBuild={number:8193,revision,postfix:0};const journalLifetime=revision;
  await h.session.hudPanel({...h.request,journalLifetime});await h.session.hudPanel({...h.request,open:false,journalLifetime});
  for(const [index,event] of [[h.sent.length-3,10],[h.sent.length-2,11]])assert.deepEqual(fields(h.sent[index],revision>=35),{event,selection:0,target:0x7f000000,...(revision>=35?{position:[0,0,0]}:{})});
 }
 assert.deepEqual(h.actor,before);assert.equal(h.sent.length,8);await h.session.disconnect();
});
test('real session rejects malformed native lifetimes and stale owner/area/control before any packet',async()=>{
 const h=sessionHarness();for(const value of [null,false,0,-1,'1',1.1,Number.MAX_SAFE_INTEGER+1])await assert.rejects(h.session.hudPanel({...h.request,journalLifetime:value}));
 for(const changed of [{actorId:0},{areaId:0},{areaGeneration:1},{open:1}])await assert.rejects(h.session.hudPanel({...h.request,...changed}));assert.equal(h.sent.length,0);await h.session.disconnect();
});
test('real session rechecks cancellation, area, peer, world and same-ID actor replacement after its first await',async()=>{
 for(const kind of ['closed','area','peer','world','actor']){
  const h=sessionHarness(),gate=deferred(),world=h.session.world;h.peer.sendGameMessage=async packet=>{h.sent.push(packet);await gate.promise;};const pending=h.session.hudPanel(h.request);await turn();
  if(kind==='closed')h.session.closed=true;
  else if(kind==='area')h.session.areaGeneration++;
  else if(kind==='peer')h.session.peer={};
  else if(kind==='world')h.session.world={};
  else{h.session.world.registry.delete(h.actor.id);h.session.world.registry.addObjectAtPos(h.actor.id,{...h.actor});}
  gate.resolve();await assert.rejects(pending);assert.deepEqual(h.sent.map(p=>[...p]),[[112,28,10]]);h.session.closed=false;h.session.peer=h.peer;h.session.world=world;await h.session.disconnect();
 }
});
