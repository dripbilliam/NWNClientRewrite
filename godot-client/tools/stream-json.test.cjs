const test=require('node:test'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {writeJson}=require('./stream-json.cjs');
test('bounded manifest writing retains JSON values and hashes actual UTF8 bytes through partial writes',async()=>{
 const value={rigs:{assets:Array.from({length:64},(_,i)=>({name:'actor '+i,keys:Array.from({length:2049},(_,j)=>j/3),label:'é🔥',optional:undefined}))},mixed:[null,true,false,undefined,NaN,Infinity,{negative:-0}]};
 const chunks=[];const result=await writeJson({async write(buffer,offset,count){const size=Math.min(count,997);chunks.push(Buffer.from(buffer.subarray(offset,offset+size)));return{bytesWritten:size};}},value,{chunkCharacters:8192});
 const bytes=Buffer.concat(chunks);assert.deepEqual(JSON.parse(bytes),JSON.parse(JSON.stringify(value)));assert.equal(result.bytes,bytes.length);assert.ok(result.writes>30);assert.equal(result.sha256,crypto.createHash('sha256').update(bytes).digest('hex'));
});
test('cycles and non-data objects fail instead of silently dropping rendering data',async()=>{
 const cycle={};cycle.self=cycle;const file={async write(buffer,_offset,count){return{bytesWritten:count};}};
 await assert.rejects(writeJson(file,cycle),/Circular/);await assert.rejects(writeJson(file,{bad:new Map()}),/plain JSON/);
});
