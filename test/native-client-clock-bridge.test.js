import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import bridgeModule from '../godot-client/tools/native-clock-bridge.cjs';

const {NativeClockBridge}=bridgeModule;
const ID=0x80000042,OTHER=ID+1,AREA=0x80000001,BUILD={number:8193,revision:37,postfix:17};
const A=(id=ID)=>({action:'create',objectType:5,id,state:{areaId:AREA}});
const D=(bit=0,id=ID)=>({action:'delete',objectType:5,id,remove:bit});
const P=(id=ID)=>({action:'appearance',objectType:5,id,mask:0x400,state:{name:{text:'Before A'}}});
const objects=(records,complete=true)=>({kind:'object-updates',records,complete});
function packet(mask=2,value=1,ids=[ID,ID,0x7f000000]){
 const writer=new NativeMessageWriter(1);writer.create(2+ids.length*4,0xffffffff,1);writer.writeByte(mask,2,1);writer.writeBool(value);writer.writeWord(ids.length,16);
 for(const id of ids)writer.writeObjectIdClient(id);writer.setPrefix(Uint8Array.of(80,3,9));return Uint8Array.from(writer.getWriteMessage().data);
}
function session(){
 const peer=new EventEmitter(),sent=[],diagnostics=[];
 peer.connect=async()=>({build:BUILD});peer.sendGameMessage=async value=>{sent.push(value);};peer.disconnect=async()=>peer.emit('closed');
 const s=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:BUILD,dispose(){}},resources:{close(){},findFile(){throw Error('No resource admission in this fixture');}},language:0,openModule:async()=>{throw Error('No catalog wait in clock bridge');},onDiagnostic:value=>diagnostics.push(value),decodeMessage:(value,options)=>value instanceof Uint8Array?decodeServerGameMessage(value,options):value});
 return {s,peer,sent,diagnostics,async deliver(value){peer.emit('message',value);await s.delivery;},close(){s.finish();}};
}
function harness(){
 const frames=[],lines=[];let current=null,connection=null,outcome={status:'accepted'};
 const bridge=new NativeClockBridge({send(frame,line){frames.push(frame);lines.push(line);return outcome;},isCurrent:(s,c)=>s===current&&c===connection});
 return {bridge,frames,lines,select(s,c){current=s;connection=c;},setOutcome(value){outcome=value;}};
}
const types=h=>h.frames.map(frame=>frame.event.type);

test('real Session attach binds/begins before connect and delivers pre-catalog clock events before later UI',async()=>{
 const h=harness(),s=session();h.select(s.s,3);
 const attached=h.bridge.attach(s.s,3);assert.equal(attached.attached,true);assert.deepEqual(types(h),['begin']);
 const ui=[];s.s.on('message',event=>ui.push({kind:event.message.kind,clockTypes:types(h)}));
 s.peer.connect=async()=>{assert.deepEqual(types(h),['begin']);assert.equal(s.s.world.nativeClockLifecycleHistory().connection,3);return {build:BUILD};};
 await s.s.connect({metadata:{connectionType:16}});
 await s.deliver({kind:'module-info',module:{minutesPerHour:30,resource:'Must not be transported'}});
 await s.deliver({kind:'module-time',mask:5,changes:{year:123,hour:4}});
 await s.deliver(packet());
 const records=[A()];await s.deliver(objects(records));
 assert.deepEqual(types(h),['begin','module-info','module-time','module-pause-state','accepted-lifecycle']);
 assert.equal(s.s.resolver,undefined);assert.equal(s.s.resourceResult,undefined);assert.equal(s.s.phase,'resources');
 assert.equal(ui.at(-1).clockTypes.at(-1),'accepted-lifecycle');assert.equal(ui[0].clockTypes.at(-1),'module-info');
 assert.equal(h.frames.at(-1).event.constructionCertified,true);assert.ok(h.frames.every(frame=>frame.history.complete));
 assert.deepEqual(h.frames[1].event,{type:'module-info',minutesPerHour:30});assert.deepEqual(h.frames[2].event,{type:'module-time',mask:5});
 assert.equal(s.sent.length,1,'Only MockPeer connect server-status command was sent');
 h.bridge.retire(s.s,3);s.close();
});

test('unknown birth from actual P before A does not poison later native writer/decoder pause coverage',async()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);
 await s.deliver(objects([P(),A()]));await s.deliver(packet(3,3));
 const fact=h.frames.find(frame=>frame.event.type==='accepted-lifecycle');
 assert.equal(fact.event.constructionCertified,false);assert.equal(fact.event.physicalToken,null);assert.equal(fact.event.constructionHistoryComplete,false);assert.equal(fact.history.complete,true);
 assert.deepEqual(h.frames.at(-1).event,{type:'module-pause-state',mask:3,value:1,exclusionIds:[ID,ID,0x7f000000]});assert.equal(h.frames.at(-1).history.complete,true);
 h.bridge.retire(s.s,3);s.close();
});

