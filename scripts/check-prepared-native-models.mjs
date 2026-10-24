// Read installed assets only. Derived test files live in an owned OS temporary
// directory; the workspace receives hashes/counts, never game asset payloads.
import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';
import {PreparedModelCache} from '../electron/prepared_model_cache.mjs';
import {parseModel} from '../src/model_parser.js';import {buildModelGeometry} from '../src/prepared_model_geometry.js';
const version=process.argv.find(a=>a.startsWith('--version='))?.slice(10)??'v1';if(!/^[a-z0-9-]+$/.test(version))throw Error('Invalid version');
const hash=b=>createHash('sha256').update(b).digest('hex'),root=process.cwd(),directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-model-prep-')),report={success:false,scope:'Read-only installed model/geometry round trip through worker, memory and disk cache. No network connections or asset bytes written to workspace.',models:[]};let cache;
try{
 const base=JSON.parse(await fs.readFile('backups/animations/dense-local-prepared-model-baseline-c-v1.json','utf8')),rows=(await fs.readFile(base.runtimeLog,'utf8')).trim().split('\n').map(JSON.parse),names=[...new Set(rows.map(r=>r.context?.model).filter(n=>typeof n==='string'&&/^[a-z0-9_]{1,32}$/i.test(n)))].slice(0,80),resolver=await openServerResourceContext({install:path.resolve(root,'../FullDecomp/NwnRootInstall')}),sources=[];
 cache=new PreparedModelCache({directory});
 for(const name of names){const raw=await resolver.getResource(name,2002);sources.push({name,raw});await cache.prepare(raw);}await cache.flush();report.cold=cache.snapshot();await cache.dispose();cache=new PreparedModelCache({directory});
 for(const{name,raw}of sources){
  const cold=parseModel(raw),warm=await cache.prepare(raw),saved=warm.nodes.map(n=>n.preparedGeometry);for(const n of warm.nodes)delete n.preparedGeometry;assert.deepEqual(warm,cold,name+' decoded source changed');for(let i=0;i<warm.nodes.length;i++)if(saved[i])warm.nodes[i].preparedGeometry=saved[i];
  let meshes=0;const digest=createHash('sha256');
  for(let i=0;i<cold.nodes.length;i++)if(saved[i]){
   const a=buildModelGeometry(cold.nodes[i]),b=buildModelGeometry(warm.nodes[i]);try{assert.ok(a&&b,name);for(const field of ['position','normal','uv']){assert.deepEqual(a.attributes[field].array,b.attributes[field].array,name+' '+field);digest.update(new Uint8Array(a.attributes[field].array.buffer));}assert.deepEqual(a.groups,b.groups,name+' groups');assert.deepEqual(a.boundingSphere,b.boundingSphere,name+' bounds');assert.deepEqual(a.userData,b.userData,name+' picking');meshes++;}finally{a?.dispose();b?.dispose();}
  }
  const bytes=raw instanceof ArrayBuffer?new Uint8Array(raw):raw;report.models.push({name,sourceSha256:hash(bytes),format:cold.format,nodes:cold.nodes.length,meshes,geometrySha256:digest.digest('hex')});
 }
 report.warm=cache.snapshot();assert.ok(report.models.length>=20,'Insufficient native model coverage');assert.equal(report.warm.diskHits+report.warm.memoryHits,report.models.length);assert.ok(report.warm.diskHits>=20);assert.equal(report.warm.misses,0);report.success=true;
}catch(error){report.failure=error.stack;}finally{
 await cache?.dispose();const target=path.resolve(directory),temporary=path.resolve(os.tmpdir())+path.sep;if(!target.startsWith(temporary)||!path.basename(target).startsWith('nwn-native-model-prep-'))throw Error('Invalid temporary cache cleanup target');await fs.rm(target,{recursive:true,force:true});await fs.writeFile(`backups/animations/prepared-native-model-roundtrip-${version}.json`,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,models:report.models.length,failure:report.failure}));if(!report.success)process.exitCode=1;
}
