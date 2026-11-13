import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {Worker} from 'node:worker_threads';

// Decoded rendering inputs only. This boundary never receives login requests,
// identity objects, raw peer packets or outgoing chat/actions.
const kinds=new Set(['module-info','module-time','module-pause-state','client-area','object-updates','object-control','party-list','player-list-all','player-list-add','player-list-delete','safe-projectile','object-visual','area-visual','gui-timing','tlk-overrides','custom-token','quickbar','sound-object','ambient-command','script-sound','voice-play','spell-targeting-data','script-targeting','script-targeting-data']);
const sensitive=/^(?:password|cdkey|communitypassword|credentials|loginidentity|privatekey|secretkey|sessionkey|authentication)$/i;
function clean(value){
 if(value===null||typeof value!=='object')return value;
 if(value instanceof ArrayBuffer||ArrayBuffer.isView(value))return value;
 if(Array.isArray(value))return value.map(clean);
 const out=Object.create(null);for(const key of Object.keys(value))if(!sensitive.test(key))out[key]=clean(value[key]);return out;
}
function sizeOf(value,seen=new Set()){
 if(value===null||value===undefined)return 8;if(typeof value==='string')return value.length*2+8;if(typeof value!=='object')return 8;
 if(value instanceof ArrayBuffer)return value.byteLength;if(ArrayBuffer.isView(value))return value.byteLength;
 if(seen.has(value))throw Error('Cyclic scene capture event');seen.add(value);let bytes=32;
 for(const key of Object.keys(value)){bytes+=key.length*2+sizeOf(value[key],seen);if(bytes>32*1024*1024)throw Error('Scene capture event exceeds 32 MiB');}seen.delete(value);return bytes;
}
export function captureMessage(message){
 if(!message||typeof message.kind!=='string'||!(kinds.has(message.kind)||message.kind.startsWith('nui-')||message.kind.startsWith('camera-')))return null;
 return clean(message);
}
export function captureView(value){
 const array=(input,size)=>Array.isArray(input)&&input.length===size&&input.every(n=>Number.isFinite(n)&&Math.abs(n)<1e9);
 if(!value||!array(value.position,3)||!array(value.target,3)||!array(value.quaternion,4)||!array(value.buffer,2)||value.buffer.some(n=>!Number.isInteger(n)||n<1||n>16384)||!Number.isInteger(value.areaId)||value.areaId<0||value.areaId>0xffffffff||![value.fov,value.near,value.far].every(Number.isFinite)||value.near<=0||value.far<=value.near||value.fov<=0||value.fov>=180)throw Error('Invalid scene capture view');
 const stats={};for(const key of ['objects','models','particleEmitters','particleActive','particleFailed','programs','geometries','textures','draws','shadowDraws'])if(Number.isFinite(value.stats?.[key])&&value.stats[key]>=0)stats[key]=value.stats[key];
 const flags={};for(const key of ['omitPreviews','modelCache','managedMatrices','scalarPoses','tileMatrices','cachedRoots','staticBatches','lightUniforms','materialReuse','shadowInputs','frameBudget'])if(typeof value.flags?.[key]==='boolean')flags[key]=value.flags[key];
 const shadowLights=Number.isInteger(value.shadowLights)&&value.shadowLights>=0&&value.shadowLights<=3?value.shadowLights:null;
 return{areaId:value.areaId,position:[...value.position],target:[...value.target],quaternion:[...value.quaternion],buffer:[...value.buffer],fov:value.fov,near:value.near,far:value.far,stats,flags,shadowLights};
}

