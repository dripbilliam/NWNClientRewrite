import {parentPort,workerData} from 'node:worker_threads';
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';import {serialize} from 'node:v8';
const {directory,maxBytes}=workerData,manifest={version:1,complete:false,created:new Date().toISOString(),resourcePolicy:'Frozen first successful resolution per session; no network or installed fallback during replay',bytes:0,events:0,contexts:Object.create(null)},hash=bytes=>createHash('sha256').update(bytes).digest('hex');
let handle,failure=null;const eventsHash=createHash('sha256'),contexts=id=>manifest.contexts[id]??={resources:Object.create(null),textures:Object.create(null)};
let work=(async()=>{await fs.mkdir(path.join(directory,'objects'),{recursive:true});handle=await fs.open(path.join(directory,'events.bin'),'wx');})();
async function write(message){
 if(message.kind==='close'){
  await handle?.sync();await handle?.close();manifest.eventsSha256=eventsHash.digest('hex');manifest.complete=!failure&&!message.failure;manifest.failure=failure??message.failure??null;
  await fs.writeFile(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});parentPort.postMessage({kind:'sealed',complete:manifest.complete,events:manifest.events,bytes:manifest.bytes,reason:manifest.failure});return;
 }
 if(failure)return;
 if(typeof message.context!=='string'||!/^context-\d+$/.test(message.context))throw Error('Invalid capture context');
 const context=contexts(message.context);
 if(message.kind==='resource'){
  const bytes=Buffer.from(message.bytes),sha256=hash(bytes),key=message.name+':'+message.type,old=context.resources[key];
  if(old?.sha256===sha256)return;
  if(old?.sha256&&old.sha256!==sha256)throw Error('Resource changed within capture context: '+key);
  if(manifest.bytes+bytes.length>maxBytes)throw Error('Capture disk limit reached');
  try{await fs.writeFile(path.join(directory,'objects',sha256),bytes,{flag:'wx'});manifest.bytes+=bytes.length;}catch(error){if(error.code!=='EEXIST')throw error;}
  context.resources[key]={sha256,bytes:bytes.length};return;
 }
 if(message.kind==='miss'){const key=message.name+':'+message.type;if(!context.resources[key])context.resources[key]={missing:true,code:message.code};return;}
 if(message.kind==='texture'){const old=context.textures[message.name];if(old!==undefined&&old!==message.type)throw Error('Texture selection changed within capture context');context.textures[message.name]=message.type;return;}
 if(message.kind==='event'){
  const bytes=serialize({sequence:message.id,at:message.at,context:message.context,event:message.event}),header=Buffer.alloc(4);header.writeUInt32LE(bytes.length);
  if(manifest.bytes+bytes.length+4>maxBytes)throw Error('Capture disk limit reached');
  await handle.writeFile(header);await handle.writeFile(bytes);eventsHash.update(header);eventsHash.update(bytes);manifest.bytes+=bytes.length+4;manifest.events++;
 }
}
parentPort.on('message',message=>{work=work.then(()=>write(message)).catch(error=>{failure??=error.message;parentPort.postMessage({kind:'failed',reason:failure});if(message.kind==='close')parentPort.postMessage({kind:'sealed',complete:false,reason:failure});}).finally(()=>{if(message.id)parentPort.postMessage({kind:'ack',id:message.id});});});
