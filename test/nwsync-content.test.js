import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {deflateSync,zstdCompressSync} from 'node:zlib';
import {parseNWSyncManifest} from '../src/nwsync_manifest.js';
import {NWSyncContent,decodeNWSyncBlob} from '../electron/nwsync_content.mjs';
import {NWSyncReader} from '../electron/nwsync_reader.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {loadNetworkObjectRules} from '../src/network_object_rules.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {openServerResourceContext} from '../electron/server_resource_context.mjs';

const sha=bytes=>createHash('sha1').update(bytes).digest('hex');
const entry=(name,text,type=2017)=>{const data=Buffer.isBuffer(text)?text:Buffer.from(text);return{name,type,data,hash:sha(data),size:data.length};};
function manifest(entries,mappings=[]){
 const bytes=Buffer.alloc(16+entries.length*42+mappings.length*22);bytes.write('NSYM');bytes.writeUInt32LE(3,4);bytes.writeUInt32LE(entries.length,8);bytes.writeUInt32LE(mappings.length,12);let offset=16;
 for(const e of entries){Buffer.from(e.hash,'hex').copy(bytes,offset);bytes.writeUInt32LE(e.size,offset+20);bytes.write(e.name,offset+24,16,'latin1');bytes.writeUInt16LE(e.type,offset+40);offset+=42;}
 for(const m of mappings){bytes.writeUInt32LE(m.index,offset);bytes.write(m.name,offset+4,16,'latin1');bytes.writeUInt16LE(m.type,offset+20);offset+=22;}return bytes;
}
function compressed(data,algorithm=0){
 const offset=algorithm===0?16:algorithm===1?20:24,body=algorithm===0?data:algorithm===1?deflateSync(data):zstdCompressSync(data),bytes=Buffer.alloc(offset+body.length);bytes.write('NSYC');bytes.writeUInt32LE(3,4);bytes.writeUInt32LE(algorithm,8);bytes.writeUInt32LE(data.length,12);if(algorithm)bytes.writeUInt32LE(1,16);body.copy(bytes,offset);return bytes;
}
function tlk(text){const data=Buffer.from(text),bytes=Buffer.alloc(60+data.length);bytes.write('TLK V3.0');bytes.writeUInt32LE(1,12);bytes.writeUInt32LE(60,16);bytes.writeUInt32LE(1,20);bytes.writeUInt32LE(data.length,52);data.copy(bytes,60);return bytes;}
async function temporary(t){const directory=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-server-content-'));t.after(()=>fs.rm(directory,{recursive:true,force:true}));return directory;}
async function repository(t,files){const requests=[];const server=http.createServer((request,response)=>{requests.push(request.url);const bytes=files.get(request.url);if(bytes){response.writeHead(200,{'content-length':bytes.length});response.end(bytes);}else{response.writeHead(404);response.end();}});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));t.after(()=>new Promise(resolve=>server.close(resolve)));return{url:`http://127.0.0.1:${server.address().port}/content`,requests};}
function expose(files,entries,{mappings=[],algorithm=0}={}){const bytes=manifest(entries,mappings),hash=sha(bytes);files.set('/content/manifests/'+hash,bytes);for(const e of entries)files.set(`/content/data/sha1/${e.hash.slice(0,2)}/${e.hash.slice(2,4)}/${e.hash}`,compressed(e.data,algorithm));return hash;}
async function install(t){const root=await temporary(t);await fs.mkdir(path.join(root,'data'));for(const key of ['nwn_base','nwn_retail']){const bytes=Buffer.alloc(64);bytes.write('KEY V1  ');bytes.writeUInt32LE(64,16);bytes.writeUInt32LE(64,20);await fs.writeFile(path.join(root,'data',key+'.key'),bytes);}await fs.mkdir(path.join(root,'lang/en/data'),{recursive:true});await fs.writeFile(path.join(root,'lang/en/data/dialog.tlk'),tlk('Base text'));return root;}
function erf(entries){const count=entries.length,start=160+count*32,bytes=Buffer.alloc(start+entries.reduce((n,e)=>n+e.data.length,0));bytes.write('HAK V1.0');bytes.writeUInt32LE(count,16);bytes.writeUInt32LE(160,24);bytes.writeUInt32LE(160+count*24,28);let next=start;for(const [i,e]of entries.entries()){const key=160+i*24,record=160+count*24+i*8;bytes.write(e.name,key,16,'latin1');bytes.writeUInt32LE(i,key+16);bytes.writeUInt16LE(e.type,key+20);bytes.writeUInt32LE(next,record);bytes.writeUInt32LE(e.data.length,record+4);e.data.copy(bytes,next);next+=e.data.length;}return bytes;}

