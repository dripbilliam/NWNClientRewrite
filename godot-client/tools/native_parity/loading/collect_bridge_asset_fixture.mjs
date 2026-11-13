// Exact two-resource recovery from the already verified local raw-byte cache.
// No database scan, download, server login, cache/source mutation or native tool.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^bridge-live-assets-[a-z0-9-]+$/.test(label??''))throw Error('Fresh bridge-live-assets label required');
const folder=path.join(project,'.cache/native-presentation-parity/loading-agent',label),directory=path.join(folder,'assets');if(fs.existsSync(folder))throw Error('Existing recovered fixture preserved');
const digest=(raw,algorithm='sha256')=>crypto.createHash(algorithm).update(raw).digest('hex');
const reportFile=path.join(project,'reports/parity-seven-fixes-manual-v2.native.json'),reportRaw=fs.readFileSync(reportFile),report=JSON.parse(reportRaw);
const modelNames=['twh_udbridge_mai','twh_udbridge_end'],live=new Map();for(const area of report.retired_areas??[])for(const row of area.pool?.template_preparation_peaks??[])if(modelNames.includes(row.model)){if(live.has(row.model)&&live.get(row.model)!==row.sha256)throw Error('Live resource identity changed within report');live.set(row.model,row.sha256);}
if(live.size!==2)throw Error('Both actual live resource identities are required');
const cache=path.join(process.env.USERPROFILE,'Documents/Neverwinter Nights.0/replacement-client/server-content'),manifestHash='abdeeb5e2727868a06e8990ea57bd3b2150b212b',manifestFile=path.join(cache,'manifests',manifestHash),manifestRaw=fs.readFileSync(manifestFile);
if(manifestRaw.length>16*1024*1024||manifestRaw.toString('ascii',0,4)!=='NSYM'||manifestRaw.readUInt32LE(4)!==3||digest(manifestRaw,'sha1')!==manifestHash)throw Error('Cached manifest proof differs');
const count=manifestRaw.readUInt32LE(8),mappings=manifestRaw.readUInt32LE(12);if(16+count*42+mappings*22!==manifestRaw.length)throw Error('Manifest length differs');
const rows=[];for(let at=0;at<count;at++){const offset=16+at*42,name=manifestRaw.toString('ascii',offset+24,offset+40).split('\0')[0].toLowerCase(),type=manifestRaw.readUInt16LE(offset+40);if(!modelNames.includes(name)||type!==2002)continue;
 const sha1=manifestRaw.subarray(offset,offset+20).toString('hex'),bytes=manifestRaw.readUInt32LE(offset+20);if(bytes>2*1024*1024)throw Error('Bridge source exceeds narrow bound');
 const file=path.join(process.env.APPDATA,'Godot/app_userdata/NWN Native Engine Prototype/native-original-bytes-v1',sha1+'.raw'),raw=fs.readFileSync(file),sha256=digest(raw);
 if(raw.length!==bytes||digest(raw,'sha1')!==sha1||sha256!==live.get(name))throw Error('Raw bridge identity differs from native manifest or actual live renderer');
 rows.push({name,type,source:file,bytes,sha1,sha256,raw});
}
if(rows.length!==2)throw Error('Both exact bridge resources are required');
fs.mkdirSync(directory,{recursive:true});const files=[];for(const row of rows){const file=path.join(directory,row.name+'.mdl');fs.writeFileSync(file,row.raw,{flag:'wx'});const {raw,...proof}=row;files.push({...proof,file});}
const proof={version:1,label,directory,files,manifest:{file:manifestFile,sha1:manifestHash,sha256:digest(manifestRaw)},liveReport:{file:reportFile,sha256:digest(reportRaw)},sourceWrites:0,serverConnections:0,nativeBuilds:0,scope:'Exactly two locally retained MDL byte blobs, matched independently to cached NWSync manifest SHA1/size and actual live renderer source SHA256; no assumption that the whole current server manifest/capture is reproduced.'};
const output=path.join(folder,'manifest.json');fs.writeFileSync(output,JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,output,sha256:digest(fs.readFileSync(output)),files:files.map(({name,bytes,sha1,sha256})=>({name,bytes,sha1,sha256}))}));
