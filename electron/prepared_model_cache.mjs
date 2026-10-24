import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash,randomUUID} from 'node:crypto';
import {deserialize} from 'node:v8';
import {Worker} from 'node:worker_threads';

const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const root=fileURLToPath(new URL('../',import.meta.url)),magic=Buffer.from('NWNPRP01');
// Invalidate for every local parser/geometry dependency, the dependency lock,
// this format and V8's serialization ABI. Names/paths never select a cache hit.
export async function preparedModelSchema(){
 const files=new Map(),visit=async file=>{
  if(files.has(file))return;const text=await fs.readFile(file,'utf8');files.set(file,text);
  for(const match of text.matchAll(/(?:from\s*|import\s*)['"]([.][^'"]+)['"]/g))await visit(path.resolve(path.dirname(file),match[1]));
 };
 await visit(fileURLToPath(import.meta.url));await visit(path.join(root,'electron/prepared_model_worker.mjs'));
 const hash=createHash('sha256').update('prepared-model-v1|'+process.versions.v8);
 for(const[file,text]of [...files].sort(([a],[b])=>a.localeCompare(b)))hash.update(path.relative(root,file).replaceAll('\\','/')+'\0'+text+'\0');
 hash.update(await fs.readFile(path.join(root,'package-lock.json')));return hash.digest('hex');
}

