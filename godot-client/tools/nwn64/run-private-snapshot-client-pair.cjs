'use strict';
// Exclusive matched original-scene normal-client ABBA; no accepted artifact.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const scope=path.join(root,'.cache/nwn64/animation-snapshot-client-pair-a');
const stage=JSON.parse(fs.readFileSync(path.join(scope,'staged.json')));
const order=['off','on','on','off'];
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
async function verify(){
 assert(stage.private&&!stage.accepted&&stage.issue==='NWN-64');
 assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const rows={};for(const mode of ['off','on'])rows[mode]=await helper.readProductionSelection(stage.selections[mode].file,stage.selections[mode].sha256);
 for(const mode of ['off','on']){
  assert.equal(rows[mode].mainSourceIdentity.sha256,stage.sourceIdentity);
  assert.equal(rows[mode].runtime.executableSha256,stage.engineSha256);
  assert.equal(rows[mode].evidence.particleSha256,stage.particleSha256);
  assert(rows[mode].flags.includes('--particle-animation-snapshot='+mode));
 }
 assert.equal(rows.off.preferences.render.sha256,rows.on.preferences.render.sha256);
 assert.equal(rows.off.preferences.layout.sha256,rows.on.preferences.layout.sha256);
 assert.deepEqual(rows.off.flags.map(x=>x.replace('particle-animation-snapshot=off','particle-animation-snapshot=on')),rows.on.flags);
 return {order,sourceIdentity:stage.sourceIdentity,engineSha256:stage.engineSha256,particleSha256:stage.particleSha256,recordingSha256:stage.recordingSha256,steadyMs:5000};
}
function summarize(run,mode,exit){
 const file=path.join(root,'reports',run+'.json'),report=JSON.parse(fs.readFileSync(file));
 assert.equal(report.exit,0);assert(report.sourceUnchanged&&report.runtimeUnchanged);
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionCameraVerification?.status,'observed');
 assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(report.native?.world?.area_id,2147618622);
 assert(report.native?.playable&&report.native?.object_visuals_complete&&report.native?.protocol_finish_ack);
 const scenery=report.native.world.base_scenery;
 assert(scenery?.known_base_complete&&scenery.pending===0&&scenery.failed===0&&scenery.resolved===scenery.expected);
 const stream=report.native.world.native_particle_stream;
 assert(stream&&!stream.closed&&!stream.failure&&stream.fast_members>=1000&&stream.fallback_reasons&&Object.keys(stream.fallback_reasons).length===0);
 assert.equal(stream.animation_snapshot,mode==='on','Actual particle snapshot route differs');
 assert.equal(stream.native.registered,stream.fast_members);
 assert(stream.native.vertices>0&&stream.renderer.last_vertices>0);
 assert(report.native.performance_window?.steady&&report.native.performance_window.elapsed_ms>=5000);
 assert.equal(Object.keys(report.native.world.failed_objects??{}).length,0);
 assert.equal(report.native.world.errors?.length??0,0);
 const log=fs.readFileSync(path.join(root,'reports',run+'.engine.log'),'utf8');
 const errors=log.split(/\r?\n/).filter(x=>x.startsWith('ERROR: '));
 const allowed=new Set(["ERROR: Can't create shader cache folder, no shader caching will happen: user://",'ERROR: Failed to read the root certificate store.']);
 assert(errors.every(x=>allowed.has(x)),'Unexpected engine diagnostic');
 assert(!/(SCRIPT ERROR|FATAL|leaked|still in use)/i.test(log),'Engine script/lifetime error');
 assert(exit===0||exit===1&&errors.length>0,'Unexpected driver exit');
 const frame=report.native.frame_intervals;
 return {run,mode,report:file,reportSha256:sha(file),conditionalEnvironmentDiagnostic:errors,frame:{mean:frame.average_ms,median:frame.median_ms,p95:frame.p95_ms,p99:frame.p99_ms,worst:frame.worst_ms,count:frame.count},entry:{playableMs:report.native.world.playable_ms,baseKnownCompleteMs:scenery.first_known_complete_ms},particles:{members:stream.members,fastMembers:stream.fast_members,registered:stream.native.registered,active:stream.native.active,vertices:stream.native.vertices,draws:stream.native.draws,rendererLastVertices:stream.renderer.last_vertices,snapshot:stream.animation_snapshot}};
}
async function leg(mode,index){
 const run=`nwn64-snapshot-client-a-${index+1}-${mode}`;
 const file=path.join(root,'reports',run+'.json'),log=path.join(scope,run+'.driver.log');
 assert(!fs.existsSync(file)&&!fs.existsSync(log),'Preserve previous run');
 const args=[path.join(root,'tools/replay-native-loading.mjs'),'--capture='+stage.capture,'--generation=2','--production-selection='+stage.selections[mode].file,'--production-selection-sha256='+stage.selections[mode].sha256,'--engine=production-selection','--profiling=false','--steady-ms=5000','--preview','--run='+run];
 const output=fs.createWriteStream(log,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>output.write(chunk));
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
 await new Promise(resolve=>output.end(resolve));
 const result=summarize(run,mode,exit);
 console.log(JSON.stringify({run,exit,frame:result.frame,particles:result.particles}));return result;
}
async function main(){
 const plan=await verify();if(process.argv.includes('--verify-only')){console.log(JSON.stringify({...plan,clientStarts:0},null,2));return;}
 const runs=[];for(let index=0;index<order.length;index++){runs.push(await leg(order[index],index));fs.writeFileSync(path.join(scope,'matrix-partial.json'),JSON.stringify({plan,runs},null,2)+'\n');}
 const file=path.join(scope,'matrix-review.json');fs.writeFileSync(file,JSON.stringify({issue:'NWN-64',success:true,plan,runs,scope:'Same private particle DLL normal-client original-scene ABBA; no accepted default or Arelith claim.'},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file,sha256:sha(file),success:true}));
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
