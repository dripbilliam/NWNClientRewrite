// Read-only audit of same-source, authoritative full-room controller timings.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
const home=path.resolve('godot-client/reports'),evidence=[];
const hash=b=>createHash('sha256').update(b).digest('hex');
async function read(name){const bytes=await fs.readFile(path.join(home,name));evidence.push({file:name,sha256:hash(bytes)});return JSON.parse(bytes);}
function distribution(rows,key){const values=rows.map(r=>Number(r[key]??0)).sort((a,b)=>a-b);assert.ok(values.length&&values.every(Number.isFinite),key);return {samples:values.length,mean:values.reduce((n,v)=>n+v,0)/values.length,p95:values[Math.ceil(values.length*0.95)-1],p99:values[Math.ceil(values.length*0.99)-1],max:values.at(-1)};}
const fields=['wall_ms','callback_rigs','actor_animation','callback_effects','callback_particles','render_cpu_ms','render_gpu_ms','memory_static_bytes','video_memory_bytes','buffer_memory_bytes'];
const modes={script:[],compiled:[]};let source,fixture,states;
for(const version of ['v1','v2'])for(const mode of ['script','compiled']){
 const run=`native-model-control-local-${mode}-${version}`,report=await read(run+'.json');
 assert.equal(report.success,true,run);assert.equal(report.sourceUnchanged,true,run);assert.equal(report.publicConnections,0,run);assert.equal(report.nativeException,false,run);assert.equal(report.nativeExit,0,run);assert.equal(report.actions.success,true,run);assert.equal(report.actions.failures.length,0,run);assert.equal(report.actions.checks.length,114,run);
 if(source)assert.deepEqual(report.sourceSha256,source,'Measured sources differ');else source=report.sourceSha256;
 if(fixture)assert.deepEqual(report.actionFixture,fixture,'Server fixtures differ');else fixture=report.actionFixture;
 const capture=await read(run+'.native-crowd-19.summary.json');
 assert.equal(capture.effect_entries,98);assert.equal(capture.effect_models,98);assert.equal(capture.world_instances,28);assert.equal(capture.effect_states.length,96);assert.equal(capture.membership_indexed,true);assert.equal(capture.particles,true);assert.equal(capture.collision,true);assert.equal(capture.particle_state.failed,0);assert.ok(capture.peaks.active>0&&capture.particle_state.active>0);
 assert.equal(capture.model_controls.compiled_requested,mode==='compiled');assert.equal(capture.model_controls.failures,0);assert.ok(capture.model_controls.poses>0);assert.equal(capture.model_controls.calls>0,mode==='compiled');
 const actual=capture.effect_states.map(r=>({...r})).sort((a,b)=>a.actor-b.actor||a.visual-b.visual);if(states)assert.deepEqual(actual,states,'Admitted/attached original effects differ');else states=actual;
 const rows=await read(run+'.native-crowd-19.frames.json');assert.equal(rows.length,capture.frame_count);
 const metrics=Object.fromEntries(fields.map(key=>[key,distribution(rows,key)]));
 const pipeline_compilations=rows.reduce((sum,row)=>sum+Object.entries(row).filter(([key])=>key.includes('pipeline_compilations')&&key.endsWith('_delta')).reduce((n,[,v])=>n+Number(v),0),0);
 modes[mode].push({run,rows,metrics,pipeline_compilations,backend:capture.model_controls,emitters:capture.particle_state.emitters,active_particles_end:capture.particle_state.active});
}
const aggregate={};for(const [mode,runs]of Object.entries(modes)){const rows=runs.flatMap(r=>r.rows);aggregate[mode]={runs:runs.map(({rows,...r})=>r),metrics:Object.fromEntries(fields.map(key=>[key,distribution(rows,key)]))};}
const comparison={};for(const key of fields){const before=aggregate.script.metrics[key],after=aggregate.compiled.metrics[key];comparison[key]={before,after,mean_reduction_percent:100*(before.mean-after.mean)/before.mean,p95_reduction_percent:100*(before.p95-after.p95)/before.p95};}
const regression=[];
for(const [run,checks]of [['native-model-control-oracle-v1',16475],['native-model-control-resources-v2',60119],['native-model-control-particle-state-v1',6871],['native-model-control-particle-order-v1',25810],['native-model-control-particle-lifetime-v1',12080]]){
 const guard=await read(run+'.debugger.json'),test=await read(run+'.json');assert.equal(guard.success,true,run);assert.equal(guard.sourceUnchanged,true,run);assert.equal(guard.engineOrLifetimeError,false,run);assert.equal(test.success,true,run);assert.equal(test.checks,checks,run);
 for(const [file,digest]of Object.entries(source))if((file.startsWith('native/')||file.startsWith('systems/'))&&file in guard.sourceSha256)assert.equal(guard.sourceSha256[file],digest,'Measured/regression implementation differs: '+file);
 regression.push({run,checks,source_sha256:guard.sourceSha256});
}
const activation=[];
for(const [run,checks]of [['native-model-control-default-oracle-v1',16539],['native-model-control-default-resources-v1',60119]]){
 const guard=await read(run+'.debugger.json'),test=await read(run+'.json');assert.equal(guard.success,true,run);assert.equal(guard.sourceUnchanged,true,run);assert.equal(guard.engineOrLifetimeError,false,run);assert.equal(test.success,true,run);assert.equal(test.checks,checks,run);
 for(const [file,digest]of Object.entries(source))if((file.startsWith('native/')||file.startsWith('systems/'))&&file!=='systems/model_native_pose.gd'&&file in guard.sourceSha256)assert.equal(guard.sourceSha256[file],digest,'Unexpected activation implementation change: '+file);
 activation.push({run,checks,source_sha256:guard.sourceSha256});
}
const audit={version:1,success:true,goal_complete:false,scope:'Two scripted and two compiled bulk-controller runs of the same complete original-server scene, twelve actors, twelve braziers, 96 simultaneous duration effects and all Heal/wind/retirement checks. Same native binary and sources, differing only in the opt-in controller backend.',decision:'Keep bulk Part arithmetic as the Windows default with --model-controls=scripted or NWN_MODEL_CONTROLS=scripted rollback. Activation has fresh original-corpus and production-resource proofs. This does not change the main renderer or complete the wider parity/60-FPS goal.',measured_source_sha256:source,default_activation:activation,fixture,aggregate,comparison,regression,evidence,limits:['Real server/frame scheduling changes the final particle count; exact arithmetic/Part/pose/event comparisons are separate original-corpus and original-resource receipts.','The exported bulk Part operation has no motion-run callbacks. Existing production pose providers use none; motion/hierarchy oracle cases still exercise the retained script path.','Engine static memory covers the complete scene and fluctuating particle allocations. It is not an isolated allocation count or OS working set.','Native state, draw and lifecycle tests do not prove all unfinished lighting, source fade, BSP ordering, point-to-point, lightning or missing-resource parity requirements.']};
const output=path.join(home,'native-model-control-evaluation-v1.json');await fs.writeFile(output,JSON.stringify(audit,null,2)+'\n');console.log(JSON.stringify({success:true,goal_complete:false,output,wall:comparison.wall_ms,animation:comparison.actor_animation,rigs:comparison.callback_rigs,particles:comparison.callback_particles,memory:comparison.memory_static_bytes},null,2));
