import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';import {deserialize} from 'node:v8';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
export class SceneCaptureArchive {
 static async open(directory){const root=await fs.realpath(directory),manifest=JSON.parse(await fs.readFile(path.join(root,'manifest.json'),'utf8'));if(manifest.version!==1||manifest.complete!==true||!/^[a-f0-9]{64}$/.test(manifest.eventsSha256))throw Error('Scene capture is incomplete or unsupported');return new SceneCaptureArchive(root,manifest);}
 constructor(directory,manifest){this.directory=directory;this.manifest=manifest;this.unrecorded=new Set();}
 async *events(){
  const file=path.join(this.directory,'events.bin');if((await fs.lstat(file)).isSymbolicLink())throw Error('Unexpected capture event link');const handle=await fs.open(file,'r'),digest=createHash('sha256');let count=0,last=-1;
  let sequence=0;
  try{while(true){const header=Buffer.alloc(4),h=await handle.read(header,0,4,null);if(h.bytesRead===0)break;if(h.bytesRead!==4)throw Error('Truncated capture frame');const size=header.readUInt32LE();if(size<1||size>64*1024*1024)throw Error('Invalid capture frame size');const bytes=Buffer.alloc(size);let offset=0;while(offset<size){const row=await handle.read(bytes,offset,size-offset,null);if(!row.bytesRead)throw Error('Truncated capture payload');offset+=row.bytesRead;}digest.update(header);digest.update(bytes);const record=deserialize(bytes);if(!Number.isFinite(record.at)||record.at<0||record.at<last||!Number.isSafeInteger(record.sequence)||record.sequence<=sequence||!Object.hasOwn(this.manifest.contexts,record.context))throw Error('Invalid capture timeline');last=record.at;sequence=record.sequence;count++;yield record;}
   if(count!==this.manifest.events||digest.digest('hex')!==this.manifest.eventsSha256)throw Error('Capture timeline checksum mismatch');
  }finally{await handle.close();}
 }
 resolver(contextId){
  const context=Object.hasOwn(this.manifest.contexts,contextId)?this.manifest.contexts[contextId]:null;if(!context)throw Error('Unknown capture context');const owner=this;
  const unavailable=(key)=>{owner.unrecorded.add(contextId+':'+key);throw Object.assign(Error('Resource was not recorded: '+key),{code:'CAPTURE_MISSING'});};
  return{async getResource(name,type){const key=String(name).toLowerCase()+':'+type,record=Object.hasOwn(context.resources,key)?context.resources[key]:null;if(!record)return unavailable(key);if(record.missing)throw Object.assign(Error('Recorded resource lookup failed: '+key),{code:record.code});if(!/^[a-f0-9]{64}$/.test(record.sha256))throw Error('Invalid capture resource hash');const file=path.join(owner.directory,'objects',record.sha256);if((await fs.lstat(file)).isSymbolicLink())throw Error('Unexpected capture resource link');const bytes=await fs.readFile(file);if(bytes.length!==record.bytes||hash(bytes)!==record.sha256)throw Error('Capture resource checksum mismatch');return Uint8Array.from(bytes).buffer;},
   async getTextureResource(name){const key=String(name).toLowerCase();if(!Object.hasOwn(context.textures,key))return unavailable(key+':texture');const type=context.textures[key];if(type===null)throw Object.assign(Error('Recorded texture is unavailable'),{code:'RESOURCE_NOT_FOUND'});return{type,extension:({2073:'ktx',2033:'dds',3:'tga',6:'plt'})[type],bytes:await this.getResource(key,type)};},
   resourceRecord(name,type){const key=String(name).toLowerCase()+':'+type;return Object.hasOwn(context.resources,key)?context.resources[key]:null;},
   resourceNames(type){return Object.keys(context.resources).filter(key=>key.endsWith(':'+type)&&!context.resources[key].missing).map(key=>key.slice(0,key.lastIndexOf(':')));},
  };
 }
}
