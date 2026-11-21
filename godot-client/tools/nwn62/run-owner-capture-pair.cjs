'use strict';
// Exclusive loading/FPS timing lease only. Two source trees differ in exactly
// the large-template owner-capture path; both use the same accepted engine.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const scope=path.join(root,'.cache/nwn62/owner-capture-pair-a');
const stage=JSON.parse(fs.readFileSync(path.join(scope,'staged.json')));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const order=['control','candidate','candidate','control'];
async function verify(){
 assert(stage.private&&!stage.accepted&&stage.issue==='NWN-62');
 assert.deepEqual(stage.changed,['systems/native_render/model_template.gd','systems/native_render/native_model_recipe.gd']);
 assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const control=await helper.readProductionSelection(stage.selections.control.file,stage.selections.control.sha256);
 const candidate=await helper.readProductionSelection(stage.selections.candidate.file,stage.selections.candidate.sha256);
 assert.equal(control.mainSourceIdentity.sha256,stage.selections.control.sourceIdentity);
 assert.equal(candidate.mainSourceIdentity.sha256,stage.selections.candidate.sourceIdentity);
 assert.equal(control.runtime.executableSha256,candidate.runtime.executableSha256);
 assert.equal(control.runtime.executableSha256,stage.engineSha256);
 assert.deepEqual(control.options,candidate.options);
 assert.deepEqual(control.flags,candidate.flags);
 assert.equal(control.preferences.render.sha256,candidate.preferences.render.sha256);
 assert.equal(control.preferences.layout.sha256,candidate.preferences.layout.sha256);
 const a=new Map(control.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 const b=new Map(candidate.mainSourceIdentity.files.map(x=>[x.file,x.sha256]));
 assert.deepEqual([...a.keys()].sort(),[...b.keys()].sort());
 assert.deepEqual([...a.keys()].filter(key=>a.get(key)!==b.get(key)).sort(),stage.changed);
 return {sourceIdentities:{control:control.mainSourceIdentity.sha256,candidate:candidate.mainSourceIdentity.sha256},engineSha256:stage.engineSha256,recordingSha256:stage.recordingSha256,order,steadyMs:5000};
}
function summarize(run,mode,exit){
 const file=path.join(root,'reports',run+'.json');const report=JSON.parse(fs.readFileSync(file));
 assert.equal(report.exit,0);assert(report.sourceUnchanged&&report.runtimeUnchanged);
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionCameraVerification?.status,'observed');
 assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(report.native?.world?.area_id,2147618622);
 assert(report.native?.performance_window?.steady&&report.native.performance_window.elapsed_ms>=5000);
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
 const entry=report.native.entry_commit_entries;
 return {run,mode,report:file,reportSha256:sha(file),conditionalEnvironmentDiagnostic:errors,frame:{mean:frame.average_ms,median:frame.median_ms,p95:frame.p95_ms,p99:frame.p99_ms,worst:frame.worst_ms,count:frame.count},entry:{playableMs:report.native.world.playable_ms,baseKnownCompleteMs:scenery.first_known_complete_ms,adoptionTimings:report.native.world.adoption_timings,commitEntries:entry},scene:{entities:report.native.performance_window.entities,baseExpected:scenery.expected,baseResolved:scenery.resolved,models:report.productionFeatures?.modelConstruction}};
}
async function leg(mode,index){
 const run=`nwn62-owner-capture-a-${index+1}-${mode}`;
 const file=path.join(root,'reports',run+'.json'),log=path.join(scope,run+'.driver.log');
 assert(!fs.existsSync(file)&&!fs.existsSync(log),'Preserve previous run');
 const args=[path.join(root,'tools/replay-native-loading.mjs'),'--capture='+stage.capture,'--generation=2','--production-selection='+stage.selections[mode].file,'--production-selection-sha256='+stage.selections[mode].sha256,'--engine=production-selection','--profiling=false','--steady-ms=5000','--preview','--run='+run];
 const output=fs.createWriteStream(log,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>output.write(chunk));
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
 await new Promise(resolve=>output.end(resolve));
 const result=summarize(run,mode,exit);
 console.log(JSON.stringify({run,exit,frame:result.frame,playableMs:result.entry.playableMs,baseKnownCompleteMs:result.entry.baseKnownCompleteMs}));
 return result;
}
async function main(){const plan=await verify();if(process.argv.includes('--verify-only')){console.log(JSON.stringify({...plan,clientStarts:0},null,2));return;}
 const runs=[];for(let i=0;i<order.length;i++){runs.push(await leg(order[i],i));fs.writeFileSync(path.join(scope,'matrix-partial.json'),JSON.stringify({plan,runs},null,2)+'\n');}
 const file=path.join(scope,'matrix-review.json');fs.writeFileSync(file,JSON.stringify({issue:'NWN-62',success:true,plan,runs,scope:'Current-source isolated owner-capture offline ABBA; profile off; no live Arelith or pixel acceptance.'},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),success:true}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
