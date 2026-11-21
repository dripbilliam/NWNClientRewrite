'use strict';
// Read-only local profile review. Never connects, launches, or changes settings.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const run=process.argv[2];if(!/^[a-z0-9-]+$/.test(run??''))throw Error('Explicit native run label required');
const file=path.resolve(__dirname,'../reports',run+'.performance.jsonl'),bytes=fs.readFileSync(file),text=bytes.toString('utf8'),lines=text.split(/\r?\n/),rows=[];
let incompleteTail=false;
for(let i=0;i<lines.length;i++){
 if(!lines[i].trim())continue;
 try{rows.push(JSON.parse(lines[i]));}catch(error){if(i!==lines.length-1||text.endsWith('\n'))throw error;incompleteTail=true;}
}
const median=values=>{const a=values.filter(Number.isFinite).sort((x,y)=>x-y),n=a.length;return n?n%2?a[n>>1]:(a[n/2-1]+a[n/2])/2:null;};
const groups=new Map();
for(const row of rows){
 if(row.ready!==true||row.frame_profile?.pending!==false||!row.frame_profile?.frames)continue;
 const camera=row.profile_presentation?.camera,motion=camera?.controlled;
 const activity=!motion||!Number.isFinite(motion.script)||typeof motion.driveHeld!=='boolean'?'unobserved':motion.driveHeld===true||motion.active===true||motion.script!==0?'sampled-motion':'sampled-idle';
 const key=JSON.stringify([row.connection,row.generation,row.areaId,activity]);if(!groups.has(key))groups.set(key,[]);groups.get(key).push(row);
}
const tracked=/^(callback_(particles|rigs|world|root|light_history|focus_lighting|effects)|root_protocol|protocol_apply|protocol_read_decode|protocol_message_.+_ms|light_history_.+|particle_native_.+_ms|actor_animation|actor_skin|keyboard_preview(?:_path|_query)?|world_(motion|poses|adoption)|world_receive_.+_ms|drive_.+|count_drive_.+|entry_.+_ms|transition_.+|snapshot_.+|publication_.+_ms|wall_ms|render_gpu_ms|profiler_collect_ms)$/;
const context=row=>({hostAtMs:row.at??null,elapsedMs:row.elapsedMs??null,ready:row.ready??null,connection:row.connection??null,generation:row.generation??null,areaId:row.areaId??null,phase:row.inputWindowPhase??null,capturedAtNativeMs:row.frame_profile.captured_at_ms??null,frames:row.frame_profile.frames});
function summarizeMetrics(observations){
 const names=[...new Set(observations.flatMap(row=>Object.keys(row.frame_profile.metrics??{})))].filter(name=>tracked.test(name)).sort();
 return Object.fromEntries(names.map(name=>{
  const present=observations.filter(row=>row.frame_profile.metrics?.[name]),maxima=present.filter(row=>Number.isFinite(row.frame_profile.metrics[name].max));
  const largest=maxima.length?maxima.reduce((a,b)=>a.frame_profile.metrics[name].max>=b.frame_profile.metrics[name].max?a:b):null,max=largest?.frame_profile.metrics[name].max??null,worst=largest?.frame_profile.worst_frame??{};
  return [name,{windows:present.length,medianOfWindowMeans:median(present.map(row=>row.frame_profile.metrics[name].mean)),medianOfWhenPresentMeans:median(present.map(row=>row.frame_profile.metrics[name].when_present_mean)),largestWindowMaximum:max,largestMaximumContext:largest?context(largest):null,largestMaximumRetainedWorstWallMatches:max!==null&&Number.isFinite(worst[name])&&Math.abs(worst[name]-max)<1e-6}];
 }));
}
function retainedSnapshots(observations){
 const snapshots=new Map();
 for(const row of observations){
  const worst=row.frame_profile.worst_frame??{};if(!Number.isFinite(worst.wall_ms))continue;
  const signature=crypto.createHash('sha256').update(JSON.stringify(Object.fromEntries(Object.entries(worst).sort(([a],[b])=>a.localeCompare(b))))).digest('hex');
  if(!snapshots.has(signature))snapshots.set(signature,{signature,contexts:[],wallMs:worst.wall_ms,spans:Object.fromEntries(Object.entries(worst).filter(([name,value])=>tracked.test(name)&&Number.isFinite(value)))});
  snapshots.get(signature).contexts.push(context(row));
 }
 return [...snapshots.values()].sort((a,b)=>b.wallMs-a.wallMs).slice(0,20);
}
const completed=rows.filter(row=>row.frame_profile?.pending===false&&row.frame_profile.frames>0);
const result={version:1,run,input:{file,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,rows:rows.length,incompleteTail},scope:'Descriptive live samples, grouped by connection/area and motion observed at delivery. Overlapping windows are not independent hitches; exact-copy snapshot deduplication is not a unique hitch count. Means and maxima are separate; maximum need not match retained worst-wall. Children are context-nested, not additive to parents. Metadata polling and world_receive spans are main-thread wall measurements; worker CPU duration is not imported as main-thread stall time. Loading/unready diagnostics remain in allCompletedWindows. Detailed profiling adds overhead; no causal savings, pooled frame percentiles or native-game/pixel parity claim.',allCompletedWindows:{observations:completed.length,metrics:summarizeMetrics(completed),retainedWorstWallSnapshots:retainedSnapshots(completed)},groups:[...groups].map(([key,observations])=>{
 return {scope:JSON.parse(key),observations:observations.length,hostTimeRangeMs:[observations[0].at,observations.at(-1).at],medianRollingFps:median(observations.map(r=>r.fps)),entityRange:[Math.min(...observations.map(r=>r.entities)),Math.max(...observations.map(r=>r.entities))],fovDegrees:[...new Set(observations.map(r=>r.profile_presentation?.camera?.fov_degrees??null))],viewports:[...new Map(observations.map(r=>[JSON.stringify(r.profile_presentation?.viewport??null),r.profile_presentation?.viewport??null])).values()],focusedSamples:observations.filter(r=>r.profile_presentation?.focused===true).length,metrics:summarizeMetrics(observations),retainedWorstWallSnapshots:retainedSnapshots(observations)};
})};
process.stdout.write(JSON.stringify(result,null,2)+'\n');
