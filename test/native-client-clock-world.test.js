import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkWorld} from '../src/network_world.js';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import ingressModule from '../godot-client/tools/native-clock-ingress.cjs';

const {NativeClockIngress}=ingressModule;
const ID=0x80000042,OTHER=ID+1,THIRD=ID+2;
const A=(id=ID,areaId=91)=>({action:'create',objectType:5,id,state:{areaId}});
const D=(bit=0,id=ID)=>({action:'delete',objectType:5,id,remove:bit});
const P=(text='Actor',id=ID)=>({action:'appearance',objectType:5,id,mask:0x400,state:{name:{text}}});
const U=(id=ID)=>({action:'update',objectType:5,id,state:{name:{text:'Party label'}}});
function world(connection=3){const diagnostics=[],w=new NetworkWorld({onDiagnostic:value=>diagnostics.push(value)});w.areaId=91;if(connection!==null)w.bindNativeClockConnection(connection);return {w,diagnostics};}
const apply=(w,records,complete=true)=>w.apply({kind:'object-updates',records,complete});
const state=(w,id=ID)=>w.nativeClockLifecycleState(w.registry.get(id));
const names=(w,id=ID)=>w.nativeActorNameFor(w.registry.get(id));
function facts(w,records){const boundaries=w.nativeClockLifecycleBoundaries(records);assert.ok(boundaries,'accepted records must retain private batch');return boundaries.map(boundary=>w.nativeClockLifecycleBoundary(boundary));}
function adapter(w,connection=3){
 const frames=[],lines=[];
 const ingress=new NativeClockIngress({beginHistory:session=>session===w&&w.nativeClockLifecycleHistory().complete===true,acceptedLifecycle:(session,boundary)=>session===w?w.nativeClockLifecycleBoundary(boundary):null,send(frame,line){frames.push(frame);lines.push(line);return {status:'accepted',backpressure:true};}});
 ingress.begin(w,connection);
 return {ingress,frames,lines,deliver(records){for(const boundary of w.nativeClockLifecycleBoundaries(records)??[])assert.equal(ingress.lifecycle(w,connection,boundary,{generation:7,areaId:91}).delivery,'accepted');}};
}
function pause(mask=2,value=3,ids=[ID,ID,0x7f000000]){
 // Actual native writer/envelope/decoder, authored bytes in original3/9 order.
 // No server/network operation or claim of captured original writer bytes.
 const writer=new NativeMessageWriter(1);writer.create(2+ids.length*4,0xffffffff,1);
 writer.writeByte(mask,2,1);writer.writeBool(value);writer.writeWord(ids.length,16);
 for(const id of ids)writer.writeObjectIdClient(id);
 writer.setPrefix(Uint8Array.of(80,3,9));return decodeServerGameMessage(Uint8Array.from(writer.getWriteMessage().data));
}

test('actual World full and delta admissions publish fresh facts tied to accepted records identity',()=>{
 const {w}=world(),first=[A(),P()];assert.equal(w.nativeClockLifecycleBoundaries(first),null);
 assert.equal(apply(w,first),true);const initial=facts(w,first);
 assert.equal(initial.length,1);assert.equal(initial[0].connection,3);assert.equal(initial[0].fact.ownership,'new');
 assert.equal(initial[0].fact.constructionCertified,true);assert.equal(initial[0].fact.aiRegistrationCertified,true);assert.equal(initial[0].fact.areaId,91);
 assert.equal(initial[0].complete,true);assert.equal(initial[0].constructionHistoryComplete,true);
 assert.equal(names(w).construction.kind,'new');assert.equal(names(w).publication.first.text,'Actor');
 assert.equal(w.nativeClockLifecycleBoundaries([...first]),null);assert.equal(w.nativeClockLifecycleBoundary({...initial[0]}),null);
 const delta=[A(OTHER,92)];apply(w,delta);const next=facts(w,delta)[0];
 assert.equal(next.fact.ownership,'new');assert.equal(next.fact.areaId,92);assert.notEqual(next.fact.physicalToken,initial[0].fact.physicalToken);
 assert.equal(next.transaction,initial[0].transaction+1);assert.equal(w.nativeClockLifecycleHistory().observerFailures,0);
});

test('actual World repeated A preserves canonical proxy and physical token without new ctor or AI',()=>{
 const {w}=world(),first=[A(),P()];apply(w,first);const canonical=w.registry.get(ID),before=names(w),token=state(w).physicalToken;
 const repeated=[A()];apply(w,repeated);const row=facts(w,repeated)[0];
 assert.equal(w.registry.get(ID),canonical);assert.equal(row.fact.ownership,'retained');assert.equal(row.fact.physicalToken,token);
 assert.equal(row.fact.constructionCertified,false);assert.equal(row.fact.aiRegistrationCertified,false);assert.deepEqual(names(w),before);
 assert.equal(state(w).physicalCurrent,true);
});

