// Bounded historical NPC/model evidence plus original local asset inspection.
// Original install/profile/NWSync databases are read-only; no network or engine.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parseKey} from '../../../../src/resource_archive.js';
import {parseNWSyncManifest} from '../../../../src/nwsync_manifest.js';
import {parse2da} from '../../../../src/area.js';
import {NWSyncReader} from '../../../../electron/nwsync_reader.mjs';
import {decodeNWSyncBlob} from '../../../../electron/nwsync_content.mjs';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),workspace=path.dirname(source),label=process.argv[2];
if(!/^claddath-ghost-assets-[a-z0-9-]+$/.test(label??''))throw Error('Fresh bounded Claddath evidence label required');
const folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label);await fs.mkdir(folder,{recursive:false});
const sha=raw=>crypto.createHash('sha256').update(raw).digest('hex'),sha1=raw=>crypto.createHash('sha1').update(raw).digest('hex');
const reportFile=path.join(source,'reports/native-manual-1793848496660.native.json'),reportRaw=await fs.readFile(reportFile),report=JSON.parse(reportRaw);
const ids=[2147620731,2147620741],actors=report.protocol_objects.filter(row=>ids.includes(row.id));
const batches=report.world.batches.map((row,index)=>({...row,index})).filter(row=>row.publications?.some(pub=>ids.includes(pub.id)));
if(actors.length!==2||actors.some(row=>row.name!=='Claddath Fleshwarp Monstrosity')||batches.length!==1||batches[0].jobs.length!==1||batches[0].jobs[0].model!=='c_goldem'||batches[0].publications.length!==2||batches[0].publications.some(pub=>!ids.includes(pub.id)||pub.meshes!==29||pub.success!==true))throw Error('Exact historical model-to-NPC batch differs');
const install=path.resolve(workspace,'../FullDecomp/NwnRootInstall'),profile='C:/Users/Niflheim/Documents/Neverwinter Nights.0',keyPins=[],resources=new Map();
for(const relative of ['lang/en/data/nwn_base_loc.key','data/nwn_retail.key','data/nwn_base.key']){
 const file=path.join(install,relative);let raw;try{raw=await fs.readFile(file);}catch(error){if(error.code==='ENOENT')continue;throw error;}
 keyPins.push({file,sha256:sha(raw)});const key=parseKey(raw);
 for(const [id,row]of key.resources)if(!resources.has(id))resources.set(id,{...row,bif:key.bifNames[row.bifIndex],keyFile:file});
}
const row=resources.get('c_goldem:2002');if(!row)throw Error('Original model absent');
const file=await fs.open(path.join(install,row.bif),'r');let model;
try{
 const header=Buffer.alloc(20);await file.read(header,0,20,0);const v11=header.toString('ascii',4,8)==='V1.1',stride=v11?20:16,offset=v11?8:4,entry=Buffer.alloc(stride);
 await file.read(entry,0,stride,header.readUInt32LE(16)+row.resourceIndex*stride);const size=entry.readUInt32LE(offset+4);
 if(size!==517418||entry.readUInt32LE(offset+8)!==2002)throw Error('Historical model byte size/type does not match current original archive');
 const raw=Buffer.alloc(size);if((await file.read(raw,0,size,entry.readUInt32LE(offset))).bytesRead!==size)throw Error('Short original model read');
 const copy=path.join(folder,'c_goldem.mdl');await fs.writeFile(copy,raw,{flag:'wx'});model={resref:'c_goldem',bytes:size,sha256:sha(raw),source:path.join(install,row.bif),keyFile:row.keyFile,resourceIndex:row.resourceIndex,copy};
}finally{await file.close();}
const loose=[];
for(const directory of [path.join(profile,'override'),path.join(install,'override'),path.join(install,'ovr')]){
 let names;try{names=await fs.readdir(directory);}catch(error){if(error.code==='ENOENT')continue;throw error;}
 for(const name of names.filter(name=>name.toLowerCase()==='c_goldem.mdl')){const file=path.join(directory,name),raw=await fs.readFile(file);loose.push({file,bytes:raw.length,sha256:sha(raw)});}
}
const cache=path.join(profile,'replacement-client/server-content'),manifestNames=(await fs.readdir(path.join(cache,'manifests'))).filter(name=>/^[a-f0-9]{40}$/.test(name));
if(manifestNames.length>8)throw Error('Unexpected broad manifest inventory');
const manifests=[],tables=new Map();let reader;
try{
 for(const name of manifestNames){
  const file=path.join(cache,'manifests',name),raw=await fs.readFile(file);if(raw.length>8*1024*1024||sha1(raw)!==name)throw Error('Cached manifest differs');
  const manifest=parseNWSyncManifest(raw),entry=manifest.catalog.get('appearance:2017');
  manifests.push({file,sha256:sha(raw),hash:name,appearance:entry,modelOverride:manifest.catalog.get('c_goldem:2002')??null});
  if(!entry||tables.has(entry.hash))continue;
  if(entry.size>4*1024*1024)throw Error('Appearance table exceeds bound');
  reader??=new NWSyncReader(path.join(profile,'nwsync'));
  let encoded=await reader.blob(entry.hash);if(!encoded){tables.set(entry.hash,{available:false,hash:entry.hash});continue;}
  const decoded=encoded.toString('ascii',0,4)==='NSYC'?await decodeNWSyncBlob(encoded,{decompressZstd:(raw,size)=>reader.decompress(raw,size),maxBytes:4*1024*1024}):encoded;
  if(decoded.length!==entry.size||sha1(decoded)!==entry.hash)throw Error('Read-only appearance identity differs');
  const table=parse2da(decoded.toString('latin1')),matches=table.orderedRows.map((row,index)=>({index,row})).filter(({row})=>String(row.RACE??'').toLowerCase()==='c_goldem');
  const copy=path.join(folder,'appearance-'+entry.hash+'.2da');await fs.writeFile(copy,decoded,{flag:'wx'});tables.set(entry.hash,{available:true,hash:entry.hash,sha256:sha(decoded),bytes:decoded.length,rows:table.orderedRows.length,matches,copy});
 }
}finally{reader?.close();}
const evidence={version:1,scope:'Historical named NPC single-model batch/resref and original stock archive byte-size match; candidate cached appearance catalogs inspected read-only. Exact screenshot room/camera, physical received appearanceID and historical texture hashes are not retained and are not invented.',source:{file:reportFile,sha256:sha(reportRaw),areaId:report.world.area_id,generation:report.world.generation},actors,batch:{index:batches[0].index,publications:batches[0].publications,jobs:batches[0].jobs.map(job=>({model:job.model,error:job.error,sourceBytes:job.phases.resource_io.payload_bytes}))},model,keyPins,looseOverrides:loose,manifests,appearanceTables:[...tables.values()],missing:['exact user screenshot room/camera correspondence','physical received appearanceID (protocol_objects omits fixed appearance)','historical per-texture source hashes'],networkConnections:0,engineLaunches:0,nativeBuilds:0,originalWrites:0};
for(const pin of keyPins)if(sha(await fs.readFile(pin.file))!==pin.sha256)throw Error('Original KEY changed');
const output=path.join(folder,'evidence.json');await fs.writeFile(output,JSON.stringify(evidence,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,sha256:sha(await fs.readFile(output)),model,looseOverrides:loose,appearanceTables:evidence.appearanceTables.map(table=>({...table,matches:table.matches?.map(match=>({index:match.index,label:match.row.LABEL,race:match.row.RACE,modelType:match.row.MODELTYPE}))})),networkConnections:0,originalWrites:0}));
