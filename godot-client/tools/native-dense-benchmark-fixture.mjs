// Offline protocol-layout fixture only. No renderer/model preparation, resolver,
// Session/Host, socket, process, authentication or original-resource mutation.
import fs from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const sha=b=>createHash('sha256').update(b).digest('hex');
const check=(v,message)=>{if(!v)throw Error(message);};
const copy=v=>structuredClone(v), INVALID=0x7f000000;
const MAX_TIMELINE=256*1024*1024,MAX_FRAME=1024*1024+4096;
const external=id=>Number.isInteger(id)&&id>=0x80000000&&id<=0xffffffff;
const keys=(o,allowed,label)=>check(Object.keys(o).every(k=>allowed.includes(k)),label+' contains unsupported fields');
const vector=v=>Array.isArray(v)&&v.length===3&&v.every(Number.isFinite);
function reserveLinks(value,ids){
 if(!value||typeof value!=='object')return;
 for(const [key,v]of Object.entries(value)){
  if(/^(?:id|objectId|ownerId|targetId|actorId|areaId|controlledId|familiarId|companionId|equipmentOwnerId|master|facingTarget)$/.test(key)&&external(v))ids.add(v);
  if(v&&typeof v==='object')reserveLinks(v,ids);
 }
}
async function hashFile(filename,maxBytes){
 const stat=await fs.stat(filename);check(stat.isFile()&&stat.size<=maxBytes,'Input file exceeds bound');
 const digest=createHash('sha256');for await(const bytes of createReadStream(filename))digest.update(bytes);
 return{bytes:stat.size,sha256:digest.digest('hex')};
}
function privatePath(root,relative){
 check(typeof relative==='string'&&relative!==''&&!path.isAbsolute(relative),'Relative catalog path required');
 const out=path.resolve(root,relative);check(out.startsWith(path.resolve(root)+path.sep),'Catalog path escapes recording');return out;
}

/** Verify a sealed packed recording, retaining only generation1 source data.
 * This composes recorded full/delta transport rows; it never simulates a World.
 */
