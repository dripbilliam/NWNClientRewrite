// Owned Session/World/host/native typed player-context pipeline. No network/GPU.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const run=path.join(project,'.cache','player-identity-tests',new Date().toISOString().replace(/[-:.TZ]/g,'')+'-'+crypto.randomUUID().slice(0,8));
const copy=path.join(run,'inputs');fs.mkdirSync(copy,{recursive:true});
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const files=new Map();
function include(filename){
 filename=path.resolve(filename);if(files.has(filename))return;
 if(!filename.startsWith(root+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(filename);files.set(filename,{path:path.relative(root,filename).replaceAll('\\','/'),sha256:hash(bytes)});
 const source=bytes.toString('utf8');
 if(filename.endsWith('.gd')){
  for(const match of source.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
  for(const match of source.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));
 }else if(/\.(?:m?js|cjs)$/.test(filename)){
  for(const match of source.matchAll(/(?:from\s*|import\s*\(?\s*)["'](\.[^"']+)["']/g))include(path.resolve(path.dirname(filename),match[1]));
 }
}
const tests=['native_player_identity_test.gd','native_player_context_gameplay_test.gd'];
for(const test of tests)include(path.join(project,'tests',test));
include(path.join(project,'systems/native_data/feedback_descriptors.json'));
for(const filename of ['package.json','test/native-player-roster.test.js','test/native-dm-permission.test.js','test/native-skill-admission.test.js','test/network-control-identity.test.js','godot-client/tests/native_player_identity_fixture.mjs','godot-client/tools/native-session-host.cjs','godot-client/reports/native-dm-permission-original-v1.json','godot-client/reports/native-skill-admission-original-v1.json','godot-client/reports/native-connection-permission-start-original-v1.json'])include(path.join(root,filename));
include(fileURLToPath(import.meta.url));
for(const [filename,row]of files){const dest=path.join(copy,row.path);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(filename,dest);if(hash(fs.readFileSync(dest))!==row.sha256)throw Error('Input changed during copy: '+row.path);}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Native Skill Count"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const godot=path.join(project,'.tools','Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));
if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unapproved existing Godot runtime');
const results=[];
const fixture=path.join(run,'host-fixture.json');
const generate=spawnSync(process.execPath,[path.join(copiedProject,'tests/native_player_identity_fixture.mjs'),'--report='+fixture],{cwd:copy,windowsHide:true,timeout:15000,encoding:'utf8'});
fs.writeFileSync(path.join(run,'fixture.stdout.log'),generate.stdout??'');fs.writeFileSync(path.join(run,'fixture.stderr.log'),generate.stderr??'');
if(generate.status!==0||generate.error)throw Error('Owned Session/World/host fixture failed; finite logs retained');
for(const test of tests){
 const name=test.replace('.gd',''),report=path.join(run,name+'.json'),log=path.join(run,name+'.engine.log');
 const result=spawnSync(godot,['--headless','--path',copiedProject,'--log-file',log,'--script','res://tests/'+test,'--','--report='+report,'--fixture='+fixture],{windowsHide:true,timeout:15000,encoding:'utf8'});
 fs.writeFileSync(path.join(run,name+'.stdout.log'),result.stdout??'');fs.writeFileSync(path.join(run,name+'.stderr.log'),result.stderr??'');
 const data=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+result.stderr);
 results.push({name,success:result.status===0&&!result.error&&clean&&data?.success===true,checks:data?.checks??0,report:path.relative(root,report),cleanEngine:clean,exitCode:result.status,error:result.error?.message??null});
 if(!results.at(-1).success)break;
}
const protocol=spawnSync(process.execPath,['--test',path.join(copy,'test/native-player-roster.test.js'),path.join(copy,'test/native-dm-permission.test.js'),path.join(copy,'test/native-skill-admission.test.js'),path.join(copy,'test/network-control-identity.test.js')],{cwd:copy,windowsHide:true,timeout:15000,encoding:'utf8'});
fs.writeFileSync(path.join(run,'protocol.tap'),protocol.stdout??'');fs.writeFileSync(path.join(run,'protocol.stderr.log'),protocol.stderr??'');
const nodeTests=Number(protocol.stdout?.match(/^# tests (\d+)/m)?.[1]??0),nodePass=protocol.status===0&&!protocol.error&&/^# fail 0$/m.test(protocol.stdout??'');
const changed=[...files].filter(([filename,row])=>hash(fs.readFileSync(filename))!==row.sha256).map(([,row])=>row.path);
const receipt={success:results.length===tests.length&&results.every(row=>row.success)&&nodePass&&changed.length===0,results,nodeTests,nodePass,nodeExitCode:protocol.status,changedInputs:changed,inputs:[...files.values()],engineSha256,directory:run,fixture,gpu:false,publicConnections:0,serverConnections:0,nativeBuilds:0,scope:'Actual in-memory installed-shape Session.connect/typed player-list+31/22 decoder/World/canonical host header through actual Gameplay full/delta forwarding into native typed permission+selected identity admission, plus current rollback/control/skill/permission regressions. No Desktop command/server/DM update/pixel/GPU outcome.'};
fs.writeFileSync(path.join(run,'runner.json'),JSON.stringify(receipt,null,2)+'\n');
if(receipt.success)fs.writeFileSync(path.join(project,'reports/native-player-identity-v1-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({success:receipt.success,directory:run,results,nodeTests,nodePass,changedInputs:changed}));
process.exitCode=receipt.success?0:1;
