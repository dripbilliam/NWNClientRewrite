import {createHash} from 'node:crypto';
import {creationAppearance,previewTables} from './staging-creation-preview.mjs';
const hash=b=>createHash('sha256').update(b).digest('hex'),MAX=64*1024*1024,CHUNK=128*1024;
export function preparePreviewBundle(value,expected){
 const m=value?.manifest;if(m?.kind!=='creation-preview'||m.version!==1||m.inventory?.length!==0||m.entities?.length!==0||m.rigs?.entities?.length!==1||m.rigs.entities[0].id!==0||!m.counts?.meshes||!m.modelResources?.length||m.modelResources.length!==m.rigs.entities[0].models.length||JSON.stringify(m.creationAppearance)!==JSON.stringify(expected))throw Error('Invalid original creation preview export');
 if(typeof value.glbBase64!=='string'||value.glbBase64.length>MAX*4/3+4||!/^[A-Za-z0-9+/]*={0,2}$/.test(value.glbBase64))throw Error('Invalid creation model envelope');
 const glb=Buffer.from(value.glbBase64,'base64');if(glb.length<20||glb.readUInt32LE(0)!==0x46546c67||glb.readUInt32LE(4)!==2||glb.readUInt32LE(8)!==glb.length)throw Error('Invalid creation GLB');
 const manifest=Buffer.from(JSON.stringify({...m,sha256:hash(glb),bytes:glb.length}));if(manifest.length>MAX)throw Error('Creation metadata exceeds capacity');
 return{manifest,glb,bytes:manifest.length+glb.length,metadata:{creationAppearance:m.creationAppearance,modelResources:m.modelResources,counts:m.counts,rigs:{counts:m.rigs.counts}}};
}
export function* creationPreviewPackets(bundle,previewId){
 for(const part of ['manifest','glb']){const b=bundle[part];yield{kind:'creation-preview-begin',previewId,part,bytes:b.length,sha256:hash(b)};let index=0;for(let at=0;at<b.length;at+=CHUNK)yield{kind:'creation-preview-chunk',previewId,part,index:index++,data:b.subarray(at,at+CHUNK).toString('base64')};yield{kind:'creation-preview-part',previewId,part,chunks:index};}
 yield{kind:'creation-preview-ready',previewId};
}
export class CreationPreview{
 constructor({prepare,active,send,onPrepared=()=>{},limit=32*1024*1024}){Object.assign(this,{prepare,active,send,onPrepared,limit});this.serial=0;this.cache=new Map();this.bytes=0;this.key=null;this.queue=null;this.jobs=new Set();this.closed=false;}
 configure(draft,rules){
  if(!draft||!this.prepare){if(this.key!==null){this.key=null;this.queue=null;this.serial++;this.send({kind:'creation-preview-stop',previewId:this.serial});}return;}
  if(rules!==this.ruleOwner){this.ruleOwner=rules;this.key=null;this.cache.clear();this.bytes=0;}
  const appearance=creationAppearance(draft),key=JSON.stringify(appearance);if(this.closed||this.key===key)return;
  this.key=key;const id=++this.serial;this.send({kind:'creation-preview-loading',previewId:id,appearance});
  if(this.cache.has(key)){const cached=this.cache.get(key);this.cache.delete(key);this.cache.set(key,cached);this.deliver(cached,id);return;}
  this.queue={key,id,appearance,rules};this.pump();
 }
 valid(job){return!this.closed&&this.active()&&job.id===this.serial&&job.key===this.key;}
 deliver(bundle,id){if(this.closed||id!==this.serial||!this.active())return;for(const packet of creationPreviewPackets(bundle,id))this.send(packet);this.onPrepared({previewId:id,appearance:bundle.metadata.creationAppearance,resources:bundle.metadata.modelResources,counts:bundle.metadata.counts,rigs:bundle.metadata.rigs.counts,bytes:bundle.bytes,glbSha256:hash(bundle.glb)});}
 pump(){if(this.closed||this.jobs.size||!this.queue)return;const job=this.queue;this.queue=null;const work=(async()=>{if(!this.valid(job))return;const tables=previewTables(job.rules),result=await this.prepare({draft:job.appearance,tables});if(!this.valid(job))return;if(!result)throw Error('Creation model preparation was cancelled');const bundle=preparePreviewBundle(result,job.appearance);if(bundle.bytes<=this.limit){this.cache.set(job.key,bundle);this.bytes+=bundle.bytes;while(this.cache.size>8||this.bytes>this.limit){const oldest=this.cache.keys().next().value;this.bytes-=this.cache.get(oldest).bytes;this.cache.delete(oldest);}}this.deliver(bundle,job.id);})().catch(error=>{if(this.valid(job))this.send({kind:'creation-preview-error',previewId:job.id,text:error.message});}).finally(()=>{this.jobs.delete(work);this.pump();});this.jobs.add(work);}
 async retire(){this.closed=true;this.configure(null);await Promise.allSettled([...this.jobs]);this.cache.clear();this.bytes=0;return{closed:true,pending:this.jobs.size,cachedBytes:this.bytes};}
}
