import {NativeParticleWorkers} from './particle-workers.mjs';
export class ParticleDelivery {
 constructor({scope,data,wire,send,current,diagnose,report}){Object.assign(this,{scope,data,wire,send,current,diagnose,report});this.rows=new Map((data?.emitters??[]).map(row=>[row.id,row]));this.activeIds=new Set();this.workers=null;this.closed=false;this.busy=false;this.initializing=false;this.stats={epoch:data?.epoch??0,scope:{...scope},emitters:this.rows.size,workers:0,frames:0,vertices:0,maxVertices:0,frameWorstMs:0,excluded:0};report.epochs.push(this.stats);}
 async start(layout){
  if(this.closed||this.workers)return;
  this.workers=new NativeParticleWorkers({count:2,layout});this.stats.workers=2;this.initializing=true;
  const emitters=[...this.rows.values()];
  this.activeIds=new Set(emitters.map(row=>row.id));
  try{this.initialization=this.workers.reset({epoch:this.data.epoch,emitters,collision:this.data.collision??[]});await this.initialization;if(this.valid())this.send({...this.scope,kind:'particles-ready',epoch:this.data.epoch,ids:[...this.activeIds]});}
  catch(error){if(this.valid())throw error;}finally{this.initializing=false;}
 }
 valid(){return !this.closed&&this.current();}
 async frame(message){
  if(!this.valid()||message.epoch!==this.data.epoch||!this.workers)return;
  const finish=extra=>{if(this.valid())this.send({...this.scope,kind:'particle-complete',epoch:message.epoch,sequence:message.sequence,...extra});};
  if(this.busy||this.changing){finish({canceled:true});return;}this.busy=true;const began=performance.now();
  try{const result=await this.workers.frame({...message,poses:message.poses.filter(row=>this.activeIds.has(row.id))});if(!this.valid())return;
   if(result.stale||result.busy){finish({canceled:true});return;}
   this.wire.sendParticles(this.scope,result);this.stats.frames++;this.stats.vertices=result.emitters.reduce((sum,row)=>sum+row.count,0);this.stats.maxVertices=Math.max(this.stats.maxVertices,this.stats.vertices);this.stats.frameWorstMs=Math.max(this.stats.frameWorstMs,performance.now()-began);
   for(const row of result.diagnostics)this.diagnose(row.code,row.message,row.data);finish({vertices:this.stats.vertices,failed:result.state.filter(row=>row.failed).length});
  }catch(error){if(this.valid()){finish({failed:true,error:error.message});this.diagnose('godot.particle-frame-failed',error.message);}else this.stats.retiredFrames=(this.stats.retiredFrames??0)+1;}finally{this.busy=false;}
 }
 patch(change){
  const work=(this.mutation??Promise.resolve()).then(()=>this.applyPatch(change));this.mutation=work.catch(()=>{});return work;
 }
 async applyPatch({removeObjects,add}){
  if(!this.valid())return;
  const remove=[...this.rows.values()].filter(row=>removeObjects.includes(row.objectId)).map(row=>row.id);
  if(!remove.length&&!add.length)return;
  this.changing=true;
  for(const id of remove){this.rows.delete(id);this.activeIds.delete(id);}for(const row of add)this.rows.set(row.id,row);
  const supported=add;for(const row of supported)this.activeIds.add(row.id);
  try{await this.initialization;if(this.valid()&&this.workers)await this.workers.patch({epoch:this.data.epoch,remove,add:supported});this.stats.emitters=this.rows.size;}catch(error){if(this.valid())throw error;}finally{this.changing=false;}
 }
 async close(){if(this.closed)return;this.closed=true;await this.workers?.close();this.stats.closed=true;this.stats.pendingJobs=this.workers?.pending.size??0;this.stats.remainingThreads=this.workers?.slots.filter(slot=>slot.worker.threadId>=0).length??0;}
}
