const test=require('node:test'),assert=require('node:assert/strict');
const {snapshot,compare}=require('../tools/native-creation-hp-proof.cjs');
const expected={HitPoints:10,MaxHitPoints:13,PregameCurrent:13,CurrentHitPoints:10};
const typed=root=>snapshot(root,()=>Object.fromEntries(Object.keys(root).map(key=>[key,3])));
const received=(current=13,maximum=13)=>({connection:1,generation:1,areaId:0x80000001,actorId:0xffffffff,actorLifetime:1,currentScope:true,postAdmissionRequested:true,current,maximum,temporary:0});
test('uploaded and exported caches retain exact original formula and SHORT types',()=>{
 const hp=typed(expected);assert.equal(compare(expected,hp,hp,false,received()).success,true);
 for(const field of Object.keys(expected)){
  const wrong=structuredClone(hp);wrong.values[field]++;const result=compare(expected,hp,wrong,false,received());
  assert.equal(result.success,false);assert.equal(result.normalization[0].field,field);
  wrong.values[field]=expected[field];wrong.types[field]=5;assert.equal(compare(expected,wrong,hp,false,received()).success,false);
 }
});
test('server-vault reconnect has no upload and still verifies fresh exported caches',()=>{
 const hp=typed(expected);assert.equal(compare(expected,null,hp,true,received()).success,true);
 assert.equal(compare(expected,hp,hp,true,received()).success,false);assert.equal(compare({},null,hp,true,received()).success,false);
});
test('server-normalized export is independently checked against received HP, never copied back to upload',()=>{
 const source={HitPoints:4,MaxHitPoints:6,PregameCurrent:6,CurrentHitPoints:4},server={...source,MaxHitPoints:7,PregameCurrent:7};
 const result=compare(source,typed(source),typed(server),false,received(7,7));
 assert.equal(result.success,true);assert.equal(result.normalization.length,2);assert.equal(result.uploadExact,true);
 assert.equal(compare(source,typed(server),typed(server),false,received(7,7)).success,false);
 assert.equal(compare(source,typed(source),typed(server),false,received(6,6)).success,false);
 for(const mutate of [r=>r.currentScope=false,r=>r.postAdmissionRequested=false,r=>r.temporary=1,r=>r.actorLifetime=0,r=>r.areaId=null,r=>r.current=8]){const invalid=received(7,7);mutate(invalid);assert.equal(compare(source,typed(source),typed(server),false,invalid).success,false);}
 assert.equal(compare(source,typed(source),typed(server)).success,false);
});