export async function inspectDenseBenchmarkSource(directory){
 const root=path.resolve(directory),recordingBytes=await fs.readFile(path.join(root,'recording.json'));
 check(recordingBytes.length<=1024*1024,'Recording manifest exceeds bound');
 const recording=JSON.parse(recordingBytes);
 check(recording.version===1&&recording.complete===true&&Array.isArray(recording.catalogs)&&recording.catalogs.length===1,'One complete sealed catalog required');
 const catalogRow=recording.catalogs[0];check(/^catalog-[0-9]+$/.test(catalogRow.directory),'Catalog directory is unsupported');
 const catalogRoot=privatePath(root,catalogRow.directory),manifestBytes=await fs.readFile(path.join(catalogRoot,'manifest.json'));
 check(manifestBytes.length<=32*1024*1024&&sha(manifestBytes)===catalogRow.sha256,'Catalog manifest checksum/bound differs');
 const catalog=JSON.parse(manifestBytes),packed=catalog.packedSource;
 check(catalog.version===2&&catalog.complete===true&&packed?.version===1&&catalog.availability&&catalog.resources,'Exact packed catalog required');
 const archivePath=privatePath(catalogRoot,packed.file),archive=await hashFile(archivePath,512*1024*1024);
 check(archive.bytes===packed.bytes&&archive.sha256===packed.sha256,'Packed captured-resource bytes differ');
 const talks=[];
 for(const [key,row]of Object.entries(catalog.talk??{})){
  check(/^[a-f0-9]{64}$/.test(row.sha256)&&Number.isSafeInteger(row.bytes),'Invalid captured talk metadata');
  const filename=privatePath(catalogRoot,'objects/'+row.sha256);let proof;
  try{proof=await hashFile(filename,64*1024*1024);}catch(error){throw Error('Captured talk bytes unavailable: '+key+': '+error.message);}
  check(proof.bytes===row.bytes&&proof.sha256===row.sha256,'Captured talk checksum differs');talks.push({key,file:'objects/'+row.sha256,...proof});
 }
 const timelinePath=path.join(root,'timeline.jsonl'),timelineStat=await fs.stat(timelinePath);
 check(timelineStat.size<=MAX_TIMELINE,'Timeline exceeds256MiB');
 const digest=createHash('sha256'),stream=createReadStream(timelinePath);stream.on('data',b=>digest.update(b));
 const lines=readline.createInterface({input:stream,crlfDelay:Infinity});
 let sequence=0,at=-1,count=0,setup=null,view=null,first=null,last=null,pending=null,lastSerial=-1,done=false;
 const registry=new Map(),allIds=new Set(),persistent=[];
 for await(const line of lines){
  if(!line.trim())continue;check(Buffer.byteLength(line)<=MAX_FRAME,'Recorded frame exceeds bound');
  const event=JSON.parse(line);check(Number.isSafeInteger(event.sequence)&&event.sequence>sequence&&Number.isFinite(event.at)&&event.at>=at,'Recorded ordering differs');
  sequence=event.sequence;at=event.at;count++;const v=event.value;
  if(event.kind==='view'&&!done)view=copy(v);
  if(event.kind!=='frame')continue;
  if(v.kind==='setup'&&!done)setup=copy(v);
  if(v.kind==='ui-protocol'&&!done&&['custom-token','tlk-overrides'].includes(v.message?.kind))persistent.push(copy(v));
  if(v.kind==='raw-world-chunk')for(const row of v.objects??[])if(external(row.id))allIds.add(row.id);
  if(v.kind==='raw-world-begin'){
   if(v.generation>1){done=true;pending=null;}
   if(!done&&v.generation===1){check(Number.isSafeInteger(v.count)&&v.count>=0&&v.count<=65536,'Captured object count invalid');pending={header:copy(v),objects:[],sequence:event.sequence};}
  }else if(v.kind==='raw-world-chunk'&&pending){
   check(v.serial===pending.header.serial&&v.generation===1&&Array.isArray(v.objects)&&v.objects.length<=64,'Captured chunk scope differs');pending.objects.push(...copy(v.objects));
   check(pending.objects.length<=pending.header.count,'Captured chunk overflow');
  }else if(v.kind==='raw-world-end'&&pending){
   check(v.serial===pending.header.serial&&v.generation===1&&pending.objects.length===pending.header.count,'Captured full/delta count differs');
   if(pending.header.data.bridgeMode==='full')registry.clear();
   else check(pending.header.data.bridgeMode==='delta'&&pending.header.data.bridgeBaseSerial===lastSerial,'Captured delta has no exact base');
   for(const id of pending.header.data.removedObjectIds??[])registry.delete(id);
   for(const row of pending.objects)registry.set(row.id,row);
   first??=copy(pending);last=copy(pending.header);lastSerial=last.serial;pending=null;
  }
 }
 check(count===recording.events&&digest.digest('hex')===recording.timelineSha256,'Timeline seal/event count differs');
 check(setup&&first&&last&&first.header.data.bridgeMode==='full'&&setup.connection===last.connection,'Captured generation1 setup/full source unavailable');
 const area=first.header.data.area,controlled=registry.get(last.data.controlledId);
 check(external(area?.id)&&Number.isInteger(area.width)&&Number.isInteger(area.height)&&area.width>0&&area.height>0&&area.tiles?.length===area.width*area.height,'Captured tile rectangle unavailable');
 check(controlled?.objectType===5&&controlled.areaId===area.id&&!controlled.replicationRemoved&&vector(controlled.replicated?.position),'Completed generation1 controlled creature unavailable');
 check(last.data.area.id===area.id,'Captured area identity changed inside generation1');
 const cohort=first.objects.filter(row=>row.areaId===area.id&&[9,12,16].includes(row.objectType));
 const cohortIds=new Set();
 for(const row of cohort){
  check(external(row.id)&&!cohortIds.has(row.id),'Invalid/duplicate captured static ID');cohortIds.add(row.id);
  check(JSON.stringify(row.staticState)===JSON.stringify(registry.get(row.id)?.staticState)&&JSON.stringify(row.lightState)===JSON.stringify(registry.get(row.id)?.lightState),'Captured static/light geometry changed before completed source');
 }
 for(const [field,embedded,type]of [['staticPlaceables','staticState',9],['placeableLights','lightState',9],['mapPins','mapPin',12],['sounds','state',16]]){
  check(Array.isArray(area[field]),'Captured area list unavailable: '+field);
  for(const item of area[field]){const row=cohort.find(r=>r.id===item.id&&r.objectType===type);check(row&&JSON.stringify(row[embedded])===JSON.stringify(item),'Area/object list differs: '+field);}
 }
 for(const id of [controlled.companionId,controlled.familiarId,controlled.replicated.master,controlled.replicated.facingTarget])
  check(id===undefined||id===null||id===INVALID||id===controlled.id,'Single-PC fixture would drop a controlled creature link');
 check(Array.isArray(controlled.replicated.path)&&controlled.replicated.path.length===0,'Single-PC fixture requires captured stationary path');
 reserveLinks(last.data,allIds);reserveLinks(controlled,allIds);
 const knownErrors=Object.entries(catalog.resources).filter(([,r])=>r.error).map(([resource,r])=>({resource,error:r.error}));
 return {version:1,kind:'sealed-native-dense-source',directory:root,catalogDirectory:catalogRow.directory,catalogRoot,recording,
  seals:{recordingSha256:sha(recordingBytes),timelineSha256:recording.timelineSha256,timelineBytes:timelineStat.size,catalogSha256:sha(manifestBytes),archive,talks},
  first:{header:first.header,sequence:first.sequence},completed:{header:last,controlled:copy(controlled)},cohort:copy(cohort),setup,view,persistent,
  sourceIds:[...allIds],resourceCoverage:{namespaceEntries:Object.keys(catalog.availability).length,recordedResources:Object.keys(catalog.resources).length,knownErrors,unrecordedOrFailed:packed.unrecordedOrFailed,nativeActiveClosureValidated:false}};
}

