'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const {NativeClockIngress,MAX_CLOCK_INGRESS_FRAMES,MAX_CLOCK_INGRESS_BYTES}=require('./native-clock-ingress.cjs');

const rate=value=>({kind:'module-info',module:{minutesPerHour:value}});
const accepted={status:'accepted'};
function harness(options={}){
 let outcome=accepted;
 const attempts=[],written=[],session={};
 const ingress=new NativeClockIngress({
  beginHistory:()=>true,
  acceptedLifecycle:()=>null,
  ...options,
  send(frame,line){
   attempts.push({frame,line});
   if(outcome==='throw')throw Error('Authored unknown transport outcome');
   const result=typeof outcome==='function'?outcome(frame,line):outcome;
   if(result?.status==='accepted')written.push({frame,line});
   return result;
  }
 });
 return {ingress,session,attempts,written,setOutcome(value){outcome=value;}};
}
const frames=fixture=>fixture.written.map(row=>row.frame);
const fact=(extra={})=>({operation:'create',recordIndex:0,objectId:0x80000042,objectType:5,nativeLifetime:2,knownLifetimeBefore:null,knownLifetimeAfter:3,ownership:'new',deletionFlag:null,cause:'accepted-A',...extra});

test('begin certifies only supplied history and a bound lifecycle owner; never timer construction',()=>{
 let injectedReads=0;
 const session={get timerConstructed(){injectedReads++;throw Error('Not an authority');},nativeLifetime:1,firstSnapshot:true};
 const seen=[];
 const untrusted=new NativeClockIngress({send(frame){seen.push(frame);return accepted;}});
 assert.equal(untrusted.begin(session,3).delivery,'accepted');
 assert.deepEqual(seen[0].event,{type:'begin',lifecycleBound:false});
 assert.deepEqual(seen[0].history,{complete:false,reason:'begin-unverified'});
 assert.equal(injectedReads,0);
 assert.equal(JSON.stringify(seen).includes('timerConstructed'),false);
 const unbound=new NativeClockIngress({send:()=>accepted,beginHistory:()=>true});
 unbound.begin(session,3);
 assert.deepEqual(unbound.snapshot().history,{complete:false,reason:'lifecycle-unbound'});
 const trusted=harness();trusted.ingress.begin(trusted.session,3);
 assert.deepEqual(frames(trusted)[0].history,{complete:true,reason:null});
 assert.equal(trusted.ingress.emit,undefined);
 assert.equal(trusted.ingress.queue,undefined);
});

test('ordered fixed projection retains native pause IDs and control sources without other module/world data',()=>{
 const f=harness();f.ingress.begin(f.session,3);
 const incoming=[
  {kind:'module-info',module:{minutesPerHour:0,name:'Not transported',tiles:['Not transported']},timerConstructed:true},
  {kind:'module-time',mask:255,changes:{day:777,hour:8},absoluteClock:123},
  {kind:'module-pause-state',mask:3,value:1,exclusionIds:[0xffffffff,0x80000042,0x80000042,0]},
  {kind:'client-area',area:{id:91,tiles:['Not transported'],name:'Not transported'}},
  {kind:'object-control',major:5,minor:2,playerId:4,objectId:0x80000042},
  {kind:'object-control',major:14,minor:14,playerId:4,objectId:0x80000043}
 ];
 for(const message of incoming)assert.equal(f.ingress.observe(f.session,3,message,{generation:7,areaId:91}).delivery,'accepted');
 const output=frames(f);
 assert.deepEqual(output.map(row=>row.serial),[1,2,3,4,5,6,7]);
 assert.deepEqual(output.slice(1).map(row=>row.event),[
  {type:'module-info',minutesPerHour:0},
  {type:'module-time',mask:255},
  {type:'module-pause-state',mask:3,value:1,exclusionIds:[0xffffffff,0x80000042,0x80000042,0]},
  {type:'client-area',areaId:91},
  {type:'object-control',playerId:4,objectId:0x80000042,sourceMajor:5,sourceMinor:2},
  {type:'object-control',playerId:4,objectId:0x80000043,sourceMajor:14,sourceMinor:14}
 ]);
 assert.deepEqual(output[1].scope,{generation:7,areaId:91});
 assert.equal(JSON.stringify(output).includes('Not transported'),false);
 const previous=f.ingress.snapshot().serial;
 assert.equal(f.ingress.observe(f.session,3,{kind:'object-updates',firstSnapshot:true,typedOwnerAbsent:true}).reason,'not-clock-event');
 assert.equal(f.ingress.snapshot().serial,previous);
});

