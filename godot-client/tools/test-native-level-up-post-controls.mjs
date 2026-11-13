// Orchestration only. Godot owns native controls, state and resource preparation.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const self=fileURLToPath(import.meta.url),project=path.resolve(path.dirname(self),'..'),workspace=path.dirname(project);
const [mode,label,kind,approval,...extra]=process.argv.slice(2);
const cases=['domains','school','failed-domains','failed-school','empty-domains','empty-school','default-domains','default-school','busy-domains','busy-school','catalog-domains','catalog-school','disabled'];
if(mode!=='--execute-approved'||!/^[a-z0-9-]{3,85}$/.test(label??'')||!cases.includes(kind)||approval!=='root-approved-post-controls-v1'||extra.length)throw Error('Use --execute-approved <fresh-label> <case> root-approved-post-controls-v1 in the coordinated headless lane');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),fileSha=file=>sha(fs.readFileSync(file)),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;
 if(!file.startsWith(workspace+path.sep))throw Error('Source leaves workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:sha(bytes)});
 if(file.endsWith('.gd'))for(const match of bytes.toString().matchAll(/["']res:\/\/([^"']+\.(?:gd|json|gdshader|glsl))["']/g))include(path.join(project,match[1]));
}
const entry='tests/native_level_up_post_controls_test.gd';include(path.join(project,entry));include(self);
const rows=[...inputs.values()].sort((a,b)=>a.path.localeCompare(b.path)),closureSha256=sha(Buffer.from(JSON.stringify(rows)));
const outputNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'];
const outputs=outputNames.map(file=>({file,sha256:fileSha(path.join(project,file))}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=fileSha(engine);
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected pinned engine');
const directory=path.join(project,'.cache/level-up-post-controls',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence preserved; use fresh label');fs.mkdirSync(copy,{recursive:true});
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(fileSha(target)!==row.sha256)throw Error('Source changed while copying');}
const copiedProject=path.join(copy,'godot-client');
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Mode1 Domain School Controls"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
for(const name of ['appdata','localappdata','temp'])fs.mkdirSync(path.join(directory,name));
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const args=['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://'+entry,'--','--report='+report,'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall'),'--case='+kind];
fs.writeFileSync(path.join(directory,'inventory.json'),JSON.stringify({entry,inputs:rows,closureSha256,engine,engineSha256,outputs,args,deadlineMs:65000,maximumOutputBytes:2*1024*1024},null,2)+'\n');
console.log(JSON.stringify({state:'copy-complete',label,case:kind,inputs:rows.length,closureSha256,deadlineMs:65000}));
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,args,{cwd:directory,windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,APPDATA:path.join(directory,'appdata'),LOCALAPPDATA:path.join(directory,'localappdata'),TEMP:path.join(directory,'temp'),TMP:path.join(directory,'temp')}});
 let stdout='',stderr='',failure=null;
 const stop=reason=>{failure??=reason;if(child.exitCode===null)child.kill();};
 const consume=(stream,data)=>{if(stream==='stdout')stdout+=data.toString();else stderr+=data.toString();if(Buffer.byteLength(stdout)+Buffer.byteLength(stderr)>2*1024*1024){stdout=stdout.slice(-512*1024);stderr=stderr.slice(-512*1024);stop('Owned output exceeded2MiB');}if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned engine reported an error');};
 child.stdout.on('data',data=>consume('stdout',data));child.stderr.on('data',data=>consume('stderr',data));
 const timer=setTimeout(()=>stop('Owned case exceeded65s'),65000);child.once('error',error=>{failure??=error.message;});
 child.once('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal,failure,stdout,stderr,pid:child.pid??null});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null,reportError=null;try{if(fs.existsSync(report))result=JSON.parse(fs.readFileSync(report));}catch(error){reportError=error.message;}
const engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'',cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+outcome.stdout+'\n'+outcome.stderr);
const changed=(data,root,key)=>data.filter(row=>!fs.existsSync(path.join(root,row[key]))||fileSha(path.join(root,row[key]))!==row.sha256).map(row=>row[key]);
const changedInputs=changed(rows,workspace,'path'),changedCopies=changed(rows,copy,'path'),changedOutputs=changed(outputs,project,'file'),engineUnchanged=fileSha(engine)===engineSha256;
let ownedChildClosed=outcome.pid===null;if(outcome.pid!==null){try{process.kill(outcome.pid,0);}catch(error){ownedChildClosed=error.code==='ESRCH';}}
const proof={schema:'native-level-up-post-controls-v1',success:outcome.code===0&&!outcome.failure&&!reportError&&result?.success===true&&cleanEngine&&!changedInputs.length&&!changedCopies.length&&!changedOutputs.length&&engineUnchanged&&ownedChildClosed,label,case:kind,checks:result?.checks??0,failures:result?.failures??[],exitCode:outcome.code,error:outcome.failure,reportError,signal:outcome.signal,cleanEngine,inputs:rows,closureSha256,changedInputs,changedCopies,nativeOutputs:outputs,changedOutputs,engineSha256,engineUnchanged,ownedChildPid:outcome.pid,ownedChildClosed,serverConnections:0,nativeBuilds:0,keyReads:0,profileReads:0,gpu:false,scope:result?.scope??'No accepted functional result; preserve rejection'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:rows.length,nativeOutputs:outputs.length}));process.exitCode=proof.success?0:1;
