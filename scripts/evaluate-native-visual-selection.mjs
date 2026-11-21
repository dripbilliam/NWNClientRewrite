// Audit the selector-only experiment. A faster inner walk is not proof of
// complete effect rendering, and a clean process exit is not a passing test.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
const home=path.resolve('godot-client/reports'),evidence=[];
async function read(file){const bytes=await fs.readFile(path.join(home,file));evidence.push({file,sha256:createHash('sha256').update(bytes).digest('hex')});return JSON.parse(bytes);}
function distribution(rows,key){const a=rows.map(r=>Number(r[key]??0)).sort((a,b)=>a-b);assert.ok(a.length&&a.every(Number.isFinite));return {samples:a.length,mean:a.reduce((s,n)=>s+n,0)/a.length,p95:a[Math.ceil(a.length*.95)-1],p99:a[Math.ceil(a.length*.99)-1],max:a.at(-1)};}
const fields=['wall_ms','callback_effects','effect_selection_total','effect_selection_setup','effect_selection_core','effect_competing_selection','actor_animation','callback_particles','render_cpu_ms','render_gpu_ms','memory_static_bytes','video_memory_bytes'];
let sources,fixture,states;const modes={script:[],compiled:[]};
for(const [mode,version]of [['script','v1'],['compiled','v1'],['compiled','v2'],['script','v2']]){
 const run=`native-visual-selector-local-${mode}-${version}`,r=await read(run+'.json');
 assert.equal(r.success,true,run);assert.equal(r.sourceUnchanged,true,run);assert.equal(r.nativeExit,0,run);assert.equal(r.nativeException,false,run);assert.equal(r.publicConnections,0,run);assert.equal(r.actions.success,true,run);assert.equal(r.actions.failures.length,0,run);assert.equal(r.actions.checks.length,115,run);
 if(sources)assert.deepEqual(r.sourceSha256,sources,'Measured sources differ');else sources=r.sourceSha256;
 if(fixture)assert.deepEqual(r.actionFixture,fixture,'Server fixtures differ');else fixture=r.actionFixture;
 const c=await read(run+'.native-crowd-19.summary.json'),backend=c.selection_backend;
 assert.equal(c.effect_entries,98);assert.equal(c.effect_models,98);assert.equal(c.world_instances,28);assert.equal(c.effect_states.length,96);assert.equal(c.particle_state.failed,0);assert.ok(c.particle_state.active>0&&c.peaks.active>0);assert.equal(c.particles,true);assert.equal(c.collision,true);assert.equal(c.membership_indexed,true);
 assert.equal(c.model_controls.compiled_requested,true);assert.equal(c.model_controls.direct_requested,true);assert.equal(c.model_controls.root_requested,true);assert.equal(c.model_controls.failures,0);
 assert.equal(backend.compiled_requested,mode==='compiled');assert.equal(backend.available,true);assert.equal(backend.calls>0,mode==='compiled');assert.equal(backend.failures,0);
 const actual=c.effect_states.map(r=>({...r})).sort((a,b)=>a.actor-b.actor||a.visual-b.visual);if(states)assert.deepEqual(actual,states,'Effect admission/attachment states differ');else states=actual;
 const rows=await read(run+'.native-crowd-19.frames.json');assert.equal(rows.length,c.frame_count);
 modes[mode].push({run,rows,backend,metrics:Object.fromEntries(fields.map(k=>[k,distribution(rows,k)]))});
}
const aggregate={};for(const [mode,runs]of Object.entries(modes)){const rows=runs.flatMap(r=>r.rows);aggregate[mode]={runs:runs.map(({rows,...r})=>r),metrics:Object.fromEntries(fields.map(k=>[k,distribution(rows,k)])),hitches:{samples:rows.length,over_60fps_budget:rows.filter(r=>r.wall_ms>1000/60).length,over_25ms:rows.filter(r=>r.wall_ms>25).length,over_50ms:rows.filter(r=>r.wall_ms>50).length}};}
const comparison={};for(const key of fields){const before=aggregate.script.metrics[key],after=aggregate.compiled.metrics[key];comparison[key]={before,after,mean_reduction_percent:100*(before.mean-after.mean)/before.mean,p95_reduction_percent:100*(before.p95-after.p95)/before.p95};}
const regression=[];
for(const [run,checks]of [['native-visual-selector-oracle-v3',10370],['native-visual-selector-world-v3',4617],['native-visual-selector-lifetime-v2',11],['native-visual-selector-particle-state-v1',6871],['native-visual-selector-particle-order-v1',25810],['native-visual-selector-particle-lifetime-v1',12080]]){
 const g=await read(run+'.debugger.json'),t=await read(run+'.json');assert.equal(g.success,true,run);assert.equal(g.sourceUnchanged,true,run);assert.equal(g.engineOrLifetimeError,false,run);assert.equal(t.success,true,run);assert.equal(t.checks,checks,run);
 for(const [file,digest]of Object.entries(sources))if((file.startsWith('native/')||file.startsWith('systems/'))&&file in g.sourceSha256)assert.equal(g.sourceSha256[file],digest,'Regression/measured implementation differs: '+file);
 regression.push({run,checks,source_sha256:g.sourceSha256});
}
const full_effect_checks=[];
for(const run of ['native-visual-selector-effects-full-v1','native-visual-selector-effects-full-base-v1']){
 const r=await read(run+'.json');assert.equal(r.sourceUnchanged,true,run);assert.equal(r.nativeException,false,run);assert.equal(r.publicConnections,0,run);
 assert.deepEqual(r.sourceSha256,sources,'Full-effect sources differ');
 if(r.actions){assert.equal(r.nativeExit,0,run);assert.equal(r.actions.checks.length,39,run);full_effect_checks.push({run,success:r.success,failures:r.actions.failures,checks:r.actions.checks.map(({label,passed,details})=>({label,passed,details}))});}
 else{assert.equal(r.failure,'Native localhost check timed out',run);full_effect_checks.push({run,success:false,failure:r.failure,boot_stage:r.bootStage,checks:[]});}
}
const report={version:1,success:true,goal_complete:false,scope:'Selector-only same-source four-run comparison on the original localhost server, 96 sustained effects, twelve actors and twelve braziers. This audit succeeds only as an honest performance/regression comparison; retained failed full-effect image checks are not accepted gameplay evidence.',decision:'Retain the compiled selector as an opt-in experiment (--visual-selection=compiled / NWN_VISUAL_SELECTION=compiled). The inner walk is cheaper, but whole-frame improvement is small and p95/p99 did not improve. Do not activate it by default or claim the 60 FPS target.',measured_sources:sources,fixture,aggregate,comparison,regression,full_effect_checks,evidence,limits:['The compiled full-effects run fails two image checks, while state, beam, projectile and lifetime checks pass. The baseline retry timed out at startup before any actions. Their full-effects comparison is INCONCLUSIVE. Investigate shared-renderer visibility when the test freezes world processing before model.hide(); that suspected explanation is not established by this comparison.','The earlier -Effects -Profile test exercised Heal profiling only, not the full effect suite.','The World wrapper retains its preexisting fixed suppression/view-gate policy. The native private selector schema reads programType10d & 255; it is not an arbitrary custom programType callback interpreter.','Fresh host and runtime/state lookups, per-phase selection, inline callback order and partial-failure non-replay behavior are retained.','GPU and CPU timings overlap. Memory is whole-engine static allocation, not isolated allocator or OS working-set tracing.']};
const output=path.join(home,'native-visual-selector-evaluation-v1.json');await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:true,goal_complete:false,output,wall:comparison.wall_ms,selection:comparison.effect_selection_core,full_effect_failures:full_effect_checks.map(r=>({run:r.run,failures:r.failures}))},null,2));
