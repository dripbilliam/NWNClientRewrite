import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/level-up-reply-scope',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=data=>crypto.createHash('sha256').update(data).digest('hex'),inputs=[];
for(const file of ['systems/native_data/level_up_reply_scope.gd','tests/native_level_up_reply_scope_test.gd','tools/test-native-level-up-reply-scope.mjs']){
 const source=path.join(project,file),bytes=fs.readFileSync(source),target=path.join(copy,file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);inputs.push({file,sha256:hash(bytes)});
}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Level Up Reply Scope"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing engine');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const child=spawnSync(engine,['--headless','--max-fps','60','--path',copy,'--log-file',log,'--script','res://tests/native_level_up_reply_scope_test.gd','--','--report='+report],{windowsHide:true,timeout:20000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+child.stderr);
const changedInputs=inputs.filter(row=>hash(fs.readFileSync(path.join(project,row.file)))!==row.sha256||hash(fs.readFileSync(path.join(copy,row.file)))!==row.sha256).map(row=>row.file);
const proof={success:child.status===0&&!child.error&&cleanEngine&&result?.success===true&&!changedInputs.length,checks:result?.checks??0,failures:result?.failures??[],directory,exitCode:child.status,error:child.error?.message??null,cleanEngine,engineSha256,inputs,changedInputs,productionIntegrated:false,serverConnections:0,gpu:false,nativeBuilds:0,scope:result?.scope??'No native result'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.length,failures:proof.failures.length}));process.exitCode=proof.success?0:1;
