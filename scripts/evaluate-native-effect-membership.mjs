// Audit immutable full-scene receipts. This does not launch or contact a game.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const home=path.resolve('godot-client/reports');
const pairs=['v2','v3'];
const fields=['wall_ms','callback_effects','callback_rigs','callback_particles','render_cpu_ms','render_gpu_ms','memory_static_bytes','video_memory_bytes','buffer_memory_bytes'];
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const evidence=[];
async function read(name){const bytes=await fs.readFile(path.join(home,name));evidence.push({file:name,sha256:hash(bytes)});return JSON.parse(bytes);}
function distribution(rows,field){const values=rows.map(r=>Number(r[field]??0)).sort((a,b)=>a-b);assert.ok(values.length&&values.every(Number.isFinite),field);return {samples:values.length,mean:values.reduce((n,v)=>n+v,0)/values.length,p95:values[Math.ceil(values.length*0.95)-1],p99:values[Math.ceil(values.length*0.99)-1],max:values.at(-1)};}
function states(capture){return capture.effect_states.map(r=>({...r})).sort((a,b)=>a.actor-b.actor||a.visual-b.visual);}
const modes={scan:[],index:[]};let sources,fixture,reference;
for(const version of pairs)for(const mode of ['scan','index']){
 const run=`native-effect-membership-local-${mode}-${version}`;
 const report=await read(run+'.json');
 assert.equal(report.success,true,run);assert.equal(report.sourceUnchanged,true,run);assert.equal(report.nativeExit,0,run);assert.equal(report.nativeException,false,run);assert.equal(report.publicConnections,0,run);
 assert.equal(report.actions.success,true,run);assert.equal(report.actions.failures.length,0,run);assert.equal(report.actions.checks.length,113,run);
 if(sources)assert.deepEqual(report.sourceSha256,sources,'Comparison sources differ');else sources=report.sourceSha256;
 if(fixture)assert.deepEqual(report.actionFixture,fixture,'Comparison server fixtures differ');else fixture=report.actionFixture;
 const capture=await read(run+'.native-crowd-19.summary.json');
 assert.equal(capture.membership_indexed,mode==='index');assert.equal(capture.effect_entries,98);assert.equal(capture.effect_models,98);assert.equal(capture.world_instances,28);assert.equal(capture.effect_states.length,96);assert.equal(capture.particle_state.failed,0);assert.ok(capture.peaks.active>0&&capture.particle_state.active>0);
 assert.equal(capture.particles,true);assert.equal(capture.collision,true);assert.equal(capture.direct_scene,true);
 const state=states(capture);if(reference)assert.deepEqual(state,reference,'Effect admission/attachment states differ');else reference=state;
 const rows=await read(run+'.native-crowd-19.frames.json');assert.equal(rows.length,capture.frame_count);
 const metrics=Object.fromEntries(fields.map(field=>[field,distribution(rows,field)]));
 modes[mode].push({run,metrics,rows,effects:capture.effect_entries,models:capture.effect_models,active_particles_end:capture.particle_state.active,emitters:capture.particle_state.emitters,failed_emitters:capture.particle_state.failed});
}
const aggregate={};
for(const [mode,runs]of Object.entries(modes)){const rows=runs.flatMap(r=>r.rows);aggregate[mode]={runs:runs.map(({rows,...r})=>r),metrics:Object.fromEntries(fields.map(field=>[field,distribution(rows,field)]))};}
const comparison={};
for(const field of fields){const before=aggregate.scan.metrics[field],after=aggregate.index.metrics[field];comparison[field]={before,after,mean_reduction_percent:100*(before.mean-after.mean)/before.mean,p95_reduction_percent:100*(before.p95-after.p95)/before.p95};}
const promotion=[];
for(const [run,checks]of [['native-effect-membership-default-state-v1',4616],['native-effect-membership-default-lifetime-v1',11],['native-particle-goal-state-v1',6871],['native-particle-goal-order-v1',25810],['native-particle-goal-lifetime-v1',12080]]){
 const guard=await read(run+'.debugger.json'),test=await read(run+'.json');
 assert.equal(guard.success,true,run);assert.equal(guard.sourceUnchanged,true,run);assert.equal(guard.engineOrLifetimeError,false,run);assert.equal(guard.publicConnections,0,run);assert.equal(test.success,true,run);assert.equal(test.checks,checks,run);
 // The measured candidate and the default differ only in the activation
 // expression. Keep those original receipt hashes, not rewritten histories.
 for(const [file,digest]of Object.entries(sources))if(file!=='systems/visual_world.gd'&&file in guard.sourceSha256)assert.equal(guard.sourceSha256[file],digest,'Unexpected post-measurement source change: '+file);
 promotion.push({run,checks,source_sha256:guard.sourceSha256});
}
const audit={version:1,scope:'Repeated complete original-server room with twelve characters, twelve braziers, 96 active stock duration effects and unchanged particle settings. Two scan and two indexed runs, plus the full authoritative Heal/wind/retirement suite in each run. Localhost only.',success:true,goal_complete:false,decision:'Keep actor-membership indexing as the default with an explicit scan rollback. This is separate from the shared/pooled renderer, which remains opt-in; the wider goal is unfinished.',identical_measured_source_sha256:sources,default_activation_regressions:promotion,fixture,aggregate,comparison,evidence,limits:['Real server and frame-clock scheduling are not a fixed-timestep particle oracle; end particle counts vary. Exact selection/lifetime regressions are separate receipts.','Engine static-memory totals include the complete scene and changing active-particle allocations; they are not isolated index allocation counts or OS working set.','CPU callbacks are disjoint owners; GPU/render spans overlap and must not be summed.','The earlier v1 diagnostic fixture exposed existing unsupported point-to-point movement. It remains an explicit compatibility requirement; the accepted fixture uses eight different fully admitted stock effects.','This sustained stress scene remains below 60 FPS. Effect/actor animation is the dominant remaining CPU work.']};
const output=path.join(home,'native-effect-membership-evaluation-v1.json');await fs.writeFile(output,JSON.stringify(audit,null,2)+'\n');
console.log(JSON.stringify({success:audit.success,goal_complete:false,output,wall:comparison.wall_ms,effects:comparison.callback_effects,animation:comparison.callback_rigs,memory:comparison.memory_static_bytes},null,2));
