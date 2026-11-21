// Offline source/evidence audit. No connections, rendering or asset preparation.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=file=>fs.readFile(new URL(file,project));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const json=async file=>JSON.parse(await read(file));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const checked=[];
for(const[name,count,graphical]of [['native-chunk-binding-v4',31,true],['native-world-publication-v3',10,true],['native-chunk-binding-final-owners-v1',119,true],['native-chunk-binding-final-references-v1',147,true],['native-chunk-binding-final-retirement-v1',72,false],['native-chunk-binding-final-templates-v1',16,true]]){
 const result=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const[key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,graphical}))assert.equal(proof[key],value,name+' '+key);
 for(const[file,digest]of Object.entries(proof.sourceSha256))assert.equal(sha(await read(file)),digest,'Current native source '+file);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 if(name==='native-chunk-binding-v4'){
  assert.equal(result.emitters.length,2);for(const e of result.emitters){assert.equal(e.failure,'');assert.equal(e.frames,96);assert.equal(e.vertices,0);assert.equal(e.chunks.created,2);assert.equal(e.chunks.impact_requests,12);assert.equal(e.chunks.detached,10);}
  assert.equal(result.hub.jobs,3);assert.equal(result.hub.failed,1);assert.equal(result.hub.workers,0);assert.equal(result.hub.pending,0);assert.equal(result.actor_chunks.ready,true);assert.equal(result.actor_chunks.created,1);assert.equal(result.delayed.jobs,1);assert.equal(result.delayed.bundles_published,1);assert.equal(result.delayed.requested,2);assert.equal(result.delayed.workers,0);
 }
 if(name==='native-world-publication-v3'){
  for(const e of result.after_admission){assert.equal(e.failure,'');assert.ok(e.frames>0&&e.allocated>0&&e.chunks.created>0);}
  assert.equal(result.hub.jobs,2);assert.equal(result.hub.chunk_models,2);assert.equal(result.hub.published,2);assert.deepEqual(result.hub.errors,[]);
 }
 checked.push({run:name,checks:count,sha256:sha(await read('reports/'+name+'.json'))});
}
const old=await json('reports/native-world-publication-v1.json');assert.equal(old.success,false);assert.equal(old.failures.length,1);
const modelOracle=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-world-model-cache-v1.json',import.meta.url)));
assert.equal(modelOracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
const nulls=modelOracle.rows.filter(row=>typeof row.case.name==='string'&&row.case.name.toLowerCase()==='null');assert.ok(nulls.some(row=>row.case.name==='null')&&nulls.some(row=>row.case.name==='NULL'));for(const row of nulls){assert.equal(row.model,false);assert.deepEqual(row.calls,[]);}
const name='native-session-chunk-binding-v3',live=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
for(const[key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true}))assert.equal(live[key],value,key);
assert.equal(native.success,true);assert.equal(native.object_visuals_complete,true);assert.equal(native.world.entities,20);assert.equal(native.world.terrain.rendered_tiles,9);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);assert.deepEqual(native.world.errors,[]);assert.deepEqual(native.world.failed_objects,{});assert.deepEqual(native.world.native_references.errors,[]);assert.ok(native.world.native_particles.simulated>0);
assert.ok(live.firstPlayable.entities<live.firstPlayable.desired&&live.firstPlayable.pendingBatches>0);assert.ok(live.movementWhileStreaming.nativeDistance>.05&&live.movementWhileStreaming.serverDistance>.05&&live.movementWhileStreaming.pendingBatches>0);assert.ok(Math.abs(live.localWalkDistance-live.authoritativeDistance)<.001);
for(const[file,digest]of Object.entries(live.sourceSha256))assert.equal(sha(await read(file)),digest,'Current default entry '+file);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
assert.ok(!bad.test(String(live.engineErrors)));assert.deepEqual(live.loadedProtocolModules.filter(file=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|model_reference_assets|model_reference_scene)\.js$|(?:^|\/)three\//.test(file)),[]);
checked.push({run:name,sha256:sha(await read('reports/'+name+'.json'))});
const captureName='native-capture-chunk-binding-v2',capture=await json('reports/'+captureName+'.json'),proof=await json('reports/'+captureName+'.verification.json');
for(const[key,value]of Object.entries({passed:true,debugHeapDisabled:true,debuggerArmed:true,nativeException:false,sourceUnchanged:true,cleanBenchmark:false}))assert.equal(proof[key],value,key);
assert.deepEqual(proof.failures,[]);assert.equal(capture.success,true);assert.equal(capture.worker_tasks_remaining,0);assert.equal(capture.input_sha256,'6bb657a6fd30d1e9e1a186e6c53c4d33f9494205e1383c5d582d308eb6d23243');assert.equal(capture.terrain.rendered_tiles,48);assert.equal(capture.objects.rendered,889);assert.equal(capture.actors.rendered_creatures,8);assert.equal(capture.actors.rendered_items,1);assert.equal(capture.native_particles.emitters,1351);assert.equal(capture.native_particles.failed,1182);assert.equal(capture.references.jobs,0);assert.ok(capture.native_particles.active>0);assert.ok(capture.character_animation.some(row=>row.delta.advanced_model_clocks>0&&row.delta.maximum_local_skin_vertex_delta>0));
for(const[file,digest]of Object.entries(proof.sourceSha256))assert.equal(sha(await read(file)),digest,'Current capture source '+file);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+captureName+suffix))),captureName+suffix);
assert.ok((await read('reports/'+captureName+'.png')).length>1000);checked.push({run:captureName,sha256:sha(await read('reports/'+captureName+'.json'))});
const output={success:true,reports:checked,firstPlayable:live.firstPlayable,liveParticles:{emitters:native.world.native_particles.emitters,simulated:native.world.native_particles.simulated,failed:native.world.native_particles.failed},captureParticles:capture.native_particles,captureFrames:capture.frame_intervals,publicConnections:0,automaticNativeChunkBindingVerified:true,completeLiveEffectsAccepted:false,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Production native chunk asset binding and actual static/actor admission lifetime fix, original owner/NULL boundaries, authored GPU/cancel/readiness checks, actual default local movement and compatible original captured snapshot with native animation. Complete scene physics, repeated transitions/full moving replay and clean dense-world FPS remain unaccepted.'};
await fs.writeFile(new URL('reports/native-chunk-binding-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...output,captureParticles:{...output.captureParticles,diagnostics:undefined}}));
