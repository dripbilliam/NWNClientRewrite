import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const root=path.join(project,'.cache/native-render-gap/particles/live-host-review-a');
if(fs.existsSync(root)) throw Error('Preserve previous evidence');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=relative=>{const file=path.join(project,relative),b=fs.readFileSync(file);if(b.length>4*1024*1024)throw Error('Bound exceeded: '+relative);return {file,bytes:b.length,sha256:sha(b),buffer:b};};
const pin=relative=>{const {buffer,...r}=read(relative);return r;};
const parse=relative=>JSON.parse(read(relative).buffer);
const oldRelative='.cache/native-presentation-parity/production-replay/fps-max-v1-ordinary-workers-b/project/tools/native-session-host.cjs';
const old=read(oldRelative),current=read('tools/native-session-host.cjs');
const expectedOld='f745497be373f8fdea267c30b584b4ebd5e375e111fe6826f2d70b0f2b985bc0';
if(old.sha256!==expectedOld)throw Error('Historical exact source differs');
const startup=parse('reports/native-live-fps-pending-a.startup.json');
if(startup.source.files.find(x=>x.file==='tools/native-session-host.cjs')?.sha256!==old.sha256)throw Error('Startup source pin differs');
const base='.cache/native-presentation-parity/root/fps-max-v1/manual-arelith-pending-a/';
const review=parse(base+'completed-review-a/analysis.json');
const host=parse('reports/native-live-fps-pending-a.json');
const launch=parse(base+'launch.json');
const policy=parse('.cache/native-render-gap/promotions/normal-d-a/post-install-defaults.json');
const oldText=old.buffer.toString(),currentText=current.buffer.toString();
function anchored(text,first,last){const start=text.indexOf(first),end=text.indexOf(last,start);if(start<0||end<start)throw Error('Source anchor missing');return {firstLine:text.slice(0,start).split('\n').length,lastLine:text.slice(0,end).split('\n').length,text:text.slice(start,end+last.length)};}
const anchors={
 registry:anchored(oldText,'const serial=++rawSerial','if(!changed)return;'),
 timer:anchored(oldText,'timer=setInterval(()=>{','},200);'),
 profileToggle:anchored(oldText,'function setHostProfiling(value)','else hostDelay.disable();}'),
 profileSample:anchored(oldText,"if(message.frame_profile?.enabled!==false&&message.frame_profile?.metrics&&Date.now()-profileAt>=2000)","await fs.appendFile(path.join(project,'reports',run+'.performance.jsonl'),JSON.stringify(sample)+'\\n');"),
 recordingGate:anchored(oldText,"const recordLoading=process.argv.includes('--record-loading')",'recordingCatalog=0;')
};
const registryCurrent=anchored(currentText,'const serial=++rawSerial','if(!changed)return;');
if(anchors.registry.text!==registryCurrent.text)throw Error('Current transport projection unexpectedly differs');
const profileCurrent=anchored(currentText,"if(message.frame_profile?.enabled!==false&&message.frame_profile?.metrics&&Date.now()-profileAt>=2000)","await fs.appendFile(path.join(project,'reports',run+'.performance.jsonl'),JSON.stringify(sample)+'\\n');");
const rows=review.rows.filter(r=>r.insideScope);
const movingStable=rows.filter(r=>r.motion==='mostly-active'&&r.populationStable);
const movingSettled=rows.filter(r=>r.motion==='mostly-active'&&r.assets==='settled');
if(movingStable.length||movingSettled.length||!startup.arguments.includes('--profile=true'))throw Error('Historical conclusion differs');
if(!policy.performance.nativeArguments.includes('--profile=false')||policy.performance.renderCore.diagnosticTimers!==false)throw Error('D default profile differs');
const summarize=g=>({scope:g.scope,motion:g.motion,assets:g.assets,windows:g.overlapping.windows,stablePopulationWindows:g.stablePopulationOnly.windows,entities:g.overlapping.entities,fpsSnapshotMedian:g.overlapping.sampledFpsMedian,meanWindowMetrics:Object.fromEntries(['wall_ms','world_motion_update_ms','world_poses','callback_particles','callback_rigs','callback_light_history','callback_native_lighting','render_setup_cpu_ms','render_gpu_ms','physics_ms','count_pending_batches','count_asset_workers'].map(n=>[n,g.overlapping.meanWindowMetrics[n]]))});
const out={version:1,createdUtc:new Date().toISOString(),success:true,kind:'bounded-existing-evidence-source-review',
 inputs:{historicalHost:{...pin(oldRelative),startupPinned:true},currentHost:pin('tools/native-session-host.cjs'),startup:pin('reports/native-live-fps-pending-a.startup.json'),launch:pin(base+'launch.json'),opened:pin(base+'opened.json'),completedReview:pin(base+'completed-review-a/analysis.json'),analysisProducer:pin('tools/native-movement-review/analyze-manual.cjs'),promotedDefaults:pin('.cache/native-render-gap/promotions/normal-d-a/post-install-defaults.json'),offlineReplaySource:pin('tools/replay-native-loading.mjs')},
 historical:{application:review.source,profile:review.profile,areas:[...new Set(rows.map(r=>r.scope))],rawWorldUpdates:review.session.rawWorldUpdates,launchDetailedProfiling:launch.profiling,nativeProfileArgument:'--profile=true',recording:{launchExplicitLoadingRecording:false,reportNativeLoadingArguments:host.nativeLoadingArguments,reportRecordingFields:Object.keys(host).filter(k=>/recording/i.test(k)),conclusion:'No loading recorder was enabled in this retained run; loadingRecording remains null without --record-loading.'}},
 sourceAnchors:Object.fromEntries(Object.entries(anchors).map(([name,a])=>[name,{firstLine:a.firstLine,lastLine:a.lastLine,sha256:sha(a.text),excerpt:name==='timer'?undefined:a.text}])),
 currentComparison:{source:policy.source,currentRegistryProjectionSameBytes:true,currentRegistryLines:[registryCurrent.firstLine,registryCurrent.lastLine],profileSampleSameBytes:anchors.profileSample.text===profileCurrent.text,currentDefaultProfile:'--profile=false',currentDiagnosticTimers:false},
 findings:[
 'The ordinary live host attempts a full registry transport-row projection plus inventory/UI container materialization every200ms when authenticated, catalog-ready, area-ready and not waiting for a previous raw acknowledgement. This constructs all rows BEFORE worldDeltas.plan and the no-change return.',
 'This work is ordinary live-network transport, not an optional recorder. Changed frames are serialized and sent only after the delta planner; movement messages are a separate presentation route. The same projection-before-delta block remains byte-identical in promoted D host source.',
 'The offline replay reads a checksummed recorded timeline (replay-native-loading.mjs43-47), reports offline:true/gameNetworkConnections:0 (line110), and sends retained events. It does not reconstruct a live protocol registry through this host transport-row projection.',
 'The historical manual run enabled detailed native profiling. Its host enabled the20ms-resolution event-loop-delay monitor and appended serialized performance samples no more frequently than once per2s. Promoted D defaults detailed profiling and diagnostic timers OFF.',
 'These are two actual live-versus-offline differences worth measuring separately. No retained evidence assigns either difference a30FPS cost or demonstrates a movement-triggered increase in the full-registry projection itself.'
 ],
 matching:{ready240FrameWindows:rows.length,movingPopulationStableWindows:movingStable.length,movingSettledWindows:movingSettled.length,stationarySettledPopulationStableWindows:rows.filter(r=>r.motion==='stationary'&&r.assets==='settled'&&r.populationStable).length,matchedStableMovementComparisonAvailable:false,groups:review.groups.map(summarize)},
 attribution:{collision:'world_motion_update_ms and aggregate physics_ms exist; no isolated path/support/actual collision-query timer in the compact analysis. particle_frame_collision_indices_ms is preparation, not a collision-query timer.',poses:'world_poses and callback_rigs exist; their sample workloads/populations differ.',lighting:'callback_light_history/native-lighting exist; raw samples also retain focus_lighting and point_shadows, but the compact comparison does not hold those populations/budgets constant.',renderer:'render_setup_cpu_ms grows in some moving groups, but is asynchronous RT setup wall time. GPU wall time stays roughly3.5–4.5ms in old group means. Neither identifies a unique moving cause.',conclusion:'The old capture separates broad envelopes but cannot isolate translation-specific cost from changed population, streaming, camera/admission, FX or detailed observability.'},
 nextMeasurement:'On promoted D, measure equal-area, equal-population, fully warmed idle vs actor translation with default profiling OFF. Separately sample live host projection/delta/serialization CPU and native raw-update adoption. Compare an ordinary live route against offline replay without adding a recorder. Preserve transport/disclosure ordering and mutation semantics before any dirty-row or static-prefix optimization.',
 limits:[...review.limits,'This review reused the existing compact64-observation analysis and bounded source files; it did not rerun the client, scan all raw profile records, rescan logs, or change product bytes.','The host is a separate process. Its CPU work and transport cadence are not directly additive to native main-thread frame time; contention/backpressure/synchronization must be measured.','The old native_live_world.gd found in the replay derivative has a different startup SHA and is not used here as exact historical native snapshot-source evidence.','No causal FPS or currentD movement-regression claim follows from this historical review.']};
fs.mkdirSync(root,{recursive:true});fs.writeFileSync(path.join(root,'receipt.json'),JSON.stringify(out,null,2)+'\n');
console.log(JSON.stringify({file:path.join(root,'receipt.json'),sha256:sha(fs.readFileSync(path.join(root,'receipt.json'))),success:true,movingStable:movingStable.length,movingSettled:movingSettled.length,currentRegistryProjectionSameBytes:true}));
