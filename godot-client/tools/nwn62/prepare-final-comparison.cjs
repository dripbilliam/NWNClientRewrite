"use strict";
// Proposal/source staging only. Compare one pre62 cohort with the final62 stack,
// keeping audited61 entry, worker/decode inputs, preferences and binaries fixed.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const project=path.resolve(__dirname,"../.."),[operation="prepare",label="entry62-final-proposal-a"]=process.argv.slice(2);
assert(["prepare","stage"].includes(operation));assert(/^[a-z0-9][a-z0-9-]{0,59}$/.test(label));
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex"),read=file=>fs.readFileSync(file),json=file=>JSON.parse(read(file));
const safe=relative=>!path.isAbsolute(relative)&&relative.split(/[\\/]/).every(part=>part&&part!=="."&&part!=="..");
const target=(root,relative)=>{assert(safe(relative));return path.join(root,relative);};
const directory=path.join(project,".cache/nwn62/entry-pairs",label),manifestFile=path.join(directory,"proposal.json");
function exact(source,before,after){assert.equal(source.split(before).length-1,1,before);return source.replace(before,after);}
function body(source,name){const start=source.indexOf("func "+name+"(");assert(start>=0);const end=source.indexOf("\nfunc ",start+1);return source.slice(start,end<0?source.length:end);}
function validate(root,pins){for(const [file,hash]of pins)assert.equal(sha(read(target(root,file))),hash,file);}
function copyPins(from,to,pins){for(const [file]of pins){const source=target(from,file),destination=target(to,file);fs.mkdirSync(path.dirname(destination),{recursive:true});if(/\.(exe|dll)$/.test(file))fs.linkSync(source,destination);else fs.writeFileSync(destination,read(source),{flag:"wx"});}}
function commonReport(world){
 const old='\t\t\tif stats.batches.size()<128: stats.batches.append(owner.stats.duplicate(true))';
 const next='\t\t\tif stats.batches.size()<128:\n\t\t\t\tvar completed_stats: Dictionary=owner.stats.duplicate(true)\n\t\t\t\tcompleted_stats.asset_worker_capacity=preload("res://tools/nwn62/worker_capacity_report.gd").sample(owner.assets)\n\t\t\t\tstats.batches.append(completed_stats)';
 const oldReturn='\tstate.area_border=borders.snapshot() if is_instance_valid(borders) else {"started":false,"enabled":tile_borders_enabled,"area_disabled":border_disabled}\n\treturn state';
 const nextReturn='\tstate.area_border=borders.snapshot() if is_instance_valid(borders) else {"started":false,"enabled":tile_borders_enabled,"area_disabled":border_disabled}\n\tstate.active_asset_worker_capacity=[]\n\tfor service in asset_owners():state.active_asset_worker_capacity.append(preload("res://tools/nwn62/worker_capacity_report.gd").sample(service))\n\treturn state';
 const patched=exact(exact(world,old,next),oldReturn,nextReturn);assert.equal(exact(exact(patched,next,old),nextReturn,oldReturn),world);return patched;
}
function prepare(){
 assert(!fs.existsSync(directory),"Fresh proposal label required");
 const baselineFile=path.join(project,".cache/nwn62/entry-pairs/entry62-v4-pair-a/pair.json"),baseline=json(baselineFile);
 const latestFile=path.join(project,".cache/nwn62/entry-pairs/entry62-direct-material-pair-a/pair.json"),latest=json(latestFile);
 const oldPins=new Map(baseline.baseline.pins.map(row=>[row.file,row.sha256]));oldPins.set(baseline.commonInfrastructure.file,baseline.commonInfrastructure.sha256);
 const newPins=new Map(latest.baselinePins.map(row=>[row.file,row.sha256]));for(const row of latest.changes)newPins.set(row.file,row.candidateSHA256);
 validate(baseline.control,oldPins);validate(latest.candidate,newPins);
 const identity=root=>require(path.join(root,"tools/native-feature-manifest.cjs")).sourceIdentity(root).sha256;
 assert.equal(identity(baseline.control),"a5ca5f67698d5d72f484e7153467163780eddd6c3bc2e5b4c343237bde7bf58c");assert.equal(identity(latest.candidate),latest.identities.candidate);
 assert.deepEqual(baseline.argv,latest.argv);
 const service="systems/native_data/asset_service.gd",world="systems/native_render/live_world.gd",pool="systems/native_render/resource_pool.gd";
 const oldService=read(target(baseline.control,service)).toString("utf8"),newService=read(target(latest.candidate,service)).toString("utf8");
 const workerSlice=text=>text.slice(text.indexOf("func _work("),text.indexOf("func _process("));
 assert.equal(workerSlice(oldService),workerSlice(newService),"Candidate worker/decode is not exact pre70");
 assert(!newService.includes("RasterUpload")&&!oldService.includes("RasterUpload"),"73 must be excluded symmetrically");
 // The approved no-dispatch early return is the only post-freeze pump delta.
 const canonical=read(target(project,service)).toString("utf8"),accepted=read(path.join(project,".cache/nwn62/completion-wave-accepted/asset_service.gd")).toString("utf8");
 const guard="\tif closed or pending.is_empty():_refresh_processing();return\n";
 assert.equal(exact(canonical,guard,""),accepted,"Canonical AS changed beyond approved early-return");
 assert.equal(body(newService,"pump"),body(accepted,"pump"));
 const finalService=exact(newService,body(newService,"pump"),body(canonical,"pump"));assert.equal(workerSlice(oldService),workerSlice(finalService));
 const oldComment="\t\t# The native route publishes only its final ShaderMaterial. A temporary\n\t\t# StandardMaterial used as a property bag creates an unused render RID.";
 const newComment="\t\t# Publish only the final ShaderMaterial. Avoid the unused StandardMaterial\n\t\t# CPU property bag; backend material resources are allocated lazily.";
 const sourcePool=read(target(latest.candidate,pool)).toString("utf8"),finalPool=exact(sourcePool,oldComment,newComment);
 const originalProject=read(target(baseline.control,"project.godot")),candidateProject=read(target(latest.candidate,"project.godot"));
 const eol=originalProject.toString("utf8").includes("\r\n")?"\r\n":"\n";
 let expectedProject=originalProject.toString("utf8");
 if(expectedProject.includes("[nwn]"+eol))expectedProject=exact(expectedProject,"[nwn]"+eol,"[nwn]"+eol+"private/publication_entry_budget_us=0"+eol);
 else expectedProject+=eol+"[nwn]"+eol+eol+"private/publication_entry_budget_us=0"+eol;
 assert.equal(candidateProject.toString("utf8"),expectedProject,"Unexpected candidate project setting difference");
 const oldWorld=read(target(baseline.control,world)).toString("utf8"),commonOldWorld=commonReport(oldWorld);
 const reportHelper=latest.commonInstrumentation.helper,reportBytes=read(target(latest.candidate,reportHelper));assert.equal(sha(reportBytes),latest.commonInstrumentation.helperSHA256);
 const frozen61=json(path.join(project,".cache/nwn61/review-b/manifest.json"));
 for(const row of frozen61.files.filter(row=>row.file!==world))if(oldPins.has(row.file)&&newPins.has(row.file))assert.equal(oldPins.get(row.file),newPins.get(row.file),"61 source mismatch: "+row.file);
 const wrappers=text=>text.slice(text.indexOf("func begin_received_snapshot("),text.indexOf("func receive(objects: Array,controlled: int) -> void:"));
 assert.equal(wrappers(oldWorld),wrappers(read(target(latest.candidate,world)).toString("utf8")),"61 wrappers differ");
 const control=path.join(directory,"control-input"),candidate=path.join(directory,"candidate-input");copyPins(baseline.control,control,oldPins);copyPins(latest.candidate,candidate,newPins);
 const put=(root,file,bytes,pins)=>{const destination=target(root,file);fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,bytes);pins.set(file,sha(bytes));};
 put(control,world,commonOldWorld,oldPins);put(control,reportHelper,reportBytes,oldPins);
 put(candidate,service,finalService,newPins);put(candidate,pool,finalPool,newPins);put(candidate,"project.godot",originalProject,newPins);
 validate(control,oldPins);validate(candidate,newPins);
 const changed=[];for(const [file,oldHash]of oldPins)if(newPins.has(file)&&newPins.get(file)!==oldHash)changed.push({file,controlSHA256:oldHash,candidateSHA256:newPins.get(file)});
 const added=[...newPins].filter(([file])=>!oldPins.has(file)).map(([file,sha256])=>({file,sha256}));
 assert.equal(sha(read(target(control,"project.godot"))),sha(read(target(candidate,"project.godot"))));
 assert.equal(sha(read(target(control,"systems/native_data/prework_store.gd"))),sha(read(target(candidate,"systems/native_data/prework_store.gd"))));
 const output={version:1,ticket:"NWN-62",kind:"final-comparison-source-only-proposal",created:new Date().toISOString(),directory,control,candidate,baseline:{file:baselineFile,sha256:sha(read(baselineFile)),leg:"control",identityBeforeCommonTail:baseline.identities.control,scope:"Exact pre62 construction/completion behavior with audited61 helper/wrappers and common report-only tail"},latest:{file:latestFile,sha256:sha(read(latestFile)),leg:"candidate",identityBeforeDeclaredDeltas:latest.identities.candidate,declaredPostFreezeDeltas:["Approved pump early-return; no dispatch/counter outcome change","CPU-temporary comment correction only","Remove fixed-zero experimental project setting so project bytes exactly equal control"]},pins:{control:[...oldPins].map(([file,sha256])=>({file,sha256})),candidate:[...newPins].map(([file,sha256])=>({file,sha256}))},changedExistingSource:changed,addedCandidateSource:added,commonReport:{helper:reportHelper,sha256:sha(reportBytes),controlWorldInverseByteExact:true,candidateWorldUnchanged:true,scope:"Finished-owner capture and report snapshot only; no task polls or frame/pump scheduling"},common61:{reviewSHA256:sha(read(path.join(project,".cache/nwn61/review-b/manifest.json"))),allSharedPinsExact:true,thinWrappersByteExact:true},workerDecode:{pre70ByteExact:true,sha256:sha(workerSlice(oldService))},thirdParty73:{included:false,settingAbsentBoth:true,scope:"No73 sidecar/helper/request/worker/upload code in either leg; canonical default-off73 integration remains intact outside this isolated comparison"},privateEntryPolicy:{projectBytesIdentical:true,settingAbsentBoth:true,ordinaryBudgetUs:3000,experimentalAllowanceEnabled:false,scope:"Candidate retains private reporting helper code, whose absent setting requests0; actual effective3000/zeroactivation must be checked"},preferences:baseline.preferences,argv:baseline.argv,identities:{control:identity(control),candidate:identity(candidate)},capture:{path:".cache/loading-benchmark-worlds/arelith-archive-shaders-v1",generation:4,scope:"Same verified derived7shader original recording; missing assets remain explicit, no live/Arelith completeness claim"},measurementProposal:{entry:"Matched fresh original-entry control/candidate in ONE cohort, fixed10/20s bounded observation as coordinator selects",required:["Strict terminal success and unchanged source/driver/runtime pins","Exact final protocol630/terrain121/knownbase553 plus failures/pending","First playable/terrain/fullknownbase latency, maximum actor/tile publication, loading frame tails","Actual W/2W event/peak metadata and direct_native_materials engagement","Effective ordinary3ms and zero entryallowance activation"],next:"Only if warranted, matched normal graphical/steady and visual comparison; no cross-cohort subtraction of earlier absolute load times"},assertions:{noWholeCanonical70Overlay:true,allWorkerDecodePre70:true,baselineAndCandidate61CommitSame:true,noCurrent65Or72Or73Experiments:true,originalArtifactsUntouched:true,noBuildsLaunchesTimings:true},stageCommand:`node tools/nwn62/prepare-final-comparison.cjs stage ${label}`};
 fs.writeFileSync(manifestFile,JSON.stringify(output,null,2)+"\n",{flag:"wx"});console.log(JSON.stringify({proposal:manifestFile,sha256:sha(read(manifestFile)),changed:changed.length,added:added.length,identities:output.identities,noLaunches:true,noStaging:true},null,2));
}
async function stage(){
 const proposal=json(manifestFile);for(const leg of ["control","candidate"])validate(proposal[leg],new Map(proposal.pins[leg].map(row=>[row.file,row.sha256])));
 const helperPath=path.join(project,"tools/native-production-selection.cjs"),expected=proposal.pins.control.find(row=>row.file==="tools/native-production-selection.cjs").sha256;assert.equal(sha(read(helperPath)),expected);
 const helper=require(helperPath),selections=[];for(const leg of ["control","candidate"]){const receipt=await helper.stageProductionSelection({project:proposal[leg],label:label+"-"+leg,argv:proposal.argv,preferenceSeeds:json(proposal.preferences.file),env:{}});selections.push({leg,file:receipt.file,sha256:receipt.sha256});}
 const output={proposal:manifestFile,proposalSHA256:sha(read(manifestFile)),selections,noBuilds:true,noLaunches:true};fs.writeFileSync(path.join(directory,"staged.json"),JSON.stringify(output,null,2)+"\n",{flag:"wx"});console.log(JSON.stringify(output,null,2));
}
if(operation==="prepare")prepare();else stage().catch(error=>{console.error(error.stack);process.exitCode=1;});
