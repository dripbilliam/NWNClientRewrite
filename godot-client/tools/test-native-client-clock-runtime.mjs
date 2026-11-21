import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,90}$/.test(label??''))throw Error('Supply a fresh runtime evidence label');
const directory=path.join(project,'.cache/native-client-clock-runtime',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing runtime evidence retained');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),fileHash=p=>hash(fs.readFileSync(p)),inputs=new Map();
let inputBytes=0;
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(file);inputBytes+=bytes.length;
 if(inputs.size>=2000||inputBytes>64*1024*1024)throw Error('Source closure exceeds bound');
 inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd')){
  for(const m of bytes.toString().matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));
  for(const m of bytes.toString().matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));
  for(const m of bytes.toString().matchAll(/["']res:\/\/([^"']+\.(?:json|gdshader|glsl))["']/g)){const p=path.join(project,m[1]);if(fs.existsSync(p))include(p);}
 }
 if(/\.[cm]?js$/.test(file))for(const m of bytes.toString().matchAll(/(?:\bfrom\s*|\bimport\s*(?:\(\s*)?|\brequire\s*\(\s*)["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(file),m[1]));
}
for(const name of ['tests/native_client_clock_runtime_test.gd','tools/native-clock-runtime-fixture.mjs','NATIVE-CLIENT-CLOCK-RUNTIME-TEST.md'])include(path.join(project,name));
include(fileURLToPath(import.meta.url));include(path.join(workspace,'package.json'));
const fixtureScript=path.join(project,'tools/native-clock-runtime-fixture.mjs');
if(fileHash(fixtureScript)!=='d2376c44d40f8e32cce0771ef9bd60e842990c79d86ccec0e2e035133e76e1fe')throw Error('Reviewed actual pipeline fixture changed');
const candidate=path.join(project,'.cache/native-clock-source-candidate-v1/builds/build-v1'),library=path.join(candidate,'bin/nwn-clock-source.dll'),build=path.join(candidate,'build-manifest.json');
const librarySha256=fileHash(library),buildSha256=fileHash(build);
if(librarySha256!=='497e483e44595a7518b860f92c55e3ab3cef9cd372b15c53a2ac31dfd2498190'||buildSha256!=='23a0e24994c71a7cef4ff12994dd78f6826c63ff2ce52d6468e54b4509d973d6')throw Error('Accepted private library/build changed');
const sourceText=fs.readFileSync(path.join(project,'systems/native_data/native_clock_source.gd'),'utf8');
const descriptorMatch=sourceText.match(/^const DESCRIPTOR_TEXT=("(?:\\.|[^"\\])*")\r?$/m);
if(!descriptorMatch)throw Error('Source descriptor literal unavailable');
const descriptor=JSON.parse(descriptorMatch[1]),descriptorSha256=hash(Buffer.from(descriptor));
const guardNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','project.godot','.godot/extension_list.cfg','.cache/native-clock-source-v1/nwn-clock-source.dll','.cache/native-clock-source-v1/clock_source.gdextension'];
const guards=guardNames.map(file=>({file,sha256:fs.existsSync(path.join(project,file))?fileHash(path.join(project,file)):null}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=fileHash(engine),nodeSha256=fileHash(process.execPath);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
async function runOwned(file,args,milliseconds,limit){
 return await new Promise(resolve=>{
  const child=spawn(file,args,{cwd:workspace,windowsHide:true,stdio:['ignore','pipe','pipe']});
  let stdout='',stderr='',error=null,bytes=0,spawned=false,exitObserved=false,killRequested=false;
  const stop=reason=>{error??=reason;if(!exitObserved&&!killRequested){killRequested=true;child.kill();}};
  const consume=(kind,data)=>{bytes+=data.length;if(bytes>limit){stop('Owned output bound exceeded');return;}if(kind==='stdout')stdout+=data.toString();else stderr+=data.toString();if(file===engine&&/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned engine reported an error');};
  child.stdout.on('data',b=>consume('stdout',b));child.stderr.on('data',b=>consume('stderr',b));child.once('spawn',()=>{spawned=true});child.once('exit',()=>{exitObserved=true});child.once('error',e=>{error??=e.message});
  const deadline=setTimeout(()=>stop('Owned deadline exceeded'),milliseconds);
  child.once('close',(exitCode,signal)=>{clearTimeout(deadline);resolve({exitCode,signal,error,stdout,stderr,ownedProcessId:child.pid??null,spawned,exitObserved,closeObserved:true,killRequested})});
 });
}
fs.mkdirSync(copy,{recursive:true});
const fixtureFile=path.join(directory,'fixture.json');
const fixtureProcess=await runOwned(process.execPath,[fixtureScript,'--output',fixtureFile],15000,1024*1024);
fs.writeFileSync(path.join(directory,'fixture-stdout.log'),fixtureProcess.stdout);fs.writeFileSync(path.join(directory,'fixture-stderr.log'),fixtureProcess.stderr);
let fixture=null,fixtureError=null;
try{
 if(fixtureProcess.exitCode!==0||fixtureProcess.error)throw Error('Actual pipeline fixture generation rejected');
 if(fs.statSync(fixtureFile).size>1024*1024)throw Error('Fixture exceeds1MiB');
 fixture=JSON.parse(fs.readFileSync(fixtureFile));
 if(fixture.checks.batchCount!==17||fixture.checks.frameCount!==15||!fixture.provenance.actualSessionWorldBridge||fixture.provenance.sourcePinsBefore.length!==fixture.provenance.sourcePinsAfter.length||JSON.stringify(fixture.provenance.sourcePinsBefore)!==JSON.stringify(fixture.provenance.sourcePinsAfter))throw Error('Actual fixture contract differs');
 for(const row of fixture.provenance.sourcePinsBefore){const file=path.join(workspace,row.path);include(file);if(fileHash(file)!==row.sha256)throw Error('Fixture source differs from retained pins');}
}catch(error){fixtureError=error.message;}
const fixtureSha256=fs.existsSync(fixtureFile)?fileHash(fixtureFile):null;
let outcome=null,result=null,reportError=null,cleanEngine=false,copiedArtifactsUnchanged=false;
if(!fixtureError){
 for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(fileHash(target)!==row.sha256)throw Error('Input changed during copy');}
 const copiedProject=path.join(copy,'godot-client'),extensionDirectory=path.join(copiedProject,'.cache/native-clock-source-v1');
 fs.mkdirSync(extensionDirectory,{recursive:true});
 const copiedLibrary=path.join(extensionDirectory,'nwn-clock-source.dll'),copiedDescriptor=path.join(extensionDirectory,'clock_source.gdextension');
 fs.copyFileSync(library,copiedLibrary);fs.writeFileSync(copiedDescriptor,descriptor,{flag:'wx'});
 fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Native Client Clock Runtime"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
 // No extension_list is authored: Source explicitly loads the hidden descriptor.
 const resultFile=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
 outcome=await runOwned(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_client_clock_runtime_test.gd','--','--report='+resultFile,'--fixture='+fixtureFile],65000,2*1024*1024);
 fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
 try{if(fs.statSync(resultFile).size>1024*1024)throw Error('Result exceeds1MiB');result=JSON.parse(fs.readFileSync(resultFile));}catch(error){reportError=error.message;}
 const engineText=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 cleanEngine=!/^(?:WARNING:|ERROR:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineText+'\n'+outcome.stderr);
 copiedArtifactsUnchanged=fileHash(copiedLibrary)===librarySha256&&fs.readFileSync(copiedDescriptor,'utf8')===descriptor;
}
const changedInputs=[...inputs].filter(([file,row])=>fileHash(file)!==row.sha256).map(([,row])=>row.path);
const changedCopies=fixtureError?[]:[...inputs.values()].filter(row=>fileHash(path.join(copy,row.path))!==row.sha256).map(row=>row.path);
const changedGuards=guards.filter(row=>(fs.existsSync(path.join(project,row.file))?fileHash(path.join(project,row.file)):null)!==row.sha256).map(row=>row.file);
const artifactUnchanged=fileHash(library)===librarySha256&&fileHash(build)===buildSha256,engineUnchanged=fileHash(engine)===engineSha256,nodeUnchanged=fileHash(process.execPath)===nodeSha256;
const fixtureUnchanged=fixtureSha256!==null&&fileHash(fixtureFile)===fixtureSha256,closed=p=>p?.spawned&&p.exitObserved&&p.closeObserved;
const proof={success:!fixtureError&&!reportError&&result?.success===true&&outcome?.exitCode===0&&!outcome.error&&cleanEngine&&closed(outcome)&&closed(fixtureProcess)&&!changedInputs.length&&!changedCopies.length&&!changedGuards.length&&artifactUnchanged&&engineUnchanged&&nodeUnchanged&&fixtureUnchanged&&copiedArtifactsUnchanged,
 checks:result?.checks??0,failures:result?.failures??[],batches:result?.batches?.length??0,coldFullSnapshots:result?.coldFullSnapshots??0,inputs:[...inputs.values()],inputBytes,changedInputs,changedCopies,guards,changedGuards,engineSha256,engineUnchanged,nodeSha256,nodeUnchanged,librarySha256,buildSha256,artifactUnchanged,descriptorSha256,copiedArtifactsUnchanged,fixtureSha256,fixtureUnchanged,fixtureError,reportError,cleanEngine,fixtureProcess,outcome,
 limits:{fixtureMilliseconds:15000,engineMilliseconds:65000,fixtureOutputBytes:1024*1024,engineOutputBytes:2*1024*1024,resultBytes:1024*1024,inputFiles:2000,inputBytes:64*1024*1024},
 mainInstallation:false,mainExtensionListWritten:false,nativeBuilds:0,serverConnections:0,keyReads:0,profileReads:0,gpu:false,userProcessActions:0,
 scope:result?.scope??'No accepted runtime result; rejected evidence retained.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({...proof,inputs:inputs.size,fixtureProcess:{exitCode:fixtureProcess.exitCode,error:fixtureProcess.error,ownedProcessId:fixtureProcess.ownedProcessId,ownedClosed:closed(fixtureProcess)},outcome:outcome?{exitCode:outcome.exitCode,error:outcome.error,ownedProcessId:outcome.ownedProcessId,ownedClosed:closed(outcome)}:null}));
process.exitCode=proof.success?0:1;
