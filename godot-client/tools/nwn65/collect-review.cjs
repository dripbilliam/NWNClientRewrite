'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const read=r=>JSON.parse(fs.readFileSync(path.join(project,r),'utf8'));
const pin=r=>{const bytes=fs.readFileSync(path.join(project,r));return {relative:r,bytes:bytes.length,sha256:sha(bytes)};};
const verified=r=>{const o=read(r);assert(o.success===true||o.passed===true,r);return {evidence:pin(r),checks:o.checks};};
const idle=read('.cache/nwn65/idle-cost-a.json');assert(idle.success&&idle.checks===9&&idle.eligible_owners===80);
assert.deepEqual(idle.legs.map(row=>row.mode),['reference','optimized','optimized','reference']);
assert.equal(idle.legs.reduce((sum,row)=>sum+row.reference_callbacks,0),26880);assert(idle.legs.every(row=>row.optimized_callbacks===0));
const current=require(path.join(project,'tools/native-performance-runtime.cjs')).acceptedRenderCore();
assert.equal(current.engineSha256,'753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b');
const sourceFiles=['systems/model_rigs.gd','systems/native_render/skeletal_rigs.gd'];
const testFiles=['tests/nwn65_rig_scheduling_test.gd','tests/nwn65_rig_idle_cost_test.gd','tests/nwn65_rig_components_test.gd','tests/nwn65_rig_modifier_test.gd','tests/nwn65_rig_skin_publisher_test.gd','tests/nwn65_rig_skin_continuation_test.gd','tests/nwn65_rig_skin_lifetime_test.gd','tests/nwn65_rig_skin_gpu_test.gd'];
const candidateD=['rig_skin_publisher','rig_skin_continuation','rig_components','rig_modifier','rig_skin_lifetime','rig_scheduling'].map(name=>verified('.cache/nwn65/v2-'+name+'-a.json'));
candidateD.push(verified('.cache/nwn65/gpu-v2-a.json'));
assert.equal(candidateD.reduce((sum,row)=>sum+row.checks,0),267);
const timings=names=>names.map(name=>{const r='.cache/nwn65/'+name+'.json',o=read(r);assert(o.success);return {evidence:pin(r),benchmark:o.benchmark};});
const report={version:1,issue:'NWN-65',readyForReview:true,completeIssueScope:false,created:new Date().toISOString(),
 acceptedSourceChange:{description:'Suspend only fully static rigid rig owners with no animated model, manual pose, attachment or skin work. Wake on normal configure/adoption/manual/native owner changes; retain active-owner callback order and explicit process pauses.',sources:sourceFiles.map(pin),
 baseline:['.cache/nwn65/baseline/model_rigs.gd','.cache/nwn65/baseline/skeletal_rigs.gd'].map(pin),
 correctness:[verified('.cache/nwn65/scheduling-d.json'),verified('.cache/nwn65/animation-work-a.json')],
 performance:{evidence:pin('.cache/nwn65/idle-cost-a.json'),order:'A-B-B-A',eligibleOwners:80,referenceCallbacks:26880,optimizedCallbacks:0,legs:idle.legs,
 scope:'Actual SceneTree callback-window CPU component saving for this explicit eligible population; no census of the user capture, whole-frame FPS or loading-latency claim.'}},
 unselectedNativeExperiments:[
 {revision:'C',build:pin('.cache/native-render-gap/scene/nwn65-engine-c/receipt.json'),proposal:pin('.cache/nwn65/engine-proposal.json'),selected:false,description:'Exact fused component setters; roughly3% lower publication median in initial matched fixture; narrow saving, not promoted.',timing:timings(['timing-a1','timing-b1','timing-b2','timing-a2'])},
 {revision:'D',build:pin('.cache/native-render-gap/scene/nwn65-engine-d/receipt.json'),proposal:pin('.cache/nwn65/engine-proposal-v2.json'),selected:false,description:'Fused setters plus invocation-local proved Node/Skeleton checks. Correctness passed but stationary timing regressed/varied; rejected for selection.',correctness:candidateD,timing:timings(['timing-v2-a1','timing-v2-b1','timing-v2-b2','timing-v2-a2'])}],
 testSources:testFiles.map(pin),normalEngineSha256:current.engineSha256,normalEngineUnchanged:true,
 remaining:'Animated-rig callback batching and substantial publication-cost reduction remain unresolved. No live Arelith/FPS or loading-latency measurement; reviewer must not treat this partial idle-owner optimization as completion of the entire original ticket.',
 handoff:'Root independently verifies and sets Linear In Review. Production rigs files transfer next to NWN-62 resumable-publication worker; no direct shared-file/native selector edits were made by this worker.'};
const out='.cache/nwn65/review.json';fs.writeFileSync(path.join(project,out),JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({success:true,report:pin(out),productionSources:report.acceptedSourceChange.sources,remaining:report.remaining}));