test('real Session A/D/A private facts preserve order before UI can mutate received DTOs',async()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);
 s.s.on('message',({message})=>{if(message.kind==='object-updates'){assert.equal(h.frames.filter(frame=>frame.event.type==='accepted-lifecycle').length,3);message.records.length=0;}});
 await s.deliver(objects([A(),D(1),A()]));
 const facts=h.frames.filter(frame=>frame.event.type==='accepted-lifecycle');
 assert.deepEqual(facts.map(frame=>frame.event.operation),['create','remove','create']);assert.deepEqual(facts.map(frame=>frame.event.recordIndex),[0,1,2]);
 assert.deepEqual(facts.map(frame=>frame.event.constructionHistoryComplete),[true,true,false]);assert.equal(facts[1].event.deletionFlag,1);assert.ok(facts.every(frame=>frame.history.complete));
 h.bridge.retire(s.s,3);s.close();
});

test('explicit accepted Node backpressure never queues or repeats the Session event',async()=>{
 const h=harness(),s=session();h.setOutcome({status:'accepted',backpressure:true});h.select(s.s,3);h.bridge.attach(s.s,3);
 await s.deliver(packet());h.bridge.flush(s.s,3);h.bridge.flush(s.s,3);
 assert.deepEqual(types(h),['begin','module-pause-state']);assert.equal(h.bridge.snapshot().ingress.queuedFrames,0);assert.equal(h.bridge.snapshot().ingress.counts.backpressure,2);
 h.bridge.retire(s.s,3);s.close();
});

test('known-unwritten pre-socket queue flushes FIFO; retire clears queue and exact listeners',async()=>{
 const h=harness(),s=session();h.setOutcome({status:'unavailable'});h.select(s.s,3);h.bridge.attach(s.s,3);
 await s.deliver(packet());assert.equal(h.bridge.snapshot().ingress.queuedFrames,2);
 const before=h.frames.length;h.setOutcome({status:'accepted'});h.bridge.flush(s.s,3);
 assert.deepEqual(h.frames.slice(before).map(frame=>frame.serial),[1,2]);assert.equal(h.bridge.snapshot().ingress.queuedFrames,0);
 const listeners=s.s.listeners('message');assert.equal(listeners.length,1);const captured=listeners[0];
 assert.equal(h.bridge.retire(s.s,3).retired,true);assert.equal(s.s.listenerCount('message'),0);assert.equal(s.s.listenerCount('diagnostic'),0);assert.equal(s.s.listenerCount('closed'),0);
 const written=h.frames.length;captured({message:decodeServerGameMessage(packet()),areaGeneration:0});assert.equal(h.frames.length,written);assert.equal(h.bridge.snapshot().attached,false);
 s.close();
});

test('retire with queued facts does not send them or disconnect the actual session',async()=>{
 const h=harness(),s=session();h.setOutcome({status:'unavailable'});h.select(s.s,3);h.bridge.attach(s.s,3);await s.deliver(packet());
 const attempts=h.frames.length;assert.deepEqual(h.bridge.retire(s.s,3),{retired:true,discardedFrames:2});assert.equal(s.s.closed,false);
 h.setOutcome({status:'accepted'});assert.equal(h.bridge.flush(s.s,3).reason,'stale-session');assert.equal(h.frames.length,attempts);s.close();
});

test('reconnect retires old listeners/queue and stale callbacks cannot target the new connection',async()=>{
 const h=harness(),old=session(),next=session();h.select(old.s,3);h.bridge.attach(old.s,3);const captured=old.s.listeners('message')[0];
 h.select(next.s,4);assert.equal(h.bridge.attach(next.s,4).attached,true);assert.equal(old.s.listenerCount('message'),0);
 const start=h.frames.length;captured({message:decodeServerGameMessage(packet()),areaGeneration:0});old.s.emit('message',{message:decodeServerGameMessage(packet()),areaGeneration:0});
 assert.equal(h.frames.length,start);assert.deepEqual(h.bridge.retire(old.s,3),{retired:false});
 await next.deliver(objects([A()]));assert.equal(h.frames.at(-1).connection,4);assert.equal(h.frames.at(-1).serial,2);
 assert.equal(h.bridge.attach(old.s,3).attached,false);assert.equal(h.bridge.snapshot().connection,4);h.bridge.retire(next.s,4);old.close();next.close();
});

