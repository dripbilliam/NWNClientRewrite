// Read existing logs only. Sliding-window summaries overlap: never pool their
// samples or average their quantiles into a claimed clean benchmark result.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [run,label]=process.argv.slice(2);
if(!/^native-manual-light-input-[a-z0-9-]+$/.test(run??'')||!/^native-light-input-live-[a-z0-9-]+$/.test(label??''))throw Error('Supply a manual trial run and fresh evidence label');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=path.join(project,'reports',run+'.performance.jsonl');
const bytes=fs.readFileSync(source),text=bytes.toString('utf8');
const complete=text.slice(0,text.lastIndexOf('\n')+1);
const rows=complete.trim().split('\n').filter(Boolean).map(JSON.parse);
const last=rows.at(-1);
if(!last?.frame_profile?.metrics?.wall_ms)throw Error('No diagnostic frame window');
const settled=rows.filter(s=>s.connection===last.connection&&s.generation===last.generation&&s.areaId===last.areaId&&s.ready===true&&s.pending_batches===0&&s.at>=last.at-60000&&s.frame_profile?.frames>0);
const metrics=s=>Object.fromEntries(Object.entries(s.frame_profile.metrics).filter(([k])=>/^(wall_ms|callback_|root_|protocol_|light_history_|particle_|world_|render_|profiler_|snapshot_|draws$|triangles$|nodes$)/.test(k)).map(([k,v])=>[k,{mean:v.mean,p95:v.p95,max:v.max,samples:v.samples}]));
const engineFile=path.join(project,'reports',run+'.engine.log');
const engineBytes=fs.existsSync(engineFile)?fs.readFileSync(engineFile):Buffer.alloc(0);
const warnings={};for(const match of engineBytes.toString('utf8').matchAll(/^WARNING: (.*)$/gm))warnings[match[1]]=(warnings[match[1]]??0)+1;
const overlayFile=path.join(project,'.cache/native-render-trials',run,'overlay.json');
const overlayBytes=fs.readFileSync(overlayFile),overlay=JSON.parse(overlayBytes);
const output=path.join(project,'reports',label+'.json'),raw=path.join(project,'reports',label+'.performance.jsonl');
if(fs.existsSync(output)||fs.existsSync(raw))throw Error('Existing evidence is preserved');
fs.writeFileSync(raw,complete,{flag:'wx'});
const evidence={version:1,run,capturedAt:new Date().toISOString(),scope:'User-controlled public login; passive existing diagnostics only. No automated movement, gameplay, capture readback or graphics benchmark.',source:{file:source,snapshot:raw,sha256:hash(Buffer.from(complete)),rows:rows.length,trailingPartialBytes:bytes.length-Buffer.byteLength(complete)},overlay:{file:overlayFile,sha256:hash(overlayBytes),renderer:overlay.rendererProject,capsule:overlay.capsule},engine:{file:engineFile,snapshotSha256:hash(engineBytes),warningCounts:warnings},latest:{at:last.at,connection:last.connection,generation:last.generation,areaId:last.areaId,fps:last.fps,ready:last.ready,pending:last.pending_batches,entities:last.entities,desired:last.desired,tiles:last.tiles,particles:last.particles,sharedParticles:last.shared_particles,lighting:last.focus_lighting,renderConfiguration:last.render_configuration,protocolHost:last.protocol_host,metrics:metrics(last),worstFrame:last.frame_profile.worst_frame},settledWindowObservations:settled.map(s=>({at:s.at,fps:s.fps,entities:s.entities,desired:s.desired,tiles:s.tiles,frames:s.frame_profile.frames,windowTicksMs:s.frame_profile.captured_at_ms,wall:s.frame_profile.metrics.wall_ms,registry:s.frame_profile.metrics.light_history_registry,particles:s.frame_profile.metrics.callback_particles})),limitations:['Detailed profiling is enabled; these are diagnosis windows, not clean FPS measurements.','Sliding windows overlap. Quantiles and sample counts are not pooled.','No matched before-run in this live location; no causal live gain is established.','Camera, viewport and focus are not persisted in these ordinary diagnostic records; no matched-view claim.','Particle bitmap failures are present; visual parity is not established by this performance observation.']};
fs.writeFileSync(output,JSON.stringify(evidence,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({file:output,sha256:hash(fs.readFileSync(output)),rows:rows.length,settledObservations:settled.length,latest:{at:last.at,fps:last.fps,entities:last.entities,desired:last.desired,tiles:last.tiles,pending:last.pending_batches},warnings}));
