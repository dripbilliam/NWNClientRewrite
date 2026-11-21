// Build an offline benchmark corpus from a sealed loading recording. Exact
// captured bytes become real ERF payloads; no prepared geometry or networking.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const validHash=value=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const check=(ok,message)=>{if(!ok)throw Error(message);};
const cp1252High=[0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178];
const cp1252=new Map(Array.from({length:256},(_,index)=>[String.fromCodePoint(index>=128&&index<160?cp1252High[index-128]:index),index]));
function reference(key){
 const match=/^([^:\/\\\x00-\x1f]{1,32}):(\d+)$/.exec(key);
 check(match&&Number(match[2])<=65535&&Number(match[2])>=0,'Invalid captured resource reference');
 check([...match[1]].every(value=>cp1252.has(value)),'Resource reference is not a CP1252 byte string');
 const name=Buffer.from([...match[1]].map(value=>cp1252.get(value)));
 return{name,type:Number(match[2])};
}
async function payload(root,row){
 check(validHash(row.sha256)&&Number.isSafeInteger(row.bytes)&&row.bytes>=0&&row.bytes<=256*1024*1024,'Invalid captured payload descriptor');
 const bytes=await fs.readFile(path.join(root,'objects',row.sha256));
 check(bytes.length===row.bytes&&sha(bytes)===row.sha256,'Captured payload checksum/length differs');
 return bytes;
}
export async function packCatalog(source,destination){
 const raw=await fs.readFile(path.join(source,'manifest.json')),manifest=JSON.parse(raw);
 check(manifest.version===2&&manifest.complete===true&&manifest.availability&&manifest.resources&&!manifest.packedSource,'Only original sealed catalogs can be cloned');
 const names=Object.keys(manifest.availability).sort();
 check(names.length>0&&names.length<=1000000,'Captured namespace exceeds archive bound');
 await fs.mkdir(destination,{recursive:false});
 const header=Buffer.alloc(160),keys=Buffer.alloc(names.length*40),locations=Buffer.alloc(names.length*8);
 header.write('ERF V1.1',0,'ascii');header.writeUInt32LE(names.length,16);header.writeUInt32LE(160,24);header.writeUInt32LE(160+keys.length,28);
 const filename=path.join(destination,'resources.erf'),out=await fs.open(filename,'wx');
 const hash=createHash('sha256'),ranges=new Map();let offset=160+keys.length+locations.length,payloads=0,gaps=0;
 try{
  for(let index=0;index<names.length;index++){
   const key=names[index],ref=reference(key),row=manifest.resources[key];
   check([1,2,3,5].includes(manifest.availability[key]),'Unknown recorded storage class');
   ref.name.copy(keys,index*40);keys.writeUInt32LE(index,index*40+32);keys.writeUInt16LE(ref.type,index*40+36);
   let range={offset,size:0};
   if(row&&!row.error){
    range=ranges.get(row.sha256);
    if(!range){const bytes=await payload(source,row);range={offset,size:bytes.length};check(offset+bytes.length<=0xffffffff,'Clone archive exceeds ERF address range');await out.write(bytes,0,bytes.length,offset);offset+=bytes.length;ranges.set(row.sha256,range);payloads++;}
   }else gaps++;
   locations.writeUInt32LE(range.offset,index*8);locations.writeUInt32LE(range.size,index*8+4);
  }
  await out.write(header,0,header.length,0);await out.write(keys,0,keys.length,header.length);await out.write(locations,0,locations.length,header.length+keys.length);await out.truncate(offset);await out.sync();
 }finally{await out.close();}
 // TLKs use the recorded direct-file interface and are copied independently.
 await fs.mkdir(path.join(destination,'objects'));
 for(const row of Object.values(manifest.talk??{})){const bytes=await payload(source,row);await fs.writeFile(path.join(destination,'objects',row.sha256),bytes);}
 const input=await fs.open(filename,'r');try{const buffer=Buffer.alloc(1024*1024);let at=0;while(at<offset){const {bytesRead}=await input.read(buffer,0,Math.min(buffer.length,offset-at),at);check(bytesRead>0,'Clone archive was truncated');hash.update(buffer.subarray(0,bytesRead));at+=bytesRead;}}finally{await input.close();}
 const digest=hash.digest('hex');
 const clone={...manifest,packedSource:{version:1,file:'resources.erf',bytes:offset,sha256:digest,namespaceEntries:names.length,uniquePayloads:payloads,unrecordedOrFailed:gaps,sourceManifestSha256:sha(raw),scope:'Synthetic ERF storage for exact captured resources and full presence metadata; absent captures remain explicit failures, not zero-byte assets. Original archive layout, network and content downloads are not reproduced.'}};
 const bytes=Buffer.from(JSON.stringify(clone));await fs.writeFile(path.join(destination,'manifest.json'),bytes,{flag:'wx'});
 return{sha256:sha(bytes),archiveSha256:digest,bytes:offset,namespaceEntries:names.length,uniquePayloads:payloads,gaps};
}
export async function cloneRecording(source,destination){
 source=path.resolve(source);destination=path.resolve(destination);
 check(source!==destination&&!destination.startsWith(source+path.sep),'Clone must be separate from original recording');
 const raw=await fs.readFile(path.join(source,'recording.json')),recording=JSON.parse(raw),timeline=await fs.readFile(path.join(source,'timeline.jsonl'));
 check(recording.version===1&&recording.complete===true&&Array.isArray(recording.catalogs)&&recording.catalogs.length<=1024,'Recording is incomplete');
 check(timeline.length<=256*1024*1024&&sha(timeline)===recording.timelineSha256,'Recording timeline checksum/bound differs');
 await fs.mkdir(destination,{recursive:false});const catalogs=[],proof=[];const seen=new Set();
 for(const row of recording.catalogs){
  check(/^catalog-[0-9]+$/.test(row.directory)&&!seen.has(row.directory),'Invalid/duplicate catalog directory');seen.add(row.directory);
  const rawCatalog=await fs.readFile(path.join(source,row.directory,'manifest.json'));check(sha(rawCatalog)===row.sha256,'Original catalog seal differs');
  const packed=await packCatalog(path.join(source,row.directory),path.join(destination,row.directory));catalogs.push({...row,sha256:packed.sha256});proof.push({directory:row.directory,...packed});
  check(sha(await fs.readFile(path.join(source,row.directory,'manifest.json')))===row.sha256,'Original catalog changed during cloning');
 }
 await fs.writeFile(path.join(destination,'timeline.jsonl'),timeline,{flag:'wx'});
 const clone={...recording,catalogs,benchmarkClone:{version:1,sourceRecordingSha256:sha(raw),sourceTimelineSha256:sha(timeline),catalogs:proof,artificialDelay:false,networkConnections:0,scope:'Same presentation timeline/exact captured assets in synthetic native-readable resource archives; an indexing/IO/preparation workload, not original storage-layout or native-executable parity.'}};
 check(sha(await fs.readFile(path.join(source,'recording.json')))===sha(raw)&&sha(await fs.readFile(path.join(source,'timeline.jsonl')))===recording.timelineSha256,'Original recording changed during cloning');
 await fs.writeFile(path.join(destination,'recording.json'),JSON.stringify(clone,null,2)+'\n',{flag:'wx'});
 return{complete:true,destination,timelineSha256:recording.timelineSha256,catalogs:proof,originalUnchanged:true,networkConnections:0};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const arg=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
 check(arg('capture')&&arg('output'),'Explicit --capture and new --output directories required');
 console.log(JSON.stringify(await cloneRecording(arg('capture'),arg('output'))));
}
