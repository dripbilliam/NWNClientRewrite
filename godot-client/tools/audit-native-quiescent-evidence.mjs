// Evidence reduction only: never runs a renderer, server, compiler or benchmark.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const label=process.argv[2];if(!/^native-world-quiescent-evidence-[a-z0-9-]+$/.test(label??''))throw Error('Supply a fresh evidence label');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function input(relative){const bytes=fs.readFileSync(path.join(project,relative));return {file:relative,sha256:hash(bytes),value:JSON.parse(bytes)};}
const names=['a-cold-v1','b-cold-v1','b-warm-v1','a-warm-v1','a-unprofiled-v1','b-unprofiled-v1','b-unprofiled-v2'];
let referenceView;
const runs=names.map(name=>{
 const source=input('reports/native-dense-quiescent-'+name+'.json'),r=source.value,n=r.native,w=n.world;
 const owner=input('.cache/native-dense-area/native-dense-quiescent-v2/native-dense-quiescent-'+name+'-owner.json');
 if(!r.success||!r.steadyCompleted||!r.profilingMatched||!r.sourceUnchanged||!r.runtimeUnchanged||!r.driverUnchanged||!n.clean_exit||!n.protocol_finish_ack||!n.performance_window.steady||n.performance_window.elapsed_ms<30000||w.entities!==2741||w.terrain.rendered_tiles!==192||!owner.value.closed||owner.value.exit!==0||owner.value.changedGuards.length||owner.value.protectedProcesses.some(p=>!p.unchanged))throw Error('Completion/ownership gate failed: '+name);
 referenceView??=n.benchmark_begin_view;
 const viewMatched=JSON.stringify(referenceView)===JSON.stringify(n.benchmark_begin_view)&&JSON.stringify(referenceView)===JSON.stringify(n.benchmark_end_view)&&referenceView.focused===false&&referenceView.unfocusable===true;
 if(n.presentation_state.detailed_profiling&&!viewMatched)throw Error('Instrumented view/focus witness changed: '+name);
 const exclusionReasons=[];
 if(!viewMatched)exclusionReasons.push('Beginning/end camera, viewport or focus witness differs from the common unfocused view; exclude from a matched FPS comparison.');
 if(name==='b-unprofiled-v1')exclusionReasons.push('Ghidra dossier queries overlapped this measurement; exclude from a clean FPS comparison.');
 const m=r.lastObservation.frame_profile?.metrics||{};
 return {name,report:source.file,sha256:source.sha256,ownerSha256:owner.sha256,profiled:n.presentation_state.detailed_profiling,scope:n.presentation_state.scope,steadyWindow:n.performance_window,frames:n.frame_intervals,meanFps:1000/n.frame_intervals.average_ms,worldCallbackMs:m.callback_world?.mean??null,particleCallbackMs:m.callback_particles?.mean??null,draws:m.draws?.mean??n.presentation_state.draws,triangles:m.triangles?.mean??n.presentation_state.triangles,nodes:m.nodes?.mean??n.presentation_state.nodes,preparedEmitters:w.native_particle_stream.native.prepared,registeredEmitters:w.native_particle_stream.native.registered,settledObservedMs:r.settledAt,postprocessInputError:n.gamma?.scene_inputs?.error??'',beginView:n.benchmark_begin_view,endView:n.benchmark_end_view,viewMatched,cleanFpsExcluded:exclusionReasons.length>0,exclusionReasons};
});
const nativeGate=input('reports/native-world-quiescent-v3.json');if(!nativeGate.value.success||nativeGate.value.checks!==236)throw Error('Native correctness gate failed');
const localNames=['native-world-quiescent-local-v1','native-world-quiescent-local-baseline-v1'];
const local=localNames.map(run=>{
 const host=input('reports/'+run+'.json'),native=input('reports/'+run+'.native.json'),owner=input('reports/'+run+'.owner.json');
 if(!host.value.success||host.value.localCycles?.length!==2||!native.value.clean_exit||!native.value.protocol_finish_ack||!owner.value.closed||owner.value.exit!==0||owner.value.changedGuards.length||owner.value.protectedProcesses.some(p=>!p.unchanged))throw Error('Original-local ownership/movement gate failed: '+run);
 for(const c of host.value.localCycles)if(!(c.nativeDistance>0.2&&Math.abs(c.nativeDistance-c.serverDistance)<0.001&&c.state.entities+c.state.hidden===c.state.desired&&c.state.pending_batches===0))throw Error('Original-local movement/publication mismatch');
 return {run,report:host.file,sha256:host.sha256,nativeSha256:native.sha256,ownerSha256:owner.sha256,cycles:host.value.localCycles.map(c=>({connection:c.connection,generation:c.generation,areaId:c.areaId,nativeDistance:c.nativeDistance,serverDistance:c.serverDistance,entities:c.state.entities,desired:c.state.desired,pendingBatches:c.state.pending_batches})),desktopProof:host.value.desktopProof,renderSettingsProof:host.value.renderSettingsProof};
});
if(JSON.stringify(local[0].desktopProof)!==JSON.stringify(local[1].desktopProof))throw Error('Headless desktop proof differs');
const pose=input('reports/native-particle-pose-cache-v2.json');if(!pose.value.success||pose.value.result.checks!==10166||pose.value.changed.length)throw Error('Pose-cache primitive gate failed');
const candidate='systems/native_render/live_world_quiescent_candidate.gd';
const testedCandidate=nativeGate.value.sourcePins.find(p=>p.relative===candidate);
if(hash(fs.readFileSync(path.join(project,candidate)))!==testedCandidate.sha256)throw Error('Current planner differs from verified native gate');
const entry=fs.readFileSync(path.join(project,'native_live_world.gd'));
if(!entry.toString().includes('const World=preload("res://systems/native_render/live_world_quiescent_candidate.gd")'))throw Error('Normal entry does not select verified planner');
const quietA=runs.find(r=>r.name==='a-unprofiled-v1'),quietB=runs.find(r=>r.name==='b-unprofiled-v2');
const report={success:true,scope:'Scoped planning-work reduction, not 140 FPS, loading, full graphics/UI or native-client parity acceptance.',currentIntegration:{entry:'native_live_world.gd',entrySha256:hash(entry),candidate,candidateSha256:testedCandidate.sha256,enabled:true,sharedNativeBuilds:0},nativeCorrectness:{file:nativeGate.file,sha256:nativeGate.sha256,checks:236},view:referenceView,runs,localChecks:local,headlessDesktopLimitation:'Both paths have map_art=0 and desktop success=false with all compared proof fields equal; do not claim full UI acceptance.',unprofiledConclusion:{fpsGainAccepted:false,matchedPair:!quietA.cleanFpsExcluded&&!quietB.cleanFpsExcluded,baselineMeanMs:quietA.frames.average_ms,candidateMeanMs:quietB.frames.average_ms,note:'No overall unprofiled FPS improvement established. Quiet candidate repeat averaged20.893ms; baseline20.781ms began focused and ended unfocused, so this is not a matched pair. Earlier candidate overlapped Ghidra. The instrumented World-owner CPU saving is established; do not extrapolate it to total unprofiled FPS.'},fixtureLimitation:'Both variants lack the recorded inc_common:2069 shader payload; actual live postprocess inputs were bound. Captured-scene comparisons do not prove equivalent full live-room rendering.',posePrimitive:{file:pose.file,sha256:pose.sha256,checks:10166,integrated:false,scope:pose.value.scope},backup:{file:'../backups/native-140fps-planning-before-v1.zip',sha256:'a0579968002401f5564351e39cb7db8c6ac43867b75189cd013c7617d48bf6ea',entries:14,readbackVerified:true},nextPriority:'Research duplicated/needless per-frame work and native spatial/tile/object visibility before further micro-optimization.',goalComplete:false};
const file=path.join(project,'reports',label+'.json');fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,file,sha256:hash(fs.readFileSync(file)),nativeChecks:236,localCycles:4,poseChecks:10166,integrated:true,unprofiledFpsGainAccepted:false,goalComplete:false}));