test('NSYM v3 preserves aliases, physical names/types and hashes and rejects invalid catalogs',()=>{
 const a=entry('custom_spell','table'),b=entry('empty',Buffer.alloc(0),3),bytes=manifest([a,b],[{index:0,name:'alias',type:2017}]),parsed=parseNWSyncManifest(bytes);assert.equal(parsed.catalog.get('alias:2017').hash,a.hash);assert.equal(parsed.entries[1].size,0);
 for(let length=0;length<bytes.length;length++)assert.throws(()=>parseNWSyncManifest(bytes.subarray(0,length)));
 for(const mutate of [b=>b.writeUInt32LE(4,4),b=>b.writeUInt32LE(2,16+2*42),b=>b.write('../bad',40),b=>b.writeUInt32LE(0xffffffff,36)]){const bad=Buffer.from(bytes);mutate(bad);assert.throws(()=>parseNWSyncManifest(bad));}
 assert.throws(()=>parseNWSyncManifest(manifest([a,a])),/Duplicate/);
 assert.throws(()=>parseNWSyncManifest(manifest([a,{...a,name:'other',size:99}])),/inconsistent/);
 const spaced=parseNWSyncManifest(manifest([entry('trailing ','data')]));assert.equal(spaced.catalog.has('trailing :2017'),true);assert.equal(spaced.catalog.has('trailing:2017'),false);
});

test('NSYC none, zlib and native Zstandard agree and enforce header/dictionary/size limits',async t=>{
 const data=Buffer.from('custom game resources '.repeat(1000));const reader=process.platform==='win32'?new NWSyncReader(await temporary(t)):null;t.after(()=>reader?.close());
 for(const algorithm of reader?[0,1,2]:[0,1])assert.deepEqual(await decodeNWSyncBlob(compressed(data,algorithm),{decompressZstd:(b,n)=>reader.decompress(b,n)}),data);
 const zero=Buffer.alloc(0);assert.deepEqual(await decodeNWSyncBlob(compressed(zero,2)),zero);
 for(const mutate of [b=>b.writeUInt32LE(4,4),b=>b.writeUInt32LE(7,8),b=>b.writeUInt32LE(data.length+1,12),b=>b.writeUInt32LE(4,16),b=>b.writeUInt32LE(1,20)]){const bytes=compressed(data,2);mutate(bytes);await assert.rejects(decodeNWSyncBlob(bytes,{decompressZstd:(b,n)=>reader?.decompress(b,n)}));}
 await assert.rejects(decodeNWSyncBlob(compressed(data),{maxBytes:10}),/size/);await assert.rejects(decodeNWSyncBlob(compressed(data).subarray(0,10)),/header|buffer/);
});

