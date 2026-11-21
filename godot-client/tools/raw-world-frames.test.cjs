const test=require('node:test'),assert=require('node:assert/strict'),{rawWorldFrames}=require('./raw-world-frames.cjs');
test('large raw worlds split below native frame limits without changing server fields',()=>{
 const objects=Array.from({length:906},(_,id)=>({id,objectType:5,appearance:{appearance:id},replicated:{description:'é'.repeat(1800),position:[id,0,0],value:42n}}));
 const frames=[...rawWorldFrames({serial:1,generation:3,data:{area:{id:7},objects,controlledId:1}},16384)];
 assert.ok(frames.length>200);for(const frame of frames)assert.ok(Buffer.byteLength(frame)<=16385);
 const parsed=frames.map(JSON.parse);assert.equal(parsed[0].count,906);assert.deepEqual(parsed[0].data,{area:{id:7},controlledId:1});assert.equal(parsed.at(-1).kind,'raw-world-end');
 assert.deepEqual(parsed.filter(frame=>frame.kind==='raw-world-chunk').flatMap(frame=>frame.objects),objects.map(row=>({...row,replicated:{...row.replicated,value:{native64:'42'}}})));
});
test('oversized raw records and invalid scopes are rejected before native parsing',()=>{
 assert.throws(()=>[...rawWorldFrames({serial:0,generation:1,data:{objects:[]}})],/Invalid/);
 assert.throws(()=>[...rawWorldFrames({serial:1,generation:1,data:{objects:[{text:'x'.repeat(9000)}]}},4096)],/bound/);
});
test('connection identity survives every raw frame without entering original server objects',()=>{
 const objects=Array.from({length:130},(_,id)=>({id,replicated:{position:[id,2,3]}}));
 const frames=[...rawWorldFrames({connection:7,serial:9,generation:1,data:{objects,area:{id:4}}})].map(JSON.parse);
 assert.ok(frames.length>=5);assert.ok(frames.every(frame=>frame.connection===7));
 assert.deepEqual(frames.filter(frame=>frame.objects).flatMap(frame=>frame.objects),objects);
 assert.equal(frames[0].data.connection,undefined);
 for(const connection of [-1,0.5,NaN,Infinity,'7'])assert.throws(()=>[...rawWorldFrames({connection,serial:1,generation:1,data:{objects:[]}})],/connection/);
});
