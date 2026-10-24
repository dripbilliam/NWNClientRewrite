import test from 'node:test';import assert from 'node:assert/strict';
import {canonicalReplayObjects,replayInventoryHash,replayFrameMetrics,summarizeReplayMeasurements} from './replay-measurement.mjs';
import {performanceCandidateFlags} from '../performance-candidates/live-performance-profile.mjs';
const hash='a'.repeat(64);

test('discard timing requires both cooperative ownership and observed shader specialization',()=>{
 for(const mode of ['opaque-alpha','keyhole-inactive','native-discard']){
  const{report,options}=fixture();for(const index of [1,2]){const m=report.measurements[index];m.mode=mode;m.frames.label=index+':'+mode;report.measurementPlan.modes[index]=mode;
   for(const [which,s]of [m.start,m.end].entries()){
    s.experiment=mode;s.runtimeOptions={particleFrameStorage:true,lightOnlyMembership:true};for(const key of ['batches','materialReuse','lightUniforms'])s.performance.telemetry[key]={enabled:false};
    s.matrixCooperation={cooperation:true,owners:1,skipped:which};s.warmDraws={enabled:true,bridge:1,fast:100};s.scenePlan={enabled:true,bridge:1,shared:true,projected:100};s.shadowPrefix={enabled:true,restored:1,prefixObjects:20,suffixObjects:10,bytes:16384};
    s.discard={opaqueAlpha:{enabled:mode!=='keyhole-inactive',removed:20},keyhole:{specializeInactive:mode!=='opaque-alpha'},programs:{inactive:30}};
   }
  }
  assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);
  const changes=[s=>s.matrixCooperation.cooperation=false,...(mode!=='keyhole-inactive'?[s=>s.discard.opaqueAlpha.removed=0,s=>s.discard.opaqueAlpha.enabled=false]:[]),...(mode!=='opaque-alpha'?[s=>s.discard.programs.inactive=0,s=>s.discard.keyhole.specializeInactive=false]:[])];
  for(const change of changes){const copy=structuredClone(report);change(copy.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(copy,options),/not exercised/);}
 }
});
function observation({frames=1260,gap=16,tail=0,label='0:baseline'}={}){return{label,dropped:0,durationMs:frames*gap+tail,rows:Array.from({length:frames},(_,i)=>({at:(i+1)*gap,gapMs:gap}))};}
function fixture(){
 const inventory=[{id:2147483650,resources:['tile']},{id:4294967091,resources:['body','head']}],identity=replayInventoryHash(inventory),modes=['baseline','flat-scene','flat-scene','baseline'];
 const state=(mode,index,end)=>({experiment:mode,elapsedMs:index*50000+(end?20160:0),frameCounts:{callbacks:index*1260+(end?1260:0),rendered:index*1260+(end?1260:0)},phase:'playing',areaId:2147483655,objects:2,models:3,canonicalObjects:5,failedObjects:[],pendingAssets:0,graphicsPending:false,particles:{emitters:4,active:3,failed:1},buffer:[1424,921],camera:{position:[1,2,3],quaternion:[0,0,0,1],target:[0,0,0]},flatScene:mode==='flat-scene'?{submittedObjects:3}:null,performance:{flags:performanceCandidateFlags('candidates'),telemetry:{shadows:{native:{maximum:1}},models:{pending:0}}}});
 const report={measurementVersion:1,environment:{operatorConfirmedIdle:true,profilerEnabled:false},rendered:true,build:{sha256:hash},harnessSha256:hash,capture:{eventsSha256:hash,unrecorded:[]},errors:[],diagnostics:[],textGaps:[],blockedRequests:[],inventory,measurementPlan:{modes,warmupMs:16000,phaseMs:20000},measurements:modes.map((mode,index)=>({index,mode,start:state(mode,index,false),end:state(mode,index,true),frames:observation({label:index+':'+mode}),inventoryStartHash:identity,inventoryEndHash:identity})),parity:{objects:false,models:false}};
 return{report,options:{expectedIds:inventory.map(r=>r.id),expectedInventoryHash:identity}};
}
test('unfinished observation tail counts toward elapsed time and the freeze gate',()=>{const r=replayFrameMetrics(observation({frames:200,gap:16,tail:1200}),200);assert.equal(r.durationMs,4400);assert.equal(r.maxMs,1200);assert.equal(r.freezesOver1000Ms,1);assert.equal(r.targetMet,false);assert.ok(r.fps<46);assert.equal(r.p95Ms,16);});
test('dropped frames, invalid clocks, missing render coverage and zero renders reject measurement',()=>{
 for(const mutate of [o=>o.dropped=1,o=>o.rows[2].at--,o=>o.rows[2].gapMs=0,o=>o.durationMs=100]){const o=observation();mutate(o);assert.throws(()=>replayFrameMetrics(o,1260));}
 assert.throws(()=>replayFrameMetrics(observation(),900),/coverage/);assert.throws(()=>replayFrameMetrics(observation({frames:1}),0),/No completed/);
});
test('inventory identity is ordering independent and includes every model resource and duplicate instance',()=>{
 const inventory=[{id:2,resources:['b','a','a']},{id:1,resources:['c']}];assert.equal(replayInventoryHash(inventory),replayInventoryHash([{id:1,resources:['c']},{id:2,resources:['a','b','a']}]));
});
test('inventory duplicate IDs, absent resources and changed resource lists cannot match',()=>{
 assert.throws(()=>replayInventoryHash([{id:1,resources:['a']},{id:1,resources:['b']}]),/duplicate/);assert.throws(()=>replayInventoryHash([{id:1,resources:[]}]),/Missing model/);assert.notEqual(replayInventoryHash([{id:1,resources:['a','a']}]),replayInventoryHash([{id:1,resources:['a']}]));
});
test('complete paired measurements retain recorded partial-frame failures and never complete the goal',()=>{const {report,options}=fixture(),r=summarizeReplayMeasurements(report,options);assert.equal(r.timingComparisonValid,true);assert.equal(r.measuredSteadyTargetMet,true);assert.deepEqual(r.recordedFrameParity,{objects:false,models:false});assert.equal(r.enableByDefault,false);assert.equal(r.goalComplete,false);});
test('concurrent-game uncertainty, profiling, missing resources and incomplete renderer state reject comparisons',()=>{
 for(const change of [r=>delete r.environment.operatorConfirmedIdle,r=>r.measurements[1].end.workerStream={enabled:true},r=>r.environment.profilerEnabled=true,r=>r.capture.unrecorded.push('missing'),r=>r.errors.push('failed'),r=>delete r.diagnostics,r=>r.measurements[1].end.pendingAssets=1,r=>r.measurements[1].end.performance.telemetry.models.pending=1]){const{report,options}=fixture();change(report);assert.throws(()=>summarizeReplayMeasurements(report,options));}
});
test('render-size, camera, flags, shader budget and stable content must agree at both endpoints',()=>{
 for(const change of [s=>s.buffer[0]++,s=>s.camera.position[0]++,s=>s.performance.flags.modelCache=false,s=>s.performance.telemetry.shadows.native.maximum++,s=>s.models--,s=>s.particles.emitters--,s=>s.particles.failed++]){const{report,options}=fixture();change(report.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(report,options),/settings changed/);}
});
test('renamed resources, altered canonical IDs and incomplete mode application reject comparisons',()=>{
 for(const change of [(r,o)=>o.expectedIds[0]++,(r,o)=>r.inventory[0].resources=['different'],(r,o)=>r.measurements[1].inventoryEndHash='b'.repeat(64),(r,o)=>r.measurements[1].end.flatScene={fallback:'unsupported'}]){const{report,options}=fixture();change(report,options);assert.throws(()=>summarizeReplayMeasurements(report,options));}
});
test('truncated phases, wrong labels, missing warmups and unbounded mode plans reject comparisons',()=>{
 for(const change of [r=>r.measurements.pop(),r=>r.measurements[1].frames.label='another',r=>r.measurements[1].end.elapsedMs=1,r=>r.measurementPlan.warmupMs=1000,r=>r.measurementPlan.modes=['flat-scene']]){const{report,options}=fixture();change(report);assert.throws(()=>summarizeReplayMeasurements(report,options));}
});
test('baseline drift and candidate repeat drift invalidate speedup inference',()=>{
 for(const index of [3,2]){const{report,options}=fixture(),m=report.measurements[index];m.frames=observation({label:index+':'+m.mode,gap:20});m.end.elapsedMs=m.start.elapsedMs+m.frames.durationMs;const r=summarizeReplayMeasurements(report,options);assert.equal(r.timingComparisonValid,false);assert.equal(r.measuredSteadyTargetMet,false);assert.ok(r.warnings.length);}
});
test('canonical extraction rejects absent captures or inconsistent final areas',()=>{assert.throws(()=>canonicalReplayObjects({views:[],archive:{manifest:{eventsSha256:hash}}}),/Verified capture/);assert.throws(()=>canonicalReplayObjects({views:[{context:'context-1',event:{view:{areaId:9}}}],archive:{manifest:{eventsSha256:hash}},records:[]}),/final area/);});
test('100-microsecond clock quantization permits only floating-point roundoff at its boundary',()=>{const{report,options}=fixture(),m=report.measurements[0];m.start.elapsedMs=250740.2000000002;m.end.elapsedMs=270939.0999999996;m.frames.durationMs=20199;assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);m.end.elapsedMs-=.01;assert.throws(()=>summarizeReplayMeasurements(report,options),/endpoint clock/);});
test('new particle/light/submission modes require observed runtime application at both endpoints',()=>{
 for(const mode of ['particle-frame','particle-lean','particle-lights','light-records','lean-submit','lean-all']){
  const{report,options}=fixture();for(const index of [1,2]){const m=report.measurements[index];m.mode=mode;m.frames.label=index+':'+mode;report.measurementPlan.modes[index]=mode;for(const s of [m.start,m.end])s.experiment=mode;}
  assert.throws(()=>summarizeReplayMeasurements(report,options),/not exercised|not disabled/);
 }
});
test('command timing requires activated submission and the requested merged backend at both endpoints',()=>{
 for(const mode of ['command-batches','command-all','merged-batches','merged-all']){
  const{report,options}=fixture();for(const index of [1,2]){const m=report.measurements[index];m.mode=mode;m.frames.label=index+':'+mode;report.measurementPlan.modes[index]=mode;
   for(const s of [m.start,m.end]){s.experiment=mode;s.runtimeOptions={particleFrameStorage:true,lightOnlyMembership:true};for(const key of ['batches','materialReuse','lightUniforms'])s.performance.telemetry[key]={enabled:false};s.commandBatches={enabled:true,merged:mode.startsWith('merged-'),disabled:false,failure:null,batches:2,instances:10,draws:2,originalDraws:10};}
  }
  assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);
  for(const change of [s=>s.commandBatches.disabled=true,s=>s.commandBatches.failure='failed',s=>s.commandBatches.instances=0,s=>s.commandBatches.draws=10,...(mode.startsWith('merged-')?[s=>s.commandBatches.merged=false]:[])]){const copy=structuredClone(report);change(copy.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(copy,options),/not exercised/);}
 }
});
test('shared frame measurements require actual reuse while all unrelated owners retain baseline state',()=>{
 const{report,options}=fixture();for(const m of report.measurements)for(const s of [m.start,m.end]){s.runtimeOptions={particleFrameStorage:false,lightOnlyMembership:false,sharedMembership:false};for(const key of ['batches','materialReuse','lightUniforms'])s.performance.telemetry[key]={enabled:true};}
 for(const index of [1,2]){const m=report.measurements[index];m.mode='shared-frame';m.frames.label=index+':shared-frame';report.measurementPlan.modes[index]='shared-frame';for(const s of [m.start,m.end]){s.experiment=m.mode;s.runtimeOptions.sharedMembership=true;s.flatScene={shared:true,membershipObjects:3};s.shadowTraversal={membership:'prepared'};}}
 assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);
 for(const change of [s=>s.runtimeOptions.sharedMembership=false,s=>s.shadowTraversal.membership='hierarchy',s=>s.performance.telemetry.batches.enabled=false,s=>s.runtimeOptions.particleFrameStorage=true]){const copy=structuredClone(report);change(copy.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(copy,options),/not exercised|unrelated/);}
});
test('warm dispatch cannot report activated without the private bridge and completed fast draws',()=>{
 const{report,options}=fixture();for(const index of [1,2]){const m=report.measurements[index];m.mode='warm-draws';m.frames.label=index+':warm-draws';report.measurementPlan.modes[index]=m.mode;for(const s of [m.start,m.end]){s.experiment=m.mode;s.runtimeOptions={particleFrameStorage:true,lightOnlyMembership:true};for(const key of ['batches','materialReuse','lightUniforms'])s.performance.telemetry[key]={enabled:false};s.warmDraws={enabled:true,bridge:1,fast:100,ordinary:2};}}
 assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);for(const change of [s=>s.warmDraws.bridge=0,s=>s.warmDraws.fast=0,s=>s.warmDraws.enabled=false]){const copy=structuredClone(report);change(copy.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(copy,options),/not exercised/);}
});