test('same attach is idempotent; externally stale selection rejects event and cannot clear history',async()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);
 assert.deepEqual(h.bridge.attach(s.s,3),{attached:true,reused:true});assert.equal(s.s.listenerCount('message'),1);assert.equal(h.frames.length,1);
 h.select(null,null);await s.deliver(packet());assert.equal(h.frames.length,1);
 assert.equal(h.bridge.flush(s.s,3).reason,'stale-session');h.bridge.retire(s.s,3);s.close();
});

test('real decoder failure taints coverage before later valid pause without awaiting UI/catalog',async()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);
 const good=packet();await s.deliver(good.subarray(0,good.length-1));await s.deliver(good);
 assert.equal(s.diagnostics[0].code,'network.game-message-invalid');assert.equal(h.frames.at(-1).event.type,'module-pause-state');assert.equal(h.frames.at(-1).history.complete,false);
 assert.equal(h.bridge.snapshot().ingress.history.reason,'decoder-rejected');h.bridge.retire(s.s,3);s.close();
});

test('actual incomplete object prefix keeps later pause false and does not fabricate a constructor',async()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);
 await s.deliver({...objects([A()],false),unhandled:{tag:'?',reason:'Authored partial prefix'}});await s.deliver(packet());
 assert.equal(h.frames.find(frame=>frame.event.type==='accepted-lifecycle').event.constructionCertified,false);
 assert.equal(h.frames.at(-1).history.complete,false);assert.equal(h.bridge.snapshot().ingress.history.reason,'incomplete-records');h.bridge.retire(s.s,3);s.close();
});

test('forged raw lifecycle DTO event cannot bypass actual World private boundary lookup',()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);
 const records=[{...A(),nativeClockLifecycle:{constructionCertified:true}}];s.s.emit('message',{message:objects(records),areaGeneration:0});
 assert.equal(types(h).includes('accepted-lifecycle'),false);assert.equal(h.bridge.snapshot().ingress.history.complete,false);assert.equal(h.bridge.snapshot().ingress.history.reason,'lifecycle-gap');
 h.bridge.retire(s.s,3);s.close();
});

test('actual Session closed event removes clock listeners without a bridge-owned disconnect',()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);s.close();
 assert.equal(h.bridge.snapshot().attached,false);assert.equal(s.s.listenerCount('message'),0);assert.equal(s.s.listenerCount('diagnostic'),0);assert.equal(s.s.listenerCount('closed'),0);
 assert.deepEqual(s.sent,[]);
});

test('late attachment is explicitly incomplete, not a reconstructed process clock beginning',async()=>{
 const h=harness(),s=session();s.s.phase='resources';h.select(s.s,3);assert.equal(h.bridge.attach(s.s,3).attached,true);
 assert.equal(h.frames[0].history.complete,false);await s.deliver(packet());assert.equal(h.frames.at(-1).history.complete,false);
 assert.ok(h.frames.some(frame=>frame.event.type==='history-gap'&&frame.event.cause==='late-bind'));
 h.bridge.retire(s.s,3);s.close();
});

test('unexpected actual World reset fences old epoch until a new attach rather than rebinding constructors',async()=>{
 const h=harness(),s=session();h.select(s.s,3);h.bridge.attach(s.s,3);await s.deliver(objects([A()]));
 const oldEpoch=h.bridge.snapshot().epoch;s.s.world.reset();await s.deliver(packet());
 assert.equal(h.bridge.snapshot().epoch,oldEpoch);assert.equal(h.bridge.snapshot().epochInvalid,true);assert.equal(h.frames.at(-1).event.type,'history-gap');
 assert.equal(h.frames.at(-1).event.cause,'reset-unverified');assert.equal(s.s.world.nativeClockLifecycleHistory().connection,null);
 const count=h.frames.length;await s.deliver(objects([A(OTHER)]));assert.equal(h.frames.length,count);h.bridge.retire(s.s,3);s.close();
});

test('snapshot contains detached counters/scalars only and uncertain send is never retried by flush',async()=>{
 const h=harness(),s=session();h.setOutcome({status:'unknown'});h.select(s.s,3);h.bridge.attach(s.s,3);h.setOutcome({status:'accepted'});
 await s.deliver(packet());h.bridge.flush(s.s,3);assert.equal(h.frames.length,1);assert.equal(h.bridge.snapshot().ingress.transportUncertain,true);
 const snapshot=h.bridge.snapshot();snapshot.counts.attached=999;snapshot.ingress.history.complete=true;assert.notEqual(h.bridge.snapshot().counts.attached,999);assert.equal(h.bridge.snapshot().ingress.history.complete,false);
 assert.equal(snapshot.session,undefined);assert.equal(snapshot.world,undefined);assert.equal(snapshot.handler,undefined);
 h.bridge.retire(s.s,3);s.close();
});
