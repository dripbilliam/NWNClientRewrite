'use strict';
// Accepted Core E ABBA replay. --verify-only performs no client launch.
// The coordinator must grant the exclusive timing lease before running legs.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn74/base-merge-pair-a');
const stage=JSON.parse(fs.readFileSync(path.join(scope,'staged.json')));
const driver=path.join(root,'tools/replay-native-loading.mjs');
const driverSha256='edf88a0ac03a7446b275e182f45f941817c805471d084ee9bc82ef059a3f184c';
const expectedEnvironmentErrors=["ERROR: Can't create shader cache folder, no shader caching will happen: user://","ERROR: Failed to read the root certificate store."];
const order=['off','on','on','off'],mergeFlags=new Set(['--static-scenery=merged','--base-scenery-draw=merged']);
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const digest=value=>crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
async function verify(){
 assert(stage.private&&!stage.accepted&&stage.issue==='NWN-74');
 assert.equal(sha(stage.sourceStage),stage.sourceStageSha256);
 assert.equal(sha(driver),driverSha256);
 assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
 for(const pin of stage.pins)assert.equal(sha(path.join(stage.input,pin.relative)),pin.sha256,'Input pin changed: '+pin.relative);
 const helper=require(path.join(stage.input,'tools/native-production-selection.cjs'));
 const off=await helper.readProductionSelection(stage.selections.off.file,stage.selections.off.sha256);
 const on=await helper.readProductionSelection(stage.selections.on.file,stage.selections.on.sha256);
 assert.equal(off.mainSourceIdentity.sha256,on.mainSourceIdentity.sha256);
 assert.equal(off.mainSourceIdentity.sha256,stage.selections.off.sourceIdentity);
 assert.equal(off.runtime.executableSha256,on.runtime.executableSha256);
 assert.equal(off.runtime.executableSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
 assert.equal(off.runtime.kind,'verified-native');
 assert.equal(off.preferences.render.sha256,on.preferences.render.sha256);
 assert.equal(off.preferences.layout.sha256,on.preferences.layout.sha256);
 assert.deepEqual(off.flags.filter(x=>!mergeFlags.has(x)),on.flags.filter(x=>!mergeFlags.has(x)));
 assert([...mergeFlags].every(x=>on.flags.includes(x))&&![...mergeFlags].some(x=>off.flags.includes(x)));
 assert.equal(off.profiling,'true');assert.equal(on.profiling,'true');
 const timeline=fs.readFileSync(path.join(stage.capture,'timeline.jsonl'),'utf8').trim().split(/\r?\n/).map(JSON.parse);
 const {selectGeneration}=await import(pathToFileURL(path.join(root,'tools/native-loading-selection.mjs')).href);
 assert.equal(selectGeneration(timeline,2).filter(x=>x.kind==='movement-input').length,360);
 return {issue:'NWN-74',engine:'accepted Core E',engineSha256:off.runtime.executableSha256,sourceIdentity:off.mainSourceIdentity.sha256,driverSha256,selectionSha256:{off:stage.selections.off.sha256,on:stage.selections.on.sha256},captureSha256:stage.recordingSha256,changedNativeOutputs:[...mergeFlags],order,steadyMs:15000,expectedArea:2147618622,scope:'Accepted production runtime and pinned original generation-2 replay; profile ON. Streamed versus merged changes static scenery and BASE draw merging together. No Arelith claim.'};
}
function diagnostics(run){
 const log=fs.readFileSync(path.join(root,'reports',run+'.engine.log'),'utf8');
 const errors=log.split(/\r?\n/).filter(x=>x.startsWith('ERROR: '));
 assert(errors.length===0||JSON.stringify(errors)===JSON.stringify(expectedEnvironmentErrors),'Unexpected engine diagnostics');
 assert(!/(SCRIPT ERROR|FATAL|leaked|still in use)/i.test(log),'Engine script/lifetime failure');
 return errors.length>0;
}
function profile(report){
 const obs=report.profileObservations;
 assert(obs?.samples>=4&&fs.existsSync(obs.file),'Profile observations missing');
 assert.equal(sha(obs.file),obs.sha256,'Profile observation changed');
 const window=report.native.performance_window;
 const rows=fs.readFileSync(obs.file,'utf8').trim().split(/\r?\n/).map(JSON.parse);
 const eligible=rows.filter(row=>row.elapsedMs>=window.started_at_ms&&row.elapsedMs<=window.started_at_ms+window.elapsed_ms&&row.areaId===2147618622&&row.frame_profile?.enabled&&row.frame_profile.frames>=30);
 assert(eligible.length>=3,'Too few matched main-lane profile windows');
 const mean=key=>eligible.reduce((sum,row)=>sum+Number(row.frame_profile.metrics[key]?.when_present_mean??row.frame_profile.metrics[key]?.mean??0),0)/eligible.length;
 return {windows:eligible.length,mainWallMs:mean('wall_ms'),callbackEnvelopeMs:mean('callback_envelope_ms'),draws:mean('draws'),nodes:mean('nodes')};
}
function summarize(report,mode,run,exit){
 assert.equal(report.sourceUnchanged,true);assert.equal(report.runtimeUnchanged,true);
 assert.equal(report.runtimeSha256?.engine,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionCameraVerification?.status,'observed');
 assert.equal(report.renderingMethodMatched,true);assert.equal(report.profilingMatched,true);
 assert.equal(report.secondaryMonitorVerified,true);
 assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(report.productionPreferences?.verification?.status,'observed');
 assert.equal(report.native?.playable,true);assert.equal(report.native?.object_visuals_complete,true);
 assert.equal(report.native?.protocol_finish_ack,true);assert.equal(report.native?.world?.area_id,2147618622);
 assert.equal(report.native?.performance_window?.steady,true);
 assert(report.native.performance_window.elapsed_ms>=15000);
 const scenery=report.native?.world?.base_scenery;
 assert.equal(scenery?.known_base_complete,true);assert.equal(scenery?.pending,0);assert.equal(scenery?.failed,0);assert.equal(scenery?.resolved,scenery?.expected);
 assert.equal(report.native?.world?.base_draw_merge?.enabled,mode==='on');
 if(mode==='on')assert(report.native.world.base_draw_merge.source_draws_replaced>0);
 assert.equal(Object.keys(report.native?.world?.failed_objects??{}).length,0);
 assert.equal(report.native?.world?.errors?.length??0,0);assert.equal(report.exit,0);
 const conditional=diagnostics(run);
 assert.equal(exit,conditional?1:0,'Driver exit differs from classified engine diagnostics');
 assert.equal(report.engineOrLifetimeError,conditional);
 if(conditional)assert.equal(report.failure,'Native engine/lifetime diagnostics observed');
 const frame=report.native.frame_intervals;
 const milestone=report.milestones.map(x=>[x.kind,x.generation,x.serial]);assert(milestone.length>20);
 return {run,mode,report:path.join(root,'reports',run+'.json'),reportSha256:sha(path.join(root,'reports',run+'.json')),conditionalEnvironmentDiagnostic:conditional,milestoneCount:milestone.length,milestoneDigest:digest(milestone),protocolObjectDigest:digest(report.native.protocol_objects),frame:{mean:frame.average_ms,median:frame.median_ms,p95:frame.p95_ms,p99:frame.p99_ms,worst:frame.worst_ms,count:frame.count},mainLane:profile(report),scene:{baseDraw:report.native.world.base_draw_merge,scenery,lights:report.native?.world?.native_lighting},loading:{playableMs:report.native.world.playable_ms,baseKnownCompleteMs:scenery.first_known_complete_ms}};
}
async function leg(mode,index){
 const run=`nwn74-normal-base-merge-a-${index+1}-${mode}`;
 const reportFile=path.join(root,'reports',run+'.json'),logFile=path.join(scope,run+'.driver.log');
 assert(!fs.existsSync(reportFile)&&!fs.existsSync(logFile),'Preserve prior run');
 const args=[driver,'--capture='+stage.capture,'--generation=2','--production-selection='+stage.selections[mode].file,'--production-selection-sha256='+stage.selections[mode].sha256,'--engine=production-selection','--profiling=true','--observe-profile=true','--steady-ms=15000','--preview','--run='+run];
 const output=fs.createWriteStream(logFile,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>output.write(chunk));
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
 await new Promise(resolve=>output.end(resolve));
 assert(exit===0||exit===1,'Replay driver exit differs');
 const report=JSON.parse(fs.readFileSync(reportFile));
 const result=summarize(report,mode,run,exit);
 console.log(JSON.stringify({run,exit,frame:result.frame,mainLane:result.mainLane}));
 return result;
}
async function main(){const plan=await verify();if(process.argv.includes('--verify-only')){console.log(JSON.stringify({...plan,runnerSha256:sha(__filename),clientStarts:0},null,2));return;}
 const runs=[],partial=path.join(scope,'normal-matrix-partial.json');
 for(let i=0;i<order.length;i++){runs.push(await leg(order[i],i));fs.writeFileSync(partial,JSON.stringify({plan,runs},null,2)+'\n');}
 assert(runs.every(x=>x.milestoneDigest===runs[0].milestoneDigest));
 assert(runs.every(x=>x.protocolObjectDigest===runs[0].protocolObjectDigest));
 const file=path.join(scope,'normal-matrix-review.json');
 fs.writeFileSync(file,JSON.stringify({issue:'NWN-74',success:true,plan,runs,scope:'Accepted Core E original-scene offline ABBA with internal main-lane profile; not live Arelith or pixel parity.'},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),success:true}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