test('HTTP manifest download verifies content, deduplicates aliases, caches offline, and isolates another server',async t=>{
 const directory=await temporary(t),files=new Map(),a=entry('spells','server A'),empty=entry('empty',Buffer.alloc(0),3),hash=expose(files,[a,empty],{mappings:[{index:0,name:'other_spells',type:2017}],algorithm:1}),server=await repository(t,files),progress=[];
 const owner=new NWSyncContent({directory,onProgress:p=>progress.push(p)});t.after(()=>owner.close());
 const context=await owner.findManifest(hash,{advertisement:{url:server.url}});assert.equal(decodeResourceText(await context.getResource('SPELLS',2017)),'server A');assert.equal((await context.getResource('empty',3)).byteLength,0);assert.equal(server.requests.length,3);assert.equal(progress.at(-1).completed,2);
 const offline=new NWSyncContent({directory,fetch:()=>{throw new Error('Offline');}});t.after(()=>offline.close());const cached=await offline.findManifest(hash);assert.equal(decodeResourceText(await cached.getResource('other_spells',2017)),'server A');
 const b=entry('spells','server B'),hashB=expose(files,[b]),second=new NWSyncContent({directory});t.after(()=>second.close());const contextB=await second.findManifest(hashB,{advertisement:{url:server.url}});assert.equal(decodeResourceText(await contextB.getResource('spells',2017)),'server B');assert.equal(decodeResourceText(await cached.getResource('spells',2017)),'server A');second.close();await assert.rejects(contextB.getResource('spells',2017),/cancelled/);await assert.rejects(second.findManifest(hashB),/cancelled/);
});

test('explicit cold-download policy never reads original NWN catalogs, inventories or blobs',async t=>{
 const root=await install(t),profile=await temporary(t),directory=await temporary(t),files=new Map(),a=entry('skills','2DA V2.0\n\nName\n0 123\n'),hash=expose(files,[a],{algorithm:1}),server=await repository(t,files);let nativeReaders=0;
 const resources=installedNetworkResources({install:root,userDirectory:profile,cacheDirectory:directory,reuseInstalledNWSync:false,contentOptions:{readerFactory:()=>{nativeReaders++;throw new Error('Original cache access is forbidden');}}});t.after(()=>resources.close());
 assert.deepEqual(resources.sourcePolicy,{reuseInstalledNWSync:false});const layer=await resources.findManifest(hash,{advertisement:{url:server.url}});assert.equal(decodeResourceText(await layer.getResource('skills',2017)),a.data.toString());assert.equal(nativeReaders,0);assert.equal(server.requests.length,2);assert.ok((await fs.stat(path.join(directory,'objects',a.hash))).size>0);
 assert.throws(()=>installedNetworkResources({install:root,reuseInstalledNWSync:'false'}),/reuse setting/);
});

test('bad downloads never become ready; damaged local blobs are diagnosed and repaired by verified downloads',async t=>{
 const directory=await temporary(t),files=new Map(),a=entry('skills','server skills'),hash=expose(files,[a]),server=await repository(t,files),issues=[];const owner=new NWSyncContent({directory,onDiagnostic:d=>issues.push(d)});t.after(()=>owner.close());
 const resourcePath=`/content/data/sha1/${a.hash.slice(0,2)}/${a.hash.slice(2,4)}/${a.hash}`;files.set(resourcePath,compressed(Buffer.from('wrong')));await assert.rejects(owner.findManifest(hash,{advertisement:{url:server.url}}),/verification/);assert.equal(owner.ready.has(a.hash),false);await assert.rejects(fs.stat(path.join(directory,'objects',a.hash)),{code:'ENOENT'});
 files.set(resourcePath,compressed(a.data));const context=await owner.findManifest(hash,{advertisement:{url:server.url}});await fs.writeFile(path.join(directory,'objects',a.hash),'bad');assert.equal(decodeResourceText(await context.getResource('skills',2017)),'server skills');assert.ok(issues.some(d=>d.code==='network.nwsync-cache-corrupt'));
 const corruptHash='a'.repeat(40);files.set('/content/manifests/'+corruptHash,manifest([a]));await assert.rejects(owner.findManifest(corruptHash,{advertisement:{url:server.url}}),/hash verification/);await assert.rejects(owner.findManifest('../escape'),/hash/);
});

