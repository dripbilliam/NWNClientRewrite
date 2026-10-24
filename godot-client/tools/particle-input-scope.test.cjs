const test=require('node:test'),assert=require('node:assert/strict'),{particleInputScope}=require('./particle-input-scope.cjs');
const scope={connection:1,areaId:9,generation:2,transferId:2},known=[{epoch:3,scope:{connection:1,areaId:7,generation:1,transferId:1}},{epoch:4,scope}],frame={...scope,kind:'particle-frame',epoch:4};
test('current renderer frames require an allocated epoch and matching connection/area/generation/transfer',()=>{
 assert.equal(particleInputScope(frame,scope,4,known),'current');
 for(const change of [{epoch:99},{connection:3},{generation:1},{transferId:9},{epoch:'4'},{kind:'walk'}])assert.equal(particleInputScope({...frame,...change},scope,4,known),'unknown');
});
test('known retired area work drains without becoming current work or authorizing a gameplay command',()=>{
 const old={...known[0].scope,kind:'particle-frame',epoch:3};assert.equal(particleInputScope(old,scope,4,known),'retired');
 assert.equal(particleInputScope({...old,kind:'particles-start'},scope,4,known),'retired');
 assert.equal(particleInputScope({...old,kind:'quickbar-activate'},scope,4,known),'unknown');
 assert.equal(particleInputScope({...old,transferId:2},scope,4,known),'unknown');
});
test('reused IDs/generation after reconnect do not make an old connection or epoch current',()=>{
 const next={connection:3,areaId:7,generation:1,transferId:3},rows=[...known,{epoch:5,scope:next}];
 assert.equal(particleInputScope({...known[0].scope,kind:'particle-frame',epoch:3},next,5,rows),'retired');
 assert.equal(particleInputScope({...next,kind:'particle-frame',epoch:5},next,5,rows),'current');
 assert.equal(particleInputScope({...known[0].scope,kind:'particle-frame',epoch:5},next,5,rows),'unknown');
});
