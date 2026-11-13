import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/level-up-rule-publication',label),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input leaves workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd')){for(const match of bytes.toString().matchAll(/(?:preload|load)\s*\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));for(const match of bytes.toString().matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));}
}
include(path.join(project,'tests/native_level_up_rule_publication_test.gd'));include(path.join(project,'reports/native-legacy-class-defaults-original-v1.json'));include(fileURLToPath(import.meta.url));
for(const[file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed while copied');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Mode1 Class Rules"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing Godot runtime');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log');
const child=spawnSync(engine,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/native_level_up_rule_publication_test.gd','--','--report='+report,'--install='+path.resolve(workspace,'../FullDecomp/NwnRootInstall'),'--oracle=res://reports/native-legacy-class-defaults-original-v1.json'],{windowsHide:true,timeout:35000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+child.stderr);
const changedInputs=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path),changedCopies=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path);
const proof={success:child.status===0&&!child.error&&cleanEngine&&result?.success===true&&!changedInputs.length&&!changedCopies.length,checks:result?.checks??0,failures:result?.failures??[],directory,cleanEngine,exitCode:child.status,error:child.error?.message??null,inputs:[...inputs.values()],changedInputs,changedCopies,engineSha256,gpu:false,serverConnections:0,nativeBuilds:0,scope:result?.scope??'No functional result.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:inputs.size}));process.exitCode=proof.success?0:1;
