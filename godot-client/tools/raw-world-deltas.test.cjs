const test=require('node:test'),assert=require('node:assert/strict'),{RawWorldDeltas}=require('./raw-world-deltas.cjs'),{rawWorldFrames}=require('./raw-world-frames.cjs');
const scope={connection:3,generation:7},object=id=>({id,objectType:5,replicated:{position:[id,2,3],wide:42n}});
function input(serial,objects,header={}){return{...scope,serial,data:{area:{id:12},controlledId:1,objects,...header}};}
test('first snapshot and acknowledged object deltas reconstruct exact raw state',()=>{
 const planner=new RawWorldDeltas(),objects=Array.from({length:643},(_,i)=>object(i));let full=planner.plan(input(1,objects));
 assert.equal(full.bridgeMode,'full');assert.equal(full.objects.length,643);assert.equal(planner.acknowledge({...scope,serial:1}),true);
 assert.equal(planner.plan(input(2,objects)),null);
 objects[100].replicated.position[0]=456;objects.splice(4,1);objects.push(object(999));
 const delta=planner.plan(input(3,objects));assert.equal(delta.bridgeMode,'delta');assert.equal(delta.bridgeBaseSerial,1);assert.deepEqual(delta.removedObjectIds,[4]);assert.deepEqual(delta.objects.map(o=>o.id),[100,999]);
 const mirror=new Map(full.objects.map(o=>[o.id,structuredClone(o)]));for(const id of delta.removedObjectIds)mirror.delete(id);for(const o of delta.objects)mirror.set(o.id,o);
 assert.deepEqual([...mirror].sort((a,b)=>a[0]-b[0]),objects.map(o=>[o.id,o]).sort((a,b)=>a[0]-b[0]));
 const frames=[...rawWorldFrames({...scope,serial:3,data:delta})].map(JSON.parse);assert.equal(frames[0].count,2);assert.equal(frames[0].data.bridgeBaseSerial,1);assert.equal(frames.find(f=>f.objects).objects[0].replicated.wide.native64,'42');
});
test('only exact acknowledgement commits; reconnect/area/reset require full state',()=>{
 const p=new RawWorldDeltas();p.plan(input(1,[object(1)]));
 for(const bad of [{connection:2,generation:7,serial:1},{connection:3,generation:8,serial:1},{connection:3,generation:7,serial:2}])assert.equal(p.acknowledge(bad),false);
 assert.throws(()=>p.plan(input(2,[])),/acknowledgement/);assert.equal(p.acknowledge({...scope,serial:1}),true);
 const next=p.plan({...input(2,[object(1)]),generation:8});assert.equal(next.bridgeMode,'full');assert.equal(next.bridgeBaseSerial,-1);p.reset();
 assert.equal(p.acknowledge({connection:3,generation:8,serial:2}),false);assert.equal(p.plan({...input(3,[object(1)]),connection:4}).bridgeMode,'full');
});
test('metadata-only changes are delivered; source objects remain unmodified',()=>{
 const p=new RawWorldDeltas(),objects=[object(1)],before=structuredClone(objects);p.plan(input(1,objects));p.acknowledge({...scope,serial:1});
 const delta=p.plan(input(2,objects,{inventory:{inventories:[['I',{entries:[{id:5}]}]]}}));assert.equal(delta.objects.length,0);assert.equal(delta.inventory.inventories[0][1].entries[0].id,5);assert.deepEqual(objects,before);
});
test('invalid identity/count and duplicates are rejected without a pending transaction',()=>{
 const p=new RawWorldDeltas();for(const objects of [[object(1),object(1)],[{id:NaN}],Array(65537).fill(object(1))])assert.throws(()=>p.plan(input(1,objects)),/Invalid/);
 assert.equal(p.pending,null);assert.equal(p.plan(input(1,[])).bridgeMode,'full');
});
