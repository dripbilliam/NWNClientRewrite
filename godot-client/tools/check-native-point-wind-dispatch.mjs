// Offline audit of partial native point-wind integration and dispatch work.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=f=>fs.readFile(new URL(f,project));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),json=async f=>JSON.parse(await read(f));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m,checked=[];
async function pins(map){for(const [file,digest]of Object.entries(map))assert.equal(sha(await read(file)),digest,'Current input '+file);}
async function logs(name){for(const ext of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+ext))),name+ext);}
for(const [suffix,count,gpu]of [['fused',13796,false],['parameters',602,false],['channels',50,false],['wind',387,true],['schedule',1907,false],['vertices',492,false],['chunks',119,true],['retirement',72,false],['publication',10,true],['particles',30,true]]){
 const name='native-point-final-'+suffix+'-v1',result=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const [key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,graphical:gpu}))assert.equal(proof[key],value,name+' '+key);
 await pins(proof.sourceSha256);await logs(name);checked.push({run:name,checks:count,sha256:sha(await read('reports/'+name+'.json'))});
}
const original=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-point-wind-observations.json',import.meta.url)));
assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(original.queries.length,189);assert.equal(original.adds.length,126);assert.equal(original.advances.length,60);
const name='native-session-point-final-v1',live=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
for(const [key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true,requestedLocalCycles:3,localStreamAbortRequested:true}))assert.equal(live[key],value,key);
await pins(live.sourceSha256);await logs(name);assert.equal(native.success,true);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);assert.equal(native.stale_session_messages,12);assert.equal(live.retiredCommands.length,12);
assert.equal(live.localAbortedCycles.length,1);assert.equal(live.localCycles.length,3);assert.ok(native.session_disconnect_probes[0].unfinished_workers>0);assert.equal(new Set([...live.localAbortedCycles,...live.localCycles].map(r=>r.nativeProcessId)).size,1);
for(const row of live.localCycles){assert.equal(row.state.entities,20);assert.equal(row.state.terrain.rendered_tiles,9);assert.equal(row.state.object_visuals_complete,true);assert.deepEqual(row.state.errors,[]);assert.equal(row.state.native_particles.failed,32);assert.equal(row.state.native_particles.simulated,25);assert.equal(row.state.native_particles.fused_simulated,25);assert.equal(row.state.native_point_wind.failure,'');assert.ok(row.state.native_point_wind.frames>0);assert.ok(Math.abs(row.nativeDistance-row.serverDistance)<.001&&row.serverDistance>.2);}
assert.equal(native.world_retirement.retired,3);assert.equal(native.world_retirement.released,3);assert.equal(native.world_retirement.pending_workers,0);assert.ok(Object.values(native.render_cache_after_release.retained).every(n=>n===0));
assert.ok(!live.loadedProtocolModules.some(f=>/(?:^|\/)(?:point_wind|particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene)\.js$|(?:^|\/)three\//.test(f)));checked.push({run:name,sha256:sha(await read('reports/'+name+'.json'))});
const captures=[];
for(const mode of ['default','composed']){
 const run='native-capture-point-final-'+mode+'-v1',result=await json('reports/'+run+'.json'),proof=await json('reports/'+run+'.verification.json');
 for(const [key,value]of Object.entries({passed:true,debugHeapDisabled:true,debuggerArmed:true,nativeException:false,sourceUnchanged:true,cleanBenchmark:false}))assert.equal(proof[key],value,run+' '+key);
 await pins(proof.sourceSha256);await logs(run);assert.equal(result.success,true);assert.equal(result.worker_tasks_remaining,0);assert.equal(result.input_sha256,'6bb657a6fd30d1e9e1a186e6c53c4d33f9494205e1383c5d582d308eb6d23243');assert.equal(result.terrain.rendered_tiles,48);assert.equal(result.objects.rendered,889);assert.equal(result.actors.rendered_creatures,8);assert.equal(result.actors.rendered_items,1);
 assert.equal(result.native_particles.emitters,1351);assert.equal(result.native_particles.failed,710);assert.deepEqual(result.native_particles.diagnostics,{'Native particle scene intersection is pending':596,'Native scene wind sampling is pending':10,'Original particle bitmap unavailable: fxpa_cloud02':104});
 assert.equal(result.native_particles.fused_simulated,mode==='default'?641:0);assert.equal(result.native_particles.composed_simulated,mode==='composed'?641:0);assert.equal(result.native_particles.gd_parameter_simulated,641);assert.equal(result.native_particles.native_parameter_simulated,0);assert.ok(result.native_particles.constant_channel_hits>0);assert.equal(result.native_point_wind.failure,'');assert.equal(result.native_point_wind.added,0);
 assert.ok(result.character_animation.some(r=>r.delta.advanced_model_clocks>0&&r.delta.maximum_local_skin_vertex_delta>0));assert.ok((await read('reports/'+run+'.png')).length>1000);
 captures.push({run,settled:result.frame_intervals.settled,simulation:result.frame_profile.metrics.native_particle_simulation,channelsPose:result.frame_profile.metrics.native_particle_channels_pose});checked.push({run,sha256:sha(await read('reports/'+run+'.json'))});
}
const result={success:true,reports:checked,originalPointCases:375,liveFailureReduction:{previous:49,current:32},capturedFailureReduction:{previous:1182,current:710},captures,publicConnections:0,nativePointListAndExplosionBindingVerified:true,fusedFrameStateVerified:true,completeWindManagerAccepted:false,completeEffectsAccepted:false,cleanBenchmark:false,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Point-list original arithmetic plus actual scene registration/retirement; authored blast sources, original/coupled/GPU regressions, default local reconnect/stream-abort and compatible animated captured snapshots. No sources detonate in actual room checks; ambient/collision/bitmap/event gaps remain. Small dispatch timing difference is not full-scene FPS acceptance.'};
await fs.writeFile(new URL('reports/native-point-wind-dispatch-v1.verified.json',project),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...result,reports:result.reports.map(r=>({run:r.run,checks:r.checks}))}));