test('actual World A/D/A keeps per-record prefixes, raw removal bits and area despite one final row',()=>{
 for(const bit of [0,1]){
  const {w}=world(),records=[A(),D(bit),A(ID,92)];apply(w,records);const rows=facts(w,records);
  assert.deepEqual(rows.map(row=>row.fact.recordIndex),[0,1,2]);assert.deepEqual(rows.map(row=>row.fact.operation),['create','remove','create']);
  assert.deepEqual(rows.map(row=>row.fact.ownership),['new','retained','unknown']);assert.deepEqual(rows.map(row=>row.fact.areaId),[91,91,92]);
  assert.deepEqual(rows.map(row=>row.complete),[true,true,true]);assert.deepEqual(rows.map(row=>row.constructionHistoryComplete),[true,true,false]);
  assert.equal(rows[1].fact.deletionFlag,bit);assert.equal(rows[0].fact.physicalToken,rows[1].fact.physicalToken);assert.equal(rows[2].fact.physicalToken,null);
  assert.equal(w.registry.get(ID).replicationRemoved,false);assert.equal(state(w).physicalCurrent,false);assert.equal(w.nativeClockLifecycleHistory().recordHistoryComplete,true);
 }
});

test('actual World certified absent D is a no-op before a genuinely fresh A, including both raw bits',()=>{
 for(const bit of [0,1]){
  const {w}=world(),records=[D(bit),A()];apply(w,records);const rows=facts(w,records);
  assert.deepEqual(rows.map(row=>row.fact.ownerAbsentCertified),[true,false]);assert.equal(rows[0].fact.deletionFlag,bit);assert.equal(rows[0].fact.physicalToken,null);
  assert.equal(rows[1].fact.constructionCertified,true);assert.equal(rows[1].fact.aiRegistrationCertified,true);assert.equal(rows[1].fact.ownership,'new');
  assert.ok(rows.every(row=>row.complete&&row.constructionHistoryComplete));assert.equal(names(w).construction.kind,'new');assert.equal(w.nativeClockLifecycleHistory().observerFailures,0);
 }
 const {w}=world(),absent=[D()];apply(w,absent);assert.equal(w.registry.get(ID),undefined);assert.equal(facts(w,absent)[0].fact.ownerAbsentCertified,true);
 const later=[A()];apply(w,later);assert.equal(facts(w,later)[0].fact.constructionCertified,true);
});

test('actual generic P/U/I proxies before A preserve record coverage while leaving birth unknown',()=>{
 for(const generic of [P('Before A'),U(),{action:'player-state',objectType:5,id:ID,state:{}},{action:'inventory-stats',objectType:5,id:ID,state:{}}]){
  const {w}=world(),records=[generic,A()];apply(w,records);const row=facts(w,records)[0],history=w.nativeClockLifecycleHistory();
  assert.equal(row.fact.ownership,'unknown');assert.equal(row.fact.physicalToken,null);assert.equal(row.fact.constructionCertified,false);assert.equal(row.fact.aiRegistrationCertified,false);
  assert.equal(row.complete,true);assert.equal(row.recordHistoryComplete,true);assert.equal(row.constructionHistoryComplete,false);
  assert.equal(history.complete,true);assert.equal(history.constructionHistoryComplete,true);assert.equal(state(w).constructionHistoryComplete,false);assert.equal(names(w).construction.kind,'unknown');assert.equal(history.observerFailures,0);
 }
});

test('actual unknown OTHER leaves uninterrupted known physical owner current and reusable',()=>{
 const {w}=world(),first=[A()];apply(w,first);const canonical=w.registry.get(ID),token=state(w).physicalToken;
 apply(w,[P('Untracked',OTHER)]);assert.equal(w.nativeClockLifecycleHistory().constructionHistoryComplete,true);assert.equal(state(w).physicalCurrent,true);
 const repeated=[A()];apply(w,repeated);assert.equal(w.registry.get(ID),canonical);assert.equal(facts(w,repeated)[0].fact.physicalToken,token);assert.equal(facts(w,repeated)[0].fact.ownership,'retained');
 const newFresh=[A(THIRD)];apply(w,newFresh);assert.equal(facts(w,newFresh)[0].fact.constructionCertified,true);assert.equal(facts(w,newFresh)[0].complete,true);
});

