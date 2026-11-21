'use strict';
// Analyze official filtered Tracy exports without reopening the multi-GB traces.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const dirs=process.argv.slice(2).map(x=>path.resolve(x));
assert.equal(dirs.length,2,'Expected control and candidate review directories');
for(const dir of dirs)assert(dir.startsWith(root+path.sep),'Review directory must stay in project');
const read=file=>JSON.parse(fs.readFileSync(file,'utf8'));
const pct=(values,q)=>{if(!values.length)return null;const a=values.slice().sort((x,y)=>x-y);return a[Math.min(a.length-1,Math.floor(q*(a.length-1)))];};
function load(dir){
 const review=read(path.join(dir,'events-review.json'));
 const frames=read(path.join(dir,'frames.json'));
 const lines=fs.readFileSync(path.join(dir,'reindex-events.tsv'),'utf8').replace(/^\uFEFF/,'').replace(/\r?\n$/,'').split(/\r?\n/);
 assert.equal(lines.shift(),'name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue');
 const rows=lines.map(line=>{const c=line.split('\t');assert.equal(c.length,7);return{name:c[0],file:c[1],line:Number(c[2]),start:Number(c[3]),duration:Number(c[4]),thread:c[5]};});
 const wanted='res://systems/native_render/drive_collision_indexed.gd';
 const canonical=name=>{const found=rows.filter(r=>r.name===name&&r.file===wanted&&r.thread===review.mainThread);const maxLine=Math.max(...found.map(r=>r.line));return found.filter(r=>r.line===maxLine).sort((a,b)=>a.start-b.start);};
 function frameIndex(start){let lo=0,hi=frames.length;while(lo<hi){const mid=(lo+hi)>>>1;if(frames[mid].start<=start)lo=mid+1;else hi=mid;}return lo-1;}
 const origin=frames[0].start;
 const trigger=canonical('reindex_sources').map(r=>{const i=frameIndex(r.start),f=frames[i];assert(f&&r.start<=f.start+f.duration+1e6);return{start_s:(r.start-origin)/1e9,call_ms:r.duration/1e6,frame_ms:f.duration/1e6,frame_period_ms:f.period/1e6,frame_world:!!f.world};});
 const steps=canonical('_reindex_step');
 const groups=trigger.map((t,i)=>({trigger_s:t.start_s,steps:[],perFrame:new Map(),first:null,last:null}));
 for(const r of steps){const t=(r.start-origin)/1e9;let group=-1;for(let i=0;i<trigger.length;i++)if(trigger[i].start_s<=t)group=i;assert(group>=0,'Stage step before trigger');const g=groups[group],frame=frameIndex(r.start);g.steps.push(r.duration);g.first=Math.min(g.first??r.start,r.start);g.last=Math.max(g.last??0,r.start+r.duration);g.perFrame.set(frame,(g.perFrame.get(frame)||0)+r.duration);}
 const stage=groups.map(g=>{const frameIds=[...g.perFrame.keys()],active=frameIds.filter(i=>frames[i].world),stageNs=g.steps.reduce((a,b)=>a+b,0);return{trigger_s:g.trigger_s,step_count:g.steps.length,span_s:g.first===null?0:(g.last-g.first)/1e9,total_step_ms:stageNs/1e6,max_step_ms:Math.max(0,...g.steps)/1e6,frames_with_steps:frameIds.length,active_frames_with_steps:active.length,max_step_time_in_one_frame_ms:Math.max(0,...g.perFrame.values())/1e6,main_frame_mean_ms:frameIds.length?frameIds.reduce((s,i)=>s+frames[i].duration,0)/frameIds.length/1e6:null,main_frame_p95_ms:pct(frameIds.map(i=>frames[i].duration/1e6),.95),main_frame_max_ms:frameIds.length?Math.max(...frameIds.map(i=>frames[i].duration))/1e6:null};});
 return{trace:review.trace,mainThread:review.mainThread,activeFrames:review.activeFrames,activeMain:review.activeMainFrames,activePeriod:review.activeFramePeriods,trigger,stage,stepEvents:steps.length};
}
const result={version:1,issue:'NWN-62',control:load(dirs[0]),candidate:load(dirs[1]),scope:'Same diagnostic binary and two-file source delta; manually repeated Arelith route, unequal durations/areas and Tracy overhead mean frame distributions are descriptive, not clean matched FPS acceptance. Canonical declaration-line CPU zones avoid duplicate caller-site attribution.'};
const out=path.join(path.dirname(dirs[0]),'nwn62-live-tracy-comparison-20261112.json');
fs.writeFileSync(out,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({file:out,control:result.control.trigger,candidate:result.candidate.trigger,candidateStages:result.candidate.stage},null,2));
