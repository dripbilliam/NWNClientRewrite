// Orchestration only. Godot production code reads/prepares all model/scene data.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const [mode,label,approval,...extra]=process.argv.slice(2);
if(mode!=='--execute-approved'||!/^[a-z0-9-]{3,80}$/.test(label??'')||approval!=='root-approved-border-geometry-v1'||extra.length)throw Error('Explicit coordinated engine lane required: --execute-approved <unique-label> root-approved-border-geometry-v1');
const directory=path.join(project,'.cache/area-border-geometry',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence retained; choose a fresh label');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;
 if(!file.startsWith(workspace+path.sep))throw Error('Source closure leaves workspace');
 const bytes=fs.readFileSync(file),row={path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)};inputs.set(file,row);
 if(!file.endsWith('.gd'))return;
 for(const match of bytes.toString().matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
 for(const match of bytes.toString().matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
 for(const match of bytes.toString().matchAll(/["']res:\/\/([^"']+\.(?:json|gdshader|glsl))["']/g)){const target=path.join(project,match[1]);if(fs.existsSync(target))include(target);}
}
const entry='tests/native_area_border_geometry_test.gd';
for(const name of [entry,'reports/native-area-border-installed-v1.json','native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'])include(path.join(project,name));
include(fileURLToPath(import.meta.url));
const outputNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'];
const outputs=outputNames.map(file=>({file,sha256:hash(fs.readFileSync(path.join(project,file)))}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine identity');
fs.mkdirSync(copy,{recursive:true});
for(const [file,row] of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed during copied inventory');}
const copiedProject=path.join(copy,'godot-client');
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Installed Border Geometry"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copiedProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(copiedProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\n');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const command=[engine,'--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://'+entry,'--','--report='+report,'--installed-fixture='+path.join(copiedProject,'reports/native-area-border-installed-v1.json'),'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall')];
fs.writeFileSync(path.join(directory,'inventory.json'),JSON.stringify({inputs:[...inputs.values()],nativeOutputs:outputs,engineSha256,command,scope:'Headless actual-model correctness; no rendering or model preparation in JavaScript.'},null,2)+'\n');
console.log(JSON.stringify({state:'copy-complete',label,directory,inputs:inputs.size,headless:true,deadlineMs:65000}));
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,command.slice(1),{cwd:copiedProject,windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',failure=null,settled=false;
 const stop=reason=>{failure??=reason;if(child.exitCode===null)child.kill();};
 const consume=(name,data)=>{
  if(name==='stdout')stdout+=data.toString();else stderr+=data.toString();
  if(Buffer.byteLength(stdout)+Buffer.byteLength(stderr)>2*1024*1024){stdout=stdout.slice(-512*1024);stderr=stderr.slice(-512*1024);stop('Owned engine output exceeded2MiB');}
  if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned engine reported an error');
 };
 child.stdout.on('data',data=>consume('stdout',data));child.stderr.on('data',data=>consume('stderr',data));
 const timer=setTimeout(()=>stop('Owned border geometry case exceeded65s'),65000);
 child.once('error',error=>{failure??=error.message;});
 child.once('close',(code,signal)=>{if(settled)return;settled=true;clearTimeout(timer);resolve({code,signal,failure,stdout,stderr,ownedProcessId:child.pid});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null,reportError=null;
if(fs.existsSync(report)){try{result=JSON.parse(fs.readFileSync(report));}catch(error){reportError=error.message;}}
const text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+outcome.stderr);
const changedInputs=[...inputs].filter(([file,row])=>!fs.existsSync(file)||hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const changedCopies=[...inputs.values()].filter(row=>!fs.existsSync(path.join(copy,row.path))||hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path);
const changedOutputs=outputs.filter(row=>!fs.existsSync(path.join(project,row.file))||hash(fs.readFileSync(path.join(project,row.file)))!==row.sha256).map(row=>row.file);
const unchangedEngine=hash(fs.readFileSync(engine))===engineSha256;
let ownedProcessClosed=true;try{process.kill(outcome.ownedProcessId,0);ownedProcessClosed=false;}catch(error){if(error.code!=='ESRCH')ownedProcessClosed=false;}
const proof={success:outcome.code===0&&!outcome.failure&&!reportError&&clean&&result?.success===true&&!changedInputs.length&&!changedCopies.length&&!changedOutputs.length&&unchangedEngine&&ownedProcessClosed,label,directory,checks:result?.checks??0,failures:result?.failures??[],engineError:outcome.failure,reportError,exitCode:outcome.code,signal:outcome.signal,cleanEngine:clean,inputs:[...inputs.values()],changedInputs,changedCopies,nativeOutputs:outputs,changedOutputs,engineSha256,unchangedEngine,ownedProcessId:outcome.ownedProcessId,ownedProcessClosed,serverConnections:0,keyReads:0,nativeBuilds:0,userProcessActions:0,headless:true,gpu:false,scope:result?.scope??'No accepted geometry result; rejected evidence retained.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');
console.log(JSON.stringify({...proof,inputs:inputs.size,nativeOutputs:outputs.length,failures:proof.failures.length}));process.exitCode=proof.success?0:1;
