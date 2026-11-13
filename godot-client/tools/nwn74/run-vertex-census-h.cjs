'use strict';
// Count-only original-scene diagnostic. Verify-only unless --execute is given.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {spawn,spawnSync,execFile}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn74/vertex-census-h');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const driver=path.join(__dirname,'replay-vertex-census-h.mjs'),driverSha='9230eb5193fe8ce580799f502e7075fc470626e28e43f0f9e9f4c944cd9e19a3';
const selection=path.join(root,'.cache/native-presentation-parity/production-replay/nwn62-completion-tail-c/production-selection.json'),selectionSha='522506865b61b04ff4e810f805488135d5ba65099adf9f7acdd4b9660d138079';
const capture='C:/Users/Niflheim/AppData/Roaming/nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf',captureSha='1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463';
const engineReceipt=path.join(root,'.cache/nwn74/engine-build-h-census/receipt.json');
const run='nwn74-vertex-census-h';
const args=[driver,`--capture=${capture}`,'--generation=2',`--production-selection=${selection}`,`--production-selection-sha256=${selectionSha}`,'--engine=production-selection','--profiling=false','--observe-profile=false','--steady-ms=5000','--preview',`--run=${run}`];
function memoryProbe(){return new Promise((resolve,reject)=>{const script="$p=Get-Process -Name 'Godot_nwn74_vertex_census_h_win64' -ErrorAction SilentlyContinue; if($p){[long](($p | Measure-Object -Property PrivateMemorySize64 -Sum).Sum)} else {0}";execFile('pwsh',['-NoProfile','-Command',script],{windowsHide:true,timeout:5000},(err,out)=>err?reject(err):resolve(Number(out.trim())||0));});}
function verify(){
 assert.equal(sha(driver),driverSha);assert.equal(sha(selection),selectionSha);assert.equal(sha(path.join(capture,'recording.json')),captureSha);
 const e=JSON.parse(fs.readFileSync(engineReceipt));assert(e.success&&e.sourceUnchanged&&e.acceptedUnchanged&&e.guardUnchanged);
 assert.equal(e.binary.sha256,'5d0c82cfc69859ed88abc926bc594335b71053fea212d85b4d6ee6c143192fa2');assert.equal(sha(e.binary.file),e.binary.sha256);
 const s=JSON.parse(fs.readFileSync(selection));assert(s.complete&&s.production&&s.profiling==='false');
 const result=spawnSync(process.execPath,[...args,'--verify-only'],{cwd:root,windowsHide:true,env:{...process.env,NWN74_VERTEX_CENSUS:'1'},encoding:'utf8',timeout:30000});
 assert.equal(result.status,0,result.stderr);const captureProof=JSON.parse(result.stdout);assert(captureProof.complete&&captureProof.events===5704&&captureProof.catalogs===1&&captureProof.networkConnections===0);
 return {issue:'NWN-74',scope:'Private original-scene vertex lookup reuse census; no FPS comparison',driverSha256:driverSha,selectionSha256:selectionSha,captureSha256:captureSha,engineSha256:e.binary.sha256,engineReceiptSha256:sha(engineReceipt),captureProof,argv:[process.execPath,...args],environment:{NWN74_VERTEX_CENSUS:'1'},runtimeLimitMs:240000,memoryLimitBytes:8*1024**3};
}
async function main(){
 const plan=verify();if(!process.argv.includes('--execute')){console.log(JSON.stringify({verified:true,...plan},null,2));return;}
 assert(!fs.existsSync(scope),'Preserve prior census run');fs.mkdirSync(scope,{recursive:true});
 const logFile=path.join(scope,'driver.log'),log=fs.createWriteStream(logFile,{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,NWN74_VERTEX_CENSUS:'1'}});
 for(const stream of [child.stdout,child.stderr])stream.on('data',chunk=>log.write(chunk));
 let peakPrivateBytes=0,haltReason=null,checking=false;const started=Date.now();
 const stop=reason=>{if(haltReason)return;haltReason=reason;execFile('taskkill',['/PID',String(child.pid),'/T','/F'],{windowsHide:true},()=>{});};
 const timer=setInterval(async()=>{if(Date.now()-started>plan.runtimeLimitMs)return stop('240-second watchdog');if(checking)return;checking=true;try{const bytes=await memoryProbe();peakPrivateBytes=Math.max(peakPrivateBytes,bytes);if(bytes>plan.memoryLimitBytes)stop('Private engine exceeded 8 GiB');}catch(error){stop('Memory guard unavailable: '+error.message);}finally{checking=false;}},3000);
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve)});clearInterval(timer);await new Promise(resolve=>log.end(resolve));
 const reportFile=path.join(root,'reports',run+'.json'),engineLog=path.join(root,'reports',run+'.engine.log');
 const report=fs.existsSync(reportFile)?JSON.parse(fs.readFileSync(reportFile)):null;
 const lines=fs.existsSync(engineLog)?fs.readFileSync(engineLog,'utf8').split(/\r?\n/).filter(line=>line.startsWith('NWN74_VERTEX_CENSUS ')):[];
 const samples=lines.map(line=>Object.fromEntries([...line.matchAll(/([a-z_]+)=([0-9]+)/g)].map(m=>[m[1],Number(m[2])])));
 const receipt={...plan,exit,haltReason,peakPrivateBytes,reportFile,reportSha256:report?sha(reportFile):null,rawSuccess:report?.success??false,rawFailure:report?.failure??null,sourceUnchanged:report?.sourceUnchanged??null,runtimeUnchanged:report?.runtimeUnchanged??null,engineLog,engineLogSha256:fs.existsSync(engineLog)?sha(engineLog):null,periods:samples.length,samples,settledLastThree:samples.slice(-3)};
 const receiptFile=path.join(scope,'receipt.json');fs.writeFileSync(receiptFile,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({receipt:receiptFile,exit,haltReason,rawSuccess:receipt.rawSuccess,rawFailure:receipt.rawFailure,periods:samples.length,settledLastThree:receipt.settledLastThree}));
 if(haltReason||!report||report.sourceUnchanged!==true||report.runtimeUnchanged!==true||samples.length<3)process.exitCode=1;
}
main().catch(error=>{console.error(error.stack);process.exitCode=1});