test('all received mask/value combinations remain numeric, not truthy coercions',()=>{
 const f=harness();f.ingress.begin(f.session,0);
 for(let mask=0;mask<4;mask++)for(let value=0;value<2;value++){
  f.ingress.observe(f.session,0,{kind:'module-pause-state',mask,value,exclusionIds:[]});
 }
 assert.deepEqual(frames(f).slice(1).map(row=>[row.event.mask,row.event.value]),[[0,0],[0,1],[1,0],[1,1],[2,0],[2,1],[3,0],[3,1]]);
});

test('exact session and strictly newer accepted connection fence stale callbacks and sticky history',()=>{
 const f=harness();f.ingress.begin(f.session,3);
 f.ingress.gap(f.session,3,'decoder-rejected');
 const before=f.attempts.length;
 assert.equal(f.ingress.observe({},3,rate(2)).reason,'stale-session');
 assert.equal(f.ingress.lifecycle({},3,{}).reason,'stale-session');
 assert.equal(f.ingress.flush(f.session,2).reason,'stale-session');
 assert.deepEqual(f.ingress.retire({},3),{retired:false});
 assert.equal(f.ingress.begin(f.session,3).reason,'old-or-duplicate-connection');
 assert.equal(f.ingress.begin({},2).reason,'old-or-duplicate-connection');
 assert.equal(f.attempts.length,before);
 f.ingress.observe(f.session,3,rate(3));
 assert.equal(frames(f).at(-1).history.complete,false);
 const next={};f.ingress.begin(next,4);
 assert.deepEqual(frames(f).at(-1).history,{complete:true,reason:null});
 assert.equal(frames(f).at(-1).serial,1);
 assert.equal(f.ingress.observe(f.session,3,rate(4)).reason,'stale-session');
 assert.deepEqual(f.ingress.retire(next,4),{retired:true,discardedFrames:0});
 assert.equal(f.ingress.observe(next,4,rate(5)).reason,'stale-session');
 assert.equal(f.ingress.begin(next,4).reason,'old-or-duplicate-connection');
});

test('accepted lifecycle facts come only from the private callback and detach scalar witnesses',()=>{
 const privateBoundaries=new WeakMap();let callbackCalls=0;
 const f=harness({acceptedLifecycle(session,boundary){callbackCalls++;assert.equal(session,f.session);return privateBoundaries.get(boundary)??null;}});
 f.ingress.begin(f.session,3);
 assert.equal(f.ingress.lifecycle(f.session,3,{complete:true,fact:fact()}).reason,'not-lifecycle-event');
 const boundary={},source=fact({secret:'Not transported',model:'Not transported'});
 privateBoundaries.set(boundary,{complete:true,fact:source});
 f.ingress.lifecycle(f.session,3,boundary,{generation:7,areaId:91});
 source.objectId=9;
 assert.deepEqual(frames(f).at(-1).event,{type:'accepted-lifecycle',...fact()});
 for(const [operation,deletionFlag,ownership] of [['remove',false,'unknown'],['remove',true,'retained'],['reset',null,'unknown']]){
  const token={};privateBoundaries.set(token,{complete:true,fact:fact({operation,deletionFlag,ownership,nativeLifetime:null,knownLifetimeAfter:null})});
  f.ingress.lifecycle(f.session,3,token);
  assert.equal(frames(f).at(-1).event.operation,operation);
  assert.equal(frames(f).at(-1).event.deletionFlag,deletionFlag);
 }
 const incomplete={};privateBoundaries.set(incomplete,{complete:false,fact:fact()});
 f.ingress.lifecycle(f.session,3,incomplete);
 assert.equal(frames(f).at(-1).history.complete,false);
 assert.equal(f.ingress.snapshot().history.reason,'incomplete-records');
 assert.equal(callbackCalls,6);
});

test('private callback failure or malformed facts cannot publish partial lifecycle state',()=>{
 for(const acceptedLifecycle of [()=>{throw Error('Private boundary unavailable');},()=>({complete:true,fact:{...fact(),knownLifetimeAfter:undefined}}),()=>({complete:1,fact:fact()})]){
  const f=harness({acceptedLifecycle});f.ingress.begin(f.session,3);
  assert.equal(f.ingress.lifecycle(f.session,3,{}).reason,'invalid-lifecycle-fact');
  assert.equal(frames(f).length,1);
  assert.equal(f.ingress.snapshot().history.complete,false);
 }
});

