// Extend only a private fixture. Original caches/SQLite are read-only;
// manifest-declared missing bodies remain gaps and never become stock aliases.
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {DatabaseSync} from 'node:sqlite';
import {zstdDecompressSync} from 'node:zlib';
import {fileURLToPath} from 'node:url';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {decodeNWSyncBlob} from '../electron/nwsync_content.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const owned=path.join(root,'godot-client/.cache/cached-warlock-creation');
const label=process.argv[2];assert.match(label??'',/^[a-z0-9-]{3,80}$/);
const source=path.resolve(process.argv[3]??path.join(owned,'cached-arelith-warlock-namespace-v2'));
assert.ok(source.startsWith(owned+path.sep));
const output=path.join(owned,label);await fs.cp(source,output,{recursive:true,errorOnExist:true,force:false});
const report=JSON.parse(await fs.readFile(path.join(output,'fixture.json')));
assert.ok(report.success&&report.captureGaps.length===0&&report.privateNwsyncCatalog.fullNamespace);
const sha=(bytes,kind='sha256')=>createHash(kind).update(bytes).digest('hex');
const manifestBytes=await fs.readFile(path.join(output,'nwsync/manifests',report.manifest));
assert.equal(sha(manifestBytes,'sha1'),report.manifest);assert.equal(sha(manifestBytes),report.manifestSha256);
const manifest=parseNWSyncManifest(manifestBytes);
const initial=[['nw_fm_bat',2027],['familiar',2036],['humanm',2036],['humanl',2036],['namefilter',2017],['pal_skin01',3],['pal_hair01',3],['pal_tattoo01',3]];
let requests=initial.map(([name,type])=>({name,type}));
if(process.argv[4]){
 const diagnostic=JSON.parse(await fs.readFile(path.resolve(process.argv[4])));
 assert.ok(Array.isArray(diagnostic.observations?.resourceReads));
 requests=diagnostic.observations.resourceReads.filter(row=>row.error).map(({name,type})=>({name,type}));
}
const unique=[...new Map(requests.map(row=>[row.name.toLowerCase()+':'+row.type,row])).values()];
assert.ok(unique.length<=128,'Only a bounded observed dependency batch may be extracted');
const followModels=process.argv[5]==='--supermodels';if(process.argv[5]&&!followModels)throw Error('Unknown bounded dependency option');
const knownRequests=new Set(unique.map(row=>row.name.toLowerCase()+':'+row.type));
const visitedModels=new Set();let modelBytes=0;
const profile=path.join(os.homedir(),'Documents/Neverwinter Nights.0');
const cache=path.join(profile,'replacement-client/server-content');
const dbPath=path.join(profile,'nwsync/nwsyncdata_0.sqlite3');
const before=await fs.stat(dbPath);const db=new DatabaseSync(dbPath,{readOnly:true});
const extension={sourceFixture:source,requests:unique,captured:[],manifestAbsent:[],captureGaps:[],dependencies:[],followModels,originalDatabaseMetadataUnchanged:false};
try{
 for(const request of unique){
  const name=request.name.toLowerCase(),type=request.type;assert.match(name,/^[a-z0-9_]{1,32}$/);assert.ok(Number.isInteger(type)&&type>=0&&type<=65535);
  const entry=manifest.catalog.get(`${name}:${type}`);
  if(!entry){extension.manifestAbsent.push({name,type,meaning:'No selected-manifest override; exact installed catalog must establish fallback or legitimate absence.'});continue;}
  let bytes;const known=report.resources.find(row=>row.name===name&&row.type===type);
  if(known){bytes=await fs.readFile(path.join(output,known.file));assert.equal(sha(bytes),known.sha256);}
  else{
   let encoded,origin;
   try{encoded=await fs.readFile(path.join(cache,'objects',entry.hash));origin='existing_compressed_file_cache';}
   catch(error){if(error.code!=='ENOENT')throw error;const row=db.prepare('SELECT data,size FROM resrefs WHERE sha1=?').get(entry.hash);if(!row){extension.captureGaps.push({name,type,sha1:entry.hash,size:entry.size});continue;}encoded=row.data;origin='existing_native_sqlite_readonly';}
   bytes=await decodeNWSyncBlob(encoded,{decompressZstd:value=>zstdDecompressSync(value)});
   assert.equal(bytes.length,entry.size);assert.equal(sha(bytes,'sha1'),entry.hash);
   const object=path.join(output,'nwsync/objects',entry.hash);
   try{await fs.writeFile(object,encoded,{flag:'wx'});}catch(error){if(error.code!=='EEXIST')throw error;assert.deepEqual(await fs.readFile(object),encoded);}
   const file=`resources/${name}.${type}.bin`;await fs.writeFile(path.join(output,file),bytes,{flag:'wx'});
   const row={name,type,sha1:entry.hash,sha256:sha(bytes),bytes:bytes.length,source:origin,file};report.resources.push(row);extension.captured.push(row);
  }
  if(followModels&&type===2002&&!visitedModels.has(name)){
   visitedModels.add(name);modelBytes+=bytes.length;assert.ok(visitedModels.size<=32&&modelBytes<=64*1024*1024,'Bounded actual supermodel closure exceeded');
   // Same binary field and ASCII command consumed by the shipping actor
   // decoder; no geometry/animation inference or guessed resource names.
   let supermodel;
   if(bytes.length>=4&&bytes.readUInt32LE(0)===0){
    assert.ok(bytes.length>=244&&bytes.readUInt32LE(4)>=232&&12+bytes.readUInt32LE(4)+bytes.readUInt32LE(8)<=bytes.length,'Invalid native MDL section bounds');
    supermodel=bytes.subarray(180,244).toString('latin1').split('\0')[0].toLowerCase();
   }else supermodel=bytes.toString('latin1').match(/^\s*setsupermodel\s+\S+\s+(\S+)/im)?.[1]?.toLowerCase()??'';
   if(supermodel&&supermodel!=='null'){
    assert.match(supermodel,/^[a-z0-9_]{1,32}$/);extension.dependencies.push({from:name,to:supermodel,type:2002,source:'Native MDL supermodel field/setsupermodel command'});
    const key=supermodel+':2002';if(!knownRequests.has(key)){assert.ok(unique.length<128);knownRequests.add(key);unique.push({name:supermodel,type:2002});}
   }
  }
 }
}finally{
 db.close();const after=await fs.stat(dbPath);extension.originalDatabaseMetadataUnchanged=before.size===after.size&&before.mtimeMs===after.mtimeMs;
 assert.ok(extension.originalDatabaseMetadataUnchanged,'Original native SQLite metadata changed');
 report.extensions=[...(report.extensions??[]),extension];report.output=output;report.captureGaps.push(...extension.captureGaps);
 report.success=report.captureGaps.length===0;
 report.privateNwsyncCatalog.extractedObjectBodies=new Set(report.resources.map(row=>row.sha1)).size;
 report.sourceFiles.push({path:'scripts/extend-cached-warlock-fixture.mjs',sha256:sha(await fs.readFile(fileURLToPath(import.meta.url)))});
 if(followModels)for(const file of ['godot-client/systems/native_data/actor_model.gd','godot-client/systems/native_data/ascii_model.gd'])report.sourceFiles.push({path:file,sha256:sha(await fs.readFile(path.join(root,file)))});
 await fs.writeFile(path.join(output,'fixture.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({success:report.success,output,resources:report.resources.length,captured:extension.captured.map(({name,type,bytes})=>({name,type,bytes})),manifestAbsent:extension.manifestAbsent,captureGaps:extension.captureGaps,originalDatabaseMetadataUnchanged:extension.originalDatabaseMetadataUnchanged,httpAttempts:0,gameConnections:0,protectedProfilesRead:0}));
}
process.exitCode=report.success?0:1;
