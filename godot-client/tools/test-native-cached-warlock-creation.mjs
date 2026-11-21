import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const label=process.argv[2];if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Use a unique evidence label');
const variant=process.argv[4]??'bounded';if(!['bounded','complete','recommended','feat-comparison'].includes(variant))throw Error('Unknown owned fixture variant');
const complete=variant!=='bounded',packageId=Number(process.argv[5]??310);if(variant==='recommended'&&![310,311,312,313,314].includes(packageId))throw Error('Only an actually visible cached package may be selected');
const script=variant==='feat-comparison'?'native_cached_warlock_feat_comparison_test.gd':variant==='recommended'?'native_cached_warlock_recommended_test.gd':complete?'native_cached_warlock_complete_test.gd':'native_cached_warlock_creation_test.gd';
const fixture=path.resolve(process.argv[3]??path.join(project,'.cache/cached-warlock-creation/cached-arelith-warlock-namespace-v2'));
if(!fixture.startsWith(path.join(project,'.cache/cached-warlock-creation')+path.sep))throw Error('Only owned offline cached fixture accepted');
const directory=path.join(project,'.cache',complete?'cached-warlock-complete':'cached-warlock-source',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Preserve previous evidence');fs.mkdirSync(copy,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(root+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(file),source=bytes.toString('utf8');inputs.set(file,{path:path.relative(root,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd')){
  for(const match of source.matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of source.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of source.matchAll(/["']res:\/\/([^"']+\.(?:json|gdshader|glsl))["']/g)){const target=path.join(project,match[1]);if(fs.existsSync(target))include(target);}
 }
}
for(const file of ['tests/'+script,'native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','systems/native_data/feedback_descriptors.json'])include(path.join(project,file));
include(fileURLToPath(import.meta.url));
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed during copy');}
const manifest=JSON.parse(fs.readFileSync(path.join(fixture,'fixture.json')));
if(!manifest.success||manifest.captureGaps.length)throw Error('Selected manifest closure has a recording gap');
const dataInputs=[{file:path.join(fixture,'fixture.json'),sha256:hash(fs.readFileSync(path.join(fixture,'fixture.json')))},...manifest.resources.map(row=>({file:path.join(fixture,row.file),sha256:row.sha256}))];
if(manifest.privateNwsyncCatalog){const manifestFile=path.join(fixture,'nwsync/manifests',manifest.manifest);dataInputs.push({file:manifestFile,sha256:manifest.manifestSha256});for(const sha1 of new Set(manifest.resources.map(row=>row.sha1))){const file=path.join(fixture,'nwsync/objects',sha1);dataInputs.push({file,sha256:hash(fs.readFileSync(file))});}}
for(const row of dataInputs)if(hash(fs.readFileSync(row.file))!==row.sha256)throw Error('Cached fixture bytes changed');
const outputs=['native-window/nwn-window-modes.exe','native-window/build-manifest.json','native-kernel/nwn-particle-kernel.dll','native-kernel/build-manifest.json','native-resource-index/nwn-resource-index.dll','native-resource-index/build-manifest.json'].map(file=>path.join(project,'.cache',file));
const nativeBefore=outputs.map(file=>({path:path.relative(project,file).replaceAll('\\','/'),sha256:hash(fs.readFileSync(file))}));
const copied=path.join(copy,'godot-client');fs.writeFileSync(path.join(copied,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Cached Warlock Source Flow"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(copied,'.godot'),{recursive:true});fs.writeFileSync(path.join(copied,'.godot/extension_list.cfg'),'res://native/particle_kernel.gdextension\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing runtime; no build/download');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const child=spawnSync(engine,['--headless','--path',copied,'--log-file',log,'--script','res://tests/'+script,'--','--report='+report,'--fixture='+fixture,'--install='+path.resolve(root,'../FullDecomp/NwnRootInstall'),...(variant==='recommended'?['--package='+packageId]:[])],{windowsHide:true,timeout:65000,maxBuffer:4*1024*1024,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const value=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,text=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(text+'\n'+child.stderr);
const changedInputs=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const changedCopy=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path);
const changedData=dataInputs.filter(row=>hash(fs.readFileSync(row.file))!==row.sha256).map(row=>row.file);
const changedNative=outputs.filter((file,index)=>hash(fs.readFileSync(file))!==nativeBefore[index].sha256);
const receipt={success:child.status===0&&!child.error&&cleanEngine&&value?.success===true&&!changedInputs.length&&!changedCopy.length&&!changedData.length&&!changedNative.length,checks:value?.checks??0,failures:value?.failures??[],blocker:value?.blocker??'',cleanEngine,exitCode:child.status,error:child.error?.message??null,directory,fixture,script,manifest:manifest.manifest,inputs:[...inputs.values()],dataInputs,changedInputs,changedCopy,changedData,nativeBefore,changedNative,engineSha256,serverConnections:0,protectedProfilesRead:0,nativeBuilds:0,gpu:false,userProcessActions:0};
fs.writeFileSync(path.join(directory,'runner.json'),JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify({...receipt,inputs:inputs.size,dataInputs:dataInputs.length,nativeBefore:6}));process.exitCode=receipt.success?0:1;
