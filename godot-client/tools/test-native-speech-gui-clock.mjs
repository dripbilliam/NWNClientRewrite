import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2],inventory=process.argv[3]==='--inventory';
if(!/^native-speech-gui-clock-[a-z0-9-]+$/.test(label??'')||process.argv.length>(inventory?4:3)||process.argv[3]!==undefined&&!inventory)throw Error('Supply one fresh GUI-clock label, optionally --inventory (no copy/launch)');
const directory=path.join(project,'.cache/native-speech-gui-clock',label),inputs=new Map();
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),fileHash=file=>hash(fs.readFileSync(file));
function include(relative,kind='source'){
 const file=path.resolve(project,relative);
 if(!file.startsWith(project+path.sep)||fs.realpathSync(file)!==file)throw Error('Static input escapes project or is linked: '+relative);
 if(inputs.has(file))return;
 const bytes=fs.readFileSync(file),row={path:path.relative(project,file).replaceAll('\\','/'),sha256:hash(bytes),kind};inputs.set(file,row);
 if(kind==='source'&&/\.(?:gd|gdshader)$/.test(file))for(const match of bytes.toString().matchAll(/["']res:\/\/([^"'\r\n]+\.(?:gd|json|gdshader|glsl))["']/g))include(match[1]);
}
include('tests/native_speech_gui_clock_test.gd');include('native_session_world.gd');include('tools/test-native-speech-gui-clock.mjs');
// Guard original configuration; copies live outside the private project so no
// main autoload or GDExtension is activated by this data-only test.
for(const file of ['project.godot','native/particle_kernel.gdextension','native/resource_index.gdextension','.godot/extension_list.cfg'])include(file,'guard');
const outputNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'];
const nativeOutputs=outputNames.map(file=>({file,sha256:fileHash(path.join(project,file))}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=fileHash(engine);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Existing engine identity differs');
if(inventory){console.log(JSON.stringify({inputs:inputs.size,sources:[...inputs.values()].filter(v=>v.kind==='source').length,guards:[...inputs.values()].filter(v=>v.kind==='guard').length,nativeOutputs:nativeOutputs.length,engineSha256,expectedChecks:54,engineLaunches:0,copyWrites:0}));process.exit(0);}
if(fs.existsSync(directory))throw Error('Existing evidence retained; use a fresh label');
const copiedProject=path.join(directory,'inputs/project');fs.mkdirSync(copiedProject,{recursive:true});
for(const[file,row]of inputs){const target=path.join(directory,'inputs',row.kind==='source'?'project':'guards',row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);row.copy=path.relative(directory,target).replaceAll('\\','/');if(fileHash(target)!==row.sha256)throw Error('Input changed during copy');}
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Actual Speech GUI Clock Inputs"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
const resultFile=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_speech_gui_clock_test.gd','--','--report='+resultFile],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',failure=null,bytes=0,spawned=false,exitObserved=false;
 const stop=reason=>{failure??=reason;if(!exitObserved)child.kill();};
 const consume=(kind,data)=>{bytes+=data.length;if(bytes>2*1024*1024){stop('Owned GUI-clock output exceeds2MiB');return;}if(kind==='stdout')stdout+=data.toString();else stderr+=data.toString();if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned GUI-clock engine reported an error');};
 child.stdout.on('data',b=>consume('stdout',b));child.stderr.on('data',b=>consume('stderr',b));child.once('spawn',()=>{spawned=true;});child.once('exit',()=>{exitObserved=true;});child.once('error',error=>{failure??=error.message;});
 const deadline=setTimeout(()=>stop('Owned GUI-clock gate exceeded65s'),65000);
 child.once('close',(code,signal)=>{clearTimeout(deadline);resolve({code,signal,failure,stdout,stderr,ownedProcessId:child.pid??null,spawned,exitObserved,closeObserved:true});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null,reportError=null;try{if(fs.existsSync(resultFile)){if(fs.statSync(resultFile).size>1024*1024)throw Error('Result exceeds1MiB');result=JSON.parse(fs.readFileSync(resultFile));}}catch(error){reportError=error.message;}
const text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',cleanEngine=!/^(?:WARNING:|ERROR:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+outcome.stderr);
const changedInputs=[...inputs].filter(([file,row])=>fileHash(file)!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>fileHash(path.join(directory,row.copy))!==row.sha256).map(row=>row.copy),changedOutputs=nativeOutputs.filter(row=>fileHash(path.join(project,row.file))!==row.sha256).map(row=>row.file),engineUnchanged=fileHash(engine)===engineSha256;
const ownedClosed=outcome.spawned&&outcome.exitObserved&&outcome.closeObserved;
const proof={success:outcome.code===0&&!outcome.failure&&!reportError&&result?.success===true&&result.checks===54&&result.actualOwnerMethods===3&&result.rootInstances===0&&result.visualNodes===0&&result.assetsRequested===0&&result.sourceParseOnly===true&&cleanEngine&&ownedClosed&&!changedInputs.length&&!changedCopies.length&&!changedOutputs.length&&engineUnchanged,checks:result?.checks??0,failures:result?.failures??[],inputs:[...inputs.values()],changedInputs,changedCopies,nativeOutputs,changedOutputs,engineSha256,engineUnchanged,ownedClosed,cleanEngine,exitCode:outcome.code,error:outcome.failure,reportError,signal:outcome.signal,ownedProcessId:outcome.ownedProcessId,serverConnections:0,keyReads:0,profileReads:0,gpu:false,userProcessActions:0,nativeBuilds:0,nativeExtensionsLoaded:false,scope:result?.scope??'No accepted actual GUI-clock input result; rejected evidence retained.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,failures:proof.failures.length,directory}));process.exitCode=proof.success?0:1;
