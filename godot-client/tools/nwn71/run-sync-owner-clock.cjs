'use strict';
// One bounded original-scene offline run. Reports clock labels, never FPS.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {spawn,execFile}=require('node:child_process');
const root=path.resolve(__dirname,'../..'),stage=path.join(root,'.cache/nwn71/sync-owner-clock-a');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const build=JSON.parse(fs.readFileSync(path.join(stage,'build-receipt.json')));
const driver=JSON.parse(fs.readFileSync(path.join(stage,'driver-receipt.json')));
const replay=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn74/render-probe-a/staged.json')));
const run='nwn71-sync-owner-clock-a',report=path.join(root,'reports',run+'.json'),engineLog=path.join(root,'reports',run+'.engine.log');
assert(build.success&&build.privateSourceRestored&&build.privateObjectsRestored&&build.privateBinaryRestored&&build.sconsignRestored&&build.acceptedSourcesUnchanged&&build.acceptedBinaryUnchanged);
assert.equal(sha(build.binary.file),build.binary.sha256);assert.equal(sha(driver.driver),driver.driverSha256);
assert.equal(sha(replay.selection.file),replay.selection.sha256);assert.equal(sha(path.join(replay.capture,'recording.json')),replay.recordingSha256);
assert(!fs.existsSync(report),'Preserve prior diagnostic run');
const args=[driver.driver,'--capture='+replay.capture,'--generation=2','--production-selection='+replay.selection.file,'--production-selection-sha256='+replay.selection.sha256,'--engine=production-selection','--profiling=true','--observe-profile=false','--steady-ms=4000','--preview','--run='+run];
const receipt={issue:'NWN-71',private:true,diagnosticOnly:true,run,engineSha256:build.binary.sha256,driverSha256:driver.driverSha256,selectionSha256:replay.selection.sha256,recordingSha256:replay.recordingSha256,startedUtc:new Date().toISOString(),memoryLimitBytes:8*1024**3,runtimeLimitMs:180000,scope:'Offline main/render/group/fence clock intervals; no FPS output or comparison.'};
function memory(){return new Promise((resolve,reject)=>execFile('pwsh',['-NoProfile','-Command',"$p=Get-Process -Name 'Godot_nwn71_sync_owner_clock_a_win64' -ErrorAction SilentlyContinue; if($p){[long](($p | Measure-Object -Property PrivateMemorySize64 -Sum).Sum)} else {0}"],{windowsHide:true,timeout:5000},(e,o)=>e?reject(e):resolve(Number(o.trim())||0)));}
async function main(){
 const log=fs.createWriteStream(path.join(stage,'driver.log'),{flags:'wx'});
 const child=spawn(process.execPath,args,{cwd:root,windowsHide:true,env:{...process.env,NWN71_SYNC_OWNER_CLOCK:'1'},stdio:['ignore','pipe','pipe']});
 for(const stream of [child.stdout,child.stderr])stream.on('data',data=>log.write(data));
 let halt=null,peak=0,checking=false;
 const stop=reason=>{if(halt)return;halt=reason;execFile('taskkill',['/PID',String(child.pid),'/T','/F'],{windowsHide:true},()=>{});};
 const begun=Date.now();
 const timer=setInterval(async()=>{if(Date.now()-begun>180000)return stop('runtime limit');if(checking)return;checking=true;try{const bytes=await memory();peak=Math.max(peak,bytes);if(bytes>8*1024**3)stop('8 GiB private-memory limit');}catch(e){stop('memory probe: '+e.message);}finally{checking=false;}},3000);
 const exit=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve);});
 clearInterval(timer);await new Promise(resolve=>log.end(resolve));
 const lines=fs.existsSync(engineLog)?fs.readFileSync(engineLog,'utf8').split(/\r?\n/):[];
 const clockRows=lines.filter(x=>x.startsWith('NWN71_CLOCK ')),waitRows=lines.filter(x=>x.startsWith('NWN71_WAIT ')),deviceRows=lines.filter(x=>x.startsWith('NWN71_DEVICE_WAIT '));
 const fps=path.join(root,'reports',run+'.fps.jsonl');
 Object.assign(receipt,{exit,halt,peakPrivateBytes:peak,reportExists:fs.existsSync(report),reportSha256:fs.existsSync(report)?sha(report):null,engineLogExists:fs.existsSync(engineLog),engineLogSha256:fs.existsSync(engineLog)?sha(engineLog):null,clockRows:clockRows.length,waitRows:waitRows.length,deviceRows:deviceRows.length,fpsFileAbsent:!fs.existsSync(fps),acceptedSourcesUnchanged:build.files.every(f=>sha(path.join(root,'.cache/native-tracy/engine-msvc-a/source',f.relative))===f.sourceBefore),acceptedBinaryUnchanged:sha(path.join(root,'.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'))===build.acceptedBinaryBefore,endedUtc:new Date().toISOString()});
 receipt.success=!halt&&receipt.reportExists&&receipt.engineLogExists&&receipt.fpsFileAbsent&&receipt.acceptedSourcesUnchanged&&receipt.acceptedBinaryUnchanged;
 fs.writeFileSync(path.join(stage,'run-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify(receipt));if(!receipt.success)process.exitCode=1;
}
main().catch(e=>{console.error(e.stack);process.exitCode=1});
