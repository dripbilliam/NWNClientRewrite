// Record accepted immutable evidence only. Does not launch engines or inspect keys.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {workspace,project,stageRoot,inside,record,json,sha} from './native-startup-experiment-lib.mjs';

const directory=inside(stageRoot,path.join(stageRoot,'startup-v4'));
const execution=path.join(directory,'execution-root-approved-adjacent-v3');
const stage=JSON.parse(fs.readFileSync(path.join(directory,'stage.json')));
const run=JSON.parse(fs.readFileSync(path.join(execution,'runner.json')));
const packs=JSON.parse(fs.readFileSync(path.join(execution,'packs.json')));
assert.equal(run.success,true);assert.equal(run.runs.length,9);assert.equal(run.attempts.length,11);
assert.deepEqual(run.changedInputs,[]);assert.deepEqual(run.changedStage,[]);assert.equal(packs.nonScriptPayloadsEqual,true);
const controls=path.join(directory,'accepted-tool-inputs');assert.ok(!fs.existsSync(controls));fs.mkdirSync(controls);
for(const row of stage.controls){
 const source=path.join(workspace,row.path);assert.equal(record(source).sha256,row.sha256);
 const destination=inside(controls,path.join(controls,row.path));fs.mkdirSync(path.dirname(destination),{recursive:true});fs.copyFileSync(source,destination);assert.equal(record(destination).sha256,row.sha256);
}
const mean=values=>values.reduce((sum,value)=>sum+value,0)/values.length;
const summary=Object.fromEntries(['A','B','C'].map(arm=>{
 const observations=run.runs.filter(row=>row.arm===arm&&!row.smoke);assert.equal(observations.length,2);
 const fields=['processToFirstMarkerMs','processToBootstrapReadyMs','engineBootstrapEnterToReadyMs','rootLoadMs','processTotalMs'];
 return[arm,{description:{A:'Pinned editor/raw PCK',B:'Pinned release/same raw PCK',C:'Same pinned release/token PCK'}[arm],samples:observations.map(row=>({name:row.name,...Object.fromEntries(fields.map(key=>[key,row[key]]))})),means:Object.fromEntries(fields.map(key=>[key,mean(observations.map(row=>row[key]))])),ranges:Object.fromEntries(fields.map(key=>[key,[Math.min(...observations.map(row=>row[key])),Math.max(...observations.map(row=>row[key]))]]))}];
}));
const releaseDelta=summary.A.means.rootLoadMs-summary.B.means.rootLoadMs;
const tokenDelta=summary.B.means.rootLoadMs-summary.C.means.rootLoadMs;
const evidenceFiles=['stage.json','execution-root-approved-adjacent-v3/runner.json','execution-root-approved-adjacent-v3/packs.json','execution-root-approved-adjacent-v3/runtime-bundles.json',...run.runs.flatMap(row=>['host.json','probe.json','accepted.json','stdout.log','stderr.log','engine.log'].map(file=>'execution-root-approved-adjacent-v3/'+row.name+'/'+file))];
const evidence=evidenceFiles.map(file=>record(path.join(directory,file)));
const source='https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/';
const receipt={
 success:true,scope:'Same-source isolated headless root-resource-load comparison; no full application, OS-cold, world or FPS claim.',
 sourceSignature:run.sourceSignature,engineVersion:'4.7.2.stable',enginePins:stage.engines,
 gates:{toolUnitTests:5,officialExportProcesses:2,correctnessSmokes:3,balancedFreshProcessObservations:6,scriptSourceTokenMappings:packs.scripts,nonScriptPayloadsEqual:true,engineClean:true,noTimeout:true,sourceAndOriginalSixOutputsAndPrivateDllExePackGuardsUnchanged:true},
 design:{order:'A/B/C smoke, then A/B/C/C/B/A',samplesPerArm:2,cache:'Filesystem warmed by export/guards; no cache flush.',bootstrap:'Host spawn to stdout marker arrival, including stdout transport; enter-tree to ready also recorded in engine ticks.',explicitLoad:'Time.get_ticks_usec around ResourceLoader.load(root, Script, CACHE_MODE_IGNORE); ClientAPI autoload already ready.',excluded:'No root.new(), _initialize(), run(), profile/key read, game session, world setup or GPU workload.'},
 summary,
 deltas:{editorRawToReleaseRawRootLoadMs:releaseDelta,editorRawToReleaseRawRootLoadPercent:100*releaseDelta/summary.A.means.rootLoadMs,releaseRawToTokensRootLoadMs:tokenDelta,releaseRawToTokensRootLoadPercent:100*tokenDelta/summary.B.means.rootLoadMs},
 packProof:{raw:packs.raw,token:packs.token,scripts:packs.scripts,commonNonScriptPayloads:9,nonScriptPayloadsEqual:true,tokenMagic:'GDSC',kind:'Official compressed tokenizer data plus remaps; not serialized VM bytecode'},
 interpretation:'Within this small warm load-only sample, changing the engine from editor to release has a much larger effect than token packaging. Tokens reduce explicit load by about176ms (~6.1%) within the same release engine. Semantic analysis/code generation remain. This cannot establish the cause or elimination of the observed14.7s full-entry/pre-run delay.',
 recommendation:'Keep runtime defaults unchanged. Root review is required before any proposed application-runtime promotion, whose full entry, native lifetime, UI, server and source-validation behavior is outside this experiment.',
 officialSources:[{url:source+'modules/gdscript/register_types.cpp#L78-L109',claim:'Official export tokenization/remapping.'},{url:source+'modules/gdscript/gdscript.cpp#L758-L805',claim:'Text and tokens still pass parse/analyze/compile.'},{url:source+'platform/windows/os_windows.cpp#L453-L474',claim:'Windows editor creates adjacent temporary DLL copies; private exact DLLs contain those effects.'},{url:source+'main/main.cpp#L1655-L1780',claim:'Official release path/main-pack overrides can be disabled; native executable-adjacent same-basename PCK avoids those switches.'}],
 preservedRejectedStages:[{path:'godot-client/reports/native-startup-experiment-preflight-v1-rejected.json',reason:'Optional cache metadata literal rejected before stage creation.'},{path:'godot-client/.cache/startup-export-probe/startup-v2/execution-root-approved-v1/runner.json',reason:'Editor shared-path DLL shadow-copy failure; stopped at first export, outputs unchanged.'},{path:'godot-client/.cache/startup-export-probe/startup-v3/execution-root-approved-private-v2/runner.json',reason:'Release disabled --path; stopped after clean exports/pack proof/editor smoke, no comparative acceptance.'}],
 evidence,acceptedToolInputs:stage.controls.map(row=>({...row,snapshot:'godot-client/.cache/startup-export-probe/startup-v4/accepted-tool-inputs/'+row.path})),
 productionSourceEdits:0,defaultChanges:0,downloads:0,nativeBuilds:0,profilesRead:0,keyAccess:0,networkSessions:0,worlds:0,rootInstances:0,rootRunCalls:0,userProcessActions:0,gpuBenchmarks:0
};
const output=path.join(project,'reports/native-startup-experiment-v1-receipt.json');json(output,receipt);
console.log(JSON.stringify({success:true,report:path.relative(workspace,output),sha256:record(output).sha256,sourceSignature:run.sourceSignature,means:Object.fromEntries(Object.entries(summary).map(([arm,row])=>[arm,row.means])),deltas:receipt.deltas,evidenceFiles:evidence.length,enginesStarted:0}));
