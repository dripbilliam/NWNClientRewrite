const test=require('node:test'),assert=require('node:assert/strict');
const {ContentTracker}=require('./content-tracker.cjs');
test('poses and pending replacement preparation leave installed content intact',()=>{
 const t=new ContentTracker();t.reset('c1:a1',[{id:7,revision:1}]);
 assert.deepEqual(t.plan({desired:[7],ready:[]}),{scope:'c1:a1',remove:[],upserts:[]});
 assert.equal(t.plan({desired:[7],ready:[{id:7,revision:1}]}).upserts.length,0);
 assert.deepEqual(t.plan({desired:[7],ready:[{id:7,revision:2}]}).upserts,[{id:7,revision:2}]);
});
test('late spawn, authoritative removal and same-ID recreation each produce content work',()=>{
 const t=new ContentTracker();t.reset('a',[]);
 let s={desired:[7],ready:[{id:7,revision:1}]},p=t.plan(s);assert.ok(t.valid(p,s));assert.equal(t.commit(p),1);
 s={desired:[],ready:[]};p=t.plan(s);assert.deepEqual(p.remove,[7]);t.commit(p);
 s={desired:[7],ready:[{id:7,revision:2}]};p=t.plan(s);assert.deepEqual(p.upserts,s.ready);assert.equal(t.commit(p),3);
});
test('resource work cannot commit after replacement, deletion or world retirement',()=>{
 const t=new ContentTracker();t.reset('a',[]);const s={desired:[7],ready:[{id:7,revision:1}]},p=t.plan(s);
 assert.equal(t.valid(p,{desired:[7],ready:[{id:7,revision:2}]}),false);
 assert.equal(t.valid(p,{desired:[],ready:[]}),false);
 t.reset('b',[]);assert.equal(t.valid(p,s),false);assert.throws(()=>t.commit(p),/Retired/);
});
test('removed objects cannot reappear through an old renderer binding and batches are bounded',()=>{
 const t=new ContentTracker();t.reset('a',[]);
 assert.equal(t.plan({desired:[],ready:[{id:7,revision:1}]}).upserts.length,0);
 const ready=Array.from({length:30},(_,id)=>({id,revision:id+1}));const s={desired:ready.map(r=>r.id),ready};
 const p=t.plan(s);assert.equal(p.upserts.length,8);t.commit(p);assert.equal(t.plan(s).upserts[0].id,8);
});
