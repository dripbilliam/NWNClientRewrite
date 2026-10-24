export function resourceWorkerCount(cores=globalThis.navigator?.hardwareConcurrency??4){return Math.max(1,Math.min(4,Math.floor((Number(cores)||4)/2)));}

// Each resource context owns its pool. Retiring an area terminates in-flight
// decoders and rejects their owners; equal resrefs from another server never
// share jobs or results. Keep one WebGL owner on the renderer thread.
export class ResourceWorkerPool{
 constructor({size=resourceWorkerCount(),createWorker=()=>new Worker(new URL('./resource_worker.js',import.meta.url),{type:'module'}),timeoutMs=30000}={}){
  if(!Number.isInteger(size)||size<1||size>8)throw Error('Invalid resource worker count');
  Object.assign(this,{size,createWorker,timeoutMs});this.workers=new Set();this.queue=[];this.serial=0;this.closed=false;this.paletteSerial=0;this.paletteContexts=new WeakMap();
  this.stats={completed:0,failed:0,cancelled:0,cpuMs:0,maxQueued:0,kinds:{},paletteMessages:0,paletteBytes:0,paletteReuses:0,paletteFallbacks:0};
 }
 run(kind,payload){
  if(this.closed)return Promise.reject(Error('Resource worker pool is closed'));
  return new Promise((resolve,reject)=>{this.queue.push({id:++this.serial,kind,payload,resolve,reject});this.stats.maxQueued=Math.max(this.stats.maxQueued,this.queue.length);this.pump();});
 }
 // Never transfer an archive/cache owner's buffer. A private copy may be
 // detached by postMessage without corrupting another concurrent reader.
 decode(kind,input,extra={}){
  const bytes=input instanceof ArrayBuffer?new Uint8Array(input):new Uint8Array(input.buffer,input.byteOffset,input.byteLength);
  return this.run(kind,{...extra,buffer:bytes.slice().buffer});
 }
 // Opt-in immutable palette sources from one area's ModelSourceCache. Capture
 // once, then clone to each worker once, not once per actor/body-part texture.
 // Each worker holds at most ONE palette set, capped at 8 MiB. Oversized or
 // unfamiliar sources retain the ordinary per-task clone behavior.
 decodePlt(input,images,rows){
  if(this.closed)return Promise.reject(Error('Resource worker pool is closed'));
  let context=this.paletteContexts.get(images);
  if(!context){
   let bytes=0,safe=images instanceof Map;
   if(safe)for(const image of images.values()){if(!(image?.data instanceof Uint8Array)){safe=false;break;}bytes+=image.data.byteLength;}
   if(!safe||bytes>8*1024*1024){this.stats.paletteFallbacks++;return this.decode('plt',input,{palettes:images,rows});}
   const snapshot=new Map();for(const [key,image]of images)snapshot.set(key,{width:image.width,height:image.height,data:new Uint8Array(image.data.buffer,image.data.byteOffset,image.data.byteLength).slice()});
   context={id:++this.paletteSerial,images:snapshot,bytes};this.paletteContexts.set(images,context);
  }
  return this.decode('plt',input,{rows,paletteContext:context});
 }
 pump(){
  if(this.closed)return;
  while(this.queue.length){
   let slot=[...this.workers].find(s=>!s.job);
   if(!slot){
    if(this.workers.size>=this.size)return;
    try{
     const worker=this.createWorker();slot={worker,job:null};this.workers.add(slot);
     worker.addEventListener('message',event=>this.finish(slot,event.data));
     worker.addEventListener('error',event=>{event.preventDefault?.();this.fail(slot,Error(event.message??'Resource worker failed'));});
     worker.addEventListener('messageerror',()=>this.fail(slot,Error('Resource worker response could not be decoded')));
    }catch(error){const job=this.queue.shift();this.stats.failed++;job.reject(error);continue;}
   }
   const job=this.queue.shift();slot.job=job;
   job.timer=setTimeout(()=>this.fail(slot,Error('Resource worker task timed out')),this.timeoutMs);
   try{
    const context=job.payload.paletteContext;let payload=job.payload,sendPalette=false;
    if(context){const {paletteContext,...data}=payload;payload={...data,paletteId:context.id};sendPalette=slot.paletteId!==context.id;if(sendPalette)payload.paletteImages=context.images;}
    slot.worker.postMessage({id:job.id,kind:job.kind,payload},payload.buffer instanceof ArrayBuffer?[payload.buffer]:[]);
    if(context){if(sendPalette){slot.paletteId=context.id;this.stats.paletteMessages++;this.stats.paletteBytes+=context.bytes;}else this.stats.paletteReuses++;}job.payload=null;
   }
   catch(error){this.fail(slot,error);}
  }
 }
 finish(slot,message){
  if(this.closed||!this.workers.has(slot)||!slot.job||message.id!==slot.job.id)return;
  const job=slot.job;clearTimeout(job.timer);slot.job=null;
  const cpuMs=Number.isFinite(message.cpuMs)?message.cpuMs:0;this.stats.cpuMs+=cpuMs;
  const kind=this.stats.kinds[job.kind]??={completed:0,cpuMs:0};kind.cpuMs+=cpuMs;
  if(message.error){this.stats.failed++;const error=Error(message.error.message);error.name=message.error.name??'Error';job.reject(error);}
  else{this.stats.completed++;kind.completed++;
   // Structured clone normalizes null-prototype property dictionaries. Restore
   // the ASCII parser's lookup semantics for untrusted property names.
   if(job.kind==='model'&&message.result?.format==='ASCII MDL')for(const node of message.result.nodes)Object.setPrototypeOf(node.properties,null);
   if(job.kind==='2da')for(const row of message.result.orderedRows)Object.setPrototypeOf(row,null);
   job.resolve(message.result);
  }
  this.pump();
 }
 fail(slot,error){
  if(!this.workers.delete(slot))return;
  slot.worker.terminate();const job=slot.job;slot.job=null;if(job){clearTimeout(job.timer);this.stats.failed++;job.reject(error);}this.pump();
 }
 snapshot(){return{...this.stats,kinds:structuredClone(this.stats.kinds),limit:this.size,workers:this.workers.size,pending:[...this.workers].filter(s=>s.job).length,queued:this.queue.length,closed:this.closed};}
 dispose(){
  if(this.closed)return;this.closed=true;this.paletteContexts=new WeakMap();
  const jobs=this.queue.splice(0);for(const slot of this.workers){slot.worker.terminate();if(slot.job){clearTimeout(slot.job.timer);jobs.push(slot.job);slot.job=null;}}this.workers.clear();
  for(const job of jobs){this.stats.cancelled++;job.reject(Error('Resource worker pool is closed'));}
 }
}
