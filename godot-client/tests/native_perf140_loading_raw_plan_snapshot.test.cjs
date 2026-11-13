'use strict';
// Tiny Node-only functional oracle. No engine, capture, server or timing claim.
// The actual 64 MiB allocation case is deferred unless explicitly enabled.
const test=require('node:test');
const assert=require('node:assert/strict');
const {RawWorldDeltas}=require('../tools/raw-world-deltas.cjs');
const {rawWorldFrames:originalFrames}=require('../tools/raw-world-frames.cjs');
const {SnapshotRawWorldDeltas,rawWorldSnapshotFrames,rawWorldFrames,MAXIMUM_FRAME_BYTES,MAXIMUM_TOTAL_BYTES}=require('../tools/perf140/loading/raw-world-plan-snapshot.cjs');
const scope=(data,serial=1,connection=7,generation=2)=>({connection,generation,serial,data});
const data=(objects,extra={})=>({area:{id:99,tiles:[{model:'floor',x:0}]},objects,controlledId:objects[0]?.id??0,...extra});
const frames=(owner,input,maximum)=>{
 const snapshot=owner.planSnapshot(input);
 return {snapshot,wire:snapshot===null?[]:[...rawWorldSnapshotFrames(snapshot,maximum)]};
};
const original=(owner,input,maximum)=>{const changed=owner.plan(input);return changed===null?[]:[...originalFrames({...input,data:changed},maximum)];};
const collect=iterator=>{const wire=[];let error=null;try{for(const frame of iterator)wire.push(frame);}catch(caught){error=caught.message;}return{wire,error};};
function pair(initial,maximum){
 const left=new RawWorldDeltas(),right=new SnapshotRawWorldDeltas();
 const expected=original(left,initial,maximum),actual=frames(right,initial,maximum);
 assert.deepEqual(actual.wire,expected);return {left,right,snapshot:actual.snapshot};
}
test('canonical full/delta/no-op/removal frames are byte identical',()=>{
 const p=pair(scope(data([{id:1,objectType:5,replicated:{position:[1,2,3]}},{id:2,staticState:{model:'table'}}])));
 assert.equal(p.right.acknowledge({connection:7,generation:2,serial:1}),true);
 assert.equal(p.left.acknowledge({connection:7,generation:2,serial:1}),true);
 const update=scope(data([{id:1,objectType:5,replicated:{position:[2,2,3]}},{id:2,staticState:{model:'table'}}]),2);
 const second=frames(p.right,update);assert.deepEqual(second.wire,original(p.left,update));
 assert.equal(second.snapshot.objectCount,1);assert.equal(second.snapshot.bridgeMode,'delta');
 p.left.acknowledge({connection:7,generation:2,serial:2});p.right.acknowledge({connection:7,generation:2,serial:2});
 assert.equal(p.right.planSnapshot(scope(update.data,3)),null);assert.equal(p.left.plan(scope(update.data,3)),null);
 const removed=scope(data([{id:1,objectType:5,replicated:{position:[2,2,3]}}]),4);
 const third=frames(p.right,removed);assert.deepEqual(third.wire,original(p.left,removed));assert.equal(third.snapshot.removedCount,1);
});
test('property order, UTF8, native64, buffers, undefined and nonfinite JSON match',()=>{
 const object={id:11,'10':'ten','2':'two',z:undefined,position:[-0,NaN,Infinity,-Infinity],text:'Å雪🜁\\\"\n',native:1234567890123456789n,bytes:Buffer.from([0,255,128]),typed:Uint8Array.from([5,9])};
 pair(scope(data([object],{time:{b:2,a:1},ui:{x:'é',y:undefined},clock:0n}),1,0,0));
 assert.equal(rawWorldFrames,originalFrames,'Generic export is the original function');
});
test('zero rows, 64-row chunks and byte-bound chunk decisions match',()=>{
 pair(scope(data([])));
 const objects=Array.from({length:130},(_,i)=>({id:i+1,value:'x'.repeat(i%5)}));
 const p=pair(scope(data(objects)));
 const wire=[...rawWorldSnapshotFrames(p.snapshot)];const chunks=wire.map(line=>JSON.parse(line)).filter(row=>row.kind==='raw-world-chunk');
 assert.deepEqual(chunks.map(row=>row.objects.length),[64,64,2]);
 pair(scope(data(objects.slice(0,9)),1,7,2),1150);
});
test('snapshot is opaque, frozen, bound to owner scope and cannot be forged',()=>{
 const owner=new SnapshotRawWorldDeltas();const snapshot=owner.planSnapshot(scope(data([{id:1,nested:{x:1}}])));
 assert.equal(Object.isFrozen(snapshot),true);assert.equal(snapshot.records,undefined);assert.equal(snapshot.objects,undefined);
 assert.equal(snapshot.header,undefined);assert.equal(snapshot.rows,undefined);
 assert.throws(()=>{snapshot.serial=88;},TypeError);
 assert.throws(()=>[...rawWorldSnapshotFrames({...snapshot})],/Unknown/);
 assert.deepEqual(owner.snapshotStatus({...snapshot}),{known:false,pending:false});
 assert.deepEqual(new SnapshotRawWorldDeltas().snapshotStatus(snapshot),{known:false,pending:false});
 const status=owner.snapshotStatus(snapshot);assert.equal(Object.isFrozen(status),true);assert.equal(status.pending,true);assert.equal(status.framing,'encoded');
});
test('wrong ACK keeps snapshot; accepted ACK and reset retire it',()=>{
 const owner=new SnapshotRawWorldDeltas(),snapshot=owner.planSnapshot(scope(data([{id:1}])));
 for(const wrong of [{connection:8,generation:2,serial:1},{connection:7,generation:3,serial:1},{connection:7,generation:2,serial:2}])assert.equal(owner.acknowledge(wrong),false);
 assert.equal([...rawWorldSnapshotFrames(snapshot)].length,3);
 assert.throws(()=>owner.planSnapshot(scope(data([{id:2}]),2)),/awaiting acknowledgement/);
 assert.equal(owner.acknowledge({connection:7,generation:2,serial:1}),true);
 assert.throws(()=>[...rawWorldSnapshotFrames(snapshot)],/stale: acknowledged/);
 const next=owner.planSnapshot(scope(data([{id:2}]),3,7,3));assert.equal(next.bridgeMode,'full');
 owner.reset();assert.throws(()=>[...rawWorldSnapshotFrames(next)],/stale: reset/);
 assert.equal(owner.acknowledge({connection:7,generation:3,serial:3}),false);
 const fresh=owner.planSnapshot(scope(data([{id:1,changed:true}]),4,8,3));assert.equal(fresh.bridgeMode,'full');
 assert.throws(()=>[...rawWorldSnapshotFrames(snapshot)],/stale/);
 const manyOwner=new SnapshotRawWorldDeltas(),many=manyOwner.planSnapshot(scope(data(Array.from({length:130},(_,id)=>({id:id+1}))))),stream=rawWorldSnapshotFrames(many);
 stream.next();assert.equal(JSON.parse(stream.next().value).objects.length,64);
 assert.equal(manyOwner.acknowledge({connection:7,generation:2,serial:99}),false);
 assert.equal(JSON.parse(stream.next().value).objects.length,64);
 assert.equal(manyOwner.acknowledge({connection:7,generation:2,serial:1}),true);
 assert.throws(()=>stream.next(),/stale: acknowledged/);
});
test('retirement during iteration errors without starting fallback or another scope',()=>{
 const owner=new SnapshotRawWorldDeltas(),snapshot=owner.planSnapshot(scope(data([{id:1}]))),stream=rawWorldSnapshotFrames(snapshot);
 assert.equal(JSON.parse(stream.next().value).kind,'raw-world-begin');owner.reset();
 assert.throws(()=>stream.next(),/stale/);
});
test('explicit snapshot captures projection while generic plan retains mutable behavior',()=>{
 const owner=new SnapshotRawWorldDeltas(),input=scope(data([{id:1,state:{value:1}}],{ui:{value:1}}));
 const snapshot=owner.planSnapshot(input);input.data.objects[0].state.value=9;input.data.ui.value=9;
 const wire=[...rawWorldSnapshotFrames(snapshot)].map(line=>JSON.parse(line));
 assert.equal(wire[0].data.ui.value,1);assert.equal(wire[1].objects[0].state.value,1);
 const generic=new SnapshotRawWorldDeltas(),other=scope(data([{id:1,state:{value:1}}]));const changed=generic.plan(other);
 other.data.objects[0].state.value=9;
 assert.equal(JSON.parse([...rawWorldFrames({...other,data:changed})][1]).objects[0].state.value,9);
});
test('generic route retains stateful toJSON-per-pass side effects',()=>{
 const run=Owner=>{let calls=0;const owner=new Owner(),input=scope(data([{id:1,toJSON(){return{id:1,n:++calls};}}]));const changed=owner.plan(input);const wire=[...originalFrames({...input,data:changed})];return {calls,wire};};
 const expected=run(RawWorldDeltas),actual=run(SnapshotRawWorldDeltas);
 assert.equal(expected.calls,3);assert.deepEqual(actual,expected);
 const keyed=Owner=>{const keys=[],owner=new Owner(),input=scope(data([{id:1,toJSON(key){keys.push(key);return{id:1,key};}}]));const changed=owner.plan(input);return{keys,wire:[...originalFrames({...input,data:changed})]};};
 const originalKeys=keyed(RawWorldDeltas);assert.deepEqual(originalKeys.keys,['','','0']);assert.deepEqual(keyed(SnapshotRawWorldDeltas),originalKeys);
});
test('reserved bridge input uses the unchanged generic framing fallback',()=>{
 const input=scope(data([{id:1}],{bridgeMode:'external',bridgeBaseSerial:99,removedObjectIds:[8]}));
 const p=pair(input);assert.equal(p.right.snapshotStatus(p.snapshot).framing,'generic');
});
test('invalid scopes, identity/count bounds and frame-size errors remain bounded',()=>{
 for(const input of [scope(data([{id:1}]),0),scope(data([{id:1}]),1,-1),scope(data([{id:1}]),1,7,-1),scope(data([{id:1},{id:1}]))]){
  const old=new RawWorldDeltas(),candidate=new SnapshotRawWorldDeltas();let message;
  try{old.plan(input);}catch(error){message=error.message;}assert.equal(typeof message,'string');assert.throws(()=>candidate.planSnapshot(input),error=>error.message===message);
 }
 assert.throws(()=>new SnapshotRawWorldDeltas().planSnapshot(scope(data(new Array(65537).fill({id:1})))),/Invalid raw delta scope/);
 const tooLargeHeader=scope(data([{id:1}],{ui:{text:'x'.repeat(512)}}));
 const old=new RawWorldDeltas(),candidate=new SnapshotRawWorldDeltas(),changed=old.plan(tooLargeHeader),snapshot=candidate.planSnapshot(tooLargeHeader);
 assert.throws(()=>[...originalFrames({...tooLargeHeader,data:changed},256)],/frame bound/);assert.throws(()=>[...rawWorldSnapshotFrames(snapshot,256)],/frame bound/);
 const exactInput=scope(data([{id:1,text:'雪'.repeat(64)}]));const exactOwner=new SnapshotRawWorldDeltas(),exactSnapshot=exactOwner.planSnapshot(exactInput),exactWire=[...rawWorldSnapshotFrames(exactSnapshot)];
 const exactMaximum=Math.max(...exactWire.map(line=>Buffer.byteLength(line)-1));pair(exactInput,exactMaximum);
 assert.throws(()=>[...rawWorldSnapshotFrames(exactSnapshot,exactMaximum-1)],/frame bound/);
 const lateInput=scope(data([{id:1},{id:2},{id:3,text:'x'.repeat(2000)}])),lateOriginal=new RawWorldDeltas(),lateOwner=new SnapshotRawWorldDeltas();
 const lateChanged=lateOriginal.plan(lateInput),lateSnapshot=lateOwner.planSnapshot(lateInput);
 const expectedLate=collect(originalFrames({...lateInput,data:lateChanged},1150)),actualLate=collect(rawWorldSnapshotFrames(lateSnapshot,1150));
 assert.deepEqual(actualLate,expectedLate);assert.match(actualLate.error,/frame bound/);
 assert.deepEqual(actualLate.wire.map(line=>JSON.parse(line).kind),['raw-world-begin','raw-world-chunk']);
 lateOwner.reset();assert.throws(()=>[...rawWorldSnapshotFrames(lateSnapshot)],/stale/);
 assert.equal(MAXIMUM_FRAME_BYTES,1024*1024);assert.equal(MAXIMUM_TOTAL_BYTES,64*1024*1024);
});
test('deferred production total-byte bound', {skip:process.env.NWN_PERF140_RAW_SNAPSHOT_HEAVY!=='1'},()=>{
 // Explicit later resource lane only. This allocation is deliberately excluded
 // from the tiny game-time gate; production cap itself is never lowered.
 const objects=Array.from({length:66},(_,id)=>({id:id+1,text:'x'.repeat(1024*1024)}));
 const input=scope(data(objects)),old=new RawWorldDeltas(),owner=new SnapshotRawWorldDeltas(),changed=old.plan(input),snapshot=owner.planSnapshot(input);
 assert.throws(()=>[...originalFrames({...input,data:changed},2*1024*1024)],/snapshot exceeds bound/);
 assert.throws(()=>[...rawWorldSnapshotFrames(snapshot,2*1024*1024)],/snapshot exceeds bound/);
});
