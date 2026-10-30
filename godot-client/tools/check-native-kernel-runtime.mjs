// Offline audit. No simulation, rendering, asset preparation or server access.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=p=>fs.readFile(new URL(p,project)),json=async p=>JSON.parse(await read(p));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m,reports=[];
for(const[name,count]of [['native-kernel-vertices-v3',492],['native-kernel-arithmetic-v2',66],['native-kernel-particles-gpu-v1',30]]){
 const data=await read('reports/'+name+'.json'),r=JSON.parse(data),debug=await json('reports/'+name+'.debugger.json');
 assert.equal(r.success,true,name);assert.equal(r.checks,count,name);assert.deepEqual(r.failures,[]);
 for(const k of ['success','normalHeap','armed','sourceUnchanged'])assert.equal(debug[k],true,name+' '+k);
 assert.equal(debug.exceptionTraps,4);assert.equal(debug.exception,false);assert.equal(debug.engineOrLifetimeError,false);
 for(const suffix of ['.cdb.log','.engine.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 for(const[file,expected]of Object.entries(debug.sourceSha256))assert.equal(hash(await read(file)),expected,'Current kernel fixture source '+file);
 if(name==='native-kernel-vertices-v3')assert.deepEqual(r.originalEvidence.map(x=>x.rows),[245]);
 if(name==='native-kernel-particles-gpu-v1'){assert.equal(debug.graphical,true);assert.ok(debug.testArguments.includes('--particle-kernel=compiled'));assert.ok((await read('reports/'+name+'.png')).length>1000);}
 reports.push({name,checks:count,sha256:hash(data),scope:r.scope});
}
const liveName='native-session-kernel-vertices-v1',live=await json('reports/'+liveName+'.json'),native=await json('reports/'+liveName+'.native.json');
for(const k of ['success','protocolOnly','compiledParticlesRequested','sourceUnchanged','debuggerArmed'])assert.equal(live[k],true,k);
assert.equal(live.renderingPrepared,false);assert.equal(live.nativeException,false);assert.equal(live.nativeExit,0);assert.equal(live.publicConnections,0);assert.equal(live.native.workersRemaining,0);assert.equal(native.protocol_finish_ack,true);
assert.equal(live.native.world.entities,20);assert.equal(live.native.world.terrain.rendered_tiles,9);assert.ok(live.authoritativeDistance>.2&&live.authoritativeDistance<2);assert.ok(Math.abs(live.authoritativeDistance-live.localWalkDistance)<.001);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+liveName+suffix))),liveName+suffix);
for(const[file,expected]of Object.entries(live.sourceSha256))assert.equal(hash(await read(file)),expected,'Current normal entry '+file);
assert.deepEqual(live.loadedProtocolModules.filter(p=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|lightning_emitter|emitter_target|model_reference_assets|model_reference_scene|model_references)\.js$|(?:^|\/)three\//.test(p)),[]);
const build=await json('.cache/native-kernel/build-manifest.json');assert.equal(hash(await read('.cache/native-kernel/nwn-particle-kernel.dll')),build.binarySha256);for(const[file,expected]of Object.entries(build.sources))assert.equal(hash(await read(file)),expected,'Current build input '+file);
const captureName='native-capture-kernel-vertices-v1',capture=await json('reports/'+captureName+'.json'),verification=await json('reports/'+captureName+'.verification.json'),base=await json('reports/native-capture-references-v3.json');
assert.equal(capture.success,false);assert.equal(verification.passed,false);assert.equal(verification.nativeException,false);assert.equal(verification.debuggerArmed,true);assert.equal(verification.sourceUnchanged,true);assert.equal(capture.worker_tasks_remaining,0);assert.equal(capture.input_sha256,base.input_sha256);assert.equal(capture.terrain.rendered_tiles,48);
assert.deepEqual(capture.actors.errors,[{model:'it_mscmedp_008',reason:'Original texture unavailable: ait_mscmedp_008'}]);
// Build/harness metadata changed after this capture. Pin its actual arithmetic
// sources separately; do not relabel its DLL/report as a final-current run.
for(const file of ['native/particle_kernel.cpp','systems/native_render/particle_kernel.gd','systems/native_render/particle_vertices.gd','systems/native_render/particle_emitter.gd'])assert.equal(hash(await read(file)),verification.sourceSha256[file],file+' captured arithmetic');
const output={success:true,scope:'Opt-in compiled vertex kernel original words, GPU fixture, normal local entry and failed-room diagnostics; incomplete native visual migration',reports,normalEntry:liveName,retainedJsModuleCount:live.loadedProtocolModules.length,buildManifestSha256:hash(await read('.cache/native-kernel/build-manifest.json')),compiledVertexMeanMs:capture.frame_profile.metrics.native_particle_vertices.mean,baselineVertexMeanMs:base.frame_profile.metrics.native_particle_vertices.mean,compiledSettledMeanMs:capture.frame_intervals.settled.average_ms,baselineSettledMeanMs:base.frame_intervals.settled.average_ms,captureSuccess:false,captureIsFinalCurrentDll:false,performanceAccepted:false,fullVisualMigrationAccepted:false,nativeShutdownFaultResolved:false,publicConnections:0};
await fs.writeFile(new URL('reports/native-kernel-runtime-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,originalVertexCases:245,compiledVertexMeanMs:output.compiledVertexMeanMs,compiledSettledMeanMs:output.compiledSettledMeanMs,performanceAccepted:false}));
