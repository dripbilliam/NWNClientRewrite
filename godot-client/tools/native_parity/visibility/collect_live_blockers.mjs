// Bounded recovery of the actual reported helper cohort. Read-only existing
// NSYM/raw cache; no server, database scan, model preparation or source edits.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {parse2da} from '../../../../src/area.js';
import {decodeResourceText} from '../../../../src/resource_archive.js';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];
if(!/^blockers-live-[a-z0-9-]+$/.test(label??''))throw Error('Fresh explicit blocker fixture label required');
const folder=path.join(project,'.cache/native-presentation-parity/root',label);
if(fs.existsSync(folder))throw Error('Existing evidence preserved');
const digest=(raw,algorithm='sha256')=>crypto.createHash(algorithm).update(raw).digest('hex');
const reportFile=path.join(project,'reports/parity-seven-fixes-manual-v2.native.json'),reportBytes=fs.readFileSync(reportFile),report=JSON.parse(reportBytes);
const ids=new Set([5680,5681,5682,5684,5685]);
const observed=report.protocol_objects.filter(o=>o.type===9&&o.replicated?.animation===74&&ids.has(o.replicated.appearance));
if(observed.length!==62)throw Error('Reported original helper cohort changed');
const manifestId='abdeeb5e2727868a06e8990ea57bd3b2150b212b';
const manifestFile=path.join(process.env.USERPROFILE,'Documents/Neverwinter Nights.0/replacement-client/server-content/manifests',manifestId),manifest=fs.readFileSync(manifestFile);
if(manifest.length>16*1024*1024||manifest.toString('ascii',0,4)!=='NSYM'||manifest.readUInt32LE(4)!==3||digest(manifest,'sha1')!==manifestId)throw Error('Retained manifest identity differs');
const count=manifest.readUInt32LE(8),mapping=manifest.readUInt32LE(12);
if(16+count*42+mapping*22!==manifest.length)throw Error('Malformed retained manifest');
const resources=new Map();
for(let at=0;at<count;at++){
 const offset=16+at*42,name=manifest.toString('ascii',offset+24,offset+40).split('\0')[0].toLowerCase(),type=manifest.readUInt16LE(offset+40);
 resources.set(name+':'+type,{name,type,sha1:manifest.subarray(offset,offset+20).toString('hex'),bytes:manifest.readUInt32LE(offset+20)});
}
const cache=path.join(process.env.APPDATA,'Godot/app_userdata/NWN Native Engine Prototype/native-original-bytes-v1');
function read(name,type,required=true){
 const record=resources.get(name.toLowerCase()+':'+type);
 if(!record){if(required)throw Error('Resource absent from retained manifest: '+name+':'+type);return null;}
 if(record.bytes>8*1024*1024)throw Error('Narrow resource bound exceeded');
 const source=path.join(cache,record.sha1+'.raw'),raw=fs.readFileSync(source);
 if(raw.length!==record.bytes||digest(raw,'sha1')!==record.sha1)throw Error('Retained raw resource identity differs');
 return {...record,source,sha256:digest(raw),raw};
}
const table=read('placeables',2017),parsed=parse2da(decodeResourceText(table.raw));
const selected=[];const payloads=[table];
for(const id of ids){
 const row=parsed.orderedRows[id];if(!row||!row.ModelName||row.ModelName==='****')throw Error('Reported physical appearance row unavailable');
 const model=String(row.ModelName).toLowerCase(),mdl=read(model,2002),pwk=read(model,2053,false);
 payloads.push(mdl);if(pwk)payloads.push(pwk);
 selected.push({appearance:id,row,model,model_sha256:mdl.sha256,pwk_sha256:pwk?.sha256??null,observed:observed.filter(o=>o.replicated.appearance===id).map(o=>({id:o.id,name:o.name,animation:o.replicated.animation,position:o.replicated.position,orientation:o.replicated.orientation}))});
}
fs.mkdirSync(path.join(folder,'assets'),{recursive:true});const files=[];
for(const value of payloads){
 const extension={2017:'2da',2002:'mdl',2053:'pwk'}[value.type],file=path.join(folder,'assets',value.name+'.'+extension);
 fs.writeFileSync(file,value.raw,{flag:'wx'});const {raw,...metadata}=value;files.push({...metadata,file});
}
const loose=path.join(process.env.USERPROFILE,'Documents/Neverwinter Nights.0/override/placeables.2da');
const evidence={version:1,label,files,selected,observed_count:observed.length,manifest:{file:manifestFile,sha1:manifestId,sha256:digest(manifest)},report:{file:reportFile,sha256:digest(reportBytes)},profile_table_override_present:fs.existsSync(loose),source_writes:0,server_connections:0,scope:'Exact retained server-manifest resource cohort identified by received appearance rows; not a generic name/white-texture classifier or a full live provider precedence replay'};
const output=path.join(folder,'manifest.json');fs.writeFileSync(output,JSON.stringify(evidence,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,sha256:digest(fs.readFileSync(output)),models:selected.map(({appearance,model,model_sha256,pwk_sha256,observed})=>({appearance,model,model_sha256,pwk_sha256,count:observed.length})),looseOverride:evidence.profile_table_override_present}));
