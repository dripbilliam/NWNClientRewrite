// Same isolated engine/guard policy as the weak-residency gate, with a paired
// pre-change material oracle and no world or graphics benchmark.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];if(!/^(?:material-init|combined-loading)-[a-z0-9-]+$/.test(label??''))throw Error('Prepared material candidate label required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),manifestFile=path.join(stage,'manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile)),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const checks=path.join(stage,label.startsWith('combined-loading-')?'checks-material-init':'checks');if(fs.existsSync(checks))throw Error('Existing check evidence preserved');fs.mkdirSync(checks);
const guards=['.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-window/nwn-window-modes.exe'].map(relative=>({relative,sha256:hash(fs.readFileSync(path.join(project,relative)))}));
const script='native_perf140_loading_material_init_test.gd',scriptBytes=fs.readFileSync(path.join(project,'tests',script));
const sourceStates=[['baseline',manifest.baseline],['candidate',manifest.candidate]].map(([variant,source])=>({variant,source,pins:[...manifest.pins.map(v=>({relative:v.relative,sha256:hash(fs.readFileSync(path.join(source,v.relative)))})),manifest.fixture]}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Pinned engine changed');
const runs=[];
for(const state of sourceStates){
 const testRoot=path.join(checks,state.variant),copy=path.join(testRoot,'project');fs.mkdirSync(copy,{recursive:true});for(const pin of state.pins){const file=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.copyFileSync(path.join(state.source,pin.relative),file);}
 fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Native Material Initialization Gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');fs.writeFileSync(path.join(copy,'tests',script),scriptBytes);
 const app=path.join(testRoot,'appdata'),local=path.join(testRoot,'localappdata');fs.mkdirSync(app);fs.mkdirSync(local);const log=path.join(testRoot,'engine.log'),proofFile=path.join(testRoot,'proof.json');
 const outcome=await new Promise(resolve=>{
  const child=spawn(engine,['--headless','--path',copy,'--log-file',log,'--script','res://tests/'+script,'--','--expect-batched='+(state.variant==='candidate'),'--report='+proofFile],{cwd:copy,windowsHide:true,env:{...process.env,APPDATA:app,LOCALAPPDATA:local,NWN_PARTICLE_KERNEL:'compiled'},stdio:['ignore','pipe','pipe']});let stdout='',stderr='',error=null,killed=false,bytes=0;
  const collect=(target,b)=>{bytes+=b.length;if(bytes>4*1024*1024){error??='Owned output exceeds 4 MiB';killed=true;child.kill();return;}if(target==='out')stdout+=b;else stderr+=b;};child.stdout.on('data',b=>collect('out',b));child.stderr.on('data',b=>collect('err',b));child.once('error',e=>error=e.message);
  const timeout=setTimeout(()=>{error='Owned material test exceeded 90 seconds';killed=true;child.kill();},90000);child.once('close',(exitCode,signal)=>{clearTimeout(timeout);resolve({pid:child.pid,exitCode,signal,error,killed,stdout,stderr});});
 });
 fs.writeFileSync(path.join(testRoot,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(testRoot,'stderr.log'),outcome.stderr);let proof=null;try{proof=JSON.parse(fs.readFileSync(proofFile));}catch{}
 const text=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+outcome.stderr,engineClean=!/SCRIPT ERROR|Parse Error|^ERROR:|WARNING:|ObjectDB.*leak|resources still in use/m.test(text);const success=outcome.exitCode===0&&!outcome.signal&&!outcome.error&&!outcome.killed&&engineClean&&proof?.success===true;
 runs.push({variant:state.variant,success,engineClean,proof,outcome:{...outcome,stdout:undefined,stderr:undefined}});if(!success)break;
}
const changedSources=sourceStates.flatMap(s=>s.pins.filter(p=>hash(fs.readFileSync(path.join(s.source,p.relative)))!==p.sha256).map(p=>({variant:s.variant,relative:p.relative}))),changedGuards=guards.filter(p=>hash(fs.readFileSync(path.join(project,p.relative)))!==p.sha256).map(p=>p.relative);
const report={success:runs.length===2&&runs.every(v=>v.success)&&!changedSources.length&&!changedGuards.length,serverConnections:0,graphicalProcessesStarted:0,sharedNativeBuilds:0,manifestSha256:hash(fs.readFileSync(manifestFile)),scriptSha256:hash(scriptBytes),engineSha256,runs,changedSources,changedGuards};const file=path.join(checks,'results.json');fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({file,...report}));if(!report.success)process.exitCode=1;
