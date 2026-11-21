"use strict";
// Offline Tracy evidence only. The CSV was filtered to one zone before this
// script runs; no client, engine or profiler process is launched here.
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),assert=require("node:assert/strict");
const root=path.resolve(__dirname,"../..");
const framesPath=path.join(root,".cache/native-tracy/arelith-review-cache-a/thenewone-review/frames.json");
const viewportPath=path.join(root,".cache/nwn74/thenewone-render-viewport.csv");
const sha=bytes=>crypto.createHash("sha256").update(bytes).digest("hex");
const frameBytes=fs.readFileSync(framesPath),viewportBytes=fs.readFileSync(viewportPath);
const frames=JSON.parse(frameBytes),lines=viewportBytes.toString().trim().split(/\r?\n/);
assert(lines[0]==="name,src_file,src_line,ns_since_start,exec_time_ns,thread,value");
const origin=frames[0].start,windows=new Map(),single=[],passes=[];
for(const start of [20,30,40,50,60,70,80,90,100,110])windows.set(start,{start_s:start,frames:[],viewport_us:[],viewport_events:0,viewports_pass_us:[]});
for(const frame of frames){
 const start=Math.floor((frame.start-origin)/1e9/10)*10,w=windows.get(start);
 if(w)w.frames.push(frame);
}
for(const line of lines.slice(1)){
 const parts=line.split(",");assert(parts.length===7&&["render viewport","render viewports"].includes(parts[0])&&parts[5]==="2");
 const start=Math.floor((Number(parts[3])-origin)/1e9/10)*10,w=windows.get(start);
 if(w&&parts[0]==="render viewport"){w.viewport_us.push(Number(parts[4])/1000);w.viewport_events++;}
 if(w&&parts[0]==="render viewports")w.viewports_pass_us.push(Number(parts[4])/1000);
 if(parts[0]==="render viewport")single.push({start:Number(parts[3]),end:Number(parts[3])+Number(parts[4]),us:Number(parts[4])/1000});
 else passes.push({start:Number(parts[3]),end:Number(parts[3])+Number(parts[4])});
}
let cursor=0;
for(const pass of passes){
 while(cursor<single.length&&single[cursor].start<pass.start)cursor++;
 const durations=[];
 while(cursor<single.length&&single[cursor].start<pass.end){durations.push(single[cursor].us);cursor++;}
 const start=Math.floor((pass.start-origin)/1e9/10)*10,w=windows.get(start);
 if(w){
  w.viewport_per_pass??=[];w.heavy_viewport_per_pass??=[];w.max_viewport_per_pass_us??=[];
  w.viewport_per_pass.push(durations.length);
  w.heavy_viewport_per_pass.push(durations.filter(value=>value>=100).length);
  w.max_viewport_per_pass_us.push(Math.max(0,...durations));
 }
}
const mean=values=>values.length?values.reduce((a,b)=>a+b,0)/values.length:0;
const percentile=(values,q)=>{if(!values.length)return 0;const sorted=values.toSorted((a,b)=>a-b);return sorted[Math.min(sorted.length-1,Math.ceil(sorted.length*q)-1)];};
const result={source:{frames:{path:path.relative(root,framesPath),sha256:sha(frameBytes)},viewport:{path:path.relative(root,viewportPath),sha256:sha(viewportBytes)}},origin_ns:origin,windows:[]};
for(const w of windows.values()){
 const rows=w.frames,viewport=w.viewport_us;
 result.windows.push({start_s:w.start_s,frame_count:rows.length,
  main_mean_ms:mean(rows.map(x=>x.duration/1e6)),period_mean_ms:mean(rows.map(x=>x.period/1e6)),
  render_thread_mean_ms:mean(rows.map(x=>(x.cost.render_thread??0)/1e6)),render_sync_mean_ms:mean(rows.map(x=>(x.cost.render_sync??0)/1e6)),
  viewport_events:w.viewport_events,viewport_total_ms:viewport.reduce((a,b)=>a+b,0)/1000,viewport_mean_per_frame_ms:rows.length?viewport.reduce((a,b)=>a+b,0)/rows.length/1000:0,
  viewports_pass_events:w.viewports_pass_us.length,viewports_pass_mean_ms:mean(w.viewports_pass_us)/1000,viewports_pass_p95_ms:percentile(w.viewports_pass_us,0.95)/1000,
  viewport_slots_per_pass:mean(w.viewport_per_pass??[]),heavy_viewports_per_pass:mean(w.heavy_viewport_per_pass??[]),largest_viewport_mean_ms:mean(w.max_viewport_per_pass_us??[])/1000,
  viewport_event_p95_us:percentile(viewport,0.95),viewport_event_max_us:Math.max(0,...viewport)});
}
result.scope="Trace window means include main/render overlap. Viewport CSV contains one Godot profile zone per viewport, often multiple per frame; do not add its duration to main or draw_cpu.";
const file=path.join(root,".cache/nwn74/thenewone-render-census-v2.json");fs.writeFileSync(file,JSON.stringify(result,null,2)+"\n",{flag:"wx"});
console.log(JSON.stringify({file:path.relative(root,file),sha256:sha(fs.readFileSync(file)),busy:result.windows.filter(x=>x.start_s>=100)}));
