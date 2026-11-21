import {createHash} from 'node:crypto';
import {NetworkWorld} from '../../src/network_world.js';
import {validatePerformanceCandidateFlags} from '../performance-candidates/live-performance-profile.mjs';
const check=(value,message)=>{if(!value)throw Error(message);};
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const finitePositive=n=>Number.isFinite(n)&&n>0;
export function canonicalReplayObjects(replay){
 const context=replay.views.at(-1)?.context;check(context&&/^[a-f0-9]{64}$/.test(replay.archive.manifest.eventsSha256),'Verified capture and final view required');
 const diagnostics=[],world=new NetworkWorld({onDiagnostic:d=>diagnostics.push(d)});
 for(const record of replay.records)if(record.context===context&&record.event.kind==='message')world.apply(structuredClone(record.event.message));
 check(diagnostics.length===0,'Canonical replay rejected decoded input');
 check(world.areaId===replay.views.at(-1).event.view.areaId,'Canonical final area differs from recorded view');
 const counts={},ids=[];
 for(const object of world.registry.objects.values()){
  if(![5,6,9,10].includes(object.objectType)||object.areaId!==world.areaId||object.replicationRemoved)continue;
  const position=object.replicated?.position??object.staticState?.position??object.lightState?.position;
  if(!position)continue;check(position.length===3&&Array.from(position).every(Number.isFinite),'Invalid canonical object pose');
  if(object.objectType===5&&!Number.isInteger(object.appearance?.appearance))continue;
  ids.push(object.id);counts[object.objectType]=(counts[object.objectType]??0)+1;
 }
 check(ids.length>0,'Canonical replay has no render-eligible objects');
 return {context,areaId:world.areaId,controlledId:world.localObjectId,registryObjects:world.registry.objects.size,ids:ids.sort((a,b)=>a-b),counts,eventsSha256:replay.archive.manifest.eventsSha256,scope:'Decoded render-eligible membership before resource/model rules; not a general visibility or native fidelity oracle'};
}
export function replayInventoryHash(inventory){
 check(Array.isArray(inventory)&&inventory.length>0,'Missing rendered inventory');
 const ids=new Set(),rows=inventory.map(row=>{
  check(Number.isInteger(row.id)&&row.id>=0&&row.id<=0xffffffff&&!ids.has(row.id),'Invalid or duplicate inventory object');ids.add(row.id);
  check(Array.isArray(row.resources)&&row.resources.length>0&&row.resources.every(r=>typeof r==='string'&&r.length>0),'Missing model resource identity');
  return{id:row.id,resources:row.resources.slice().sort()};
 }).sort((a,b)=>a.id-b.id);
 return createHash('sha256').update(JSON.stringify(rows)).digest('hex');
}

// RAF observations are separate from the rolling diagnostic window. Include
// the unfinished tail in elapsed/worst time: otherwise a long stall just before
// `take()` could disappear from both the FPS denominator and freeze gate.
export function replayFrameMetrics(observation,renderedFrames){
 check(observation?.dropped===0&&Array.isArray(observation.rows)&&observation.rows.length>0,'Incomplete replay frame observation');
 check(finitePositive(observation.durationMs),'Missing replay observation duration');
 const gaps=observation.rows.map(row=>row.gapMs);check(gaps.every(finitePositive),'Invalid replay frame gap');
 for(let i=0;i<observation.rows.length;i++){const row=observation.rows[i];check(Number.isFinite(row.at),'Invalid replay frame time');if(i)check(row.at>observation.rows[i-1].at&&Math.abs(row.at-observation.rows[i-1].at-row.gapMs)<.01,'Replay observation clock mismatch');}
 const completedMs=gaps.reduce((a,b)=>a+b,0),tailMs=observation.durationMs-completedMs;check(tailMs>=-.01,'Replay observation duration is truncated');
 check(Number.isSafeInteger(renderedFrames)&&renderedFrames>=0&&Math.abs(renderedFrames-gaps.length)<=2,'Rendered/observed frame coverage differs');
 const sorted=gaps.slice().sort((a,b)=>a-b),frames=Math.min(renderedFrames,gaps.length);check(frames>0,'No completed render frames');
 const durationMs=Math.max(completedMs,observation.durationMs),fps=frames*1000/durationMs,p95Ms=sorted[Math.ceil(sorted.length*.95)-1],maxMs=Math.max(sorted.at(-1),tailMs);
 return{frames,renderedFrames,observedFrames:gaps.length,durationMs,tailMs:Math.max(0,tailMs),fps,averageMs:durationMs/frames,p95Ms,maxMs,hitchesOver50Ms:gaps.filter(g=>g>50).length+Number(tailMs>50),freezesOver1000Ms:gaps.filter(g=>g>=1000).length+Number(tailMs>=1000),targetMet:frames>=120&&fps>=60&&p95Ms<=16.7&&maxMs<1000};
}

