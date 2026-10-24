import fs from 'node:fs/promises';
import path from 'node:path';

// Derived timings only; never reproduce packet contents, addresses or keys.
const directory=path.resolve('runtime-logs');
const paths=await Promise.all((await fs.readdir(directory)).filter(n=>n.endsWith('.jsonl')).map(async name=>({name,stat:await fs.stat(path.join(directory,name))})));
const selected=process.argv[2]??paths.sort((a,b)=>b.stat.mtimeMs-a.stat.mtimeMs)[0].name;
const rows=(await fs.readFile(path.join(directory,path.basename(selected)),'utf8')).trim().split('\n').flatMap(line=>{try{return[JSON.parse(line)];}catch{return[];}});
const quantile=(values,p)=>values.length?values.toSorted((a,b)=>a-b)[Math.min(values.length-1,Math.floor(values.length*p))]:null;
const groups=new Map();for(const row of rows){const context=row.context??{},duration=context.durationMs;if(Number.isFinite(duration)){let group=groups.get(row.code);if(!group)groups.set(row.code,group=[]);group.push({at:row.timestamp,ms:duration,name:context.name??context.model??null});}}
const summary={log:path.basename(selected),start:rows[0]?.timestamp,end:rows.at(-1)?.timestamp,
 timings:[...groups].map(([code,items])=>({code,count:items.length,p50Ms:quantile(items.map(r=>r.ms),.5),p95Ms:quantile(items.map(r=>r.ms),.95),slowest:items.toSorted((a,b)=>b.ms-a.ms).slice(0,5)})),
 timeline:rows.filter(r=>/portal-(started|ready)|area-shaders-prepared|area-variants-prepared|frame-stall/.test(r.code)).map(r=>({at:r.timestamp,code:r.code,context:Object.fromEntries(Object.entries(r.context??{}).filter(([key])=>!/(host|password|key|address|packet)/i.test(key)))})),
 caveat:'Resource durations overlap and include waiting; do not sum them as CPU time. Frame callback gaps are not evidence of continuous frame work.'};
const output=path.resolve(process.argv[3]??'backups/animations/area-performance-log-review-v1.json');await fs.writeFile(output,JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify({output,start:summary.start,end:summary.end,timings:summary.timings.map(({code,count,p50Ms,p95Ms,slowest})=>({code,count,p50Ms,p95Ms,slowest:slowest[0]})),timeline:summary.timeline.map(r=>({at:r.at,code:r.code,area:r.context.name??r.context.areaId,durationMs:r.context.durationMs,renderMs:r.context.renderMs,frameMs:r.context.totalMs,pointSlots:r.context.lightSlots?.point}))},null,2));