test('accepted backpressure is a successful write and is never queued or repeated',()=>{
 const f=harness();f.setOutcome({status:'accepted',backpressure:true});
 f.ingress.begin(f.session,3);f.ingress.observe(f.session,3,rate(2));f.ingress.flush(f.session,3);
 assert.equal(f.attempts.length,2);
 assert.equal(f.ingress.snapshot().queuedFrames,0);
 assert.equal(f.ingress.snapshot().counts.backpressure,2);
 assert.equal(f.ingress.snapshot().history.complete,true);
});

test('only explicit zero-write unavailable is retried, in exact FIFO order and encoded bytes',()=>{
 const f=harness();f.setOutcome({status:'unavailable'});
 f.ingress.begin(f.session,3);f.ingress.observe(f.session,3,rate(2));f.ingress.observe(f.session,3,{kind:'module-time',mask:1});
 assert.equal(f.written.length,0);assert.equal(f.ingress.snapshot().queuedFrames,3);
 const queuedBytes=f.ingress.snapshot().queuedBytes;
 f.setOutcome(accepted);f.ingress.flush(f.session,3);
 assert.deepEqual(frames(f).map(row=>row.serial),[1,2,3]);
 assert.equal(queuedBytes,f.written.reduce((sum,row)=>sum+Buffer.byteLength(row.line),0));
 for(const {frame,line} of f.written){assert.deepEqual(JSON.parse(line),frame);assert.equal(line,JSON.stringify(frame)+'\n');}
 assert.equal(f.ingress.snapshot().queuedBytes,0);assert.equal(f.ingress.snapshot().history.complete,true);
});

test('unknown, exceptions, bare socket booleans and async results stop writes without blind retry',()=>{
 for(const outcome of [{status:'unknown'},'throw',false,true,Promise.resolve(accepted),{status:'accepted',backpressure:1}]){
  const f=harness();f.setOutcome(outcome);
  assert.equal(f.ingress.begin(f.session,3).delivery,'uncertain');
  assert.equal(f.ingress.snapshot().transportUncertain,true);
  f.setOutcome(accepted);
  f.ingress.flush(f.session,3);f.ingress.observe(f.session,3,rate(2));f.ingress.flush(f.session,3);
  assert.equal(f.attempts.length,1);
  assert.equal(f.ingress.snapshot().queuedFrames,1);
  assert.equal(f.ingress.snapshot().history.complete,false);
  f.ingress.begin({},4);
  assert.equal(f.attempts.length,2);
  assert.equal(frames(f).at(-1).connection,4);
  assert.equal(frames(f).at(-1).serial,1);
  assert.equal(f.ingress.snapshot().transportUncertain,false);
 }
});

test('a queued unknown head is removed once; later queued facts are not written on the uncertain stream',()=>{
 const f=harness();f.setOutcome({status:'unavailable'});
 f.ingress.begin(f.session,3);f.ingress.observe(f.session,3,rate(2));
 f.setOutcome({status:'unknown'});f.ingress.flush(f.session,3);
 const attempts=f.attempts.length;
 f.setOutcome(accepted);f.ingress.flush(f.session,3);
 assert.equal(f.attempts.length,attempts);assert.equal(f.ingress.snapshot().queuedFrames,1);
 assert.equal(f.ingress.snapshot().transportUncertain,true);
});

test('the 64-frame pre-socket cap drops overflow, exposes serial gap and never repairs history in-place',()=>{
 const f=harness();f.setOutcome({status:'unavailable'});f.ingress.begin(f.session,3);
 for(let at=0;at<63;at++)f.ingress.observe(f.session,3,rate(at));
 assert.equal(f.ingress.snapshot().queuedFrames,64);
 const overflow=f.ingress.observe(f.session,3,rate(64));
 assert.deepEqual(overflow,{recorded:false,delivery:'dropped',serial:65});
 assert.equal(f.ingress.snapshot().queuedFrames,MAX_CLOCK_INGRESS_FRAMES);
 assert.ok(f.ingress.snapshot().queuedBytes<=MAX_CLOCK_INGRESS_BYTES);
 assert.deepEqual(f.ingress.snapshot().history,{complete:false,reason:'queue-overflow'});
 f.setOutcome(accepted);f.ingress.flush(f.session,3);
 assert.deepEqual(frames(f).map(row=>row.serial),[...Array.from({length:64},(_,at)=>at+1),66]);
 assert.deepEqual(frames(f).at(-1).event,{type:'history-gap',cause:'queue-overflow'});
 assert.equal(frames(f).at(-1).history.complete,false);
 f.ingress.observe(f.session,3,rate(2));assert.equal(frames(f).at(-1).history.complete,false);
});

