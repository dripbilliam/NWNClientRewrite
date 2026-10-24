// Synchronous renderer work only. Resource fetch/decoding and shader readiness
// remain asynchronous owners; this queue never waits on them inside a frame.
// A single driver upload/model constructor cannot be interrupted. Record its
// overshoot and yield before the next task rather than promising a hard cap.
export class FrameWorkBudget{
 constructor({budgetMs=2,clock=()=>performance.now(),schedule=callback=>requestAnimationFrame(callback),cancel=handle=>cancelAnimationFrame(handle)}={}){
  Object.assign(this,{budgetMs,clock,schedule,cancel});this.queues=[[],[],[]];this.pending=0;this.active=0;this.frame=null;this.deadline=-Infinity;this.closed=false;this.pumping=false;
  this.stats={frames:0,completed:0,cancelled:0,failed:0,cpuMs:0,maxTaskMs:0,maxQueued:0,oversized:0,kinds:{}};
 }
 run(work,{priority=1,kind='work',current=()=>true}={}){
  if(this.closed)return Promise.reject(this.closedError());
  return new Promise((resolve,reject)=>{const tier=Math.max(0,Math.min(2,Math.floor(Number(priority)||0)));this.queues[tier].push({work,kind,current,resolve,reject});this.pending++;this.stats.maxQueued=Math.max(this.stats.maxQueued,this.pending);
   // Async continuations of one multipart model can use the SAME frame's
   // remaining budget. Forcing every tiny part onto a new rAF adds seconds.
   if(this.clock()<this.deadline)this.drain();this.requestFrame();
  });
 }
 closedError(){return Object.assign(Error('Frame work budget is closed'),{code:'FRAME_WORK_CLOSED'});}
 requestFrame(){if(this.closed||!this.pending||this.frame!==null)return;this.frame=this.schedule(()=>{this.frame=null;if(this.closed)return;const requested=Number(typeof this.budgetMs==='function'?this.budgetMs():this.budgetMs);this.sliceBudget=Number.isFinite(requested)?Math.max(.1,Math.min(16,requested)):2;this.deadline=this.clock()+this.sliceBudget;this.stats.frames++;this.drain();this.requestFrame();});}
 drain(){if(this.pumping||this.closed)return;this.pumping=true;try{
  while(this.pending&&this.clock()<this.deadline&&!this.closed){const queue=this.queues.find(queue=>queue.length),job=queue.shift();this.pending--;let current;
   try{current=job.current();}catch(error){this.stats.failed++;job.reject(error);continue;}if(!current){this.stats.cancelled++;job.reject(Object.assign(Error('Frame work owner is no longer current'),{code:'FRAME_WORK_CANCELLED'}));continue;}
   const started=this.clock();this.active++;
   try{const value=job.work();if(value&&typeof value.then==='function')throw Error('Frame work must be synchronous');this.stats.completed++;this.stats.kinds[job.kind]=(this.stats.kinds[job.kind]??0)+1;job.resolve(value);}catch(error){this.stats.failed++;job.reject(error);}finally{this.active--;const duration=Math.max(0,this.clock()-started);this.stats.cpuMs+=duration;this.stats.maxTaskMs=Math.max(this.stats.maxTaskMs,duration);if(duration>this.sliceBudget)this.stats.oversized++;}
  }
 }finally{this.pumping=false;if(!this.pending&&this.frame!==null){this.cancel(this.frame);this.frame=null;}}}
 snapshot(){return{...this.stats,kinds:{...this.stats.kinds},queued:this.pending,active:this.active,scheduled:this.frame!==null,closed:this.closed};}
 dispose(){if(this.closed)return;this.closed=true;this.deadline=-Infinity;if(this.frame!==null)this.cancel(this.frame);this.frame=null;for(const queue of this.queues)for(const job of queue.splice(0)){this.pending--;this.stats.cancelled++;job.reject(this.closedError());}}
}
