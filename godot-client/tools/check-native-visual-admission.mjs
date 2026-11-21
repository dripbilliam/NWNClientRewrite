// Offline source/evidence audit. No connections, asset preparation or rendering.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=name=>fs.readFile(new URL(name,project));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const json=async name=>JSON.parse(await read(name));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const original=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-world-visual-admission-v1.json',import.meta.url)));
assert.equal(original.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
assert.equal(original.rows.length,54);assert.equal(original.rows.filter(row=>row.attempted).length,42);
const nullRows=original.rows.filter(row=>row.attempted&&!row.case.loaded);assert.equal(nullRows.length,21);
for(const row of nullRows){assert.equal(row.result,false);assert.equal(row.modelSlot,0);assert.equal(row.resref,'previous_model');assert.equal(row.field44,123);assert.equal(row.calls.length,1);}
const reports=[];
for(const [name,count,graphical]of [['native-visual-failure-v4',28,false],['native-static-pose-failure-regression-v2',8,false],['native-template-failure-regression-v2',16,true]]){
 const report=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
 assert.equal(report.success,true);assert.equal(report.checks,count);assert.deepEqual(report.failures,[]);
 for(const [key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,graphical}))assert.equal(proof[key],value,name+' '+key);
 for(const[file,digest]of Object.entries(proof.sourceSha256))assert.equal(sha(await read(file)),digest,'Current native source '+file);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
 if(name==='native-visual-failure-v4'){
  assert.equal(report.streams.length,4);assert.equal(report.streams[0].rendered,1);assert.equal(report.streams[0].errors.length,2);assert.deepEqual(report.streams[0].scope_errors,[]);assert.deepEqual(Object.keys(report.streams[0].object_failures).sort(),['2','4']);
  assert.equal(report.streams[1].rendered,1);assert.deepEqual(report.streams[1].errors,[]);
  assert.equal(report.streams[2].rendered,0);assert.equal(report.streams[2].errors.length,1);
  assert.equal(report.streams[3].scope_errors.length,1);
 }
 reports.push({run:name,checks:count,sha256:sha(await read('reports/'+name+'.json'))});
}
const first=await json('reports/native-visual-failure-v1.debugger.json');assert.equal(first.success,false);assert.equal(first.engineOrLifetimeError,true);
const name='native-session-visual-failure-v3',live=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
for(const[key,value]of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true}))assert.equal(live[key],value,key);
assert.equal(native.success,true);assert.equal(native.playable,true);assert.equal(native.object_visuals_complete,true);assert.equal(native.world.object_visuals_complete,true);assert.deepEqual(native.world.failed_objects,{});assert.deepEqual(native.world.errors,[]);
assert.equal(native.world.entities,20);assert.equal(native.world.desired,20);assert.equal(native.world.terrain.rendered_tiles,9);assert.equal(native.world.pending_batches,0);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);
assert.ok(live.firstPlayable.entities<live.firstPlayable.desired&&live.firstPlayable.pendingBatches>0);
assert.ok(live.movementWhileStreaming.nativeDistance>.05&&live.movementWhileStreaming.serverDistance>.05&&live.movementWhileStreaming.entities<live.movementWhileStreaming.desired&&live.movementWhileStreaming.pendingBatches>0);
assert.ok(live.localWalkDistance>.2&&live.localWalkDistance<2&&Math.abs(live.localWalkDistance-live.authoritativeDistance)<.001);
assert.ok(!bad.test(String(live.engineErrors)));
for(const[file,digest]of Object.entries(live.sourceSha256))assert.equal(sha(await read(file)),digest,'Current default entry '+file);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+name+suffix))),name+suffix);
assert.deepEqual(live.loadedProtocolModules.filter(file=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|model_reference_assets|model_reference_scene)\.js$|(?:^|\/)three\//.test(file)),[]);
reports.push({run:name,sha256:sha(await read('reports/'+name+'.json'))});
const output={success:true,originalCases:54,nullModelCases:21,reports,firstPlayable:live.firstPlayable,movementWhileStreaming:live.movementWhileStreaming,retainedJsModules:live.loadedProtocolModules.length,particleDiagnostics:native.world.native_particles,publicConnections:0,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Complete original bounded visual loaders with explicit lower providers, actual authored native workers/admission and warm default local control/cleanup. Effects/full moving-world/cancellation/cold-warm/FPS acceptance incomplete.'};
await fs.writeFile(new URL('reports/native-visual-admission-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...output,particleDiagnostics:{...output.particleDiagnostics,diagnostics:undefined}}));
