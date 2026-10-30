import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),reports=path.join(project,'reports');
const read=async name=>JSON.parse(await fs.readFile(path.join(reports,name+'.json'),'utf8'));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const sources=async values=>{for(const [name,digest]of Object.entries(values))if(sha(await fs.readFile(path.resolve(project,name)))!==digest)throw Error('Source differs from native receipt: '+name);};
const clean=async name=>{for(const suffix of ['.engine.log','.console.log']){let value;try{value=await fs.readFile(path.join(reports,name+suffix),'utf8');}catch(e){if(e.code==='ENOENT'&&suffix==='.console.log')continue;throw e;}if(/SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use|Unicode parsing error/m.test(value))throw Error('Full engine/console error: '+name);}};
const expected=Object.fromEntries(('index:11 coalescing:12 publication:12 session-cache:18 ordering:20 adoption:6 retirement:78 retirement-physics:10 recording:17 source-bytes:15 nwsync:38 data-retirement:12 actor-retirement:10 packed-keys:67 ascii:15 ascii-typed:81 ui-data-retirement:20 prepared-writer:27 cache-paths:13 skin-stream:277 skin-cache:12 clip-index:81 pipeline-monitors:8 material-cold:12 material-prewarm:12 tables:30 table-cost:23 prepared-cache:16 inheritance:16 validation:252 persistent-actors:14 entry-prefetch:9 actor-failure:27 static-failure:28 ancestors:42 raster-pixels:608 palette-preparation:25 mesh-preparation:846 mesh-cache:14 failed-model:10 postdraw:8 icon-reuse:20 vertices:1227 geometry:2137').split(' ').map(row=>{const [name,count]=row.split(':');return[name,Number(count)];}));
const suite=await read('native-loading-prewarm-verified-suite.suite');
if(!suite.success||suite.checks!==6236||suite.cases.length!==44||new Set(suite.cases.map(row=>row.name)).size!==44)throw Error('Incomplete native suite');
for(const row of suite.cases){
 if(row.checks!==expected[row.name]||!row.success)throw Error('Native case differs: '+row.name);
 const proof=await read(row.run+'.debugger'),result=await read(row.run);
 if(!proof.success||!proof.normalHeap||proof.exceptionTraps!==4||!proof.armed||proof.exception||proof.engineOrLifetimeError||!proof.sourceUnchanged||proof.debuggerExit!==0||!result.success||result.checks!==row.checks)throw Error('Native proof failed: '+row.run);
 await clean(row.run);await sources(proof.sourceSha256);
}
const replay=async(name,current=false)=>{
 const r=await read(name);await clean(name);
 if(!r.success||r.exit!==0||!r.timelineDelivered||!r.offline||r.gameNetworkConnections!==0||!r.sourceUnchanged||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||!r.native.object_visuals_complete||r.native.workers_remaining!==0||!r.native.protocol_finish_ack||r.native.world.entities!==630||r.native.world.desired!==630||r.native.prepared_write_queue.pending!==0)throw Error('Incomplete full-area receipt: '+name);
 if(current)await sources(r.sourceSha256);return r;
};
const reference=await replay('native-loading-prewarm-area4-reference-v1'),candidate=await replay('native-loading-prewarm-area4-candidate-v1'),current=await replay('native-loading-prewarm-default-area4-v1',true);
if(reference.recordingSha256!==candidate.recordingSha256||JSON.stringify(reference.sourceSha256)!==JSON.stringify(candidate.sourceSha256)||reference.native.material_prewarm.enabled||!candidate.native.material_prewarm.enabled)throw Error('Pre-promotion comparison source/input/mode differs');
for(const r of[candidate,current]){const w=r.native.material_prewarm;if(!w.enabled||!w.done||!w.closed||w.prepared!==20||w.failures.length||w.retained_materials!==0||w.retained_textures!==0)throw Error('Default shader owners not prepared/drained');}
const localName='native-loading-prewarm-default-local-v1',local=await read(localName),nativeLocal=await read(localName+'.native');
if(!local.success||!local.sourceUnchanged||!local.debuggerArmed||local.nativeException||local.engineErrors||local.nativeExit!==0||local.publicConnections!==0||nativeLocal.world.entities!==19||nativeLocal.workers_remaining!==0||!nativeLocal.protocol_finish_ack||!nativeLocal.object_visuals_complete||!local.loadingRecording?.complete)throw Error('Authoritative local load failed');
await sources(local.sourceSha256);await clean(localName);
const output={success:true,createdAt:new Date().toISOString(),nativeChecks:6236,cases:44,defaultArea:{run:'native-loading-prewarm-default-area4-v1',entities:630,playerMs:current.native.world.playable_ms,terrainMs:current.native.world.terrain.complete_ms,warmup:current.native.material_prewarm},local:{run:localName,entities:19,server:'127.0.0.1:5121',scope:'Headless authority/loading check; graphical shader owners validated separately'},comparison:{reference:'native-loading-prewarm-area4-reference-v1',candidate:'native-loading-prewarm-area4-candidate-v1',referencePlayerMs:reference.native.world.playable_ms,candidatePlayerMs:candidate.native.world.playable_ms,scope:'Same-source single offline observations before default promotion; not statistical FPS or complete route/original-client parity acceptance'},publicConnections:0,goalComplete:false,performanceAccepted:false,fullGameplayAccepted:false};
const name=process.argv.find(x=>x.startsWith('--run='))?.slice(6)??'native-loading-material-prewarm-audit-v1';if(!/^[a-z0-9-]+$/.test(name))throw Error('Invalid receipt name');
await fs.writeFile(path.join(reports,name+'.json'),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,checks:6236,cases:44,report:path.join(reports,name+'.json')}));
