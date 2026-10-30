// Offline evidence/source audit only; no asset preparation or connections.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=file=>fs.readFile(new URL(file,project));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const json=async file=>JSON.parse(await read(file));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const original=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-particle-chunks-v1.json',import.meta.url)));
assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(original.rows.length,110);assert.equal(original.rows.filter(row=>row.case.operation==='render').length,96);
const reports=[];
for(const[name,count]of [['native-particle-chunks-v3',119],['native-particle-chunks-standard-regression-v2',30]]){
 const result=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const[key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,graphical:true}))assert.equal(proof[key],value,name+' '+key);
 for(const[file,digest]of Object.entries(proof.sourceSha256))assert.equal(sha(await read(file)),digest,'Current native source '+file);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 if(name==='native-particle-chunks-v3'){
  assert.equal(result.original_rows,110);assert.equal(result.runtime.backend,'compiled');assert.equal(result.runtime.frames,120);assert.equal(result.runtime.vertices,0);assert.equal(result.runtime.missing_chunk_models,0);assert.equal(result.runtime.failure,'');assert.equal(result.models_created,2);assert.equal(result.destroyed,2);assert.equal(result.impact_plays,15);assert.equal(result.scene_detaches,13);
 }
 reports.push({run:name,checks:count,sha256:sha(await read('reports/'+name+'.json'))});
}
const failed=await json('reports/native-particle-chunks-v1.json'),failedProof=await json('reports/native-particle-chunks-v1.debugger.json');assert.equal(failed.success,false);assert.equal(failed.failures.length,1);assert.equal(failedProof.engineOrLifetimeError,false);
const name='native-session-particle-chunk-owners-v1',live=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
for(const[key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true}))assert.equal(live[key],value,key);
assert.equal(native.success,true);assert.equal(native.object_visuals_complete,true);assert.equal(native.world.entities,20);assert.equal(native.world.terrain.rendered_tiles,9);assert.deepEqual(native.world.failed_objects,{});assert.deepEqual(native.world.errors,[]);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);
assert.ok(live.firstPlayable.entities<live.firstPlayable.desired&&live.firstPlayable.pendingBatches>0);assert.ok(live.movementWhileStreaming.nativeDistance>.05&&live.movementWhileStreaming.serverDistance>.05&&live.movementWhileStreaming.pendingBatches>0);assert.ok(Math.abs(live.localWalkDistance-live.authoritativeDistance)<.001);
for(const[file,digest]of Object.entries(live.sourceSha256))assert.equal(sha(await read(file)),digest,'Current default launcher '+file);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
assert.ok(!bad.test(String(live.engineErrors)));assert.deepEqual(live.loadedProtocolModules.filter(file=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|model_reference_assets|model_reference_scene)\.js$|(?:^|\/)three\//.test(file)),[]);
reports.push({run:name,sha256:sha(await read('reports/'+name+'.json'))});
const output={success:true,originalRows:110,reports,firstPlayable:live.firstPlayable,liveParticles:{emitters:native.world.native_particles.emitters,failed:native.world.native_particles.failed,simulated:native.world.native_particles.simulated},retainedJsModules:live.loadedProtocolModules.length,publicConnections:0,automaticLiveChunkBindingAccepted:false,fullEffectsAccepted:false,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Bounded original chunk owners with captured lower providers and coupled authored native model/clip GPU services; standard-particle/default-local regressions pass. Automatic world assets/services, nested ownership, full effects/pixels and dense-world FPS remain incomplete.'};
await fs.writeFile(new URL('reports/native-particle-chunks-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(output));
