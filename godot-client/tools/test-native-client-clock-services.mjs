import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,90}$/.test(label??''))throw Error('Supply a fresh clock-services evidence label');
const directory=path.join(project,'.cache/native-client-clock-services',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence retained');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=p=>hash(fs.readFileSync(p)),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd'))for(const m of bytes.toString().matchAll(/["']res:\/\/([^"']+\.gd)["']/g))include(path.join(project,m[1]));
}
for(const relative of ['tests/native_client_clock_services_test.gd','NATIVE-CLIENT-CLOCK-SERVICES.md','NATIVE-REMOTE-CLIENT-CLOCK-LIFECYCLE.md'])include(path.join(project,relative));
for(const relative of ['backups/animations/native-client-creature-clock-observations.json','scripts/inspect-native-client-creature-clock.py'])include(path.join(workspace,relative));
include(fileURLToPath(import.meta.url));
const primitiveNativeBasis=[];
for(const [name,count,sha256] of [
 ['native-client-pause-observations.json',759,'5f1827c3f528b9f40a698fbd7a3287f15969cf2fd74f87f58b124fca6593b8b1'],
 ['native-client-creature-clock-observations.json',90,'9dd68ce3a17082f316ae1e697f410a28dc449baf463546e8fae9e2c14f6300eb'],
 ['native-seconds-world-delta-observations.json',55,'f8014d38f18c76fe946ddc12c75123871ba1131b5b834ee1e11d65bf9e31be34'],
]){
 const file=path.join(workspace,'backups/animations',name),bytes=fs.readFileSync(file),value=JSON.parse(bytes);
 if(hash(bytes)!==sha256||value.rows.length!==count||value.binarySha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Primitive retained basis differs');
 include(file);primitiveNativeBasis.push({name,sha256,cases:count,reexecuted:false});
}
const corpusPath=path.join(workspace,'backups/animations/native-client-creature-clock-observations.json'),corpusBytes=fs.readFileSync(corpusPath);
if(hash(corpusBytes)!=='9dd68ce3a17082f316ae1e697f410a28dc449baf463546e8fae9e2c14f6300eb')throw Error('Retained original caller corpus differs');
const corpus=JSON.parse(corpusBytes);if(corpus.rows.length!==90||corpus.binarySha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Retained corpus scope differs');
const outputNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'];
const nativeOutputs=outputNames.map(file=>({file,sha256:fileHash(path.join(project,file))}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=fileHash(engine);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
fs.mkdirSync(copy,{recursive:true});
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(fileHash(target)!==row.sha256)throw Error('Input changed during copy');}
const fixture=path.join(directory,'fixture.json');fs.writeFileSync(fixture,corpusBytes);const fixtureSha256=hash(corpusBytes);
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Native Clock Services"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const resultFile=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_client_clock_services_test.gd','--','--report='+resultFile,'--fixture='+fixture],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',failure=null,bytes=0,spawned=false,exitObserved=false;
 const stop=reason=>{failure??=reason;if(!exitObserved)child.kill();};
 const consume=(kind,data)=>{bytes+=data.length;if(bytes>2*1024*1024){stop('Owned clock-services output exceeds2MiB');return;}if(kind==='stdout')stdout+=data.toString();else stderr+=data.toString();if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned engine reported an error');};
 child.stdout.on('data',b=>consume('stdout',b));child.stderr.on('data',b=>consume('stderr',b));child.once('spawn',()=>{spawned=true});child.once('exit',()=>{exitObserved=true});
 const deadline=setTimeout(()=>stop('Owned clock-services gate exceeded65s'),65000);child.once('error',error=>{failure??=error.message});
 child.once('close',(code,signal)=>{clearTimeout(deadline);resolve({code,signal,failure,stdout,stderr,ownedProcessId:child.pid??null,spawned,exitObserved,closeObserved:true})});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null,reportError=null;try{if(fs.existsSync(resultFile)){if(fs.statSync(resultFile).size>1024*1024)throw Error('Result exceeds1MiB');result=JSON.parse(fs.readFileSync(resultFile));}}catch(error){reportError=error.message;}
const text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',cleanEngine=!/^(?:WARNING:|ERROR:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+outcome.stderr);
const changedInputs=[...inputs].filter(([file,row])=>fileHash(file)!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>fileHash(path.join(copy,row.path))!==row.sha256).map(row=>row.path),changedOutputs=nativeOutputs.filter(row=>fileHash(path.join(project,row.file))!==row.sha256).map(row=>row.file);
const fixtureUnchanged=fileHash(fixture)===fixtureSha256,engineUnchanged=fileHash(engine)===engineSha256,ownedClosed=outcome.spawned&&outcome.exitObserved&&outcome.closeObserved;
const proof={success:outcome.code===0&&!outcome.failure&&!reportError&&result?.success===true&&result?.retainedNativeCasesReexecuted===0&&result?.authoredScenarios===11&&cleanEngine&&ownedClosed&&!changedInputs.length&&!changedCopies.length&&!changedOutputs.length&&fixtureUnchanged&&engineUnchanged,checks:result?.checks??0,failures:result?.failures??[],retainedNativeCasesReexecuted:result?.retainedNativeCasesReexecuted??null,authoredScenarios:result?.authoredScenarios??0,inputs:[...inputs.values()],changedInputs,changedCopies,nativeOutputs,changedOutputs,engineSha256,engineUnchanged,fixtureSha256,fixtureUnchanged,ownedClosed,cleanEngine,exitCode:outcome.code,error:outcome.failure,reportError,signal:outcome.signal,ownedProcessId:outcome.ownedProcessId,serverConnections:0,keyReads:0,profileReads:0,gpu:false,userProcessActions:0,nativeBuilds:0,scope:result?.scope??'No accepted component result; rejected evidence retained.'};
proof.primitiveNativeBasis=primitiveNativeBasis;
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,failures:proof.failures.length,directory}));process.exitCode=proof.success?0:1;
