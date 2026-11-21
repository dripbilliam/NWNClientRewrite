// Offline source/evidence audit of native immutable session render caching.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=f=>fs.readFile(new URL(f,project));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),json=async f=>JSON.parse(await read(f));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const checked=[];
async function pins(map){for(const [file,digest]of Object.entries(map))assert.equal(sha(await read(file)),digest,'Current input '+file);}
async function logs(name){for(const ext of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+ext))),name+ext);}
for(const [name,count,gpu]of [['native-session-render-cache-v3',18,true],['native-shared-cache-templates-v1',16,true],['native-shared-cache-publication-v1',10,true],['native-shared-cache-chunks-v1',119,true],['native-shared-cache-retirement-v1',72,false],['native-shared-cache-references-v1',147,true]]){
 const result=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const [key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,graphical:gpu}))assert.equal(proof[key],value,name+' '+key);
 await pins(proof.sourceSha256);await logs(name);checked.push({run:name,checks:count,sha256:sha(await read('reports/'+name+'.json'))});
}
const original=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-model-search-release-v1.json',import.meta.url)));
assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(original.search.length,42);assert.equal(original.release.length,7);
for(const row of original.release){assert.equal(row.remaining,row.case.count-1);assert.deepEqual(row.calls,row.case.count===1?[['delete',true]]:[]);}
const name='native-shared-cache-three-transitions-v1',live=await json('reports/'+name+'.json'),native=live.native;
for(const [key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,debuggerExit:0,debuggerArmed:true,nativeException:false,engineErrors:false,sourceUnchanged:true,requestedTransitions:3,completedTransitions:3,nativeFinished:true,nativeUiReady:true}))assert.equal(live[key],value,key);
await pins(live.sourceSha256);await logs(name);
assert.equal(native.success,true);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);assert.equal(native.world.owns_pool,false);assert.equal(native.door_probes.length,3);assert.deepEqual(live.admittedAreas.map(r=>r.generation),[1,2,3,4]);
const initial=native.door_probes[0].render_cache;
for(const [i,row]of native.door_probes.entries()){
 assert.equal(row.previous_generation,i+1);assert.equal(row.generation,i+2);assert.equal(row.new_area_ready,true);assert.equal(row.object_visuals_complete,true);assert.equal(row.entities,i===1?20:92);assert.equal(row.entities,row.desired);assert.equal(row.tiles,i===1?9:100);assert.deepEqual(row.errors,[]);assert.deepEqual(row.failed_objects,{});
 for(const field of ['meshes_created','textures_created','materials_created','templates_created'])assert.equal(row.render_cache[field],initial[field],'Returning areas rebuild no pooled resources: '+field);
 for(const field of ['mesh_evictions','material_evictions','texture_evictions','template_evictions'])assert.equal(row.render_cache[field],0);
 if(i>0){assert.ok(row.render_cache.template_hits>native.door_probes[i-1].render_cache.template_hits);assert.ok(row.render_cache.mesh_hits>native.door_probes[i-1].render_cache.mesh_hits);}
}
assert.equal(native.render_cache_before_release.templates_created,77);assert.equal(native.render_cache_before_release.meshes_created,1253);assert.ok(Object.values(native.render_cache_after_release.retained).every(n=>n===0));
assert.equal(native.world_retirement.retired,3);assert.equal(native.world_retirement.released,3);assert.equal(native.world_retirement.pending_workers,0);assert.equal(native.world_retirement.pending_worlds,0);assert.equal(native.inventory_reopen_probe.visible_pixels>0,true);assert.equal(live.inventoryProofs.at(-1).generation,4);assert.equal(native.keyboard_probe.released,true);assert.equal(native.interaction_probe.server_dialog_closed,true);assert.equal(native.camera.valid,true);
assert.ok(!Object.keys(live.loadedProtocolModules).some(f=>/(?:^|\/)(?:model_parser|prepared_model_geometry|network_scene|particle_[^/]+)\.js$|(?:^|\/)three\//.test(f)));checked.push({run:name,sha256:sha(await read('reports/'+name+'.json'))});
const entryName='native-session-shared-cache-v1',entry=await json('reports/'+entryName+'.json'),entryNative=await json('reports/'+entryName+'.native.json');
for(const [key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true}))assert.equal(entry[key],value,key);
await pins(entry.sourceSha256);await logs(entryName);assert.equal(entryNative.success,true);assert.equal(entryNative.object_visuals_complete,true);assert.equal(entryNative.workers_remaining,0);assert.equal(entryNative.protocol_finish_ack,true);assert.equal(entryNative.world.entities,20);assert.equal(entryNative.world.terrain.rendered_tiles,9);assert.equal(entryNative.world.owns_pool,false);assert.equal(entryNative.world.native_particles.failed,49);assert.deepEqual(entryNative.world.errors,[]);assert.deepEqual(entryNative.world.failed_objects,{});assert.ok(Object.values(entryNative.render_cache_after_release.retained).every(n=>n===0));
assert.ok(entry.firstPlayable.entities<entry.firstPlayable.desired&&entry.firstPlayable.pendingBatches>0);assert.ok(entry.movementWhileStreaming.serverDistance>.05&&entry.movementWhileStreaming.nativeDistance>.05&&entry.movementWhileStreaming.pendingBatches>0);assert.ok(Math.abs(entry.localWalkDistance-entry.authoritativeDistance)<.001);checked.push({run:entryName,sha256:sha(await read('reports/'+entryName+'.json'))});
const captureName='native-capture-shared-cache-v1',capture=await json('reports/'+captureName+'.json'),proof=await json('reports/'+captureName+'.verification.json');
for(const [key,value]of Object.entries({passed:true,debugHeapDisabled:true,debuggerArmed:true,nativeException:false,sourceUnchanged:true,cleanBenchmark:false}))assert.equal(proof[key],value,key);
await pins(proof.sourceSha256);await logs(captureName);assert.equal(capture.success,true);assert.equal(capture.worker_tasks_remaining,0);assert.equal(capture.input_sha256,'6bb657a6fd30d1e9e1a186e6c53c4d33f9494205e1383c5d582d308eb6d23243');assert.equal(capture.terrain.rendered_tiles,48);assert.equal(capture.objects.rendered,889);assert.equal(capture.actors.rendered_creatures,8);assert.equal(capture.actors.rendered_items,1);assert.equal(capture.native_particles.failed,1182);assert.ok(capture.character_animation.some(r=>r.delta.advanced_model_clocks>0&&r.delta.maximum_local_skin_vertex_delta>0));
const previous=await json('reports/native-capture-spawn-words-v1.json');for(const field of ['meshes_created','materials_created','textures_created','templates_created'])assert.equal(capture.resources[field],previous.resources[field]);
assert.ok((await read('reports/'+captureName+'.png')).length>1000);checked.push({run:captureName,sha256:sha(await read('reports/'+captureName+'.json'))});
const output={success:true,reports:checked,originalSearchCases:42,originalReleaseCases:7,cacheAfterTwoAreas:initial,transitionMs:native.door_probes.map(r=>r.elapsed_ms),firstPlayable:entry.firstPlayable,captureIntervals:capture.frame_intervals,publicConnections:0,pooledResourcesRebuiltOnReturn:0,exactOriginalEvictionAccepted:false,reconnectAccepted:false,fullEffectsAccepted:false,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Bounded native immutable resource/template retention across worlds, private effect state and picking identities, actual default Prelude and three authoritative transitions, captured final snapshot with native animation. Count-bound cache policy is a Godot adaptation, not exact original eviction. No clean speedup/FPS, full effects/reconnect or global-fault acceptance.'};
await fs.writeFile(new URL('reports/native-session-render-cache-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...output,reports:output.reports.map(r=>({run:r.run,checks:r.checks}))}));