function translated(record,mapping,offset){
 keys(record,['id','objectType','areaId','staticState','lightState','mapPin','state','nativeLifetime','nativeSoundHeight'],'Captured clone row');
 check([9,12,16].includes(record.objectType)&&mapping.has(record.id),'Unsupported clone row');
 const result=copy(record);result.id=mapping.get(record.id);
 const fields=record.objectType===9?['staticState','lightState']:record.objectType===12?['mapPin']:['state'];
 for(const field of fields)if(result[field]){
  check(result[field].id===record.id&&vector(result[field].position),'Embedded clone ID/position differs');
  result[field].id=result.id;result[field].position=result[field].position.map((n,i)=>n+offset[i]);
 }
 return result;
}

/** Build detached raw protocol layout, not meshes, lights, model plans or state. */
export function buildDenseBenchmarkFixture(source,{copiesX=2,copiesY=2,particles=true,particleCollision=true}={}){
 check(source?.kind==='sealed-native-dense-source'&&source.version===1,'Inspected sealed source required');
 check([1,2].includes(copiesX)&&[1,2].includes(copiesY)&&typeof particles==='boolean'&&typeof particleCollision==='boolean','Only bounded1x1 through2x2 layouts/Boolean flags supported');
 const data=copy(source.completed.header.data),originalArea=source.first.header.data.area,area=copy(originalArea);
 const used=new Set(source.sourceIds);used.add(area.id);used.add(data.controlledId);
 const rows=[],maps=[],offsets=[];let next=0x90000000;
 const ids=new Set(source.cohort.map(r=>r.id));check(ids.size===source.cohort.length,'Duplicate source cohort IDs');
 for(let cy=0;cy<copiesY;cy++)for(let cx=0;cx<copiesX;cx++){
  const mapping=new Map(),offset=[cx*originalArea.width*10,cy*originalArea.height*10,0];offsets.push(offset);
  for(const row of source.cohort){
   if(cx===0&&cy===0)mapping.set(row.id,row.id);
   else{while(used.has(next))next++;check(external(next),'Synthetic object ID namespace exhausted');mapping.set(row.id,next);used.add(next++);}
  }
  maps.push(mapping);for(const row of source.cohort)rows.push(translated(row,mapping,offset));
 }
 check(!ids.has(data.controlledId),'Controlled source collides with clone cohort');
 rows.push(copy(source.completed.controlled));
 area.width=originalArea.width*copiesX;area.height=originalArea.height*copiesY;area.tiles=[];
 for(let y=0;y<area.height;y++)for(let x=0;x<area.width;x++)area.tiles.push(copy(originalArea.tiles[(y%originalArea.height)*originalArea.width+x%originalArea.width]));
 for(const [field,embedded,type]of [['staticPlaceables','staticState',9],['placeableLights','lightState',9],['mapPins','mapPin',12],['sounds','state',16]]){
  area[field]=[];
  for(let c=0;c<maps.length;c++)for(const value of originalArea[field]){
   const raw=source.cohort.find(r=>r.id===value.id&&r.objectType===type);
   check(raw,'Area list has no raw clone source: '+field);area[field].push(translated(raw,maps[c],offsets[c])[embedded]);
  }
 }
 // Player-owned/global UI and inventory remain captured source data, not cloned
 // NPC/party entities. Empty custom map pins have no ambiguous area translation.
 check(Array.isArray(area.playerMapPins)&&area.playerMapPins.length===0,'Player map pins need an explicit translation policy');
 data.area=area;data.bridgeMode='full';data.bridgeBaseSerial=-1;data.removedObjectIds=[];
 const connection=source.completed.header.connection,generation=1,serial=1;
 const setup=copy(source.setup);setup.serverLabel=`OFFLINE SYNTHETIC DENSE ${copiesX}x${copiesY}`;
 const records=[];const emit=(kind,value)=>records.push({sequence:records.length+1,at:0,kind,value});
 emit('frame',{kind:'session-reset',connection});emit('frame',setup);emit('acknowledgement',{kind:'catalog-ready',connection});
 for(const value of source.persistent)emit('frame',{...copy(value),connection,generation});
 const view=copy(source.view??{connection});view.connection=connection;view.particles=particles;view.particle_collision=particleCollision;emit('view',view);
 emit('frame',{kind:'raw-world-begin',connection,generation,serial,count:rows.length,data});
 for(let start=0;start<rows.length;start+=64)emit('frame',{kind:'raw-world-chunk',connection,generation,serial,objects:rows.slice(start,start+64)});
 emit('frame',{kind:'raw-world-end',connection,generation,serial});emit('acknowledgement',{kind:'raw-world-accepted',connection,generation,serial});emit('acknowledgement',{kind:'area-ready',connection,generation});
 check(new Set(rows.map(r=>r.id)).size===rows.length&&rows.every(r=>r.areaId===area.id&&external(r.id)),'Synthetic world ID/area consistency failed');
 const timeline=records.map(r=>{const line=JSON.stringify(r);check(Buffer.byteLength(line)<=MAX_FRAME,'Synthetic frame exceeds recorded transport bound');return line+'\n';}).join('');
 const summary={version:1,kind:'synthetic-native-dense-layout',copiesX,copiesY,copies:maps.length,areaId:area.id,width:area.width,height:area.height,tiles:area.tiles.length,objects:rows.length,controlledCreatures:1,controlledId:data.controlledId,
  staticModels:rows.filter(r=>r.staticState).length,lightOnly:rows.filter(r=>r.lightState&&!r.staticState).length,sounds:area.sounds.length,mapPins:area.mapPins.length,placeableLights:area.placeableLights.length,
  offsets,sourceGeneration:1,sourceCompletedSerial:source.completed.header.serial,sourceTimelineSha256:source.seals.timelineSha256,sourceCatalogSha256:source.seals.catalogSha256,
  sourceResourceCoverage:copy(source.resourceCoverage),particlesEnabled:particles,collisionEnabled:particleCollision,renderingPrepared:false,nativeValidated:false,
  scope:'Synthetic adjacent tiled copies of captured immutable Hubint static/light/sound/pin records plus one captured stationary controlled creature. Exact captured resources; no claim of exact live area or4x visible density. Missing/capture-gap resources remain explicit, never manufactured.'};
 const recording={version:1,complete:true,failure:null,events:records.length,bytes:Buffer.byteLength(timeline),timelineSha256:sha(timeline),catalogs:copy(source.recording.catalogs),metadata:{synthetic:true},policy:'Offline synthetic raw protocol layout; container seal completeness is not asset/render completion.',benchmarkClone:summary};
 return {recording,records,timeline,summary};
}