test('disconnect aborts an outstanding download and prevents late publication or caching',async t=>{
 const directory=await temporary(t);let observedSignal,release;const entered=new Promise(resolve=>release=resolve),owner=new NWSyncContent({directory,fetch:async(_url,{signal})=>{observedSignal=signal;release();return new Promise((_resolve,reject)=>signal.addEventListener('abort',()=>reject(new Error('aborted')),{once:true}));}});t.after(()=>owner.close());const pending=owner.findManifest('a'.repeat(40),{advertisement:{url:'http://127.0.0.1/content'}});await entered;owner.close();await assert.rejects(pending,/cancelled/);assert.equal(observedSignal.aborted,true);assert.equal(owner.ready.size,0);
});

test('server context uses wire HAKs, selected manifests, custom TLKs and active decoder rules rather than local IFO or stock IDs',async t=>{
 const root=await install(t),profile=await temporary(t),cacheDirectory=await temporary(t),files=new Map();await fs.mkdir(path.join(profile,'hak'));await fs.mkdir(path.join(profile,'override'));
 const tables={skills:'2DA V2.0\n\nName Description Icon\n0 16777216 16777216 custom\n1 16777216 16777216 custom\n2 16777216 16777216 custom\n',baseitems:'2DA V2.0\n\nModelType\n0 7\n',classes:'2DA V2.0\n\nPickSchool PickDomains\n0 1 1\n',visualeffects:'2DA V2.0\n\nType_FD\n0 B\n',spells:'2DA V2.0\n\nTargetType\n0 16\n',feat:'2DA V2.0\n\nFeat\n0 5000\n'};
 await fs.writeFile(path.join(profile,'hak/first.hak'),erf([entry('spells','first HAK'),entry('only_hak','wire HAK')]));await fs.writeFile(path.join(profile,'hak/second.hak'),erf([entry('spells','second HAK')]));await fs.writeFile(path.join(profile,'override/spells.2da'),'loose override');await fs.writeFile(path.join(profile,'override/loose.2da'),'profile loose');
 const hash=expose(files,[...Object.entries(tables).map(([name,data])=>entry(name,data)),entry('custom',tlk('Custom server name'),2018),entry('customf',tlk('Female server name'),2018)]),additionalSpell=entry('spells','2DA V2.0\n\nTargetType\n0 32\n'),extra=expose(files,[additionalSpell]),wrongLanguage=expose(files,[entry('spells','should not load')]),server=await repository(t,files),resources=installedNetworkResources({install:root,userDirectory:profile,cacheDirectory});t.after(()=>resources.close());
 const requirements={customTlk:'custom',nwmResourceName:'',haks:['first','second'],advertisement:{hash,url:server.url,manifests:[{hash:extra,flags:1,language:255},{hash:wrongLanguage,flags:1,language:2}]}};
 const result=await resolveServerResources(requirements,{...resources,language:0});assert.equal(result.ready,true);assert.equal(result.resolved.some(r=>r.name===wrongLanguage),false);
 const resolver=await resources.openModule(null,result.resolved),rules=await loadNetworkObjectRules(resolver);assert.equal(rules.skillCount,3);assert.equal(rules.baseItemModelType(0),7);assert.equal(rules.spellInputInfo(0).targetType,32);assert.deepEqual(rules.classInfo(0),{pickSchool:true,pickDomains:true});assert.equal(rules.isBeam(0),true);
 assert.equal(decodeResourceText(await resolver.getResource('only_hak',2017)),'wire HAK');assert.equal(decodeResourceText(await resolver.getResource('loose',2017)),'profile loose');assert.equal((await resources.talkString(0x1000000,0,result.resolved,()=>{})).text,'Custom server name');assert.equal((await resources.talkString(0x1000000,1,result.resolved,()=>{})).text,'Female server name');assert.equal((await resources.talkString(0,0,result.resolved,()=>{})).text,'Base text');
 const legacy=await resources.openModule(null,result.resolved.filter(r=>r.kind==='hak'));assert.equal(decodeResourceText(await legacy.getResource('spells',2017)),'first HAK');
 const withoutHaks=await resources.openModule(null,[]);assert.equal(decodeResourceText(await withoutHaks.getResource('spells',2017)),'loose override');assert.equal(withoutHaks.hasResource('only_hak',2017),false);
});

