import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
import {PreparedModelCache,preparedModelSchema} from '../electron/prepared_model_cache.mjs';
import {parseModel} from '../src/model_parser.js';import {buildModelGeometry,prepareModelGeometry} from '../src/prepared_model_geometry.js';
const source=(offset=0)=>new TextEncoder().encode(`#MAXMODEL ASCII\nnewmodel fixture\nsetsupermodel fixture null\nclassification tile\nbeginmodelgeom fixture\nnode trimesh mesh\n parent NULL\n position 1 2 3\n orientation 0 0 1 0\n bitmap test\n verts 3\n ${offset} 0 0\n 1 0 0\n 0 1 0\n tverts 3\n 0 0 0\n 1 0 0\n 0 1 0\n faces 1\n 0 1 2 1 0 1 2 0\nendnode\nendmodelgeom fixture\ndonemodel fixture\n`);
const schema='a'.repeat(64),options=directory=>({directory,schema,size:2}),withDirectory=async work=>{const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-prepared-model-test-'));try{await work(directory);}finally{await fs.rm(directory,{recursive:true,force:true});}};

test('persistent model results match cold geometry byte for byte and keep live arrays independent',async()=>{
 const bytes=source(),original=parseModel(bytes.buffer),cold=buildModelGeometry(original.nodes[0]);
 try{const stats=prepareModelGeometry(original),warm=buildModelGeometry(original.nodes[0]);try{
  assert.equal(stats.meshes,1);for(const name of ['position','normal','uv'])assert.deepEqual(warm.attributes[name].array,cold.attributes[name].array);
  assert.deepEqual(warm.groups,cold.groups);assert.deepEqual(warm.boundingSphere,cold.boundingSphere);assert.deepEqual(warm.userData,cold.userData);
  warm.attributes.position.array[0]=123;assert.notEqual(original.nodes[0].preparedGeometry.position[0],123);
 }finally{warm.dispose();}}finally{cold.dispose();}
});

test('disk cache survives owner restart, content and schema changes rebuild, memory results cannot inherit mutations',async()=>withDirectory(async directory=>{
 const a=new PreparedModelCache(options(directory)),bytes=source();const first=await a.prepare(bytes);assert.equal(a.snapshot().misses,1);assert.equal(a.snapshot().preparedMeshes,1);assert.ok(first.nodes[0].preparedGeometry);
 first.animations.push({name:'inherited-only'});first.nodes[0].preparedGeometry.position[0]=999;
 const second=await a.prepare(bytes);assert.equal(a.snapshot().memoryHits,1);assert.equal(second.animations.length,0);assert.notEqual(second.nodes[0].preparedGeometry.position[0],999);assert.equal(Object.getPrototypeOf(second.nodes[0].properties),null);
 await a.flush();await a.dispose();const b=new PreparedModelCache(options(directory));assert.deepEqual(await b.prepare(bytes),second);assert.equal(b.snapshot().diskHits,1);assert.equal(b.snapshot().misses,0);assert.equal(b.snapshot().workers,0);
 await b.prepare(source(.25));assert.equal(b.snapshot().misses,1);await b.dispose();
 const c=new PreparedModelCache({...options(directory),schema:'b'.repeat(64)});await c.prepare(bytes);assert.equal(c.snapshot().misses,1);assert.equal(c.snapshot().diskHits,0);await c.dispose();
}));

test('coalesced requests own distinct results, bad disk data rebuilds and memory/disk caps evict',async()=>withDirectory(async directory=>{
 const a=new PreparedModelCache({...options(directory),maxMemoryBytes:0}),bytes=source();const[first,second]=await Promise.all([a.prepare(bytes),a.prepare(bytes)]);assert.notEqual(first,second);assert.equal(a.snapshot().misses,1);assert.equal(a.snapshot().memoryBytes,0);assert.equal(bytes[0],35);await a.flush();await a.dispose();
 const folder=path.join(directory,schema),files=await fs.readdir(folder);await fs.writeFile(path.join(folder,files[0]),'corrupt');
 const b=new PreparedModelCache({...options(directory),maxDiskBytes:0,maxMemoryBytes:1});await b.prepare(bytes);assert.equal(b.snapshot().corrupt,1);assert.equal(b.snapshot().misses,1);await b.flush();assert.deepEqual((await fs.readdir(folder)).filter(x=>x.endsWith('.bin')),[]);await b.dispose();
}));

test('malformed models reject without files and closing in flight drains workers/queues',async()=>withDirectory(async directory=>{
 const a=new PreparedModelCache(options(directory));await assert.rejects(a.prepare(Uint8Array.of(0,1,2)));assert.equal(a.snapshot().failed,1);assert.equal(a.snapshot().misses,1);
 const work=Array.from({length:6},(_,i)=>a.prepare(source(i*.01)));const settled=Promise.allSettled(work);await a.dispose();assert.ok((await settled).every(r=>r.status==='rejected'));assert.equal(a.snapshot().workers,0);assert.equal(a.snapshot().queued,0);await assert.rejects(a.prepare(source()),/closed/);
}));

test('schema covers preparation code and serialization ABI reproducibly',async()=>{const[a,b]=await Promise.all([preparedModelSchema(),preparedModelSchema()]);assert.match(a,/^[a-f0-9]{64}$/);assert.equal(a,b);});

test('renderer reuse validates actual source bytes and schema before skipping disk/CPU/transfer work',async()=>withDirectory(async directory=>{
 const cache=new PreparedModelCache(options(directory)),first=await cache.prepare(source(),{metadata:true});assert.match(first.key,/^[a-f0-9]{64}$/);assert.ok(first.model);const before=cache.snapshot();
 assert.deepEqual(await cache.prepare(source(),{knownKey:first.key,metadata:true}),{key:first.key,reused:true});assert.equal(cache.snapshot().rendererHits,1);assert.equal(cache.snapshot().misses,before.misses);assert.equal(cache.snapshot().memoryHits,0);
 const changed=await cache.prepare(source(.5),{knownKey:first.key,metadata:true});assert.notEqual(changed.key,first.key);assert.ok(changed.model);assert.equal(cache.snapshot().misses,2);await cache.dispose();
}));
