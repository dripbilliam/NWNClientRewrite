import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2];if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/script-floating-core',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Preserve previous evidence');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),seen=new Set(),inputs=[];
function collect(file){if(seen.has(file))return;seen.add(file);const bytes=fs.readFileSync(path.join(project,file));inputs.push({path:file,sha256:hash(bytes)});if(/\.(gd|gdshader)$/.test(file))for(const m of bytes.toString().matchAll(/["']res:\/\/([^"'\r\n]+\.(?:gd|gdshader))["']/g))collect(m[1]);}
collect('tests/native_script_floating_core_test.gd');collect('tools/test-native-script-floating-core.mjs');for(const row of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(project,row.path),target);}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Native Script Floating Core Isolated"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected engine');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');console.log(JSON.stringify({stage:'copy-complete',inputs:inputs.length,report}));
const child=spawnSync(engine,['--headless','--max-fps','60','--path',copy,'--log-file',log,'--script','res://tests/native_script_floating_core_test.gd','--','--report='+report,'--install='+path.resolve(project,'../../FullDecomp/NwnRootInstall')],{windowsHide:true,encoding:'utf8',timeout:65000});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,body=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+child.stderr;
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(body),changedInputs=inputs.filter(row=>hash(fs.readFileSync(path.join(project,row.path)))!==row.sha256).map(x=>x.path),changedCopies=inputs.filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(x=>x.path);
const proof={success:child.status===0&&!child.error&&result?.success===true&&cleanEngine&&!changedInputs.length&&!changedCopies.length,checks:result?.checks??0,failures:result?.failures??[],cleanEngine,exitCode:child.status,error:child.error?.message??null,inputs,changedInputs,changedCopies,engineSha256,gpu:false,serverConnections:0,nativeBuilds:0,productionImported:false,scope:result?.scope??'No accepted result.'};fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.length}));process.exitCode=proof.success?0:1;
