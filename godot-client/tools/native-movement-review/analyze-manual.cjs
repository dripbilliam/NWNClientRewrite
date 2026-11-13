'use strict';
// Bounded offline analysis of completed profiling evidence. No launch or test.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..'),[run,label]=process.argv.slice(2);
if(run!=='native-live-fps-pending-a'||!/^[a-z0-9-]+$/.test(label??''))throw Error('Explicit known manual run and fresh review required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1/manual-arelith-pending-a','completed-review-'+label);
if(fs.existsSync(root))throw Error('Previous evidence preserved');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),base=path.join(project,'reports',run),report=JSON.parse(fs.readFileSync(base+'.json')),native=JSON.parse(fs.readFileSync(base+'.native.json'));
const bytes=fs.readFileSync(base+'.performance.jsonl');if(bytes.length>16*1024*1024)throw Error('Profiling evidence exceeds bound');
if(!bytes.toString('utf8').endsWith('\n'))throw Error('Completed profile ends with a partial row');
const input=bytes.toString('utf8').trim().split('\n').map(JSON.parse),startup=JSON.parse(fs.readFileSync(base+'.startup.json'));
if(!report.success||!native.success||report.sourceUnchanged!==true||startup.source.sha256!=='e62371bcf4380f09ccd72a9a3eae432dc4751106353e369eb438a025d72c5d30')throw Error('Expected completed installed source/session missing');
const settingsFile='C:/Users/Niflheim/Documents/Neverwinter Nights.0/settings.tml',settingsBytes=fs.readFileSync(settingsFile),settings={};let section='';
for(const text of settingsBytes.toString('utf8').split(/\r?\n/)){
 const line=text.trim();if(line.startsWith('[')){section=line.slice(1,-1);continue;}
 if(!section.startsWith('graphics')||line.startsWith('#')||!line.includes('='))continue;
 const index=line.indexOf('='),key=line.slice(0,index).trim();if(/password|token|account|server/i.test(key))continue;
 const raw=line.slice(index+1).trim();let value;try{value=JSON.parse(raw);}catch{value=raw;}
 settings[section+'.'+key]=value;
}
const names=['wall_ms','callback_world','world_motion','world_motion_update_ms','world_stream_priority_ms','world_adoption','world_poses','world_base_draw_flush_ms','world_readiness_and_borders_ms','world_inflight_capture_ms','world_pending_plan_ms','world_actor_owner_setup_ms','world_static_owner_setup_ms','world_base_owner_setup_ms','callback_particles','callback_rigs','callback_light_history','callback_native_lighting','callback_root','root_protocol','render_setup_cpu_ms','render_cpu_ms','render_gpu_ms','physics_ms','profiler_record_ms','profiler_summary_ms','callback_overlap_ms','unattributed_callback_ms','count_controlled_motion_active','count_controlled_drive_held','count_pending_batches','count_asset_workers','count_world_instances'];
const worldChildren=['world_motion','world_adoption','world_poses','world_base_draw_flush_ms','world_readiness_and_borders_ms','world_inflight_capture_ms','world_pending_plan_ms','world_actor_owner_setup_ms','world_static_owner_setup_ms','world_base_owner_setup_ms'];
const firstByScope=new Map(),rows=[];
for(const r of input){
 const scope=[r.connection,r.generation,r.areaId].join(':'),capture=r.frame_profile?.captured_at_ms??r.native_ticks_ms;
 if(!firstByScope.has(scope))firstByScope.set(scope,capture);
 if(!r.ready||r.frame_profile?.frames!==240)continue;
 const metrics=r.frame_profile.metrics,means=Object.fromEntries(names.map(n=>[n,metrics[n]?.mean??0])),max=n=>metrics[n]?.max??0;
 const duration=means.wall_ms*240;
 const insideScope=capture-duration>firstByScope.get(scope)+50;
 const active=means.count_controlled_motion_active;
 const motion=max('count_controlled_motion_active')===0?'stationary':active>=0.95&&max('count_controlled_motion_active')<=1?'mostly-active':'mixed';
 const assets=max('count_pending_batches')===0&&max('count_asset_workers')===0?'settled':'work-active';
 const populationStable=Math.abs(max('count_world_instances')-means.count_world_instances)<1e-6;
 rows.push({at:r.at,capture,duration,scope,insideScope,motion,assets,populationStable,entities:r.entities,desired:r.desired,fps:r.fps,viewport:r.profile_presentation?.viewport,means,worldResidual:means.callback_world-worldChildren.reduce((s,n)=>s+means[n],0),maxima:Object.fromEntries(names.map(n=>[n,max(n)]))});
}
const avg=a=>a.length?a.reduce((s,v)=>s+v,0)/a.length:null,median=a=>{a=[...a].sort((a,b)=>a-b);return a.length?a.length%2?a[a.length>>1]:(a[a.length/2-1]+a[a.length/2])/2:null;};
function summarize(selected){return {windows:selected.length,entities:selected.length?[Math.min(...selected.map(r=>r.entities)),Math.max(...selected.map(r=>r.entities))]:null,sampledFpsMedian:median(selected.map(r=>r.fps)),meanWindowMetrics:Object.fromEntries(names.map(n=>[n,avg(selected.map(r=>r.means[n]))])),worldResidualMean:avg(selected.map(r=>r.worldResidual))};}
const nonoverlap=[];let lastEndByScope=new Map();
for(const r of rows.filter(r=>r.insideScope))if(r.capture-r.duration>(lastEndByScope.get(r.scope)??-Infinity)+50){nonoverlap.push(r);lastEndByScope.set(r.scope,r.capture);}
const groups=[];for(const scope of firstByScope.keys())for(const motion of ['stationary','mostly-active','mixed'])for(const assets of ['settled','work-active']){
 const matching=rows.filter(r=>r.insideScope&&r.scope===scope&&r.motion===motion&&r.assets===assets);if(!matching.length)continue;
 groups.push({scope,motion,assets,overlapping:summarize(matching),nonoverlapping:summarize(nonoverlap.filter(r=>r.scope===scope&&r.motion===motion&&r.assets===assets)),stablePopulationOnly:summarize(matching.filter(r=>r.populationStable))});
}
const sourceRoot=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source'),sourceFiles=['servers/rendering/rendering_server_default.cpp','servers/rendering/renderer_scene_cull.cpp','servers/rendering/renderer_canvas_cull.cpp','servers/rendering/renderer_rd/storage_rd/light_storage.cpp','scene/3d/light_3d.cpp'];
const output={version:1,run,source:startup.source.sha256,session:{success:report.success,nativeSuccess:native.success,nativeExit:report.nativeExit,sourceUnchanged:report.sourceUnchanged,rawWorldUpdates:report.rawWorldUpdates,hostReportSha256:sha(fs.readFileSync(base+'.json')),nativeReportSha256:sha(fs.readFileSync(base+'.native.json'))},profile:{file:base+'.performance.jsonl',bytes:bytes.length,sha256:sha(bytes),observations:input.length,ready240:rows.length},settings:{file:settingsFile,sha256:sha(settingsBytes),modified:fs.statSync(settingsFile).mtime.toISOString(),graphics:settings,scope:'Only actual graphics values, excludes ~~schema defaults and all account/network content. Saved limiter values do not override the user-reported temporary uncapped measurement.'},engineSources:sourceFiles.map(relative=>({relative,file:path.join(sourceRoot,relative),sha256:sha(fs.readFileSync(path.join(sourceRoot,relative)))})),groups,rows,nonoverlappingRowTimes:nonoverlap.map(r=>r.at),limits:['Diagnostic profiling enabled; not clean FPS acceptance or a matched original-client benchmark.','Window metrics are 240-frame overlapping summaries; snapshot FPS has a different horizon. Nonoverlap uses aggregate wall duration with a50ms guard, not exact per-frame timestamps.','Scope boundary exclusion uses the first observed summary and is conservative, not an original server scope timestamp.','Population, moving NPCs, camera and model publication can change within the same area. Motion/asset conditioning is descriptive, not a causal movement experiment.','Renderer setup time is asynchronous render-thread wall time for XR pre_render plus scene.update and canvas.update. It is before draw_viewports, and does not by itself attribute cost to a specific cull/resource update.','Callback parents and children overlap. Renderer CPU/GPU/main-thread values cannot be added as independent serial costs.','Original 170-200FPS is user-reported; settings file establishes saved options, not exact live camera, workload, draw counts or a recorded matched original trace.']};
fs.mkdirSync(root);fs.writeFileSync(path.join(root,'performance.jsonl'),bytes,{flag:'wx'});fs.writeFileSync(path.join(root,'analysis.json'),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({root,source:output.source,observations:input.length,session:output.session,groups:groups.map(g=>({scope:g.scope,motion:g.motion,assets:g.assets,windows:g.overlapping.windows,nonoverlap:g.nonoverlapping.windows,fps:g.overlapping.sampledFpsMedian,metrics:Object.fromEntries(['world_pending_plan_ms','callback_world','callback_particles','callback_rigs','render_setup_cpu_ms','render_gpu_ms'].map(k=>[k,g.overlapping.meanWindowMetrics[k]]))})),settings:{window:[settings['graphics.window.windowed.width'],settings['graphics.window.windowed.height']],quality:settings['graphics.general.shader-quality'],lighting:settings['graphics.lighting.enhanced'],lights:settings['graphics.lighting.max-lights'],lod:settings['graphics.lod.enabled']}},null,2));
