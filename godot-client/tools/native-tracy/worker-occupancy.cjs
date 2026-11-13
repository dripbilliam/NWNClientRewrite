'use strict';
// Tracy worker-task spans are elapsed activity, not CPU utilization. Keep that
// distinction when comparing workers with the serial frame critical path.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const base=path.join(root,'.cache/native-tracy/arelith-review-cache-a/newestertrace-review');
const input=path.join(base,'worker-tasks.tsv'),output=path.join(base,'worker-occupancy.json');
assert(!fs.existsSync(output));
const origin=JSON.parse(fs.readFileSync(path.join(base,'frames.json'),'utf8'))[0].start;
const lines=fs.readFileSync(input,'utf8').split(/\r?\n/);
assert.equal(lines.shift().replace(/^\uFEFF/,''),'name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue');
const rows=[];const descriptions=new Map();
for(const line of lines){if(!line)continue;const c=line.split('\t');assert(c.length>=7);const start=Number(c[3]),duration=Number(c[4]);if(duration<0)continue;const value=c.slice(6).join('\t');const description=value.match(/description=(.*)$/)?.[1]??'';rows.push({start,end:start+duration,thread:c[5],description});descriptions.set(description,(descriptions.get(description)||0)+1);}
function union(spans){let total=0,end=-Infinity;for(const [a,b] of spans.sort((x,y)=>x[0]-y[0])){if(b<=end)continue;total+=b-Math.max(a,end);end=b;}return total;}
function window(startS,endS){const low=origin+startS*1e9,high=origin+endS*1e9,selected=rows.filter(r=>r.start<high&&r.end>low),threads=new Map();for(const r of selected){if(!threads.has(r.thread))threads.set(r.thread,[]);threads.get(r.thread).push([Math.max(r.start,low),Math.min(r.end,high)]);}const busyNs=[...threads.values()].reduce((n,spans)=>n+union(spans),0);return {start_s:startS,end_s:endS,tasks:selected.length,threads:threads.size,worker_span_equivalents:busyNs/(high-low),scope:'Sum of per-thread task-scope elapsed spans divided by window length. Includes waits/IO; upper bound on executing CPU cores, not CPU usage.'};}
const report={trace:'newestertrace.tracy',taskRows:rows.length,distinctThreads:new Set(rows.map(r=>r.thread)).size,descriptions:[...descriptions].map(([name,count])=>({name,count})).sort((a,b)=>b.count-a.count).slice(0,20),windows:[[40,50],[50,60],[60,70],[70,80],[90,100],[100,110],[130,140],[140,150],[150,160],[160,170]].map(([a,b])=>window(a,b))};
fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({taskRows:report.taskRows,distinctThreads:report.distinctThreads,windows:report.windows,descriptions:report.descriptions.slice(0,8)}));
