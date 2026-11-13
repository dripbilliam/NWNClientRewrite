'use strict';
// Four private render-probe legs, streamed/merged/merged/streamed. --verify-only
// never launches. The coordinator must grant the exclusive timing lease first.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {spawn,execFile}=require('node:child_process');
const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn74/base-merge-pair-a');
const stageFile=path.join(scope,'staged.json'),stage=JSON.parse(fs.readFileSync(stageFile));
const verifyOnly=process.argv.includes('--verify-only');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const digest=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const ordered=['off','on','on','off'];
const mergeFlags=new Set(['--static-scenery=merged','--base-scenery-draw=merged']);
const expectedEnvironmentErrors=["ERROR: Can't create shader cache folder, no shader caching will happen: user://","ERROR: Failed to read the root certificate store."];
async function verify(){
 assert(stage.private&&!stage.accepted&&stage.issue==='NWN-74');
 assert.equal(sha(stage.sourceStage),stage.sourceStageSha256);
 assert.equal(sha(stage.engine.receipt),stage.engine.receiptSha256);
 assert.equal(sha(stage.engine.file),stage.engine.sha256);
 assert.equal(sha(stage.driver),stage.driverSha256);
 assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
 for(const pin of stage.pins)assert.equal(sha(path.join(stage.input,pin.relative)),pin.sha256,'Input pin changed: '+pin.relative);
 const helper=require(path.join(stage.input,'tools/native-production-selection.cjs'));
 const off=await helper.readProductionSelection(stage.selections.off.file,stage.selections.off.sha256);
 const on=await helper.readProductionSelection(stage.selections.on.file,stage.selections.on.sha256);
 assert.equal(off.mainSourceIdentity.sha256,on.mainSourceIdentity.sha256);
 assert.equal(off.mainSourceIdentity.sha256,stage.selections.off.sourceIdentity);
 assert.equal(on.mainSourceIdentity.sha256,stage.selections.on.sourceIdentity);
 assert.equal(off.runtime.executableSha256,on.runtime.executableSha256);
 assert.equal(off.preferences.render.sha256,on.preferences.render.sha256);
 assert.equal(off.preferences.layout.sha256,on.preferences.layout.sha256);
 assert.deepEqual(off.flags.filter(x=>!mergeFlags.has(x)),on.flags.filter(x=>!mergeFlags.has(x)));
 assert([...mergeFlags].every(x=>on.flags.includes(x))&&![...mergeFlags].some(x=>off.flags.includes(x)));
 assert.equal(off.loadingPipeline.pipeline,'streamed');assert.equal(on.loadingPipeline.pipeline,'merged');
 assert.equal(off.profiling,'true');assert.equal(on.profiling,'true');
 const timeline=fs.readFileSync(path.join(stage.capture,'timeline.jsonl'),'utf8').trim().split(/\r?\n/).map(JSON.parse);
 const {selectGeneration}=await import(pathToFileURL(path.join(root,'tools/native-loading-selection.mjs')).href);
 const generation=selectGeneration(timeline,2);
 assert(generation.filter(x=>x.kind==='movement-input').length===360);
 return {stageSha256:sha(stageFile),runnerSha256:sha(__filename),sourceIdentity:off.mainSourceIdentity.sha256,privateEngineSha256:stage.engine.sha256,driverSha256:stage.driverSha256,captureSha256:stage.recordingSha256,selectionSha256:{off:stage.selections.off.sha256,on:stage.selections.on.sha256},changedNativeOutputs:[...mergeFlags],generation:2,movementInputs:360,expectedScene:{areaId:2147618622,completeWorld:true,objectVisuals:true,protocolFinishAck:true},steadyMs:15000,order:ordered,anticipatedMinutes:5,scope:stage.scope};
}
function memoryProbe(){return new Promise((resolve,reject)=>{
 const script="$p=@(Get-Process -Name 'Godot_nwn74_render_probe_b_win64' -ErrorAction SilentlyContinue); if($p.Count -gt 1){throw 'Multiple private probe engines'}; if($p.Count -eq 0){'0 0 0'}else{$q=$p[0];[string]$q.Id+' '+[string]$q.PeakWorkingSet64+' '+[string]$q.PrivateMemorySize64}";
 execFile('pwsh',['-NoProfile','-Command',script],{windowsHide:true,timeout:5000},(error,stdout)=>{
  if(error)return reject(error);
  const parts=stdout.trim().split(/\s+/).map(Number);
  if(parts.length!==3||parts.some(x=>!Number.isSafeInteger(x)))return reject(Error('Invalid process-memory sample'));
  resolve({pid:parts[0],peakWorkingSetBytes:parts[1],privateBytes:parts[2]});
 });
});}
function environmentOnly(run){
 const log=fs.readFileSync(path.join(root,'reports',run+'.engine.log'),'utf8');
 const lines=log.split(/\r?\n/).filter(x=>x.startsWith('ERROR: '));
 const recognized=lines.length===0||lines.length===2&&JSON.stringify(lines)===JSON.stringify(expectedEnvironmentErrors);
 return {accepted:recognized&&!/(SCRIPT ERROR|FATAL|leaked|still in use)/i.test(log),conditional:lines.length===2,errors:lines};
}
function summary(report,mode,run,memory){
 assert.equal(report.sourceUnchanged,true);assert.equal(report.runtimeUnchanged,true);
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionCameraVerification?.status,'observed');
 assert.equal(report.renderingMethodMatched,true);assert.equal(report.profilingMatched,true);
 assert.equal(report.particleEngineReads?.verified,true);assert.equal(report.terrainHeight?.verified,true);
 assert.equal(report.secondaryMonitorVerified,true);assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(report.productionPreferences?.verification?.status,'observed');
 assert.equal(report.native?.playable,true);assert.equal(report.native?.object_visuals_complete,true);
 assert.equal(report.native?.protocol_finish_ack,true);assert.equal(report.native?.world?.area_id,2147618622);
 assert.equal(report.native?.performance_window?.steady,true);
 assert(report.native.performance_window.elapsed_ms>=15000);
 const scenery=report.native?.world?.base_scenery;
 assert.equal(scenery?.known_base_complete,true);
 assert.equal(scenery?.pending,0);assert.equal(scenery?.failed,0);
 assert.equal(scenery?.resolved,scenery?.expected);
 assert.equal(report.native?.world?.base_draw_merge?.enabled,mode==='on');
 if(mode==='on')assert(report.native.world.base_draw_merge.source_draws_replaced>0);
 assert.equal(Object.keys(report.native?.world?.failed_objects??{}).length,0);
 assert.equal(report.native?.world?.errors?.length??0,0);
 assert.equal(report.exit,0);
 const diagnostics=environmentOnly(run);
 assert(diagnostics.accepted,'Only clean logs or the two known sandbox environment diagnostics are allowed');
 if(diagnostics.conditional){assert.equal(report.failure,'Native engine/lifetime diagnostics observed');assert.equal(report.engineOrLifetimeError,true);}
 else assert.equal(report.engineOrLifetimeError,false);
 const metrics=report.profileObservations;
 assert(metrics?.samples>=4&&fs.existsSync(metrics.file),'Render phase observations missing');
 const rows=fs.readFileSync(metrics.file,'utf8').trim().split(/\r?\n/).map(JSON.parse);
 const window=report.native.performance_window;
 const eligible=rows.filter(row=>row.elapsedMs>=window.started_at_ms&&row.elapsedMs<=window.started_at_ms+window.elapsed_ms&&row.areaId===2147618622&&row.frame_profile?.enabled&&row.frame_profile.frames>=30&&row.frame_profile.metrics?.rt_frame_wall_us);
 assert(eligible.length>=3,'Too few completed render phase windows');
 const mean=key=>eligible.reduce((sum,row)=>sum+Number(row.frame_profile.metrics[key]?.when_present_mean??row.frame_profile.metrics[key]?.mean??0),0)/eligible.length;
 const frame=report.native.frame_intervals;
 const milestone=report.milestones.map(x=>[x.kind,x.generation,x.serial]);assert(milestone.length>20);
 return {run,mode,report:path.join(root,'reports',run+'.json'),reportSha256:sha(path.join(root,'reports',run+'.json')),conditionalEnvironmentDiagnostic:diagnostics.conditional,engineErrors:diagnostics.errors,milestoneCount:milestone.length,milestoneDigest:digest(milestone),protocolObjectDigest:digest(report.native.protocol_objects),frame:{mean:frame.average_ms,median:frame.median_ms,p95:frame.p95_ms,p99:frame.p99_ms,worst:frame.worst_ms,count:frame.count},renderPhaseMs:{frame:mean('rt_frame_wall_us')/1000,setup:mean('rt_setup_wall_us')/1000,dirtyDrain:mean('rt_dirty_drain_setup_us')/1000,pairRepair:mean('rt_pair_repair_us')/1000,viewport:mean('rt_viewport_draw_us')/1000,shadowPreparation:mean('rt_shadow_prep_us')/1000,forward:mean('rt_forward_total_us')/1000,forwardDrawList:mean('rt_forward_draw_list_us')/1000},scene:{instances:mean('rt_scene_instance_count'),visibleGeometry:mean('rt_visible_geometry_count'),visibleLights:mean('rt_visible_light_count'),shadows:mean('rt_scene_shadow_count'),baseDraw:report.native.world.base_draw_merge,scenery:report.native.world.base_scenery},loading:{playableMs:report.native.world.playable_ms,baseKnownCompleteMs:report.native.world.base_scenery.first_known_complete_ms},memory};
}
async function runLeg(mode,index){
 const run=`nwn74-base-merge-b-${index+1}-${mode}`,selection=stage.selections[mode];
 const reportFile=path.join(root,'reports',run+'.json'),logFile=path.join(scope,run+'.driver.log');
 assert(!fs.existsSync(reportFile)&&!fs.existsSync(logFile),'Preserve prior run');
 const args=[stage.driver,'--capture='+stage.capture,'--generation=2','--production-selection='+selection.file,'--production-selection-sha256='+selection.sha256,'--engine=production-selection','--profiling=true','--observe-profile=true','--steady-ms=15000','--preview','--run='+run];
 const output=fs.createWriteStream(logFile,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>output.write(chunk));
 let peakWorkingSetBytes=0,peakPrivateBytes=0,observedPid=0,probeFailure=null,probing=false;
 const timer=setInterval(async()=>{if(probing)return;probing=true;try{const sample=await memoryProbe();if(sample.pid){observedPid=sample.pid;peakWorkingSetBytes=Math.max(peakWorkingSetBytes,sample.peakWorkingSetBytes);peakPrivateBytes=Math.max(peakPrivateBytes,sample.privateBytes);}}catch(error){probeFailure=error.message;}finally{probing=false;}},3000);
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});clearInterval(timer);
 await new Promise(resolve=>output.end(resolve));
 const after=await memoryProbe();assert.equal(after.pid,0,'Private engine remained open after replay driver exited');
 assert(exit===0||exit===1,'Replay driver exit differs');assert(!probeFailure,'Memory probe failed: '+probeFailure);assert(observedPid>0&&peakWorkingSetBytes>0,'Private engine process not observed');
 const report=JSON.parse(fs.readFileSync(reportFile));const result=summary(report,mode,run,{pid:observedPid,peakWorkingSetBytes,peakPrivateBytes});
 assert.equal(exit,result.conditionalEnvironmentDiagnostic?1:0,'Driver exit does not match the classified engine diagnostics');
 console.log(JSON.stringify({run,exit,frame:result.frame,renderPhaseMs:result.renderPhaseMs,sceneInstances:result.scene.instances,visibleGeometry:result.scene.visibleGeometry,memory:result.memory}));
 return result;
}
async function main(){const plan=await verify();if(verifyOnly){const memory=await memoryProbe();assert.equal(memory.pid,0,'Private probe engine already open');console.log(JSON.stringify({...plan,memoryPreflight:memory},null,2));return;}
 const runs=[];const partial=path.join(scope,'matrix-partial.json');
 for(let i=0;i<ordered.length;i++){runs.push(await runLeg(ordered[i],i));fs.writeFileSync(partial,JSON.stringify({plan,runs},null,2)+'\n');}
 assert(runs.every(x=>x.milestoneDigest===runs[0].milestoneDigest));
 assert(runs.every(x=>x.protocolObjectDigest===runs[0].protocolObjectDigest));
 assert(runs.every(x=>x.scene.visibleLights===runs[0].scene.visibleLights));
 assert(runs.every(x=>x.scene.shadows===runs[0].scene.shadows));
 const review={issue:'NWN-74',success:true,plan,runs,scope:'Private diagnostic engine, profile ON; streamed versus merged changes static scenery and BASE draw merging together. This is conditional local graphical evidence, not a normal-client FPS or live Arelith acceptance.'};
 const file=path.join(scope,'matrix-review.json');fs.writeFileSync(file,JSON.stringify(review,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(file),success:true}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
