// Receipt audit only: no game connection, asset parsing or rendering.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const reports=path.join(project,'reports');
const phase=process.argv.find(value=>value.startsWith('--phase='))?.slice(8)??'clips';
if(!['optimized','compiled','prefetch','ancestors','raster','mesh','transitions','typed','cache','skin','clips'].includes(phase))throw Error('Unknown native loading audit phase');
const cachePhase=['cache','skin','clips'].includes(phase),typedPhase=['typed','cache','skin','clips'].includes(phase),transitionPhase=['transitions','typed','cache','skin','clips'].includes(phase);
const meshPhase=['mesh','transitions','typed','cache','skin','clips'].includes(phase),rasterPhase=['raster','mesh','transitions','typed','cache','skin','clips'].includes(phase);
const ancestorPhase=['ancestors','raster','mesh','transitions','typed','cache','skin','clips'].includes(phase),entryPhase=['prefetch','ancestors','raster','mesh','transitions','typed','cache','skin','clips'].includes(phase);
const artifactPrefix=phase==='clips'?'native-loading-clips-default':phase==='skin'?'native-loading-skin-default':phase==='cache'?'native-loading-cache-default':phase==='typed'?'native-loading-typed-final':phase==='transitions'?'native-loading-transition-default':'native-loading-mesh-default';
const currentPrefix=phase==='clips'?'native-loading-clips-suite':phase==='skin'?'native-loading-skin-suite':phase==='cache'?'native-loading-cache-verified-suite':phase==='typed'?'native-loading-typed-suite':phase==='transitions'?'native-loading-transition-verified-suite':phase==='mesh'?'native-loading-mesh-suite':phase==='raster'?'native-loading-raster-suite':'native-loading-ancestor-verified-suite';
const run=process.argv.find(value=>value.startsWith('--run='))?.slice(6)??'native-loading-'+phase+'-audit-'+Date.now();
if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid audit run name');
const read=async name=>JSON.parse(await fs.readFile(path.join(reports,name+'.json'),'utf8'));
const checkEngineLog=async name=>{
 const text=await fs.readFile(path.join(reports,name+'.engine.log'),'utf8');
 if(/SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use|Unicode parsing error/m.test(text))throw Error('Full engine log contains an error: '+name);
};
const required=[['index',11],['coalescing',12],['publication',12],['session-cache',18],['ordering',20],['adoption',6],['retirement',transitionPhase?78:72],['recording',17],['source-bytes',15],['nwsync',38],['data-retirement',12],['actor-retirement',10],['packed-keys',67],['ascii',15],['tables',30],['table-cost',23],['prepared-cache',16],['inheritance',16]];
if(phase!=='optimized')required.push(['validation',252],['persistent-actors',14]);
if(entryPhase)required.push(['entry-prefetch',9]);
if(ancestorPhase)required.push(['actor-failure',27],['static-failure',28],['ancestors',42]);
if(rasterPhase)required.push(['raster-pixels',608],['palette-preparation',25]);
if(meshPhase)required.push(['mesh-preparation',846],['mesh-cache',14],['failed-model',10],['postdraw',8],['icon-reuse',20]);
if(transitionPhase)required.push(['retirement-physics',10]);
if(typedPhase)required.push(['ascii-typed',81],['ui-data-retirement',20]);
if(cachePhase)required.push(['prepared-writer',27],['cache-paths',13]);
if(['skin','clips'].includes(phase))required.push(['skin-stream',277],['skin-cache',12]);
if(phase==='clips')required.push(['clip-index',81]);
const native=[];
for(const [name,checks]of required){
 const run=ancestorPhase?currentPrefix+'-'+name+'-v1':phase!=='optimized'?'native-loading-'+phase+'-suite-'+name+'-v1':name==='inheritance'?'native-loading-final-inheritance-v2':'native-loading-final-suite-'+name+'-'+(name==='source-bytes'?'v4':'v3');
 const proof=await read(run+'.debugger'),result=await read(run);
 if(!proof.success||!proof.armed||!proof.normalHeap||proof.exceptionTraps!==4||proof.exception||proof.engineOrLifetimeError||!proof.sourceUnchanged||!result.success||result.checks!==checks)throw Error('Unaccepted native receipt: '+run);
 for(const [relative,digest]of Object.entries(proof.sourceSha256)){
  const current=createHash('sha256').update(await fs.readFile(path.join(project,relative))).digest('hex');
  if(current!==digest)throw Error('Native sources changed after receipt: '+relative);
 }
 native.push({run,checks,success:true});
}
const comparisons=[];
for(const generation of [3,4]){
 const oldName='native-loading-generation'+generation+'-baseline-v1';
 const newName=meshPhase?artifactPrefix+'-area'+generation+'-v1':phase==='raster'?(generation===3?'native-loading-raster-final-candidate-v2':'native-loading-raster-area4-candidate-v1'):phase==='ancestors'?(generation===3?'native-loading-ancestor-world-candidate-v2':'native-loading-ancestor-area4-candidate-v1'):phase==='prefetch'?(generation===3?'native-loading-entry-prefetch-candidate-v1':'native-loading-entry-prefetch-area4-candidate-v1'):generation===3?(phase==='compiled'?'native-loading-deferred-axis-world-v1':'native-loading-generation3-packed-ascii-v1'):'native-loading-generation4-optimized-v1';
 const old=await read(oldName),next=await read(newName);
 for(const [name,receipt]of [[oldName,old],[newName,next]]){
  if(!receipt.success||receipt.exit!==0||!receipt.offline||receipt.gameNetworkConnections!==0||!receipt.timelineDelivered||!receipt.sourceUnchanged||!receipt.debuggerArmed||receipt.nativeException||receipt.engineOrLifetimeError||receipt.native.workers_remaining!==0||!receipt.native.protocol_finish_ack||!receipt.native.object_visuals_complete)throw Error('Unaccepted complete-area replay: '+name);
  await checkEngineLog(name);
 }
 comparisons.push({generation,baseline:oldName,optimized:newName,baselinePlayerMs:old.native.world.playable_ms,optimizedPlayerMs:next.native.world.playable_ms,optimizedTerrainCompleteMs:next.native.world.terrain.complete_ms,optimizedCameraAnchorMs:next.native.world.camera_anchor_ms,entities:next.native.world.entities,desired:next.native.world.desired,scope:'Cold prepared cache; same frozen input and engine/driver; OS/driver caches not flushed. Earlier baseline lacks preview opt-out. Not clean FPS or original-executable timing acceptance.'});
}
const sweepRun=meshPhase?artifactPrefix+'-five-area-v1':phase==='raster'?'native-loading-raster-default-five-area-v1':phase==='ancestors'?'native-loading-ancestor-default-five-area-v1':phase==='prefetch'?'native-loading-prefetch-default-five-area-v1':phase==='compiled'?'native-loading-compiled-five-area-v1':'native-loading-final-five-area-v1';
const sweep=await read(sweepRun);
await checkEngineLog(sweepRun);
if(sweep.success||!sweep.offline||sweep.gameNetworkConnections!==0||!sweep.timelineDelivered||!sweep.sourceUnchanged||!sweep.debuggerArmed||sweep.nativeException||sweep.engineOrLifetimeError||sweep.native.workers_remaining!==0||!sweep.native.protocol_finish_ack)throw Error('Five-area partial receipt differs from its declared scope');
const errors=[...(sweep.native.world.errors??[]),...Object.values(sweep.native.world.failed_objects??{}).map(row=>row.error)];
if(!errors.length||errors.some(error=>!String(error.reason??'').startsWith('Unrecorded native resource:')))throw Error('Unexpected full-sweep error outside known capture gaps');
const local=await read('native-loading-final-prelude-gameplay-v1');
if(!local.success||!local.sourceUnchanged||!local.debuggerArmed||local.nativeException||local.engineErrors||local.debuggerExit!==0||local.publicConnections!==0||local.requestedTransitions!==3||local.completedTransitions!==3||local.native.workers_remaining!==0||!local.native.protocol_finish_ack)throw Error('Local gameplay integration receipt is incomplete');
const output={createdAt:new Date().toISOString(),success:true,nativeChecks:native.reduce((sum,row)=>sum+row.checks,0),native,comparisons,fiveArea:{run:'native-loading-final-five-area-v1',completeWorldAccepted:false,timelineDelivered:true,nativeCrash:false,engineOrLifetimeError:false,explicitCaptureGaps:errors.length,workersRemaining:0},local:{run:'native-loading-final-prelude-gameplay-v1',success:true,server:'127.0.0.1:5121',completedTransitions:3,keyboardReleased:local.native.keyboard_probe.released,inventoryOpenWhileMoving:local.native.keyboard_probe.inventory_open,strafeDistances:local.native.strafe_probes.map(row=>({key:row.key,distance:row.distance,facingDot:row.minimum_facing_dot})),scope:'Authoritative Prelude click/keyboard movement, inventory/reopen, examine/dialogue and three door transitions; not complete combat, original visual or mixed-client parity acceptance'},knownFailedReceipts:[{run:'native-loading-final-suite-source-bytes-v3',reason:'Runner omitted required authored --fixture argument; native exited 2 before checks. Retained; corrected v4 supplies it.'}],publicConnections:0,performanceAccepted:false,fullGameplayAccepted:false,goalComplete:false,optimizationPhaseStartedAt:'2026-10-27T10:21:32Z',minimumOptimizationPhaseEndsAt:'2026-10-27T12:21:32Z'};
output.knownFailedReceipts.push({run:'native-loading-final-inheritance-v1',reason:'New fixture had an inferred Variant type rejected by GDScript; corrected explicit bool fixture passes v2. No production change.'});
const stress=await read('native-loading-final-prelude-eight-transitions-v1');
output.additionalStress={run:'native-loading-final-prelude-eight-transitions-v1',success:stress.success,nativeFailure:stress.native?.failure,completedTransitions:stress.completedTransitions,sourceUnchanged:stress.sourceUnchanged,nativeException:stress.nativeException,engineErrors:stress.engineErrors,scope:'Stopped at first closed campaign door without open acknowledgement. Not accepted as repeated-transition stress; no claim about the unobserved later transitions or server script cause.'};
output.phase=phase;
output.fiveArea.run=sweepRun;
if(entryPhase){
 output.entryComparisons=[];
 for(const stem of ['native-loading-entry-prefetch','native-loading-entry-prefetch-area4','native-loading-entry-prefetch-area1']){
  const before=await read(stem+'-reference-v1'),after=await read(stem+'-candidate-v1');
  await checkEngineLog(stem+'-reference-v1');await checkEngineLog(stem+'-candidate-v1');
  for(const receipt of [before,after])if(!receipt.sourceUnchanged||!receipt.offline||receipt.gameNetworkConnections!==0||receipt.nativeException||receipt.engineOrLifetimeError||!receipt.debuggerArmed||receipt.native.workers_remaining!==0||!receipt.native.protocol_finish_ack)throw Error('Entry comparison runtime proof failed: '+stem);
  if(JSON.stringify(before.sourceSha256)!==JSON.stringify(after.sourceSha256)||before.recordingSha256!==after.recordingSha256)throw Error('Entry comparison sources/recording differ: '+stem);
  const prior=before.native.world,next=after.native.world;
  const count=world=>world.admissions.filter(row=>[9,10].includes(row.kind)&&row.elapsed_ms<=world.playable_ms).length;
  if(prior.streaming_priority.entry_prefetch.enabled||!next.streaming_priority.entry_prefetch.enabled||next.entry_prefetch_batches!==1||next.entry_prefetch_objects!==8||count(next)!==8||count(prior)!==0)throw Error('Entry comparison did not exercise the expected bounded wave: '+stem);
  if(stem.endsWith('area1')){
   if(before.success||after.success||!before.measurement?.completed||!after.measurement?.completed||before.measurement.captureGaps.length!==4||after.measurement.captureGaps.length!==4||before.measurement.otherWorldErrors.length||after.measurement.otherWorldErrors.length)throw Error('Partial first-area coverage differs from declared scope');
  }else if(!before.success||!after.success)throw Error('Complete entry comparison failed: '+stem);
  output.entryComparisons.push({reference:stem+'-reference-v1',candidate:stem+'-candidate-v1',referencePlayerMs:prior.playable_ms,candidatePlayerMs:next.playable_ms,extraPlayerMs:next.playable_ms-prior.playable_ms,referenceSceneryBeforePlayer:count(prior),candidateSceneryBeforePlayer:count(next),completeWorldAccepted:!stem.endsWith('area1'),scope:'Same-source single observations, fresh prepared cache, OS/driver cache uncontrolled; local scenery readiness tradeoff, not statistical FPS or latency acceptance'});
 }
}
if(phase!=='optimized'){
 const loadRun=meshPhase?artifactPrefix+'-local-v1':phase==='raster'?'native-loading-raster-default-local-v1':phase==='ancestors'?'native-loading-ancestor-default-local-v1':phase==='prefetch'?'native-loading-entry-prefetch-default-local-v1':'native-loading-deferred-axis-local-v1';
 const load=await read(loadRun),nativeLoad=await read(loadRun+'.native');
 if(!load.success||!load.sourceUnchanged||!load.debuggerArmed||load.nativeException||load.nativeExit!==0||load.publicConnections!==0||!load.loadingRecording?.complete||nativeLoad.workers_remaining!==0||!nativeLoad.protocol_finish_ack||!nativeLoad.object_visuals_complete)throw Error('Current compiled-phase local loading receipt is incomplete');
 if(entryPhase&&nativeLoad.world.streaming_priority.entry_prefetch.enabled!==true)throw Error('Default entry prefetch was not enabled in the local run');
 if(ancestorPhase&&(nativeLoad.world.ancestor_preparation?.enabled!==true||nativeLoad.world.ancestor_preparation.active!==0||nativeLoad.world.ancestor_preparation.peak>2))throw Error('Default ancestor preparation was not enabled/bounded/drained in the local run');
 if(rasterPhase&&(!nativeLoad.world.raster_conversion?.enabled||!nativeLoad.world.raster_conversion.available||nativeLoad.world.ancestor_preparation.per_root!==1))throw Error('Current default raster/helper policy did not run locally');
 output.currentLocalLoad={run:loadRun,success:true,entities:load.native.world.entities,workersRemaining:0,scope:'Current native-library/decoder authoritative Prelude load and sealed resource capture; earlier three-transition gameplay receipt is retained separately'};
 output.nativeAbiRegressions=[];
 for(const [name,checks]of ancestorPhase?[[currentPrefix+'-vertices-v1',1227],[currentPrefix+'-geometry-v1',2137]]:phase==='prefetch'?[['native-loading-prefetch-suite-vertices-v1',1227],['native-loading-prefetch-suite-geometry-v1',2137]]:[['native-loading-compiled-particle-vertices-v1',1227],['native-loading-compiled-scene-geometry-v2',2137]]){
  const proof=await read(name+'.debugger'),result=await read(name);
  if(!proof.success||!proof.armed||proof.exception||proof.engineOrLifetimeError||!proof.sourceUnchanged||result.checks!==checks)throw Error('Native ABI regression failed: '+name);
  for(const [relative,digest]of Object.entries(proof.sourceSha256))if(createHash('sha256').update(await fs.readFile(path.join(project,relative))).digest('hex')!==digest)throw Error('ABI regression sources changed: '+relative);
  output.nativeAbiRegressions.push({run:name,checks});
 }
 output.knownFailedReceipts.push({run:'native-loading-persistent-actors-v1',reason:'New fixture used Array.all on PackedStringArray and omitted required CLI fixture argument. Corrected Array conversion and invocation pass v2/current compiled suite.'},{run:'native-loading-compiled-scene-geometry-v1',reason:'Runner selected a nonexistent script name; actual native_scene_geometry_kernel_test.gd passes v2. No production repair or waived assertion.'});
}
if(ancestorPhase){
 const observations=(await fs.readFile(path.join(reports,sweepRun+'.performance.jsonl'),'utf8')).trim().split('\n').map(JSON.parse);
 output.readinessByArea=[];
 for(const generation of [1,2,3,4,5]){
  const rows=observations.filter(row=>row.state.generation===generation);
  const readyRows=rows.filter(row=>Number(row.state.playable_ms)>0);
  if(readyRows.length<2||readyRows.some(row=>!row.state.ready||row.state.errors.length))throw Error('Player readiness regressed during frozen area '+generation);
  output.readinessByArea.push({generation,samples:rows.length,readySamples:readyRows.length,readinessRevocations:0,maxFailedObjects:Math.max(...rows.map(row=>Object.keys(row.state.failed_objects??{}).length))});
 }
 const budget=sweep.native.world.ancestor_preparation;
 if(!budget.enabled||budget.active!==0||budget.peak>2)throw Error('Final default source helpers are not enabled/bounded/drained');
 output.ancestorComparisons=[];
 for(const [reference,candidate]of [['native-loading-ancestor-world-reference-v2','native-loading-ancestor-world-candidate-v2'],['native-loading-ancestor-area4-reference-v1','native-loading-ancestor-area4-candidate-v1']]){
  const before=await read(reference),after=await read(candidate);
  await checkEngineLog(reference);await checkEngineLog(candidate);
  for(const receipt of [before,after])if(!receipt.success||receipt.exit!==0||!receipt.sourceUnchanged||!receipt.offline||receipt.gameNetworkConnections!==0||!receipt.debuggerArmed||receipt.nativeException||receipt.engineOrLifetimeError||!receipt.native.object_visuals_complete||receipt.native.workers_remaining!==0||!receipt.native.protocol_finish_ack)throw Error('Ancestor comparison did not complete: '+reference);
  if(JSON.stringify(before.sourceSha256)!==JSON.stringify(after.sourceSha256)||before.recordingSha256!==after.recordingSha256)throw Error('Ancestor pair sources/recording differ: '+reference);
  const a=before.native.world,b=after.native.world;
  if(a.ancestor_preparation.enabled||!b.ancestor_preparation.enabled||b.ancestor_preparation.maximum!==2||b.ancestor_preparation.peak>2||b.ancestor_preparation.active!==0||a.entities!==b.entities||a.desired!==b.desired)throw Error('Ancestor pair ownership/coverage differs');
  output.ancestorComparisons.push({reference,candidate,referencePlayerMs:a.playable_ms,candidatePlayerMs:b.playable_ms,referenceTerrainMs:a.terrain.complete_ms,candidateTerrainMs:b.terrain.complete_ms,entities:b.entities,scope:'Same-source single paired observations; fresh prepared caches, uncontrolled OS/driver caches. Earlier generation-3 v1 pair is retained separately; not statistical FPS acceptance.'});
 }
 const suite=await read(currentPrefix+'.suite');
 if(!suite.success||suite.checks!==(phase==='clips'?6204:phase==='skin'?6123:phase==='cache'?5834:phase==='typed'?5794:phase==='transitions'?5693:phase==='mesh'?5677:phase==='raster'?4779:4146)||suite.cases.length!==(phase==='clips'?41:phase==='skin'?40:phase==='cache'?38:phase==='typed'?36:phase==='transitions'?34:phase==='mesh'?33:phase==='raster'?28:26))throw Error('Current loading suite manifest incomplete');
 output.currentSuite={run:currentPrefix+'.suite',checks:suite.checks,cases:suite.cases.length};
 const currentGameplay=await read('native-loading-ancestor-prelude-gameplay-v1');
 output.currentGameplay={run:'native-loading-ancestor-prelude-gameplay-v1',success:currentGameplay.success,completedTransitions:currentGameplay.completedTransitions,nativeFailure:currentGameplay.native?.failure,sourceUnchanged:currentGameplay.sourceUnchanged,nativeException:currentGameplay.nativeException,engineErrors:currentGameplay.engineErrors,scope:'Current local inventory/movement/dialogue attempt again stopped at the first campaign door with no open acknowledgement. Transition/gameplay acceptance remains false.'};
 if(currentGameplay.success||!currentGameplay.sourceUnchanged||currentGameplay.nativeException||currentGameplay.engineErrors||currentGameplay.completedTransitions!==0||currentGameplay.native?.failure!=='Original campaign door did not open')throw Error('Current local gameplay result differs from declared open gap');
 if(rasterPhase){output.historicalGameplayGap={...output.currentGameplay,scope:'Earlier ancestor-source gameplay attempt stopped at first campaign door; retained historical evidence, not current-raster gameplay acceptance.'};delete output.currentGameplay;}
 output.knownFailedReceipts.push({run:'native-loading-ancestor-suite-ascii-v1',reason:'New suite runner joined two PowerShell CLI arguments into one string; native exited 2 before assertions. Corrected runner quotes each argument; verified suite uses a new prefix. No production repair or waived checks.'});
}
if(rasterPhase){
 const originalOracle=await fs.readFile(path.join(project,'../backups/animations/native-tga-origin-v1.json'));
 const oracleSha=createHash('sha256').update(originalOracle).digest('hex');
 if(oracleSha!=='1631828109384843f926fb9e9119f97794e8fb1727e5ea55991c1a8f86802b5c')throw Error('Original raw TGA oracle changed');
 output.originalRasterOracle={sha256:oracleSha,cases:288,scope:'Unchanged original CPU resource handler; not GPU sampling/full malformed codec parity'};
 output.rasterComparisons=[];
 for(const [reference,candidate]of [['native-loading-raster-final-reference-v1','native-loading-raster-final-candidate-v2'],['native-loading-raster-area4-reference-v1','native-loading-raster-area4-candidate-v1']]){
  const before=await read(reference),after=await read(candidate);await checkEngineLog(reference);await checkEngineLog(candidate);
  for(const receipt of [before,after])if(!receipt.success||receipt.exit!==0||!receipt.sourceUnchanged||!receipt.offline||receipt.gameNetworkConnections!==0||!receipt.debuggerArmed||receipt.nativeException||receipt.engineOrLifetimeError||!receipt.native.object_visuals_complete||receipt.native.workers_remaining!==0||!receipt.native.protocol_finish_ack)throw Error('Raster comparison did not complete: '+reference);
  if(JSON.stringify(before.sourceSha256)!==JSON.stringify(after.sourceSha256)||before.recordingSha256!==after.recordingSha256)throw Error('Raster pair sources/recording differ: '+reference);
  const a=before.native.world,b=after.native.world;
  if(a.raster_conversion.enabled||!b.raster_conversion.enabled||!b.raster_conversion.available||a.ancestor_preparation.per_root!==1||b.ancestor_preparation.per_root!==1||b.ancestor_preparation.active!==0||b.ancestor_preparation.peak>2||a.entities!==b.entities||a.desired!==b.desired)throw Error('Raster pair mode, ownership or required coverage differs');
  const admission=world=>world.admissions.length<512?Math.max(...world.admissions.map(row=>row.elapsed_ms)):null;
  output.rasterComparisons.push({reference,candidate,referencePlayerMs:a.playable_ms,candidatePlayerMs:b.playable_ms,referenceTerrainMs:a.terrain.complete_ms,candidateTerrainMs:b.terrain.complete_ms,referenceLastTrackedAdmissionMs:admission(a),candidateLastTrackedAdmissionMs:admission(b),entities:b.entities,scope:'Same-source single observations, fresh prepared cache; OS/driver caches uncontrolled. Capped 512-entry admission logs cannot prove last admission time. Cumulative resource creations vary with retired intermediate appearances and are not final scene counts. Not clean FPS/original-GPU acceptance.'});
 }
 if(!sweep.native.world.raster_conversion?.enabled||!sweep.native.world.raster_conversion.available||sweep.native.world.ancestor_preparation.per_root!==1)throw Error('Default full sweep did not exercise compiled pixels and fair helper share');
 output.knownFailedReceipts.push({run:'native-loading-raster-syntax-v1',reason:'New GD pixel adapter inferred int widths from an untyped reader. Explicit int annotations fix compilation; v2 and current suite pass. The failed engine-error receipt remains retained.'},{run:'native-loading-raster-pixels-v1',reason:'New fixture called is_zero_approx on int; corrected exact integer comparison and rerun with unchanged production behavior.'});
 output.rejectedExperiments=[{run:'native-loading-raster-order-candidate-v1',reference:'native-loading-raster-order-reference-v1',reason:'Animation sources first raised player readiness from 3149 to 3377 ms in a complete 441-object observation. Source priority branch and flag removed; candidate retained in authored source checkpoint.'}];
}
if(meshPhase){
 const validateCurrent=async(name,receipt)=>{
  for(const[relative,digest]of Object.entries(receipt.sourceSha256??{}))if(createHash('sha256').update(await fs.readFile(path.join(project,relative))).digest('hex')!==digest)throw Error('Current loading source differs: '+name+':'+relative);
 };
 await validateCurrent(sweepRun,sweep);
 for(const generation of[3,4]){const name=artifactPrefix+'-area'+generation+'-v1';await validateCurrent(name,await read(name));}
 const localLoad=await read(artifactPrefix+'-local-v1'),localNative=await read(artifactPrefix+'-local-v1.native');
 await validateCurrent(artifactPrefix+'-local-v1',localLoad);
 for(const world of[sweep.native.world,localNative.world])if(!world.pool.mesh_preparation.enabled||world.pool.main_mesh_preparations!==0||world.pool.prepared_mesh_uses<=0)throw Error('Current default worker mesh path missing or silently fell back');
 const icons=sweep.native.gameplay_ui.desktop.art;
 if(!icons.model_reuse_enabled||icons.cached_models>icons.maximum_cached_models||icons.model_reuses<=0||icons.pending!==0||icons.active)throw Error('Current bounded GUI reuse did not run or drain');
 output.meshComparisons=[];
 for(const[reference,candidate]of[['native-loading-mesh-world-reference-v1','native-loading-mesh-world-candidate-v1'],['native-loading-mesh-area4-reference-v1','native-loading-mesh-area4-candidate-v1'],['native-loading-postdraw-area4-main-v1','native-loading-postdraw-area4-worker-v1']]){
  const before=await read(reference),after=await read(candidate);
  for(const[name,receipt]of[[reference,before],[candidate,after]]){await checkEngineLog(name);if(!receipt.success||!receipt.sourceUnchanged||!receipt.offline||receipt.gameNetworkConnections!==0||!receipt.debuggerArmed||receipt.nativeException||receipt.engineOrLifetimeError||receipt.native.workers_remaining!==0||!receipt.native.protocol_finish_ack)throw Error('Unaccepted mesh comparison: '+name);}
  if(JSON.stringify(before.sourceSha256)!==JSON.stringify(after.sourceSha256)||before.recordingSha256!==after.recordingSha256)throw Error('Mesh pair sources/recording differ');
  const a=before.native.world,b=after.native.world;
  if(a.pool.mesh_preparation.enabled||!b.pool.mesh_preparation.enabled||a.pool.main_mesh_preparations<=0||b.pool.main_mesh_preparations!==0||b.pool.prepared_mesh_uses<=0||a.entities!==b.entities||a.desired!==b.desired)throw Error('Mesh pair did not exercise exact required paths/coverage');
  const peak=async(name,key)=>Math.max(...(await fs.readFile(path.join(reports,name+'.performance.jsonl'),'utf8')).trim().split('\n').map(JSON.parse).map(row=>row.frame_profile.metrics[key]?.max??0));
  output.meshComparisons.push({reference,candidate,referencePlayerMs:a.playable_ms,candidatePlayerMs:b.playable_ms,referenceMeshPublicationPeakMs:await peak(reference,'publication_mesh_cpu_ms'),candidateMeshPublicationPeakMs:await peak(candidate,'publication_mesh_cpu_ms'),referenceFramePeakMs:await peak(reference,'wall_ms'),candidateFramePeakMs:await peak(candidate,'wall_ms'),entities:b.entities,scope:'Same-source exact-data worker/main comparison; fresh prepared caches, uncontrolled OS/driver caches. Main mesh phase improves; pre-player icon teardown can dominate overall frame. Not statistical entry/FPS/native-original parity acceptance.'});
 }
 const reference='native-loading-icon-cache-reference-v1',candidate='native-loading-icon-cache-candidate-v1',before=await read(reference),after=await read(candidate);
 for(const[name,receipt]of[[reference,before],[candidate,after]]){await checkEngineLog(name);if(!receipt.success||!receipt.sourceUnchanged||!receipt.offline||receipt.gameNetworkConnections!==0||!receipt.debuggerArmed||receipt.nativeException||receipt.engineOrLifetimeError||receipt.native.workers_remaining!==0||!receipt.native.protocol_finish_ack)throw Error('Unaccepted icon reuse comparison: '+name);}
 if(JSON.stringify(before.sourceSha256)!==JSON.stringify(after.sourceSha256)||before.recordingSha256!==after.recordingSha256||before.native.world.entities!==after.native.world.entities)throw Error('Icon pair input/source/final coverage differs');
 const a=before.native.gameplay_ui.desktop.art,b=after.native.gameplay_ui.desktop.art;
 if(a.model_reuse_enabled||!b.model_reuse_enabled||b.cached_models>b.maximum_cached_models||b.model_reuses<=0||a.rendered!==b.rendered)throw Error('Icon reuse pair did not exercise bounded identical art coverage');
 output.guiReuse={reference,candidate,referencePlayerMs:before.native.world.playable_ms,candidatePlayerMs:after.native.world.playable_ms,rendered:b.rendered,cachedModels:b.cached_models,reuses:b.model_reuses,scope:'Original rendered pixels/bounds separately checked by graphical suite; retained private GUI actors avoid immediate post-bake teardown, bounded 32 models/512 descendants each. Overflow uses original transient path. Shutdown still frees every model on main; not a claim of no teardown cost or identical world-entry latency.'};
 for(const suffix of['postdraw','icon-reuse'])if(!(await read(currentPrefix+'-'+suffix+'-v1.debugger')).graphical)throw Error('Post-draw/original icon checks require actual graphical rendering');
 output.knownFailedReceipts.push({run:'native-loading-icon-reuse-v1',reason:'New cache predicate needed an explicit bool type; new fixture called open instead of mount. Corrected production type/fixture API, retained failed logs, graphical v2 and full current suite pass; no assertion waived.'});
}
if(transitionPhase){
 const reference='native-loading-transition-scan-reference-v1',candidate='native-loading-transition-inherit-candidate-v1',before=await read(reference),after=await read(candidate);
 for(const[name,receipt]of[[reference,before],[candidate,after]]){
  await checkEngineLog(name);
  const errors=[...(receipt.native.world.errors??[]),...Object.values(receipt.native.world.failed_objects??{}).map(row=>row.error)];
  if(receipt.success||receipt.exit!==1||!receipt.timelineDelivered||!receipt.sourceUnchanged||!receipt.offline||receipt.gameNetworkConnections!==0||!receipt.debuggerArmed||receipt.nativeException||receipt.engineOrLifetimeError||receipt.native.workers_remaining!==0||!receipt.native.protocol_finish_ack||receipt.native.world_retirement.pending_worlds!==0||receipt.native.data_retirement.pending!==0||!errors.length||errors.some(error=>!String(error.reason??'').startsWith('Unrecorded native resource:')))throw Error('Transition pair differs from declared partial-capture scope: '+name);
 }
 if(JSON.stringify(before.sourceSha256)!==JSON.stringify(after.sourceSha256)||before.recordingSha256!==after.recordingSha256||!before.native.world.retirement_physics_scan||after.native.world.retirement_physics_scan)throw Error('Transition sources/recording/actual modes differ from intended pair');
 if(sweep.native.world.retirement_physics_scan||(await read(artifactPrefix+'-local-v1.native')).world.retirement_physics_scan)throw Error('Current default still recursively scans retired worlds');
 output.transitionRetirement={reference,candidate,referenceBeginTotalMs:before.native.world_retirement.begin_ms,candidateBeginTotalMs:after.native.world_retirement.begin_ms,referenceBeginPeakMs:before.native.world_retirement.max_begin_ms,candidateBeginPeakMs:after.native.world_retirement.max_begin_ms,retired:after.native.world_retirement.retired,scope:'Same-source single original-paced offline pair, complete delivered timeline but missing captured bytes in both. Actual native-physics ray exclusion is covered separately by focused fixtures; timing difference is not full gameplay/FPS/original-executable parity acceptance.'};
 output.knownFailedReceipts.push({run:'native-loading-transition-suite-retirement-v1',reason:'New physics setup advanced frames after the stale-completion observer was connected, counting legitimate pre-retirement results. Observer now connects immediately at the retirement boundary; zero post-retirement completions remain required. Retained failure and rerun all current cases under a new prefix.'});
}
if(typedPhase){
 output.asciiKeyComparisons=[];
 for(const generation of[3,4]){
  const reference='native-loading-typed-ascii-area'+generation+'-reference-v1',candidate='native-loading-typed-ascii-area'+generation+'-candidate-v1';
  const a=await read(reference),b=await read(candidate);
  for(const[name,r]of[[reference,a],[candidate,b]]){await checkEngineLog(name);if(!r.success||!r.sourceUnchanged||!r.offline||r.gameNetworkConnections!==0||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||!r.native.object_visuals_complete||r.native.workers_remaining!==0||!r.native.protocol_finish_ack)throw Error('Incomplete typed ASCII comparison: '+name);}
  if(JSON.stringify(a.sourceSha256)!==JSON.stringify(b.sourceSha256)||a.recordingSha256!==b.recordingSha256||a.native.world.ascii_key_write!=='arrays'||b.native.world.ascii_key_write!=='typed'||a.native.world.entities!==b.native.world.entities||a.native.world.desired!==b.native.world.desired)throw Error('Typed ASCII pair sources/modes/coverage differ');
  output.asciiKeyComparisons.push({reference,candidate,referencePlayerMs:a.native.world.playable_ms,candidatePlayerMs:b.native.world.playable_ms,entities:b.native.world.entities,scope:'Same-source single cold prepared-cache observations, reversed order across areas. Direct typed parsing is byte-exact and faster in isolated parser fixtures, but this does not establish a general end-to-end loading or FPS gain.'});
 }
 for(const w of[sweep.native.world,(await read(artifactPrefix+'-local-v1.native')).world])if(w.ascii_key_write!=='typed')throw Error('Default direct typed ASCII writes not exercised');
 const reference='native-loading-ui-handoff-main-v1',candidate='native-loading-typed-final-five-area-v1',a=await read(reference),b=await read(candidate);
 for(const[name,r]of[[reference,a],[candidate,b]]){
  await checkEngineLog(name);
  const gaps=[...(r.native.world.errors??[]),...Object.values(r.native.world.failed_objects??{}).map(row=>row.error)];
  if(r.success||r.exit!==1||!r.timelineDelivered||!r.sourceUnchanged||!r.offline||r.gameNetworkConnections!==0||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||r.native.workers_remaining!==0||!r.native.protocol_finish_ack||r.native.data_retirement.pending!==0||!gaps.length||gaps.some(error=>!String(error.reason??'').startsWith('Unrecorded native resource:')))throw Error('UI handoff pair differs from declared partial-capture scope: '+name);
 }
 if(JSON.stringify(a.sourceSha256)!==JSON.stringify(b.sourceSha256)||a.recordingSha256!==b.recordingSha256||a.native.gameplay_ui.desktop.raw_data_retirement_enabled||!b.native.gameplay_ui.desktop.raw_data_retirement_enabled||a.native.gameplay_ui.desktop.raw_data_retirements!==0||b.native.gameplay_ui.desktop.raw_data_retirements!==4||a.native.world.entities!==b.native.world.entities)throw Error('UI handoff source, mode, retirement count or final coverage differs');
 const peaks=async name=>{
  const rows=(await fs.readFile(path.join(reports,name+'.performance.jsonl'),'utf8')).trim().split('\n').map(JSON.parse),out={};
  for(const row of rows){const generation=row.state?.generation;if(!(generation>=2))continue;out[generation]??={};for(const[key,value]of Object.entries(row.frame_profile?.metrics??{}))if(/^snapshot_ui_desktop.*_ms$/.test(key)||key==='wall_ms')out[generation][key]=Math.max(out[generation][key]??0,value.max);}
  return out;
 };
 output.uiRawDataHandoff={reference,candidate,referencePeaks:await peaks(reference),candidatePeaks:await peaks(candidate),scope:'Same-source original-paced sealed offline pair; entire timeline delivered but captured resource gaps remain explicit. Raw JSON map/header references only enter the bounded fenced disposal owner; no UI nodes/GPU resources leave main. Single profiled observations, not statistical FPS or complete gameplay acceptance.'};
 output.knownFailedReceipts.push({run:'native-loading-ui-data-retirement-v1',reason:'New optional-owner lookup used get_meta with null default, which still emits an engine error when absent. Explicit has_meta guard fixes missing/closed-owner fallback. All 20 assertions passed before and after; v2/current suite additionally require clean full engine logs.'});
}
if(cachePhase){
 output.preparedCacheMatrix=[];let matrixSources=null;
 for(const generation of[3,4])for(const write of['sync','deferred'])for(const gate of['global','path']){
  const name='native-loading-cache-matrix-area'+generation+'-'+write+'-'+gate+'-v1',r=await read(name),w=r.native.world,q=r.native.prepared_write_queue;
  await checkEngineLog(name);
  if(!r.success||r.exit!==0||!r.timelineDelivered||!r.offline||r.gameNetworkConnections!==0||!r.sourceUnchanged||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||!r.native.object_visuals_complete||r.native.workers_remaining!==0||!r.native.protocol_finish_ack||w.entities!==(generation===3?441:630)||w.entities!==w.desired||w.prepared_cache_lock!==gate||!w.prepared_cache_writes||q.enabled!==(write==='deferred')||q.pending!==0||q.owners!==0||!q.closed)throw Error('Incomplete cache matrix case: '+name);
  matrixSources??=JSON.stringify(r.sourceSha256);if(matrixSources!==JSON.stringify(r.sourceSha256)||r.recordingSha256!==sweep.recordingSha256)throw Error('Cache matrix sources/input differ');
  if(write==='deferred'&&(q.failed!==0||q.skipped_full!==0||q.skipped_closed!==0||q.submitted<=0||q.completed!==q.submitted||q.threads.length!==1||q.peak_packets>q.maximum_packets||q.peak_estimated_bytes>q.maximum_bytes))throw Error('Cache writer did not save/drain every eligible matrix source within bounds: '+name);
  output.preparedCacheMatrix.push({run:name,generation,write,gate,playerMs:w.playable_ms,terrainMs:w.terrain.complete_ms,lastTrackedAdmissionMs:w.admissions.length<512?Math.max(...w.admissions.map(row=>row.elapsed_ms)):null,entities:w.entities,writerPeakPackets:q.peak_packets??0,writerPeakEstimatedBytes:q.peak_estimated_bytes??0,writerSkipped:q.skipped_full??0,scope:'Identical-source independent-factor complete-area observations; reverse order in area4, fresh prepared caches, OS/driver caches uncontrolled. Capped admissions cannot prove last arrival. Not statistical/original-executable FPS or loading parity.'});
 }
 for(const r of[sweep,await read(artifactPrefix+'-area3-v1'),await read(artifactPrefix+'-area4-v1')]){
  const q=r.native.prepared_write_queue,w=r.native.world;
  if(!q.enabled||q.pending!==0||q.owners!==0||!q.closed||q.failed!==0||q.submitted!==q.completed||q.threads.length!==1||q.peak_packets>128||q.peak_estimated_bytes>64*1024*1024||w.prepared_cache_lock!=='path'||!w.prepared_cache_writes)throw Error('Current default cache writer/lock lifecycle is incomplete');
 }
 const q=(await read(artifactPrefix+'-local-v1.native')).prepared_write_queue;
 if(!q.enabled||q.pending!==0||q.owners!==0||!q.closed||q.failed!==0||q.submitted!==q.completed)throw Error('Authoritative local cache writer did not drain');
 output.preparedCachePolicy={thread:'One low-priority native thread with an application lease through menu/world changes and a last-owner shutdown join',payloads:'Published immutable decoded MDL sources only; mutable generic GFF/table/UI/GPU state is excluded; rigs and other derivatives keep synchronous persistence',bounds:'128 packets and 64 MiB existing serialized-size charge, not a hard RSS bound; full queues skip only optional persistence, never rendered assets',integrity:'Unchanged checksum/schema/content validation and atomic publication; refcounted per-destination gates exclude same-key repair/rename while unrelated destinations proceed',fullPerformanceAccepted:false};
 output.knownFailedReceipts.push({run:'native-loading-cache-suite-failed-model-v1',reason:'Existing held-decoder fixture override still had the old internal decoder signature. Updated its optional argument and forwarding; failed-model assertions are unchanged. The new prefix reruns the full suite with current source/test hashes.'});
}
if(['skin','clips'].includes(phase)){
 const peak=async(name,key)=>Math.max(...(await fs.readFile(path.join(reports,name+'.performance.jsonl'),'utf8')).trim().split('\n').map(JSON.parse).map(row=>row.frame_profile?.metrics?.[key]?.max??0));
 output.skinComparisons=[];
 for(const generation of[3,4]){
  const reference='native-loading-skin-area'+generation+'-reference-v1',candidate='native-loading-skin-area'+generation+'-candidate-v1',a=await read(reference),b=await read(candidate);
  for(const[name,r]of[[reference,a],[candidate,b]]){await checkEngineLog(name);if(!r.success||!r.sourceUnchanged||!r.offline||r.gameNetworkConnections!==0||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||r.native.workers_remaining!==0||!r.native.protocol_finish_ack||!r.native.object_visuals_complete||r.native.prepared_write_queue.pending!==0)throw Error('Incomplete skin comparison: '+name);}
  if(JSON.stringify(a.sourceSha256)!==JSON.stringify(b.sourceSha256)||a.recordingSha256!==b.recordingSha256||a.native.world.skin_preparation.enabled||!b.native.world.skin_preparation.enabled||a.native.world.entities!==b.native.world.entities||a.native.world.desired!==b.native.world.desired)throw Error('Skin comparison source/mode/required coverage differs');
  output.skinComparisons.push({reference,candidate,referencePlayerMs:a.native.world.playable_ms,candidatePlayerMs:b.native.world.playable_ms,referenceSkinSourcePeakMs:await peak(reference,'actor_install_skin_source_ms'),candidateSkinSourcePeakMs:await peak(candidate,'actor_install_skin_source_ms'),referenceSkinRuntimePeakMs:await peak(reference,'actor_install_skin_runtime_ms'),candidateSkinRuntimePeakMs:await peak(candidate,'actor_install_skin_runtime_ms'),entities:b.native.world.entities,scope:'Same-source single observations, reversed order in area4; exact data/private binds/posed bake covered separately. Child phase peaks overlap and are sampled, not summed frame CPU or proof of faster world entry/FPS.'});
 }
 const reference='native-loading-skin-route-main-v1',candidate=phase==='clips'?'native-loading-skin-default-five-area-v1':artifactPrefix+'-five-area-v1',a=await read(reference),b=phase==='clips'?await read(candidate):sweep;
 for(const[name,r]of[[reference,a],[candidate,b]]){
  await checkEngineLog(name);
  if(r.success||r.exit!==1||!r.timelineDelivered||!r.sourceUnchanged||!r.offline||r.gameNetworkConnections!==0||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||r.native.workers_remaining!==0||!r.native.protocol_finish_ack||r.native.prepared_write_queue.pending!==0||r.native.data_retirement.pending!==0||r.native.world_retirement.pending_worlds!==0||r.measurement.otherWorldErrors.length||!r.measurement.captureGaps.length)throw Error('Skin route differs from declared partial-capture scope: '+name);
 }
 if(JSON.stringify(a.sourceSha256)!==JSON.stringify(b.sourceSha256)||a.recordingSha256!==b.recordingSha256||a.native.world.skin_preparation.enabled||!b.native.world.skin_preparation.enabled||a.native.world.entities!==b.native.world.entities||a.native.world.actor_rigs.skin_main_meshes<=0||a.native.world.actor_rigs.skin_prepared_meshes!==0||b.native.world.actor_rigs.skin_main_meshes!==0||b.native.world.actor_rigs.skin_prepared_meshes!==a.native.world.actor_rigs.skin_meshes)throw Error('Skin route source or actual final runtime paths differ');
 output.skinRoute={reference,candidate,referenceFinalRig:a.native.world.actor_rigs,candidateFinalRig:b.native.world.actor_rigs,referenceSkinSourcePeakMs:await peak(reference,'actor_install_skin_source_ms'),candidateSkinSourcePeakMs:await peak(candidate,'actor_install_skin_source_ms'),referenceSkinRuntimePeakMs:await peak(reference,'actor_install_skin_runtime_ms'),candidateSkinRuntimePeakMs:await peak(candidate,'actor_install_skin_runtime_ms'),scope:'Same-source original-paced route pair, both explicit incomplete captured dependencies; actual final skin counts/modes and full shutdown are required. Single profiled observations, not complete-world/original-client visual/FPS acceptance.'};
 for(const generation of[3,4]){
  const r=await read(artifactPrefix+'-area'+generation+'-v1'),w=r.native.world,prepared=(w.batches??[]).reduce((n,row)=>n+(row.skin_prepared_meshes??0),0),main=(w.batches??[]).reduce((n,row)=>n+(row.skin_main_meshes??0),0);
  if(!w.skin_preparation.enabled||prepared<=0||main!==0||w.actor_rigs.skin_main_meshes!==0)throw Error('Current default did not use worker skin streams without legacy fallbacks');
 }
 if(!(await read(currentPrefix+'-skin-stream-v1.debugger')).graphical)throw Error('Exact skin/posed bake validation requires graphical native rendering');
 output.knownFailedReceipts.push({run:'native-loading-skin-stream-parity-v1',reason:'New fixture selected three rigid body parts as skins and deliberately rejected influence cases emitted production push_error. Corrected actual skin corpus and capture only the pinned logger (failure arrays/success expectations remain strictly asserted); v3/current suite add pure-data retirement validation.'},{run:'native-loading-skin-cache-v1',reason:'New fixture mistook WorkerThreadPool completion Error for a task result. Actual Thread return API fixes the fixture; v2/current suite verify all original cache assertions.'});
 output.skinPolicy={revision:'skin-upload-v1',worker:'Exact face winding/flat normals/UVs, zero and negative-weight policy, four influences, typed upload streams; source fields preserved and content+derivative identities isolated',main:'Private 65-bone skeletons/binds and actual slot mapping validation, ArrayMesh/Resource publication and pose owners remain main',disposal:'Only pure original/derived skin-source data enters the existing fenced data-disposal owner; skeletons, meshes and Skin resources remain main',performanceAccepted:false};
}
if(phase==='clips'){
 const peak=async(name,key)=>Math.max(0,...(await fs.readFile(path.join(reports,name+'.performance.jsonl'),'utf8')).trim().split('\n').map(JSON.parse).map(row=>row.frame_profile?.metrics?.[key]?.max??0));
 output.clipComparisons=[];
 for(const version of[1,2])for(const generation of[3,4]){
  const reference='native-loading-clip-area'+generation+'-main-v'+version,candidate='native-loading-clip-area'+generation+'-worker-v'+version,a=await read(reference),b=await read(candidate);
  for(const[name,r]of[[reference,a],[candidate,b]]){
   await checkEngineLog(name);
   if(!r.success||r.exit!==0||!r.timelineDelivered||!r.sourceUnchanged||!r.offline||r.gameNetworkConnections!==0||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||r.native.workers_remaining!==0||!r.native.protocol_finish_ack||!r.native.object_visuals_complete||r.native.world.entities!==(generation===3?441:630)||r.native.world.entities!==r.native.world.desired)throw Error('Incomplete animation index comparison: '+name);
  }
  if(JSON.stringify(a.sourceSha256)!==JSON.stringify(b.sourceSha256)||a.recordingSha256!==b.recordingSha256||a.clipPreparationRequested!=='main'||b.clipPreparationRequested!=='worker'||a.native.world.actor_rigs.indexed_clip_models!==0||b.native.world.actor_rigs.indexed_clip_models<=0)throw Error('Animation index pair source/mode/coverage differs');
  output.clipComparisons.push({reference,candidate,referencePlayerMs:a.native.world.playable_ms,candidatePlayerMs:b.native.world.playable_ms,referenceInstallPeakMs:await peak(reference,'actor_install_animation_ms'),candidateInstallPeakMs:await peak(candidate,'actor_install_animation_ms'),referenceWallPeakMs:await peak(reference,'wall_ms'),candidateWallPeakMs:await peak(candidate,'wall_ms'),entities:b.native.world.entities,scope:'Same-source original input, fresh prepared-cache single observations, reversed order across areas and v2. v2 additionally borrows immutable controller definitions. Reduced child installation work does not establish lower world-entry latency or overall maximum hitch/FPS.'});
 }
 const reference='native-loading-clips-route-main-v1',candidate=artifactPrefix+'-five-area-v1',a=await read(reference),b=sweep;
 for(const[name,r]of[[reference,a],[candidate,b]]){
  await checkEngineLog(name);
  if(r.success||r.exit!==1||!r.timelineDelivered||!r.sourceUnchanged||!r.offline||r.gameNetworkConnections!==0||!r.debuggerArmed||r.nativeException||r.engineOrLifetimeError||r.native.workers_remaining!==0||!r.native.protocol_finish_ack||r.native.prepared_write_queue.pending!==0||r.native.data_retirement.pending!==0||r.native.world_retirement.pending_worlds!==0||r.measurement.otherWorldErrors.length||!r.measurement.captureGaps.length)throw Error('Animation index route differs from declared partial-capture scope: '+name);
 }
 if(JSON.stringify(a.sourceSha256)!==JSON.stringify(b.sourceSha256)||a.recordingSha256!==b.recordingSha256||a.native.world.clip_preparation.enabled||!b.native.world.clip_preparation.enabled||a.native.world.actor_rigs.indexed_clip_models!==0||b.native.world.actor_rigs.indexed_clip_models<=0||a.native.world.entities!==b.native.world.entities)throw Error('Animation index route source or actual runtime modes differ');
 output.clipRoute={reference,candidate,referenceFinalRig:a.native.world.actor_rigs,candidateFinalRig:b.native.world.actor_rigs,referenceInstallPeakMs:await peak(reference,'actor_install_animation_ms'),candidateInstallPeakMs:await peak(candidate,'actor_install_animation_ms'),referenceWallPeakMs:await peak(reference,'wall_ms'),candidateWallPeakMs:await peak(candidate,'wall_ms'),scope:'Current-source original-paced full delivered timeline. Incomplete captured dependencies remain explicit; this is not original-client/FPS/complete-world acceptance.'};
 for(const generation of[3,4])if(!(await read(artifactPrefix+'-area'+generation+'-v1')).native.world.clip_preparation.enabled)throw Error('Current default animation index not enabled');
 if(!(await read(artifactPrefix+'-local-v1.native')).world.clip_preparation.enabled)throw Error('Current local load did not use the animation index default');
 output.clipPolicy={revision:'actor-rig-emitter-v10-clip-index',shared:'Content-keyed immutable clip array/name-to-index/controller definitions; no duplicate graph embedded into the serialized index',private:'Requested Animation resources, AnimationLibrary, event copies, active names/clocks/transitions; old assets without a prepared index retain the legacy path',nativeEvidence:'FindAnimation 0x140050f80 and Gob::GetAnimation 0x1400510b0 use resident model definitions on demand. The port optimization retains its existing exact-case/last-duplicate selection; original case-insensitive/first-match/default-fallback parity remains a separate gap.',performanceAccepted:false};
 output.knownFailedReceipts.push({run:'native-loading-clip-index-fixture-v1',reason:'All81 assertions passed, but unprivileged Godot startup could not read the Windows certificate store. Read-authorized v2/v3 and the current suite require unchanged full error detection; no engine error was filtered.'});
}
const destination=path.join(reports,run+'.json');
await fs.writeFile(destination,JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:true,checks:output.nativeChecks,report:destination,scope:'Current focused native sources and retained complete-area comparisons; full five-area/gameplay/FPS acceptance remains incomplete'}));
