// Reviewed runner-contract correction. The original runner/stage/fixtures and
// canonical package are retained byte-for-byte. Importing does not execute.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {workspace,parityRoot,inside,record,normalizePregame,validateBic,normalReleaseArguments} from './native-release-functional-lib.mjs';
import {safeName,json,unchanged,cleanEngine,childEnvironment,inspectPack} from './native-startup-experiment-lib.mjs';

export function originalCadence(args){
 assert.equal(args[0],'--headless');assert.ok(!args.includes('--max-fps'),'Do not silently override another cadence');
 return[args[0],'--max-fps','60',...args.slice(1)];
}
export function functionalArguments(arm,entry,stage,target,install){
 const report=path.join(target,'result.json'),log=path.join(target,'engine.log');
 const common=['--report='+report,'--install='+install,'--fixture='+stage.fixture,'--entity-api-rest=false',...entry.args];
 assert.ok(['editor','release'].includes(arm));
 const args=arm==='editor'?['--headless','--path',stage.copy,'--log-file',log,'--script','res://'+entry.script,'--',...common]:normalReleaseArguments(entry.script,report,log,install,stage.fixture,entry.args);
 return{report,log,args:originalCadence(args)};
}
export async function main(argv){
 const [mode,label,lane]=argv;assert.equal(mode,'--execute-approved');safeName(label);safeName(lane);
 const directory=inside(parityRoot,path.join(parityRoot,label)),stageFile=path.join(directory,'stage.json'),stage=JSON.parse(fs.readFileSync(stageFile));
 assert.equal(stage.status,'STAGED_NOT_EXECUTED');assert.equal(stage.directory,directory);
 assert.equal(stage.sourceSignature,'19e4f9fb0bbb10d410b2f0aacab5f367a03d03cd10320aa3b0c1f3d1ea202d0d','This reviewed runner reuses the explicit fixed revision only');
 const evidence=path.join(directory,'execution-'+lane);assert.ok(!fs.existsSync(evidence));fs.mkdirSync(evidence);
 const executionTools=[record(fileURLToPath(import.meta.url)),record(path.join(workspace,'scripts/tests/native-release-functional-v2.test.mjs'))];
 const mandatory=[...stage.extraInputs,...stage.nativeInputs,...Object.values(stage.engines),...stage.dataProvenance,...stage.fixed.filter(row=>row.path.startsWith('godot-client/.cache/cached-warlock-creation/'))];
 assert.deepEqual(unchanged(mandatory),[],'Original tool/data/native/engine identity changed');
 const originalSourceChangesSinceStage=unchanged(stage.sourceInputs);
 const guards=[...stage.fixed.map(row=>record(path.join(workspace,row.path))),...executionTools],packageGuards=[];
 const changedOriginal=()=>unchanged(guards);
 const changedCopy=()=>[...stage.copied,...packageGuards].filter(row=>{try{return record(row.file).sha256!==row.sha256;}catch{return true;}}).map(row=>row.file);
 assert.deepEqual(changedOriginal(),[]);assert.deepEqual(changedCopy(),[]);
 const attempts=[],results=[];let failure=null;
 async function launch(name,executable,args){
  assert.deepEqual(changedOriginal(),[]);assert.deepEqual(changedCopy(),[]);
  const target=path.join(evidence,name);fs.mkdirSync(target);const env=childEnvironment(target),logs={stdout:[],stderr:[]};
  let timeout=false,stopped=false,spawnError=null,bytes=0;const child=spawn(executable,args,{cwd:target,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
  const attempt={name,executable,executableSha256:record(executable).sha256,args,pid:child.pid??null,capMs:65000};attempts.push(attempt);
  function stop(reason){if(!stopped){stopped=true;attempt.stopReason=reason;child.kill();}}
  const live={stdout:'',stderr:''};
  for(const stream of ['stdout','stderr'])child[stream].on('data',chunk=>{
   bytes+=chunk.length;if(bytes>16*1024*1024){stop('output-cap');return;}logs[stream].push(chunk);live[stream]=(live[stream]+chunk.toString('utf8')).slice(-65536);if(!cleanEngine(live[stream]))stop('engine-error-observed');
  });
  const timer=setTimeout(()=>{timeout=true;stop('owned-timeout');},65000);
  const exit=await new Promise(resolve=>{child.on('error',error=>{spawnError=error.message;});child.on('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal});});});
  const stdout=Buffer.concat(logs.stdout).toString('utf8'),stderr=Buffer.concat(logs.stderr).toString('utf8');fs.writeFileSync(path.join(target,'stdout.log'),stdout);fs.writeFileSync(path.join(target,'stderr.log'),stderr);
  const logFile=args[args.indexOf('--log-file')+1],engineLog=fs.existsSync(logFile)?fs.readFileSync(logFile,'utf8'):'';
  const clean=cleanEngine(stdout+'\n'+stderr+'\n'+engineLog);
  const host={...attempt,...exit,timeout,stopped,spawnError,cleanEngine:clean,ownedProcessClosed:true,changedOriginal:changedOriginal(),changedCopy:changedCopy()};json(path.join(target,'host.json'),host);
  assert.equal(exit.code,0,'Owned exit rejected '+name);assert.equal(timeout,false);assert.equal(stopped,false);assert.equal(spawnError,null);assert.equal(clean,true,'Engine rejected '+name);assert.deepEqual(host.changedOriginal,[]);assert.deepEqual(host.changedCopy,[]);return host;
 }
 try{
  // Revalidate, do not rewrite/repack, the package accepted in the first run.
  const priorProofFile=path.join(directory,'execution-root-approved-functional-v1/normal-package.json'),priorProof=JSON.parse(fs.readFileSync(priorProofFile));assert.equal(priorProof.success,true);
  const packReport=path.join(stage.packageDirectory,'pack.json'),packResult=JSON.parse(fs.readFileSync(packReport));assert.equal(packResult.success,true);assert.deepEqual(packResult.errors,[]);assert.equal(packResult.original_game_assets_packed,false);
  const packFile=path.join(stage.packageDirectory,'NwnReleaseTest.pck'),pack=inspectPack(packFile);assert.equal(pack.sha256,packResult.pack_sha256);assert.equal(pack.sha256,priorProof.packSha256);
  assert.equal(record(path.join(stage.copy,'tools/prepare-release-pack.gd')).sha256,priorProof.packer.sha256);
  assert.equal(record(path.join(stage.copy,'tools/native-engine-runtime.cjs')).sha256,priorProof.selector.sha256);
  assert.ok(pack.entries.has('__release_boot.gd'));assert.ok(pack.entries.has('__release_boot.tscn'));
  for(const entry of stage.cases)assert.ok(pack.entries.has(entry.script));
  for(const row of packResult.source_files){assert.equal(record(path.join(stage.copy,row.path)).sha256,row.sha256);assert.equal(pack.entries.get(row.path)?.sha256,row.sha256);}
  const selectionFile=path.join(stage.packageDirectory,'runtime.json'),require=createRequire(import.meta.url),{selectNativeRuntime}=require(path.join(stage.copy,'tools/native-engine-runtime.cjs'));
  const selected=await selectNativeRuntime(stage.copy,'release',selectionFile);assert.equal(selected.executable,stage.executable);assert.equal(selected.pack,packFile);
  packageGuards.push(...[packFile,packReport,selectionFile,priorProofFile].map(file=>({file,sha256:record(file).sha256})));
  json(path.join(evidence,'reused-package.json'),{success:true,sourceSignature:stage.sourceSignature,originalPackageProof:record(priorProofFile),packSha256:pack.sha256,rewritten:false,repacked:false,selection:selected,executionTools});
  const gff=await import(pathToFileURL(path.join(stage.privateWorkspace,'src/gff.js'))),install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
  for(const entry of stage.cases){
   const paired=[];
   for(const arm of ['editor','release']){
    const name=entry.name+'-'+arm,target=path.join(evidence,name),{report,args}=functionalArguments(arm,entry,stage,target,install);
    const executable=arm==='editor'?path.join(stage.copy,'.tools/Godot_v4.7.2-stable_win64.exe'):selected.executable;
    const host=await launch(name,executable,args);assert.ok(fs.existsSync(report));const value=JSON.parse(fs.readFileSync(report));assert.equal(value.success,true,name+' fixture failed');assert.deepEqual(value.failures,[]);
    let normalized;
    if(entry.bic){
     const bicFile=report+'.bic';assert.ok(fs.existsSync(bicFile));const parsed=gff.parseGff(fs.readFileSync(bicFile),'BIC ');normalized=validateBic(parsed.root,value,gff.getGffFieldTypes,gff.getGffStructType);
     json(path.join(target,'independent-bic.json'),{...normalized,tree:undefined,bicSha256:record(bicFile).sha256,bytes:fs.statSync(bicFile).size});
    }else normalized=normalizePregame(value);
    const accepted={name,arm,checks:value.checks,success:true,cleanEngine:host.cleanEngine,reportSha256:record(report).sha256,normalized};paired.push(accepted);results.push({...accepted,normalized:entry.bic?{...normalized,tree:undefined}:normalized});json(path.join(target,'accepted.json'),results.at(-1));
   }
   assert.deepEqual(paired[0].normalized,paired[1].normalized,'Independent semantic/lifecycle divergence '+entry.name);
   json(path.join(evidence,entry.name+'-parity.json'),{success:true,case:entry.name,editor:paired[0].reportSha256,release:paired[1].reportSha256,independentTypedBicEquality:entry.bic,sourceAssertionsUnchanged:true,cadence:60});
  }
 }catch(error){failure={message:error.message,stack:error.stack};}
 const changedInputs=changedOriginal(),changedCopied=changedCopy(),success=!failure&&results.length===6&&!changedInputs.length&&!changedCopied.length;
 const receipt={success,status:success?'ACCEPTED_OFFLINE_FUNCTIONAL_RELEASE_SCOPE':'REJECTED_PRESERVED',sourceSignature:stage.sourceSignature,stageSha256:record(stageFile).sha256,lane,executionTools,cadence:60,originalPackageReused:true,attempts,results,failure,originalSourceChangesSinceStage,changedInputs,changedCopied,scope:'Historical fixed19e4f9 source revision only; later UI code is explicitly not covered. Same unmodified canonical raw package/bootstrap/selector and original fixture assertions. Controlled raster/font; no live host/server/world/visual acceptance.',engineLaunches:attempts.length,packageRewrites:0,productionSourceEdits:0,defaultChanges:0,nativeBuilds:0,downloads:0,networkSessions:0,keyAccess:0,userProcessActions:0,gpu:false};
 json(path.join(evidence,'runner.json'),receipt);console.log(JSON.stringify({success,directory:evidence,sourceSignature:stage.sourceSignature,results:results.length,attempts:attempts.length,failure,changedInputs,changedCopied}));return success?0:1;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))process.exitCode=await main(process.argv.slice(2));
