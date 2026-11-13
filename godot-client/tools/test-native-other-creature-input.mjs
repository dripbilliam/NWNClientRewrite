// Copied, source-pinned normal target input/identity/native-oracle CPU suite.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const run=path.join(project,'.cache','other-creature-input-tests',new Date().toISOString().replace(/[-:.TZ]/g,'')+'-'+crypto.randomUUID().slice(0,8)),copy=path.join(run,'inputs');fs.mkdirSync(copy,{recursive:true});
const hash=value=>crypto.createHash('sha256').update(value).digest('hex'),inputs=new Map();
function include(filename){
 filename=path.resolve(filename);if(inputs.has(filename))return;
 if(!filename.startsWith(root+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(filename),text=bytes.toString('utf8');inputs.set(filename,{path:path.relative(root,filename).replaceAll('\\','/'),sha256:hash(bytes)});
 if(filename.endsWith('.gd')){
  for(const match of text.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of text.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
 }else if(/\.(?:m?js|cjs)$/.test(filename))for(const match of text.matchAll(/(?:from\s*|import\s*\(?\s*)["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(filename),match[1]));
}
const cases=['native_other_creature_radial_test.gd','native_other_creature_input_test.gd','native_world_radial_input_test.gd','native_player_identity_test.gd','native_world_radial_probe_compile_test.gd'];
for(const name of cases)include(path.join(project,'tests',name));
for(const file of ['package.json','godot-client/reports/native-other-creature-radial-original-v1.json','godot-client/reports/native-dm-permission-original-v1.json','godot-client/reports/native-skill-admission-original-v1.json','godot-client/reports/native-connection-permission-start-original-v1.json','test/native-player-roster.test.js','test/native-dm-permission.test.js','test/native-skill-admission.test.js','test/network-control-identity.test.js','godot-client/tests/native_player_identity_fixture.mjs','godot-client/tools/native-session-host.cjs'])include(path.join(root,file));
include(fileURLToPath(import.meta.url));
for(const [file,row]of inputs){const dest=path.join(copy,row.path);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(file,dest);if(hash(fs.readFileSync(dest))!==row.sha256)throw Error('Source changed during copy: '+row.path);}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Normal Creature Input"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools','Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing runtime');
const fixture=path.join(run,'host-fixture.json'),generated=spawnSync(process.execPath,[path.join(copiedProject,'tests/native_player_identity_fixture.mjs'),'--report='+fixture],{cwd:copy,windowsHide:true,timeout:15000,encoding:'utf8'});
fs.writeFileSync(path.join(run,'fixture.stdout.log'),generated.stdout??'');fs.writeFileSync(path.join(run,'fixture.stderr.log'),generated.stderr??'');
if(generated.status!==0||generated.error)throw Error('Owned typed Session/World/host fixture failed; finite logs retained');
const results=[];
for(const script of cases){
 const name=script.slice(0,-3),report=path.join(run,name+'.json'),log=path.join(run,name+'.engine.log');
 const process=spawnSync(engine,['--headless','--path',copiedProject,'--log-file',log,'--script','res://tests/'+script,'--','--report='+report,'--fixture='+fixture,'--oracle='+path.join(copiedProject,'reports/native-other-creature-radial-original-v1.json')],{windowsHide:true,timeout:15000,encoding:'utf8'});
 fs.writeFileSync(path.join(run,name+'.stdout.log'),process.stdout??'');fs.writeFileSync(path.join(run,name+'.stderr.log'),process.stderr??'');
 const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+process.stderr);
 results.push({name,success:process.status===0&&!process.error&&cleanEngine&&result?.success===true,checks:result?.checks??0,report:path.relative(root,report),cleanEngine,exitCode:process.status,error:process.error?.message??null});if(!results.at(-1).success)break;
}
const node=spawnSync(process.execPath,['--test',...['native-player-roster.test.js','native-dm-permission.test.js','native-skill-admission.test.js','network-control-identity.test.js'].map(file=>path.join(copy,'test',file))],{cwd:copy,windowsHide:true,timeout:15000,encoding:'utf8'});
fs.writeFileSync(path.join(run,'node.tap'),node.stdout??'');fs.writeFileSync(path.join(run,'node.stderr.log'),node.stderr??'');
const nodeTests=Number(node.stdout?.match(/^# tests (\d+)/m)?.[1]??0),nodePass=node.status===0&&!node.error&&/^# fail 0$/m.test(node.stdout??'');
const changedInputs=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const receipt={success:results.length===cases.length&&results.every(row=>row.success)&&nodePass&&changedInputs.length===0,results,nodeTests,nodePass,changedInputs,inputs:[...inputs.values()],directory:run,engineSha256,gpu:false,publicConnections:0,serverConnections:0,nativeBuilds:0,scope:'Current copied normal target policy versus2304 complete original fixtures; actual native Desktop/ServerRadial/Quickbar pointer, drag, disclosure lifetime; original self31 and typed Session/World/host identity pipeline. Authored pointer state is not an original-server gameplay outcome or pixel/performance benchmark.'};
fs.writeFileSync(path.join(run,'runner.json'),JSON.stringify(receipt,null,2)+'\n');if(receipt.success)fs.writeFileSync(path.join(project,'reports/native-other-creature-input-v1-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({success:receipt.success,results,nodeTests,nodePass,changedInputs,directory:run}));process.exitCode=receipt.success?0:1;
