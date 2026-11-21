// Offline evidence audit only. Does not prepare assets, simulate, draw or connect.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const project=new URL('../',import.meta.url),read=path=>fs.readFile(new URL(path,project),'utf8');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const reports=[],checks=[['native-particle-schedule-v4',1907],['native-particle-physics-v3',1262],['native-particle-vertices-v3',491],['native-particle-runtime-v8',29],['native-emitter-data-runtime-v2',601],['native-actor-particle-regression-v2',266819]];
const engineError=/SCRIPT ERROR|^ERROR:|ObjectDB instances leaked|resources still in use/m;
for(const[name,count]of checks){
 const bytes=await read('reports/'+name+'.json'),value=JSON.parse(bytes);
 assert.equal(value.success??value.passed,true,name);assert.equal(value.checks,count,name);assert.equal(value.failures.length,0,name);
 if(name.startsWith('native-particle-')&&!name.includes('gpu'))assert.ok(!engineError.test(await read('reports/'+name+'.log')),name+' engine log');
 reports.push({name,sha256:hash(bytes),checks:count});
}
const run='native-session-particles-v3',bytes=await read('reports/'+run+'.json'),live=JSON.parse(bytes),native=JSON.parse(await read('reports/'+run+'.native.json'));
assert.equal(live.success,true);assert.equal(live.protocolOnly,true);assert.equal(live.renderingPrepared,false);assert.equal(live.publicConnections,0);
assert.equal(live.nativeExit,0);assert.equal(live.debuggerArmed,true);assert.equal(live.nativeException,false);assert.equal(live.sourceUnchanged,true);
assert.equal(live.native.workersRemaining,0);assert.equal(native.protocol_finish_ack,true);assert.equal(live.native.world.entities,20);assert.equal(live.native.world.terrain.rendered_tiles,9);
assert.ok(live.authoritativeDistance>.2&&live.authoritativeDistance<2);assert.ok(Math.abs(live.authoritativeDistance-live.localWalkDistance)<.001);
assert.ok(!engineError.test(await read('reports/'+run+'.engine.log')));assert.ok(!engineError.test(await read('reports/'+run+'.cdb.log')));
assert.ok(!/^NATIVE_SESSION_EXCEPTION\r?$/m.test(await read('reports/'+run+'.cdb.log')));
const forbidden=live.loadedProtocolModules.filter(name=>/(?:^|\/)(?:particle_[^/]+|model_particles|model_parser|prepared_model_geometry|network_scene)\.js$|(?:^|\/)three\//.test(name));assert.deepEqual(forbidden,[]);
for(const[file,expected]of Object.entries(live.sourceSha256))assert.equal(hash(await fs.readFile(new URL(file,project))),expected,'Current native runtime source: '+file);
for(const file of ['particle_schedule','particle_initialization','particle_movement','particle_math','particle_trig','particle_random','particle_channels','particle_vertices','particle_emitter'])assert.ok(live.sourceSha256['systems/native_render/'+file+'.gd']);
reports.push({name:run,sha256:hash(bytes),scope:'Final source-pinned direct-entry local check; no active particle quads in sampled final frame'});
const gpu='native-particle-runtime-gpu-v2',gpuBytes=await read('reports/'+gpu+'.json'),image=JSON.parse(gpuBytes),debug=await read('reports/'+gpu+'.cdb.log');
assert.equal(image.success,true);assert.equal(image.checks,30);assert.ok(image.rendered_image);assert.ok(/^NATIVE_PARTICLE_ARMED\r?$/m.test(debug));assert.ok(!/^NATIVE_PARTICLE_EXCEPTION\r?$/m.test(debug));assert.ok(!engineError.test(debug));
reports.push({name:gpu,sha256:hash(gpuBytes),scope:'Scoped final GPU fixture; original torch equip and portal drawing, direct/template/actor owners; no full-world/frame-pacing acceptance'});
const output={success:true,scope:'Partial native standard particle CPU/data/GPU/local-entry evidence audit; no complete migration/performance acceptance',reports,pinnedRuntimeSources:live.sourceSha256,publicConnections:0,fullParticleParityAccepted:false,fullVisualMigrationAccepted:false,denseMovingWorldAccepted:false,performanceAccepted:false,nativeShutdownFaultResolved:false};
await fs.writeFile(new URL('reports/native-particle-core-v2.verified.json',project),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,reports:reports.length,originalRuntimeCases:290+800+165+647+876+384+245,fullParticleParityAccepted:false,performanceAccepted:false}));
