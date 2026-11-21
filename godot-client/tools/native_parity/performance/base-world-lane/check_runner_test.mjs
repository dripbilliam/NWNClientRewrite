// Node-only staging/refusal checks. This file never calls the engine-run function.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
import {parseOptions,stageBaseWorldLaneChecks,validateStageForRun} from './check_base_world_lane.mjs';

const here=path.dirname(fileURLToPath(import.meta.url)),projectRoot=path.resolve(here,'../../../..');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const cache=path.join(projectRoot,'.cache');
const relative=(base,file)=>{const rel=path.relative(base,file);return rel!==''&&rel!=='..'&&!rel.startsWith('..'+path.sep)&&!path.isAbsolute(rel);};
const options=process.argv.slice(2);if(options.some(arg=>!arg.startsWith('--out='))||options.length>1)throw Error('Only optional --out=<fresh private cache directory> is accepted');
const out=path.resolve(options[0]?.slice(6)||path.join(cache,'native-presentation-parity/performance/base-world-lane-node',new Date().toISOString().replaceAll(':','-')+'-'+crypto.randomBytes(4).toString('hex')));
if(!relative(cache,out)||fs.existsSync(out))throw Error('Fresh Node-check output must stay below project .cache');
let parent=path.dirname(out);while(!fs.existsSync(parent))parent=path.dirname(parent);if(fs.realpathSync(parent)!==fs.realpathSync(cache)&&!relative(fs.realpathSync(cache),fs.realpathSync(parent)))throw Error('Output parent resolves outside cache');
fs.mkdirSync(out,{recursive:true});
const authority=JSON.parse(fs.readFileSync(path.join(here,'authority.json')));
const sourceBefore=authority.sourceFiles.map(pin=>({relative:pin.relative,sha256:sha(fs.readFileSync(path.join(projectRoot,pin.relative)))}));
const runnerSha=sha(fs.readFileSync(path.join(here,'check_base_world_lane.mjs')));
let checks=0,success=false,error=null;const stages=[];
function check(value,message){checks++;assert.ok(value,message);}
function refuses(call,pattern,message){checks++;assert.throws(call,pattern,message);}
try{
 check(parseOptions([]).run===false,'Default invocation stages only');
 check(parseOptions(['--stage-only']).run===false,'Explicit stage remains nonexecuting');
 check(parseOptions(['--run']).run===true,'Only explicit --run requests execution');
 refuses(()=>parseOptions(['--run','--stage-only']),/Choose either/,'Conflicting mode flags refused');
 refuses(()=>parseOptions(['--benchmark']),/Unknown argument/,'Unbounded or graphical modes do not exist');
 for(const key of ['out','report','source-root'])refuses(()=>parseOptions(['--'+key+'=a','--'+key+'=b']),/Repeated/,'Repeated path refused: '+key);
 refuses(()=>stageBaseWorldLaneChecks({out:path.join(projectRoot,'not-cache')}),/below the project/,'Working-tree output refused');
 refuses(()=>stageBaseWorldLaneChecks({out:path.join(out,'relative-report'),report:'result.json'}),/absolute new path/,'Relative report refused before staging');
 refuses(()=>stageBaseWorldLaneChecks({out:path.join(out,'outside-report'),report:path.join(out,'result.json')}),/absolute new path/,'Report outside its fresh stage refused');
 refuses(()=>stageBaseWorldLaneChecks({out:path.join(out,'outside-source'),sourceRoot:path.dirname(projectRoot)}),/Reviewed source/,'Outside source root refused');
 const stage=stageBaseWorldLaneChecks({out:path.join(out,'main-stage')});stages.push(stage.receipt);
 check(stage.receipt.sourceProfile==='main-v3-static-table-elision','Main source pair selects only the explicit main profile');
 check(stage.receipt.stageOnly&&stage.receipt.engineStarts===0&&stage.receipt.historicalChecksRerun===false,'Stage receipt distinguishes historical120 checks from no current engine run');
 check(path.isAbsolute(stage.receipt.report)&&relative(stage.out,stage.receipt.report)&&!fs.existsSync(stage.receipt.report),'Absolute explicit result path is reserved but not written');
 check(stage.receipt.stagedFiles.length===15&&stage.receipt.stagedFiles.every(pin=>!pin.relative.endsWith('.dll')&&!pin.relative.endsWith('.gdextension')),'Exactly15 small scripts/config/cert files; no native extension or assets');
 const stagedCheck=fs.readFileSync(path.join(stage.project,'check.gd'),'utf8');
 check(stagedCheck.includes('not report.is_absolute_path()')&&stagedCheck.includes('FileAccess.file_exists(report)'),'Godot fixture also refuses missing/relative/existing reports');
 const stagedWorld=fs.readFileSync(path.join(stage.project,'receive_owner.gd'),'utf8');
 check(stagedWorld.includes('base_scenery_omitted.erase(id)')&&stagedWorld.includes('if field=="base_scenery_progress":continue'),'Actual receive omission and single-current-progress seams staged');
 refuses(()=>validateStageForRun(stage),/stage-only output/,'Stage-only receipt cannot later execute');
 refuses(()=>stageBaseWorldLaneChecks({out:stage.out}),/Existing stage/,'Existing output cannot be overwritten');
 const executableStage=stageBaseWorldLaneChecks({out:path.join(out,'guard-only-run-stage'),run:true});stages.push(executableStage.receipt);
 check(validateStageForRun(executableStage).stageBytes.length>0,'Explicit-run stage validates with no engine invocation by this Node check');
 fs.appendFileSync(path.join(executableStage.project,'check.gd'),'\n# Private deliberate drift for refusal check.\n');
 refuses(()=>validateStageForRun(executableStage),/Pinned stage\/input changed/,'Staged script mutation is refused before an engine can start');
 const reportStage=stageBaseWorldLaneChecks({out:path.join(out,'existing-report-stage'),run:true});stages.push(reportStage.receipt);
 fs.writeFileSync(reportStage.receipt.report,'{"existing":true}\n',{flag:'wx'});
 refuses(()=>validateStageForRun(reportStage),/Existing result/,'Existing explicit report is preserved');
 const privateSource=path.join(out,'private-source');
 for(const pin of authority.sourceFiles){const target=path.join(privateSource,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(projectRoot,pin.relative),target,fs.constants.COPYFILE_EXCL);}
 const privateStage=stageBaseWorldLaneChecks({out:path.join(out,'private-source-stage'),sourceRoot:privateSource,run:true});stages.push(privateStage.receipt);
 fs.appendFileSync(path.join(privateSource,'systems/native_render/live_world.gd'),'\n# Private deliberate source drift.\n');
 refuses(()=>validateStageForRun(privateStage),/Pinned stage\/input changed/,'Private capsule source change after staging is refused');
 refuses(()=>stageBaseWorldLaneChecks({out:path.join(out,'drift-source-stage'),sourceRoot:privateSource}),/Reviewed source changed/,'Unreviewed source bytes are refused even outside extracted seams');
 const capsuleSource=path.join(out,'capsule-source');
 for(const pin of authority.sourceFiles){
  let bytes=fs.readFileSync(path.join(projectRoot,pin.relative));
  if(pin.relative.endsWith('live_world.gd'))bytes=fs.readFileSync(path.join(here,'reference/capsule-live_world.gd.txt'));
  if(pin.relative.endsWith('object_stream.gd'))bytes=fs.readFileSync(path.join(here,'reference/capsule-object_stream.gd.txt'));
  const target=path.join(capsuleSource,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
 }
 const capsuleStage=stageBaseWorldLaneChecks({out:path.join(out,'capsule-stage'),sourceRoot:capsuleSource});stages.push(capsuleStage.receipt);
 check(capsuleStage.receipt.stageOnly&&capsuleStage.receipt.sourceProfile==='capsule-v3-preserved-motion-profiling','Pinned capsule World/Object pair stages through its explicit separate profile without executing');
 const capsuleReceive=fs.readFileSync(path.join(capsuleStage.project,'receive_owner.gd'),'utf8');
 check(capsuleReceive.includes('FrameProfile.finish("drive_publish_full",drive_publish_began)')&&capsuleReceive.includes('FrameProfile.finish("drive_publish_delta",drive_publish_began)'),'Actual capsule publication timers are preserved in staged receive bodies');
 check(sha(capsuleReceive)===authority.sourceProfiles.find(profile=>profile.name==='capsule-v3-preserved-motion-profiling').generatedOverrides['receive_owner.gd'],'Capsule receive output has its own exact reviewed hash, not a normalized main body');
 const mixedSource=path.join(out,'mixed-source');
 for(const pin of authority.sourceFiles){const target=path.join(mixedSource,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(projectRoot,pin.relative),target,fs.constants.COPYFILE_EXCL);}
 fs.copyFileSync(path.join(here,'reference/capsule-object_stream.gd.txt'),path.join(mixedSource,'systems/native_render/object_stream.gd'));
 refuses(()=>stageBaseWorldLaneChecks({out:path.join(out,'mixed-main-world-capsule-object'),sourceRoot:mixedSource}),/Reviewed source combination changed/,'Main World plus individually reviewed capsule Object is refused as a wrong combined profile');
 fs.copyFileSync(path.join(here,'reference/capsule-live_world.gd.txt'),path.join(mixedSource,'systems/native_render/live_world.gd'));
 fs.copyFileSync(path.join(projectRoot,'systems/native_render/object_stream.gd'),path.join(mixedSource,'systems/native_render/object_stream.gd'));
 refuses(()=>stageBaseWorldLaneChecks({out:path.join(out,'mixed-capsule-world-main-object'),sourceRoot:mixedSource}),/Reviewed source combination changed/,'Capsule World plus individually reviewed main Object is also refused');
 check(sourceBefore.every(pin=>sha(fs.readFileSync(path.join(projectRoot,pin.relative)))===pin.sha256),'Shared runtime sources unchanged');
 check(sha(fs.readFileSync(path.join(here,'check_base_world_lane.mjs')))===runnerSha,'Runner source unchanged during Node checks');
 success=true;
}catch(value){error=String(value?.stack||value);}
const result={version:1,success,checks,error,engineStarts:0,nativeBuilds:0,ensureCalls:0,gpuTests:0,assets:0,worlds:0,benchmarks:0,serverConnections:0,sharedRuntimeEdits:0,liveSessionTouched:false,runnerSha256:runnerSha,sourceBefore,stages:stages.map(stage=>({out:stage.out,stageOnly:stage.stageOnly,engineStarts:stage.engineStarts,stageSha256:sha(fs.readFileSync(path.join(stage.out,'stage.json')))})),scope:'Node-only staged-body and refusal checks. Explicit-run receipts are staged to exercise pure validation; the engine-run function is never called.'};
fs.writeFileSync(path.join(out,'node-checks.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({out,success,checks,error,engineStarts:0}));process.exitCode=success?0:1;
