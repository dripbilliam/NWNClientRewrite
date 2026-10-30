// Offline evidence audit; no game/network operation.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=f=>fs.readFile(new URL(f,project));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),json=async f=>JSON.parse(await read(f));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m,reports=[];
async function pins(map){for(const [name,digest]of Object.entries(map))assert.equal(sha(await read(name)),digest,'Current source '+name);}
async function logs(run){for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+run+suffix))),run+suffix);}
for(const [run,count,gpu]of [['native-admission-final-v2',346,true],['native-admission-fused-v2',13796,false],['native-admission-particles-v2',30,true]]){
 const result=await json('reports/'+run+'.json'),proof=await json('reports/'+run+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const [key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,graphical:gpu}))assert.equal(proof[key],value,run+' '+key);
 await pins(proof.sourceSha256);await logs(run);reports.push({run,checks:count,sha256:sha(await read('reports/'+run+'.json'))});
}
const corpusBytes=await fs.readFile(new URL('../../backups/animations/native-emitter-admission-observations-v2.json',import.meta.url)),corpus=JSON.parse(corpusBytes);
assert.equal(sha(corpusBytes),'8d402f8d25ba955c2ae45e042703f2f42b17f4faabd1cdaf26f35b36e5ea228c');
assert.equal(corpus.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
assert.equal(corpus.radii.length,105);assert.equal(corpus.spheres.length,48);assert.equal(corpus.admissions.length,60);assert.ok(corpus.admissions.every(r=>r.identity_valid));
const admission=await json('reports/native-admission-final-v2.json');assert.equal(admission.original_sha256,sha(corpusBytes));assert.ok(admission.metrics.culled_frames>0);
const captures=[];
for(const [mode,simulated,culled]of [['fast',542,99],['unculled',641,0]]){
 const run='native-capture-admission-'+mode+'-v1',result=await json('reports/'+run+'.json'),proof=await json('reports/'+run+'.verification.json');
 for(const [key,value]of Object.entries({passed:true,debugHeapDisabled:true,debuggerArmed:true,nativeException:false,sourceUnchanged:true,cleanBenchmark:false}))assert.equal(proof[key],value,run+' '+key);
 await pins(proof.sourceSha256);await logs(run);
 assert.equal(result.success,true);assert.equal(result.worker_tasks_remaining,0);assert.equal(result.input_sha256,'6bb657a6fd30d1e9e1a186e6c53c4d33f9494205e1383c5d582d308eb6d23243');
 assert.equal(result.terrain.rendered_tiles,48);assert.equal(result.objects.rendered,889);assert.equal(result.actors.rendered_creatures,8);assert.equal(result.actors.rendered_items,1);
 const p=result.native_particles;assert.equal(p.emitters,1351);assert.equal(p.failed,710);assert.equal(p.fused_simulated,simulated);assert.equal(p.currently_culled,culled);assert.equal(p.culled_emitters,culled);
 assert.deepEqual(p.diagnostics,{'Native particle scene intersection is pending':596,'Native scene wind sampling is pending':10,'Original particle bitmap unavailable: fxpa_cloud02':104});assert.deepEqual(p.classification_counts,{'0':5,'2':20,'4':1323,'8':3});
 assert.ok(result.character_animation.some(r=>r.delta.advanced_model_clocks>0&&r.delta.maximum_local_skin_vertex_delta>0));assert.ok((await read('reports/'+run+'.png')).length>1000);
 assert.equal(result.frame_intervals.settled.count,179);assert.equal(result.frame_intervals.settled.over_50ms,0);
 captures.push({run,settled:result.frame_intervals.settled,admission:result.frame_profile.metrics.native_particle_admission,simulation:result.frame_profile.metrics.native_particle_simulation,channelsPose:result.frame_profile.metrics.native_particle_channels_pose});reports.push({run,sha256:sha(await read('reports/'+run+'.json'))});
}
const run='native-session-admission-v1',live=await json('reports/'+run+'.json'),native=await json('reports/'+run+'.native.json');
for(const [key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true,requestedLocalCycles:3,localStreamAbortRequested:true}))assert.equal(live[key],value,key);
await pins(live.sourceSha256);await logs(run);assert.equal(native.success,true);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);assert.equal(native.stale_session_messages,12);assert.equal(live.retiredCommands.length,12);
assert.equal(live.localAbortedCycles.length,1);assert.equal(live.localCycles.length,3);assert.ok(native.session_disconnect_probes[0].unfinished_workers>0);assert.equal(new Set([...live.localAbortedCycles,...live.localCycles].map(r=>r.nativeProcessId)).size,1);
for(const row of live.localCycles){assert.equal(row.state.entities,20);assert.equal(row.state.terrain.rendered_tiles,9);assert.equal(row.state.object_visuals_complete,true);assert.deepEqual(row.state.errors,[]);assert.equal(row.state.native_particles.simulated,25);assert.equal(row.state.native_particles.failed,32);assert.ok(row.state.native_particles.culling_checks>0);assert.ok(Math.abs(row.nativeDistance-row.serverDistance)<.001&&row.serverDistance>.2);}
assert.equal(native.world_retirement.retired,3);assert.equal(native.world_retirement.released,3);assert.equal(native.world_retirement.pending_workers,0);assert.ok(Object.values(native.render_cache_after_release.retained).every(n=>n===0));
assert.ok(!live.loadedProtocolModules.some(f=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene)\.js$|(?:^|\/)three\//.test(f)));
reports.push({run,sha256:sha(await read('reports/'+run+'.json'))});
const result={success:true,reports,captures,originalCases:213,publicConnections:0,originalRadiusAndCallbackVerified:true,conservativeNativeAdmissionVerified:true,fullBspCameraParityAccepted:false,completeEffectsAccepted:false,fullMovingReplayAccepted:false,cleanBenchmark:false,performanceAccepted:false,nativeShutdownFaultResolved:false,fullMigrationAccepted:false,scope:'Original frame-admission evidence with exact arithmetic, conservative native GPU re-entry, current source pins, compatible animated snapshots and actual default local stream-abort/reconnect ownership. Small uncontrolled timing gain, incomplete effects and remaining protocol JS; full goal not achieved.'};
await fs.writeFile(new URL('reports/native-particle-admission-v1.verified.json',project),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,originalCases:213,reports:reports.map(r=>({run:r.run,checks:r.checks})),performanceAccepted:false,publicConnections:0}));
