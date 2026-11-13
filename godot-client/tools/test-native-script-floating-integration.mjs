import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {receivedScriptFloatingFixture,SCRIPT_FLOATING_TARGET_STATES} from './native-script-floating-received-fixture.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2],kind=process.argv[3]??'integration';
const entries={integration:'native_script_floating_integration_test.gd',anchor:'native_script_floating_anchor_test.gd','live-compile':'native_script_floating_live_compile_test.gd',boundary:'native_script_floating_completion_test.gd'},entry=entries[kind];
if(!/^[a-z0-9-]{3,80}$/.test(label??'')||!entry)throw Error('Supply a unique evidence label and optional integration|anchor|live-compile|boundary case');
const directory=path.join(project,'.cache/script-floating-integration',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Existing evidence retained');
fs.mkdirSync(copy,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Source closure leaves workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd')){const source=bytes.toString();for(const m of source.matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));for(const m of source.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,m[1]));for(const m of source.matchAll(/["']res:\/\/([^"']+\.(?:json|gdshader|glsl))["']/g)){const target=path.join(project,m[1]);if(fs.existsSync(target))include(target);}}
}
for(const file of ['tests/'+entry,'tools/native-script-floating-received-fixture.mjs','tools/native-session-host.cjs','tools/native-text-event-scope.cjs','tools/raw-combat-events.cjs','systems/native_data/feedback_descriptors.json','native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json'])include(path.join(project,file));include(fileURLToPath(import.meta.url));
for(const file of ['src/network_game_messages.js','src/network_feedback_message.js','src/network_build.js','src/native_message.js','src/script_string.js','src/gff_text.js','src/game_object_array.js','src/network_entity_lifetimes.js','backups/animations/native-client-feedback-layouts.json'])include(path.join(workspace,file));
const receivedFixture=receivedScriptFloatingFixture();receivedFixture.targetVariants=Object.fromEntries(SCRIPT_FLOATING_TARGET_STATES.filter(state=>state!=='known-unrendered').map(state=>[state,receivedScriptFloatingFixture({targetState:state})]));receivedFixture.redisclosedFixture=receivedScriptFloatingFixture({disclosure:'redisclosed'});receivedFixture.unknownAreaFixture=receivedScriptFloatingFixture({worldAreaAvailable:false});fs.writeFileSync(path.join(directory,'fixture.json'),JSON.stringify(receivedFixture,null,2)+'\n');
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed during copied inventory');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Script Floating Integration"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');fs.mkdirSync(path.join(copiedProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(copiedProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\n');
const outputNames=['.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json'],outputs=outputNames.map(file=>({file,sha256:hash(fs.readFileSync(path.join(project,file)))}));
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const outcome=await new Promise(resolve=>{
 const child=spawn(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/'+entry,'--','--report='+report,'--fixture='+path.join(directory,'fixture.json'),'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall')],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let stdout='',stderr='',failure=null,settled=false;
 const stop=reason=>{failure??=reason;if(child.exitCode===null)child.kill();};
 const consume=(name,data)=>{if(name==='stdout')stdout+=data.toString();else stderr+=data.toString();if(Buffer.byteLength(stdout)+Buffer.byteLength(stderr)>2*1024*1024){stdout=stdout.slice(-512*1024);stderr=stderr.slice(-512*1024);stop('Bounded engine output exceeded2MiB');}if(/SCRIPT ERROR|Parse Error|^ERROR:/m.test(stdout+'\n'+stderr))stop('Owned offline engine reported an error');};
 child.stdout.on('data',bytes=>consume('stdout',bytes));child.stderr.on('data',bytes=>consume('stderr',bytes));
 const deadline=setTimeout(()=>stop('Owned ScriptFloating integration exceeded65s'),65000);
 child.once('error',error=>{failure??=error.message;});
 child.once('close',(code,signal)=>{if(settled)return;settled=true;clearTimeout(deadline);resolve({code,signal,failure,stdout,stderr,ownedProcessId:child.pid});});
});
fs.writeFileSync(path.join(directory,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(directory,'stderr.log'),outcome.stderr);
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+outcome.stderr);
const changedInputs=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path),changedOutputs=outputs.filter(row=>hash(fs.readFileSync(path.join(project,row.file)))!==row.sha256).map(row=>row.file);
const proof={success:outcome.code===0&&!outcome.failure&&clean&&result?.success===true&&!changedInputs.length&&!changedCopies.length&&!changedOutputs.length,checks:result?.checks??0,failures:result?.failures??[],cleanEngine:clean,exitCode:outcome.code,error:outcome.failure,signal:outcome.signal,directory,inputs:[...inputs.values()],changedInputs,changedCopies,nativeOutputs:outputs,changedOutputs,ownedProcessId:outcome.ownedProcessId,engineSha256,serverConnections:0,keyReads:0,nativeBuilds:0,userProcessActions:0,gpu:false,scope:result?.scope??'No accepted offline result; engine evidence retained.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size,failures:proof.failures.length}));process.exitCode=proof.success?0:1;
