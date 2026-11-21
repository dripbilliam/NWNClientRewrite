// Offline audit of the scoped dword adapter correction; no network or rendering.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=f=>fs.readFile(new URL(f,project));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const json=async f=>JSON.parse(await read(f));
const clean=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const checked=[];
for(const [name,count] of [['native-spawn-words-v1',2140],['native-spawn-words-simulation-v1',18084],['native-spawn-words-vertices-v1',492]]){
 const result=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 for(const [key,value] of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true,publicConnections:0}))assert.equal(proof[key],value,name+' '+key);
 for(const [file,digest] of Object.entries(proof.sourceSha256))assert.equal(sha(await read(file)),digest,'Current native source '+file);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!clean.test(String(await read('reports/'+name+suffix))),name+suffix);
 checked.push({run:name,checks:count,sha256:sha(await read('reports/'+name+'.json'))});
}
const oracle=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-fountain-spawn-words-v1.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,224);
assert.deepEqual([...new Set(oracle.rows.map(r=>r.case.spawnType))].sort((a,b)=>a-b),[-2147483648,-1,0,1,2147483647,2147483648,4294967295]);
for(const row of oracle.rows.filter(r=>r.case.spawnType===4294967295)){
 const expected=oracle.rows.find(r=>r.case.spawnType===-1&&JSON.stringify({...r.case,spawnType:-1})===JSON.stringify({...row.case,spawnType:-1}));
 assert.ok(expected);assert.deepEqual({...row,case:null},{...expected,case:null},'Original signed/unsigned spellings preserve the same trace');
}
const name='native-session-spawn-words-v1',live=await json('reports/'+name+'.json'),native=await json('reports/'+name+'.native.json');
for(const [key,value] of Object.entries({success:true,protocolOnly:true,renderingPrepared:false,publicConnections:0,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true}))assert.equal(live[key],value,key);
for(const [file,digest] of Object.entries(live.sourceSha256))assert.equal(sha(await read(file)),digest,'Current default entry '+file);
assert.equal(native.success,true);assert.equal(native.object_visuals_complete,true);assert.equal(native.workers_remaining,0);assert.equal(native.protocol_finish_ack,true);assert.equal(native.world.entities,20);assert.equal(native.world.terrain.rendered_tiles,9);assert.deepEqual(native.world.errors,[]);assert.deepEqual(native.world.failed_objects,{});
assert.ok(live.firstPlayable.entities<live.firstPlayable.desired&&live.firstPlayable.pendingBatches>0);
assert.ok(live.movementWhileStreaming.nativeDistance>.05&&live.movementWhileStreaming.serverDistance>.05&&live.movementWhileStreaming.pendingBatches>0);assert.ok(Math.abs(live.localWalkDistance-live.authoritativeDistance)<.001);
const counts=Object.fromEntries(Object.entries(Object.groupBy(native.world.native_particles.diagnostics,r=>r.reason)).map(([reason,rows])=>[reason,rows.length]));
assert.deepEqual(counts,{'Native explosion point-wind registration is pending':17,'Native particle scene intersection is pending':32});
assert.equal(native.world.native_particles.emitters,57);assert.equal(native.world.native_particles.simulated,8);assert.equal(native.world.native_particles.failed,49);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!clean.test(String(await read('reports/'+name+suffix))),name+suffix);
assert.deepEqual(live.loadedProtocolModules.filter(f=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene)\.js$|(?:^|\/)three\//.test(f)),[]);
checked.push({run:name,sha256:sha(await read('reports/'+name+'.json'))});
const captureName='native-capture-spawn-words-v1',capture=await json('reports/'+captureName+'.json'),proof=await json('reports/'+captureName+'.verification.json');
for(const [key,value] of Object.entries({passed:true,debugHeapDisabled:true,debuggerArmed:true,nativeException:false,sourceUnchanged:true,cleanBenchmark:false}))assert.equal(proof[key],value,key);
assert.deepEqual(proof.failures,[]);assert.equal(capture.success,true);assert.equal(capture.worker_tasks_remaining,0);assert.equal(capture.input_sha256,'6bb657a6fd30d1e9e1a186e6c53c4d33f9494205e1383c5d582d308eb6d23243');
assert.equal(capture.terrain.rendered_tiles,48);assert.equal(capture.objects.rendered,889);assert.equal(capture.actors.rendered_creatures,8);assert.equal(capture.actors.rendered_items,1);assert.equal(capture.native_particles.emitters,1351);assert.equal(capture.native_particles.failed,1182);assert.ok(capture.native_particles.active>0);
assert.ok(capture.character_animation.some(r=>r.delta.advanced_model_clocks>0&&r.delta.maximum_local_skin_vertex_delta>0));
for(const [file,digest] of Object.entries(proof.sourceSha256))assert.equal(sha(await read(file)),digest,'Current captured source '+file);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!clean.test(String(await read('reports/'+captureName+suffix))),captureName+suffix);
assert.ok((await read('reports/'+captureName+'.png')).length>1000);checked.push({run:captureName,sha256:sha(await read('reports/'+captureName+'.json'))});
const result={success:true,reports:checked,liveParticleFailures:counts,firstPlayable:live.firstPlayable,captureIntervals:capture.frame_intervals,publicConnections:0,fullEffectsAccepted:false,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Original source-node dword zero branch, compiled adapter boundaries and regressions, actual default Prelude streaming/movement and compatible captured snapshot plus native animation. No complete scene services, full moving protocol replay, clean FPS or global native-fault acceptance.'};
await fs.writeFile(new URL('reports/native-particle-spawn-word-v1.verified.json',project),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(result));
