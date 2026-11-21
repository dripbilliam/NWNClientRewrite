// Reuse a completed owned cold-download cache without changing any active
// resource mappings. Same-volume hard links publish whole immutable blobs
// atomically; existing targets and in-flight downloader writes are untouched.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {NWSyncContent} from '../electron/nwsync_content.mjs';
const [downloadFile,destination,output]=process.argv.slice(2);
if(!downloadFile||!destination||!output)throw Error('Expected completed download report, destination cache and output report');
const source=JSON.parse(await fs.readFile(downloadFile,'utf8'));
if(source.success!==true||!source.cache?.directory||!source.advertisement?.hash)throw Error('A completed cold download is required');
const from=path.resolve(source.cache.directory),to=path.resolve(destination),hash=source.advertisement.hash;
if(from.toLowerCase()===to.toLowerCase()||!/^[a-f0-9]{40}$/.test(hash))throw Error('Invalid cache seed request');
const bytes=await fs.readFile(path.join(from,'manifests',hash));
if(crypto.createHash('sha1').update(bytes).digest('hex')!==hash)throw Error('Source manifest integrity check failed');
const entries=[...new Map(parseNWSyncManifest(bytes).entries.map(e=>[e.hash,e])).values()];
const report={startedAt:new Date().toISOString(),source:from,destination:to,manifest:hash,total:entries.length,linked:0,alreadyPresent:0,compressedBytesLinked:0,sourceHeadersChecked:0,httpRequests:0};
await fs.mkdir(path.join(to,'objects'),{recursive:true});await fs.mkdir(path.join(to,'manifests'),{recursive:true});
let cursor=0,failed;
try{
 await Promise.all(Array.from({length:8},async()=>{while(!failed&&cursor<entries.length){const entry=entries[cursor++],filename=path.join(from,'objects',entry.hash);let file;try{
  file=await fs.open(filename,'r');const header=Buffer.alloc(16),read=await file.read(header,0,16,0),stat=await file.stat();
  if(read.bytesRead!==16||header.toString('ascii',0,4)!=='NSYC'||header.readUInt32LE(4)!==3||header.readUInt32LE(12)!==entry.size||![0,1,2].includes(header.readUInt32LE(8)))throw Error('Invalid source blob header: '+entry.hash);report.sourceHeadersChecked++;
  try{await fs.link(filename,path.join(to,'objects',entry.hash));report.linked++;report.compressedBytesLinked+=stat.size;}catch(error){if(error.code!=='EEXIST')throw error;report.alreadyPresent++;}
 }catch(error){failed=error;throw error;}finally{await file?.close();}}}));
 try{await fs.link(path.join(from,'manifests',hash),path.join(to,'manifests',hash));}catch(error){if(error.code!=='EEXIST')throw error;const existing=await fs.readFile(path.join(to,'manifests',hash));if(crypto.createHash('sha1').update(existing).digest('hex')!==hash)throw Error('Existing destination manifest failed verification');}
 // Reopen through the production owner with HTTP and installed-cache reads
 // forbidden. Admission checks headers; demanded bytes still receive the
 // normal decompression, SHA1 and size checks, rather than trusting filenames.
 const content=new NWSyncContent({directory:to,fetch:()=>{report.httpRequests++;throw Error('Seeded content must work offline');}});
 try{const view=await content.findManifest(hash);report.offlineAdmission=true;report.demanded=[];for(const name of ['classes','racialtypes','skills','spells','feat','baseitems']){const data=await view.getResource(name,2017);report.demanded.push({name,type:2017,bytes:data.byteLength});}}finally{content.close();}
 report.success=true;
}catch(error){report.failure=error.message;process.exitCode=1;}
finally{report.finishedAt=new Date().toISOString();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
