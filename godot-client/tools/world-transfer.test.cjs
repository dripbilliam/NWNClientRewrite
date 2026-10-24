const test=require('node:test'),assert=require('node:assert/strict');
const {WorldTransfer}=require('./world-transfer.cjs');
const value=(areaId=5,generation=1,connection=1)=>({connection,areaId,generation});
test('following unchanged world does not repeatedly clear the native room',()=>{
 const t=new WorldTransfer(),{scope}=t.follow(value());t.prepare(scope,{...value(),sha256:'a'});assert.ok(t.acknowledge({...value(),sha256:'a'}));
 assert.equal(t.follow(value()).changed,false);assert.equal(t.scope,scope);assert.equal(t.admitted,true);
});
test('A to B to A needs new bundles and cannot accept an old load acknowledgement',()=>{
 const t=new WorldTransfer(),a=t.follow(value()).scope;t.prepare(a,{...value(),sha256:'a'});
 const b=t.follow(value(6,2)).scope;assert.equal(t.admitted,false);assert.equal(t.bundle,null);
 assert.equal(t.acknowledge({...value(),sha256:'a'}),false);
 assert.equal(t.prepare(a,{...value(),sha256:'a'}),false);
 t.prepare(b,{...value(6,2),sha256:'b'});assert.ok(t.acknowledge({...value(6,2),sha256:'b'}));
 const returned=t.follow(value(5,3)).scope;assert.notEqual(returned,a);assert.equal(t.matches(a,value(5,3)),false);
});
test('leave and reconnect invalidate pending jobs even when all numeric identifiers are reused',()=>{
 const t=new WorldTransfer(),old=t.follow(value()).scope;t.clear();const next=t.follow(value()).scope;
 assert.notEqual(next,old);assert.equal(t.matches(old),false);assert.equal(t.prepare(old,{...value(),sha256:'x'}),false);
});
test('source world changing before the next polling tick invalidates a pending result',async()=>{
 const t=new WorldTransfer(),old=t.follow(value()).scope;let release;const ready=new Promise(r=>release=r);let live=value(),committed=false;
 const job=ready.then(()=>{if(t.matches(old,live))committed=t.prepare(old,{...value(),sha256:'old'});});
 live=value(6,2);release();await job;assert.equal(committed,false);assert.equal(t.bundle,null);
});
test('wrong package scope and hash never admit a native world',()=>{
 const t=new WorldTransfer(),{scope}=t.follow(value());assert.throws(()=>t.prepare(scope,{...value(6),sha256:'x'}),/another world/);
 t.prepare(scope,{...value(),sha256:'x'});assert.equal(t.acknowledge({...value(),sha256:'y'}),false);assert.equal(t.admitted,false);
 assert.equal(t.acknowledge({...value(5,1,3),sha256:'x'}),false);
});
