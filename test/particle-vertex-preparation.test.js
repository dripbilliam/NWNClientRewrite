import test from 'node:test';import assert from 'node:assert/strict';import {Worker} from 'node:worker_threads';import * as T from 'three';
import {ParticleVertexPreparation} from '../src/particle_vertex_preparation.js';import {buildParticleVertexBatch,sampleParticleVertices} from '../src/particle_vertex_batch.js';import {ResourceWorkerPool} from '../src/resource_worker_pool.js';import {ModelParticlePresentation,createModelEmitter} from '../src/model_particles.js';
const createWorker=()=>{const w=new Worker(new URL('../scripts/resource-worker-thread-fixture.mjs',import.meta.url));return{postMessage:(...args)=>w.postMessage(...args),terminate:()=>w.terminate(),addEventListener(kind,fn){w.on(kind,data=>fn(kind==='message'?{data}:{message:data.message,preventDefault(){}}));}};};
function fixture(pool=null){
 const root=new T.Group(),camera=new T.PerspectiveCamera(),texture=new T.Texture(),reports=[],emitters=[];
 for(let i=0;i<6;i++){const model=new T.Group();model.userData.mdlRoot='authored';model.position.x=i;root.add(model);const group=new T.Group();model.add(group);const mesh=createModelEmitter({name:'test'+i,properties:{texture:'fixture',update:i===5?'Explosion':'Fountain',render:['Normal','Billboard_to_Local_Z','Billboard_to_World_Z','Linked','Motion_Blur','Aligned_to_Particle_Dir'][i],blend:'Lighten',birthrate:30,lifeexp:.6,sizestart:.3,sizeend:.8,colorstart:[1,.5,.25],colorend:[.2,.3,.1],alphastart:.8,alphaend:0,xgrid:2,ygrid:2,fps:i%2?7:12,framestart:i%2?3:0,frameend:i%2?0:3,velocity:1,randvel:.5,affectedbywind:'false'}},new Map([['fixture',texture]]),'authored');group.add(mesh);emitters.push(mesh);}
 const presentation=new ModelParticlePresentation({camera,seed:19,vertexPool:()=>pool,minWorkerParticles:0,report:(...args)=>reports.push(args)});return{root,camera,texture,presentation,reports,emitters};
}
const particles=e=>JSON.stringify(e.active188.records,(key,value)=>key==='emitter8'?undefined:value);

test('real pipelined workers preserve RNG, physics, explosion events, atlas clocks and uploaded vertices across60 moving frames',async()=>{
 const pool=new ResourceWorkerPool({size:3,createWorker}),reference=fixture(),worker=fixture(pool);
 try{
  for(let frame=0;frame<60;frame++){
   for(const f of [reference,worker]){f.camera.position.set(Math.sin(frame*.1)*5,7,9);f.camera.lookAt(2,1,0);f.root.children[0].rotation.y=frame*.03;if(frame===3||frame===25)f.emitters[5].userData.mdlPendingDetonate=1;f.presentation.update(f.root,[1/60,1/30,1/90][frame%3]);}
   await worker.presentation.vertexPreparation.work;assert.equal(worker.presentation.random.state,reference.presentation.random.state);assert.equal(worker.presentation.random.draws,reference.presentation.random.draws);
   const a=[...reference.presentation.entries.values()],b=[...worker.presentation.entries.values()];assert.equal(a.length,b.length);
   for(let i=0;i<a.length;i++){assert.equal(a[i].failed,false);assert.equal(b[i].failed,false);assert.equal(particles(a[i].e),particles(b[i].e));assert.equal(a[i].drawCount,b[i].drawCount);for(const name of ['position','uv','particleColor']){const aa=a[i].mesh.geometry.attributes[name],bb=b[i].mesh.geometry.attributes[name];if(!aa){assert.equal(bb,undefined);continue;}assert.deepEqual(new Uint8Array(aa.array.buffer,0,a[i].drawCount*aa.itemSize*aa.array.BYTES_PER_ELEMENT),new Uint8Array(bb.array.buffer,0,b[i].drawCount*bb.itemSize*bb.array.BYTES_PER_ELEMENT));}}
  }
  assert.ok(worker.presentation.vertexSnapshot().frames>40);assert.equal(worker.presentation.vertexSnapshot().failedJobs,0);
 }finally{reference.presentation.dispose();worker.presentation.dispose();pool.dispose();reference.texture.dispose();worker.texture.dispose();}
});