// This validates one fully imported frozen workload. It does not assert native
// visual parity, production readiness or completion of the multi-scene goal.
export function summarizeReplayMeasurements(report,{expectedIds,expectedInventoryHash}={}){
 check(report.measurementVersion===1,'Replay measurements missing or unsupported');
 check(report.environment?.operatorConfirmedIdle===true,'Concurrent-game state is unconfirmed');
 check(report.environment.profilerEnabled===false&&!report.cpuProfile,'Profiler-tainted timing is diagnostic only');
 check(report.rendered===true&&!report.failure,'Replay did not finish rendering');
 check(/^[a-f0-9]{64}$/.test(report.build?.sha256??'')&&/^[a-f0-9]{64}$/.test(report.harnessSha256??''),'Replay code identity missing');
 check(/^[a-f0-9]{64}$/.test(report.capture?.eventsSha256??''),'Frozen input identity missing');
 for(const [name,rows]of Object.entries({errors:report.errors,diagnostics:report.diagnostics,textGaps:report.textGaps,resourceGaps:report.capture.unrecorded}))check(Array.isArray(rows)&&rows.length===0,'Replay '+name+' are missing or nonempty');
 check(Array.isArray(report.blockedRequests)&&report.blockedRequests.every(url=>url==='https://fonts.googleapis.com/css2'),'Unexpected external request');
 check(Array.isArray(expectedIds)&&expectedIds.length>0&&new Set(expectedIds).size===expectedIds.length,'Independent canonical IDs required');
 check(/^[a-f0-9]{64}$/.test(expectedInventoryHash??''),'Verified complete resource inventory required');
 const actualIds=report.inventory?.map(row=>row.id).sort((a,b)=>a-b),ids=expectedIds.slice().sort((a,b)=>a-b);
 check(same(actualIds,ids),'Rendered IDs differ from independent canonical IDs');
 check(replayInventoryHash(report.inventory)===expectedInventoryHash,'Rendered resource inventory changed');
 const measurements=report.measurements;check(Array.isArray(measurements)&&measurements.length>=4,'At least four measurement phases required');
 check(same(report.measurementPlan?.modes,measurements.map(m=>m.mode))&&report.measurementPlan.warmupMs>=16000&&report.measurementPlan.phaseMs>=20000,'Measurement plan or warmup is incomplete');
 const reference=measurements[0].start,referenceHash=measurements[0].inventoryStartHash;
 check(referenceHash===expectedInventoryHash,'Measurement starts with a different inventory');
 const signature=state=>({phase:state.phase,areaId:state.areaId,objects:state.objects,models:state.models,canonicalObjects:state.canonicalObjects,buffer:state.buffer,camera:state.camera,emitters:state.particles?.emitters,failedEmitters:state.particles?.failed,flags:state.performance?.flags,shadowMaximum:state.performance?.telemetry?.shadows?.native?.maximum});
 const key=signature(reference);check(key.phase==='playing'&&key.objects===ids.length&&key.models>0&&key.emitters>=0&&key.failedEmitters>=0&&Array.isArray(key.buffer)&&key.buffer.length===2&&key.buffer.every(finitePositive)&&key.camera&&key.flags&&Number.isFinite(key.shadowMaximum),'Incomplete measurement scene settings');
 validatePerformanceCandidateFlags(key.flags);
 const phases=measurements.map((m,index)=>{
  check(m.index===index&&typeof m.mode==='string'&&m.start.experiment===m.mode&&m.end.experiment===m.mode,'Replay measurement mode/order mismatch');
  check(m.frames?.label===index+':'+m.mode,'Replay frame label mismatch');
  // Independent 100-us performance.now samples can land exactly on the
  // boundary. Budget one nanosecond for subtraction roundoff, not another
  // timer tick; the recorded endpoint discrepancy was 0.100000000559 ms.
  const clockRoundoff=Math.max(.000001,Number.EPSILON*8*Math.max(1,Math.abs(m.start.elapsedMs),Math.abs(m.end.elapsedMs),m.frames.durationMs));
  check(Number.isFinite(m.start.elapsedMs)&&Number.isFinite(m.end.elapsedMs)&&m.end.elapsedMs-m.start.elapsedMs>=m.frames.durationMs-.1-clockRoundoff,'Replay measurement endpoint clock mismatch');
  check(m.inventoryStartHash===referenceHash&&m.inventoryEndHash===referenceHash,'Inventory changed during measurement');
  for(const state of [m.start,m.end]){check(state.workerStream==null,'Worker mirror diagnostics are not a gameplay FPS comparison');check(same(signature(state),key),'Replay content, camera or settings changed');check(state.pendingAssets===0&&state.graphicsPending===false&&Array.isArray(state.failedObjects)&&state.failedObjects.length===0&&state.performance.telemetry?.models?.pending===0,'Replay phase is incomplete');}
  check(m.frames.durationMs>=report.measurementPlan.phaseMs-10,'Replay phase was cut short');
  const rendered=m.end.frameCounts?.rendered-m.start.frameCounts?.rendered,metrics=replayFrameMetrics(m.frames,rendered);
  check(metrics.frames>=120,'Too few completed replay frames');
  if(m.mode.includes('flat'))check(m.end.flatScene&&!m.end.flatScene.fallback&&m.end.flatScene.submittedObjects>0,'Compiled projection was not exercised');
  if(m.mode.includes('broad'))check(m.end.performance.telemetry?.batches?.staticOnly===false&&m.end.performance.telemetry.batches.batches>0&&!m.end.performance.telemetry.batches.disabled,'Broad batching was not exercised');
  if(['particle-frame','particle-lean','particle-lights','lean-all','wide-all','grid-all','command-all','merged-all','merged-samples','warm-draws','planned-draws','prefix-draws','cooperative-draws','opaque-alpha','keyhole-inactive','native-discard','spatial-draws','cached-poses','array-commands','compiled-main','ancestor-poses','orphan-dynamic','orphan-all','packet-main'].includes(m.mode))for(const state of [m.start,m.end])check(state.runtimeOptions?.particleFrameStorage===true,'Particle frame storage was not exercised');
  if(['light-records','particle-lights','lean-all','wide-all','grid-all','command-all','merged-all','merged-samples','warm-draws','planned-draws','prefix-draws','cooperative-draws','opaque-alpha','keyhole-inactive','native-discard','spatial-draws','cached-poses','array-commands','compiled-main','ancestor-poses','orphan-dynamic','orphan-all','packet-main'].includes(m.mode))for(const state of [m.start,m.end])check(state.runtimeOptions?.lightOnlyMembership===true,'Light membership filtering was not exercised');
  if(['lean-submit','particle-lean','lean-all','point-grid','grid-all','command-batches','command-all','merged-batches','merged-all','merged-samples','warm-draws','planned-draws','prefix-draws','cooperative-draws','opaque-alpha','keyhole-inactive','native-discard','spatial-draws','cached-poses','array-commands','compiled-main','ancestor-poses','orphan-dynamic','orphan-all','packet-main'].includes(m.mode))for(const state of [m.start,m.end])check(state.performance.telemetry?.batches?.enabled===false&&state.performance.telemetry?.materialReuse?.enabled===false&&state.performance.telemetry?.lightUniforms?.enabled===false,'Submission owners were not disabled');
  if(['wide-batches','wide-all'].includes(m.mode))for(const state of [m.start,m.end])check(state.performance.telemetry?.batches?.limit===128&&state.performance.telemetry.batches.staticOnly===false&&state.performance.telemetry.batches.batches>0&&!state.performance.telemetry.batches.disabled,'Wide batching was not exercised');
  if(['point-grid','grid-all'].includes(m.mode))for(const state of [m.start,m.end])check(state.runtimeOptions?.pointGrid===true&&state.pointGrid?.enabled===true&&state.pointGrid.active===true&&state.pointGrid.activeDraws>0&&state.pointGrid.ownedPrograms>0&&state.pointGrid.materials>0&&state.pointGrid.usedBytes>0&&Number.isFinite(state.pointGrid.averageLights),'Spatial point lighting was not exercised');
  if(['command-batches','command-all','merged-batches','merged-all','merged-samples','array-commands'].includes(m.mode))for(const state of [m.start,m.end])check(state.commandBatches?.enabled===true&&!state.commandBatches.disabled&&!state.commandBatches.failure&&state.commandBatches.batches>0&&state.commandBatches.instances>0&&state.commandBatches.draws<state.commandBatches.originalDraws,'Command batching was not exercised');
  if(m.mode==='array-commands')for(const state of [m.start,m.end])check(state.commandBatches?.arrayPalette===true&&state.commandBatches.merged===true&&state.commandBatches.palettes?.layers>0&&state.commandBatches.palettes.bytes>0,'Array texture command batching was not exercised');
  if(m.mode.startsWith('merged-'))for(const state of [m.start,m.end])check(state.commandBatches?.merged===true,'Merged geometry was not exercised');
  if(m.mode==='merged-samples')for(const state of [m.start,m.end])check(state.commandBatches?.sampleAll===true,'Implicit texture sampling was not exercised');
  if(m.mode==='shared-frame')for(const state of [m.start,m.end]){
   check(state.runtimeOptions?.sharedMembership===true&&state.flatScene?.shared===true&&state.flatScene.membershipObjects>0&&state.shadowTraversal?.membership==='prepared','Shared frame membership was not exercised');
   check(state.runtimeOptions?.particleFrameStorage===reference.runtimeOptions.particleFrameStorage&&state.runtimeOptions?.lightOnlyMembership===reference.runtimeOptions.lightOnlyMembership,'Shared projection changed unrelated runtime owners');
   for(const[name,flag]of [['batches','staticBatches'],['lightUniforms','lightUniforms'],['materialReuse','materialReuse']])check(state.performance.telemetry[name]?.enabled===key.flags[flag],'Shared projection changed unrelated submission owners');
  }
  if(m.mode==='cached-poses')for(const state of [m.start,m.end])check(state.particlePoses?.enabled===true&&state.particlePoses.reused>0,'Unchanged particle pose sampling was not exercised');
  if(['cooperative-draws','opaque-alpha','keyhole-inactive','native-discard','spatial-draws','cached-poses','array-commands','compiled-main','ancestor-poses','orphan-dynamic','orphan-all','packet-main'].includes(m.mode))check(m.start.matrixCooperation?.cooperation===true&&m.start.matrixCooperation.owners>0&&m.end.matrixCooperation?.cooperation===true&&m.end.matrixCooperation.skipped>m.start.matrixCooperation.skipped,'Known matrix owner cooperation was not exercised');
  if(['prefix-draws','cooperative-draws','opaque-alpha','keyhole-inactive','native-discard','spatial-draws','cached-poses','array-commands','compiled-main','ancestor-poses','orphan-dynamic','orphan-all','packet-main'].includes(m.mode))for(const state of [m.start,m.end])check(state.shadowPrefix?.enabled===true&&state.shadowPrefix.restored>0&&state.shadowPrefix.prefixObjects>0&&state.shadowPrefix.suffixObjects>0&&state.shadowPrefix.bytes>0&&!state.shadowPrefix.failure,'Live shadow prefix was not exercised');
  if(['planned-draws','prefix-draws','cooperative-draws','opaque-alpha','keyhole-inactive','native-discard','spatial-draws','cached-poses','array-commands','compiled-main','ancestor-poses','orphan-dynamic','orphan-all','packet-main'].includes(m.mode))for(const state of [m.start,m.end])check(state.scenePlan?.enabled===true&&state.scenePlan.bridge===1&&state.scenePlan.shared===true&&state.scenePlan.projected>0,'Prepared scene projection was not exercised');
  if(['warm-draws','planned-draws','prefix-draws','cooperative-draws','opaque-alpha','keyhole-inactive','native-discard','spatial-draws','cached-poses','array-commands','ancestor-poses','orphan-dynamic','orphan-all'].includes(m.mode))for(const state of [m.start,m.end])check(state.warmDraws?.enabled===true&&state.warmDraws.bridge===1&&state.warmDraws.fast>0,'Warm draw executor was not exercised');
  if(m.mode==='ancestor-poses')for(const state of [m.start,m.end])check(state.particlePoses?.ancestors?.enabled===true&&state.particlePoses.ancestors.reused>0,'Shared particle pose ancestry was not exercised');
  if(['orphan-dynamic','orphan-all'].includes(m.mode))for(const state of [m.start,m.end])check(state.attributeUploads?.enabled===true&&state.attributeUploads.uploads>0,'Renamed attribute uploads were not exercised');
  if(['opaque-alpha','native-discard'].includes(m.mode))for(const state of [m.start,m.end])check(state.discard?.opaqueAlpha?.enabled===true&&state.discard.opaqueAlpha.removed>0,'Opaque alpha specialization was not exercised');
  if(['keyhole-inactive','native-discard'].includes(m.mode))for(const state of [m.start,m.end])check(state.discard?.keyhole?.specializeInactive===true&&state.discard.programs?.inactive>0,'Inactive keyhole shader programs were not exercised');
  if(m.mode==='spatial-draws')for(const state of [m.start,m.end]){const v=state.scenePlan?.spatial;check(v?.indexed>0&&v.nodes>0&&v.planeTests>0&&v.indexed+v.fallback===v.members,'Hierarchical spatial visibility was not exercised');}
  if(m.mode==='packet-main')for(const state of [m.start,m.end])check(state.compiledPass?.enabled===true&&state.compiledPass.replayed>0&&state.compiledPass.packetBlocks>0&&state.compiledPass.packetCommands>0,'Packet backend was not exercised');
  if(m.mode==='compiled-main')for(const state of [m.start,m.end])check(state.compiledPass?.enabled===true&&state.compiledPass.prepared===true&&state.compiledPass.replayed>0&&state.compiledPass.draws>0&&state.compiledPass.commands>0,'Compiled main pass was not exercised');
  return{index,mode:m.mode,...metrics};
 });
 check(phases[0].mode==='baseline'&&phases.at(-1).mode==='baseline','Comparison must be bounded by baseline controls');
 const counts=new Map();for(const phase of phases)counts.set(phase.mode,(counts.get(phase.mode)??0)+1);check([...counts.values()].every(n=>n>=2),'Each replay mode requires repeated measurements');
 const baselines=phases.filter(p=>p.mode==='baseline'),spreadPercent=(Math.max(...baselines.map(p=>p.averageMs))/Math.min(...baselines.map(p=>p.averageMs))-1)*100;
 const repeats=[...counts.keys()].map(mode=>{const rows=phases.filter(p=>p.mode===mode);return{mode,spreadPercent:(Math.max(...rows.map(p=>p.averageMs))/Math.min(...rows.map(p=>p.averageMs))-1)*100};});
 const warnings=repeats.filter(r=>r.spreadPercent>5).map(r=>r.mode+' frame time spread exceeds 5%; reject speedup inference'),trustworthy=warnings.length===0;
 return{scope:'One complete frozen room at the configured experimental profile; full RAF observations, not a production control, isolated GPU timing or native fidelity acceptance',phases,baselineSpreadPercent:spreadPercent,modeRepeatSpread:repeats,timingComparisonValid:trustworthy,warnings,measuredSteadyTargetMet:trustworthy&&phases.every(p=>p.targetMet),recordedFrameParity:report.parity,enableByDefault:false,goalComplete:false};
}
