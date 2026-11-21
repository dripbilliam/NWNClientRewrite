'use strict';
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const stage=JSON.parse(fs.readFileSync(path.join(root,'.cache/nwn62/worker-texture-pair-a/staged.json')));
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const expected=['candidate','control','control-2','candidate-2'];
assert(stage.private&&!stage.accepted&&stage.issue==='NWN-62');
assert.deepEqual(stage.changed,['project.godot']);
assert.equal(sha(path.join(stage.capture,'recording.json')),stage.recordingSha256);
const controlSelection=JSON.parse(fs.readFileSync(stage.selections.control.file));
const candidateSelection=JSON.parse(fs.readFileSync(stage.selections.candidate.file));
for(const [file,pin] of [['systems/native_data/asset_service.gd',stage.sourcePins.assetService],['systems/native_data/raster_upload_preparation.gd',stage.sourcePins.rasterUpload],['systems/native_render/resource_pool.gd',stage.sourcePins.resourcePool]]){
 assert.equal(sha(path.join(controlSelection.sourceProject,file)),pin,`Staged control source drift: ${file}`);
 assert.equal(sha(path.join(candidateSelection.sourceProject,file)),pin,`Staged candidate source drift: ${file}`);
}
const rows=[];
for(const name of expected){
 const file=path.join(root,'reports',`nwn62-worker-texture-a-${name}.json`);
 const report=JSON.parse(fs.readFileSync(file));
 const mode=name.startsWith('candidate')?'candidate':'control';
 const world=report.native?.world,pool=world?.pool,frame=report.native?.frame_intervals;
 assert(report.sourceUnchanged&&report.runtimeUnchanged);
 assert.equal(report.productionFeatures?.verification?.status,'observed');
 assert.equal(report.productionFeatures?.worldVerification?.status,'observed');
 assert.equal(report.productionWindowVerification?.status,'observed');
 assert.equal(world?.area_id,2147618622);
 assert.equal(world?.entities,1918);
 assert(world?.drive_collision?.ready&&world?.base_scenery?.known_base_complete);
 assert.equal(world.base_scenery.resolved,world.base_scenery.expected);
 assert.equal(world.base_scenery.pending,0);
 assert.equal(world.base_scenery.failed,0);
 assert.deepEqual(world.errors,[]);
 assert.deepEqual(world.failed_objects,{});
 assert(report.native?.performance_window?.steady&&report.native.performance_window.elapsed_ms>=5000);
 assert.equal(pool?.worker_texture_creation?.enabled===true,mode==='candidate');
 if(mode==='candidate'){
  assert(pool.worker_textures_used>0&&pool.worker_texture_creation.memo.builds>0);
  assert.equal(pool.worker_texture_creation.memo.failures,0);
  assert.equal(pool.raster_upload_preparation.counts.invalid_packets,0);
  assert.equal(pool.raster_upload_preparation.counts.invalid_sidecars,0);
 }else assert.equal(pool.worker_textures_used??0,0);
 const log=fs.readFileSync(path.join(root,'reports',`nwn62-worker-texture-a-${name}.engine.log`),'utf8');
 const errors=log.split(/\r?\n/).filter(line=>line.startsWith('ERROR: '));
 const allowed=new Set(["ERROR: Can't create shader cache folder, no shader caching will happen: user://",'ERROR: Failed to read the root certificate store.']);
 assert(errors.every(line=>allowed.has(line))&&errors.length===2,'Unexpected engine diagnostic');
 assert(!/(SCRIPT ERROR|FATAL|leaked|still in use)/i.test(log),'Script/lifetime error');
 assert.equal(report.failure,'Native engine/lifetime diagnostics observed');
 rows.push({name,mode,report:file,sha256:sha(file),world:{entities:world.entities,baseResolved:world.base_scenery.resolved,baseExpected:world.base_scenery.expected,failed:world.base_scenery.failed},entry:{playableMs:world.playable_ms,baseKnownCompleteMs:world.base_scenery.first_known_complete_ms},frame:{meanMs:frame.average_ms,medianMs:frame.median_ms,p95Ms:frame.p95_ms,p99Ms:frame.p99_ms,worstMs:frame.worst_ms,count:frame.count},textures:{created:pool.textures_created,hits:pool.texture_hits,workerUsed:pool.worker_textures_used??0,workerMemo:pool.worker_texture_creation?.memo??null,workerFallbacks:pool.raster_upload_preparation.counts.fallbacks}});
}
const first={meanMs:rows[0].frame.meanMs-rows[1].frame.meanMs,p95Ms:rows[0].frame.p95Ms-rows[1].frame.p95Ms,baseMs:rows[0].entry.baseKnownCompleteMs-rows[1].entry.baseKnownCompleteMs};
const second={meanMs:rows[3].frame.meanMs-rows[2].frame.meanMs,p95Ms:rows[3].frame.p95Ms-rows[2].frame.p95Ms,baseMs:rows[3].entry.baseKnownCompleteMs-rows[2].entry.baseKnownCompleteMs};
const result={issue:'NWN-62',private:true,accepted:false,order:expected,stageSha256:sha(path.join(root,'.cache/nwn62/worker-texture-pair-a/staged.json')),sourceIdentities:{control:stage.selections.control.sourceIdentity,candidate:stage.selections.candidate.sourceIdentity},engineSha256:stage.engineSha256,recordingSha256:stage.recordingSha256,changed:stage.changed,rows,pairedCandidateMinusControl:{first,second,averageMeanMs:(first.meanMs+second.meanMs)/2,averageP95Ms:(first.p95Ms+second.p95Ms)/2,averageBaseMs:(first.baseMs+second.baseMs)/2},limitations:['The driver classifies both known root-certificate and shader-cache errors as failure despite complete scenes; this is a diagnostic matrix, not strict acceptance.','The two repeat runs have different texture-creation counts; exact visual output and live Arelith behavior are not proven.','Only 5-second post-completion frame windows are compared; this does not quantify entry callback tail reduction.']};
const output=path.join(root,'.cache/nwn62/worker-texture-pair-a/matrix-review.json');
assert(!fs.existsSync(output),'Preserve prior matrix review');
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({file:output,sha256:sha(output),order:result.order,paired:result.pairedCandidateMinusControl,workerUsed:rows.filter(row=>row.mode==='candidate').map(row=>row.textures.workerUsed),success:true}));
