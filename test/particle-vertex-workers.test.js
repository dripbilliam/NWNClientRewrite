import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {Worker} from 'node:worker_threads';
import {buildParticleVertices} from '../src/particle_vertices.js';import {sampleParticleVertices,packParticleVertexBatch,buildParticleVertexBatch} from '../src/particle_vertex_batch.js';import {ResourceWorkerPool} from '../src/resource_worker_pool.js';
const f=Math.fround;
function fromCase(c){
 const state={fade:f(c.fade),height50:f(c.height),opacity70:f(c.elevationOpacity)};
 const records=Array.from({length:c.count},(_,i)=>({position10:[1+i,2+i*2,3-i],trail64:[-1+i,1+i*2,2-i],quaternion34:[.5,-.5,.5,.5],direction4c:[0,0,1],rotation1c:f(c.rotation+i*.125),age:f(c.age+i*.125),field48:f(c.frameTime),frame44:c.initialFrame,stopped70:c.stopped}));
 return{renderMode1a8:c.mode,active188:{records},lifeExp:f(c.life),source50:c.source?{opacity108:f(c.opacity),instance:c.sourceInstance?{...state,fade:f(c.sourceFade)}:null}:null,instance100:c.instance?state:null,flags:c.flags,position1e0:[1,2,3],quaternion1d0:[.5,.5,.5,.5],ageMode1cc:c.ageMode,xGrid:c.grid[0],yGrid:c.grid[1],elevationThreshold:f(5),colorStart:c.colorStart.map(f),colorEnd:c.colorEnd.map(f),alphaStart:f(c.alphaStart),alphaEnd:f(c.alphaEnd),sizeStart:f(c.sizes[0]),sizeEnd:f(c.sizes[1]),sizeStartY:f(c.sizes[2]),sizeEndY:f(c.sizes[3]),fps:f(c.fps),frameStart:f(c.frameStart),frameEnd:f(c.frameEnd),blendMode68:c.blend,twoSided:c.twoSided};
}
const createWorker=()=>{const worker=new Worker(new URL('../scripts/resource-worker-thread-fixture.mjs',import.meta.url));return{postMessage:(...args)=>worker.postMessage(...args),terminate:()=>worker.terminate(),addEventListener(kind,fn){worker.on(kind,value=>fn(kind==='message'?{data:value}:{message:value.message,preventDefault(){}}));}};};

test('worker snapshots match all245 native vertex streams and preserve main-thread atlas mutations',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-particle-vertices-observations.json',import.meta.url))),items=[],states=[];
 for(const [key,row]of oracle.rows.entries()){
  const c=row.case,e=fromCase(c);e.elevationThreshold=oracle.elevationThreshold;const providers={sourceFactor:()=>c.factor,cameraQuaternion:()=>c.camera,lightColor:()=>c.tint},expected=structuredClone(e),out=buildParticleVertices(expected,providers),input=sampleParticleVertices(e,providers);
  assert.equal(Boolean(input),Boolean(out));assert.deepEqual(e.active188.records.map(p=>[p.frame44,p.field48]),expected.active188.records.map(p=>[p.frame44,p.field48]));states.push({e,expected,out});if(input)items.push({key,input});
 }
 const payload=packParticleVertexBatch(items),reference=buildParticleVertexBatch(structuredClone(payload)),pool=new ResourceWorkerPool({size:3,createWorker});
 try{const results=await pool.run('particle-vertices',payload);assert.equal(payload.buffer.byteLength,0,'private snapshot was transferred');assert.deepEqual(results,reference);for(const {key,out,error}of results){assert.equal(error,undefined);assert.deepEqual(new Uint32Array(out.buffer),new Uint32Array(states[key].out.buffer));assert.equal(out.softInverse,states[key].out.softInverse);assert.deepEqual(states[key].e.active188,states[key].expected.active188);}}
 finally{pool.dispose();}
});

test('snapshots own their data and one malformed frame cannot suppress other emitter outputs',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-particle-vertices-observations.json',import.meta.url))),row=oracle.rows.find(r=>r.words.length),e=fromCase(row.case),input=sampleParticleVertices(e,{sourceFactor:()=>row.case.factor,cameraQuaternion:()=>row.case.camera,lightColor:()=>row.case.tint}),payload=packParticleVertexBatch([{key:7,input}]),before=buildParticleVertexBatch(structuredClone(payload));
 e.active188.records[0].position10[0]=99999;assert.deepEqual(buildParticleVertexBatch(payload),before);payload.frames.push({...payload.frames[0],key:8,offset:999999});const results=buildParticleVertexBatch(payload);assert.deepEqual(results[0],before[0]);assert.match(results[1].error,/bounds/);
});
