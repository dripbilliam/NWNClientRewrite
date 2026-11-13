import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const self=fileURLToPath(import.meta.url),project=path.resolve(path.dirname(self),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??'')||process.argv.length!==3)throw Error('Supply a fresh evidence label');
const directory=path.join(project,'.cache/level-up-pending-cancel',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence is preserved');
const hash=value=>crypto.createHash('sha256').update(value).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;
 if(!file.startsWith(project+path.sep))throw Error('Input escapes project');
 const bytes=fs.readFileSync(file);inputs.set(file,{file:path.relative(project,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd'))for(const match of bytes.toString().matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]??match[2]));
}
for(const file of ['tests/native_level_up_pending_cancel_test.gd','systems/native_data/feedback_descriptors.json','native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll'])include(path.join(project,file));
include(self);
for(const[file,row]of inputs){const destination=path.join(copy,row.file);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(file,destination);if(hash(fs.readFileSync(destination))!==row.sha256)throw Error('Source changed while copying');}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned pending level-up cancellation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copy,'.godot'),{recursive:true});fs.writeFileSync(path.join(copy,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing Godot engine');
const outputs=['native-window/nwn-window-modes.exe','native-window/build-manifest.json','native-kernel/nwn-particle-kernel.dll','native-kernel/build-manifest.json','native-resource-index/nwn-resource-index.dll','native-resource-index/build-manifest.json'].map(file=>({file:'.cache/'+file,sha256:hash(fs.readFileSync(path.join(project,'.cache',file)))}));
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const args=['--headless','--max-fps','60','--path',copy,'--log-file',log,'--script','res://tests/native_level_up_pending_cancel_test.gd','--','--report='+report,'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall'),'--case=valid'];
fs.writeFileSync(path.join(directory,'inventory.json'),JSON.stringify({inputs:[...inputs.values()],outputs,engineSha256,args},null,2));
const child=spawnSync(engine,args,{windowsHide:true,timeout:55000,maxBuffer:2*1024*1024,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,logs=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'ERROR: missing engine log')+'\n'+child.stdout+'\n'+child.stderr;
const engineClean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|Unicode parsing error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(logs);
const changedSources=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.file);
const changedCopies=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(copy,row.file)))!==row.sha256).map(row=>row.file);
const changedOutputs=outputs.filter(row=>hash(fs.readFileSync(path.join(project,row.file)))!==row.sha256).map(row=>row.file);
const engineUnchanged=hash(fs.readFileSync(engine))===engineSha256;
const proof={success:child.status===0&&!child.error&&result?.success===true&&engineClean&&!changedSources.length&&!changedCopies.length&&!changedOutputs.length&&engineUnchanged,checks:result?.checks??0,failures:result?.failures??[],exitCode:child.status,error:child.error?.message??null,engineClean,engineUnchanged,inputs:[...inputs.values()],changedSources,changedCopies,outputs,changedOutputs,report,gpu:false,serverConnections:0,nativeBuilds:0,userProcessActions:0,scope:'Actual fallback Finish/Cancel pointer input, pending disabled controls and Escape-equivalent close signal, private draft/reply retirement and late-result isolation. Authored canonical input and server replies; no original-server admission, physical OS Escape or pixel acceptance.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');
console.log(JSON.stringify({...proof,inputs:inputs.size,outputs:outputs.length}));process.exitCode=proof.success?0:1;
