// Explicit opt-in only. No production launcher/default/build helpers are invoked.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {workspace,project,stageRoot,inside,safeName,record,json,unchanged,cleanEngine,childEnvironment,inspectPack,comparePacks,runtimeBundle,runtimeArguments,slash} from './native-startup-experiment-lib.mjs';

const [mode,label,lane]=process.argv.slice(2);
assert.equal(mode,'--execute-approved','Usage: --execute-approved STAGED-LABEL PARENT-APPROVED-LANE. This tool is not an authorization request.');
safeName(label);safeName(lane);
const directory=inside(stageRoot,path.join(stageRoot,label)),stageFile=path.join(directory,'stage.json');
const stage=JSON.parse(fs.readFileSync(stageFile));
assert.equal(stage.status,'STAGED_NOT_EXECUTED');assert.equal(path.resolve(stage.directory),directory);
assert.equal(path.resolve(stage.copy),path.join(directory,'project'));
const evidence=path.join(directory,'execution-'+lane);assert.ok(!fs.existsSync(evidence),'Preserve earlier evidence');fs.mkdirSync(evidence);
assert.equal(stage.privateLibraries?.length,2,'Private DLL isolation stage required');
for(const row of stage.privateLibraries)inside(path.join(directory,'native-libraries'),path.join(workspace,row.path));
const fixed=[...stage.closure.files,...stage.controls,...stage.guards,...stage.privateLibraries,...Object.values(stage.engines)];
const runtimeGuards=[],runtimeBundles=[];
const currentChanged=()=>unchanged([...fixed,...runtimeGuards]);
const stagedChanged=()=>stage.stagedInputs.filter(row=>record(path.join(stage.copy,row.relative)).sha256!==row.sha256).map(row=>row.relative);
assert.deepEqual(currentChanged(),[],'Source or outputs changed after staging; prepare a fresh copy');assert.deepEqual(stagedChanged(),[]);
const attempts=[],runs=[];let failure=null;
const engineCleanPattern='Warnings, script/parse errors, leaked instances and nonzero/timeout exits are rejected';

