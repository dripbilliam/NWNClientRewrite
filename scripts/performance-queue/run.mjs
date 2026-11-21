// Default: print the prepared plan. Nothing launches without --run.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash,randomBytes} from 'node:crypto';
import {spawn} from 'node:child_process';
import {createWriteStream,existsSync} from 'node:fs';
import {finished} from 'node:stream/promises';
import os from 'node:os';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const modernPowerShell=path.join(process.env.ProgramFiles??'C:/Program Files','PowerShell/7/pwsh.exe');
const powershell=existsSync(modernPowerShell)?modernPowerShell:process.env.SystemRoot?path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe'):'powershell.exe';
const manifest=JSON.parse(await fs.readFile(path.join(root,'scripts/performance-queue/manifest.json'),'utf8'));
const args=process.argv.slice(2),known=['--list','--preflight','--run','--help'];
for(const arg of args)if(!known.includes(arg)&&!arg.startsWith('--stage=')&&!arg.startsWith('--only='))throw Error('Unknown option: '+arg);
const stages=(args.find(a=>a.startsWith('--stage='))?.slice(8)??'all').split(',');
const only=args.find(a=>a.startsWith('--only='))?.slice(7).split(',');
for(const stage of stages)if(stage!=='all'&&!manifest.stages.includes(stage))throw Error('Unknown stage: '+stage);
for(const id of only??[])if(!manifest.tests.some(test=>test.id===id))throw Error('Unknown test: '+id);
const selected=new Set(manifest.tests.filter(test=>(stages.includes('all')||stages.includes(test.stage))&&(!only||only.includes(test.id))).map(test=>test.id));
const includeDependencies=id=>{const test=manifest.tests.find(row=>row.id===id);if(!test)throw Error('Unknown dependency '+id);for(const dependency of test.dependencies??[]){if(selected.has(dependency))continue;selected.add(dependency);includeDependencies(dependency);}};
for(const id of [...selected])includeDependencies(id);
const tests=manifest.tests.filter(test=>selected.has(test.id));
if(!tests.length)throw Error('No tests selected');
if(args.includes('--help')) {
  console.log('Prepared tests only. Commands:\n  node scripts/performance-queue/run.mjs --list\n  node scripts/performance-queue/run.mjs --preflight\n  node scripts/performance-queue/run.mjs --run --stage=unit\n  node scripts/performance-queue/run.mjs --run --stage=all\nOptional: --only=id,id. Close games before running. No tests build or change dist.');
} else if(!args.includes('--run')&&!args.includes('--preflight')) {
  console.log('PLAN ONLY — NOTHING STARTED. '+tests.length+' selected test groups. See unique run summaries for execution history.');
  for(const test of tests)console.log(`${test.stage.padEnd(9)} ${test.id}: ${test.coverage}`);
} else {
  await main();
}

