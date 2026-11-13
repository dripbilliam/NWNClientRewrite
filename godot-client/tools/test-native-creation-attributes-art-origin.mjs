import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const label=process.argv[2];if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Use a unique evidence label');
const baseline=process.argv[3]==='--baseline-rows';if(process.argv[3]&&!baseline)throw Error('Unknown diagnostic mode');
const originalRowSource=path.join(project,'.cache/creation-attributes-art-origin/checkpoint-before-static-rows/native_attributes_chooser.gd');
const directory=path.join(project,'.cache/creation-attributes-art-origin',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Preserve prior evidence');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input leaves workspace');const source=baseline&&file===path.join(project,'systems/native_attributes_chooser.gd')?originalRowSource:file,data=fs.readFileSync(source);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sourcePath:path.relative(workspace,source).replaceAll('\\','/'),sha256:hash(data)});if(file.endsWith('.gd'))for(const found of data.toString().matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']|extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,found[1]??found[2]));}
include(path.join(project,'tests/native_creation_attributes_art_origin_test.gd'));include(fileURLToPath(import.meta.url));
for(const[,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(workspace,row.sourcePath),target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Input changed during copy');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Hidden Attributes Art Origin"\n[display]\nwindow/size/no_focus=true\nwindow/size/borderless=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(-32000,-32000)\nwindow/size/viewport_width=16\nwindow/size/viewport_height=16\n[rendering]\nrenderer/rendering_method="forward_plus"\n');
const outputPaths=['native-window/nwn-window-modes.exe','native-window/build-manifest.json','native-kernel/nwn-particle-kernel.dll','native-kernel/build-manifest.json','native-resource-index/nwn-resource-index.dll','native-resource-index/build-manifest.json'].map(file=>path.join(project,'.cache',file));
const nativeBefore=outputPaths.map(file=>({path:path.relative(project,file).replaceAll('\\','/'),sha256:hash(fs.readFileSync(file))}));
const godot=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected runtime; no build/download permitted');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const child=spawnSync(godot,['--rendering-method','forward_plus','--rendering-driver','vulkan','--position','-32000,-32000','--resolution','16x16','--max-fps','30','--path',copiedProject,'--log-file',log,'--script','res://tests/native_creation_attributes_art_origin_test.gd','--','--report='+report,'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall')],{windowsHide:true,timeout:35000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engine+'\n'+child.stderr);
const changed=[...inputs].filter(([,row])=>hash(fs.readFileSync(path.join(workspace,row.sourcePath)))!==row.sha256).map(([,row])=>row.path),changedNative=outputPaths.filter((file,index)=>hash(fs.readFileSync(file))!==nativeBefore[index].sha256);
const proof={success:child.status===0&&!child.error&&clean&&result?.success===true&&!changed.length&&!changedNative.length,checks:result?.checks??0,failures:result?.failures??[],directory,report,cleanEngine:clean,exitCode:child.status,error:child.error?.message??null,baselineSelected:baseline,inputs:[...inputs.values()],changedInputs:changed,engineSha256,nativeBefore,changedNative,gpuRaster:true,gpuBenchmark:false,serverConnections:0,nativeBuilds:0,scope:'Bounded hidden non-activating actual installed Attributes model/font raster and row-origin geometry. No FPS benchmark, rules mutation, server or user-client interaction.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:proof.inputs.length,nativeBefore:proof.nativeBefore.length}));process.exitCode=proof.success?0:1;
