import {ParticleSceneCapture} from '../../src/particle_worker_scene.js';
import {compareParticleWorkerState} from '../../src/particle_worker_compare.js';

export async function auditParticleWorker({presentation,root,camera,frames=4,warmFrames=20}){
 const beforeUpdate=presentation.update,beforePool=presentation.vertexPool,pending=new Map(),rows=[];let capture,worker,nextId=0;
 const request=message=>new Promise((resolve,reject)=>{const id=++nextId,timer=setTimeout(()=>{pending.delete(id);reject(Error('Particle worker audit deadline'));},30000);pending.set(id,{resolve,reject,timer});worker.postMessage({...message,id});});
 presentation.update=()=>{};
 try{
  presentation.vertexPreparation?.close();presentation.vertexPreparation=null;presentation.vertexPool=()=>null;beforeUpdate.call(presentation,root,0);
  capture=new ParticleSceneCapture(presentation,root);worker=new Worker(new URL('./particle-simulation-worker.mjs',import.meta.url),{type:'module'});
  worker.onmessage=event=>{const reply=event.data,entry=pending.get(reply.id);if(!entry)return;pending.delete(reply.id);clearTimeout(entry.timer);reply.error?entry.reject(Error(reply.error)):entry.resolve(reply);};worker.onerror=event=>{for(const entry of pending.values()){clearTimeout(entry.timer);entry.reject(Error(event.message));}pending.clear();};
  const initial=capture.initial(),initialState=capture.state(),init=await request({type:'init',scene:initial,oracle:true});rows.push({phase:'bootstrap',...compareParticleWorkerState(initialState,init.state)});
  for(let frame=0;frame<warmFrames;frame++){const delta=[1/60,.033,.01,.05][frame%4],input=capture.frame(delta);beforeUpdate.call(presentation,root,delta);const reply=await request({type:'frame',frame:input,discardVertices:true});if(reply.random.state!==presentation.random.state||reply.random.draws!==presentation.random.draws)throw Error('Particle RNG mismatch during warmup');}
  for(let frame=0;frame<frames;frame++){const delta=[1/60,.033,.01,.05][frame%4],input=capture.frame(delta);beforeUpdate.call(presentation,root,delta);const reference=capture.state(),reply=await request({type:'frame',frame:input,oracle:true});rows.push({phase:frame,simulationMs:reply.simulationMs,timing:reply.timing,...compareParticleWorkerState(reference,reply.state)});}
  const closed=await request({type:'close'});return{scope:'Offline persistent dedicated particle simulation oracle; fixed topology, synchronous source vertices, no FPS claim',warmFrames,passed:rows.every(row=>row.exact)&&closed.closed,nodes:initial.nodes.length,emitters:initial.entries.length,failedEmitters:initial.entries.filter(e=>e.failed).length,colliderGeometries:initial.geometries.length,rows};
 }finally{for(const entry of pending.values()){clearTimeout(entry.timer);entry.reject(Error('Particle audit closed'));}pending.clear();worker?.terminate();capture?.dispose();presentation.vertexPool=beforePool;presentation.update=beforeUpdate;}
}
