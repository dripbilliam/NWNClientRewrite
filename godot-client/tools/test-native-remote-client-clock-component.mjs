import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {remoteClientClockFixture} from './native-remote-client-clock-fixture.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,90}$/.test(label??''))throw Error('Supply a fresh remote-clock component evidence label');
const directory=path.join(project,'.cache/native-remote-client-clock',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence retained');fs.mkdirSync(copy,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=p=>hash(fs.readFileSync(p)),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Component source escapes workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd'))for(const m of bytes.toString().matchAll(/["']res:\/\/([^"']+\.gd)["']/g))include(path.join(project,m[1]));
 if(/\.(?:js|mjs|cjs)$/.test(file))for(const m of bytes.toString().matchAll(/(?:from\s*|import\s*|require\(\s*)["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(file),m[1]));
}
for(const relative of ['tests/native_remote_client_clock_component_test.gd','tools/native-remote-client-clock-fixture.mjs','NATIVE-REMOTE-CLIENT-CLOCK-COMPONENT.md'])include(path.join(project,relative));
for(const relative of ['src/world_timer.js','src/client_pause.js','evidence/client-pause-clocks.md','scripts/inspect-native-client-pause.py','scripts/inspect-native-client-creature-clock.py','scripts/inspect-native-seconds-world-delta.py','backups/animations/native-client-pause-observations.json','backups/animations/native-client-creature-clock-observations.json','backups/animations/native-seconds-world-delta-observations.json'])include(path.join(workspace,relative));
include(fileURLToPath(import.meta.url));
const fixture=remoteClientClockFixture(),fixtureBytes=Buffer.from(JSON.stringify(fixture,null,2)+'\n'),fixtureSha256=hash(fixtureBytes);fs.writeFileSync(path.join(directory,'fixture.json'),fixtureBytes);
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(fileHash(target)!==row.sha256)throw Error('Component input changed during copy');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Native Remote Clock Components"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const outputNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'],nativeOutputs=outputNames.map(file=>({file,sha256:fileHash(path.join(project,file))}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=fileHash(engine);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
const resultFile=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_remote_client_clock_component_test.gd','--','--report='+resultFile,'--fixture='+path.join(directory,'fixture.json')],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',failure=null;
 const stop=reason=>{failure??=reason;if(child.exitCode===null)child.kill();};
 const consume=(kind,data)=>{if(kind==='stdout')stdout+=data.toString();else stderr+=data.toString();if(Buffer.byteLength(stdout)+Buffer.byteLength(stderr)>2*1024*1024){stdout=stdout.slice(-512*1024);stderr=stderr.slice(-512*1024);stop('Component output exceeds2MiB');}if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned component engine reported an error');};
 child.stdout.on('data',b=>consume('stdout',b));child.stderr.on('data',b=>consume('stderr',b));
 const deadline=setTimeout(()=>stop('Owned component gate exceeded65s'),65000);child.once('error',error=>{failure??=error.message});
 child.once('close',(code,signal)=>{clearTimeout(deadline);resolve({code,signal,failure,stdout,stderr,ownedProcessId:child.pid})});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null,reportError=null;try{if(fs.existsSync(resultFile))result=JSON.parse(fs.readFileSync(resultFile));}catch(error){reportError=error.message;}
const text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',cleanEngine=!/^(?:WARNING:|ERROR:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+outcome.stderr);
const changedInputs=[...inputs].filter(([file,row])=>fileHash(file)!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>fileHash(path.join(copy,row.path))!==row.sha256).map(row=>row.path),changedOutputs=nativeOutputs.filter(row=>fileHash(path.join(project,row.file))!==row.sha256).map(row=>row.file);
const fixtureUnchanged=fileHash(path.join(directory,'fixture.json'))===fixtureSha256,engineUnchanged=fileHash(engine)===engineSha256;
const proof={success:outcome.code===0&&!outcome.failure&&!reportError&&result?.success===true&&cleanEngine&&!changedInputs.length&&!changedCopies.length&&!changedOutputs.length&&fixtureUnchanged&&engineUnchanged,checks:result?.checks??0,failures:result?.failures??[],originalPauseCases:result?.originalPauseCases??0,originalCreatureCases:result?.originalCreatureCases??0,originalSecondsCases:result?.originalSecondsCases??0,inputs:[...inputs.values()],changedInputs,changedCopies,nativeOutputs,changedOutputs,engineSha256,engineUnchanged,fixtureSha256,fixtureUnchanged,cleanEngine,exitCode:outcome.code,error:outcome.failure,reportError,signal:outcome.signal,ownedProcessId:outcome.ownedProcessId,serverConnections:0,keyReads:0,profileReads:0,gpu:false,userProcessActions:0,nativeBuilds:0,scope:result?.scope??'No accepted native clock component result; rejected evidence retained.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,failures:proof.failures.length,directory}));process.exitCode=proof.success?0:1;

