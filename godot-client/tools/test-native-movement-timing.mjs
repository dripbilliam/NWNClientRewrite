import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [overlayFile,label]=process.argv.slice(2);
if(!/^native-movement-timing-[a-z0-9-]+$/.test(label??''))throw Error('Supply trial overlay and fresh check label');
const overlay=JSON.parse(fs.readFileSync(overlayFile)),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
if(overlay.kind!=='private-light-input-manual-trial'||!overlay.movementRecording)throw Error('Expected movement recording trial');
const stage=path.join(project,'.cache/native-movement-checks',label);if(fs.existsSync(stage))throw Error('Existing checks preserved');fs.mkdirSync(stage,{recursive:true});
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe');
const guards=['.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-window/nwn-window-modes.exe'].map(relative=>({relative,sha256:hash(fs.readFileSync(path.join(project,relative)))}));
const runs=[];
for(const [name,source,script,checkOnly]of [['projection',project,'res://tests/native_movement_timing_test.gd',false],['trial-entry',overlay.rendererProject,'res://native_session_world.gd',true]]){
 const app=path.join(stage,name+'-appdata'),local=path.join(stage,name+'-localappdata'),log=path.join(stage,name+'.engine.log');fs.mkdirSync(app);fs.mkdirSync(local);
 const result=await new Promise(resolve=>{
  const child=spawn(engine,['--headless','--path',source,'--log-file',log,...(checkOnly?['--check-only']:[]),'--script',script],{cwd:source,windowsHide:true,env:{...process.env,APPDATA:app,LOCALAPPDATA:local,NWN_PARTICLE_KERNEL:'compiled'},stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='',error=null;child.stdout.on('data',v=>stdout+=v);child.stderr.on('data',v=>stderr+=v);child.once('error',v=>error=v.message);
  const timer=setTimeout(()=>{error='Owned headless check exceeded 90 seconds';child.kill();},90000);
  child.once('close',(exitCode,signal)=>{clearTimeout(timer);resolve({pid:child.pid,exitCode,signal,error,stdout,stderr});});
 });
 fs.writeFileSync(path.join(stage,name+'.stdout.log'),result.stdout);fs.writeFileSync(path.join(stage,name+'.stderr.log'),result.stderr);
 const text=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+result.stderr;
 const engineClean=!/SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB.*leak|resources still in use/m.test(text);
 const proof=checkOnly?{success:true}:result.stdout.split('\n').map(line=>{try{return JSON.parse(line);}catch{return null;}}).find(v=>v?.checks);
 const success=result.exitCode===0&&!result.signal&&!result.error&&engineClean&&proof?.success===true;
 runs.push({name,success,engineClean,proof,...result,stdout:undefined,stderr:undefined});if(!success)break;
}
const changedGuards=guards.filter(v=>hash(fs.readFileSync(path.join(project,v.relative)))!==v.sha256);
const changedTrialPins=overlay.trialPins.filter(v=>hash(fs.readFileSync(path.join(overlay.rendererProject,v.relative)))!==v.sha256).map(v=>v.relative);
const report={success:runs.length===2&&runs.every(v=>v.success)&&!changedGuards.length&&!changedTrialPins.length,serverConnections:0,graphicalProcessesStarted:0,sharedNativeBuilds:0,engineSha256:hash(fs.readFileSync(engine)),overlay:{file:overlayFile,sha256:hash(fs.readFileSync(overlayFile))},runs,changedGuards,changedTrialPins};
const output=path.join(project,'reports',label+'.json');if(fs.existsSync(output))throw Error('Existing check report preserved');fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));if(!report.success)process.exitCode=1;
