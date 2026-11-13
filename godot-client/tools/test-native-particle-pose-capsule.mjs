import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [capsule,label,mode='capsule',suite='pose']=process.argv.slice(2);
if(!/^native-dense-(pose|light-input)-[a-z0-9-]+$/.test(capsule??'')||!/^native-(particle-pose|light-input)-engine-[a-z0-9-]+$/.test(label??'')||!['capsule','ordinary'].includes(mode)||!['pose','light'].includes(suite))throw Error('Supply private capsule, fresh native test label, mode and optional suite');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),digest=f=>hash(fs.readFileSync(f));
const parentFile=path.join(project,'.cache/native-dense-area',capsule,'candidate-sources.json'),receipt=JSON.parse(fs.readFileSync(parentFile));
if(!receipt.isolatedBuildFinalized||!receipt.isolatedBuild)throw Error('Private build not finalized');
let ordinaryRuntimeProof=null;
if(mode==='ordinary'){
 const manifestFile=path.join(project,'.cache/native-kernel/build-manifest.json'),manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8').replace(/^\uFEFF/,''));
 if(manifest.binarySha256!==digest(path.join(project,'.cache/native-kernel/nwn-particle-kernel.dll')))throw Error('Ordinary DLL differs from its build manifest');
 for(const[relative,sha]of Object.entries(manifest.sources))if(digest(path.join(project,relative))!==sha)throw Error('Ordinary compiled input changed: '+relative);
 ordinaryRuntimeProof={manifest:manifestFile,sha256:digest(manifestFile),binarySha256:manifest.binarySha256};
 receipt.sourceProject=project;
 receipt.sourcePins=receipt.sourcePins.filter(p=>fs.existsSync(path.join(project,p.relative))).map(p=>({...p,finalSha256:digest(path.join(project,p.relative))}));
}
const stage=path.join(project,'.cache/native-particle-pose-checks',label),copy=path.join(stage,'project');
if(fs.existsSync(stage))throw Error('Existing test evidence is preserved');
const guards=['.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json'].map(relative=>({relative,sha256:digest(path.join(project,relative))}));
fs.mkdirSync(copy,{recursive:true});
for(const pin of receipt.sourcePins){const source=path.join(receipt.sourceProject,pin.relative);if(digest(source)!==pin.finalSha256)throw Error('Parent source changed');const destination=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(source,destination);if(digest(destination)!==pin.finalSha256)throw Error('Copy differs');}
const projectText='config_version=5\n[application]\nconfig/name="Owned Native Particle Pose Gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
fs.writeFileSync(path.join(copy,'project.godot'),projectText);fs.mkdirSync(path.join(copy,'.godot'),{recursive:true});
fs.writeFileSync(path.join(copy,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=digest(engine);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Pinned engine differs');
const app=path.join(stage,'appdata'),local=path.join(stage,'localappdata');fs.mkdirSync(app);fs.mkdirSync(local);
const scripts=suite==='light'?['native_light_input_registry_test']:['native_particle_pose_cache_engine_test','native_particle_typed_pose_test','native_particle_presentation_test','native_particle_presentation_lifetime_test'];
const runs=[];
for(const script of scripts){
 const output=path.join(stage,script+'.json'),log=path.join(stage,script+'.engine.log');
 const result=await new Promise(resolve=>{
  const child=spawn(engine,['--headless','--path',copy,'--log-file',log,'--script','res://tests/'+script+'.gd','--','--particle-kernel=compiled','--report='+output,...(suite==='light'?['--baseline=res://tests/fixtures/focus_lighting_before_native_input.gd']:[])],{cwd:copy,env:{...process.env,APPDATA:app,LOCALAPPDATA:local,NWN_PARTICLE_KERNEL:'compiled'},windowsHide:true,stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='',error=null,killed=false,spawned=false,exited=false,bytes=0;
  const stop=reason=>{error??=reason;if(!exited&&!killed){killed=true;child.kill();}};
  const collect=(name,data)=>{bytes+=data.length;if(bytes>2*1024*1024){stop('Owned test output exceeds2MiB');return;}if(name==='out')stdout+=data.toString();else stderr+=data.toString();};
  child.stdout.on('data',data=>collect('out',data));child.stderr.on('data',data=>collect('err',data));child.once('spawn',()=>spawned=true);child.once('exit',()=>exited=true);child.once('error',e=>error??=e.message);
  const deadline=setTimeout(()=>stop('Owned test exceeded120s'),120000);
  child.once('close',(exitCode,signal)=>{clearTimeout(deadline);resolve({pid:child.pid,exitCode,signal,error,killed,spawned,exited,closed:true,stdout,stderr});});
 });
 fs.writeFileSync(path.join(stage,script+'.stdout.log'),result.stdout);fs.writeFileSync(path.join(stage,script+'.stderr.log'),result.stderr);
 let proof=null,proofError=null;try{proof=JSON.parse(fs.readFileSync(output));}catch(e){proofError=e.message;}
 const engineText=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+result.stderr;
 const engineClean=!/SCRIPT ERROR|Parse Error|^(?:ERROR:|WARNING:)|ObjectDB instances leaked|resources still in use|Leaked instance/m.test(engineText);
 const success=result.exitCode===0&&!result.error&&result.spawned&&result.exited&&result.closed&&!result.killed&&proof?.success===true&&proof.failures.length===0&&engineClean;
 runs.push({script,success,checks:proof?.checks??0,failures:proof?.failures??[],cache:proof?.cache,oracle:proof?.oracle,engineClean,proofError,proofSha256:proof?digest(output):null,outcome:{...result,stdout:undefined,stderr:undefined}});
 if(!success)break;
}
const changedSources=receipt.sourcePins.filter(p=>digest(path.join(receipt.sourceProject,p.relative))!==p.finalSha256).map(p=>p.relative);
const changedCopies=receipt.sourcePins.filter(p=>!['project.godot','.godot/extension_list.cfg'].includes(p.relative)&&digest(path.join(copy,p.relative))!==p.finalSha256).map(p=>p.relative);
const changedGuards=guards.filter(p=>digest(path.join(project,p.relative))!==p.sha256).map(p=>p.relative);
const testOverridesMatch=fs.readFileSync(path.join(copy,'project.godot'),'utf8')===projectText&&fs.readFileSync(path.join(copy,'.godot/extension_list.cfg'),'utf8')==='res://native/particle_kernel.gdextension\n';
const success=runs.length===scripts.length&&runs.every(r=>r.success)&&!changedSources.length&&!changedCopies.length&&!changedGuards.length&&digest(engine)===engineSha256&&testOverridesMatch;
const report={success,label,capsule,mode,suite,ordinaryRuntimeProof,sourcePins:receipt.sourcePins,checks:runs.reduce((n,r)=>n+r.checks,0),runs,sourceReceipt:{file:parentFile,sha256:digest(parentFile)},changedSources,changedCopies,guards,changedGuards,testOverridesMatch,engineSha256,sourceProject:receipt.sourceProject,copiedProject:copy,sharedNativeBuilds:0,nativeBuilds:0,gameNetworkConnections:0,gpu:false,scope:suite==='light'?'Actual compiled light-input registry versus frozen GDScript and native history/lamp outputs. No live-room/GPU/FPS acceptance.':'Actual native particle pose reuse versus uncached arithmetic, plus existing pose/presentation/lifetime gates. Explicit ordinary mode verifies current compiled inputs and copies its DLL; no live room or FPS acceptance.'};
const file=path.join(project,'reports',label+'.json');fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,file,checks:report.checks,runs:runs.map(r=>({script:r.script,success:r.success,checks:r.checks,failures:r.failures.slice(0,5),error:r.outcome.error,engineClean:r.engineClean})),changedSources,changedCopies,changedGuards}));
process.exitCode=success?0:1;
