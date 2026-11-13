// Explicit approved lane only. Unchanged normal raw packer/bootstrap/selector.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {workspace,project,parityRoot,inside,record,sha,normalizePregame,validateBic,normalReleaseArguments} from './native-release-functional-lib.mjs';
import {safeName,json,unchanged,cleanEngine,childEnvironment,inspectPack} from './native-startup-experiment-lib.mjs';

const [mode,label,lane]=process.argv.slice(2);assert.equal(mode,'--execute-approved','Requires root-approved runtime lane after file-only staging');safeName(label);safeName(lane);
const directory=inside(parityRoot,path.join(parityRoot,label)),stageFile=path.join(directory,'stage.json'),stage=JSON.parse(fs.readFileSync(stageFile));
assert.equal(stage.status,'STAGED_NOT_EXECUTED');assert.equal(stage.directory,directory);
const evidence=path.join(directory,'execution-'+lane);assert.ok(!fs.existsSync(evidence));fs.mkdirSync(evidence);
// Feature work may advance after the file-only snapshot. Test the explicitly
// frozen private revision, while guarding the current originals from any change
// during execution. Tool/data/engine/native identities must still match pins.
const mandatory=[...stage.extraInputs,...stage.nativeInputs,...Object.values(stage.engines),...stage.dataProvenance,...stage.fixed.filter(row=>row.path.startsWith('godot-client/.cache/cached-warlock-creation/'))];
assert.deepEqual(unchanged(mandatory),[],'Tool/data/native/engine identity changed; review before execution');
const originalSourceChangesSinceStage=unchanged(stage.sourceInputs);
const guards=stage.fixed.map(row=>record(path.join(workspace,row.path))),generatedGuards=[];
const changedOriginal=()=>unchanged(guards);
const changedCopy=()=>[...stage.copied,...generatedGuards].filter(row=>{try{return record(row.file).sha256!==row.sha256;}catch{return true;}}).map(row=>row.file);
assert.deepEqual(changedOriginal(),[]);assert.deepEqual(changedCopy(),[]);
const attempts=[],results=[];let failure=null;
async function launch(name,executable,args,cap){
 assert.deepEqual(changedOriginal(),[]);assert.deepEqual(changedCopy(),[]);
 const target=path.join(evidence,name);fs.mkdirSync(target);const env=childEnvironment(target),logs={stdout:[],stderr:[]};
 let timeout=false,stopped=false,spawnError=null,bytes=0;const child=spawn(executable,args,{cwd:target,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
 const attempt={name,executable,executableSha256:record(executable).sha256,args,pid:child.pid??null,capMs:cap};attempts.push(attempt);
 function stop(reason){if(!stopped){stopped=true;attempt.stopReason=reason;child.kill();}}
 const liveText={stdout:'',stderr:''};
 for(const stream of ['stdout','stderr'])child[stream].on('data',chunk=>{
  bytes+=chunk.length;if(bytes>16*1024*1024){stop('output-cap');return;}logs[stream].push(chunk);
  liveText[stream]=(liveText[stream]+chunk.toString('utf8')).slice(-65536);
  if(!cleanEngine(liveText[stream]))stop('engine-error-observed');
 });
 const timer=setTimeout(()=>{timeout=true;stop('owned-timeout');},cap);
 const exit=await new Promise(resolve=>{child.on('error',error=>{spawnError=error.message;});child.on('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal});});});
 const stdout=Buffer.concat(logs.stdout).toString('utf8'),stderr=Buffer.concat(logs.stderr).toString('utf8');
 fs.writeFileSync(path.join(target,'stdout.log'),stdout);fs.writeFileSync(path.join(target,'stderr.log'),stderr);
 const logFile=args[args.indexOf('--log-file')+1],engineLog=fs.existsSync(logFile)?fs.readFileSync(logFile,'utf8'):'';
 const clean=cleanEngine(stdout+'\n'+stderr+'\n'+engineLog);
 const host={...attempt,...exit,timeout,stopped,spawnError,cleanEngine:clean,ownedProcessClosed:true,changedOriginal:changedOriginal(),changedCopy:changedCopy()};json(path.join(target,'host.json'),host);
 assert.equal(exit.code,0,'Owned exit rejected '+name);assert.equal(timeout,false);assert.equal(stopped,false);assert.equal(spawnError,null);assert.equal(clean,true,'Engine log rejected '+name);assert.deepEqual(host.changedOriginal,[]);assert.deepEqual(host.changedCopy,[]);return host;
}
try{
 const packReport=path.join(stage.packageDirectory,'pack.json'),packerLog=path.join(evidence,'packer.engine.log');
 await launch('normal-raw-packer',path.join(stage.copy,'.tools/Godot_v4.7.2-stable_win64.exe'),['--headless','--path',stage.copy,'--log-file',packerLog,'--script','res://tools/prepare-release-pack.gd','--','--directory='+stage.packageDirectory,'--report='+packReport,'--entity-api-rest=false'],120000);
 const packResult=JSON.parse(fs.readFileSync(packReport));assert.equal(packResult.success,true);assert.deepEqual(packResult.errors,[]);assert.equal(packResult.original_game_assets_packed,false);
 const packFile=path.join(stage.packageDirectory,'NwnReleaseTest.pck'),pack=inspectPack(packFile);assert.equal(pack.sha256,packResult.pack_sha256);
 assert.ok(pack.entries.has('__release_boot.gd'));assert.ok(pack.entries.has('__release_boot.tscn'));
 for(const entry of stage.cases)assert.ok(pack.entries.has(entry.script),'Normal pack omitted exact source fixture');
 for(const row of packResult.source_files){const source=path.join(stage.copy,row.path);assert.equal(record(source).sha256,row.sha256);assert.equal(pack.entries.get(row.path)?.sha256,row.sha256,'Raw source payload differs '+row.path);}
 const selectionFile=path.join(stage.packageDirectory,'runtime.json');
 json(selectionFile,{kind:'native-release-package',executable:stage.executable,pack:packFile,receipt:packReport,directory:stage.packageDirectory,sourceSignature:stage.sourceSignature,packSha256:pack.sha256,originalGameAssetsPacked:false,selection:selectionFile});
 const require=createRequire(import.meta.url),{selectNativeRuntime}=require(path.join(stage.copy,'tools/native-engine-runtime.cjs'));
 const selected=await selectNativeRuntime(stage.copy,'release',selectionFile);assert.equal(selected.executable,stage.executable);assert.equal(selected.pack,packFile);
 generatedGuards.push(...[packFile,packReport,selectionFile].map(file=>({file,sha256:record(file).sha256})));
 json(path.join(evidence,'normal-package.json'),{success:true,selector:record(path.join(stage.copy,'tools/native-engine-runtime.cjs')),packer:record(path.join(stage.copy,'tools/prepare-release-pack.gd')),selection:selected,rawScripts:[...pack.entries.keys()].filter(name=>name.endsWith('.gd')).length,tokenScripts:[...pack.entries.keys()].filter(name=>name.endsWith('.gdc')).length,packSha256:pack.sha256});
 const gff=await import(pathToFileURL(path.join(stage.privateWorkspace,'src/gff.js')));
 const install=path.resolve(workspace,'../FullDecomp/NwnRootInstall');
 for(const entry of stage.cases){
  const paired=[];
  for(const arm of ['editor','release']){
   const name=entry.name+'-'+arm,target=path.join(evidence,name),report=path.join(target,'result.json'),log=path.join(target,'engine.log');
   const common=['--report='+report,'--install='+install,'--fixture='+stage.fixture,'--entity-api-rest=false',...entry.args];
   const args=arm==='editor'?['--headless','--path',stage.copy,'--log-file',log,'--script','res://'+entry.script,'--',...common]:normalReleaseArguments(entry.script,report,log,install,stage.fixture,entry.args);
   const executable=arm==='editor'?path.join(stage.copy,'.tools/Godot_v4.7.2-stable_win64.exe'):selected.executable;
   const host=await launch(name,executable,args,65000);assert.ok(fs.existsSync(report));const value=JSON.parse(fs.readFileSync(report));assert.equal(value.success,true,name+' fixture failed');assert.deepEqual(value.failures,[]);
   let normalized;
   if(entry.bic){
    const bicFile=report+'.bic';assert.ok(fs.existsSync(bicFile));
    const parsed=gff.parseGff(fs.readFileSync(bicFile),'BIC ');normalized=validateBic(parsed.root,value,gff.getGffFieldTypes,gff.getGffStructType);
    json(path.join(target,'independent-bic.json'),{...normalized,tree:undefined,bicSha256:record(bicFile).sha256,bytes:fs.statSync(bicFile).size});
   }else normalized=normalizePregame(value);
   const accepted={name,arm,checks:value.checks,success:true,cleanEngine:host.cleanEngine,reportSha256:record(report).sha256,normalized};paired.push(accepted);results.push({...accepted,normalized:entry.bic?{...normalized,tree:undefined}:normalized});
   json(path.join(target,'accepted.json'),results.at(-1));
  }
  assert.deepEqual(paired[0].normalized,paired[1].normalized,'Independent semantic/lifecycle divergence '+entry.name);
  json(path.join(evidence,entry.name+'-parity.json'),{success:true,case:entry.name,editor:paired[0].reportSha256,release:paired[1].reportSha256,independentTypedBicEquality:entry.bic,sourceAssertionsUnchanged:true});
 }
}catch(error){failure={message:error.message,stack:error.stack};}
const changedInputs=changedOriginal(),changedCopied=changedCopy();
const success=!failure&&results.length===6&&!changedInputs.length&&!changedCopied.length;
json(path.join(evidence,'runner.json'),{success,status:success?'ACCEPTED_OFFLINE_FUNCTIONAL_RELEASE_SCOPE':'REJECTED_PRESERVED',sourceSignature:stage.sourceSignature,stageSha256:record(stageFile).sha256,lane,attempts,results,failure,originalSourceChangesSinceStage,changedInputs,changedCopied,scope:'Frozen staged revision of existing raw-source packer/bootstrap/selector plus actual input/native BIC/menu/lifecycle fixtures; later production source changes are listed, not claimed covered. Controlled raster/font, no visual/live host/server/world acceptance',engineLaunches:attempts.length,productionSourceEdits:0,defaultChanges:0,nativeBuilds:0,downloads:0,networkSessions:0,keyAccess:0,userProcessActions:0,gpu:false});
console.log(JSON.stringify({success,directory:evidence,results:results.length,attempts:attempts.length,failure,changedInputs,changedCopied}));process.exitCode=success?0:1;
