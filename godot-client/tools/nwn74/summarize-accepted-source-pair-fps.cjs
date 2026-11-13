'use strict';
// Run after the coordinator's exclusive ABBA pair. Preserve raw diagnostics.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),scope=path.join(root,'.cache/nwn74/fps-pair-f');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const planFile=path.join(scope,'plan.json'),plan=JSON.parse(fs.readFileSync(planFile));
assert.equal(plan.kind,'matched-private-normal-client-fps-pair');
assert.deepEqual(plan.sequence.map(x=>x.mode),['control','candidate','candidate','control']);
const rows=[];
for(const entry of plan.sequence){
 const reportFile=path.join(root,'reports',entry.run+'.json'),receiptFile=path.join(scope,entry.run+'.receipt.json');
 const report=JSON.parse(fs.readFileSync(reportFile)),receipt=JSON.parse(fs.readFileSync(receiptFile));
 assert.equal(receipt.reportSha256,sha(reportFile));assert.equal(receipt.mode,entry.mode);assert.equal(receipt.engineSha256,plan.engines[entry.mode].engineSha256);
 assert.equal(receipt.selectionSha256,plan.selection.sha256);assert.equal(receipt.captureSha256,plan.capture.sha256);
 assert.equal(receipt.haltReason,null);assert.equal(receipt.sourceUnchanged,true);assert.equal(receipt.runtimeUnchanged,true);
 const native=report.native??{},frame=native.frame_intervals??{},window=native.performance_window??{},view=window.view_begin??{};
 assert.equal(window.steady,true);assert(window.elapsed_ms>=10000,'Steady BASE window too short');
 assert(frame.count>=500,'Too few frame intervals');
 assert.equal(view.detailed_profiling,false);assert.equal(view.maximum_fps,0);assert.equal(view.vsync,0);
 assert.deepEqual(view.viewport,[3440,1369]);assert.equal(view.settings?.compact_scenery_enabled,true);
 for(const key of ['average_ms','median_ms','p95_ms','p99_ms','worst_ms'])assert(Number.isFinite(frame[key])&&frame[key]>0,'Missing '+key);
 const ready=report.milestones?.find(x=>x.kind==='area-ready');assert(ready&&ready.areaId===window.areaId&&Number.isFinite(ready.elapsedMs));
 const fpsFile=receipt.fpsObservations?.file;assert(fpsFile&&sha(fpsFile)===receipt.fpsObservations.sha256);
 const fpsRows=fs.readFileSync(fpsFile,'utf8').trim().split(/\r?\n/).map(JSON.parse).filter(x=>x.elapsedMs>=window.started_at_ms&&x.elapsedMs<=window.started_at_ms+window.elapsed_ms&&x.ready===true&&Number.isFinite(x.fps));
 rows.push({run:entry.run,mode:entry.mode,rawSuccess:report.success,rawFailure:report.failure??null,engineSha256:receipt.engineSha256,reportSha256:receipt.reportSha256,readyArea:ready.areaId,entryAreaReadyMs:ready.elapsedMs,steadyMs:window.elapsed_ms,intervals:frame.count,meanFrameMs:frame.average_ms,medianFrameMs:frame.median_ms,p95FrameMs:frame.p95_ms,p99FrameMs:frame.p99_ms,worstFrameMs:frame.worst_ms,derivedMeanFps:1000/frame.average_ms,rollingFpsSamples:fpsRows.length,rollingFpsMean:fpsRows.length?fpsRows.reduce((a,x)=>a+x.fps,0)/fpsRows.length:null,view:{viewport:view.viewport,msaa3d:view.msaa_3d,vsync:view.vsync,maximumFps:view.maximum_fps,detailedProfiling:view.detailed_profiling,particlesEnabled:view.settings?.particles_enabled,particleCollisionEnabled:view.settings?.particle_collision_enabled}});
}
assert(rows.every(x=>JSON.stringify(x.view)===JSON.stringify(rows[0].view)),'Render settings differ across pair');
const byMode={};for(const mode of ['control','candidate']){
 const items=rows.filter(x=>x.mode===mode);const avg=key=>items.reduce((a,x)=>a+x[key],0)/items.length;
 byMode[mode]={runs:items.map(x=>x.run),entryAreaReadyMs:avg('entryAreaReadyMs'),meanFrameMs:avg('meanFrameMs'),medianFrameMs:avg('medianFrameMs'),p95FrameMs:avg('p95FrameMs'),p99FrameMs:avg('p99FrameMs'),worstFrameMs:avg('worstFrameMs'),derivedMeanFps:avg('derivedMeanFps')};
}
const comparison={candidateMinusControlMeanFrameMs:byMode.candidate.meanFrameMs-byMode.control.meanFrameMs,candidateMinusControlEntryMs:byMode.candidate.entryAreaReadyMs-byMode.control.entryAreaReadyMs,candidateOverControlFpsRatio:byMode.candidate.derivedMeanFps/byMode.control.derivedMeanFps};
const output={issue:'NWN-74',scope:'Private same-source ABBA normal-client FPS pair; do not promote accepted engine from this result alone because the control rebuild included 25 pending TUs',plan:planFile,planSha256:sha(planFile),rows,byMode,comparison,strictAllPassed:rows.every(x=>x.rawSuccess===true)};
const file=path.join(root,'reports/nwn74-guard-fps-pair-f-summary.json');assert(!fs.existsSync(file),'Preserve prior summary');fs.writeFileSync(file,JSON.stringify(output,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(file),strictAllPassed:output.strictAllPassed,byMode,comparison},null,2));
