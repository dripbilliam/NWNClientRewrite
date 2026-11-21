import fs from 'node:fs';
const files=process.argv.slice(2);
if(!files.length)throw Error('Pass benchmark report paths');
const results=files.map(file=>{
 const sidecar=file.replace(/\.json$/,'.exclusion.json');
 const exclusion=fs.existsSync(sidecar)?JSON.parse(fs.readFileSync(sidecar)):null;
 return {file,report:JSON.parse(fs.readFileSync(file)),exclusion};
});
const cameraEqual=(a,b)=>a&&b&&['far','fov','near'].every(k=>Math.abs(a[k]-b[k])<1e-5)&&a.position.every((v,i)=>Math.abs(v-b.position[i])<1e-5)&&Math.abs(Math.abs(a.quaternion.reduce((s,v,i)=>s+v*b.quaternion[i],0))-1)<1e-5;
const viewEqual=(a,b)=>a&&b&&['focused','headless','max_fps','msaa_3d','particle_lighting','particle_presentation','screen','vsync'].every(k=>a[k]===b[k])&&JSON.stringify(a.viewport)===JSON.stringify(b.viewport)&&JSON.stringify(a.world)===JSON.stringify(b.world)&&cameraEqual(a.camera,b.camera);
const base=results[0].report;
const cameraDifference=(a,b)=>{
 if(!a||!b)return null;
 const positionDistance=Math.hypot(...a.position.map((v,i)=>v-b.position[i]));
 const dot=a.quaternion.reduce((s,v,i)=>s+v*b.quaternion[i],0),norm=Math.hypot(...a.quaternion)*Math.hypot(...b.quaternion);
 return {positionWorldUnits:positionDistance,orientationRadians:2*Math.acos(Math.min(1,Math.abs(dot/norm))),scope:'Raw transform delta only; the strict view comparison is retained. No pixel-equivalence claim.'};
};
for(const {file,report:r,exclusion}of results){
 const excluded=exclusion?.excludeFromPerformance?exclusion:results[0].exclusion?.excludeFromPerformance?results[0].exclusion:null;
 if(excluded){
  console.log(JSON.stringify({file,valid:false,excludedFromPerformance:true,reason:excluded.reason,scope:'Known excluded run or baseline; no FPS or frame-time statistics published.'}));
  continue;
 }
 const f=r.native?.frame_intervals,v=r.native?.performance_window?.view_begin,end=r.native?.perf140_view_end;
 const guards=r.success&&r.offline&&r.gameNetworkConnections===0&&r.steadyCompleted&&r.sourceUnchanged&&r.driverUnchanged&&r.runtimeUnchanged&&r.profilingMatched&&!r.engineOrLifetimeError&&r.exit===0&&!r.debuggerRequested&&!r.debuggerArmed;
 console.log(JSON.stringify({file,valid:!!guards,profiling:r.profilingRequested,sameCaptureAsBaseline:r.recordingSha256===base.recordingSha256,sameViewAsBaseline:viewEqual(base.native?.performance_window?.view_begin,v),cameraDifferenceFromBaseline:cameraDifference(base.native?.performance_window?.view_begin?.camera,v?.camera),stableView:viewEqual(v,end),frames:f?.count,meanMs:f?.average_ms,fps:f?1000/f.average_ms:null,p95Ms:f?.p95_ms,p99Ms:f?.p99_ms,worstMs:f?.worst_ms,hitchesOver50Ms:f?.over_50ms,draws:r.native?.presentation_state?.draws,triangles:r.native?.presentation_state?.triangles,playableMs:r.native?.world?.playable_ms,source:r.sourceProject,scope:'One run per row; no statistical significance or visual parity claim is implied.'}));
}