test('invalid later record rolls back canonical rows, names and clock publications while tainting both histories',()=>{
 const {w}=world(),beforeRecords=[A(),P('Before')];apply(w,beforeRecords);
 const canonical=w.registry.get(ID),raw=structuredClone(canonical),beforeNames=names(w),sequence=w.nativeActorNameSequence(),oldFact=facts(w,beforeRecords)[0],token=state(w).physicalToken;
 const rejected=[P('Must roll back'),A(OTHER),{action:'create',objectType:6,id:ID,state:{}}];
 assert.throws(()=>apply(w,rejected),/Conflicting replicated object type/);
 assert.equal(w.registry.get(ID),canonical);assert.deepEqual(canonical,raw);assert.equal(w.registry.get(OTHER),undefined);
 assert.deepEqual(names(w),beforeNames);assert.equal(w.nativeActorNameSequence(),sequence);assert.equal(w.nativeActorNameHistory().complete,false);
 assert.equal(w.nativeClockLifecycleBoundaries(rejected),null);assert.deepEqual(facts(w,beforeRecords)[0],oldFact);
 assert.equal(state(w).physicalToken,token);assert.equal(state(w).physicalCurrent,false);
 assert.equal(w.nativeClockLifecycleHistory().recordHistoryComplete,false);assert.equal(w.nativeClockLifecycleHistory().constructionHistoryComplete,false);
 const after=[A(THIRD)];apply(w,after);assert.equal(facts(w,after)[0].fact.constructionCertified,false);assert.equal(facts(w,after)[0].complete,false);
});

test('actual incomplete prefixes and untracked direct calls cannot restore coverage or constructors',()=>{
 for(const untracked of [w=>apply(w,[A()],false),w=>w.applyObjectUpdates([A()])]){
  const {w}=world();untracked(w);assert.equal(w.nativeClockLifecycleHistory().complete,false);assert.equal(w.nativeClockLifecycleHistory().constructionHistoryComplete,false);
  const next=[A(OTHER)];apply(w,next);const row=facts(w,next)[0];assert.equal(row.complete,false);assert.equal(row.fact.constructionCertified,false);
  assert.equal(names(w,OTHER).construction.kind,'unknown');
 }
});

test('actual reset/reconnect rejects stale canonical IDs and opaque boundaries without token alias',()=>{
 const {w}=world(),records=[A()];apply(w,records);const old=w.registry.get(ID),oldBoundary=w.nativeClockLifecycleBoundaries(records)[0],before=facts(w,records)[0];
 w.reset();w.areaId=91;w.bindNativeClockConnection(4);
 assert.equal(w.nativeClockLifecycleState(old),null);assert.equal(w.nativeClockLifecycleBoundary(oldBoundary),null);assert.equal(w.nativeClockLifecycleBoundaries(records),null);
 const current=[A()];apply(w,current);const after=facts(w,current)[0];
 assert.equal(after.connection,4);assert.notEqual(after.epoch,before.epoch);assert.notEqual(after.fact.physicalToken,before.fact.physicalToken);assert.equal(after.fact.constructionCertified,true);
 assert.equal(w.nativeClockLifecycleState({...w.registry.get(ID)}),null);
});

test('injected clock DTOs/imported proxies cannot impersonate private ownership; exposed reads are detached',()=>{
 const {w}=world(),records=[A()];apply(w,records);const before=facts(w,records)[0],row=w.registry.get(ID),view=state(w);
 row.nativeClockLifecycleState={...view,physicalCurrent:true};row.clockConstruction={fresh:true};
 const boundary=w.nativeClockLifecycleBoundaries(records)[0],detached=w.nativeClockLifecycleBoundary(boundary);detached.fact.physicalToken='forged';detached.fact.objectId=0;view.physicalToken='forged';
 assert.deepEqual(w.nativeClockLifecycleBoundary(boundary),before);assert.notEqual(state(w).physicalToken,'forged');
 assert.ok(Object.isFrozen(w.nativeClockLifecycleBoundaries(records)));assert.throws(()=>w.nativeClockLifecycleBoundaries(records).push({}),TypeError);
 const imported=world().w,clone=structuredClone(row);assert.equal(imported.registry.addObjectAtPos(ID,clone).status,0);
 assert.equal(imported.nativeClockLifecycleState(clone),null);const reused=[{...A(),nativeClockLifecycleState:before}];apply(imported,reused);
 assert.equal(facts(imported,reused)[0].fact.constructionCertified,false);assert.equal(facts(imported,reused)[0].fact.physicalToken,null);
});