test('one frame remains bounded, expired work cannot overwrite sync fallback, and owner changes discard late results',async()=>{
 const f=fixture(),jobs=[],uploads=[],entry={alive:true};f.presentation.update(f.root,.1);const source=[...f.presentation.entries.values()][0],input=sampleParticleVertices(source.e,{...source.providers,cameraQuaternion:()=>[1,0,0,0]});let now=0,owner=true;
 const pool={size:2,run(_kind,payload){return new Promise(resolve=>jobs.push({payload,resolve}));}},p=new ParticleVertexPreparation({pool,current:()=>owner,valid:e=>e.alive,upload:(...args)=>uploads.push(args),now:()=>now,staleMs:100});
 assert.equal(p.submit([{entry,input},{entry,input}]),true);for(let i=0;i<20;i++){now++;assert.equal(p.frame().collect,false);assert.equal(p.submit([{entry,input}]),false);}assert.equal(jobs.length,2);
 now=200;assert.equal(p.frame().enabled,false);for(const job of jobs)job.resolve(buildParticleVertexBatch(job.payload));await p.work;assert.equal(uploads.length,0);assert.equal(p.stats.discarded,2);assert.equal(p.frame().enabled,true);
 jobs.length=0;p.submit([{entry,input}]);owner=false;for(const job of jobs)job.resolve(buildParticleVertexBatch(job.payload));await p.work;assert.equal(uploads.length,0);p.close();assert.equal(p.submit([{entry,input}]),false);f.presentation.dispose();f.texture.dispose();
});

test('worker failure resumes synchronous preparation; removed emitters cannot receive late GPU writes',async()=>{
 const pending=[],pool={size:2,run(_kind,payload){return new Promise((resolve,reject)=>pending.push({payload,resolve,reject}));}},f=fixture(pool);f.presentation.update(f.root,.1);assert.ok(pending.length);
 pending[0].reject(Error('worker crash'));for(const job of pending.slice(1))job.resolve(buildParticleVertexBatch(job.payload));await f.presentation.vertexPreparation.work;assert.equal(f.presentation.vertexPreparation.failed,true);f.presentation.update(f.root,.1);assert.ok([...f.presentation.entries.values()].every(e=>e.drawCount>0||e.e.active188.records.length===0));assert.equal(f.reports.filter(r=>r[0]==='particle.vertex-worker-fallback').length,1);
 f.presentation.dispose();f.texture.dispose();
 const jobs=[],g=fixture({size:2,run(_kind,payload){return new Promise(resolve=>jobs.push({payload,resolve}));}});g.presentation.update(g.root,.1);const old=[...g.presentation.entries.values()][0];g.root.children[0].removeFromParent();g.presentation.update(g.root,.1);for(const job of jobs)job.resolve(buildParticleVertexBatch(job.payload));await g.presentation.vertexPreparation.work;assert.equal(g.presentation.entries.has(old.mesh),false);assert.equal(old.drawCount,0);g.presentation.dispose();g.texture.dispose();
});

test('busy rendering workers never delay simulation/RNG or skip atlas clock advances',async()=>{
 const jobs=[],pool={size:2,run(_kind,payload){return new Promise(resolve=>jobs.push({payload,resolve}));}},reference=fixture(),worker=fixture(pool);
 try{
  for(let frame=0;frame<18;frame++){
   for(const f of [reference,worker]){if(frame===2||frame===9)f.emitters[5].userData.mdlPendingDetonate=1;f.presentation.update(f.root,[.033,.019,.041][frame%3]);}
   assert.equal(worker.presentation.random.state,reference.presentation.random.state);assert.equal(worker.presentation.random.draws,reference.presentation.random.draws);
   const a=[...reference.presentation.entries.values()],b=[...worker.presentation.entries.values()];for(let i=0;i<a.length;i++)assert.equal(particles(a[i].e),particles(b[i].e));assert.ok(jobs.length<=2);
  }
  assert.ok(worker.presentation.vertexSnapshot().skippedFrames>=15);for(const job of jobs)job.resolve(buildParticleVertexBatch(job.payload));await worker.presentation.vertexPreparation.work;
  // Returned draw data does not write snapshot atlas state back into simulation.
  const a=[...reference.presentation.entries.values()],b=[...worker.presentation.entries.values()];for(let i=0;i<a.length;i++)assert.equal(particles(a[i].e),particles(b[i].e));
 }finally{reference.presentation.dispose();worker.presentation.dispose();reference.texture.dispose();worker.texture.dispose();}
});
