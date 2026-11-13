import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),workspace=path.dirname(project);
const run=process.argv[2];if(!/^[a-z0-9-]{3,80}$/.test(run??''))throw Error('Supply unique evidence label');
const directory=path.join(project,'.cache/npc-combat-source',run),copy=path.join(directory,'inputs');if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(workspace+path.sep))throw Error('Input outside workspace');const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(workspace,file).replaceAll('\\','/'),sha256:hash(bytes)});if(file.endsWith('.gd')){const source=bytes.toString();for(const match of source.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));for(const match of source.matchAll(/extends\s+["']res:\/\/([^"']+)["']/g))include(path.join(project,match[1]));}}
for(const relative of ['tests/native_npc_combat_probe_compile_test.gd','tests/native_combat_probe_compile_test.gd','tests/native_npc_combat_server_fixture.mjs','tools/native-npc-combat-proof.cjs','tools/native-npc-combat-character.cjs','tools/native-combat-check-lifecycle.cjs','tools/native-session-host.cjs','tools/native-actions-fixture.mjs','tools/test-native-actions.ps1','join-native.ps1','../test/native-npc-combat-proof.test.js','../test/native-npc-combat-character.test.js','../test/native-combat-check-lifecycle.test.js','../package.json'])include(path.join(project,relative));
include(fileURLToPath(import.meta.url));
for(const [file,row]of inputs){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Input changed during copy');}
const copiedProject=path.join(copy,'godot-client');fs.writeFileSync(path.join(copiedProject,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned NPC Combat Source"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const godot=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(godot));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected existing Godot');
const cases=[];
for(const script of ['native_npc_combat_probe_compile_test.gd','native_combat_probe_compile_test.gd']){
 const name=script.replace('.gd',''),report=path.join(directory,name+'.json'),log=path.join(directory,name+'.engine.log');
 const child=spawnSync(godot,['--headless','--max-fps','60','--path',copiedProject,'--log-file',log,'--script','res://tests/'+script,'--','--report='+report],{windowsHide:true,timeout:35000,encoding:'utf8'});
 fs.writeFileSync(path.join(directory,name+'.stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,name+'.stderr.log'),child.stderr??'');
 const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
 const clean=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engine+'\n'+child.stderr);
 cases.push({success:child.status===0&&!child.error&&clean&&result?.success===true,checks:result?.checks??0,failures:result?.failures??[],report,log,cleanEngine:clean,exitCode:child.status,error:child.error?.message??null});if(!cases.at(-1).success)break;
}
const protocol=spawnSync(process.execPath,['--test',path.join(copy,'test/native-npc-combat-proof.test.js'),path.join(copy,'test/native-npc-combat-character.test.js'),path.join(copy,'test/native-combat-check-lifecycle.test.js')],{windowsHide:true,timeout:15000,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'policy.tap'),protocol.stdout??'');fs.writeFileSync(path.join(directory,'policy.stderr.log'),protocol.stderr??'');
const protocolChecks=Number(protocol.stdout?.match(/^# tests (\d+)$/m)?.[1]??0),policyClean=protocol.status===0&&!protocol.error&&/^# fail 0$/m.test(protocol.stdout??'');
const syntax=spawnSync(process.execPath,['--check',path.join(copiedProject,'tools/native-session-host.cjs')],{windowsHide:true,timeout:5000,encoding:'utf8'});fs.writeFileSync(path.join(directory,'host-syntax.log'),(syntax.stdout??'')+(syntax.stderr??''));
const changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path),copyChanged=[...inputs.values()].filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path);
const proof={success:cases.length===2&&cases.every(row=>row.success)&&policyClean&&syntax.status===0&&!syntax.error&&changed.length===0&&copyChanged.length===0,directory,cases,protocolChecks,protocolExitCode:protocol.status,hostSyntaxExitCode:syntax.status,checks:cases.reduce((sum,row)=>sum+row.checks,0)+protocolChecks,inputs:[...inputs.values()],changedInputs:changed,changedCopiedInputs:copyChanged,engineSha256,nativeBuilds:0,gpu:false,serverConnections:0,serverOutcomeAccepted:false,scope:'Actual source NPC and prior PC dispatcher/probe compilation, retired-owner guards and strict original-server evidence policy. No NPC game/session outcome is inferred from these copied tests.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:proof.inputs.length}));process.exitCode=proof.success?0:1;
