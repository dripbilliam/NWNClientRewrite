'use strict';
// Joins saved main sync, render draw and worker waits by timestamp only.
// Empty ZoneText prevents an exact group/task producer identity claim.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const base=path.join(root,'.cache/native-tracy/arelith-review-cache-a');
const output=path.join(root,'.cache/nwn71/new-live-sync-20261112-b.json');
assert(!fs.existsSync(output),'Preserve previous review');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const overlap=(a,b)=>Math.max(0,Math.min(a.end_ns,b.end_ns)-Math.max(a.start_ns,b.start_ns))/1e6;
const zone=(row,origin)=>({start_ns:Math.round(origin+row.start_s*1e9),end_ns:Math.round(origin+row.start_s*1e9+row.duration_ms*1e6),duration_ms:row.duration_ms,thread:row.thread});
const out={issue:'NWN-71',schema:1,traces:[],scope:'Read-only temporal intersection of official Tracy zones. Main sync, render draw and worker elapsed spans overlap; do not add them. Accepted Tracy engine has empty ZoneText for every worker wait/task, so no exact group/task identity can be assigned.'};
for(const mode of ['control','candidate']){
 const folder=path.join(base,mode+'-live-review-20261112');
 const eventsFile=path.join(folder,'events-review.json');
 const workerFile=path.join(root,'.cache/nwn71/live-worker-20261112-'+mode,'worker.json');
 const framesFile=path.join(folder,'extra-frames.json');
 const first=Buffer.alloc(1024),handle=fs.openSync(framesFile,'r');fs.readSync(handle,first,0,first.length,0);fs.closeSync(handle);
 const match=first.toString().match(/"start"\s*:\s*(\d+)/);assert(match,'First frame origin unavailable');
 const origin=Number(match[1]);assert(Number.isSafeInteger(origin));
 const events=JSON.parse(fs.readFileSync(eventsFile,'utf8'));
 const worker=JSON.parse(fs.readFileSync(workerFile,'utf8'));
 const get=name=>events.zones.find(x=>x.name===name)?.largest??[];
 const draws=get('NWNCapture/Render/draw_cpu').map(row=>zone(row,origin));
 const renderThread=draws[0]?.thread;assert(renderThread&&renderThread!==events.mainThread);
 const waits=worker.rows.filter(row=>row.name==='NWNCapture/Worker/wait_group_scope'||row.name==='NWNCapture/Worker/wait_task_scope');
 const groups=waits.filter(row=>row.name.endsWith('wait_group_scope'));
 const tasks=waits.filter(row=>row.name.endsWith('wait_task_scope'));
 assert.equal(worker.analysis.counts.labeled_waits,0);
 assert.equal(worker.analysis.counts.labeled_task_waits,0);
 assert.equal(worker.producerRowsScanned,mode==='control'?210540:276435);
 const topSync=get('NWNCapture/Render/sync_scope').map(row=>{
  const sync=zone(row,origin);
  const groupOverlaps=groups.filter(w=>w.thread===renderThread&&overlap(w,sync)>0).map(w=>({start_ns:w.start_ns,ms:w.duration_ms,thread:w.thread,intersection_ms:overlap(w,sync),value:w.value})).sort((a,b)=>b.intersection_ms-a.intersection_ms);
  const taskOverlaps=tasks.filter(w=>overlap(w,sync)>0).map(w=>({start_ns:w.start_ns,ms:w.duration_ms,thread:w.thread,intersection_ms:overlap(w,sync),value:w.value})).sort((a,b)=>b.intersection_ms-a.intersection_ms);
  const drawOverlaps=draws.filter(d=>overlap(d,sync)>0).map(d=>({start_ns:d.start_ns,ms:d.duration_ms,thread:d.thread,intersection_ms:overlap(d,sync)})).sort((a,b)=>b.intersection_ms-a.intersection_ms);
  return {relative_start_s:row.start_s,absolute_start_ns:sync.start_ns,main_sync_ms:sync.duration_ms,main_thread:sync.thread,render_draws:drawOverlaps,render_group_waits:groupOverlaps,other_task_waits:taskOverlaps,classification:groupOverlaps.some(w=>w.intersection_ms>=20)?'render-group-wait-overlap':drawOverlaps.some(d=>d.intersection_ms>=20)?'render-draw-without-retained-long-group-wait':'not-attributed-by-top-zones'};
 });
 out.traces.push({mode,trace:events.trace,sourceProject:events.sourceProject,renderThread,eventsReview:{file:eventsFile,sha256:sha(eventsFile)},workerLabels:{file:workerFile,sha256:sha(workerFile),rowsScanned:worker.input.rows,producerRowsScanned:worker.producerRowsScanned,labeledWaits:worker.analysis.counts.labeled_waits,labeledTaskWaits:worker.analysis.counts.labeled_task_waits,retainedGroupWaits:groups.length,retainedTaskWaits:tasks.length,thresholdMs:0.25},frameOriginNs:origin,topSync});
}
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(out,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({file:output,sha256:sha(output),summary:out.traces.map(t=>({mode:t.mode,sync:t.topSync.map(s=>({start:s.relative_start_s,ms:s.main_sync_ms,classification:s.classification,groupOverlapMs:s.render_group_waits[0]?.intersection_ms??0,drawOverlapMs:s.render_draws[0]?.intersection_ms??0}))}))}));
