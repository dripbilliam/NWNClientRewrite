import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {parseGff} from '../src/gff.js';
import {isNetworkBytes} from '../src/network_bytes.js';
import {MAX_NETWORK_CHARACTER_BYTES} from '../src/network_character.js';
const validId=id=>typeof id==='string'&&/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/.test(id);
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const local=value=>value?.entries?.find(e=>typeof e.text==='string')?.text??'';

// Owned application vault, not the installed game directory. Blob filenames
// are content hashes; server names never become paths. A durable immutable
// BIC precedes an atomic entry pointer; failed saves retain the old version.
// Entry IDs are local storage identity, never canonical game OBJECT_IDs.
export class NetworkCharacterVault{
 constructor(directory){this.directory=path.resolve(directory);this.queue=Promise.resolve();}
 async initialize(){await fs.mkdir(path.join(this.directory,'blobs'),{recursive:true});await fs.mkdir(path.join(this.directory,'entries'),{recursive:true});}
 async list(){
  await this.initialize();const result=[];
  for(const file of await fs.readdir(path.join(this.directory,'entries'))){const id=file.slice(0,-5);if(!file.endsWith('.json')||!validId(id))continue;const entry=await this.entry(id);result.push(entry);}
  return result.sort((a,b)=>b.savedAt.localeCompare(a.savedAt)||a.id.localeCompare(b.id));
 }
 async entry(id){
  if(!validId(id))throw new Error('Invalid saved character selection');
  const e=JSON.parse(await fs.readFile(path.join(this.directory,'entries',id+'.json'),'utf8'));
  if(e.id!==id||typeof e.sha256!=='string'||!/^[a-f0-9]{64}$/.test(e.sha256)||!Number.isSafeInteger(e.bytes)||e.bytes<56||e.bytes>MAX_NETWORK_CHARACTER_BYTES||typeof e.name!=='string'||typeof e.savedAt!=='string'||!Number.isFinite(Date.parse(e.savedAt)))throw new Error('Saved character metadata is invalid');return e;
 }
 async read(id){const e=await this.entry(id),bytes=await fs.readFile(path.join(this.directory,'blobs',e.sha256+'.bic'));if(bytes.length!==e.bytes||hash(bytes)!==e.sha256)throw new Error('Saved character integrity check failed');parseGff(bytes,'BIC ');return Uint8Array.from(bytes);}
 save(message,{id=null}={}){
  if(id!==null&&!validId(id))return Promise.reject(new Error('Invalid saved character entry'));
  if(!isNetworkBytes(message.data)||message.data.length<56||message.data.length>MAX_NETWORK_CHARACTER_BYTES)return Promise.reject(new Error('Invalid exported character data'));
  const bytes=Uint8Array.from(message.data),work=this.queue.then(async()=>{
   const root=parseGff(bytes,'BIC ').root;await this.initialize();if(id!==null)await this.entry(id);
   const digest=hash(bytes),entry={id:id??crypto.randomUUID(),sha256:digest,bytes:bytes.length,name:[local(root.FirstName),local(root.LastName)].filter(Boolean).join(' ')||'Saved character',savedAt:new Date().toISOString()};
   const blob=path.join(this.directory,'blobs',digest+'.bic');
   try{const existing=await fs.readFile(blob);if(existing.length!==bytes.length||hash(existing)!==digest)throw new Error('Saved character blob integrity check failed');}
   catch(error){if(error.code!=='ENOENT')throw error;const temporary=blob+'.'+crypto.randomUUID()+'.tmp';try{const file=await fs.open(temporary,'wx');try{await file.writeFile(bytes);await file.sync();}finally{await file.close();}await fs.rename(temporary,blob);}catch(writeError){await fs.unlink(temporary).catch(()=>{});throw writeError;}}
   const destination=path.join(this.directory,'entries',entry.id+'.json'),temporary=destination+'.'+crypto.randomUUID()+'.tmp';
   try{const out=await fs.open(temporary,'wx');try{await out.writeFile(JSON.stringify(entry)+'\n');await out.sync();}finally{await out.close();}await fs.rename(temporary,destination);}catch(error){await fs.unlink(temporary).catch(()=>{});throw error;}
   return entry;
  }).finally(()=>bytes.fill(0));this.queue=work.catch(()=>{});return work;
 }
}
