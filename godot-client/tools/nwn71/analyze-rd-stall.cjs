'use strict';
// Bounded Tracy CPU-zone review. Same-thread child coverage is distinct from
// cross-thread temporal overlap; neither is a GPU duration or causal proof.
const fs=require('node:fs');
const path=require('node:path');
const {spawnSync}=require('node:child_process');

const filters={
  sync:'NWNCapture/Render/sync_scope',
  scene:'NWN71/SceneCull/',
  rd:'NWN71/RD/',
  worker:'NWNCapture/Worker/task_scope',
  groupWait:'NWNCapture/Worker/wait_group_scope',
  pipeline:'NWN71/Pipeline/vkCreateGraphicsPipelines',
  fence:'driver->fence_wait'
};
function intersection(a,b){return Math.max(0,Math.min(a.end_ns,b.end_ns)-Math.max(a.start_ns,b.start_ns));}
function unionNs(intervals){
  let total=0,end=-Infinity;
  for(const [start,stop] of intervals.sort((a,b)=>a[0]-b[0])){
    if(stop<=end)continue;
    total+=stop-Math.max(start,end);end=stop;
  }
  return total;
}
function childCoverage(parent,children){
  const spans=children.filter(x=>x.thread===parent.thread&&x!==parent&&x.start_ns>=parent.start_ns&&x.end_ns<=parent.end_ns)
    .map(x=>[x.start_ns,x.end_ns]);
  const covered=unionNs(spans);
  return {labeled_child_union_ms:covered/1e6,unlabeled_inside_ms:(parent.end_ns-parent.start_ns-covered)/1e6};
}
function small(r){return {name:r.name,thread:r.thread,start_s:r.start_ns/1e9,duration_ms:(r.end_ns-r.start_ns)/1e6,value:r.value};}
function analyze(groups,top=3){
  const syncs=groups.sync.slice().sort((a,b)=>(b.end_ns-b.start_ns)-(a.end_ns-a.start_ns)).slice(0,top);
  return syncs.map(sync=>{
    const s=small(sync);
    const scene=groups.scene.filter(r=>intersection(sync,r)>0).sort((a,b)=>intersection(sync,b)-intersection(sync,a));
    const rd=groups.rd.filter(r=>intersection(sync,r)>0).sort((a,b)=>intersection(sync,b)-intersection(sync,a));
    const workers=groups.worker.filter(r=>intersection(sync,r)>0).sort((a,b)=>(b.end_ns-b.start_ns)-(a.end_ns-a.start_ns));
    const related=(key)=>groups[key].filter(r=>intersection(sync,r)>0).sort((a,b)=>intersection(sync,b)-intersection(sync,a));
    return {sync:s,scene:scene.slice(0,8).map(r=>({...small(r),overlap_with_sync_ms:intersection(sync,r)/1e6})),
      rd:rd.slice(0,30).map(r=>({...small(r),overlap_with_sync_ms:intersection(sync,r)/1e6,...childCoverage(r,groups.rd)})),
      worker_overlap:{count:workers.length,top:workers.slice(0,12).map(small)},
      group_waits:related('groupWait').slice(0,8).map(small),
      pipeline_creates:related('pipeline').slice(0,8).map(small),
      driver_fence_waits:related('fence').slice(0,8).map(small),
      interpretation:'Zones on different threads only overlap in time. Worker overlap, child coverage and render sync do not establish a blocking producer.'};
  });
}
function zoneSummary(rows){
  const byName=Object.groupBy(rows,r=>r.name);
  return Object.entries(byName).map(([name,items])=>{
    const ms=items.map(r=>(r.end_ns-r.start_ns)/1e6).sort((a,b)=>a-b);
    return {name,count:ms.length,median_ms:ms[Math.floor(ms.length/2)],p95_ms:ms[Math.floor(ms.length*.95)],max_ms:ms.at(-1),over_2ms:ms.filter(v=>v>2).length};
  }).sort((a,b)=>b.max_ms-a.max_ms);
}
function exportRows(exe,trace,filter){
  const out=spawnSync(exe,['-u','-f',filter,'-s','\t',trace],{encoding:'utf8',windowsHide:true,shell:false,maxBuffer:16*1024*1024,timeout:30000});
  if(out.status!==0)throw Error(`${filter}: ${out.error||out.stderr||out.status}`);
  const lines=out.stdout.split(/\r?\n/);
  if(lines.shift()!=='name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue')throw Error(`${filter}: CSV header changed`);
  const rows=[];
  for(const line of lines){
    if(!line)continue;
    const c=line.split('\t');if(c.length<7)throw Error(`${filter}: malformed CSV row`);
    const start_ns=Number(c[3]),duration_ns=Number(c[4]);
    if(!Number.isSafeInteger(start_ns)||!Number.isSafeInteger(duration_ns)||duration_ns<0)throw Error(`${filter}: invalid time`);
    rows.push({name:c[0],start_ns,end_ns:start_ns+duration_ns,thread:c[5],value:c.slice(6).join('\t')});
  }
  return rows;
}
function main(){
  const arg=n=>process.argv.find(x=>x.startsWith(`--${n}=`))?.slice(n.length+3);
  const trace=arg('trace'),report=arg('report'),top=Number(arg('top')??3);
  if(!trace||!report||!Number.isInteger(top)||top<1||top>10)throw Error('Require --trace, fresh --report and --top=1..10');
  const traceFile=path.resolve(trace),reportFile=path.resolve(report);
  if(!fs.statSync(traceFile).isFile()||fs.existsSync(reportFile))throw Error('Trace must exist and report must be new');
  const exe=path.resolve(__dirname,'../../.cache/native-tracy/vendor/windows-0.13.0/tracy-csvexport.exe');
  const groups={};for(const [key,filter] of Object.entries(filters))groups[key]=exportRows(exe,traceFile,filter);
  const result={schema:'nwn71-rd-stall-review-v1',trace:traceFile,counts:Object.fromEntries(Object.entries(groups).map(([k,v])=>[k,v.length])),rdZones:zoneSummary(groups.rd),topSyncs:analyze(groups,top),
    scope:'Diagnostic CPU elapsed zones only. Same-thread nested durations use union coverage; cross-thread spans are overlap, not additive or causal. No FPS or GPU-time claim.'};
  fs.writeFileSync(reportFile,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
  console.log(JSON.stringify({report:reportFile,counts:result.counts,topSyncs:result.topSyncs.map(x=>({sync:x.sync,scene:x.scene.slice(0,2),rd:x.rd.slice(0,5),worker_overlap:x.worker_overlap.count}))}));
}
if(require.main===module)main();
module.exports={analyze,childCoverage,intersection,unionNs};
