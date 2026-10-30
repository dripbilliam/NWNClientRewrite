// Offline audit only; this tool does not prepare assets or connect to servers.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=p=>fs.readFile(new URL(p,project)),json=async p=>JSON.parse(await read(p));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),reports=[];
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
for(const[name,count]of [['native-particle-lightning-v2',5494],['native-reference-reattach-v1',784],['native-reference-gpu-v2',147],['native-particle-runtime-reference-v2',29],['native-actor-reference-regression-v1',266819],['native-static-clip-v1',8]]){
 const b=await read('reports/'+name+'.json'),r=JSON.parse(b);assert.equal(r.success??r.passed,true,name);assert.equal(r.checks,count,name);assert.deepEqual(r.failures,[]);reports.push({name,checks:count,sha256:hash(b)});
 if(name!=='native-reference-gpu-v2')assert.ok(!bad.test(String(await read('reports/'+name+'.log'))),name+' log');
}
const gpu=await json('reports/native-reference-gpu-v2.debugger.json');
for(const k of ['success','normalHeap','armed','sourceUnchanged'])assert.equal(gpu[k],true,k);
assert.equal(gpu.exceptionTraps,4);assert.equal(gpu.exception,false);assert.equal(gpu.engineOrLifetimeError,false);
for(const[file,sha]of Object.entries(gpu.sourceSha256))assert.equal(hash(await read(file)),sha,'Current GPU source '+file);
const name='native-session-references-v1',live=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
for(const k of ['success','protocolOnly','sourceUnchanged','debuggerArmed'])assert.equal(live[k],true,k);
assert.equal(live.renderingPrepared,false);assert.equal(live.nativeException,false);assert.equal(live.nativeExit,0);assert.equal(live.publicConnections,0);
assert.equal(live.native.workersRemaining,0);assert.equal(native.protocol_finish_ack,true);assert.equal(live.native.world.entities,20);assert.equal(live.native.world.terrain.rendered_tiles,9);
assert.ok(live.authoritativeDistance>.2&&live.authoritativeDistance<2);assert.ok(Math.abs(live.localWalkDistance-live.authoritativeDistance)<.001);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),suffix);
assert.deepEqual(live.loadedProtocolModules.filter(p=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|lightning_emitter|emitter_target|model_reference_assets|model_reference_scene|model_references)\.js$|(?:^|\/)three\//.test(p)),[]);
for(const[file,sha]of Object.entries(live.sourceSha256))assert.equal(hash(await read(file)),sha,'Current normal-entry source '+file);
const capture=await json('reports/native-capture-references-v3.json');assert.equal(capture.success,false);assert.equal(capture.terrain.rendered_tiles,48);
assert.deepEqual(capture.actors.errors,[{model:'it_mscmedp_008',reason:'Original texture unavailable: ait_mscmedp_008'}]);
assert.ok(capture.frame_profile.metrics.native_particle_vertices.mean>20);assert.ok(capture.frame_profile.metrics.native_particle_simulation.mean>20);
const output={success:true,scope:'Scoped native references/lightning CPU/GPU and normal-entry audit; failed dense-room diagnostic retained',reports,gpuSourceSha256:gpu.sourceSha256,normalEntrySourceSha256:live.sourceSha256,publicConnections:0,denseCaptureSuccess:false,performanceAccepted:false,fullVisualMigrationAccepted:false,nativeShutdownFaultResolved:false};
await fs.writeFile(new URL('reports/native-reference-runtime-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,reports:reports.length,fullVisualMigrationAccepted:false,performanceAccepted:false}));