test('actual narrow clock owner transport hides historical D tokens and cannot be mutated or forged',()=>{
 const {w}=world(),first=[A()];apply(w,first);const canonical=w.registry.get(ID),owner=w.nativeClockOwnerTransport(canonical);
 assert.deepEqual(Object.keys(owner).sort(),['connection','epoch','physicalCurrent','physicalToken','source','version']);
 assert.equal(owner.version,1);assert.equal(owner.source,'native-client-clock-owner-v1');assert.equal(owner.connection,3);assert.equal(owner.physicalCurrent,true);
 assert.equal(owner.physicalToken,state(w).physicalToken);owner.physicalToken='mutated';owner.physicalCurrent=false;
 assert.notEqual(w.nativeClockOwnerTransport(canonical).physicalToken,'mutated');assert.equal(w.nativeClockOwnerTransport(canonical).physicalCurrent,true);
 canonical.nativeClockOwner={...owner,physicalCurrent:true};assert.equal(w.nativeClockOwnerTransport({...canonical}),null);
 const removed=[D(1)];apply(w,removed);const history=state(w),hidden=w.nativeClockOwnerTransport(canonical);
 assert.ok(history.physicalToken);assert.equal(history.physicalCurrent,false);assert.equal(hidden.physicalCurrent,false);assert.equal(hidden.physicalToken,null);
 w.reset();assert.equal(w.nativeClockOwnerTransport(canonical),null);
});

test('clock observer rejection does not alter accepted actor-name constructor ownership',()=>{
 const {w}=world();apply(w,[A(),P('Original')]);
 // Authored malformed direct-DTO BOOL cannot arise from the narrowing native
 // reader. It targets observer isolation without inventing a real wire case.
 const malformed=[D(2),A(OTHER),P('Independent',OTHER)];assert.equal(apply(w,malformed),true);
 assert.equal(w.nativeClockLifecycleBoundaries(malformed),null);assert.ok(w.nativeClockLifecycleHistory().observerFailures>0);
 assert.equal(w.nativeActorNameHistory().complete,true);assert.equal(names(w,OTHER).construction.kind,'new');assert.equal(names(w,OTHER).publication.first.text,'Independent');
 assert.equal(w.nativeClockLifecycleHistory().recordHistoryComplete,false);
});

test('actual World→private helper→v2 ingress keeps unknown birth separate from subsequent native pause coverage',()=>{
 const {w}=world(),a=adapter(w),records=[P('Before A'),A()];apply(w,records);a.deliver(records);
 const lifecycle=a.frames.find(frame=>frame.event.type==='accepted-lifecycle');
 assert.equal(lifecycle.event.version,2);assert.equal(lifecycle.event.constructionCertified,false);assert.equal(lifecycle.event.physicalToken,null);assert.equal(lifecycle.event.constructionHistoryComplete,false);
 assert.equal(lifecycle.history.complete,true);assert.equal(lifecycle.event.lifecycleEpoch,facts(w,records)[0].epoch);
 const received=pause();assert.deepEqual(received,{kind:'module-pause-state',mask:2,value:1,exclusionIds:[ID,ID,0x7f000000],major:3,minor:9});
 assert.equal(a.ingress.observe(w,3,received,{generation:7,areaId:91}).delivery,'accepted');
 assert.deepEqual(a.frames.at(-1).event,{type:'module-pause-state',mask:2,value:1,exclusionIds:[ID,ID,0x7f000000]});assert.equal(a.frames.at(-1).history.complete,true);
 assert.deepEqual(a.frames.map(frame=>frame.serial),[1,2,3]);assert.equal(a.ingress.snapshot().queuedFrames,0);
 for(let index=0;index<a.lines.length;index++)assert.deepEqual(JSON.parse(a.lines[index]),a.frames[index]);
});

test('actual World A/D/A projects v2 lifecycle order, raw D and immutable prefix into transport',()=>{
 const {w}=world(),a=adapter(w),records=[A(),D(1),A()];apply(w,records);a.deliver(records);
 const projected=a.frames.filter(frame=>frame.event.type==='accepted-lifecycle');
 assert.deepEqual(projected.map(frame=>frame.event.recordIndex),[0,1,2]);assert.deepEqual(projected.map(frame=>frame.event.constructionHistoryComplete),[true,true,false]);
 assert.deepEqual(projected.map(frame=>frame.history.complete),[true,true,true]);assert.equal(projected[1].event.deletionFlag,1);
 assert.equal(projected[0].event.physicalToken,projected[1].event.physicalToken);assert.equal(projected[2].event.physicalToken,null);
 assert.ok(projected.every(frame=>typeof frame.event.ownerAbsentCertified==='boolean'));
});

test('actual incomplete World fact taints ingress coverage and a later valid pause cannot repair it',()=>{
 const {w}=world(),a=adapter(w),records=[A()];apply(w,records,false);a.deliver(records);
 assert.equal(a.frames.find(frame=>frame.event.type==='accepted-lifecycle').history.complete,false);
 a.ingress.observe(w,3,pause());assert.equal(a.frames.at(-1).event.type,'module-pause-state');assert.equal(a.frames.at(-1).history.complete,false);
 assert.equal(a.ingress.snapshot().history.reason,'incomplete-records');
});
