import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a fresh instance-ID evidence label');
const directory=path.join(project,'.cache/native-direct-instance-ids',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence retained');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),fileHash=file=>hash(fs.readFileSync(file)),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Closure escapes workspace');
 const bytes=fs.readFileSync(file);if(inputs.size>=64||bytes.length>1024*1024)throw Error('Pure ID closure exceeds bound');
 inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd'))for(const match of bytes.toString().matchAll(/(?:(?:preload|load)\s*\(\s*|extends\s+)["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
}
include(path.join(project,'tests/native_direct_handoff_instance_ids_test.gd'));include(fileURLToPath(import.meta.url));
const guards=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','project.godot','.godot/extension_list.cfg'].map(file=>({file,sha256:fs.existsSync(path.join(project,file))?fileHash(path.join(project,file)):null}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=fileHash(engine),nodeSha256=fileHash(process.execPath);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
fs.mkdirSync(copy,{recursive:true});
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(fileHash(target)!==row.sha256)throw Error('Source changed during copy');}
const copiedProject=path.join(copy,'godot-client'),projectText='config_version=5\n[application]\nconfig/name="Owned Pure Instance IDs"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';
fs.writeFileSync(path.join(copiedProject,'project.godot'),projectText,{flag:'wx'});
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log'),appData=path.join(directory,'appdata'),localData=path.join(directory,'localappdata');fs.mkdirSync(appData);fs.mkdirSync(localData);
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_direct_handoff_instance_ids_test.gd','--','--result='+report],{cwd:copiedProject,env:{...process.env,APPDATA:appData,LOCALAPPDATA:localData},windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',bytes=0,error=null,spawned=false,exitObserved=false,killRequested=false;
 const stop=reason=>{error??=reason;if(!exitObserved&&!killRequested){killRequested=true;child.kill();}};
 const consume=(name,data)=>{bytes+=data.length;if(bytes>1024*1024){stop('Owned output exceeded1MiB');return;}if(name==='stdout')stdout+=data.toString();else stderr+=data.toString();if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned ID engine reported an error');};
 child.stdout.on('data',data=>consume('stdout',data));child.stderr.on('data',data=>consume('stderr',data));child.once('spawn',()=>spawned=true);child.once('exit',()=>exitObserved=true);child.once('error',value=>error??=value.message);
 const deadline=setTimeout(()=>stop('Owned pure ID gate exceeded35s'),35000);
 child.once('close',(exitCode,signal)=>{clearTimeout(deadline);resolve({exitCode,signal,error,stdout,stderr,ownedProcessId:child.pid??null,spawned,exitObserved,closeObserved:true,killRequested});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null,reportError=null;try{if(fs.statSync(report).size>128*1024)throw Error('ID result exceeds128KiB');result=JSON.parse(fs.readFileSync(report));}catch(error){reportError=error.message;}
const text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+outcome.stderr);
const changedInputs=[...inputs].filter(([file,row])=>fileHash(file)!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>fileHash(path.join(copy,row.path))!==row.sha256).map(row=>row.path),changedGuards=guards.filter(row=>(fs.existsSync(path.join(project,row.file))?fileHash(path.join(project,row.file)):null)!==row.sha256).map(row=>row.file);
const engineUnchanged=fileHash(engine)===engineSha256,nodeUnchanged=fileHash(process.execPath)===nodeSha256,ownedClosed=outcome.spawned&&outcome.exitObserved&&outcome.closeObserved,projectUnchanged=fs.readFileSync(path.join(copiedProject,'project.godot'),'utf8')===projectText,noExtensionList=!fs.existsSync(path.join(copiedProject,'.godot/extension_list.cfg'));
const proof={success:outcome.exitCode===0&&!outcome.error&&!reportError&&result?.success===true&&result.checks===12&&cleanEngine&&ownedClosed&&!changedInputs.length&&!changedCopies.length&&!changedGuards.length&&engineUnchanged&&nodeUnchanged&&projectUnchanged&&noExtensionList,checks:result?.checks??0,failures:result?.failures??[],actual:result?.actual,cleanEngine,reportError,inputs:[...inputs.values()],changedInputs,changedCopies,guards,changedGuards,engineSha256,engineUnchanged,nodeSha256,nodeUnchanged,projectUnchanged,noExtensionList,ownedClosed,outcome,sessionStartup:false,sockets:0,serverConnections:0,profileKeyReads:0,nativeBuilds:0,gpu:false,userProcessActions:0,scope:result?.scope??'No accepted pure ID result; evidence retained.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({...proof,inputs:inputs.size,outcome:{...outcome,stdout:undefined,stderr:undefined}}));process.exitCode=proof.success?0:1;
