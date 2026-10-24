// Fresh public NWSync test. Actual server assets stay outside this workspace.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {NWSyncContent} from '../electron/nwsync_content.mjs';
import {readServerInfoAdvertisement} from '../src/server_discovery.js';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {parseTalkTable} from '../src/talk_table.js';
const workspace=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [discoveryFile,outputFile]=process.argv.slice(2),output=path.resolve(outputFile??'');
if(!discoveryFile||!output.startsWith(path.join(workspace,'backups','animations')+path.sep))throw new Error('Discovery metadata and evidence report path are required');
const discovery=JSON.parse(await fs.readFile(discoveryFile,'utf8')),advertisement=readServerInfoAdvertisement(Buffer.from(discovery.advertisementHex,'hex'));
if(!advertisement)throw new Error('Server did not advertise public NWSync content');
const runDirectory=path.resolve(os.tmpdir(),'..','NwnReplacementClient','ContentTests','public-'+crypto.randomUUID()),directory=path.join(runDirectory,'cache');
await fs.mkdir(runDirectory,{recursive:true});await fs.mkdir(directory);
const sha=bytes=>crypto.createHash('sha1').update(bytes).digest('hex'),completedObjects=new Set(),requestedObjects=new Set();
const report={startedAt:new Date().toISOString(),scope:'Publicly advertised content only; login rejection recorded separately; no character upload or gameplay',endpoint:discovery.endpoint,module:discovery.moduleName,advertisement,stage:'download',cache:{directory,initialEntries:(await fs.readdir(directory)).length,reuseInstalledNWSync:false,nativeDatabaseReads:0},downloads:{requests:0,completed:0,bytes:0,statuses:{},manifests:[]},diagnostics:[],reads:[],readFailures:[]};
let queue=Promise.resolve();
function save(){report.elapsedSeconds=Math.round((Date.now()-Date.parse(report.startedAt))/1000);report.downloads.distinctObjectsRequested=requestedObjects.size;report.downloads.distinctObjectsCompleted=completedObjects.size;const snapshot=JSON.stringify(report,null,2)+'\n';queue=queue.then(async()=>{await fs.writeFile(output+'.tmp',snapshot);await fs.rename(output+'.tmp',output);});return queue;}
async function auditedFetch(url,options){
 const parsed=new URL(url),hash=parsed.pathname.split('/').at(-1),kind=parsed.pathname.includes('/manifests/')?'manifest':'object';report.downloads.requests++;if(kind==='object')requestedObjects.add(hash);
 const response=await fetch(url,options);report.downloads.statuses[response.status]=(report.downloads.statuses[response.status]??0)+1;if(!response.body)return response;
 let bytes=0;const chunks=[],body=response.body.pipeThrough(new TransformStream({transform(chunk,controller){bytes+=chunk.length;report.downloads.bytes+=chunk.length;if(kind==='manifest'&&bytes<=64*1024*1024)chunks.push(chunk);controller.enqueue(chunk);},flush(){report.downloads.completed++;if(response.ok&&kind==='object')completedObjects.add(hash);if(response.ok&&kind==='manifest'){const raw=Buffer.concat(chunks,bytes),manifest=parseNWSyncManifest(raw),unique=[...new Map(manifest.entries.map(entry=>[entry.hash,entry])).values()];report.downloads.manifests.push({hash,downloadHashMatches:sha(raw)===hash,bytes,resources:manifest.entries.length,uniqueObjects:unique.length,uncompressedBytes:unique.reduce((n,e)=>n+e.size,0),twoDATables:manifest.entries.filter(e=>e.type===2017).length});}}}));
 return new Response(body,{status:response.status,statusText:response.statusText,headers:response.headers});
}
// A null nativeDirectory structurally disables all original DB lookups. The
// helper may only be used to decompress newly downloaded Zstandard buffers.
const content=new NWSyncContent({directory,nativeDirectory:null,concurrency:16,fetch:auditedFetch,onProgress:progress=>report.progress=progress,onDiagnostic:diagnostic=>report.diagnostics.push(diagnostic)});
const timer=setInterval(()=>{void save().catch(()=>{});console.log(JSON.stringify({stage:report.stage,progress:report.progress,downloadedMiB:Number((report.downloads.bytes/1048576).toFixed(1)),objects:completedObjects.size,elapsedSeconds:report.elapsedSeconds}));},15000),deadline=setTimeout(()=>{report.timedOut=true;content.close();},3600000);
await save();
try{
 const selected=[advertisement.hash,...advertisement.manifests.filter(m=>m.language===0||m.language===255).map(m=>m.hash)],layers=[];
 for(const hash of new Set(selected))layers.push(await content.findManifest(hash,{advertisement}));
 report.stage='read-downloaded-rules';await save();
 const active=new Map();for(const layer of layers)for(const entry of layer.entries)active.set(`${entry.name}:${entry.type}`,{layer,entry});
 for(const {layer,entry}of active.values()){
  if(entry.type!==2017&&entry.type!==2018)continue;
  try{
   const bytes=Buffer.from(await layer.getResource(entry.name,entry.type));if(!completedObjects.has(entry.hash)||sha(bytes)!==entry.hash)throw new Error('Resource was not verified against a fresh download');
   const summary={name:entry.name,type:entry.type,sha1:entry.hash,manifest:layer.name,bytes:bytes.length,downloadedThisRun:true};
   if(entry.type===2017){const table=parse2da(decodeResourceText(bytes));summary.rows=table.orderedRows.length;summary.columns=table.columns;}
   else{const table=parseTalkTable(bytes);summary.language=table.language;summary.strings=table.count;let nonempty=0;for(let i=0;i<table.count;i++)if(table.get(i))nonempty++;summary.nonemptyStringsRead=nonempty;}
   report.reads.push(summary);
  }catch(error){report.readFailures.push({name:entry.name,type:entry.type,error:error.message});}
 }
 report.cache.objects=(await fs.readdir(path.join(directory,'objects'))).length;report.success=report.readFailures.length===0;report.stage=report.success?'complete':'read-failures';
}catch(error){report.failure=error.message;report.stage='failed';}
finally{clearInterval(timer);clearTimeout(deadline);content.close();report.finishedAt=new Date().toISOString();await save();console.log(JSON.stringify({success:report.success??false,stage:report.stage,failure:report.failure,downloadedMiB:Number((report.downloads.bytes/1048576).toFixed(1)),objects:completedObjects.size,reads:report.reads.length,readFailures:report.readFailures.length,cache:directory}));if(!report.success)process.exitCode=1;}