test('encoded byte budget counts exact UTF-8 frames and clears only on a newer connection',()=>{
 const probe=harness();probe.ingress.begin(probe.session,3);probe.ingress.observe(probe.session,3,rate(2));
 const byteLimit=probe.written.reduce((sum,row)=>sum+Buffer.byteLength(row.line),0)-1;
 const f=harness({maximumBytes:byteLimit});f.setOutcome({status:'unavailable'});f.ingress.begin(f.session,3);
 const firstBytes=f.ingress.snapshot().queuedBytes;
 assert.equal(f.ingress.observe(f.session,3,rate(2)).delivery,'dropped');
 assert.equal(f.ingress.snapshot().queuedBytes,firstBytes);
 assert.ok(firstBytes<=byteLimit);assert.equal(f.ingress.snapshot().history.complete,false);
 f.setOutcome(accepted);f.ingress.begin({},4);
 assert.equal(f.ingress.snapshot().queuedBytes,0);assert.equal(f.ingress.snapshot().history.complete,true);
 assert.throws(()=>harness({maximumFrames:65}),/Invalid clock ingress options/);
 assert.throws(()=>harness({maximumBytes:MAX_CLOCK_INGRESS_BYTES+1}),/Invalid clock ingress options/);
});

test('serial exhaustion never wraps, emits a duplicate, or creates a constructor witness',()=>{
 const f=harness({maximumSerial:2});f.ingress.begin(f.session,3);f.ingress.observe(f.session,3,rate(2));
 assert.deepEqual(f.ingress.observe(f.session,3,rate(3)),{recorded:false,reason:'serial-exhausted'});
 f.ingress.flush(f.session,3);
 assert.deepEqual(frames(f).map(row=>row.serial),[1,2]);assert.equal(f.ingress.snapshot().history.complete,false);
 f.ingress.begin({},4);assert.equal(frames(f).at(-1).serial,1);
});

test('queued frames are detached and deeply frozen, and snapshots expose no mutable queue/state',()=>{
 const f=harness();f.setOutcome({status:'unavailable'});f.ingress.begin(f.session,3);
 const exclusionIds=[0x80000042,0xffffffff],selectedScope={generation:7,areaId:91};
 f.ingress.observe(f.session,3,{kind:'module-pause-state',mask:1,value:0,exclusionIds},selectedScope);
 exclusionIds[0]=9;selectedScope.areaId=99;
 const status=f.ingress.snapshot();status.history.complete=false;status.counts.accepted=999;
 f.setOutcome(accepted);f.ingress.flush(f.session,3);
 const frame=frames(f).at(-1);
 assert.deepEqual(frame.event.exclusionIds,[0x80000042,0xffffffff]);assert.equal(frame.scope.areaId,91);
 assert.ok(Object.isFrozen(frame));assert.ok(Object.isFrozen(frame.event.exclusionIds));
 assert.throws(()=>{frame.event.exclusionIds.push(1);},TypeError);
 assert.equal(f.ingress.snapshot().history.complete,true);
 assert.notEqual(f.ingress.snapshot().counts.accepted,999);
});

test('invalid supported facts taint without publishing partial fields; accessors and inherited flags are not read',()=>{
 const invalid=[
  {kind:'module-info',module:{minutesPerHour:256}},
  {kind:'module-time',mask:-1},
  {kind:'module-pause-state',mask:1,value:true,exclusionIds:[]},
  {kind:'module-pause-state',mask:1,value:0,exclusionIds:[1,-1,2]},
  {kind:'module-pause-state',mask:1,value:0,exclusionIds:Array(1)},
  {kind:'client-area',area:{id:1.5}},
  {kind:'object-control',major:14,minor:2,playerId:0,objectId:1}
 ];
 for(const message of invalid){const f=harness();f.ingress.begin(f.session,3);assert.equal(f.ingress.observe(f.session,3,message).reason,'invalid-clock-event');assert.equal(frames(f).length,1);assert.equal(f.ingress.snapshot().history.complete,false);}
 let reads=0;const f=harness();f.ingress.begin(f.session,3);
 const accessor={get kind(){reads++;return 'module-info';}};
 assert.equal(f.ingress.observe(f.session,3,accessor).reason,'not-clock-event');
 assert.equal(f.ingress.observe(f.session,3,Object.create({kind:'module-info',module:{minutesPerHour:2}})).reason,'not-clock-event');
 const message={kind:'module-info',get module(){reads++;return {minutesPerHour:2};}};
 assert.equal(f.ingress.observe(f.session,3,message).reason,'invalid-clock-event');assert.equal(reads,0);
});

