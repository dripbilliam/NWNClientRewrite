// Independent normal-target policy CPU test. No Desktop/runtime selector bound.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const run=path.join(project,'.cache','other-creature-radial-tests',new Date().toISOString().replace(/[-:.TZ]/g,'')+'-'+crypto.randomUUID().slice(0,8));
const copy=path.join(run,'project'),hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
fs.mkdirSync(copy,{recursive:true});
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;
 if(!file.startsWith(project+path.sep))throw Error('Input escapes native project');
 const bytes=fs.readFileSync(file),relative=path.relative(project,file).replaceAll('\\','/');inputs.set(file,{path:relative,sha256:hash(bytes)});
 if(file.endsWith('.gd'))for(const match of bytes.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
}
for(const file of ['tests/native_other_creature_radial_test.gd','reports/native-other-creature-radial-original-v1.json','tools/test-native-other-creature-radial.mjs'])include(path.join(project,file));
for(const[file,row]of inputs){const destination=path.join(copy,row.path);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(file,destination);if(hash(fs.readFileSync(destination))!==row.sha256)throw Error('Source changed during copy');}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Other Creature Policy"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const godot=path.join(project,'.tools','Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unapproved existing runtime');
const report=path.join(run,'policy.json'),log=path.join(run,'engine.log');
const processResult=spawnSync(godot,['--headless','--path',copy,'--log-file',log,'--script','res://tests/native_other_creature_radial_test.gd','--','--report='+report,'--oracle='+path.join(copy,'reports/native-other-creature-radial-original-v1.json')],{windowsHide:true,timeout:15000,encoding:'utf8'});
fs.writeFileSync(path.join(run,'stdout.log'),processResult.stdout??'');fs.writeFileSync(path.join(run,'stderr.log'),processResult.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engine+'\n'+processResult.stderr);
const changedInputs=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const receipt={success:processResult.status===0&&!processResult.error&&cleanEngine&&result?.success===true&&changedInputs.length===0,directory:run,checks:result?.checks??0,cleanEngine,changedInputs,inputs:[...inputs.values()],engineSha256,exitCode:processResult.status,error:processResult.error?.message??null,publicConnections:0,serverConnections:0,nativeBuilds:0,gpu:false,scope:'Independent normal993790 projection versus2304 unchanged original captured-service fixtures and explicit unknowns. No active Desktop/selector/missing-DM/party binding or server/pixel acceptance.'};
fs.writeFileSync(path.join(run,'runner.json'),JSON.stringify(receipt,null,2)+'\n');
if(receipt.success)fs.writeFileSync(path.join(project,'reports/native-other-creature-policy-v1-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({success:receipt.success,directory:run,checks:receipt.checks,cleanEngine,exitCode:processResult.status,error:receipt.error,changedInputs}));process.exitCode=receipt.success?0:1;