function capture(executable,arguments_) {
  return new Promise((resolve,reject)=>{
    const child=spawn(executable,arguments_,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});let stdout='',stderr='';
    child.stdout.on('data',chunk=>{stdout+=chunk;if(stdout.length>2e6)child.stdout.destroy();});child.stderr.on('data',chunk=>{stderr+=chunk;});child.on('error',reject);
    child.on('close',code=>code===0?resolve(stdout.trim()):reject(Error('Read-only preflight/server helper failed: '+stderr.trim())));
  });
}
async function assertNoGame() {
  if(process.platform!=='win32')throw Error('This prepared runner targets Windows');
  // No command lines, credentials or window contents leave this query.
  const json=await capture(powershell,['-NoProfile','-NonInteractive','-Command',"$ErrorActionPreference='Stop'; $queueGames=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -in @('nwmain.exe','nwmain-windows.exe','electron.exe') } | Select-Object ProcessId,Name); ConvertTo-Json -InputObject $queueGames -Compress"]);
  const games=JSON.parse(json||'[]');
  if(games.length)throw Error('Close games/other Electron test instances first. Preserved: '+games.map(g=>g.Name+' PID '+g.ProcessId).join(', '));
}
async function preflight() {
  await assertNoGame();
  const contract=JSON.parse(await fs.readFile(path.join(root,'scripts/performance-queue/source-contract.json'),'utf8'));
  const drift=[];for(const [name,expected]of Object.entries(contract.sha256)) {
    const actual=createHash('sha256').update(await fs.readFile(path.join(root,name))).digest('hex');if(actual!==expected)drift.push(name);
  }
  if(drift.length)throw Error('Source changed since queue preparation; review/re-pin the affected fixtures before running: '+drift.join(', '));
  for(const test of tests)for(const file of test.requires??[])await fs.access(path.resolve(root,file));
  if(tests.some(test=>test.engine==='electron'))await fs.access(path.join(root,'node_modules/electron/dist/electron.exe'));
  if(tests.some(test=>test.server||['installed','local'].includes(test.stage)))for(const binary of contract.binaries) {
    const actual=createHash('sha256').update(await fs.readFile(path.resolve(root,binary.path))).digest('hex');
    if(actual!==binary.sha256)throw Error('Installed binary differs from pinned evidence: '+binary.path);
  }
  return {sourceFiles:Object.keys(contract.sha256).length,tests:tests.length};
}
async function lease(action,serverProcessId=0,serverCreated='') {
  // Process-scoped policy for the hash-pinned, locally authored fixture
  // scripts. No persistent execution-policy setting is changed.
  const result=await capture(powershell,['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(root,'scripts/performance-queue/server-lease.ps1'),'-Action',action,'-ServerProcessId',String(serverProcessId),...(serverCreated?['-ServerCreated',serverCreated]:[])]);
  return JSON.parse(result);
}
async function main() {
  const checked=await preflight();
  if(!args.includes('--run')){console.log(JSON.stringify({preflight:true,...checked,executed:0}));return;}
  const directory=path.join(root,'runtime-logs','performance-queue');await fs.mkdir(directory,{recursive:true});
  const runId='queue-'+new Date().toISOString().toLowerCase().replace(/[^a-z0-9]/g,'-')+'-'+randomBytes(3).toString('hex');
  const lockPath=path.join(directory,'active.lock'),lock=await fs.open(lockPath,'wx').catch(()=>{throw Error('Queue lock exists. Preserve any running tests; inspect runtime-logs/performance-queue/active.lock before removing a stale lock.');});
  const output=path.join(directory,runId);await fs.mkdir(output);await lock.writeFile(JSON.stringify({runId,processId:process.pid,output})+'\n');
  const summary={runId,status:'running',started:new Date().toISOString(),scope:'Offline and owned local server only; no Arelith',runtime:{platform:process.platform,arch:process.arch,versions:process.versions},preflight:checked,tests:[]};
  const replace=value=>value.replaceAll('{run}',runId).replaceAll('{output}',output);
  let serverProcessId=0,serverCreated='',interrupted=false;
  const interrupt=()=>{interrupted=true;console.error('Stop requested. Letting the current owned check finish; no further tests will start.');};process.on('SIGINT',interrupt);process.on('SIGTERM',interrupt);
  const save=()=>fs.writeFile(path.join(output,'summary.json'),JSON.stringify(summary,null,2)+'\n');
  try {
    await save();
    for(const test of tests) {
      if(interrupted)throw Error('Queue interrupted after current test');
      await assertNoGame();
      if((test.stage==='local'||test.server)&&!serverProcessId) {
        const started=await lease('Start');serverProcessId=started.processId;serverCreated=started.created;summary.server={processId:serverProcessId,created:serverCreated,port:5123};await save();
        const deadline=Date.now()+30000;let ready=false;
        while(Date.now()<deadline){const state=await lease('Ready',serverProcessId,serverCreated);if(state.exited)throw Error('Owned server exited during startup');if(state.ready){ready=true;break;}await new Promise(resolve=>setTimeout(resolve,250));}
        if(!ready)throw Error('Owned server did not become ready');
      }
      const row={id:test.id,stage:test.stage,started:new Date().toISOString(),status:'running'};summary.tests.push(row);await save();
      const executable=test.engine==='electron'?path.join(root,'node_modules/electron/dist/electron.exe'):process.execPath;
      const arguments_=test.args.map(replace),environment={...process.env};delete environment.ELECTRON_RUN_AS_NODE;
      console.log('Running '+test.id+'; logs: '+output);
      const stdout=createWriteStream(path.join(output,test.id+'.stdout.txt'),{flags:'wx'}),stderr=createWriteStream(path.join(output,test.id+'.stderr.txt'),{flags:'wx'});
      const began=performance.now();
      const code=await new Promise((resolve,reject)=>{
        const child=spawn(executable,arguments_,{cwd:root,env:environment,windowsHide:true,stdio:['ignore','pipe','pipe']});row.processId=child.pid;
        // A deadline is diagnostic: never start another process over a still
        // running handle or kill an unverified process tree automatically.
        const timer=setTimeout(()=>{row.deadlineExceeded=true;console.error(test.id+' exceeded its expected duration; waiting on owned PID '+child.pid+'. No retry will start.');void save();},test.deadlineMs??180000);
        child.stdout.pipe(stdout);child.stderr.pipe(stderr);child.on('error',error=>{clearTimeout(timer);stdout.end();stderr.end();reject(error);});child.on('close',exitCode=>{clearTimeout(timer);resolve(exitCode);});
      });
      await Promise.all([finished(stdout),finished(stderr)]);row.ms=performance.now()-began;row.exitCode=code;
      if(code!==0||row.deadlineExceeded)throw Error(test.id+' failed or exceeded its expected duration; inspect its logs');
      if(test.rejectSkipped&&/#\s+SKIP\b/i.test(await fs.readFile(path.join(output,test.id+'.stdout.txt'),'utf8')))throw Error(test.id+' skipped required coverage');
      for(const reportName of test.reports??[]) {
        const reportPath=path.resolve(root,replace(reportName)),report=JSON.parse(await fs.readFile(reportPath,'utf8'));
        if(test.cleanupProfilePrefix&&report.temporaryProfile) {
          const target=path.resolve(report.temporaryProfile),temporary=await fs.realpath(os.tmpdir()),real=await fs.realpath(target),info=await fs.lstat(target);
          if(!info.isDirectory()||info.isSymbolicLink()||path.dirname(real).toLowerCase()!==temporary.toLowerCase()||!path.basename(real).startsWith(test.cleanupProfilePrefix))throw Error('Invalid owned temporary profile cleanup target');
          await fs.rm(real,{recursive:true,force:true,maxRetries:20,retryDelay:100});row.cleanedTemporaryProfile=real;
        }
        if(report.success!==true)throw Error(test.id+' report did not confirm success: '+reportPath);
        row.reports??=[];row.reports.push(reportPath);
      }
      row.status='passed';row.finished=new Date().toISOString();await save();
    }
    summary.status='passed';
  } catch(error) {
    summary.status='failed';summary.failure=error.stack;const active=summary.tests.at(-1);if(active?.status==='running')active.status='failed';process.exitCode=1;console.error(error.message);
  } finally {
    if(serverProcessId) {
      try {summary.server.cleanup=await lease('Stop',serverProcessId,serverCreated);}catch(error){summary.server.cleanupFailure=error.message;summary.status='failed';process.exitCode=1;}
    }
    summary.finished=new Date().toISOString();await save();await lock.close();
    const owner=JSON.parse(await fs.readFile(lockPath,'utf8'));if(owner.runId===runId)await fs.unlink(lockPath);
    process.off('SIGINT',interrupt);process.off('SIGTERM',interrupt);console.log('Queue '+summary.status+': '+path.join(output,'summary.json'));
  }
}
