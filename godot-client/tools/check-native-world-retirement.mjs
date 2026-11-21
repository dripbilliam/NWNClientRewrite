// Offline source/evidence audit only. No connections/render/resource preparation.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=file=>fs.readFile(new URL(file,project));
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const json=async file=>JSON.parse(await read(file));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const checked=[];
for(const[name,count,graphical]of [['native-world-retirement-v2',72,false],['native-visual-failure-retirement-regression-v1',28,false],['native-template-retirement-regression-v1',16,true]]){
 const result=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const[key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,graphical}))assert.equal(proof[key],value,name+' '+key);
 for(const[file,sha]of Object.entries(proof.sourceSha256))assert.equal(hash(await read(file)),sha,'Current native test input '+file);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 if(name==='native-world-retirement-v2'){
  assert.equal(result.cycles.length,6);assert.equal(result.canceled_callbacks,0);assert.equal(result.stale_registry_callbacks,0);
  assert.equal(result.retirement.retired,9);assert.equal(result.retirement.released,9);assert.equal(result.retirement.forced_drains,1);assert.equal(result.retirement.peak_worlds,2);assert.ok(result.retirement.peak_workers>0);assert.equal(result.retirement.pending_worlds,0);assert.equal(result.retirement.pending_workers,0);
 }
 checked.push({run:name,checks:count,sha256:hash(await read('reports/'+name+'.json'))});
}
const names=['native-world-retirement-prelude-v1','native-session-world-retirement-v1'];
const summaries=[];
for(const name of names){
 const result=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
 for(const[key,value]of Object.entries({success:true,protocolOnly:true,publicConnections:0,renderingPrepared:false,sourceUnchanged:true,debuggerArmed:true,nativeException:false}))assert.equal(result[key],value,name+' '+key);
 for(const[file,sha]of Object.entries(result.sourceSha256))assert.equal(hash(await read(file)),sha,'Current launcher input '+file);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 assert.equal(native.success,true);assert.equal(native.playable,true);assert.equal(native.object_visuals_complete,true);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);assert.equal(native.world_retirement.pending_worlds,0);assert.equal(native.world_retirement.pending_workers,0);assert.deepEqual(native.world.failed_objects,{});assert.deepEqual(native.world.errors,[]);
 const modules=Array.isArray(result.loadedProtocolModules)?result.loadedProtocolModules:Object.keys(result.loadedProtocolModules);
 assert.deepEqual(modules.filter(file=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|model_reference_assets|model_reference_scene)\.js$|(?:^|\/)three\//.test(file)),[]);
 if(!Array.isArray(result.loadedProtocolModules))for(const[file,sha]of Object.entries(result.loadedProtocolModules))assert.equal(hash(await fs.readFile(new URL('../'+file,project))),sha,'Current protocol source '+file);
 if(name===names[0]){
  assert.equal(result.debuggerExit,0);assert.equal(result.engineErrors,false);assert.equal(result.performanceAccepted,false);assert.equal(result.admittedAreas.length,2);assert.deepEqual(result.admittedAreas.map(row=>row.generation),[1,2]);assert.equal(result.inventoryProofs.length,2);assert.deepEqual(result.inventoryProofs.map(row=>row.reopen),[false,true]);assert.ok(result.authoritativeClickDistance>.2&&result.authoritativeDriveDistance>.2);
  assert.equal(native.retired_areas.length,1);assert.equal(native.retired_areas[0].entities,20);assert.equal(native.retired_areas[0].terrain.rendered_tiles,9);assert.equal(native.world.entities,92);assert.equal(native.world.terrain.rendered_tiles,100);assert.equal(native.world_retirement.retired,1);assert.equal(native.world_retirement.released,1);assert.equal(native.door_probe.new_area_ready,true);assert.equal(native.interaction_probe.examine_received,true);assert.equal(native.interaction_probe.server_dialog_closed,true);
  assert.ok((await read('reports/'+name+'.native.png')).length>1000);
 }else{
  assert.equal(result.nativeExit,0);assert.ok(!bad.test(String(result.engineErrors)));assert.equal(native.world.entities,20);assert.equal(native.world.terrain.rendered_tiles,9);assert.ok(result.firstPlayable.entities<result.firstPlayable.desired&&result.firstPlayable.pendingBatches>0);assert.ok(result.movementWhileStreaming.nativeDistance>.05&&result.movementWhileStreaming.serverDistance>.05&&result.movementWhileStreaming.pendingBatches>0);assert.ok(Math.abs(result.localWalkDistance-result.authoritativeDistance)<.001);
 }
 checked.push({run:name,sha256:hash(await read('reports/'+name+'.json'))});summaries.push({run:name,retirement:native.world_retirement,particles:{emitters:native.world.native_particles.emitters,failed:native.world.native_particles.failed,simulated:native.world.native_particles.simulated}});
}
const original=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-world-retirement-boundaries-v1.json',import.meta.url)));assert.equal(original.checks.length,5);assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
const initial=await json('reports/native-world-retirement-v1.debugger.json');assert.equal(initial.success,false);assert.equal(initial.engineOrLifetimeError,true);
const output={success:true,originalInstructionChecks:5,reports:checked,summaries,publicConnections:0,fullMigrationAccepted:false,performanceAccepted:false,nativeShutdownFaultResolved:false,scope:'Actual held native workers and subsequent world preparation over six authored cycles/overflow, one real authoritative Prelude transition and actual default local entry. Not the complete original cancel algorithm or repeated real transitions/reconnects, full effects/moving-capture/cold-warm/FPS acceptance.'};
await fs.writeFile(new URL('reports/native-world-retirement-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(output));
