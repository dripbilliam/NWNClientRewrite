// Offline evidence audit only; no rendering, asset preparation or connection.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url), read=name=>fs.readFile(new URL(name,project));
const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const parse=async name=>JSON.parse(await read('reports/'+name));
const errors=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
const checked=[];
for(const [run,count] of [['native-streaming-priority-v1',46],['native-streaming-reference-gpu-v1',147]]){
 const result=await parse(run+'.json'),proof=await parse(run+'.debugger.json');
 assert.equal(result.success,true);assert.equal(result.checks,count);assert.deepEqual(result.failures,[]);
 assert.equal(proof.success,true);assert.equal(proof.normalHeap,true);assert.equal(proof.exceptionTraps,4);assert.equal(proof.armed,true);assert.equal(proof.exception,false);assert.equal(proof.engineOrLifetimeError,false);assert.equal(proof.sourceUnchanged,true);
 for(const [name,sha] of Object.entries(proof.sourceSha256))assert.equal(digest(await read(name)),sha,'Current source '+name);
 for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!errors.test(String(await read('reports/'+run+suffix))));
 checked.push({run,checks:count,sha256:digest(await read('reports/'+run+'.json'))});
}
const run='native-session-streaming-priority-v2',live=await parse(run+'.json'),native=await parse(run+'.native.json');
assert.equal(live.success,true);assert.equal(live.publicConnections,0);assert.equal(live.protocolOnly,true);assert.equal(live.renderingPrepared,false);assert.equal(live.nativeExit,0);assert.equal(live.debuggerArmed,true);assert.equal(live.nativeException,false);assert.equal(live.sourceUnchanged,true);
assert.equal(native.protocol_finish_ack,true);assert.equal(native.workers_remaining,0);assert.equal(native.world.entities,20);assert.equal(native.world.terrain.rendered_tiles,9);
assert.equal(live.firstPlayable.entities,1);assert.ok(live.firstPlayable.desired>live.firstPlayable.entities);assert.ok(live.firstPlayable.pendingBatches>0);
assert.ok(live.movementWhileStreaming.nativeDistance>.05);assert.ok(live.movementWhileStreaming.serverDistance>.05);assert.ok(live.movementWhileStreaming.entities<live.movementWhileStreaming.desired);assert.ok(live.movementWhileStreaming.pendingBatches>0);
assert.ok(live.localWalkDistance>.2&&live.localWalkDistance<2);assert.ok(Math.abs(live.authoritativeDistance-live.localWalkDistance)<.001);
assert.equal(native.world.entities+native.world.hidden,native.world.desired);
for(const [name,sha] of Object.entries(live.sourceSha256))assert.equal(digest(await read(name)),sha,'Current launcher/runtime source '+name);
for(const suffix of ['.engine.log','.cdb.log'])assert.ok(!errors.test(String(await read('reports/'+run+suffix))));
assert.deepEqual(live.loadedProtocolModules.filter(name=>/(?:^|\/)(?:model_parser|model_hierarchy|prepared_model_geometry|network_scene|native_ui_assets|model_particles|particle_[^/]+)\.js$|(?:^|\/)three\//.test(name)),[]);
checked.push({run,sha256:digest(await read('reports/'+run+'.json')),firstPlayable:live.firstPlayable,movementWhileStreaming:live.movementWhileStreaming});
const output={success:true,reports:checked,publicConnections:0,fullMigrationAccepted:false,denseMovingWorldAccepted:false,performanceAccepted:false,nativeShutdownFaultResolved:false,scope:'Actual native planner/readiness and scoped GPU/local evidence; warm Prelude control/movement before background completion, no cold/dense/public/frame-pacing acceptance'};
await fs.writeFile(new URL('reports/native-streaming-priority-v1.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,reports:checked.length,firstPlayable:live.firstPlayable,movementWhileStreaming:live.movementWhileStreaming}));
