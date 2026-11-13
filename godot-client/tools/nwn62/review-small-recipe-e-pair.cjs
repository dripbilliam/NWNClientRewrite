'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const stageFile=path.join(root,'.cache/nwn62/small-recipe-e-pair-a/staged.json');
const stage=JSON.parse(fs.readFileSync(stageFile));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert.deepEqual(stage.changed,['systems/native_render/model_template.gd','systems/native_render/native_model_recipe.gd']);
assert(stage.private&&!stage.accepted);
assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
for(const [mode,row] of Object.entries(stage.selections)){
 const selection=JSON.parse(fs.readFileSync(row.file));
 assert.equal(sha(row.file),row.sha256);
 assert.equal(selection.mainSourceIdentity.sha256,row.sourceSignature);
 assert.equal(selection.runtime.executableSha256,stage.engineSha256);
 assert.deepEqual(selection.options,JSON.parse(fs.readFileSync(stage.selections.control.file)).options);
 assert.equal(selection.profiling,'true');
 if(mode==='control')for(const file of stage.changed){
  const original=JSON.parse(fs.readFileSync(stage.privateSourceReceipt));
  const pin=file.endsWith('model_template.gd')?original.template.beforeSha256:original.recipe.beforeSha256;
  assert.equal(sha(path.join(selection.sourceProject,file)),pin);
 }
}
const order=['candidate-1','control-1','control-2','candidate-2'];
const allowed=new Set(["ERROR: Can't create shader cache folder, no shader caching will happen: user://",'ERROR: Failed to read the root certificate store.']);
const rows=order.map(name=>{
 const mode=name.startsWith('candidate')?'candidate':'control';
 const base=`nwn62-small-recipe-e-${name}`;
 const reportFile=path.join(root,'reports',base+'.json');
 const report=JSON.parse(fs.readFileSync(reportFile));
 const native=report.native,world=native.world,pool=world.pool,frame=native.frame_intervals;
 const log=fs.readFileSync(path.join(root,'reports',base+'.engine.log'),'utf8');
 const errors=log.split(/\r?\n/).filter(line=>line.startsWith('ERROR: '));
 assert.equal(report.productionSelection?.sourceSignature,stage.selections[mode].sourceSignature);
 assert(report.sourceUnchanged&&report.runtimeUnchanged&&report.driverUnchanged);
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(report.profilingMatched,true);
 assert.equal(native.success,true);assert.equal(world.area_id,2147618622);
 assert.equal(world.entities,1918);assert.equal(native.object_visuals_complete,true);
 assert(world.drive_collision.ready&&world.base_scenery.known_base_complete);
 assert.equal(world.base_scenery.resolved,1784);assert.equal(world.base_scenery.pending,0);assert.equal(world.base_scenery.failed,0);
 assert.deepEqual(world.errors,[]);assert.deepEqual(world.object_errors,[]);assert.deepEqual(world.failed_objects,{});
 assert(native.performance_window.steady&&native.performance_window.elapsed_ms>=5000);
 assert(errors.length===2&&errors.every(line=>allowed.has(line)),`${name}: engine errors`);
 assert(!/(SCRIPT ERROR|FATAL|leaked|still in use)/i.test(log),`${name}: script/lifetime error`);
 assert.equal(report.failure,'Native engine/lifetime diagnostics observed');
 const profiles=fs.readFileSync(path.join(root,'reports',base+'.performance.jsonl'),'utf8').trim().split(/\r?\n/).map(JSON.parse);
 const maximum=metric=>Math.max(...profiles.map(row=>row.frame_profile?.metrics?.[metric]?.max??0));
 const construction=pool.template_construction;
 if(mode==='candidate'){
  assert(construction.packed_templates_built>0);
  assert(construction.recipe_templates_built>0);
  assert.equal(construction.recipe_templates_built+construction.packed_templates_built,pool.templates_created);
 }
 const topDiagnostic=pool.template_diagnostic_peaks?.[0]??null;
 return {name,mode,reportSha256:sha(reportFile),sourceSignature:report.productionSelection.sourceSignature,world:{entities:world.entities,baseResolved:world.base_scenery.resolved,baseExpected:world.base_scenery.expected,meshesCreated:pool.meshes_created,texturesCreated:pool.textures_created},entry:{playableMs:world.playable_ms,baseKnownCompleteMs:world.base_scenery.first_known_complete_ms},frame:{meanMs:frame.average_ms,medianMs:frame.median_ms,p95Ms:frame.p95_ms,p99Ms:frame.p99_ms,worstMs:frame.worst_ms,count:frame.count},profile:{maxSmallPackedMs:maximum('publication_template_small_pack_ms'),maxTemplateStepMs:maximum('publication_template_step_ms'),maxTerrainCallbackMs:maximum('callback_terrain'),maxAssetCallbackMs:maximum('callback_assets')},construction:{templates:pool.templates_created,recipeTemplates:construction.recipe_templates_built,packedTemplates:construction.packed_templates_built,recipeClones:construction.recipe_clones,packedClones:construction.packed_clones,fallbacks:construction.recipe_capture_fallbacks,fallbackReasons:construction.recipe_fallback_reasons??{}},topDiagnostic:topDiagnostic?{model:topDiagnostic.model,phaseMaxUs:topDiagnostic.phase_max_us,stepUs:topDiagnostic.step?.step_us}:null,engineErrors:errors};
});
const diff=(candidate,control)=>({meanMs:candidate.frame.meanMs-control.frame.meanMs,p95Ms:candidate.frame.p95Ms-control.frame.p95Ms,firstPlayableMs:candidate.entry.playableMs-control.entry.playableMs,baseCompleteMs:candidate.entry.baseKnownCompleteMs-control.entry.baseKnownCompleteMs});
const first=diff(rows[0],rows[1]),second=diff(rows[3],rows[2]);
const average=Object.fromEntries(Object.keys(first).map(key=>[key,(first[key]+second[key])/2]));
const result={issue:'NWN-62',private:true,accepted:false,stageSha256:sha(stageFile),engineSha256:stage.engineSha256,recordingSha256:stage.recordingSha256,changed:stage.changed,order,rows,pairedCandidateMinusControl:{first,second,average},assessment:'Selective E routes authored-light small templates through recipe and leaves other small templates packed. Evaluate measured publication tail, full loading, frame intervals, and scene completeness before any promotion.',limitations:['The profiler-on original-scene replay is offline, not live Arelith acceptance.','Screenshots cover one recorded view and do not prove complete visual equivalence.','The strict driver exits 1 for the same known sandbox shader-cache and root-certificate diagnostics in every leg, despite native world success.']};
const output=path.join(root,'.cache/nwn62/small-recipe-e-pair-a/matrix-review.json');
assert(!fs.existsSync(output));fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({file:output,sha256:sha(output),paired:result.pairedCandidateMinusControl,packMax:rows.map(row=>({name:row.name,packed:row.profile.maxSmallPackedMs,step:row.profile.maxTemplateStepMs,terrain:row.profile.maxTerrainCallbackMs})),accepted:false}));
