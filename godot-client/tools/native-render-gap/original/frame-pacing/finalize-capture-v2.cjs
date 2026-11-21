'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../../../..'),[label,run]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||!/^render-gap-[a-z0-9-]+$/.test(run??''))throw Error('Explicit capture label and native replay run required');
const base=path.join(project,'.cache/native-render-gap/original/frame-pacing','rip-'+label),output=path.join(base,'acceptance.json');
if(fs.existsSync(output))throw Error('Preserve prior acceptance');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),read=n=>fs.readFileSync(path.join(base,n)),pin=file=>({file,sha256:sha(fs.readFileSync(file))});
const p=JSON.parse(read('preflight.json')),q=JSON.parse(read('process.json')),e=JSON.parse(read('exit.json')),raw=read('native.json'),r=JSON.parse(raw);
const gameFile=path.join(project,'reports',run+'.native.json'),gameBytes=fs.readFileSync(gameFile),g=JSON.parse(gameBytes),outerFile=path.join(project,'reports',run+'.json'),outer=JSON.parse(fs.readFileSync(outerFile));
const created=Number((BigInt(p.creationFileTimeUtc)-116444736000000000n)/10000n);
const lo=(Date.parse(q.startedUtc)-created)/1000,hi=(Date.parse(e.finishedUtc)-created)/1000,reportAge=(fs.statSync(gameFile).mtimeMs-created)/1000;
const pacing=g.render_gap.pacing,last=Math.max(...pacing.main.map(x=>x[13])),delayMax=reportAge-last/1e6;
const start=g.performance_window.started_at_ms/1000,end=(g.performance_window.started_at_ms+g.performance_window.elapsed_ms)/1000;
const invalid=r.samples.filter(x=>x[6]||x[7]||x[8]||x[9]!==1),threadRaw=gameBytes.toString().match(/"main_thread_policy"\s*:\s*\{[^}]*"expected_creation_100ns"\s*:\s*(\d+)/);
const errors=[];
for(const [ok,message]of [
 [r.success&&e.exit===0,'Sampler failed'],[invalid.length===0,'Suspend/context/resume error or prior suspend'],
 [r.samples.length>1000,'Insufficient captures'],[r.samples.every(x=>x[4]>=0),'Unknown module'],
 [g.success&&g.clean_exit&&outer.success&&outer.renderGapVerification?.status==='observed','Replay/cleanup/actual-use rejected'],
 [pacing.main_thread_policy.thread_id===r.tid,'Captured thread is not observed main thread'],
 [threadRaw?.[1]===r.thread_creation_100ns,'Thread creation differs'],[String(p.pid)===String(r.pid),'Process ID differs'],
 [p.creationFileTimeUtc===r.process_creation_100ns,'Process creation differs'],
 [delayMax>=0&&lo>=start+delayMax&&hi<=end,'Capture not wholly inside steady quiet window'],
 [p.engine.sha256===r.modules.find(m=>m.sha256===p.engine.sha256)?.sha256,'Exact engine absent'],
 [p.kernel.sha256===r.modules.find(m=>m.sha256===p.kernel.sha256)?.sha256,'Exact kernel absent']
])if(!ok)errors.push(message);
const result={version:2,success:errors.length===0,errors,raw:{file:path.join(base,'native.json'),sha256:sha(raw)},game:{file:gameFile,sha256:sha(gameBytes),success:g.success,cleanExit:g.clean_exit,mainTid:pacing.main_thread_policy.thread_id},outer:pin(outerFile),roles:{pid:r.pid,tid:r.tid,processCreationString:r.process_creation_100ns,threadCreationString:r.thread_creation_100ns,exactThreadCreationMatched:threadRaw?.[1]===r.thread_creation_100ns},samples:r.samples.length,invalidSamples:invalid.length,unknownModules:r.samples.filter(x=>x[4]<0).length,wallUs:r.wall_us,pauseUs:r.pause_total_us,pauseFraction:r.pause_total_us/r.wall_us,pauseMaxUs:r.pause_max_us,pauseOver200Us:r.pause_over_200us,highResolutionPrivateTimer:r.high_resolution_timer,missedDue:r.missed_due,timing:{captureOuterStartProcessAgeSeconds:lo,captureOuterEndProcessAgeSeconds:hi,godotSteadyStartSeconds:start,godotSteadyEndSeconds:end,finalReportFileAgeSeconds:reportAge,lastCompletedPacingEndUs:last,godotOsOriginDelayMinimumSeconds:0,godotOsOriginDelayMaximumSeconds:delayMax,minimumStartMarginSeconds:lo-start-delayMax,minimumEndMarginSeconds:end-hi,reason:'Report wall age minus last completed OS pacing timestamp upper-bounds the QPC origin delay after Windows process creation. Entire outer capture lies inside the steady interval for every origin delay in this bound.'},tooling:[pin(__filename),pin(path.join(__dirname,'run-rip-v2.ps1')),pin(path.join(base,'schedule.json')),pin(path.join(base,'process.json')),pin(path.join(base,'exit.json'))],scope:'Perturbed main-thread RIP leaf-frequency diagnostic only; no FPS or inclusive stack/caller cost claim. Exact owned process/thread lifetime, observed modules, successful replay, steady containment and every suspend/context/resume status are required.'};
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file:output,sha256:sha(fs.readFileSync(output)),success:result.success,errors,timing:result.timing,samples:result.samples,pauseFraction:result.pauseFraction}));if(!result.success)process.exitCode=1;
