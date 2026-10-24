import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash,randomUUID} from 'node:crypto';
import {inflate} from 'node:zlib';
import {promisify} from 'node:util';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {NWSyncReader} from './nwsync_reader.mjs';
const inflateAsync=promisify(inflate),MAX_RESOURCE=256*1024*1024,MAX_MANIFEST=64*1024*1024;
const digest=bytes=>createHash('sha1').update(bytes).digest('hex');
const validHash=hash=>typeof hash==='string'&&/^[0-9a-f]{40}$/.test(hash);
export async function decodeNWSyncBlob(input,{decompressZstd,maxBytes=MAX_RESOURCE}={}){
 const bytes=Buffer.from(input.buffer,input.byteOffset,input.byteLength);
 if(bytes.length<16||bytes.toString('ascii',0,4)!=='NSYC'||bytes.readUInt32LE(4)!==3)throw new Error('Invalid NWSync compressed buffer');
 const algorithm=bytes.readUInt32LE(8),size=bytes.readUInt32LE(12);if(size>maxBytes)throw new Error('NWSync resource exceeds the supported size');
 if(size===0)return Buffer.alloc(0);
 let result;
 if(algorithm===0)result=bytes.subarray(16);
 else if(algorithm===1){if(bytes.length<20||bytes.readUInt32LE(16)!==1)throw new Error('Unsupported NWSync zlib header');result=await inflateAsync(bytes.subarray(20),{maxOutputLength:Math.max(1,size)});}
 else if(algorithm===2){if(bytes.length<24||bytes.readUInt32LE(16)!==1||bytes.readUInt32LE(20)!==0)throw new Error('Unsupported NWSync Zstandard header or dictionary');if(!decompressZstd)throw new Error('NWSync Zstandard decompression is unavailable');result=await decompressZstd(bytes.subarray(24),size);}
 else throw new Error(`Unsupported NWSync compression algorithm ${algorithm}`);
 if(!result||result.length!==size)throw new Error('NWSync decompressed size does not match');return result;
}

