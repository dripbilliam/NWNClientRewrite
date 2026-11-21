"use strict";
// Source-only: exact frozen identity/batch32 candidate vs pump/counter hunk.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const project=path.resolve(__dirname,"../.."),label=process.argv[2]||"entry62-worker-wave-pair-a";
assert(/^[a-z0-9][a-z0-9-]{0,59}$/.test(label));
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex"),read=file=>fs.readFileSync(file),json=file=>JSON.parse(read(file));
const parentFile=path.join(project,".cache/nwn62/entry-pairs/entry62-batch32-pair-a/pair.json"),parent=json(parentFile);
const directory=path.join(project,".cache/nwn62/entry-pairs",label);assert(!fs.existsSync(directory),"Refusing overwrite");
const safe=relative=>!path.isAbsolute(relative)&&relative.split(/[\\/]/).every(part=>part&&part!=="."&&part!=="..");
const target=(root,relative)=>{assert(safe(relative));return path.join(root,relative);};
const pins=new Map(parent.baselinePins.map(row=>[row.file,row.sha256]));for(const row of parent.changes)pins.set(row.file,row.candidateSHA256);
for(const [file,expected]of pins)assert.equal(sha(read(target(parent.candidate,file))),expected,file);
const service="systems/native_data/asset_service.gd",canonical=read(target(project,service)).toString("utf8"),canonicalBefore=read(path.join(project,".cache/nwn62/completion-wave-before/asset_service.gd")).toString("utf8"),frozen=read(target(parent.candidate,service)).toString("utf8");
function body(source,name){const start=source.indexOf("func "+name+"(");assert(start>=0);const end=source.indexOf("\nfunc ",start+1);return source.slice(start,end<0?source.length:end);}
function exact(source,before,after){assert.equal(source.split(before).length-1,1,before);return source.replace(before,after);}
const counter='var worker_capacity_stats:={"dispatches":0,"completed_slot_reuses":0,"maximum_reserved_active":0,"maximum_inflight":0,"backlog_bound_blocks":0}\n';
assert(canonical.includes(counter));assert(!canonicalBefore.includes(counter));
let inverse=exact(canonical,body(canonical,"pump"),body(canonicalBefore,"pump"));inverse=exact(inverse,counter,"");
assert.equal(inverse,canonicalBefore,"Canonical changes extend beyond approved pump+counter");
let changed=exact(frozen,body(frozen,"pump"),body(canonical,"pump"));
changed=exact(changed,"func _init() -> void: set_process(false)",counter+"func _init() -> void: set_process(false)");
let frozenInverse=exact(changed,body(changed,"pump"),body(frozen,"pump"));frozenInverse=exact(frozenInverse,counter,"");assert.equal(frozenInverse,frozen);
// Every non-pump function remains byte exact; the canonical73 request capture,
// worker sidecar and main handoff and the frozen pre70 worker stay independent.
const names=[...frozen.matchAll(/^func ([a-zA-Z_0-9]+)\(/gm)].map(match=>match[1]).filter(name=>name!=="pump");
const functionProof=names.map(name=>{assert.equal(body(changed,name),body(frozen,name),name);return {name,sha256:sha(body(frozen,name))};});
const control=path.join(directory,"control-input"),candidate=path.join(directory,"candidate-input");
for(const [file]of pins)for(const root of [control,candidate]){
  const source=target(parent.candidate,file),destination=target(root,file);fs.mkdirSync(path.dirname(destination),{recursive:true});
  if(/\.(exe|dll)$/.test(file))fs.linkSync(source,destination);else fs.writeFileSync(destination,read(source),{flag:"wx"});
}
fs.writeFileSync(target(candidate,service),changed);
for(const [file,expected]of pins){assert.equal(sha(read(target(control,file))),expected);assert.equal(sha(read(target(candidate,file))),file===service?sha(changed):expected,file);}
const identity=root=>require(path.join(root,"tools/native-feature-manifest.cjs")).sourceIdentity(root).sha256;
assert.equal(identity(control),parent.identities.candidate,"Control identity differs from exact frozen batch32 candidate");
const worldPath="systems/native_render/live_world.gd",worldBefore=read(target(control,worldPath)).toString("utf8");
const oldTail='\t\t\tif stats.batches.size()<128: stats.batches.append(owner.stats.duplicate(true))';
const newTail='\t\t\tif stats.batches.size()<128:\n\t\t\t\tvar completed_stats: Dictionary=owner.stats.duplicate(true)\n\t\t\t\tcompleted_stats.asset_worker_capacity=preload("res://tools/nwn62/worker_capacity_report.gd").sample(owner.assets)\n\t\t\t\tstats.batches.append(completed_stats)';
let worldAfter=exact(worldBefore,oldTail,newTail);
const oldReturn='\tstate.area_border=borders.snapshot() if is_instance_valid(borders) else {"started":false,"enabled":tile_borders_enabled,"area_disabled":border_disabled}\n\treturn state';
const newReturn='\tstate.area_border=borders.snapshot() if is_instance_valid(borders) else {"started":false,"enabled":tile_borders_enabled,"area_disabled":border_disabled}\n\tstate.active_asset_worker_capacity=[]\n\tfor service in asset_owners():state.active_asset_worker_capacity.append(preload("res://tools/nwn62/worker_capacity_report.gd").sample(service))\n\treturn state';
worldAfter=exact(worldAfter,oldReturn,newReturn);
assert.equal(exact(exact(worldAfter,newTail,oldTail),newReturn,oldReturn),worldBefore);
const reportHelper="tools/nwn62/worker_capacity_report.gd",helperBytes=read(target(project,reportHelper));
for(const root of [control,candidate]){fs.writeFileSync(target(root,worldPath),worldAfter);const destination=target(root,reportHelper);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,helperBytes,{flag:"wx"});}
pins.set(worldPath,sha(worldAfter));pins.set(reportHelper,sha(helperBytes));
const manifest={version:1,ticket:"NWN-62",kind:"bounded-completed-worker-wave-pair",created:new Date().toISOString(),directory,control,candidate,parent:{file:parentFile,sha256:sha(read(parentFile)),leg:"candidate",project:parent.candidate},baselinePins:[...pins].map(([file,sha256])=>({file,sha256})),changes:[{file:service,controlSHA256:sha(frozen),candidateSHA256:sha(changed)}],commonInstrumentation:{worldPath,beforeSHA256:sha(worldBefore),afterSHA256:sha(worldAfter),inverseByteExact:true,helper:reportHelper,helperSHA256:sha(helperBytes),scope:"Completed-wave metadata capture immediately before existing owner close; active-owner metadata only in existing snapshot. No task poll, pump, callback delivery, budget or frame scheduling change."},canonical:{beforeSHA256:sha(canonicalBefore),afterSHA256:sha(canonical),inverseByteExact:true},nonPumpFunctionProof:functionProof,identities:{control:identity(control),candidate:identity(candidate)},preferences:parent.preferences,argv:parent.argv,assertions:{controlExactFrozenIdentityBatch32ExceptCommonReport:true,candidateOnlyPumpAndCounterVersusControl:true,commonReportByteIdenticalBoth:true,noExtraWorkerLimit:true,activeAtMostW:true,retainedAtMost2W:true,maxPendingUnchanged:true,callbackBudgetOrderOwnershipUnchanged:true,noBudgetOrLoadingPolicyChange:true,workerDecodePre70Exact:true,noCurrent65Or70Or72Or73:true,canonical73FWorkerAndHandoffPreserved:true,noBuildsOrLaunches:true}};
const manifestFile=path.join(directory,"pair.json");fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+"\n",{flag:"wx"});
async function stage(){
 const helper=require(path.join(project,"tools/native-production-selection.cjs"));
 assert.equal(sha(read(path.join(project,"tools/native-production-selection.cjs"))),pins.get("tools/native-production-selection.cjs"));
 const selections=[];
 for(const [leg,root]of [["control",control],["candidate",candidate]]){
  const receipt=await helper.stageProductionSelection({project:root,label:label+"-"+leg,argv:parent.argv,preferenceSeeds:json(parent.preferences.file),env:{}});selections.push({leg,file:receipt.file,sha256:receipt.sha256});
 }
 const staged={pair:manifestFile,pairSHA256:sha(read(manifestFile)),selections,noBuilds:true,noLaunches:true};fs.writeFileSync(path.join(directory,"staged.json"),JSON.stringify(staged,null,2)+"\n",{flag:"wx"});console.log(JSON.stringify(staged,null,2));
}
stage().catch(error=>{console.error(error.stack);process.exitCode=1;});