test('optional additional manifests do not block admission; required and language-selected failures do',async()=>{
 const hash='1'.repeat(40),extra='2'.repeat(40),base={haks:[],customTlk:'',nwmResourceName:'',advertisement:{hash,url:'http://example.invalid',manifests:[{hash:extra,flags:0,language:255}]}};
 const findManifest=async value=>value===hash?{}:null,issues=[];assert.equal((await resolveServerResources(base,{findManifest,onDiagnostic:d=>issues.push(d)})).ready,true);assert.ok(issues.some(d=>d.required===false));
 base.advertisement.manifests[0].flags=1;assert.equal((await resolveServerResources(base,{findManifest,onDiagnostic:()=>{}})).ready,false);base.advertisement.manifests[0].language=2;assert.equal((await resolveServerResources(base,{findManifest,language:0,onDiagnostic:()=>{}})).ready,true);
});

test('custom TLKs in legacy HAKs are selected ahead of physical files and malformed tables block admission',async t=>{
 const root=await install(t),profile=await temporary(t),cacheDirectory=await temporary(t);await fs.mkdir(path.join(profile,'hak'));await fs.mkdir(path.join(profile,'tlk'));await fs.writeFile(path.join(profile,'tlk/custom.tlk'),tlk('Loose custom'));
 await fs.writeFile(path.join(profile,'hak/server.hak'),erf([entry('custom',tlk('HAK custom'),2018)]));await fs.writeFile(path.join(profile,'hak/bad.hak'),erf([entry('custom',Buffer.from('bad TLK'),2018)]));await fs.writeFile(path.join(profile,'hak/badfemale.hak'),erf([entry('custom',tlk('Good primary'),2018),entry('customf',Buffer.from('bad female TLK'),2018)]));
 const resources=installedNetworkResources({install:root,userDirectory:profile,cacheDirectory});t.after(()=>resources.close());const requirements={haks:['server'],customTlk:'custom',nwmResourceName:'',advertisement:null},result=await resolveServerResources(requirements,{...resources,onDiagnostic:()=>{}});assert.equal(result.ready,true);assert.equal((await resources.talkString(0x1000000,0,result.resolved,()=>{})).text,'HAK custom');
 const broken=await resolveServerResources({...requirements,haks:['bad']},{...resources,onDiagnostic:()=>{}});assert.equal(broken.ready,false);assert.deepEqual(broken.missing,[{kind:'tlk',name:'custom'}]);assert.equal((await resolveServerResources({...requirements,haks:['badfemale']},{...resources,onDiagnostic:()=>{}})).ready,false);
});

