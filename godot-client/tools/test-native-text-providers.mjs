import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {actorNameFixture} from './native-actor-name-fixture.mjs';
import {receivedScriptFloatingFixture} from './native-script-floating-received-fixture.mjs';
import {actorNameWorldFixture} from './native-actor-name-world-fixture.mjs';
import {receivedSpeechFixture} from './native-overhead-received-fixture.mjs';
const project=fileURLToPath(new URL('../',import.meta.url)),workspace=path.dirname(project.replace(/[\\/]$/,''));
const arg=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
const run=arg('run'),script=arg('script'),graphical=process.argv.includes('--graphical');
if(!/^nwn33-[a-z0-9-]+$/.test(run??'')||!/^tests\/native_[a-z0-9_]+\.gd$/.test(script??''))throw Error('Explicit NWN-33 run and native test script required');
let screen=null;
if(graphical){
 const helper=path.join(project,'tools/native-window-screen.ps1').replaceAll("'","''");
 const value=execFileSync('pwsh',['-NoProfile','-Command',". '"+helper+"'; Get-NativeSecondaryScreen"],{encoding:'utf8',windowsHide:true}).trim();
 if(!/^\d+$/.test(value))throw Error('No secondary monitor is available; use headless validation');
 screen=Number(value);
}
const directory=path.join(project,'.cache/nwn33',run),copy=path.join(directory,'inputs'),copiedProject=path.join(copy,'godot-client');
if(fs.existsSync(directory))throw Error('Existing text evidence retained');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();let inputBytes=0;
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;
 if(!file.startsWith(workspace+path.sep))throw Error('Text provider closure escapes workspace');
 // Dynamic optional extensions are absent on some builds. The engine still
 // reports a failure if a test actually requires one of those extensions.
 if(file.endsWith('.gdextension')&&!fs.existsSync(file))return;
 const bytes=fs.readFileSync(file);inputBytes+=bytes.length;
 if(inputs.size>=2048||inputBytes>64*1024*1024)throw Error('Text provider closure exceeds bound');
 inputs.set(file,{path:path.relative(workspace,file),sha256:hash(bytes)});
 if(file.endsWith('.gd')){
  for(const match of bytes.toString().matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of bytes.toString().matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of bytes.toString().matchAll(/["']res:\/\/([^"']+\.(?:json|gdshader|glsl))["']/g))if(fs.existsSync(path.join(project,match[1])))include(path.join(project,match[1]));
 }
 if(/\.(?:js|mjs|cjs)$/.test(file))for(const match of bytes.toString().matchAll(/(?:from\s*|require\s*\(\s*|import\s*)["'](\.[^"']+\.(?:js|mjs|cjs))["']/g))include(path.resolve(path.dirname(file),match[1]));
}
include(path.join(project,script));
for(const file of ['tools/native-actor-name-fixture.mjs','native/particle_kernel.gdextension','native/resource_index.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll'])include(path.join(project,file));
include(path.join(workspace,'src/network_actor_name_state.js'));
const fixtures={original:'backups/animations/native-talk-token-parser-observations.json',supplement:'godot-client/.cache/native-talk-parse/native-talk-parser-certified-v1/result.json','game-corpus':'backups/animations/native-game-talk-token-observations.json'};
if(script.endsWith('native_script_floating_echo_test.gd')){fixtures['script-receiver']='backups/animations/native-client-feedback-layouts.json';include(path.join(project,'tools/native-session-host.cjs'));}
if(script.endsWith('native_overhead_integration_test.gd')){fixtures['chat-writer']='backups/animations/native-network-chat-writer-observations.json';fixtures['speech-writer']='backups/animations/native-network-speech-observations.json';include(path.join(project,'tools/native-session-host.cjs'));}
for(const file of Object.values(fixtures))include(path.join(workspace,file));
include(fileURLToPath(import.meta.url));
include(path.join(project,'tools/native-window-screen.ps1'));
fs.mkdirSync(copy,{recursive:true});
for(const [file,row]of inputs){const to=path.join(copy,row.path);fs.mkdirSync(path.dirname(to),{recursive:true});fs.copyFileSync(file,to);}
fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="NWN-33 text provider scope"\n[display]\nwindow/size/no_focus=true\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copiedProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(copiedProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n');
let fixtureData=actorNameFixture();
if(script.endsWith('native_script_floating_echo_test.gd'))fixtureData.unknownAreaFixture=receivedScriptFloatingFixture({worldAreaAvailable:false});
if(script.endsWith('native_actor_name_gameplay_test.gd'))fixtureData=actorNameWorldFixture();
if(script.endsWith('native_overhead_integration_test.gd')){fixtureData=receivedSpeechFixture({contextAvailable:false});fixtureData.tokenContextFixture=receivedSpeechFixture();}
const fixture=path.join(directory,'fixture.json');fs.writeFileSync(fixture,JSON.stringify(fixtureData,null,2)+'\n');const fixtureHash=hash(fs.readFileSync(fixture));

const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineHash=hash(fs.readFileSync(engine));
if(engineHash!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing Godot engine');
const output=path.join(directory,'result.json'),log=path.join(directory,'engine.log'),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
const ownedAppData=path.join(directory,'appdata'),ownedLocalData=path.join(directory,'localappdata');fs.mkdirSync(ownedAppData);fs.mkdirSync(ownedLocalData);
const args=[...(graphical?['--screen',String(screen)]:['--headless']),'--rendering-method','gl_compatibility','--max-fps','60','--resolution','1280x900','--path',copiedProject,'--log-file',log,'--script','res://'+script,'--','--report='+output,'--fixture='+fixture,'--install='+install,...Object.entries(fixtures).map(([key,file])=>'--'+key+'='+path.join(copy,file))];
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,args,{cwd:copiedProject,windowsHide:true,env:{...process.env,APPDATA:ownedAppData,LOCALAPPDATA:ownedLocalData},stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',error=null,bytes=0,killed=false;const stop=reason=>{error??=reason;if(!killed){killed=true;child.kill();}};
 const consume=(name,value)=>{bytes+=value.length;if(bytes>2*1024*1024){stop('Output budget exceeded');return;}if(name==='stdout')stdout+=value;else stderr+=value;if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Engine script error');};
 child.stdout.on('data',value=>consume('stdout',value));child.stderr.on('data',value=>consume('stderr',value));child.once('error',value=>error=value.message);
 const timer=setTimeout(()=>stop('Text provider scope test timed out'),90000);
 child.once('close',(exitCode,signal)=>{clearTimeout(timer);resolve({exitCode,signal,error,stdout,stderr,killed});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
let result=null;try{result=JSON.parse(fs.readFileSync(output,'utf8'));}catch{}
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const changedCopies=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path);
const engineText=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/SCRIPT ERROR|Parse Error|^ERROR:|ObjectDB.*leak|resources still in use/m.test(engineText+'\n'+outcome.stderr);
const fixtureUnchanged=hash(fs.readFileSync(fixture))===fixtureHash;
const success=outcome.exitCode===0&&!outcome.error&&result?.success===true&&clean&&!changed.length&&!changedCopies.length&&fixtureUnchanged&&hash(fs.readFileSync(engine))===engineHash;
const proof={success,script,graphical,screen,unfocusable:true,window:result?.window??null,checks:result?.checks??0,failures:result?.failures??[],clean,changed,changedCopies,fixtureHash,fixtureUnchanged,engineHash,inputs:[...inputs.values()],inputBytes,serverConnections:0,userProcessActions:0,outcome};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,outcome:{...outcome,stdout:undefined,stderr:undefined}}));process.exitCode=success?0:1;
