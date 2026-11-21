// Diagnostic comparison only. Native profile windows overlap: never pool their
// frame counts or sum their hitch counts as if they were independent samples.
import fs from 'node:fs';
const files=process.argv.slice(2);if(!files.length)throw Error('Explicit replay reports required');
const phases=['keyboard_preview','keyboard_preview_query','keyboard_preview_path','drive_query_factory','drive_preview_collection','drive_shape_build','drive_tile_build','drive_clear_heights','drive_publish_full','drive_publish_delta','drive_publish_motion','protocol_read_decode','protocol_apply','world_adoption','callback_particles','render_cpu_ms','render_gpu_ms','wall_ms'];
for(const file of files){
 const r=JSON.parse(fs.readFileSync(file));
 const observation=r.profileObservations;if(!observation?.file)throw Error('Detailed replay observations are missing: '+file);
 const rows=fs.readFileSync(observation.file,'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
 const ready=rows.filter(row=>row.ready===true);
 const maxima=Object.fromEntries(phases.map(phase=>[phase,ready.reduce((max,row)=>Math.max(max,Number(row.frame_profile?.metrics?.[phase]?.max??0)),0)]));
 const seen=new Set(),spikes=[];
 for(const row of ready.toSorted((a,b)=>(b.frame_profile?.worst_frame?.keyboard_preview??0)-(a.frame_profile?.worst_frame?.keyboard_preview??0))){
  const w=row.frame_profile?.worst_frame??{},key=JSON.stringify([w.wall_ms,w.keyboard_preview,w.keyboard_preview_query,w.keyboard_preview_path]);
  if(seen.has(key))continue;seen.add(key);if(spikes.length>=8)break;
  spikes.push({elapsedMs:row.elapsedMs,fields:Object.fromEntries(Object.entries(w).filter(([k,v])=>typeof v==='number'&&(phases.includes(k)||k.startsWith('count_drive_')||k==='count_asset_workers'||k==='count_asset_queued'||k.startsWith('pipeline_compilations_')&&k.endsWith('_delta'))))});
 }
 const w=r.native?.world;
 console.log(JSON.stringify({file,valid:!!(r.success&&r.offline&&r.gameNetworkConnections===0&&r.sourceUnchanged&&r.runtimeUnchanged&&r.driverUnchanged&&r.exit===0&&!r.engineOrLifetimeError),profiling:r.profilingRequested,movement:r.movementReplay,requestedRoute:r.driveCollisionRequested,actualRoute:w?.drive_collision_route,world:{entities:w?.entities,desired:w?.desired,pending:w?.pending_batches,ready:w?.ready,complete:w?.object_visuals_complete,playableMs:w?.playable_ms,cameraBoundMs:w?.controlled_camera_bound_ms,terrainMs:w?.terrain_admission_ms,drive:w?.drive_collision},observations:rows.length,readyObservations:ready.length,maxima,spikes,scope:'Overlapping detailed-profile windows; maxima and exact recorded worst-frame spans only. No unique hitch count, pooled mean, matched visual result or unprofiled FPS claim.'}));
}