export class PreparedModelCache{
 constructor({directory,maxMemoryBytes=256*1024*1024,maxDiskBytes=2*1024*1024*1024,size=2,schema=null,report=()=>{}}){
  if(!directory||!Number.isInteger(size)||size<1||size>4)throw Error('Invalid prepared-model cache options');
  Object.assign(this,{directory,maxMemoryBytes,maxDiskBytes,size,report});this.schemaWork=schema?Promise.resolve(schema):null;
  this.memory=new Map();this.pending=new Map();this.workers=new Set();this.queue=[];this.serial=0;this.closed=false;this.writes=new Set();this.bytes=0;
  this.stats={requests:0,rendererHits:0,memoryHits:0,diskHits:0,misses:0,failed:0,corrupt:0,writes:0,writeFailures:0,evicted:0,preparedMeshes:0,preparedVertices:0,cpuMs:0};
 }
 async prepare(input,{knownKey=null,metadata=false}={}){
  if(this.closed)throw Error('Prepared-model cache is closed');this.stats.requests++;
  const source=input instanceof ArrayBuffer?new Uint8Array(input):new Uint8Array(input.buffer,input.byteOffset,input.byteLength);
  // Hash and copy the caller's bytes before yielding; never detach its archive.
  const sourceHash=digest(source),copy=source.slice(),schema=await(this.schemaWork??=preparedModelSchema());
  if(this.closed)throw Error('Prepared-model cache is closed');
  const key=digest(schema+'|'+sourceHash);
  if(metadata&&knownKey===key){this.stats.rendererHits++;return{key,reused:true};}
  let work=this.pending.get(key);
  if(!work){work=this.encoded(key,copy,schema,sourceHash);this.pending.set(key,work);void work.finally(()=>{if(this.pending.get(key)===work)this.pending.delete(key);}).catch(()=>{});}
  const bytes=await work;if(this.closed)throw Error('Prepared-model cache is closed');
  // Every caller owns its base model. Inheritance and instances cannot mutate
  // the persisted model, another area or another server's same-named model.
  const model=deserialize(bytes).model;
  for(const node of model.nodes)if(node.properties)Object.setPrototypeOf(node.properties,null);
  return metadata?{key,model,bytes:bytes.byteLength}:model;
 }
 remember(key,bytes){
  if(this.memory.has(key)){this.bytes-=this.memory.get(key).byteLength;this.memory.delete(key);}
  if(bytes.byteLength>this.maxMemoryBytes)return;
  this.memory.set(key,bytes);this.bytes+=bytes.byteLength;
  while(this.bytes>this.maxMemoryBytes){const[k,v]=this.memory.entries().next().value;this.memory.delete(k);this.bytes-=v.byteLength;this.stats.evicted++;}
 }
 async encoded(key,source,schema,sourceHash){
  if(this.memory.has(key)){this.stats.memoryHits++;const bytes=this.memory.get(key);this.remember(key,bytes);return bytes;}
  const directory=path.join(this.directory,schema),file=path.join(directory,key+'.bin');
  try{
   const stat=await fs.stat(file);if(stat.size>256*1024*1024||stat.size<40)throw Error('Invalid prepared-model cache size');
   const data=await fs.readFile(file),bytes=data.subarray(40);
   if(!data.subarray(0,8).equals(magic)||data.subarray(8,40).toString('hex')!==digest(bytes))throw Error('Invalid prepared-model cache checksum');
   const decoded=deserialize(bytes);if(decoded.schema!==schema||decoded.sourceHash!==sourceHash||!Array.isArray(decoded.model?.nodes))throw Error('Stale prepared-model cache entry');
   if(this.closed)throw Error('Prepared-model cache is closed');
   this.stats.diskHits++;this.remember(key,bytes);void fs.utimes(file,new Date(),new Date()).catch(()=>{});return bytes;
  }catch(error){
   if(this.closed)throw error;
   if(error.code!=='ENOENT'){this.stats.corrupt++;void fs.unlink(file).catch(()=>{});}
  }
  this.stats.misses++;const result=await this.calculate(source,schema,sourceHash);
  if(this.closed)throw Error('Prepared-model cache is closed');
  const bytes=Buffer.from(result.buffer);this.stats.preparedMeshes+=result.stats.meshes;this.stats.preparedVertices+=result.stats.vertices;this.stats.cpuMs+=result.stats.cpuMs;this.remember(key,bytes);
  // Storage is best effort; a slow/full disk never holds up an already prepared
  // model. Atomic rename and checksum make interrupted writes disposable.
  if(bytes.byteLength>256*1024*1024-40)return bytes;
  const writing=(async()=>{const temporary=file+'.'+randomUUID()+'.tmp';try{await fs.mkdir(directory,{recursive:true});await fs.writeFile(temporary,Buffer.concat([magic,Buffer.from(digest(bytes),'hex'),bytes]));await fs.rename(temporary,file);this.stats.writes++;await this.trim(file,bytes.byteLength+40);}catch(error){this.stats.writeFailures++;this.report('renderer.model-cache-write-failed',error.message);}finally{await fs.unlink(temporary).catch(()=>{});}})();
  this.writes.add(writing);void writing.finally(()=>this.writes.delete(writing));return bytes;
 }
 calculate(source,schema,sourceHash){
  return new Promise((resolve,reject)=>{this.queue.push({id:++this.serial,source,schema,sourceHash,resolve,reject});this.pump();});
 }
 pump(){
  if(this.closed)return;
  while(this.queue.length){
   let slot=[...this.workers].find(s=>!s.job);
   if(!slot){if(this.workers.size>=this.size)return;
    let worker;try{worker=new Worker(new URL('./prepared_model_worker.mjs',import.meta.url));}catch(error){this.stats.failed++;this.queue.shift().reject(error);continue;}slot={worker,job:null};this.workers.add(slot);
    worker.on('message',message=>{if(!slot.job||message.id!==slot.job.id)return;const job=slot.job;slot.job=null;clearTimeout(slot.timer);if(message.error){this.stats.failed++;job.reject(Error(message.error));}else job.resolve(message);slot.idle=setTimeout(()=>this.retire(slot),5000);slot.idle.unref?.();this.pump();});
    worker.on('error',error=>this.retire(slot,error));worker.on('exit',code=>{if(this.workers.has(slot))this.retire(slot,Error('Model preparation worker exited '+code));});
   }
   clearTimeout(slot.idle);const job=this.queue.shift();slot.job=job;
   slot.timer=setTimeout(()=>this.retire(slot,Error('Model preparation timed out')),30000);
   try{slot.worker.postMessage({id:job.id,buffer:job.source.buffer,schema:job.schema,sourceHash:job.sourceHash},[job.source.buffer]);}catch(error){this.retire(slot,error);}
  }
 }
 retire(slot,error=Error('Prepared-model cache is closed')){
  if(!this.workers.delete(slot))return;clearTimeout(slot.timer);clearTimeout(slot.idle);void slot.worker.terminate();
  if(slot.job){this.stats.failed++;slot.job.reject(error);slot.job=null;}this.pump();
 }
 async trim(file,size){
  // Scan old namespaces once, then serialize incremental accounting. Repeated
  // writes must not rescan the whole cache or overshoot by dozens of entries.
  const work=(this.trimming??Promise.resolve()).catch(()=>{}).then(async()=>{
   if(!this.diskEntries){this.diskEntries=new Map();for(const folder of await fs.readdir(this.directory,{withFileTypes:true})){if(!folder.isDirectory()||!/^[a-f0-9]{64}$/.test(folder.name))continue;const dir=path.join(this.directory,folder.name);for(const entry of await fs.readdir(dir)){if(!/^[a-f0-9]{64}\.bin$/.test(entry))continue;const name=path.join(dir,entry);try{const stat=await fs.stat(name);this.diskEntries.set(name,{size:stat.size,at:stat.mtimeMs});}catch{}}}}
   this.diskEntries.set(file,{size,at:Date.now()});let total=[...this.diskEntries.values()].reduce((n,e)=>n+e.size,0);
   if(total<=this.maxDiskBytes)return;
   for(const[name,entry]of [...this.diskEntries].sort(([,a],[,b])=>a.at-b.at)){if(total<=this.maxDiskBytes)break;await fs.unlink(name).catch(()=>{});this.diskEntries.delete(name);total-=entry.size;}
  });this.trimming=work;await work;
 }
 snapshot(){return{...this.stats,memoryBytes:this.bytes,memoryEntries:this.memory.size,pending:this.pending.size,workers:this.workers.size,queued:this.queue.length,closed:this.closed};}
 async flush(){await Promise.allSettled([...this.writes]);}
 async dispose(){if(this.closed)return;this.closed=true;for(const slot of [...this.workers])this.retire(slot);for(const job of this.queue.splice(0))job.reject(Error('Prepared-model cache is closed'));await Promise.allSettled([...this.pending.values()]);await this.flush();this.memory.clear();this.bytes=0;}
}
