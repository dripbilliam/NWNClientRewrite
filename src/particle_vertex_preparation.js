import {packParticleVertexBatch} from './particle_vertex_batch.js';

// One immutable frame at a time. The owner continues EVERY simulation and
// atlas update while workers construct draw vertices; no simulation is moved,
// skipped, throttled or given a separate RNG stream. WebGL stays with the owner.
export class ParticleVertexPreparation{
 constructor({pool,current=()=>true,valid=()=>true,upload,error=()=>{},report=()=>{},now=()=>performance.now(),staleMs=250}){
  Object.assign(this,{pool,current,valid,upload,error,report,now,staleMs});this.closed=false;this.failed=false;this.pending=false;this.generation=0;this.work=Promise.resolve();
  this.stats={frames:0,completedFrames:0,emitters:0,applied:0,discarded:0,skippedFrames:0,failedJobs:0,staleFrames:0,packMs:0,lastLatencyMs:0,maxLatencyMs:0};
 }
 frame(){
  if(this.closed||this.failed||this.pool.closed||!this.current())return{enabled:false,collect:false};
  if(this.pending&&this.now()-this.startedAt>this.staleMs){if(!this.invalidated){this.invalidate();this.stats.staleFrames++;}return{enabled:false,collect:false};}
  if(this.pending)this.stats.skippedFrames++;
  return{enabled:true,collect:!this.pending};
 }
 submit(items){
  if(this.pending||this.closed||this.failed||this.pool.closed||!this.current()||!items.length)return false;
  this.pending=true;this.invalidated=false;const generation=this.generation,started=this.startedAt=this.now(),groups=Array.from({length:Math.min(this.pool.size,items.length)},()=>({weight:0,items:[]}));this.stats.frames++;this.stats.emitters+=items.length;
  // Balance by particles, not emitters: one large emitter must not monopolize
  // a worker while three workers finish tiny effects and sit idle.
  for(const [key,item]of items.entries()){const group=groups.reduce((a,b)=>a.weight<=b.weight?a:b);group.items.push({key,input:item.input});group.weight+=item.input.records.length;}
  const jobs=groups.map(group=>{
   let job;try{job=this.pool.run('particle-vertices',packParticleVertexBatch(group.items));}catch(error){job=Promise.reject(error);}
   return Promise.resolve(job).then(frames=>{
    for(const frame of frames){
     const entry=items[frame.key]?.entry;
     if(!entry||this.closed||this.failed||generation!==this.generation||!this.current()||!this.valid(entry)){this.stats.discarded++;continue;}
     try{if(frame.error)this.error(entry,Error(frame.error));else{this.upload(entry,frame.out);this.stats.applied++;}}catch(error){this.error(entry,error);}
    }
   }).catch(error=>{
    if(this.closed||generation!==this.generation||!this.current())return;
    this.stats.failedJobs++;if(!this.failed){this.failed=true;this.generation++;this.report('particle.vertex-worker-fallback','Particle vertex worker failed; synchronous preparation will resume',{message:error.message});}
   });
  });
  this.stats.packMs+=this.now()-started;
  this.work=Promise.allSettled(jobs).then(()=>{this.pending=false;this.invalidated=false;this.stats.completedFrames++;this.stats.lastLatencyMs=this.now()-started;this.stats.maxLatencyMs=Math.max(this.stats.maxLatencyMs,this.stats.lastLatencyMs);});
  return true;
 }
 invalidate(){this.generation++;this.invalidated=true;}
 close(){if(this.closed)return;this.closed=true;this.invalidate();}
 snapshot(){return{...this.stats,pending:this.pending,closed:this.closed,failed:this.failed,workers:this.pool.size};}
}
