// Read-only CPU-profile analysis. Timings from this diagnostic run are not an
// unprofiled FPS benchmark. Resolve minified frames using the exact build map.
import fs from 'node:fs/promises';
import path from 'node:path';
import {SourceMap} from 'node:module';
const args=process.argv.slice(2),arg=name=>args.find(v=>v.startsWith('--'+name+'='))?.slice(name.length+3);
for(const value of args)if(!['report','output'].some(name=>value.startsWith('--'+name+'=')))throw Error('Unknown profile summary option');
const root=process.cwd(),inside=file=>{const rel=path.relative(path.join(root,'runtime-logs/performance-queue'),file);return rel&&!rel.startsWith('..')&&!path.isAbsolute(rel);};
if(!arg('report')||!arg('output'))throw Error('Explicit report and new output required');
const input=path.resolve(arg('report')),output=path.resolve(arg('output'));if(!inside(input)||!inside(output)||!output.endsWith('.json'))throw Error('Scoped profile paths required');
const report=JSON.parse(await fs.readFile(input,'utf8'));if(!report.babylonProfiles?.length)throw Error('No scoped Babylon profiles');
const map=new SourceMap(JSON.parse(await fs.readFile(path.join(report.build.directory,'assets',report.build.bundle+'.map'),'utf8'))),rows=new Map();let totalUs=0,idleUs=0;
for(const reference of report.babylonProfiles){
 if(!inside(path.resolve(reference.file)))throw Error('Unexpected profile location');
 const profile=JSON.parse(await fs.readFile(reference.file,'utf8'));if(profile.samples.length!==profile.timeDeltas.length)throw Error('Incomplete profile samples');
 const nodes=new Map(profile.nodes.map(n=>[n.id,n])),parents=new Map();for(const node of profile.nodes)for(const child of node.children??[])parents.set(child,node.id);
 const keys=new Map();
 for(const node of profile.nodes){const frame=node.callFrame,entry=frame.url?.includes(report.build.bundle)?map.findEntry(frame.lineNumber,frame.columnNumber):null,file=entry?.originalSource??frame.url??'',line=(entry?.originalLine??frame.lineNumber)+1,key=file+':'+line+':'+frame.functionName;keys.set(node.id,key);if(!rows.has(key))rows.set(key,{file,line,function:frame.functionName||'(anonymous)',selfUs:0,inclusiveUs:0});}
 for(let i=0;i<profile.samples.length;i++){
  const id=profile.samples[i],delta=profile.timeDeltas[i],node=nodes.get(id);if(!node||!Number.isFinite(delta)||delta<0)throw Error('Invalid profile sample');totalUs+=delta;
  if(node.callFrame.functionName==='(idle)'){idleUs+=delta;continue;}
  rows.get(keys.get(id)).selfUs+=delta;let parent=id,depth=0;while(parent!==undefined){rows.get(keys.get(parent)).inclusiveUs+=delta;parent=parents.get(parent);if(++depth>1000)throw Error('Invalid profile ancestry');}
 }
}
const activeUs=totalUs-idleUs,format=row=>({...row,selfMs:row.selfUs/1000,inclusiveMs:row.inclusiveUs/1000,selfPercentOfNonIdle:100*row.selfUs/activeUs,inclusivePercentOfNonIdle:100*row.inclusiveUs/activeUs}),values=[...rows.values()],programUs=values.filter(row=>!row.file&&row.function==='(program)').reduce((sum,row)=>sum+row.selfUs,0);
const files=new Map();for(const row of values){const file=row.file||row.function;files.set(file,(files.get(file)??0)+row.selfUs);}
const summary={scope:'Two scoped steady Babylon JS profiles. Idle samples are excluded from non-idle shares. Unattributed (program) samples are not classified as CPU work or GPU execution; neither they nor idle gaps establish GPU time. Inclusive rows overlap. Use stage clocks for measured CPU durations.',source:input,profileCount:report.babylonProfiles.length,totalMs:totalUs/1000,idleMs:idleUs/1000,nonIdleMs:activeUs/1000,unattributedProgramMs:programUs/1000,attributedJsMs:(activeUs-programUs)/1000,stages:report.babylonRoom.measurements.filter(r=>r.profiled).map(r=>r.stageTimings),topSelf:values.toSorted((a,b)=>b.selfUs-a.selfUs).slice(0,25).map(format),topInclusive:values.toSorted((a,b)=>b.inclusiveUs-a.inclusiveUs).slice(0,30).map(format),files:[...files].toSorted((a,b)=>b[1]-a[1]).slice(0,25).map(([file,time])=>({file,selfMs:time/1000,percentOfNonIdle:100*time/activeUs}))};
await fs.writeFile(output,JSON.stringify(summary,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({output,attributedJsMs:summary.attributedJsMs,unattributedProgramMs:summary.unattributedProgramMs,idleMs:summary.idleMs,topSelf:summary.topSelf.slice(0,8),stages:summary.stages},null,2));
