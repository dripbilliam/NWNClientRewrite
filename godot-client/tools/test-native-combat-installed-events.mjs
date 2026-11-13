// Narrow original installed MDL/event diagnostic. No game network or renderer.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const run=path.join(project,'.cache/combat-installed-events',new Date().toISOString().replace(/[-:.TZ]/g,'')+'-'+crypto.randomUUID().slice(0,8)),copy=path.join(run,'inputs');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;
 if(!file.startsWith(workspace+path.sep))throw Error('Input outside workspace');
 const bytes=fs.readFileSync(file),row={path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)};inputs.set(file,row);
 if(file.endsWith('.gd')){const text=bytes.toString();for(const match of text.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));for(const match of text.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));}
}
include(path.join(project,'tests/native_combat_installed_events_probe.gd'));include(fileURLToPath(import.meta.url));
for(const file of ['native/particle_kernel.gdextension','native/resource_index.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/build-manifest.json'])include(path.join(project,file));
for(const [file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Input changed while copied');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Original Combat Events"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copiedProject,'.godot'),{recursive:true});fs.writeFileSync(path.join(copiedProject,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\nres://native/resource_index.gdextension\n');
const godot=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing Godot runtime');
const report=path.join(run,'result.json'),log=path.join(run,'engine.log'),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
const child=spawnSync(godot,['--headless','--path',copiedProject,'--log-file',log,'--script','res://tests/native_combat_installed_events_probe.gd','--','--report='+report,'--install='+install],{windowsHide:true,timeout:35000,encoding:'utf8'});
fs.writeFileSync(path.join(run,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(run,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+child.stderr);
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const receipt={success:child.status===0&&!child.error&&clean&&result?.success===true&&changed.length===0,checks:result?.checks??0,engineSha256,exitCode:child.status,error:child.error?.message??null,cleanEngine:clean,changedInputs:changed,inputs:[...inputs.values()],directory:run,report,gpu:false,serverConnections:0,nativeBuilds:0,scope:result?.scope??'Installed-model event diagnostic failed before a result'};
fs.writeFileSync(path.join(run,'proof.json'),JSON.stringify(receipt,null,2)+'\n');
if(receipt.success)fs.writeFileSync(path.join(project,'reports/native-combat-installed-events-v1-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({...receipt,inputs:receipt.inputs.length}));process.exitCode=receipt.success?0:1;
