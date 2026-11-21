// Evidence audit only. No network, renderer, model prep or simulation here.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=p=>fs.readFile(new URL(p,project)),json=async p=>JSON.parse(await read(p));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m,reports=[];
const checkSources=async sources=>{for(const[file,expected]of Object.entries(sources))assert.equal(hash(await read(file)),expected,'Current source '+file);};
for(const[name,count]of [['native-kernel-default-schedule-v1',1907],['native-kernel-default-physics-v1',1262],['native-kernel-default-lightning-v1',5494],['native-kernel-default-vertices-v1',492],['native-kernel-default-moving-v1',18084],['native-kernel-default-particles-gpu-v1',30],['native-kernel-default-reference-gpu-v1',147],['native-kernel-gd-rollback-physics-v1',1262],['native-kernel-gd-rollback-particles-v1',29]]){
 const bytes=await read('reports/'+name+'.json'),r=JSON.parse(bytes),debug=await json('reports/'+name+'.debugger.json');
 assert.equal(r.success,true,name);assert.equal(r.checks,count,name);assert.deepEqual(r.failures,[]);
 for(const k of ['success','normalHeap','armed','sourceUnchanged'])assert.equal(debug[k],true,name+' '+k);
 assert.equal(debug.exceptionTraps,4);assert.equal(debug.exception,false);assert.equal(debug.engineOrLifetimeError,false);await checkSources(debug.sourceSha256);
 for(const suffix of ['.cdb.log','.engine.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 if(r.backend)assert.equal(r.backend,name.includes('gd-rollback')?'gd':'compiled');
 if(name==='native-kernel-default-particles-gpu-v1'){
  assert.equal(debug.graphical,true);assert.ok(!debug.testArguments.some(a=>a.startsWith('--particle-kernel=')));
  for(const model of r.models)for(const emitter of model.emitters)assert.equal(emitter.backend,'compiled');
 }
 if(name==='native-kernel-default-moving-v1'){assert.equal(r.scenarios.length,12);assert.equal(r.scenarios.reduce((sum,v)=>sum+v.frames,0),2160);}
 reports.push({name,checks:count,sha256:hash(bytes),scope:r.scope});
}
const liveName='native-session-kernel-default-v1',live=await json('reports/'+liveName+'.json'),native=await json('reports/'+liveName+'.native.json');
for(const k of ['success','protocolOnly','compiledParticlesRequested','sourceUnchanged','debuggerArmed'])assert.equal(live[k],true,k);
assert.equal(live.renderingPrepared,false);assert.equal(live.nativeException,false);assert.equal(live.nativeExit,0);assert.equal(live.publicConnections,0);assert.equal(live.native.workersRemaining,0);assert.equal(native.protocol_finish_ack,true);
assert.equal(live.native.world.entities,20);assert.equal(live.native.world.terrain.rendered_tiles,9);assert.ok(live.authoritativeDistance>.2&&live.authoritativeDistance<2);assert.ok(Math.abs(live.localWalkDistance-live.authoritativeDistance)<.001);await checkSources(live.sourceSha256);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+liveName+suffix))),liveName+suffix);
assert.deepEqual(live.loadedProtocolModules.filter(p=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|lightning_emitter|emitter_target|model_reference_assets|model_reference_scene|model_references)\.js$|(?:^|\/)three\//.test(p)),[]);
const build=await json('.cache/native-kernel/build-manifest.json');await checkSources(build.sources);assert.equal(hash(await read('.cache/native-kernel/nwn-particle-kernel.dll')),build.binarySha256);assert.equal(build.flags.includes('/fp:strict'),true);
const name='native-capture-kernel-default-v1',capture=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.verification.json'),baseline=await json('reports/native-capture-references-v3.json');
assert.equal(capture.success,false);assert.equal(proof.passed,false);assert.equal(proof.debuggerArmed,true);assert.equal(proof.nativeException,false);assert.equal(proof.sourceUnchanged,true);await checkSources(proof.sourceSha256);
assert.equal(capture.worker_tasks_remaining,0);assert.equal(capture.input_sha256,baseline.input_sha256);assert.equal(capture.terrain.rendered_tiles,48);
assert.deepEqual(capture.actors.errors,[{model:'it_mscmedp_008',reason:'Original texture unavailable: ait_mscmedp_008'}]);assert.equal(capture.native_particles.failed,1182);
assert.ok(capture.frame_intervals.settled.count>=179);assert.equal(capture.frame_intervals.settled.over_50ms,0);
const output={success:true,scope:'Default compiled particle original/authoring/GPU/local-entry and explicit failed-room evidence audit; no full migration/performance acceptance',reports,defaultLocalEntry:liveName,retainedJsModuleCount:live.loadedProtocolModules.length,buildManifestSha256:hash(await read('.cache/native-kernel/build-manifest.json')),defaultCapture:name,defaultCaptureSuccess:false,settledFrameMeanMs:capture.frame_intervals.settled.average_ms,simulationMeanMs:capture.frame_profile.metrics.native_particle_simulation.mean,vertexMeanMs:capture.frame_profile.metrics.native_particle_vertices.mean,publicConnections:0,performanceAccepted:false,fullVisualMigrationAccepted:false,nativeShutdownFaultResolved:false};
await fs.writeFile(new URL('reports/native-particle-simulation-default-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,reports:reports.length,settledFrameMeanMs:output.settledFrameMeanMs,simulationMeanMs:output.simulationMeanMs,performanceAccepted:false}));
