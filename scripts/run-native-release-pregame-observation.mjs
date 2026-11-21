// One reviewed editor-only observation. Original stage/package/assertions retained.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {workspace,project,parityRoot,record,inside} from './native-release-functional-lib.mjs';
import {json,unchanged,childEnvironment,cleanEngine} from './native-startup-experiment-lib.mjs';
import {functionalArguments} from './run-native-release-functional-v2.mjs';

assert.equal(process.argv[2],'--execute-approved');assert.equal(process.argv[3],'root-approved-observation-v1');
const directory=path.join(parityRoot,'release-functional-v1'),stage=JSON.parse(fs.readFileSync(path.join(directory,'stage.json')));
assert.equal(stage.sourceSignature,'19e4f9fb0bbb10d410b2f0aacab5f367a03d03cd10320aa3b0c1f3d1ea202d0d');
const evidence=path.join(directory,'observation-root-approved-v1');assert.ok(!fs.existsSync(evidence));fs.mkdirSync(evidence);
const relative='tests/native_release_pregame_observation_test.gd',source=path.join(project,relative),copy=inside(stage.copy,path.join(stage.copy,relative));assert.ok(!fs.existsSync(copy));fs.copyFileSync(source,copy);assert.equal(record(source).sha256,record(copy).sha256);
const tools=[record(source),record(fileURLToPath(import.meta.url)),record(path.join(workspace,'scripts/run-native-release-functional-v2.mjs'))];
const mandatory=[...stage.extraInputs,...stage.nativeInputs,...Object.values(stage.engines),...stage.dataProvenance,...stage.fixed.filter(row=>row.path.startsWith('godot-client/.cache/cached-warlock-creation/'))];assert.deepEqual(unchanged(mandatory),[]);
const originalSourceChangesSinceStage=unchanged(stage.sourceInputs),guards=[...stage.fixed.map(row=>record(path.join(workspace,row.path))),...tools];
const packFile=path.join(stage.packageDirectory,'NwnReleaseTest.pck');assert.equal(record(packFile).sha256,'2a81dca9ecd86ec69983be7cd79a6fcd0df1fe13ebe4ef05648cd296e1be5007');
const fixedCopy=[...stage.copied,{file:copy,sha256:record(copy).sha256},...[packFile,path.join(stage.packageDirectory,'pack.json'),path.join(stage.packageDirectory,'runtime.json')].map(file=>({file,sha256:record(file).sha256}))];
const changedCopy=()=>fixedCopy.filter(row=>record(row.file).sha256!==row.sha256).map(row=>row.file);
assert.deepEqual(changedCopy(),[]);const {args,report,log}=functionalArguments('editor',{script:relative,args:[]},stage,evidence,path.resolve(workspace,'../FullDecomp/NwnRootInstall'));
const executable=path.join(stage.copy,'.tools/Godot_v4.7.2-stable_win64.exe'),env=childEnvironment(evidence),child=spawn(executable,args,{cwd:evidence,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
const chunks={stdout:[],stderr:[]};let stopped=false,timeout=false,error=null,count=0;
function stop(){if(!stopped){stopped=true;child.kill();}}
for(const stream of ['stdout','stderr'])child[stream].on('data',value=>{chunks[stream].push(value);count+=value.length;if(count>8*1024*1024)stop();if(!cleanEngine(value.toString('utf8')))stop();});
const timer=setTimeout(()=>{timeout=true;stop();},65000);const exit=await new Promise(resolve=>{child.on('error',value=>{error=value.message;});child.on('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal});});});
const stdout=Buffer.concat(chunks.stdout).toString('utf8'),stderr=Buffer.concat(chunks.stderr).toString('utf8');fs.writeFileSync(path.join(evidence,'stdout.log'),stdout);fs.writeFileSync(path.join(evidence,'stderr.log'),stderr);
const engine=fs.existsSync(log)?fs.readFileSync(log,'utf8'):'ERROR: missing engine log',value=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,observations=fs.existsSync(report+'.observation.json')?JSON.parse(fs.readFileSync(report+'.observation.json')):null;
const changedInputs=unchanged(guards),changedCopied=changedCopy(),clean=cleanEngine(stdout+'\n'+stderr+'\n'+engine);
const target=observations?.events.find(event=>event.description==='Physical Internet action reaches native list using an authored received view');
const reproduced=value?.success===false&&value.checks===4&&JSON.stringify(value.failures)==='["Physical Internet action reaches native list using an authored received view"]';
const diagnosticCompleted=clean&&!timeout&&!stopped&&!error&&!changedInputs.length&&!changedCopied.length&&!!target&&(reproduced&&exit.code===1||value?.success===true&&exit.code===0);
const result={diagnosticCompleted,baselineAccepted:value?.success===true,baselineReproduced:reproduced,sourceRevision:stage.sourceSignature,originalSourceChangesSinceStage,pid:child.pid,...exit,error,timeout,stopped,cleanEngine:clean,ownedProcessClosed:true,changedInputs,changedCopied,tools,args,target:target??null,observation:report+'.observation.json',releaseCases:0,assertionsChanged:0,waitsChanged:0,productChanges:0,packageRewrites:0,networkSessions:0,keyAccess:0,gpu:false};
json(path.join(evidence,'runner.json'),result);console.log(JSON.stringify(result));process.exitCode=diagnosticCompleted?0:1;
