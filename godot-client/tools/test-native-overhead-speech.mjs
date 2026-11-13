import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {receivedSpeechFixture} from './native-overhead-received-fixture.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),label=process.argv[2];
if(!/^[a-z0-9-]{3,80}$/.test(label??''))throw Error('Supply a unique evidence label');
const directory=path.join(project,'.cache/overhead-speech',label),copy=path.join(directory,'inputs');
if(fs.existsSync(directory))throw Error('Existing evidence preserved');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),seen=new Set(),files=[];
function collect(file){if(seen.has(file))return;seen.add(file);const source=fs.readFileSync(path.join(project,file));files.push({path:file,sha256:hash(source)});if(/\.(gd|gdshader)$/.test(file))for(const match of source.toString().matchAll(/["']res:\/\/([^"'\r\n]+\.(?:gd|gdshader))["']/g))collect(match[1]);}
collect('tests/native_overhead_speech_test.gd');collect('tools/test-native-overhead-speech.mjs');
for(const file of ['tools/native-overhead-received-fixture.mjs','tools/native-session-host.cjs','tools/native-text-event-scope.cjs','tools/raw-combat-events.cjs'])collect(file);
const externalInputs=[],externalSeen=new Set();
function external(file){file=path.resolve(file);if(externalSeen.has(file))return;externalSeen.add(file);const bytes=fs.readFileSync(file);externalInputs.push({path:file,sha256:hash(bytes)});if(!/\.(?:js|mjs|cjs)$/.test(file))return;for(const match of bytes.toString().matchAll(/(?:from\s*|require\(\s*|import\s*)["'](\.[^"']+)["']/g)){let target=path.resolve(path.dirname(file),match[1]);if(!fs.existsSync(target)&&fs.existsSync(target+'.js'))target+='.js';if(fs.existsSync(target)&&fs.statSync(target).isFile())external(target);}}
external(path.join(project,'tools/native-overhead-received-fixture.mjs'));external(path.join(project,'tools/native-session-host.cjs'));external(path.join(project,'tools/native-text-event-scope.cjs'));external(path.join(project,'tools/raw-combat-events.cjs'));
const fixture=receivedSpeechFixture({contextAvailable:false});
for(const row of fixture.provenance.originalFiles)external(path.resolve(project,'..',row.path));
for(const row of files){const target=path.join(copy,row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(project,row.path),target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Copy mismatch');}
fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Native Overhead Speech"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=hash(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Unexpected engine');
const report=path.join(directory,'result.json'),log=path.join(directory,'engine.log'),install=path.resolve(project,'../../FullDecomp/NwnRootInstall');
const fixturePath=path.join(directory,'fixture.json');fs.writeFileSync(fixturePath,JSON.stringify(fixture,null,2)+'\n');const fixtureSha256=hash(fs.readFileSync(fixturePath));
console.log(JSON.stringify({stage:'copy-complete',inputs:files.length,report}));
const child=spawnSync(engine,['--headless','--max-fps','60','--path',copy,'--log-file',log,'--script','res://tests/native_overhead_speech_test.gd','--','--report='+report,'--install='+install,'--fixture='+fixturePath],{windowsHide:true,encoding:'utf8',timeout:65000});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,engineLog=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'';
const cleanEngine=!/^(?:ERROR:|WARNING:)|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit/m.test(engineLog+'\n'+child.stderr),changedInputs=files.filter(row=>hash(fs.readFileSync(path.join(project,row.path)))!==row.sha256).map(row=>row.path),changedCopies=files.filter(row=>hash(fs.readFileSync(path.join(copy,row.path)))!==row.sha256).map(row=>row.path);
const changedExternal=externalInputs.filter(row=>hash(fs.readFileSync(row.path))!==row.sha256).map(row=>row.path),fixtureUnchanged=hash(fs.readFileSync(fixturePath))===fixtureSha256;
const proof={success:child.status===0&&!child.error&&cleanEngine&&result?.success===true&&!changedInputs.length&&!changedCopies.length&&!changedExternal.length&&fixtureUnchanged,checks:result?.checks??0,failures:result?.failures??[],cleanEngine,exitCode:child.status,error:child.error?.message??null,inputs:files,externalInputs,changedInputs,changedCopies,changedExternal,fixtureUnchanged,fixtureSha256,engineSha256,gpu:false,serverConnections:0,nativeBuilds:0,productionImported:false,scope:result?.scope??'No accepted result.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:files.length,externalInputs:externalInputs.length}));process.exitCode=proof.success?0:1;