export class SceneCapture {
 constructor({directory,maxQueuedBytes=256*1024*1024,maxBytes=2*1024*1024*1024,now=()=>performance.now()}){
  this.directory=path.resolve(directory,'scene-'+randomUUID());this.now=now;this.started=now();this.queued=0;this.pending=new Map();this.sequence=0;this.closed=false;this.failure=null;
  this.contexts=new WeakMap();this.contextIndex=0;this.seenResources=new Set();this.maxQueuedBytes=maxQueuedBytes;this.worker=new Worker(new URL('./scene_capture_worker.mjs',import.meta.url),{workerData:{directory:this.directory,maxBytes}});
  this.worker.on('message',message=>{if(message.kind==='ack'){this.queued-=this.pending.get(message.id)??0;this.pending.delete(message.id);}else if(message.kind==='failed')this.failure=message.reason;else if(message.kind==='sealed'){this.sealed=message;this.resolveClose?.(message);}});
  this.worker.on('error',error=>{this.failure=error.message;this.resolveClose?.({complete:false,reason:error.message});});
  this.worker.on('exit',code=>{if(!this.sealed){this.failure??='Capture worker exited before sealing ('+code+')';this.resolveClose?.({complete:false,reason:this.failure});}});
 }
 send(message,bytes=1024,transfer=[]){
  if(this.closed||this.failure)return false;
  if(this.queued+bytes>this.maxQueuedBytes){this.failure='Capture queue limit reached; recording is incomplete';return false;}
  const id=++this.sequence;this.queued+=bytes;this.pending.set(id,bytes);
  try{this.worker.postMessage({...message,id,at:this.now()-this.started},transfer);return true;}catch(error){this.queued-=bytes;this.pending.delete(id);this.failure=error.message;return false;}
 }
 contextFor(session){let context=this.contexts.get(session);if(!context){context='context-'+(++this.contextIndex);this.contexts.set(session,context);}return context;}
 event(context,event){try{const bytes=sizeOf(event);return this.send({kind:'event',context,event:clean(event)},bytes);}catch(error){this.failure=error.message;return false;}}
 message(context,event){try{const message=captureMessage(event.message);return message?this.event(context,{kind:'message',message,areaGeneration:event.areaGeneration}):false;}catch(error){this.failure=error.message;return false;}}
 resource(context,name,type,bytes){
  if(typeof name!=='string'||!/^[^\x00-\x1f/\\:]{1,32}$/.test(name)||!Number.isInteger(type)||type<0||type>65535){this.failure='Invalid capture resource identity';return false;}
  const key=context+':'+name.toLowerCase()+':'+type;if(this.seenResources.has(key))return true;
  const source=bytes instanceof ArrayBuffer?new Uint8Array(bytes):ArrayBuffer.isView(bytes)?new Uint8Array(bytes.buffer,bytes.byteOffset,bytes.byteLength):null;
  if(!source){this.failure='Unsupported capture resource bytes';return false;}
  if(this.closed||this.failure)return false;
  if(this.queued+source.byteLength>this.maxQueuedBytes){this.failure='Capture queue limit reached; recording is incomplete';return false;}
  const copy=source.slice(),sent=this.send({kind:'resource',context,name:name.toLowerCase(),type,bytes:copy.buffer},copy.byteLength,[copy.buffer]);if(sent)this.seenResources.add(key);return sent;
 }
 miss(context,name,type,code){return this.send({kind:'miss',context,name:name.toLowerCase(),type,code:code==='RESOURCE_NOT_FOUND'?code:'RESOURCE_ERROR'});}
 texture(context,name,type){return this.send({kind:'texture',context,name:name.toLowerCase(),type});}
 view(context,value){return this.event(context,{kind:'view',view:captureView(value)});}
 wrapResolver(context,resolver){
  const owner=this,read=resolver.getResource,texture=resolver.getTextureResource;
  resolver.getResource=async function(name,type){let bytes;try{bytes=await read.call(this,name,type);}catch(error){try{owner.miss(context,name,type,error.code);}catch{}throw error;}try{owner.resource(context,name,type,bytes);}catch(error){owner.failure=error.message;}return bytes;};
  if(texture)resolver.getTextureResource=async function(name){let result;try{result=await texture.call(this,name);}catch(error){try{owner.texture(context,name,null);}catch{}throw error;}try{owner.texture(context,name,result.type);}catch(error){owner.failure=error.message;}return result;};
  return resolver;
 }
 status(){return{recording:!this.closed&&!this.failure,directory:this.directory,queuedBytes:this.queued,failure:this.failure,sealed:this.sealed?.complete??false};}
 async close(){
  if(this.closeWork)return this.closeWork;
  this.closed=true;this.closeWork=new Promise(resolve=>{this.resolveClose=resolve;});
  if(this.worker.threadId===-1)this.resolveClose({complete:false,reason:this.failure??'Worker exited'});
  else this.worker.postMessage({kind:'close',failure:this.failure});
  const result=await this.closeWork;await this.worker.terminate();return{...result,directory:this.directory};
 }
}
