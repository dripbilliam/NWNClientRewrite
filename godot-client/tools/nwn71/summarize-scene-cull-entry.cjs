'use strict';
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const label=process.argv.find(x=>x.startsWith('--label='))?.slice(8)??'b';
if(!['b','c','d'].includes(label))throw Error('Unknown capture label');
const root=path.resolve(__dirname,'../..'),trace=path.join(root,`.cache/nwn71/capture-scene-cull-entry-${label}/entry.tracy`),exporter=path.join(root,'.cache/native-tracy/vendor/windows-0.13.0/tracy-csvexport.exe');
function rows(filter){const out=spawnSync(exporter,['-u','-f',filter,'-s','\t',trace],{encoding:'utf8',windowsHide:true,shell:false,maxBuffer:16*1024*1024,timeout:30000});if(out.status!==0)throw Error(filter+': '+(out.error||out.stderr));const lines=out.stdout.split(/\r?\n/);if(lines.shift()!=='name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue')throw Error('header');return lines.filter(Boolean).map(line=>{const c=line.split('\t');return {name:c[0],thread:c[5],start_ns:Number(c[3]),end_ns:Number(c[3])+Number(c[4]),duration_ms:Number(c[4])/1e6,value:c[6]};});}
const stages=rows('NWN71/SceneCull/').concat(rows('NWN71/Viewport/'));
const syncs=rows('NWNCapture/Render/sync_scope');
const draws=rows('viewport->draw_viewports');
const waits=rows('NWNCapture/Worker/wait_group_scope');
const pipeline=rows('NWN71/Pipeline/vkCreateGraphicsPipelines');
function summarize(list){const groups=Object.groupBy(list,r=>r.name);return Object.entries(groups).map(([name,a])=>{const v=a.map(r=>r.duration_ms).sort((x,y)=>x-y);return {name,count:v.length,median_ms:v[Math.floor(v.length/2)],p95_ms:v[Math.floor(v.length*.95)],max_ms:v.at(-1)};}).sort((a,b)=>b.max_ms-a.max_ms);}
function overlap(a,b){return a.start_ns<b.end_ns&&a.end_ns>b.start_ns;}
const top=syncs.slice().sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,10).map(s=>({start_s:s.start_ns/1e9,ms:s.duration_ms,thread:s.thread,draws:draws.filter(r=>overlap(r,s)&&r.duration_ms>1).sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,4).map(r=>({start_s:r.start_ns/1e9,ms:r.duration_ms,thread:r.thread})),stages:stages.filter(r=>overlap(r,s)&&r.duration_ms>1).sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,20).map(r=>({name:r.name,start_s:r.start_ns/1e9,ms:r.duration_ms,thread:r.thread})),waits:waits.filter(r=>overlap(r,s)&&r.duration_ms>1).sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,10).map(r=>({name:r.name,ms:r.duration_ms,thread:r.thread,value:r.value})),pipelines:pipeline.filter(r=>overlap(r,s)).sort((a,b)=>b.duration_ms-a.duration_ms).slice(0,10).map(r=>({start_s:r.start_ns/1e9,ms:r.duration_ms,thread:r.thread}))}));
const report={trace,counts:{stages:stages.length,syncs:syncs.length,draws:draws.length,waits:waits.length,pipelines:pipeline.length},stages:summarize(stages),sync:summarize(syncs),waits:summarize(waits),topSyncs:top,scope:'Diagnostic CPU elapsed zones; nested spans overlap. No normal-client FPS inference.'};
const file=path.join(root,`.cache/nwn71/capture-scene-cull-entry-${label}/summary.json`);fs.writeFileSync(file,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,counts:report.counts,stages:report.stages,sync:report.sync,waits:report.waits,topSyncs:top.slice(0,4)}));
