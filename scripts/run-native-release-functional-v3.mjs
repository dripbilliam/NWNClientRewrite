// New initial-readiness fixture overlay. Old snapshots, rejections and packages
// are retained. Existing canonical packer/bootstrap/selector remain unchanged.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {workspace,project,parityRoot,record,inside,sha,normalizePregame,validateBic} from './native-release-functional-lib.mjs';
import {safeName,json,unchanged,cleanEngine,childEnvironment,inspectPack} from './native-startup-experiment-lib.mjs';
import {functionalArguments} from './run-native-release-functional-v2.mjs';

export function verifyFixtureOverlay(previous,next,allowed){
 const allowedMap=new Map(allowed.map(row=>[row.relative,row.sha256]));
 for(const [name,row]of previous.entries)assert.equal(next.entries.get(name)?.sha256,row.sha256,'Existing canonical payload changed: '+name);
 const added=[...next.entries].filter(([name])=>!previous.entries.has(name));
 assert.deepEqual(added.map(([name])=>name).sort(),[...allowedMap.keys()].sort(),'Unexpected additional pack payload');
 for(const [name,row]of added)assert.equal(row.sha256,allowedMap.get(name));
 return{commonPayloadsUnchanged:previous.entries.size,added:added.map(([name,row])=>({relative:name,sha256:row.sha256}))};
}
export async function main(argv){
 const [mode,label,lane]=argv;assert.equal(mode,'--execute-approved');safeName(label);safeName(lane);
 const directory=inside(parityRoot,path.join(parityRoot,label)),stageFile=path.join(directory,'stage.json'),stage=JSON.parse(fs.readFileSync(stageFile));
 assert.equal(stage.sourceSignature,'19e4f9fb0bbb10d410b2f0aacab5f367a03d03cd10320aa3b0c1f3d1ea202d0d');
 const evidence=path.join(directory,'execution-'+lane);assert.ok(!fs.existsSync(evidence));fs.mkdirSync(evidence);
 const fixtureRelative='tests/native_release_initial_browser_gate_test.gd',source=path.join(project,fixtureRelative),destination=inside(stage.copy,path.join(stage.copy,fixtureRelative));
 assert.ok(!fs.existsSync(destination),'New overlay must not overwrite a prior source');fs.copyFileSync(source,destination);assert.equal(record(source).sha256,record(destination).sha256);
 const extraNames=['tests/native_release_pregame_observation_test.gd','tests/native_release_pregame_ready_observation_test.gd',fixtureRelative];
 const overlay=extraNames.map(relative=>({relative,file:path.join(stage.copy,relative),sha256:record(path.join(stage.copy,relative)).sha256}));
 const executionTools=[record(source),record(fileURLToPath(import.meta.url)),record(path.join(workspace,'scripts/tests/native-release-functional-v3.test.mjs')),record(path.join(workspace,'scripts/run-native-release-functional-v2.mjs'))];
 const mandatory=[...stage.extraInputs,...stage.nativeInputs,...Object.values(stage.engines),...stage.dataProvenance,...stage.fixed.filter(row=>row.path.startsWith('godot-client/.cache/cached-warlock-creation/'))];assert.deepEqual(unchanged(mandatory),[]);
 const originalSourceChangesSinceStage=unchanged(stage.sourceInputs),guards=[...stage.fixed.map(row=>record(path.join(workspace,row.path))),...executionTools];
 const generated=[],copied=[...stage.copied,...overlay];
 const changedOriginal=()=>unchanged(guards),changedCopy=()=>[...copied,...generated].filter(row=>record(row.file).sha256!==row.sha256).map(row=>row.file);
 assert.deepEqual(changedOriginal(),[]);assert.deepEqual(changedCopy(),[]);
 const attempts=[],results=[];let failure=null,packageRevision=null;
 async function launch(name,executable,args,capMs=65000){
  assert.deepEqual(changedOriginal(),[]);assert.deepEqual(changedCopy(),[]);const target=path.join(evidence,name);fs.mkdirSync(target);const env=childEnvironment(target),chunks={stdout:[],stderr:[]},live={stdout:'',stderr:''};
  let timeout=false,stopped=false,error=null,count=0;const child=spawn(executable,args,{cwd:target,env,windowsHide:true,stdio:['ignore','pipe','pipe']});const attempt={name,executable,executableSha256:record(executable).sha256,args,pid:child.pid??null,capMs};attempts.push(attempt);
  function stop(reason){if(!stopped){stopped=true;attempt.stopReason=reason;child.kill();}}
  for(const stream of ['stdout','stderr'])child[stream].on('data',value=>{count+=value.length;if(count>16*1024*1024){stop('output-cap');return;}chunks[stream].push(value);live[stream]=(live[stream]+value.toString('utf8')).slice(-65536);if(!cleanEngine(live[stream]))stop('engine-error-observed');});
  const timer=setTimeout(()=>{timeout=true;stop('owned-timeout');},capMs);const exit=await new Promise(resolve=>{child.on('error',value=>{error=value.message;});child.on('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal});});});
  const stdout=Buffer.concat(chunks.stdout).toString('utf8'),stderr=Buffer.concat(chunks.stderr).toString('utf8');fs.writeFileSync(path.join(target,'stdout.log'),stdout);fs.writeFileSync(path.join(target,'stderr.log'),stderr);
  const logFile=args[args.indexOf('--log-file')+1],text=fs.existsSync(logFile)?fs.readFileSync(logFile,'utf8'):'ERROR: missing engine log',clean=cleanEngine(stdout+'\n'+stderr+'\n'+text);
  const host={...attempt,...exit,error,timeout,stopped,cleanEngine:clean,ownedProcessClosed:true,changedOriginal:changedOriginal(),changedCopy:changedCopy()};json(path.join(target,'host.json'),host);
  assert.equal(exit.code,0,'Owned exit rejected '+name);assert.equal(error,null);assert.equal(timeout,false);assert.equal(stopped,false);assert.equal(clean,true);assert.deepEqual(host.changedOriginal,[]);assert.deepEqual(host.changedCopy,[]);return host;
 }
 try{
  const previousPackFile=path.join(stage.packageDirectory,'NwnReleaseTest.pck'),previous=inspectPack(previousPackFile);assert.equal(previous.sha256,'2a81dca9ecd86ec69983be7cd79a6fcd0df1fe13ebe4ef05648cd296e1be5007');generated.push({file:previousPackFile,sha256:previous.sha256});
  const packageSignature=sha(JSON.stringify({baseSourceRevision:stage.sourceSignature,fixtureOverlay:overlay.map(({relative,sha256})=>({relative,sha256}))}));
  const packageDirectory=path.join(stage.copy,'.cache/release-tests',packageSignature.slice(0,16),'project');assert.ok(!fs.existsSync(packageDirectory));fs.mkdirSync(packageDirectory,{recursive:true});
  const executable=path.join(packageDirectory,'NwnReleaseTest.exe');fs.copyFileSync(path.join(stage.copy,'.tools/windows_release_x86_64.exe'),executable);assert.equal(record(executable).sha256,stage.engines.release.sha256);
  const modeFile=path.join(packageDirectory,'.cache/native-window/nwn-window-modes.exe');fs.mkdirSync(path.dirname(modeFile),{recursive:true});fs.copyFileSync(path.join(stage.copy,'.cache/native-window/nwn-window-modes.exe'),modeFile);
  generated.push(...[executable,modeFile].map(file=>({file,sha256:record(file).sha256})));
  const packReport=path.join(packageDirectory,'pack.json'),packLog=path.join(evidence,'new-package.engine.log');
  await launch('normal-overlay-packer',path.join(stage.copy,'.tools/Godot_v4.7.2-stable_win64.exe'),['--headless','--path',stage.copy,'--log-file',packLog,'--script','res://tools/prepare-release-pack.gd','--','--directory='+packageDirectory,'--report='+packReport,'--entity-api-rest=false'],120000);
  const value=JSON.parse(fs.readFileSync(packReport));assert.equal(value.success,true);assert.deepEqual(value.errors,[]);assert.equal(value.original_game_assets_packed,false);
  const packFile=path.join(packageDirectory,'NwnReleaseTest.pck'),pack=inspectPack(packFile);assert.equal(pack.sha256,value.pack_sha256);const comparison=verifyFixtureOverlay(previous,pack,overlay);
  for(const row of value.source_files){assert.equal(record(path.join(stage.copy,row.path)).sha256,row.sha256);assert.equal(pack.entries.get(row.path)?.sha256,row.sha256);}
  const selectionFile=path.join(packageDirectory,'runtime.json');json(selectionFile,{kind:'native-release-package',executable,pack:packFile,receipt:packReport,directory:packageDirectory,sourceSignature:packageSignature,packSha256:pack.sha256,originalGameAssetsPacked:false,selection:selectionFile});
  const require=createRequire(import.meta.url),{selectNativeRuntime}=require(path.join(stage.copy,'tools/native-engine-runtime.cjs'));const selected=await selectNativeRuntime(stage.copy,'release',selectionFile);
  generated.push(...[packFile,packReport,selectionFile].map(file=>({file,sha256:record(file).sha256})));
  packageRevision={baseSourceRevision:stage.sourceSignature,fixtureOverlay:overlay,packageSignature,packSha256:pack.sha256,previousPackSha256:previous.sha256,comparison,selector:selected,oldPackageRewritten:false};json(path.join(evidence,'package-revision.json'),packageRevision);
  const gff=await import(pathToFileURL(path.join(stage.privateWorkspace,'src/gff.js'))),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
  const cases=stage.cases.map(entry=>entry.name==='pregame'?{...entry,script:fixtureRelative}:entry);
  for(const entry of cases){
   const paired=[];
   for(const arm of ['editor','release']){
    const name=entry.name+'-'+arm,target=path.join(evidence,name),{report,args}=functionalArguments(arm,entry,stage,target,install);const host=await launch(name,arm==='editor'?path.join(stage.copy,'.tools/Godot_v4.7.2-stable_win64.exe'):selected.executable,args);
    const value=JSON.parse(fs.readFileSync(report));assert.equal(value.success,true);assert.deepEqual(value.failures,[]);let normalized;
    if(entry.bic){const file=report+'.bic';const parsed=gff.parseGff(fs.readFileSync(file),'BIC ');normalized=validateBic(parsed.root,value,gff.getGffFieldTypes,gff.getGffStructType);json(path.join(target,'independent-bic.json'),{...normalized,tree:undefined,bicSha256:record(file).sha256});}
    else{const gate=JSON.parse(fs.readFileSync(report+'.initial-ready.json'));assert.equal(gate.accepted,true);assert.equal(gate.initialGateCeilingMs,15000);assert.equal(gate.coldResponsivenessAccepted,false);assert.equal(gate.subsequentWaitsChanged,false);assert.equal(gate.visibilityAssertionChanged,false);normalized=normalizePregame(value);}
    const accepted={name,arm,checks:value.checks,success:true,cleanEngine:host.cleanEngine,reportSha256:record(report).sha256,normalized};paired.push(accepted);results.push({...accepted,normalized:entry.bic?{...normalized,tree:undefined}:normalized});json(path.join(target,'accepted.json'),results.at(-1));
   }
   assert.deepEqual(paired[0].normalized,paired[1].normalized,'Independent semantic/lifecycle divergence '+entry.name);json(path.join(evidence,entry.name+'-parity.json'),{success:true,case:entry.name,editor:paired[0].reportSha256,release:paired[1].reportSha256,independentTypedBicEquality:entry.bic,newInitialBrowserGate:entry.name==='pregame',coldResponsivenessAccepted:false});
  }
 }catch(error){failure={message:error.message,stack:error.stack};}
 const changedInputs=changedOriginal(),changedCopied=changedCopy(),success=!failure&&results.length===6&&!changedInputs.length&&!changedCopied.length;
 json(path.join(evidence,'runner.json'),{success,status:success?'ACCEPTED_FIXED_SOURCE_PLUS_INITIAL_GATE_SCOPE':'REJECTED_PRESERVED',baseSourceRevision:stage.sourceSignature,packageRevision,executionTools,lane,attempts,results,failure,originalSourceChangesSinceStage,changedInputs,changedCopied,cadence:60,scope:'Fixed historical19e4f9 product source plus declared NEW test-only fixture overlay. Initial Browser readiness contract corrected, original later waits/inputs/visibility assertion preserved. No cold responsiveness or later UI source acceptance.',productionSourceEdits:0,oldPackageRewrites:0,defaultChanges:0,nativeBuilds:0,downloads:0,networkSessions:0,keyAccess:0,userProcessActions:0,gpu:false});
 console.log(JSON.stringify({success,directory:evidence,baseSourceRevision:stage.sourceSignature,packageSignature:packageRevision?.packageSignature??null,attempts:attempts.length,results:results.length,failure,changedInputs,changedCopied}));return success?0:1;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))process.exitCode=await main(process.argv.slice(2));