test('prepared shadow caching requires actual current source draws and GPU storage',()=>{const{report,options}=fixture();for(const index of [1,2]){const m=report.measurements[index];m.mode='prefix-draws';m.frames.label=index+':prefix-draws';report.measurementPlan.modes[index]=m.mode;for(const s of [m.start,m.end]){s.experiment=m.mode;s.runtimeOptions={particleFrameStorage:true,lightOnlyMembership:true,sharedMembership:true};for(const key of ['batches','materialReuse','lightUniforms'])s.performance.telemetry[key]={enabled:false};s.warmDraws={enabled:true,bridge:1,fast:100};s.scenePlan={enabled:true,bridge:1,shared:true,projected:100};s.shadowPrefix={enabled:true,restored:1,prefixObjects:20,suffixObjects:10,bytes:16384};}}assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);for(const change of [s=>s.shadowPrefix.restored=0,s=>s.shadowPrefix.suffixObjects=0,s=>s.shadowPrefix.bytes=0,s=>s.shadowPrefix.failure='copy failed',s=>s.scenePlan.shared=false]){const copy=structuredClone(report);change(copy.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(copy,options),/not exercised/);}});

test('spatial visibility timing requires actual indexed bounds and plane traversal at both endpoints',()=>{
 const{report,options}=fixture();for(const index of [1,2]){
  const m=report.measurements[index];m.mode='spatial-draws';m.frames.label=index+':spatial-draws';report.measurementPlan.modes[index]=m.mode;
  for(const [which,s]of [m.start,m.end].entries()){
   s.experiment=m.mode;s.runtimeOptions={particleFrameStorage:true,lightOnlyMembership:true,sharedMembership:true};
   for(const key of ['batches','materialReuse','lightUniforms'])s.performance.telemetry[key]={enabled:false};
   s.matrixCooperation={cooperation:true,owners:1,skipped:which};s.warmDraws={enabled:true,bridge:1,fast:100};
   s.scenePlan={enabled:true,bridge:1,shared:true,projected:100,spatial:{indexed:110,fallback:10,members:120,nodes:17,planeTests:36}};
   s.shadowPrefix={enabled:true,restored:1,prefixObjects:20,suffixObjects:10,bytes:16384};
  }
 }
 assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);
 for(const change of [s=>delete s.scenePlan.spatial,s=>s.scenePlan.spatial.indexed=0,s=>s.scenePlan.spatial.planeTests=0,s=>s.scenePlan.spatial.members++]){
  const copy=structuredClone(report);change(copy.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(copy,options),/spatial visibility was not exercised/);
 }
});

