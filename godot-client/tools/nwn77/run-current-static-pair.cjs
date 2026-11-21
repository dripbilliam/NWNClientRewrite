'use strict';
// Exclusive timing lease only. Four normal-client original-scene replay legs.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const variant=process.argv.includes('--base')?'base':'static';
const flag=variant==='base'?'--base-scenery-draw=merged':'--static-scenery=merged';
const scope=path.join(root,`.cache/nwn77/current-${variant}-pair-a`);
const stageFile=path.join(scope,'staged.json');
const stage=JSON.parse(fs.readFileSync(stageFile));
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const order=['off','on','on','off'];
async function verify(){
 assert(stage.private&&!stage.accepted&&stage.variant===variant);
 assert.equal(hash(path.join(stage.capture,'recording.json')),stage.recordingSha256);
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const off=await helper.readProductionSelection(stage.selections.off.file,stage.selections.off.sha256);
 const on=await helper.readProductionSelection(stage.selections.on.file,stage.selections.on.sha256);
 assert.equal(off.mainSourceIdentity.sha256,on.mainSourceIdentity.sha256);
 assert.equal(off.mainSourceIdentity.sha256,stage.sourceIdentity);
 assert.equal(off.runtime.executableSha256,on.runtime.executableSha256);
 assert.equal(off.runtime.executableSha256,stage.engineSha256);
 assert.equal(off.preferences.render.sha256,on.preferences.render.sha256);
 assert.equal(off.preferences.layout.sha256,on.preferences.layout.sha256);
 assert.deepEqual(off.flags.filter(x=>x!==flag),on.flags.filter(x=>x!==flag));
 assert(!off.flags.includes(flag)&&on.flags.includes(flag));
 assert.equal(off.profiling,'false');assert.equal(on.profiling,'false');
 return {sourceIdentity:stage.sourceIdentity,engineSha256:stage.engineSha256,selectionSha256:{off:stage.selections.off.sha256,on:stage.selections.on.sha256},recordingSha256:stage.recordingSha256,order,steadyMs:15000};
}
function summarize(run,mode,exit){
 const file=path.join(root,'reports',run+'.json');
 const report=JSON.parse(fs.readFileSync(file));
 assert.equal(report.exit,0);
 assert(report.sourceUnchanged&&report.runtimeUnchanged);
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionCameraVerification?.status,'observed');
 assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(report.native?.world?.area_id,2147618622);
 assert(report.native?.performance_window?.steady&&report.native.performance_window.elapsed_ms>=15000);
 assert(report.native?.playable&&report.native?.object_visuals_complete&&report.native?.protocol_finish_ack);
 const scenery=report.native.world.base_scenery;
 assert(scenery?.known_base_complete&&scenery.pending===0&&scenery.failed===0&&scenery.resolved===scenery.expected);
 assert.equal(Object.keys(report.native.world.failed_objects??{}).length,0);
 assert.equal(report.native.world.errors?.length??0,0);
 const log=fs.readFileSync(path.join(root,'reports',run+'.engine.log'),'utf8');
 const errors=log.split(/\r?\n/).filter(x=>x.startsWith('ERROR: '));
 const allowed=new Set(["ERROR: Can't create shader cache folder, no shader caching will happen: user://",'ERROR: Failed to read the root certificate store.']);
 assert(errors.every(x=>allowed.has(x)),'Unexpected engine diagnostic');
 assert(!/(SCRIPT ERROR|FATAL|leaked|still in use)/i.test(log),'Engine script/lifetime error');
 assert(exit===0||exit===1&&errors.length>0,'Unexpected driver exit');
 const frame=report.native.frame_intervals;
 return {run,mode,report:file,reportSha256:hash(file),conditionalEnvironmentDiagnostic:errors,frame:{mean:frame.average_ms,median:frame.median_ms,p95:frame.p95_ms,p99:frame.p99_ms,worst:frame.worst_ms,count:frame.count},world:{terrainStatic:report.native.world.terrain?.static_scenery,baseDraw:report.native.world.base_draw_merge,baseScenery:{expected:scenery.expected,resolved:scenery.resolved,knownBaseComplete:scenery.known_base_complete},playableMs:report.native.world.playable_ms,baseKnownCompleteMs:scenery.first_known_complete_ms}};
}
async function leg(mode,index){
 const run=`nwn77-current-${variant}-a-${index+1}-${mode}`;
 const reportFile=path.join(root,'reports',run+'.json'),logFile=path.join(scope,run+'.driver.log');
 assert(!fs.existsSync(reportFile)&&!fs.existsSync(logFile),'Preserve prior run');
 const args=[path.join(root,'tools/replay-native-loading.mjs'),'--capture='+stage.capture,'--generation=2','--production-selection='+stage.selections[mode].file,'--production-selection-sha256='+stage.selections[mode].sha256,'--engine=production-selection','--profiling=false','--steady-ms=15000','--preview','--run='+run];
 const output=fs.createWriteStream(logFile,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>output.write(chunk));
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
 await new Promise(resolve=>output.end(resolve));
 const result=summarize(run,mode,exit);
 console.log(JSON.stringify({run,exit,frame:result.frame}));
 return result;
}
async function main(){const plan=await verify();if(process.argv.includes('--verify-only')){console.log(JSON.stringify({...plan,clientStarts:0},null,2));return;}
 const runs=[],partial=path.join(scope,'matrix-partial.json');
 for(let i=0;i<order.length;i++){runs.push(await leg(order[i],i));fs.writeFileSync(partial,JSON.stringify({plan,runs},null,2)+'\n');}
 const file=path.join(scope,'matrix-review.json');fs.writeFileSync(file,JSON.stringify({issue:stage.issue,success:true,plan,runs,scope:`Current-source original-scene offline ABBA with ${variant} scenery only; no live Arelith or pixel parity.`},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:hash(file),success:true}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
