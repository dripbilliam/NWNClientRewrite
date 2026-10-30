import {parentPort,workerData} from 'node:worker_threads';
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
const {directory}=workerData;const hash=createHash('sha256');const catalogs=new Set();
const sensitive=/^(?:password|cdkey|communitypassword|credentials|loginidentity|privatekey|secretkey|sessionkey|authentication)$/i;
function clean(value){if(value===null||typeof value!=='object')return value;if(Array.isArray(value))return value.map(clean);const out={};for(const[k,v]of Object.entries(value))if(!sensitive.test(k))out[k]=clean(v);return out;}
// Only decoded presentation envelopes reach this writer. Preserve server NUI
// tokens (window IDs); authentication/hello and client commands are never input.
let handle,bytes=0,events=0,failure=null,closing=false;
let work=(async()=>{await fs.mkdir(directory,{recursive:true});handle=await fs.open(path.join(directory,'timeline.jsonl'),'wx');})();
async function write(message){
 if(message.kind==='close'){
  closing=true;await handle?.sync();await handle?.close();const resources=[];
  for(const name of catalogs){try{const raw=await fs.readFile(path.join(directory,name,'manifest.json'));const manifest=JSON.parse(raw);if(manifest.complete!==true)throw Error(manifest.failure??'Incomplete native resources');resources.push({directory:name,sha256:createHash('sha256').update(raw).digest('hex'),resources:Object.keys(manifest.resources).length});}catch(error){failure??=name+': '+error.message;}}
  if(!events||!catalogs.size)failure??='No native world/resource context was recorded';
  const manifest={version:1,complete:!failure&&!message.failure,failure:failure??message.failure??null,events,bytes,timelineSha256:hash.digest('hex'),catalogs:resources,metadata:clean(message.metadata??{}),policy:'Decoded native presentation inputs and original resource bytes. No authentication packets, outgoing actions, or rendering preparation. Fresh application cache on replay; OS/driver cache state uncontrolled.'};
  await fs.writeFile(path.join(directory,'recording.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});parentPort.postMessage({kind:'sealed',...manifest,directory});return;
 }
 if(closing||failure)return;
 const value=JSON.parse(message.text);let record={sequence:message.sequence,at:message.at,kind:message.kind,value:clean(value)};
 if(message.kind==='frame'&&value.kind==='setup'){
  const name=path.basename(value.recordingDirectory??'');if(!/^catalog-[0-9]+$/.test(name)||path.resolve(value.recordingDirectory)!==path.join(directory,name))throw Error('Recording catalog escaped its private directory');
  catalogs.add(name);record.value={kind:'setup',connection:value.connection,install:value.install,moduleName:value.moduleName,serverLabel:value.serverLabel,interactive:true,resourceSources:{recordedCatalog:name,customTlk:value.resourceSources?.customTlk?{name:value.resourceSources.customTlk.name}:null}};
 }
 const line=JSON.stringify(record)+'\n';bytes+=Buffer.byteLength(line);if(bytes>256*1024*1024)throw Error('Native loading timeline exceeded disk bound');
 await handle.writeFile(line);hash.update(line);events++;
}
parentPort.on('message',message=>{work=work.then(()=>write(message)).catch(error=>{failure??=error.message;parentPort.postMessage({kind:'failure',reason:failure});if(message.kind==='close')parentPort.postMessage({kind:'sealed',complete:false,reason:failure});}).finally(()=>{if(message.bytes)parentPort.postMessage({kind:'ack',bytes:message.bytes});});});
