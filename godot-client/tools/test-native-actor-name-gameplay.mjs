import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {actorNameWorldFixture} from './native-actor-name-world-fixture.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,90}$/.test(label??''))throw Error('Supply a fresh actor-name Gameplay evidence label');
const directory=path.join(project,'.cache/native-actor-name-gameplay',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence retained');
fs.mkdirSync(copy,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),fileHash=file=>hash(fs.readFileSync(file)),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Source closure leaves workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd'))for(const m of bytes.toString().matchAll(/["']res:\/\/([^"']+\.(?:gd|json|gdshader|glsl))["']/g)){const target=path.join(project,m[1]);if(!fs.existsSync(target))throw Error('Missing static dependency '+m[1]);include(target);}
 if(/\.(?:js|cjs|mjs)$/.test(file))for(const m of bytes.toString().matchAll(/(?:from\s*|require\(\s*|import\s*)['"](\.[^'"]+)['"]/g)){let target=path.resolve(path.dirname(file),m[1]);if(!fs.existsSync(target)&&fs.existsSync(target+'.js'))target+='.js';if(fs.existsSync(target)&&fs.statSync(target).isFile())include(target);}
}
for(const name of ['tests/native_actor_name_gameplay_test.gd','tools/native-actor-name-world-fixture.mjs','native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'])include(path.join(project,name));
include(fileURLToPath(import.meta.url));
const fixtureText=JSON.stringify(actorNameWorldFixture(),null,2)+'\n',fixtureSha256=hash(Buffer.from(fixtureText));fs.writeFileSync(path.join(directory,'fixture.json'),fixtureText);
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(fileHash(target)!==row.sha256)throw Error('Source changed during bounded copy');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Native Actor Name Gameplay"\n[display]\nwindow/subwindows/embed_subwindows=true\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copiedProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(copiedProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\n');
const outputNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'];
const nativeOutputs=outputNames.map(file=>({file,sha256:fileHash(path.join(project,file))}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=fileHash(engine);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_actor_name_gameplay_test.gd','--','--report='+report,'--fixture='+path.join(directory,'fixture.json')],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',failure=null;
 const stop=reason=>{failure??=reason;if(child.exitCode===null)child.kill();};
 const consume=(name,data)=>{if(name==='stdout')stdout+=data.toString();else stderr+=data.toString();if(Buffer.byteLength(stdout)+Buffer.byteLength(stderr)>2*1024*1024){stdout=stdout.slice(-512*1024);stderr=stderr.slice(-512*1024);stop('Bounded output exceeded2MiB');}if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned copied engine reported an error');};
 child.stdout.on('data',data=>consume('stdout',data));child.stderr.on('data',data=>consume('stderr',data));
 const timer=setTimeout(()=>stop('Owned actor-name Gameplay gate exceeded65s'),65000);
 child.once('error',error=>{failure??=error.message});
 child.once('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal,failure,stdout,stderr,ownedProcessId:child.pid})});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null,reportError=null;try{if(fs.existsSync(report))result=JSON.parse(fs.readFileSync(report,'utf8'));}catch(error){reportError=error.message;}
const engineText=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineText+'\n'+outcome.stderr);
const changedInputs=[...inputs].filter(([file,row])=>fileHash(file)!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>fileHash(path.join(copy,row.path))!==row.sha256).map(row=>row.path),changedOutputs=nativeOutputs.filter(row=>fileHash(path.join(project,row.file))!==row.sha256).map(row=>row.file);
const fixtureUnchanged=fileHash(path.join(directory,'fixture.json'))===fixtureSha256,engineUnchanged=fileHash(engine)===engineSha256;
const proof={success:outcome.code===0&&!outcome.failure&&!reportError&&cleanEngine&&result?.success===true&&!changedInputs.length&&!changedCopies.length&&!changedOutputs.length&&fixtureUnchanged&&engineUnchanged,checks:result?.checks??0,failures:result?.failures??[],cleanEngine,exitCode:outcome.code,error:outcome.failure,reportError,signal:outcome.signal,directory,inputs:[...inputs.values()],changedInputs,changedCopies,nativeOutputs,changedOutputs,fixtureSha256,fixtureUnchanged,engineSha256,engineUnchanged,ownedProcessId:outcome.ownedProcessId,serverConnections:0,keyReads:0,originalProfileReads:0,nativeBuilds:0,gpu:false,userProcessActions:0,scope:result?.scope??'No accepted actor-name Gameplay result; rejected evidence retained.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,failures:proof.failures.length}));process.exitCode=proof.success?0:1;