/** File-only materialization. Copies exact catalog bytes into a fresh directory. */
export async function writeDenseBenchmarkFixture(source,fixture,destination){
 const output=path.resolve(destination);check(output!==source.directory&&!output.startsWith(source.directory+path.sep),'Output must be separate from source recording');
 await fs.mkdir(output,{recursive:false});
 const target=path.join(output,source.catalogDirectory);await fs.mkdir(target);
 for(const relative of ['manifest.json',source.recording.catalogs[0]&&JSON.parse(await fs.readFile(path.join(source.catalogRoot,'manifest.json'),'utf8')).packedSource.file,...source.seals.talks.map(t=>t.file)]){
  check(typeof relative==='string','Catalog file unavailable');const input=privatePath(source.catalogRoot,relative),out=privatePath(target,relative);await fs.mkdir(path.dirname(out),{recursive:true});await fs.copyFile(input,out,fs.constants.COPYFILE_EXCL);
 }
 const manifest=await fs.readFile(path.join(target,'manifest.json'));check(sha(manifest)===source.seals.catalogSha256,'Copied catalog manifest differs');
 const packed=JSON.parse(manifest).packedSource,archive=await hashFile(privatePath(target,packed.file),512*1024*1024);
 check(archive.sha256===source.seals.archive.sha256&&archive.bytes===source.seals.archive.bytes,'Copied packed resource differs');
 for(const talk of source.seals.talks){const proof=await hashFile(privatePath(target,talk.file),64*1024*1024);check(proof.sha256===talk.sha256&&proof.bytes===talk.bytes,'Copied talk differs');}
 await fs.writeFile(path.join(output,'timeline.jsonl'),fixture.timeline,{flag:'wx'});await fs.writeFile(path.join(output,'recording.json'),JSON.stringify(fixture.recording,null,2)+'\n',{flag:'wx'});
 const sourceRecording=await fs.readFile(path.join(source.directory,'recording.json')),sourceManifest=await fs.readFile(path.join(source.catalogRoot,'manifest.json'));
 check(sha(sourceRecording)===source.seals.recordingSha256&&sha(sourceManifest)===source.seals.catalogSha256,'Source metadata changed while materializing');
 const sourceTimeline=await hashFile(path.join(source.directory,'timeline.jsonl'),MAX_TIMELINE),sourceArchive=await hashFile(privatePath(source.catalogRoot,packed.file),512*1024*1024);
 check(sourceTimeline.sha256===source.seals.timelineSha256&&sourceArchive.sha256===source.seals.archive.sha256,'Source timeline/archive changed while materializing');
 return {directory:output,timelineSha256:fixture.recording.timelineSha256,catalogSha256:source.seals.catalogSha256,originalMetadataUnchanged:true,nativeValidated:false};
}

if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const arg=name=>process.argv.find(x=>x.startsWith('--'+name+'='))?.slice(name.length+3);
 check(arg('source'),'Explicit --source sealed recording required');
 const source=await inspectDenseBenchmarkSource(arg('source')),fixture=buildDenseBenchmarkFixture(source);
 const output=arg('output');console.log(JSON.stringify(output?{...await writeDenseBenchmarkFixture(source,fixture,output),summary:fixture.summary}:fixture.summary));
}
