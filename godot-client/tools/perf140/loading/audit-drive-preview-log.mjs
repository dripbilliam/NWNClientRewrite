// Read-only diagnostic extraction. Complete newline-terminated records only;
// never treats an in-progress trailing JSON fragment as a received sample.
import fs from 'node:fs';import path from 'node:path';
const file=process.argv[2];if(!file)throw Error('Explicit existing performance JSONL required');
const fields=['wall_ms','keyboard_preview','keyboard_preview_query','keyboard_preview_path','drive_query_factory','drive_shape_build','drive_tile_build','drive_clear','drive_clear_heights','drive_publish_full','drive_publish_delta','drive_publish_motion','count_drive_factory_rows','count_drive_shape_builds','count_drive_shape_cache_hits','count_drive_shape_vertices','count_drive_shape_faces','count_drive_tile_builds','count_drive_tile_cache_hits','count_drive_clear_calls','count_drive_clear_obstacle_inputs','count_drive_clear_creature_inputs','count_drive_clear_pending_inputs','count_drive_model_group_inputs','render_gpu_ms','count_asset_workers','count_asset_queued','count_pending_batches','pipeline_compilations_surface_delta','pipeline_compilations_specialization_delta'];
let carry='',samples=0,ready=0,malformed=0,bytes=0;const spikes=[];
for await(const chunk of fs.createReadStream(path.resolve(file),{encoding:'utf8',highWaterMark:65536})){
 bytes+=Buffer.byteLength(chunk);carry+=chunk;let newline;
 while((newline=carry.indexOf('\n'))>=0){const line=carry.slice(0,newline).trim();carry=carry.slice(newline+1);if(!line)continue;let row;try{row=JSON.parse(line);}catch{malformed++;continue;}samples++;
  if(row.ready!==true||Number(row.pending_batches)!==0)continue;ready++;
  const frame=row.frame_profile?.worst_frame;if(!frame||typeof frame!=='object'||!(Number(frame.keyboard_preview)>20))continue;
  const selected=Object.fromEntries(fields.filter(k=>typeof frame[k]==='number').map(k=>[k,frame[k]]));spikes.push({sampleAt:row.at,connection:row.connection,generation:row.generation,areaId:row.areaId,fields:selected});
 }
 if(carry.length>2*1024*1024)throw Error('Unterminated performance row exceeds explicit 2 MiB bound');
}
spikes.sort((a,b)=>Number(b.fields.keyboard_preview)-Number(a.fields.keyboard_preview));
console.log(JSON.stringify({source:path.resolve(file),bytes,completeSamples:samples,readyPendingZeroSamples:ready,malformedCompleteLines:malformed,ignoredTrailingBytes:Buffer.byteLength(carry),spikes:spikes.slice(0,16),scope:'Read-only rolling worst-frame samples; current sample ready/pending fields and exact frame metrics retained. No frame-time inference from missing subphase keys; repeated windows are not independent frame identities.'},null,2));
