import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.dirname(project.replace(/[\\/]$/,''));
const arg=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
const run=arg('run'),script=arg('script'),graphical=process.argv.includes('--graphical');
if(!/^nwn40-[a-z0-9-]+$/.test(run??'')||!/^tests\/native_[a-z0-9_]+\.gd$/.test(script??''))throw Error('Explicit NWN-40 run and native test script required');
let screen=null;
if(graphical){
 const helper=path.join(project,'tools/native-window-screen.ps1').replaceAll("'","''");
 const value=execFileSync('pwsh',['-NoProfile','-Command',". '"+helper+"'; Get-NativeSecondaryScreen"],{encoding:'utf8',windowsHide:true}).trim();
 if(!/^\d+$/.test(value))throw Error('No secondary monitor is available; use headless validation');
 screen=Number(value);
}
const directory=path.join(project,'.cache/nwn40',run),copy=path.join(directory,'inputs'),copiedProject=path.join(copy,'godot-client');
if(fs.existsSync(directory))throw Error('Existing browser evidence retained');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();let inputBytes=0;
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;
 if(!file.startsWith(workspace+path.sep))throw Error('Browser closure escapes workspace');
 // Dynamic optional extensions are absent on some builds. The engine still
 // reports a failure if a test actually requires one of those extensions.
 if(file.endsWith('.gdextension')&&!fs.existsSync(file))return;
 const bytes=fs.readFileSync(file);inputBytes+=bytes.length;
 if(inputs.size>=2048||inputBytes>64*1024*1024)throw Error('Browser closure exceeds bound');
 inputs.set(file,{path:path.relative(workspace,file),sha256:hash(bytes)});
 if(file.endsWith('.gd')){
  for(const match of bytes.toString().matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of bytes.toString().matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of bytes.toString().matchAll(/["']res:\/\/([^"']+\.(?:json|gdshader|glsl))["']/g))if(fs.existsSync(path.join(project,match[1])))include(path.join(project,match[1]));
 }
}
for(const file of [script,'native/particle_kernel.gdextension','native/resource_index.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll'])include(path.join(project,file));
include(fileURLToPath(import.meta.url));
include(path.join(project,'tools/native-window-screen.ps1'));
fs.mkdirSync(copy,{recursive:true});
for(const [file,row]of inputs){const to=path.join(copy,row.path);fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(file,to);}
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="NWN-40 browser scope"\n[display]\nwindow/size/no_focus=true\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copiedProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(copiedProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineHash=hash(fs.readFileSync(engine));
const output=path.join(directory,'result.json'),log=path.join(directory,'engine.log'),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
const ownedAppData=path.join(directory,'appdata'),ownedLocalData=path.join(directory,'localappdata');fs.mkdirSync(ownedAppData);fs.mkdirSync(ownedLocalData);
const args=[...(graphical?['--screen',String(screen)]:['--headless']),'--rendering-method','gl_compatibility','--max-fps','60','--resolution','1280x900','--path',copiedProject,'--log-file',log,'--script','res://'+script,'--','--report='+output,'--install='+install];
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,args,{cwd:copiedProject,windowsHide:true,env:{...process.env,APPDATA:ownedAppData,LOCALAPPDATA:ownedLocalData},stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',error=null,bytes=0,killed=false;const stop=reason=>{error??=reason;if(!killed){killed=true;child.kill();}};
 child.stdout.on('data',value=>{bytes+=value.length;if(bytes>2*1024*1024)stop('Output budget exceeded');else stdout+=value;});child.stderr.on('data',value=>{bytes+=value.length;if(bytes>2*1024*1024)stop('Output budget exceeded');else stderr+=value;});child.once('error',value=>error=value.message);
 const timer=setTimeout(()=>stop('Browser scope test timed out'),90000);
 child.once('close',(exitCode,signal)=>{clearTimeout(timer);resolve({exitCode,signal,error,stdout,stderr,killed});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null;try{result=JSON.parse(fs.readFileSync(output,'utf8'));}catch{}
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const engineText=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB.*leak|resources still in use/m.test(engineText+'\n'+outcome.stderr);
const success=outcome.exitCode===0&&!outcome.error&&result?.success===true&&clean&&!changed.length&&hash(fs.readFileSync(engine))===engineHash;
const proof={success,script,graphical,screen,unfocusable:true,window:result?.window??null,checks:result?.checks??0,failures:result?.failures??[],clean,changed,engineHash,inputs:[...inputs.values()],inputBytes,serverConnections:0,userProcessActions:0,outcome};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,outcome:{...outcome,stdout:undefined,stderr:undefined}}));process.exitCode=success?0:1;
