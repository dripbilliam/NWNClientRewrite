import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/area-border-settings',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),seen=new Set(),inputs=[];
function collect(file){if(seen.has(file))return;seen.add(file);const bytes=fs.readFileSync(path.join(project,file));inputs.push({path:file,sha256:hash(bytes)});if(/\.(gd|gdshader)$/.test(file))for(const match of bytes.toString().matchAll(/["']res:\/\/([^"'\r\n]+\.(?:gd|gdshader))["']/g))collect(match[1]);}
collect('tests/native_area_border_settings_test.gd');collect('tools/test-native-area-border-settings.mjs');
for(const row of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(project,row.path),target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Copy mismatch');}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Native Area Border Settings Isolated"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected engine');
const userDirectory=path.join(process.env.APPDATA,'Godot/app_userdata/NWN Native Engine Prototype'),userInputs=['native-options.cfg','native-menu-layout.cfg'].map(file=>{const target=path.join(userDirectory,file);return {path:target,exists:fs.existsSync(target),sha256:fs.existsSync(target)?hash(fs.readFileSync(target)):null};});
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
console.log(JSON.stringify({stage:'copy-complete',inputs:inputs.length,report}));
const child=spawnSync(engine,['--headless','--max-fps','60','--path',copy,'--log-file',log,'--script','res://tests/native_area_border_settings_test.gd','--','--report='+report],{windowsHide:true,encoding:'utf8',timeout:65000});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+child.stderr),changedInputs=inputs.filter(row=>hash(fs.readFileSync(path.join(project,row.path)))!==row.sha256).map(row=>row.path),changedCopies=inputs.filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path),changedUserInputs=userInputs.filter(row=>fs.existsSync(row.path)!==row.exists||(row.exists&&hash(fs.readFileSync(row.path))!==row.sha256)).map(row=>row.path);
const proof={success:child.status===0&&!child.error&&cleanEngine&&result?.success===true&&!changedInputs.length&&!changedCopies.length&&!changedUserInputs.length,checks:result?.checks??0,failures:result?.failures??[],cleanEngine,exitCode:child.status,error:child.error?.message??null,inputs,changedInputs,changedCopies,userInputs,changedUserInputs,engineSha256,gpu:false,serverConnections:0,nativeBuilds:0,productionEdits:false,scope:result?.scope??'No accepted result.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.length,userInputs:userInputs.length}));process.exitCode=proof.success?0:1;
