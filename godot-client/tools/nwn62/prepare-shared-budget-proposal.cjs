'use strict';
// Source-only proposal. Does not stage a selection, parse Godot or launch/tests.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),label=process.argv[2]||'shared4-proposal-b';assert(/^shared4-proposal-[a-z0-9-]+$/.test(label));const directory=path.join(root,'.cache/nwn62',label);assert(!fs.existsSync(directory),'Retain earlier proposal');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex'),read=file=>fs.readFileSync(file),setting='nwn/private/publication_shared_budget_us';
const parentFile=path.join(root,'.cache/nwn62/entry-pairs/entry62-final-proposal-a/proposal.json'),parent=JSON.parse(read(parentFile));
assert.equal(sha(read(parentFile)),'94dd2089568fb7eee917064bc5463b34482d2e88e110ad56292e892992eed5e6');
const poolPath='systems/native_render/resource_pool.gd',helperPath='tools/nwn62/shared_budget_ledger_audit.gd';
const poolBefore=read(path.join(parent.candidate,poolPath)).toString('utf8');assert.equal(sha(poolBefore),parent.pins.candidate.find(pin=>pin.file===poolPath).sha256);
let pool=poolBefore;const hunks=[];
function exact(before,after){assert.equal(pool.split(before).length-1,1,before);pool=pool.replace(before,after);hunks.push({before,after});}
exact('var publication_budget_us:=3000',`static func configured_private_shared_budget() -> int:
\tvar setting: Variant=ProjectSettings.get_setting("${setting}",0)
\treturn 4000 if setting is int and int(setting)==4000 else 3000
var publication_budget_us:=configured_private_shared_budget()
var _private_shared_audit=preload("res://${helperPath}").new()`);
exact('if publication_frame!=frame:\n','if publication_frame!=frame:\n\t\t_private_shared_audit.finish_frame(self)\n');
const consume='\treturn completion_units+_completion_depth<maximum_completion_units_per_frame and ((priority and priority_publications==0 and not _completion_priority) or _completion_depth==0 and completion_units==0 and publications==0 and construction_steps==0 or elapsed<publication_budget_limit_us())';
exact(consume,consume.replace('\treturn ','\tvar allowed: bool=')+'\n\tif not allowed:_private_shared_audit.deny("completion",elapsed,publication_budget_limit_us(),completion_units+_completion_depth>=maximum_completion_units_per_frame)\n\treturn allowed');
const publish='\treturn (priority and priority_publications==0) or publications==0 and construction_steps==0 and completion_units==0 or elapsed<publication_budget_limit_us() and publications<maximum_publications_per_frame';
exact(publish,publish.replace('\treturn ','\tvar allowed: bool=')+'\n\tif not allowed:_private_shared_audit.deny("publication",elapsed,publication_budget_limit_us(),publications>=maximum_publications_per_frame)\n\treturn allowed');
exact('\t\tvar elapsed:=Time.get_ticks_usec()-_completion_began;publication_us+=elapsed;completion_us+=elapsed;_completion_began=0','\t\tvar elapsed:=Time.get_ticks_usec()-_completion_began;publication_us+=elapsed;completion_us+=elapsed;_completion_began=0\n\t\t_private_shared_audit.record("completion",elapsed,false)');
exact('func construction_finished(began: int) -> void:\n\t_publication_frame()\n\tif _completion_depth==0:publication_us+=Time.get_ticks_usec()-began\n\tconstruction_steps+=1','func construction_finished(began: int) -> void:\n\t_publication_frame()\n\tvar elapsed:=0\n\tif _completion_depth==0:elapsed=Time.get_ticks_usec()-began;publication_us+=elapsed\n\tconstruction_steps+=1\n\t_private_shared_audit.record("construction",elapsed,_completion_depth>0)');
exact('\tif _completion_depth==0:publication_us+=Time.get_ticks_usec()-began\n\tpublications+=1','\tvar elapsed:=0\n\tif _completion_depth==0:elapsed=Time.get_ticks_usec()-began;publication_us+=elapsed\n\tpublications+=1\n\t_private_shared_audit.record("publication",elapsed,_completion_depth>0)');
exact('\tstate.publication_budget.private_entry=private_entry_budget_snapshot()','\tstate.publication_budget.private_entry=private_entry_budget_snapshot()\n\tstate.publication_budget.private_shared={"setting_key":"'+setting+'","requested_us":ProjectSettings.get_setting("'+setting+'",0),"effective_ordinary_us":publication_budget_us,"audit":_private_shared_audit.snapshot(self),"scope":"PRIVATE whole-world shared-ledger allowance comparison only; absent/default0 keeps3000us; only4000 admits4000us. No callback/operation/unit/worker bound change."}');
const helper=`extends RefCounted
# PRIVATE shared-ledger counters only. No clock reads, owners or frame arrays.
# Existing outer elapsed values are reused with their original lazy clock
# condition. Nested construction/publication counts have NO elapsed/max sample.
var frames:=0
var charged_us:=0
var maximum_charged_us:=0
var exhausted_frames:=0
var maximum_overrun_us:=0
var quota_frames:=0
var last_finished:=-1
var operations: Dictionary={}
var denials: Dictionary={}
func finish_frame(pool)->void:
\tif int(pool.publication_frame)<0 or int(pool.publication_frame)==last_finished:return
\tlast_finished=int(pool.publication_frame);frames+=1
\tvar used:=int(pool.publication_us);var limit:=int(pool.publication_budget_us)
\tcharged_us+=used;maximum_charged_us=maxi(maximum_charged_us,used);maximum_overrun_us=maxi(maximum_overrun_us,used-limit)
\tif used>=limit:exhausted_frames+=1
\tif int(pool.publications)>=int(pool.maximum_publications_per_frame):quota_frames+=1
func record(kind: String,elapsed: int,nested: bool)->void:
\tif not operations.has(kind):operations[kind]={"calls":0,"nested_calls":0,"timed_calls":0,"cpu_us":0,"maximum_us":0}
\tvar row: Dictionary=operations[kind];row.calls+=1;row.nested_calls+=int(nested)
\tif not nested:row.timed_calls+=1;row.cpu_us+=elapsed;row.maximum_us=maxi(row.maximum_us,elapsed)
func deny(kind: String,elapsed: int,limit: int,quota: bool)->void:
\tif not denials.has(kind):denials[kind]={"attempts":0,"time":0,"quota":0,"time_and_quota":0,"maximum_observed_us":0}
\tvar row: Dictionary=denials[kind];row.attempts+=1;row.maximum_observed_us=maxi(row.maximum_observed_us,elapsed)
\tif elapsed>=limit:row.time+=1
\tif quota:row.quota+=1
\tif elapsed>=limit and quota:row.time_and_quota+=1
func snapshot(pool)->Dictionary:
\tvar current: bool=int(pool.publication_frame)>=0 and int(pool.publication_frame)!=last_finished
\tvar used:=int(pool.publication_us) if current else 0;var limit:=int(pool.publication_budget_us)
\treturn {"frames":frames+int(current),"charged_us":charged_us+used,"maximum_charged_us":maxi(maximum_charged_us,used),"maximum_overrun_us":maxi(maximum_overrun_us,used-limit),"exhausted_frames":exhausted_frames+int(current and used>=limit),"quota_frames":quota_frames+int(current and int(pool.publications)>=int(pool.maximum_publications_per_frame)),"operations":operations.duplicate(true),"denials":denials.duplicate(true),"scope":"PRIVATE bounded scalar aggregates, original lazy clock conditions preserved. Shared charged_us is additive; nested construction/publication have counts only, no elapsed/max. Progress/priority reservation and indivisible API overruns retain original behavior; no hard deadline preemption."}
`;
const writes=[{file:'before/'+poolPath,value:poolBefore},{file:'common/'+poolPath,value:pool},{file:'common/'+helperPath,value:helper}];
const baseProject=read(path.join(parent.candidate,'project.godot')).toString('utf8');assert(!baseProject.includes(setting));
for(const [leg,budget]of [['control',0],['candidate',4000]]){
 let configured=baseProject;const section='[nwn]\n';assert(!configured.includes('[nwn]')||configured.includes(section),'Unexpected section line ending');configured=configured.includes(section)?configured.replace(section,section+'\nprivate/publication_shared_budget_us='+budget+'\n'):configured+'\n'+section+'\nprivate/publication_shared_budget_us='+budget+'\n';writes.push({file:leg+'/project.godot',value:configured});
}
for(const item of writes){const file=path.join(directory,item.file);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,item.value,{flag:'wx'});}
const proofs={};for(const relative of ['systems/native_render/model_template.gd','systems/native_render/object_stream.gd','systems/native_render/area_stream.gd','systems/native_render/creature_stream.gd','systems/native_render/live_world.gd','systems/native_data/asset_service.gd'])proofs[relative]=sha(read(path.join(parent.candidate,relative)));
const manifest={version:1,ticket:'NWN-62',kind:'PRIVATE source-only ordinary shared3ms versus4ms allowance proposal',parent:{file:parentFile,sha256:sha(read(parentFile)),leg:'candidate',project:parent.candidate},directory,setting:{name:setting,control:0,candidate:4000,defaultAbsentEffective:3000,acceptedPositiveValue:4000,noCLIOrEnvironmentIngress:true,scope:'Whole-world private run, including post-firstplay scenery and steady. No loading mark extension or canonical default change.'},files:writes.map(item=>({file:item.file,sha256:sha(item.value)})),hunks,unchangedSourceProofs:proofs,scope:{sharedCPU:'Asset completion callbacks/result-release + nested publication + construction/planning + World adoption + draw flush, one Engine frame ledger; only this total allowance changes.',unchangedBounds:{operationStepCapUs:1500,liveStepMaximumUnits:32,serviceCompletionPassUs:1500,serviceCompletionsPerPass:8,completionUnitsPerFrame:64,publicationUnitsPerFrame:16,worldAdoptionsPerCallback:8,ordinaryCallbackLimitUs:3000,workerActive:'<=W',workerRetained:'<=2W',maximumPending:'unchanged'},charged:[{unit:'AssetService completion',start:'After ready-task and capacity/budget gate, before wait_for_task_completion',end:'After running/results removal, epoch-valid completed.emit and drain result reference release',nested:'Nested construction/publication increments units but outer completion wall time is charged exactly once; stale releases included.'},{unit:'Stream construction/planning/publication',start:'Existing unit_began or planning unit timer',end:'Existing construction_finished/publication_finished; setup/finalization within these scopes unchanged',nested:'1.5ms step remains cooperative; individual GPU/pack/helper activation may overrun.'},{unit:'World adoption',start:'After candidate sorting and allowance checks, install_began',end:'After lifetime/desired check, replacement, motion, pose, service registration, show/draw admission/base reservation',nested:'Only this operation wall time is charged; old pre62 adoption had independent3ms/8adopt loop.'},{unit:'Base draw flush',start:'draw_began immediately before flush(0.5,1)',end:'publication_finished after flush',nested:'Original indivisible boundary retained.'}],outsideLedger:['Ready-task scan, AssetService request/pump and its bookkeeping after completion scope.','World candidate enumeration/sorting and invisible-result handling before the measured adoption unit.','Completed-batch statistics deep copy, finish_stream_owner/retirement after adoption loop; separately profiled but not silently claimed bounded here.','Asynchronous rendering/GPU work and engine frame delay.'],reservation:'Exact old first-progress and one priority reservation predicates preserved. Can exceed limit for necessary initial/priority work or an indivisible call; counters report actual overruns, never claim hard3/4ms preemption.'},diagnostic:{commonBothViews:true,addedClockReads:0,sourceOnlyBoundedNumerics:true,sharedChargedAndMaximumOverrun:true,completionPublicationTimeAndQuotaDenials:true,maximumIndividualOuterScopesOnly:true,nestedOperationsCountedWithoutTiming:true,nestedAtomicTimingFromExistingCreatureTileScalars:true,noPerFrameArraysOrStrongOwnerReferences:true},assertions:{canonicalSourcesUntouched:true,final3msInputUntouched:true,commonPoolAndAuditBytesBothViews:true,onlyProjectSettingDiffBetweenPlannedViews:true,pre70WorkerDecodeAnd73OffPreserved:true,noBuildsLaunchesOrTests:true,rootReviewRequiredBeforeAnyTest:true}};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({directory,manifestSHA256:sha(read(path.join(directory,'manifest.json'))),commonPoolSHA256:sha(pool),helperSHA256:sha(helper),hunks:hunks.length,noBuildsLaunchesOrTests:true},null,2));
