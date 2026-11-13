// Read retained receipts only. This script never starts a client or connects.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const root=new URL('../godot-client/',import.meta.url);
const read=async name=>JSON.parse(await fs.readFile(new URL('reports/'+name+'.json',root),'utf8'));
const fingerprints=async name=>({name,sha256:createHash('sha256').update(await fs.readFile(new URL('reports/'+name+'.json',root))).digest('hex')});
const equalSources=(a,b)=>{
 const changes=[...new Set([...Object.keys(a),...Object.keys(b)])].filter(key=>a[key]!==b[key]);
 assert.deepEqual(changes,[],'Comparison must use identical source hashes');return true;
};
const localNames=['native-particle-fog-local-base-v2','native-particle-fog-local-shared-v4'];
const local=await Promise.all(localNames.map(read));
for(const r of local){
 assert.equal(r.success,true);assert.equal(r.sourceUnchanged,true);assert.equal(r.nativeException,false);assert.equal(r.nativeExit,0);assert.equal(r.publicConnections,0);
 assert.equal(r.actions.checks.length,103);assert.ok(r.actions.checks.every(c=>c.passed));assert.deepEqual(r.actions.failures,[]);
 assert.equal(r.native.world.effects.stats.started,166);assert.equal(r.native.world.effects.stats.failed,0);
}
equalSources(local[0].sourceSha256,local[1].sourceSha256);
const localStages=[];
for(const index of [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18]){
 const pair=await Promise.all(localNames.map(name=>read(name+'.native-crowd-'+index+'.summary')));
 assert.equal(pair[0].label,pair[1].label);
 for(const value of pair)assert.equal(value.particle_state.failed,0);
 const compact=value=>({wall_ms:value.metrics.wall_ms,particle_ms:value.metrics.callback_particles??null,render_cpu_ms:value.metrics.render_cpu_ms,render_gpu_ms:value.metrics.render_gpu_ms,memory_static_bytes:value.metrics.memory_static_bytes,particle_state:value.particle_state,frames:value.frame_count});
 localStages.push({label:pair[0].label,particles:pair[0].particles,collision:pair[0].collision,direct_scene:pair[0].direct_scene,baseline:compact(pair[0]),candidate:compact(pair[1])});
}
const roomNames=['native-particle-fog-room-base-v1','native-particle-fog-room-shared-v1'];
const room=await Promise.all(roomNames.map(read));
for(const r of room){assert.equal(r.success,true);assert.equal(r.sourceUnchanged,true);assert.equal(r.gameNetworkConnections,0);assert.equal(r.nativeException,false);assert.equal(r.engineOrLifetimeError,false);assert.equal(r.native.performance_window.steady,true);}
equalSources(room[0].sourceSha256,room[1].sourceSha256);assert.equal(room[0].recordingSha256,room[1].recordingSha256);
const roomSummary=[];
for(let i=0;i<room.length;i++){
 const r=room[i],p=r.native.world.native_particles;
 assert.equal(p.emitters,778);assert.equal(p.failed,32);assert.deepEqual(p.reason_counts,{'Original particle bitmap unavailable: fxpa_cloud02':32});
 const rows=(await fs.readFile(new URL('reports/'+roomNames[i]+'.performance.jsonl',root),'utf8')).trim().split('\n').map(JSON.parse);
 const last=rows.at(-1).frame_profile.metrics;
 roomSummary.push({run:roomNames[i],intervals:r.native.frame_intervals,particle_callback_ms:last.callback_particles,render_cpu_ms:last.render_cpu_ms,render_gpu_ms:last.render_gpu_ms,missing_bitmap_emitters:32,shared:r.native.world.native_particle_stream??null});
}
const gpuNames=['native-gpu-particle-per-emitter-v1','native-gpu-particle-batched-v1'];
const gpu=await Promise.all(gpuNames.map(read));
for(let i=0;i<gpu.length;i++){
 const proof=await read(gpuNames[i]+'.debugger');assert.equal(gpu[i].success,true);assert.equal(proof.success,true);assert.equal(proof.sourceUnchanged,true);assert.equal(proof.engineOrLifetimeError,false);assert.equal(gpu[i].particle_count,1506);assert.ok(gpu[i].moving_sample_pixels>100);assert.ok(gpu[i].visible_sample_pixels>1000);
}
assert.equal(gpu[0].texture_sha256,gpu[1].texture_sha256);
const result={success:true,scope:'Diagnostic comparisons and isolated architecture feasibility. No gameplay/default renderer promotion and no completion of the active parity/performance goal.',
 local:{runs:await Promise.all(localNames.map(fingerprints)),source_identical:true,checks_each:103,real_server_effects_started_each:166,stages:localStages},
 room:{runs:await Promise.all(roomNames.map(fingerprints)),source_identical:true,recording_identical:true,steady_seconds:12,results:roomSummary,limitation:'Both runs retain the same 32 missing-bitmap emitters. The capture is a useful matched bottleneck test, not all-effects-present or live-server acceptance. Candidate retains 510 per-emitter fallback callbacks, so its roughly38 FPS result is insufficient.'},
 gpu_architecture:{runs:await Promise.all(gpuNames.map(fingerprints)),per_emitter:gpu[0].frame_profile,batched:gpu[1].frame_profile,wall_ratio:gpu[0].frame_profile.metrics.wall_ms.mean/gpu[1].frame_profile.metrics.wall_ms.mean,particle_count:1506,limitation:'Simplified GPU-only moving original-texture sprites; not real NWN effect/physics/RNG/chunk/lighting conversion. Do not equate its high FPS with real-room performance.'},
 next:'Prototype pooled GPU state/simulation with groups by texture, material and mesh. Avoid one GPUParticles3D per original emitter. Cover chunk and lit effects rather than silently leaving the dominant work on the old callbacks; validate actual original effects/full room before any promotion.',
 completeGoal:false,defaultChanged:false,publicGameConnections:0};
const output=new URL('reports/native-particle-fog-and-gpu-evaluation-v1.json',root);
await fs.writeFile(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,report:output.pathname,room_baseline_ms:roomSummary[0].intervals.average_ms,room_candidate_ms:roomSummary[1].intervals.average_ms,gpu_layout_ratio:result.gpu_architecture.wall_ratio,completeGoal:false}));
