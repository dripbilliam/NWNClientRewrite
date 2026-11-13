'use strict';
const assert=require('node:assert/strict');
function verify(report,{helper,manifest}={}){
 const p=report.cameraProbe,n=report.native;assert(report.success===true&&report.exit===0&&report.sourceUnchanged===true&&report.runtimeUnchanged===true,'Original replay/closure acceptance failed');
 assert(report.timelineDelivered===true&&report.steadyCompleted===true&&n?.object_visuals_complete===true&&n?.protocol_finish_ack===true&&n.workers_remaining===0&&n.clean_exit===true);
 assert(helper&&manifest,'Exact private capability/feature proof required');assert(report.productionFeatures?.runtime?.executableSha256===manifest.base.engineSha256&&report.productionFeatures?.source?.sha256===manifest.privateSourceIdentity.sha256);
 const actualUse=helper.verifyAcceptedBundleUse(report.productionFeatures.renderCore,n.accepted_render_bundle,{requireBusyUse:true});assert.equal(actualUse.status,'observed',JSON.stringify(actualUse.errors));
 assert(report.movementReplay?.prediction?.verified===true&&report.movementReplay.accepted===report.movementReplay.inputs&&report.movementReplay.rejected===0,'Original recorded prediction proof failed');
 assert(report.productionCameraVerification?.status==='observed','Required terminal actor/camera gate failed');
 assert(p?.success===true&&p.diagnosticOnly===true&&p.actorInput===false&&p.authorityTest===false&&['static','yaw'].includes(p.mode));
 const t=p.engineThroughput,raw=n.camera_probe_native;assert(t&&raw&&['begin_process_frames','end_process_frames','begin_ticks_usec','end_ticks_usec','frames_delta','elapsed_usec'].every(k=>Number.isSafeInteger(t[k])&&t[k]===raw[k]));assert(t.frames_delta===t.end_process_frames-t.begin_process_frames&&t.elapsed_usec===t.end_ticks_usec-t.begin_ticks_usec&&t.elapsed_usec>=19500000&&t.elapsed_usec<23000000);assert(Math.abs(t.average_fps-t.frames_delta*1e6/t.elapsed_usec)<1e-6);
 assert(p.commands.length<=2500&&p.samples.length<=256&&p.samples.length>=100);assert(p.hostWindow.elapsedMs>19500&&p.hostWindow.elapsedMs<25000&&p.trimmedRollingFps.length>=10);
 assert(n.runtime_features.presentation.detailed_profiling===false&&n.runtime_features.presentation.maximum_fps===0&&n.runtime_features.presentation.vsync===0);
 return{success:true,mode:p.mode,actualUse,engine:t,host:p.hostWindow,rollingFps:p.trimmedRollingFps,commands:p.commands.length,observations:p.samples.length,scope:'Private fully-loaded camera/render diagnostic with unchanged actor authority. One pair is descriptive, not repeated optimization or original-client parity acceptance.'};
}
module.exports={verify};