test('profile portraits provide images without admitting rules and remain separate from server layers',async t=>{
 const root=await install(t),profile=await temporary(t);await fs.mkdir(path.join(profile,'portraits'));await fs.writeFile(path.join(profile,'portraits/CustomM.TGA'),'portrait');await fs.writeFile(path.join(profile,'portraits/ruleset.2da'),'must not mount');
 const a=await openServerResourceContext({install:root,userDirectory:profile}),b=await openServerResourceContext({install:root});assert.equal(new TextDecoder().decode(await a.getResource('customm',3)),'portrait');assert.deepEqual(a.portraitNames(),['customm']);assert.deepEqual(b.portraitNames(),[]);await assert.rejects(a.getResource('ruleset',2017),{code:'RESOURCE_NOT_FOUND'});await assert.rejects(b.getResource('customm',3),{code:'RESOURCE_NOT_FOUND'});
});
test('source registration order agrees with 35 executions of the original priority routine, including repeated HAKs/manifests',async t=>{
 const observed=JSON.parse(readFileSync(new URL('../backups/animations/native-resource-priority-observations.json',import.meta.url))),root=await install(t);assert.equal(observed.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(observed.rows.length,35);
 const memoryFile=(name,data,priority)=>({name,priority,arrayBuffer:async()=>data});
 for(const row of observed.rows){
  const archiveSources=row.registrations.filter(s=>s.type===3&&s.name!=='module'),manifestSources=row.registrations.filter(s=>s.type===5),resolved=[];
  for(const source of [...archiveSources].reverse())resolved.push({kind:'hak',name:source.name,resource:memoryFile(source.name,erf([entry('shared',source.name),entry('hak_shared',source.name)]),source.priority)});
  for(const source of manifestSources)resolved.push({kind:'nwsync',name:source.name,resource:{name:source.name,hasResource:name=>name==='shared',getResource:async()=>Uint8Array.from(Buffer.from(source.name)).buffer}});
  // Compare all registered source positions, not only the final winning table.
  const resolver=await openServerResourceContext({install:root,resolved,hakPriority:file=>file.priority});assert.deepEqual(resolver.layers.map(s=>s.name),row.ordered.filter(s=>s.type===5).map(s=>s.name));assert.deepEqual(resolver.haks.map(s=>({name:s.name,priority:s.priority})),row.ordered.filter(s=>s.type===3&&s.name!=='module').map(s=>({name:s.name,priority:s.priority})));
  if(resolver.haks.length)assert.equal(decodeResourceText(await resolver.getResource('hak_shared',2017)),row.ordered.find(s=>s.type===3&&s.name!=='module').name);
  assert.equal(decodeResourceText(await resolver.getResource('shared',2017)),row.ordered.find(s=>s.type===5||(s.type===3&&s.name!=='module')).name);
 }
});

test('installed SQLite catalog and compressed blobs are reused without modifying original databases', {skip:process.platform!=='win32'},async t=>{
 const {DatabaseSync}=await import('node:sqlite'),directory=await temporary(t),nativeDirectory=path.join(directory,'Ünicode-cache');await fs.mkdir(nativeDirectory);const data=entry('custom_rules','Native SQLite data'),hash=sha(manifest([data])),metadata=path.join(nativeDirectory,'nwsyncmeta.sqlite3'),shard=path.join(nativeDirectory,'nwsyncdata_0.sqlite3');
 const db=new DatabaseSync(metadata);db.exec('create table manifests(sha1 text);create table manifest_resrefs(manifest_sha1 text,resref_sha1 text,resref text,restype integer);create table shards(id integer,serial integer);');db.prepare('insert into manifests values(?)').run(hash);db.prepare('insert into manifest_resrefs values(?,?,?,?)').run(hash,data.hash,data.name,data.type);db.exec('insert into shards values(1,0)');db.close();const blobDB=new DatabaseSync(shard);blobDB.exec('create table resrefs(sha1 text,data blob,size integer)');blobDB.prepare('insert into resrefs values(?,?,?)').run(data.hash,compressed(data.data,2),data.size);blobDB.close();const before=await Promise.all([metadata,shard].map(async file=>sha(await fs.readFile(file))));
 let reads=0,inventories=0;const owner=new NWSyncContent({directory:path.join(directory,'private'),nativeDirectory,readerFactory:directory=>{const reader=new NWSyncReader(directory),blob=reader.blob.bind(reader),inventory=reader.inventory.bind(reader);reader.blob=(...args)=>{reads++;return blob(...args);};reader.inventory=(...args)=>{inventories++;return inventory(...args);};return reader;},fetch:()=>{throw new Error('Must remain offline');}});t.after(()=>owner.close());const view=await owner.findManifest(hash);assert.equal(reads,0,'admission uses database catalog without decompressing the whole installed collection');assert.equal(inventories,1);assert.equal(decodeResourceText(await view.getResource('custom_rules',2017)),data.data.toString());assert.equal(reads,1);assert.equal(owner.nativeBlobs.has(data.hash),true);owner.close();const after=await Promise.all([metadata,shard].map(async file=>sha(await fs.readFile(file))));assert.deepEqual(after,before);await assert.rejects(fs.stat(path.join(directory,'private/objects',data.hash)),{code:'ENOENT'});
});
