import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project),label=process.argv[2],hash=value=>crypto.createHash('sha256').update(value).digest('hex');
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/quickbar-associate-model',label),copy=path.join(directory,'inputs'),oracle='godot-client/.cache/quickbar-associate-cpu/original-v1/result.json';
if(fs.existsSync(directory))throw Error('Existing evidence retained');
const sources=['godot-client/tests/native_quickbar_associate_commands_test.gd','godot-client/systems/native_data/quickbar_associate_commands.gd','godot-client/tools/test-native-quickbar-associate-commands.mjs',oracle];
const original=JSON.parse(fs.readFileSync(path.join(root,oracle),'utf8'));if(!original.success||original.cases.length!==28)throw Error('Complete current original oracle required');
for(const item of original.sources){if(hash(fs.readFileSync(path.join(root,item.path)))!==item.sha256)throw Error('Original oracle source changed');sources.push(item.path);}
const inputs=[...new Set(sources)].map(name=>({path:name,sha256:hash(fs.readFileSync(path.join(root,name)))}));
for(const row of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(root,row.path),target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed during copy');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Associate Commands Policy"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected pinned engine');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const child=spawnSync(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_quickbar_associate_commands_test.gd','--','--report='+report,'--oracle='+path.join(copy,oracle)],{windowsHide:true,timeout:35000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+child.stderr);
const changed=inputs.filter(row=>hash(fs.readFileSync(path.join(root,row.path)))!==row.sha256).map(row=>row.path);
const proof={success:child.status===0&&!child.error&&clean&&result?.success===true&&!changed.length,checks:result?.checks??0,failures:result?.failures??[],cleanEngine:clean,exitCode:child.status,error:child.error?.message??null,changedInputs:changed,inputs,engineSha256,serverConnections:0,gpu:false,nativeBuilds:0,scope:result?.scope};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.length}));process.exitCode=proof.success?0:1;
