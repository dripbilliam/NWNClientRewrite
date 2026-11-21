// Offline evidence audit only: no rendering/resource preparation or connections.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url), read=name=>fs.readFile(new URL(name,project));
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const json=async name=>JSON.parse(await read(name));
const bad=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const name='native-static-pose-v1',r=await json('reports/'+name+'.json'),proof=await json('reports/'+name+'.debugger.json');
assert.equal(r.success,true);assert.equal(r.checks,8);assert.deepEqual(r.failures,[]);
assert.equal(r.frames,180);assert.equal(r.static_objects,602);assert.equal(r.network_connections,0);
for(const [key,value]of Object.entries({success:true,normalHeap:true,exceptionTraps:4,armed:true,exception:false,engineOrLifetimeError:false,sourceUnchanged:true}))assert.equal(proof[key],value,key);
for(const [file,sha]of Object.entries(proof.sourceSha256))assert.equal(digest(await read(file)),sha,'Current fixture source '+file);
const liveName='native-session-static-pose-v1',live=await json('reports/'+liveName+'.json'),native=await json('reports/'+liveName+'.native.json');
for(const [key,value]of Object.entries({success:true,publicConnections:0,protocolOnly:true,renderingPrepared:false,nativeExit:0,debuggerArmed:true,nativeException:false,sourceUnchanged:true}))assert.equal(live[key],value,key);
// Host field retains a diagnostic tail, including warnings, despite its name.
// Fatal/script/lifetime errors are checked separately from incomplete effects.
assert.ok(!bad.test(String(live.engineErrors)), 'Fatal diagnostic tail');
assert.equal(native.protocol_finish_ack,true);assert.equal(native.workers_remaining,0);
assert.equal(native.world.entities,20);assert.equal(native.world.desired,20);assert.equal(native.world.terrain.rendered_tiles,9);assert.equal(native.world.pending_batches,0);assert.deepEqual(native.world.errors,[]);
assert.equal(live.firstPlayable.entities,1);assert.ok(live.firstPlayable.desired>1);assert.ok(live.firstPlayable.pendingBatches>0);
assert.ok(live.movementWhileStreaming.nativeDistance>.05&&live.movementWhileStreaming.serverDistance>.05);assert.ok(live.movementWhileStreaming.entities<live.movementWhileStreaming.desired&&live.movementWhileStreaming.pendingBatches>0);
assert.ok(live.localWalkDistance>.2&&live.localWalkDistance<2);assert.ok(Math.abs(live.localWalkDistance-live.authoritativeDistance)<.001);
assert.ok(native.world.pose_evaluations>native.world.static_pose_evaluations&&native.world.static_pose_evaluations>0);
for(const[file,sha]of Object.entries(live.sourceSha256))assert.equal(digest(await read(file)),sha,'Current normal entry '+file);
for(const run of [name,liveName])for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!bad.test(String(await read('reports/'+run+suffix))),run+suffix);
assert.deepEqual(live.loadedProtocolModules.filter(file=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene|model_reference_assets|model_reference_scene)\.js$|(?:^|\/)three\//.test(file)),[]);
const instructions=JSON.parse(await fs.readFile(new URL('../../backups/animations/native-world-frame-boundaries-v1.json',import.meta.url)));
assert.equal(instructions.checks.length,6);
assert.equal(instructions.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
const output={success:true,originalInstructionChecks:6,nativeChecks:r.checks,firstPlayable:live.firstPlayable,movementWhileStreaming:live.movementWhileStreaming,particleDiagnostics:native.world.native_particles,retainedJsModules:live.loadedProtocolModules.length,publicConnections:0,performanceAccepted:false,fullMigrationAccepted:false,nativeShutdownFaultResolved:false,scope:'Source-pinned actual native pose fixture and default warm local movement/cleanup; incomplete particle effects retained as diagnostics; no full binary dirty/culling, complete dense moving-world or FPS acceptance',reports:[name,liveName].map(run=>({run}))};
await fs.writeFile(new URL('reports/native-static-pose-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...output,particleDiagnostics:{...output.particleDiagnostics,diagnostics:undefined}}));