test('compiled pass and shared ancestry require independent observed activation at both endpoints',()=>{for(const mode of ['compiled-main','ancestor-poses','packet-main']){const {report,options}=fixture();for(const index of [1,2]){const m=report.measurements[index];m.mode=mode;m.frames.label=index+':'+mode;report.measurementPlan.modes[index]=mode;for(const [which,s]of [m.start,m.end].entries()){s.experiment=mode;s.runtimeOptions={particleFrameStorage:true,lightOnlyMembership:true,sharedMembership:true};for(const name of ['batches','materialReuse','lightUniforms'])s.performance.telemetry[name]={enabled:false};s.matrixCooperation={cooperation:true,owners:1,skipped:which};s.scenePlan={enabled:true,bridge:1,shared:true,projected:100};s.shadowPrefix={enabled:true,restored:1,prefixObjects:20,suffixObjects:10,bytes:16384};s.warmDraws={enabled:mode==='ancestor-poses',bridge:1,fast:100};s.compiledPass={enabled:mode!=='ancestor-poses',prepared:true,replayed:1,draws:100,commands:1000,packetBlocks:8,packetCommands:1000};s.particlePoses={ancestors:{enabled:mode==='ancestor-poses',reused:10,fallback:false}};}}assert.equal(summarizeReplayMeasurements(report,options).timingComparisonValid,true);const changes=mode==='packet-main'?[s=>s.compiledPass.packetBlocks=0,s=>s.compiledPass.packetCommands=0,s=>s.compiledPass.replayed=0]:mode==='compiled-main'?[s=>s.compiledPass.replayed=0,s=>s.compiledPass.prepared=false,s=>s.compiledPass.commands=0]:[s=>s.particlePoses.ancestors.enabled=false,s=>s.particlePoses.ancestors.reused=0];for(const change of changes){const copy=structuredClone(report);change(copy.measurements[1].end);assert.throws(()=>summarizeReplayMeasurements(copy,options),/not exercised/);}}});