// Only verified, content-addressed bytes enter the private cache. Original
// client databases are read-only. No server supplied names become file paths.
export class NWSyncContent{
 constructor({directory,nativeDirectory=null,fetch:fetchResource=globalThis.fetch,readerFactory=dir=>new NWSyncReader(dir),onDiagnostic=()=>{},onProgress=()=>{},concurrency=4}={}){
  if(!directory)throw new Error('NWSync cache directory is unavailable');if(!Number.isInteger(concurrency)||concurrency<1||concurrency>16)throw new Error('Invalid NWSync download concurrency');Object.assign(this,{directory,nativeDirectory,fetchResource,readerFactory,onDiagnostic,onProgress,concurrency});this.controller=new AbortController();this.manifests=new Map();this.pendingBlobs=new Map();this.ready=new Set();this.nativeBlobs=new Set();this.closed=false;this.downloadedBytes=0;
 }
 reader(){if(!this.nativeReader||this.nativeReader.closed)this.nativeReader=this.readerFactory(this.nativeDirectory??this.directory);return this.nativeReader;}
 check(){if(this.closed)throw new Error('Server content loading was cancelled');}
 publishProgress(force=false){const now=Date.now();if(this.progressState&&(force||now-(this.progressTime??0)>100)){this.progressTime=now;this.onProgress({...this.progressState,downloadedBytes:this.downloadedBytes});}}
 diagnostic(code,reason,context={}){this.onDiagnostic({code,reason,...context});}
 async readCache(relative,max){try{const file=path.join(this.directory,relative),stat=await fs.stat(file);if(stat.size>max)throw new Error('Cached NWSync entry exceeds the supported size');return await fs.readFile(file);}catch(error){if(error.code==='ENOENT')return null;throw error;}}
 async writeCache(relative,bytes){
  this.check();const file=path.join(this.directory,relative),temporary=file+'.'+randomUUID()+'.tmp';await fs.mkdir(path.dirname(file),{recursive:true});
  try{await fs.writeFile(temporary,bytes,{flag:'wx'});this.check();await fs.rename(temporary,file);}finally{await fs.rm(temporary,{force:true}).catch(()=>{});}
 }
 async download(base,relative,max){
  this.check();const url=new URL(base);if(!['http:','https:'].includes(url.protocol)||url.username||url.password||url.search||url.hash)throw new Error('Invalid NWSync repository URL');url.pathname=url.pathname.replace(/\/?$/,'/');
  const timeout=AbortSignal.timeout(60000),signal=AbortSignal.any([timeout,this.controller.signal]);let response;
  try{response=await this.fetchResource(new URL(relative,url),{signal});}catch{this.check();throw new Error('NWSync repository request failed');}
  if(!response.ok){await response.body?.cancel();throw new Error(`NWSync repository returned HTTP ${response.status}`);}
  if(Number(response.headers.get('content-length'))>max){await response.body?.cancel();throw new Error('NWSync download exceeds the supported size');}
  const chunks=[];let length=0;try{for await(const chunk of response.body){this.check();length+=chunk.length;if(length>max)throw new Error('NWSync download exceeds the supported size');chunks.push(chunk);this.downloadedBytes+=chunk.length;this.publishProgress();}}catch(error){await response.body?.cancel().catch(()=>{});throw error;}
  this.check();return Buffer.concat(chunks,length);
 }
 async decoded(bytes){return decodeNWSyncBlob(bytes,{decompressZstd:(data,size)=>this.reader().decompress(data,size)});}
 async localInventory(){
  if(!this.localHashes)this.localHashes=(async()=>{try{return new Set((await fs.readdir(path.join(this.directory,'objects'),{withFileTypes:true})).filter(file=>file.isFile()&&validHash(file.name)).map(file=>file.name));}catch(error){if(error.code==='ENOENT')return new Set();throw error;}})();
  return this.localHashes;
 }
 async ensureBlob(entry,url){
  this.check();if(this.ready.has(entry.hash))return;
  // Native SQLiteStorageProvider::Has1c3d60 uses its hash/shard index. Our
  // content-addressed file store builds that availability index in one listing,
  // rather than opening every blob at admission. Demand still verifies header,
  // decompressed size and SHA1, repairing missing/corrupt files from the repo.
  const local=await this.localInventory();this.check();if(local.has(entry.hash)){this.ready.add(entry.hash);return;}
  if(this.nativeDirectory&&!this.nativeReadFailed){
   try{this.nativeInventory??=this.reader().inventory();const hashes=await this.nativeInventory;if(hashes.has(entry.hash)){this.nativeBlobs.add(entry.hash);this.ready.add(entry.hash);return;}}
   catch{this.nativeReadFailed=true;this.diagnostic('network.nwsync-native-cache-failed','Installed NWSync resource inventory could not be read');}
  }
  await this.blob(entry,url);
 }
 async blob(entry,url){
  const {hash,size}=entry;if(!validHash(hash))throw new Error('Invalid NWSync content hash');
  if(this.pendingBlobs.has(hash))return this.pendingBlobs.get(hash);
  const work=(async()=>{
   this.check();let bytes=null;const cached=await this.readCache(path.join('objects',hash),MAX_RESOURCE);if(cached){try{bytes=await this.decoded(cached);if(digest(bytes)!==hash||(size!==null&&bytes.length!==size))throw new Error('Cached content hash does not match');}catch{this.diagnostic('network.nwsync-cache-corrupt','Cached server content failed verification',{hash});bytes=null;}}
   if(!bytes&&this.nativeDirectory&&!this.nativeReadFailed){
    try{const encoded=await this.reader().blob(hash);if(encoded){const candidate=encoded.subarray(0,4).toString('ascii')==='NSYC'?await this.decoded(encoded):encoded;if(digest(candidate)!==hash||(size!==null&&candidate.length!==size))throw new Error('Installed content hash does not match');bytes=candidate;this.nativeBlobs.add(hash);}}
    catch{this.nativeReadFailed=true;this.diagnostic('network.nwsync-native-cache-failed','Installed NWSync content could not be read or verified');}
   }
   if(!bytes){if(!url)throw new Error('Required NWSync content is not cached and no repository is available');const encoded=await this.download(url,`data/sha1/${hash.slice(0,2)}/${hash.slice(2,4)}/${hash}`,MAX_RESOURCE);bytes=await this.decoded(encoded);if(digest(bytes)!==hash||(size!==null&&bytes.length!==size))throw new Error('Downloaded NWSync content failed hash or size verification');await this.writeCache(path.join('objects',hash),encoded);}
   this.check();if(this.localHashes){const local=await this.localHashes;this.check();local.add(hash);}this.ready.add(hash);return bytes;
  })();this.pendingBlobs.set(hash,work);try{return await work;}finally{if(this.pendingBlobs.get(hash)===work)this.pendingBlobs.delete(hash);}
 }
 async findManifest(hash,{advertisement}={}){
  this.check();if(!validHash(hash))throw new Error('Invalid NWSync manifest hash');if(this.manifests.has(hash))return this.manifests.get(hash);
  const work=this.loadManifest(hash,advertisement?.url??null);this.manifests.set(hash,work);try{return await work;}catch(error){this.manifests.delete(hash);if(!this.closed)this.diagnostic('network.nwsync-manifest-failed','Server content could not be loaded',{hash,detail:/^(Invalid|Unsupported|NWSync|Downloaded|Cached|Required|Duplicate)/.test(error.message)?error.message:error.code??'CONTENT_LOAD_FAILED'});throw error;}
 }
 async loadManifest(hash,url){
  this.check();this.progressState={phase:'server-manifest',manifest:hash,completed:0,total:0};this.publishProgress(true);let bytes=await this.readCache(path.join('manifests',hash),MAX_MANIFEST),manifest=null;
  if(bytes){if(digest(bytes)===hash)manifest=parseNWSyncManifest(bytes);else this.diagnostic('network.nwsync-cache-corrupt','Cached server manifest failed verification',{hash});}
  if(!manifest&&this.nativeDirectory&&!this.nativeReadFailed){try{manifest=await this.reader().manifest(hash);}catch{this.nativeReadFailed=true;this.diagnostic('network.nwsync-native-cache-failed','Installed NWSync catalog could not be read');}}
  if(!manifest){if(!url)throw new Error('Required NWSync manifest is not cached and no repository is available');bytes=await this.download(url,`manifests/${hash}`,MAX_MANIFEST);if(digest(bytes)!==hash)throw new Error('Downloaded NWSync manifest failed hash verification');manifest=parseNWSyncManifest(bytes);await this.writeCache(path.join('manifests',hash),bytes);}
  const entries=[...new Map(manifest.entries.map(e=>[e.hash,e])).values()];let cursor=0;this.progressState={phase:'server-content',manifest:hash,completed:0,total:entries.length};this.publishProgress(true);
  let failed=false;const workers=await Promise.allSettled(Array.from({length:Math.min(this.concurrency,entries.length)},async()=>{while(!failed&&cursor<entries.length){const entry=entries[cursor++];try{await this.ensureBlob(entry,url);}catch(error){failed=true;throw error;}this.progressState.completed++;this.publishProgress();}}));const failure=workers.find(result=>result.status==='rejected');if(failure)throw failure.reason;this.check();this.publishProgress(true);
  return{name:hash,entries:manifest.entries,catalog:manifest.catalog,hasResource:(name,type)=>manifest.catalog.has(`${name.toLowerCase()}:${type}`),getResource:async(name,type)=>{
   this.check();const entry=manifest.catalog.get(`${name.toLowerCase()}:${type}`);if(!entry)throw Object.assign(new Error('Resource is not in the selected NWSync manifest'),{code:'RESOURCE_NOT_FOUND'});const data=await this.blob(entry,url);return data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength);
  }};
 }
 close(){if(this.closed)return;this.closed=true;this.controller.abort();this.nativeReader?.close();this.ready.clear();this.nativeBlobs.clear();}
}
