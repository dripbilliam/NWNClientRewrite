'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const stageFile=path.join(root,'.cache/nwn62/worker-texture-pair-c/staged.json');
const stage=JSON.parse(fs.readFileSync(stageFile));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
assert.deepEqual(stage.changed,['project.godot']);
assert(stage.private&&!stage.accepted);
assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
for(const [mode,selection] of Object.entries(stage.selections)){
 const selected=JSON.parse(fs.readFileSync(selection.file));
 assert.equal(sha(selection.file),selection.sha256);
 assert.equal(selected.mainSourceIdentity.sha256,selection.sourceIdentity);
 for(const [file,pin] of [
  ['systems/native_data/asset_service.gd',stage.sourcePins.assetService],
  ['systems/native_data/raster_upload_preparation.gd',stage.sourcePins.rasterUpload],
  ['systems/native_render/resource_pool.gd',stage.sourcePins.resourcePool],
 ])assert.equal(sha(path.join(selected.sourceProject,file)),pin,`${mode}: ${file}`);
}
const names=['candidate','control','control-2','candidate-2'];
const rows=names.map(name=>{
 const mode=name.startsWith('candidate')?'candidate':'control';
 const file=path.join(root,'reports',`nwn62-worker-texture-c-${name}.json`);
 const report=JSON.parse(fs.readFileSync(file));
 const world=report.native?.world;
 const pool=world?.pool;
 const frame=report.native?.frame_intervals;
 const log=fs.readFileSync(path.join(root,'reports',`nwn62-worker-texture-c-${name}.engine.log`),'utf8');
 const errors=log.split(/\r?\n/).filter(line=>line.startsWith('ERROR: '));
 const allowed=new Set(["ERROR: Can't create shader cache folder, no shader caching will happen: user://",'ERROR: Failed to read the root certificate store.']);
 assert(report.sourceUnchanged&&report.runtimeUnchanged,`${name}: source/runtime drift`);
 assert.equal(report.productionSelection?.sourceSignature,stage.selections[mode].sourceIdentity);
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(report.profilingMatched,true);
 assert.equal(world.area_id,2147618622);
 assert.equal(world.entities,1918);
 assert(world.drive_collision.ready&&world.base_scenery.known_base_complete);
 assert.equal(world.base_scenery.resolved,1784);
 assert.equal(world.base_scenery.pending,0);
 assert.equal(world.base_scenery.failed,0);
 assert.deepEqual(world.errors,[]);
 assert.deepEqual(world.failed_objects,{});
 assert(report.native.performance_window.steady&&report.native.performance_window.elapsed_ms>=5000);
 assert.equal(pool.worker_texture_creation?.enabled===true,mode==='candidate');
 if(mode==='candidate'){
  assert.equal(pool.worker_texture_creation.memo.builds,626);
  assert(pool.worker_texture_creation.memo.redundant_skips>2900);
  assert.equal(pool.worker_texture_creation.memo.failures,0);
  assert.equal(pool.raster_upload_preparation.counts.invalid_packets,0);
  assert.equal(pool.raster_upload_preparation.counts.invalid_sidecars,0);
 }
 assert(errors.length===2&&errors.every(line=>allowed.has(line)),`${name}: engine diagnostics`);
 assert(!/(SCRIPT ERROR|FATAL|leaked|still in use)/i.test(log),`${name}: script/lifetime error`);
 assert.equal(report.failure,'Native engine/lifetime diagnostics observed');
 const windows=fs.readFileSync(path.join(root,'reports',`nwn62-worker-texture-c-${name}.performance.jsonl`),'utf8').trim().split(/\r?\n/).map(JSON.parse);
 const maximum=metric=>Math.max(...windows.map(row=>row.frame_profile?.metrics?.[metric]?.max??0));
 return {name,mode,report:file,sha256:sha(file),world:{entities:world.entities,baseResolved:world.base_scenery.resolved,baseExpected:world.base_scenery.expected},entry:{playableMs:world.playable_ms,baseKnownCompleteMs:world.base_scenery.first_known_complete_ms},frame:{meanMs:frame.average_ms,medianMs:frame.median_ms,p95Ms:frame.p95_ms,p99Ms:frame.p99_ms,worstMs:frame.worst_ms,count:frame.count},profile:{maxAssetCallbackMs:maximum('callback_assets'),maxTexturePublicationMs:maximum('publication_texture_cpu_ms')},textures:{created:pool.textures_created,workerUsed:pool.worker_textures_used??0,workerMemo:pool.worker_texture_creation?.memo??null}};
});
const delta=(candidate,control)=>({meanMs:candidate.frame.meanMs-control.frame.meanMs,p95Ms:candidate.frame.p95Ms-control.frame.p95Ms,baseMs:candidate.entry.baseKnownCompleteMs-control.entry.baseKnownCompleteMs});
const first=delta(rows[0],rows[1]),second=delta(rows[3],rows[2]);
const result={issue:'NWN-62',private:true,accepted:false,stageSha256:sha(stageFile),order:names,sourcePins:stage.sourcePins,engineSha256:stage.engineSha256,recordingSha256:stage.recordingSha256,changed:stage.changed,rows,pairedCandidateMinusControl:{first,second,averageMeanMs:(first.meanMs+second.meanMs)/2,averageP95Ms:(first.p95Ms+second.p95Ms)/2,averageBaseMs:(first.baseMs+second.baseMs)/2},assessment:'Candidate reduces speculative worker GPU creation, but has no repeatable profiled frame benefit and delays known-base completion in both pairs. Keep default off; do not promote.',limitations:['Profiling changes work scheduling; worker textures were not used in these profiled legs despite candidate worker creation. The earlier unprofiled pair did use worker textures.','Two profiler-on pairs are not live Arelith behavior or exact pixel parity.','Known shader-cache and root-certificate diagnostics force strict driver failure despite complete scenes.']};
const output=path.join(root,'.cache/nwn62/worker-texture-pair-c/matrix-review.json');
assert(!fs.existsSync(output),'Preserve earlier review');
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({file:output,sha256:sha(output),paired:result.pairedCandidateMinusControl,workerBuilds:rows.filter(row=>row.mode==='candidate').map(row=>row.textures.workerMemo.builds),accepted:false}));