async function launch(name,executable,args,capMs,reportFile=null){
 assert.deepEqual(currentChanged(),[],'Producer changed before owned launch');assert.deepEqual(stagedChanged(),[]);
 const target=path.join(evidence,name);fs.mkdirSync(target);
 const env=childEnvironment(target),executableSha256=record(executable).sha256;
 const chunks={stdout:[],stderr:[]},markers=[];let lineBuffer='',bytes=0,timedOut=false,killed=false,spawnError=null;
 const attempt={name,executable,executableSha256,args,capMs,directory:target,reportFile,startedUtc:new Date().toISOString()};attempts.push(attempt);
 const started=process.hrtime.bigint();
 const child=spawn(executable,args,{cwd:target,windowsHide:true,env,stdio:['ignore','pipe','pipe']});
 attempt.pid=child.pid??null;
 function elapsed(){return Number(process.hrtime.bigint()-started)/1e6;}
 function stop(reason){if(!killed){killed=true;attempt.killReason=reason;child.kill();}}
 function collect(stream,chunk){
  bytes+=chunk.length;if(bytes>16*1024*1024){stop('bounded-output-limit');return;}
  chunks[stream].push(chunk);
  if(stream==='stdout'){
   lineBuffer+=chunk.toString('utf8');const lines=lineBuffer.split(/\r?\n/);lineBuffer=lines.pop();
   for(const line of lines)if(line.startsWith('STARTUP_PROBE ')){
    try{markers.push({...JSON.parse(line.slice('STARTUP_PROBE '.length)),hostElapsedMs:elapsed()});}catch{stop('malformed-marker');}
   }
  }
 }
 child.stdout.on('data',data=>collect('stdout',data));child.stderr.on('data',data=>collect('stderr',data));
 const timer=setTimeout(()=>{timedOut=true;stop('owned-process-timeout');},capMs);
 const outcome=await new Promise(resolve=>{
  child.on('error',error=>{spawnError=error.message;});
  child.on('close',(code,signal)=>{clearTimeout(timer);resolve({code,signal});});
 });
 const stdout=Buffer.concat(chunks.stdout).toString('utf8'),stderr=Buffer.concat(chunks.stderr).toString('utf8');
 fs.writeFileSync(path.join(target,'stdout.log'),stdout);fs.writeFileSync(path.join(target,'stderr.log'),stderr);
 const engineLog=args[args.indexOf('--log-file')+1],log=engineLog&&fs.existsSync(engineLog)?fs.readFileSync(engineLog,'utf8'):'';
 const engineClean=cleanEngine(stdout+'\n'+stderr+'\n'+log);
 const result={...attempt,...outcome,elapsedMs:elapsed(),timedOut,killed,spawnError,engineClean,markers,ownedProcessClosed:true,changedInputs:currentChanged(),changedStage:stagedChanged()};
 json(path.join(target,'host.json'),result);
 assert.equal(result.code,0,'Owned process exit rejected: '+name);assert.equal(spawnError,null);assert.equal(timedOut,false);assert.equal(killed,false);assert.equal(engineClean,true,'Engine log rejected: '+name);
 assert.deepEqual(result.changedInputs,[]);assert.deepEqual(result.changedStage,[]);
 return result;
}
function exportedFile(relative){return inside(directory,path.join(evidence,relative));}
try{
 // Both packages use the official exporter; the only preset difference is script mode.
 // Export work is correctness preparation, never included in startup measurements.
 const rawFile=exportedFile('raw.pck'),tokenFile=exportedFile('tokens.pck');
 for(const [preset,file]of [['RawText',rawFile],['BinaryTokens',tokenFile]]){
  const log=path.join(evidence,'export-'+preset+'.log');
  await launch('export-'+preset,stage.engines.editor.file,['--headless','--path',stage.copy,'--log-file',log,'--export-pack',preset,file],120000);
  assert.ok(fs.existsSync(file),'Exporter did not produce private pack');
 }
 const raw=inspectPack(rawFile),token=inspectPack(tokenFile);
 const packProof=comparePacks(raw,token,stage.stagedInputs);
 // Validate the two identical native extension descriptors and project/autoload settings.
 for(const name of ['native/particle_kernel.gdextension','native/resource_index.gdextension']){
  assert.equal(raw.entries.get(name)?.sha256,record(path.join(stage.copy,name)).sha256);
  assert.equal(token.entries.get(name)?.sha256,raw.entries.get(name)?.sha256);
 }
 assert.ok(raw.entries.has('project.binary'));assert.equal(raw.entries.get('project.binary').sha256,token.entries.get('project.binary')?.sha256);
 assert.ok(raw.entries.has('.godot/extension_list.cfg'));assert.equal(raw.entries.get('.godot/extension_list.cfg').sha256,token.entries.get('.godot/extension_list.cfg')?.sha256);
 json(path.join(evidence,'packs.json'),{...packProof,raw:{path:rawFile,bytes:raw.bytes,sha256:raw.sha256,entries:raw.entries.size},token:{path:tokenFile,bytes:token.bytes,sha256:token.sha256,entries:token.entries.size}});
 const packGuards=[record(rawFile),record(tokenFile)];
 const arms={A:{engine:'editor',pack:rawFile},B:{engine:'release',pack:rawFile},C:{engine:'release',pack:tokenFile}};
 for(const [arm,definition]of Object.entries(arms)){
  const bundle=runtimeBundle(evidence,arm);fs.mkdirSync(bundle.directory);
  fs.copyFileSync(stage.engines[definition.engine].file,bundle.executable);fs.copyFileSync(definition.pack,bundle.pack);
  const executable=record(bundle.executable),pack=record(bundle.pack);
  assert.equal(executable.sha256,stage.engines[definition.engine].sha256);assert.equal(pack.sha256,record(definition.pack).sha256);
  runtimeGuards.push(executable,pack);
  runtimeBundles.push({arm,...bundle,originalExecutable:stage.engines[definition.engine].file,originalExecutableSha256:stage.engines[definition.engine].sha256,privateExecutableSha256:executable.sha256,privatePackSha256:pack.sha256});
  definition.bundle=bundle;
 }
 json(path.join(evidence,'runtime-bundles.json'),runtimeBundles);
 let expectedMethods=null;
 // Initial correctness smokes are kept distinct from the balanced observations.
 const order=[...['A','B','C'].map(arm=>({arm,smoke:true})),...['A','B','C','C','B','A'].map(arm=>({arm,smoke:false}))];
 for(const [index,observation]of order.entries()){
  assert.deepEqual(unchanged(packGuards),[]);
  const arm=arms[observation.arm],name=String(index+1).padStart(2,'0')+'-'+observation.arm+(observation.smoke?'-smoke':''),target=path.join(evidence,name);
  const reportFile=path.join(target,'probe.json'),engineLog=path.join(target,'engine.log');
  // Official release templates disable path overrides; matching adjacent PCK is
  // the native supported route. The copied EXE/pack contain no source directory.
  const result=await launch(name,arm.bundle.executable,runtimeArguments(reportFile,engineLog),90000,reportFile);
  assert.ok(fs.existsSync(reportFile));const probe=JSON.parse(fs.readFileSync(reportFile));
  assert.equal(probe.success,true);assert.equal(probe.complete,true);assert.equal(probe.root_resource_valid,true);assert.equal(probe.display,'headless');
  assert.equal(probe.root_instances_created,0);assert.equal(probe.root_run_calls,0);assert.equal(probe.network_sessions,0);assert.equal(probe.key_access,0);assert.equal(probe.worlds,0);
  assert.equal(probe.autoload_rest.enabled,false);assert.equal(probe.autoload_rest.listening,false);
  assert.deepEqual(probe.native_extensions,['res://native/particle_kernel.gdextension','res://native/resource_index.gdextension']);
  assert.equal(probe.engine.major,4);assert.equal(probe.engine.minor,7);assert.equal(probe.engine.patch,2);
  assert.equal(probe.editor_feature,arm.engine==='editor');assert.equal(probe.debug_feature,arm.engine==='editor');
  assert.deepEqual(probe.marks.map(row=>row.phase),['bootstrap_enter_tree','bootstrap_ready','root_load_begin','root_load_end']);
  assert.deepEqual(result.markers.map(row=>row.phase),['bootstrap_enter_tree','bootstrap_ready','root_load_begin','root_load_end','complete']);
  assert.ok(result.markers.every(row=>row.pid===result.pid));
  if(expectedMethods===null)expectedMethods=probe.root_methods;else assert.deepEqual(probe.root_methods,expectedMethods,'Root methods differ between arms');
  const marker=phase=>result.markers.find(row=>row.phase===phase);
  runs.push({name,...observation,engine:arm.engine,packSha256:record(arm.pack).sha256,pid:result.pid,processToFirstMarkerMs:marker('bootstrap_enter_tree').hostElapsedMs,processToBootstrapReadyMs:marker('bootstrap_ready').hostElapsedMs,engineBootstrapEnterToReadyMs:(marker('bootstrap_ready').ticks_usec-marker('bootstrap_enter_tree').ticks_usec)/1000,rootLoadMs:probe.root_load_usec/1000,processTotalMs:result.elapsedMs,cleanEngine:result.engineClean,probeSha256:record(reportFile).sha256});
  json(path.join(target,'accepted.json'),runs.at(-1));
 }
 assert.deepEqual(unchanged(packGuards),[]);
}catch(error){failure={message:error.message,stack:error.stack};}
const changedInputs=currentChanged(),changedStage=stagedChanged();
const success=!failure&&changedInputs.length===0&&changedStage.length===0&&runs.length===9;
const final={success,status:success?'ACCEPTED_LOAD_ONLY_EXPERIMENT':'REJECTED_PRESERVED',approvedLane:lane,sourceSignature:stage.sourceSignature,stageSha256:record(stageFile).sha256,failure,runs,attempts,changedInputs,changedStage,privateLibraries:stage.privateLibraries,runtimeBundles,engineCleanPattern,scope:'Only resource load, not root construction/run, full application startup, network or world',sampling:'Three correctness smokes then A/B/C/C/B/A in fresh processes. No OS cache flush; exports and guards warm file caches. No OS-cold claim. Host marker arrival includes stdout transport.',engineLaunches:attempts.length,packExports:attempts.filter(row=>row.name.startsWith('export-')).length,rootRunCalls:0,profilesRead:0,keyAccess:0,networkSessions:0,worlds:0,nativeBuilds:0,userProcessActions:0,productionSourceEdits:0,defaultChanges:0};
json(path.join(evidence,'runner.json'),final);
console.log(JSON.stringify({...final,attempts:attempts.length,runs:runs.length,directory:evidence}));process.exitCode=success?0:1;
