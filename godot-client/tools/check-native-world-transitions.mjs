// Offline acceptance of the scoped real-server transition stress probe.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=f=>fs.readFile(new URL(f,project));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const json=async f=>JSON.parse(await read(f));
const name='native-prelude-three-transitions-v3',report=await json('reports/'+name+'.json');
for(const [key,value] of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,debuggerExit:0,debuggerArmed:true,nativeException:false,engineErrors:false,sourceUnchanged:true,requestedTransitions:3,completedTransitions:3,nativeFinished:true,nativeUiReady:true}))assert.equal(report[key],value,key);
for(const file of ['tests/native_world_transitions_test.gd','native/particle_kernel.cpp','native/particle_simulation.hpp','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','tools/test-native-local-world.ps1'])assert.ok(report.sourceSha256[file],'Required pinned input '+file);
for(const [file,digest] of Object.entries(report.sourceSha256))assert.equal(sha(await read(file)),digest,'Current source/DLL '+file);
const native=report.native;
assert.equal(native.success,true);assert.equal(native.object_visuals_complete,true);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);
assert.equal(report.admittedAreas.length,4);assert.deepEqual(report.admittedAreas.map(r=>r.generation),[1,2,3,4]);assert.equal(new Set(report.admittedAreas.map(r=>r.id)).size,2);
assert.equal(native.door_probes.length,3);
for(const [index,row] of native.door_probes.entries()){
 assert.equal(row.previous_generation,index+1);assert.equal(row.generation,index+2);assert.notEqual(row.previous_area,row.area);assert.equal(row.previous_area,report.admittedAreas[index].id);assert.equal(row.area,report.admittedAreas[index+1].id);
 assert.equal(row.new_area_ready,true);assert.equal(row.object_visuals_complete,true);assert.equal(row.entities,row.desired);assert.equal(row.entities,index===1?20:92);assert.equal(row.tiles,index===1?9:100);assert.deepEqual(row.errors,[]);assert.deepEqual(row.failed_objects,{});
 assert.equal(row.retirement.retired,index+1);assert.equal(row.retirement.released,index+1);assert.equal(row.retirement.pending_workers,0);assert.equal(row.retirement.pending_worlds,0);assert.equal(row.retirement.forced_drains,0);
}
assert.equal(native.world_retirement.retired,3);assert.equal(native.world_retirement.released,3);assert.equal(native.world_retirement.pending_workers,0);assert.equal(native.world_retirement.pending_worlds,0);
assert.ok(native.inventory_probe.visible_pixels>0&&native.inventory_reopen_probe.visible_pixels>0);assert.equal(report.inventoryProofs.at(-1).generation,4);assert.equal(report.inventoryProofs.at(-1).reopen,true);assert.equal(native.keyboard_probe.released,true);assert.equal(native.interaction_probe.server_dialog_closed,true);assert.equal(native.camera.valid,true);
assert.ok(report.authoritativeClickDistance>.2&&report.authoritativeClickDistance<2);assert.ok(report.authoritativeDriveDistance>.2);assert.ok(report.keyboardOperations.includes('stop'));
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m.test(String(await read('reports/'+name+suffix))),suffix);
assert.ok((await read('reports/'+name+'.native.png')).length>1000);
assert.deepEqual(Object.keys(report.loadedProtocolModules).filter(f=>/(?:^|\/)(?:model_parser|prepared_model_geometry|network_scene|model_particles|particle_[^/]+)\.js$|(?:^|\/)three\//.test(f)),[]);
const early=await json('reports/native-prelude-three-transitions-v2.json');assert.equal(early.success,false);assert.equal(early.native.failure,'Repeated original-server transition did not render its admitted objects');assert.equal(early.native.door_probes[0].new_area_ready,true);assert.equal(early.native.door_probes[0].object_visuals_complete,false);assert.equal(early.native.door_probes[0].entities,1);assert.equal(early.native.door_probes[0].desired,92);assert.deepEqual(early.native.door_probes[0].errors,[]);assert.deepEqual(early.native.door_probes[0].failed_objects,{});
const result={success:true,run:name,reportSha256:sha(await read('reports/'+name+'.json')),areas:report.admittedAreas,transitions:native.door_probes,retirement:native.world_retirement,publicConnections:0,repeatedPreludeDoorTransitionsVerified:true,reconnectAccepted:false,fullEffectsAccepted:false,cleanColdWarmComparison:false,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Three real authoritative door transitions between two Prelude areas in one native client, complete object admission per leg, real UI/input/equipment and final inventory reopening, source/DLL/debugger guards. Existing server/cache state, editor preserved; no blocked workers in these actual transitions, no full effects/reconnect/whole-campaign/FPS acceptance.'};
await fs.writeFile(new URL('reports/native-world-transitions-v1.verified.json',project),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,areas:result.areas,transitionMs:result.transitions.map(r=>r.elapsed_ms),retirement:result.retirement,publicConnections:0,performanceAccepted:false}));