test('actual private lifecycle projection separates physical certainty from complete clock transport',()=>{
 const boundaries=new WeakMap();
 const f=harness({acceptedLifecycle:(_session,boundary)=>boundaries.get(boundary)??null});f.ingress.begin(f.session,3);
 const boundary={},value={version:1,source:'native_client_clock_lifecycle_v1',epoch:7,connection:3,transaction:9,complete:true,recordHistoryComplete:true,constructionHistoryComplete:false,fact:{operation:'create',recordIndex:4,objectId:0x80000042,objectType:5,ownership:'unknown',deletionFlag:null,areaId:91,physicalToken:null,ownerAbsentCertified:false,constructionCertified:false,aiRegistrationCertified:false}};
 boundaries.set(boundary,value);assert.equal(f.ingress.lifecycle(f.session,3,boundary,{generation:2,areaId:91}).delivery,'accepted');
 assert.deepEqual(frames(f).at(-1).event,{type:'accepted-lifecycle',version:2,lifecycleEpoch:7,transaction:9,...value.fact,constructionHistoryComplete:false});
 value.fact.objectId=123;
 assert.equal(frames(f).at(-1).event.objectId,0x80000042);
 assert.equal(frames(f).at(-1).history.complete,true);
 f.ingress.observe(f.session,3,{kind:'module-pause-state',mask:2,value:1,exclusionIds:[0x80000042,0x80000042]});
 assert.equal(frames(f).at(-1).history.complete,true);
 assert.deepEqual(frames(f).at(-1).event,{type:'module-pause-state',mask:2,value:1,exclusionIds:[0x80000042,0x80000042]});
 const removed={};boundaries.set(removed,{...value,constructionHistoryComplete:true,fact:{...value.fact,operation:'remove',objectId:0x80000042,deletionFlag:0,ownerAbsentCertified:true}});
 assert.equal(f.ingress.lifecycle(f.session,3,removed).delivery,'accepted');
 assert.equal(frames(f).at(-1).event.deletionFlag,0);
 assert.equal(frames(f).at(-1).history.complete,true);
});

test('actual lifecycle certs reject mismatched connection, Boolean D flags and invented construction',()=>{
 const base={version:1,source:'native_client_clock_lifecycle_v1',epoch:7,connection:3,transaction:9,complete:true,recordHistoryComplete:true,constructionHistoryComplete:true,fact:{operation:'create',recordIndex:0,objectId:0x80000042,objectType:5,ownership:'new',deletionFlag:null,areaId:91,physicalToken:'client-clock:7:3:1',ownerAbsentCertified:false,constructionCertified:true,aiRegistrationCertified:true}};
 for(const mutate of [v=>{v.connection=4;},v=>{v.recordHistoryComplete=false;},v=>{v.constructionHistoryComplete=false;},v=>{v.fact.physicalToken=null;},v=>{v.fact.aiRegistrationCertified=false;},v=>{v.fact.ownership='unknown';},v=>{v.fact.ownerAbsentCertified=true;},v=>{v.fact.operation='remove';v.fact.deletionFlag=true;},v=>{v.epoch=0;}]){
  const value=structuredClone(base);mutate(value);
  const f=harness({acceptedLifecycle:()=>value});f.ingress.begin(f.session,3);
  assert.equal(f.ingress.lifecycle(f.session,3,{}).reason,'invalid-lifecycle-fact');
  assert.equal(frames(f).length,1);assert.equal(f.ingress.snapshot().history.complete,false);
 }
 const f=harness({acceptedLifecycle:()=>base});f.ingress.begin(f.session,3);
 assert.equal(f.ingress.lifecycle(f.session,3,{}).delivery,'accepted');
 assert.equal(frames(f).at(-1).event.constructionCertified,true);
 assert.equal(frames(f).at(-1).history.complete,true);
});
