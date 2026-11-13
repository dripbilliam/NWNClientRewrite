'use strict';
// Bounded private Forward+ operation census. Diagnostic counts only.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {spawn,execFile}=require('node:child_process');
const {pathToFileURL}=require('node:url');
const root=path.resolve(__dirname,'../..');
const label=process.argv[2],verifyOnly=process.argv.includes('--verify-only');
assert.equal(label,'render-probe-a');
const stageFile=path.join(root,'.cache/nwn74',label,'staged.json'),staged=JSON.parse(fs.readFileSync(stageFile));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const driver=path.join(__dirname,'replay-material-dedup.mjs'),driverSha='684dbbe12ad5c884408fb29e7c7380ebfc40e31de949fc48580868a535fa6ed1';
const candidateReceiptFile=path.join(root,'.cache/nwn74/engine-build-e/receipt.json');
const run='nwn74-material-dedup-e',reportFile=path.join(root,'reports',run+'.json');
const args=[driver,'--capture='+staged.capture,'--generation=2','--production-selection='+staged.selection.file,'--production-selection-sha256='+staged.selection.sha256,'--engine=production-selection','--profiling=true','--observe-profile=true','--steady-ms=4000','--preview','--run='+run];
async function verify(){
 assert(staged.private&&!staged.accepted&&!staged.production);
 assert.equal(sha(stageFile),'31e6d21c9d74fb66837445f82637e70df93440195a3128133b8f01b40853460a');
 assert.equal(sha(driver),driverSha);
 assert.equal(sha(staged.baseSelection),staged.baseSelectionSha256);
 assert.equal(sha(staged.engine.receipt),staged.engine.receiptSha256);
 assert.equal(sha(staged.engine.file),staged.engine.sha256);
 const candidate=JSON.parse(fs.readFileSync(candidateReceiptFile));
 assert(candidate.success&&candidate.acceptedUnchanged&&candidate.controlUnchanged&&candidate.controlSourceUnchanged&&candidate.sourceUnchanged);
 assert.equal(candidate.binary.sha256,'37fddca06fe823a30c7158a40543d1116116b7abe1f8545fa22f952ef836e01d');
 assert.equal(sha(candidate.binary.file),candidate.binary.sha256);
 assert.equal(sha(path.join(staged.capture,'recording.json')),staged.recordingSha256);
 const timeline=fs.readFileSync(path.join(staged.capture,'timeline.jsonl'),'utf8').trim().split(/\r?\n/).map(line=>JSON.parse(line));
 const {selectGeneration}=await import(pathToFileURL(path.join(root,'tools/native-loading-selection.mjs')).href);
 const generation=selectGeneration(timeline,2);
 const capturedFrames=generation.filter(row=>row.kind==='frame').length;
 const movementInputs=generation.filter(row=>row.kind==='movement-input').length;
 assert(capturedFrames>1000&&movementInputs===360,'Original generation-2 entry differs');
 for(const pin of staged.pins)assert.equal(sha(path.join(staged.input,pin.relative)),pin.sha256,'Input changed '+pin.relative);
 const helper=require(path.join(staged.input,'tools/native-production-selection.cjs'));
 const selected=await helper.readProductionSelection(staged.selection.file,staged.selection.sha256);
 assert.equal(selected.profiling,'true');
 assert.equal(selected.mainSourceIdentity.sha256,staged.selection.sourceIdentity);
 assert.equal(sha(path.join(selected.sourceProject,staged.profile.relative)),staged.profile.privateSha256);
 return {issue:'NWN-74',verified:true,private:true,driverSha256:driverSha,selectionSha256:staged.selection.sha256,profileSha256:staged.profile.privateSha256,engineSha256:candidate.binary.sha256,engineReceiptSha256:sha(candidateReceiptFile),captureSha256:staged.recordingSha256,selectedGeneration:2,capturedFrames,movementInputs,argv:[process.execPath,...args],runtimeLimitMs:240000,memoryLimitBytes:8*1024**3,scope:'Short graphical Forward+ operation census only; no FPS acceptance.'};
}
function memoryProbe(){return new Promise((resolve,reject)=>{
 const script="$p=Get-Process -Name 'Godot_nwn74_material_dedup_e_win64' -ErrorAction SilentlyContinue; if($p){[long](($p | Measure-Object -Property PrivateMemorySize64 -Sum).Sum)} else {0}";
 execFile('pwsh',['-NoProfile','-Command',script],{windowsHide:true,timeout:5000},(err,stdout)=>err?reject(err):resolve(Number(stdout.trim())||0));
});}
async function main(){
 const pins=await verify();if(verifyOnly){console.log(JSON.stringify(pins,null,2));return;}
 assert(!fs.existsSync(reportFile),'Preserve previous diagnostic report');
 const output=path.join(root,'.cache/nwn74',label,run+'.driver.log');
 const log=fs.createWriteStream(output,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>log.write(chunk));
 let peakPrivateBytes=0,haltReason=null,checking=false;
 const stop=reason=>{if(haltReason)return;haltReason=reason;execFile('taskkill',['/PID',String(child.pid),'/T','/F'],{windowsHide:true},()=>{});};
 const began=Date.now();const timer=setInterval(async()=>{
  if(Date.now()-began>240000)return stop('240-second watchdog');
  if(checking)return;checking=true;
  try{const bytes=await memoryProbe();peakPrivateBytes=Math.max(peakPrivateBytes,bytes);if(bytes>8*1024**3)stop('Godot private bytes exceeded 8 GiB');}
  catch(error){stop('Memory guard unavailable: '+error.message);}finally{checking=false;}
 },3000);
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
 clearInterval(timer);await new Promise(resolve=>log.end(resolve));
 const report=fs.existsSync(reportFile)?JSON.parse(fs.readFileSync(reportFile)):null;
 const result={...pins,run,exit,haltReason,peakPrivateBytes,report:reportFile,reportSha256:report?sha(reportFile):null,profileSamples:report?.profileObservations?.samples??0,profileFile:report?.profileObservations?.file??null,rawSuccess:report?.success??false,rawFailure:report?.failure??null,engineUnchanged:report?.runtimeUnchanged??null,sourceUnchanged:report?.sourceUnchanged??null};
 const receipt=path.join(root,'.cache/nwn74',label,run+'.receipt.json');fs.writeFileSync(receipt,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({receipt,sha256:sha(receipt),exit,haltReason,peakPrivateBytes,profileSamples:result.profileSamples,rawSuccess:result.rawSuccess,rawFailure:result.rawFailure}));
 if(haltReason||!report||report.runtimeUnchanged!==true||report.sourceUnchanged!==true||result.profileSamples<1)process.exitCode=1;
}
main().catch(error=>{console.error(error.stack);process.exitCode=1;});
