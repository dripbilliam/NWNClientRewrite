// Best-effort source preparation only. Foreground consumers bypass this queue
// and share the owner's actual cache promise. No instances, GPU compilation or
// canonical state is allowed here. Leave worker capacity for foreground work.
export class ResourcePrefetch{
 constructor({read,current=()=>true,limit=2}){if(!Number.isInteger(limit)||limit<1)throw Error('Invalid prefetch limit');Object.assign(this,{read,current,limit});this.queue=new Map();this.running=new Map();this.waiters=[];this.closed=false;this.stats={completed:0,failed:0,skipped:0,peak:0};}
 enqueue(requests){
  if(this.closed||!this.current())return;
  for(const request of requests)if(!this.running.has(request.key))this.queue.set(request.key,request);
  this.pump();
 }
 pump(){
  if(this.closed||!this.current()){this.stats.skipped+=this.queue.size;this.queue.clear();this.notify();return;}
  while(this.queue.size&&this.running.size<this.limit){
   const [key,request]=this.queue.entries().next().value;this.queue.delete(key);
   if(request.current&&!request.current()){this.stats.skipped++;continue;}
   const work=Promise.resolve().then(async()=>{if(this.closed||!this.current()||request.current&&!request.current()){this.stats.skipped++;return;}await this.read(request);this.stats.completed++;}).catch(()=>{this.stats.failed++;}).finally(()=>{this.running.delete(key);this.pump();this.notify();});
   this.running.set(key,work);this.stats.peak=Math.max(this.stats.peak,this.running.size);
  }
  this.notify();
 }
 notify(){if(!this.queue.size&&!this.running.size)for(const resolve of this.waiters.splice(0))resolve();}
 idle(){return this.queue.size||this.running.size?new Promise(resolve=>this.waiters.push(resolve)):Promise.resolve();}
 close(){if(this.closed)return;this.closed=true;this.stats.skipped+=this.queue.size;this.queue.clear();this.notify();}
 snapshot(){return{...this.stats,queued:this.queue.size,pending:this.running.size,limit:this.limit,closed:this.closed};}
}
