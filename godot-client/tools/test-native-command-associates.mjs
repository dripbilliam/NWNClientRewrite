import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const run=path.join(project,'.cache','staged-command-associates',new Date().toISOString().replace(/[-:.TZ]/g,'')+'-'+crypto.randomUUID().slice(0,8)),copy=path.join(run,'inputs');fs.mkdirSync(copy,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(root+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(file),text=bytes.toString('utf8');inputs.set(file,{path:path.relative(root,file).replaceAll('\\','/'),sha256:hash(bytes)});
 if(file.endsWith('.gd')){
  for(const match of text.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of text.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
 }else if(/\.(?:m?js|cjs)$/.test(file))for(const match of text.matchAll(/(?:from\s*|import\s*\(?\s*)["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(file),match[1]));
}
const cases=['native_command_associates_test.gd','native_command_associate_input_test.gd'];for(const name of cases)include(path.join(project,'tests',name));
for(const file of ['godot-client/tests/native_command_associate_transport.mjs','package.json','godot-client/reports/native-command-associate-original-v1.json','godot-client/reports/native-command-associate-original-v2.json','scripts/inspect-native-command-associate-menu.py','scripts/inspect-native-command-associate-menu-v2.py'])include(path.join(root,file));include(fileURLToPath(import.meta.url));
for(const[file,row]of inputs){const destination=path.join(copy,row.path);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(file,destination);if(hash(fs.readFileSync(destination))!==row.sha256)throw Error('Input changed during copy');}
const copied=path.join(copy,'godot-client');fs.writeFileSync(path.join(copied,'project.godot'),'config_version=5\n[application]\nconfig/name="Staged Commands Only"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing runtime');
const results=[];
for(const script of cases){
 const report=path.join(run,script+'.json'),log=path.join(run,script+'.engine.log');
 const child=spawnSync(engine,['--headless','--path',copied,'--log-file',log,'--script','res://tests/'+script,'--','--report='+report,...[1,2].map(v=>'--oracle='+path.join(copied,'reports/native-command-associate-original-v'+v+'.json'))],{windowsHide:true,timeout:35000,encoding:'utf8',maxBuffer:4*1024*1024});
 fs.writeFileSync(path.join(run,script+'.stdout.log'),child.stdout??'');fs.writeFileSync(path.join(run,script+'.stderr.log'),child.stderr??'');
 const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,logText=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(logText+'\n'+child.stderr);
 results.push({script,success:child.status===0&&!child.error&&cleanEngine&&result?.success===true,checks:result?.checks??0,cleanEngine,exitCode:child.status,error:child.error?.message??null,report});if(!results.at(-1).success)break;
}
let transport=null;
if(results.length===cases.length&&results.every(row=>row.success)){
 const report=path.join(run,'transport.json'),child=spawnSync(process.execPath,[path.join(copied,'tests/native_command_associate_transport.mjs'),'--fixture='+results[1].report,'--report='+report],{cwd:copy,windowsHide:true,timeout:10000,encoding:'utf8'});
 fs.writeFileSync(path.join(run,'transport.stdout.log'),child.stdout??'');fs.writeFileSync(path.join(run,'transport.stderr.log'),child.stderr??'');const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null;
 transport={success:child.status===0&&!child.error&&result?.success===true,checks:result?.checks??0,report,exitCode:child.status};
}
const changedInputs=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const receipt={success:results.length===cases.length&&results.every(row=>row.success)&&transport?.success===true&&!changedInputs.length,results,transport,changedInputs,inputs:[...inputs.values()],directory:run,engineSha256,productionIntegrated:false,publicConnections:0,serverConnections:0,nativeBuilds:0,gpu:false,userProcessActions:0};
fs.writeFileSync(path.join(run,'runner.json'),JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify({...receipt,inputs:inputs.size}));process.exitCode=receipt.success?0:1;
