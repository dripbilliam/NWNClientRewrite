'use strict';
// Verify by default. An explicit --run=<planned-label> executes one matched
// normal-client replay; the coordinator grants the exclusive FPS lease.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {spawn,execFile}=require('node:child_process');
const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn74/fps-pair-f');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const driver=path.join(__dirname,'replay-accepted-source-pair.mjs');
const driverSha='d9cc8e5acd9f4313661ea6f47ce18c2e1e29e6791c3ca2e73a86365967882b54';
const selectionFile=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json');
const selectionSha='522506865b61b04ff4e810f805488135d5ba65099adf9f7acdd4b9660d138079';
const capture='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf';
const captureSha='1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463';
const expected={control:'0c5b840e4dfd9500dcbba4e8aa68b1aed635461659281cda543d331916be4795',candidate:'52d8c4f85e126c28de5d321119b3a67310ec121a307a9c6e83802a529a6a7af3'};
const modes=['control','candidate','candidate','control'];
const runs=modes.map((mode,index)=>({run:`nwn74-guard-fps-${String.fromCharCode(97+index)}-${mode}`,mode}));
function inputPath(base,relative){assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(x=>!x||x==='.'||x==='..'));const file=path.resolve(base,relative);assert(!path.relative(base,file).startsWith('..'));return file;}
async function verify(){
 assert.equal(sha(driver),driverSha,'Pair replay driver changed');
 assert.equal(sha(selectionFile),selectionSha,'Frozen normal-client selection changed');
 assert.equal(sha(path.join(capture,'recording.json')),captureSha,'Capture changed');
 assert.equal(sha(path.join(root,'.cache/nwn74/accepted-forward-before-guard.cpp')),'49fc6ca310573c5a0704e5a6d9dfa4cf769b37d756239f7e49aa9502d1d97705');
 assert.equal(sha(path.join(root,'.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp')),'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd');
 assert.equal(sha(path.join(root,'.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe')),'0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1');
 assert.equal(sha(path.join(__dirname,'accepted-material-guard.diff')),'60151dda7158466cce7dfb96bbc6fa1ffc40d67f3bae306c35e29e063d248414');
 const selection=JSON.parse(fs.readFileSync(selectionFile));
 assert(selection.complete&&selection.production&&selection.profiling==='false'&&selection.options.includes('--detailed-profiling=off'));
 assert.equal(selection.pins.length,2431);
 for(const pin of selection.pins)assert.equal(sha(inputPath(selection.sourceProject,pin.relative)),pin.sha256,'Frozen client pin differs: '+pin.relative);
 const helper=require(path.join(root,'tools/native-production-selection.cjs'));
 const selected=await helper.readProductionSelection(selectionFile,selectionSha);
 assert.equal(selected.mainSourceIdentity.sha256,'2899da533f9fce0e34dfe5ef102cba2d79e4984fb9603469c637edba8e230556');
 const timeline=fs.readFileSync(path.join(capture,'timeline.jsonl'),'utf8').trim().split(/\r?\n/).map(JSON.parse);
 const {selectGeneration}=await import(pathToFileURL(path.join(root,'tools/native-loading-selection.mjs')).href);
 const generation=selectGeneration(timeline,2);
 const capturedFrames=generation.filter(x=>x.kind==='frame').length,movementInputs=generation.filter(x=>x.kind==='movement-input').length;
 assert(capturedFrames>1000&&movementInputs===360,'Generation-2 original input differs');
 const receipts={};for(const mode of ['control','candidate']){
  const file=path.join(root,'.cache/nwn74',`engine-build-f-${mode}`,'receipt.json'),value=JSON.parse(fs.readFileSync(file));
  assert(value.success&&value.mode===mode&&value.sourcePinsUnchanged&&value.acceptedBefore===value.acceptedAfter&&value.acceptedAfter==='0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1');
  assert.equal(value.binary.sha256,expected[mode]);assert.equal(sha(value.binary.file),expected[mode]);
  receipts[mode]={file,sha256:sha(file),binary:value.binary.file,engineSha256:value.binary.sha256,compileCount:value.actualCompiles.length,sourcePins:value.sourcePins};
 }
 assert.equal(receipts.control.compileCount,25);assert.equal(receipts.candidate.compileCount,1);
 assert.equal(receipts.candidate.sourcePins[0].relative,'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp');
 const source=path.join(root,'.cache/nwn74/engine-source-f-control');
 for(const pin of receipts.control.sourcePins.filter(x=>x.relative!==receipts.candidate.sourcePins[0].relative))assert.equal(sha(inputPath(source,pin.relative)),pin.sha256,'Control non-Forward+ source changed');
 const config={issue:'NWN-74',kind:'matched-private-normal-client-fps-pair',execution:'verify-only until coordinator grants exclusive FPS lease',selection:{file:selectionFile,sha256:selectionSha,profiling:false,sourceIdentity:selected.mainSourceIdentity.sha256,pins:selection.pins.length},capture:{file:capture,sha256:captureSha,generation:2,capturedFrames,movementInputs},driver:{file:driver,sha256:driverSha},engines:receipts,sequence:runs.map(({run,mode})=>({run,mode,argv:[process.execPath,driver,`--capture=${capture}`,'--generation=2',`--production-selection=${selectionFile}`,`--production-selection-sha256=${selectionSha}`,'--engine=production-selection','--profiling=false','--observe-profile=false','--steady-ms=15000','--preview',`--nwn74-mode=${mode}`,`--run=${run}`]})),runtimeLimitMs:240000,memoryLimitBytes:8*1024**3};
 return config;
}
function memoryProbe(mode){return new Promise((resolve,reject)=>{
 const name=mode==='control'?'Godot_nwn74_accepted_source_control_f_win64':'Godot_nwn74_accepted_source_candidate_f_win64';
 const script=`$p=Get-Process -Name '${name}' -ErrorAction SilentlyContinue; if($p){[long](($p | Measure-Object -Property PrivateMemorySize64 -Sum).Sum)} else {0}`;
 execFile('pwsh',['-NoProfile','-Command',script],{windowsHide:true,timeout:5000},(err,out)=>err?reject(err):resolve(Number(out.trim())||0));
});}
async function runOne(config,label){
 const entry=config.sequence.find(x=>x.run===label);assert(entry,'Only a planned run label is allowed');
 const reportFile=path.join(root,'reports',entry.run+'.json'),receiptFile=path.join(scope,entry.run+'.receipt.json'),logFile=path.join(scope,entry.run+'.driver.log');
 for(const file of [reportFile,receiptFile,logFile])assert(!fs.existsSync(file),'Preserve previous output: '+file);
 const log=fs.createWriteStream(logFile,{flags:'wx'});
 const child=spawn(process.execPath,entry.argv.slice(1),{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',bytes=>log.write(bytes));
 let peakPrivateBytes=0,haltReason=null,checking=false;const started=Date.now();
 const stop=reason=>{if(haltReason)return;haltReason=reason;execFile('taskkill',['/PID',String(child.pid),'/T','/F'],{windowsHide:true},()=>{});};
 const timer=setInterval(async()=>{if(Date.now()-started>config.runtimeLimitMs)return stop('240-second watchdog');if(checking)return;checking=true;try{const bytes=await memoryProbe(entry.mode);peakPrivateBytes=Math.max(peakPrivateBytes,bytes);if(bytes>config.memoryLimitBytes)stop('Private engine exceeded 8 GiB');}catch(e){stop('Memory guard unavailable: '+e.message);}finally{checking=false;}},3000);
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve)});clearInterval(timer);await new Promise(resolve=>log.end(resolve));
 const report=fs.existsSync(reportFile)?JSON.parse(fs.readFileSync(reportFile)):null;
 const result={issue:'NWN-74',run:entry.run,mode:entry.mode,exit,haltReason,peakPrivateBytes,report:reportFile,reportSha256:report?sha(reportFile):null,rawSuccess:report?.success??false,rawFailure:report?.failure??null,runtimeUnchanged:report?.runtimeUnchanged??null,sourceUnchanged:report?.sourceUnchanged??null,fpsObservations:report?.fpsObservations??null,engineSha256:config.engines[entry.mode].engineSha256,selectionSha256:config.selection.sha256,captureSha256:config.capture.sha256};
 fs.writeFileSync(receiptFile,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({receipt:receiptFile,exit,haltReason,rawSuccess:result.rawSuccess,rawFailure:result.rawFailure,fpsSamples:result.fpsObservations?.samples??0,peakPrivateBytes}));
 if(haltReason||!report||report.runtimeUnchanged!==true||report.sourceUnchanged!==true||(result.fpsObservations?.samples??0)<3)process.exitCode=1;
}
async function main(){const config=await verify();fs.mkdirSync(scope,{recursive:true});const planFile=path.join(scope,'plan.json');if(fs.existsSync(planFile)){const prior=JSON.parse(fs.readFileSync(planFile));assert.deepEqual(prior,config,'Saved FPS pair plan changed');}else fs.writeFileSync(planFile,JSON.stringify(config,null,2)+'\n',{flag:'wx'});const label=process.argv.find(x=>x.startsWith('--run='))?.slice(6);if(!label){console.log(JSON.stringify({verified:true,plan:planFile,planSha256:sha(planFile),sequence:config.sequence.map(x=>({run:x.run,mode:x.mode})),scope:config.execution}));return;}await runOne(config,label);}
main().catch(error=>{console.error(error.stack);process.exitCode=1});
