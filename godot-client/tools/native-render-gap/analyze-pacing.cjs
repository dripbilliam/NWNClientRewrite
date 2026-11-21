'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const project=path.resolve(__dirname,'../..'),run=process.argv[2];if(!/^[-a-z0-9]+$/.test(run??''))throw Error('Exact run required');
const file=path.join(project,'reports',run+'.json'),bytes=fs.readFileSync(file),n=JSON.parse(bytes).native,g=n.render_gap,p=g.pacing;
if(!p?.enabled||n.performance_window?.steady!==true)throw Error('Completed steady pacing capture required');
const stat=a=>{a=a.filter(Number.isFinite).sort((a,b)=>a-b);return {count:a.length,mean:a.reduce((s,x)=>s+x,0)/a.length,p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)],maximum:a.at(-1)};};
const out={run,input:{file,sha256:crypto.createHash('sha256').update(bytes).digest('hex')},steady:true,scope:'Tail900 completed main and render frames, approximately the last8-10s quiet window. Absolute wall spans nest/overlap. Own-thread120-frame CPU windows have Windows coarse time quantization, so individual ratios can exceed1. Detailed profiling, if enabled, adds overhead. These counters alone do not establish a clean FPS gain.',detailedProfiling:n.performance_window.view_end.detailed_profiling,policies:{process:p.process_policy,main:p.main_thread_policy,render:p.render_thread_policy,sameThread:p.same_thread},drops:{main:p.main_dropped,render:p.render_dropped,cpu:p.cpu_dropped}};
const columns=Object.fromEntries(p.columns.map((k,i)=>[k,i]));
for(const lane of ['main','render']){
 const rows=p[lane].slice(-900);out[lane]={};
 const spans=lane==='main'?[['total','start_us','end_us'],['process','process_begin_us','scenetree_process_end_us'],['sync','sync_begin_us','sync_end_us'],['audio','audio_begin_us','audio_end_us'],['delay','delay_begin_us','end_us'],['after_process_before_sync','scenetree_process_end_us','sync_begin_us']]:[['total','start_us','end_us'],['begin','start_us','begin_frame_end_us'],['setup','begin_frame_end_us','setup_end_us'],['viewport','viewport_begin_us','viewport_end_us'],['end','end_frame_begin_us','end_frame_end_us']];
 out[lane].intervalMs=stat(rows.slice(1).map((r,i)=>(r[columns.start_us]-rows[i][columns.start_us])/1000));
 for(const [name,a,b]of spans)out[lane][name+'Ms']=stat(rows.map(r=>r[columns[a]]&&r[columns[b]]?(r[columns[b]]-r[columns[a]])/1000:NaN));
 const cpu=p.cpu_windows.filter(r=>r[1]===(lane==='main'?0:1)&&r[8]===1).slice(-8),wallUs=cpu.reduce((s,r)=>s+r[4]-r[3],0),cpu100ns=cpu.reduce((s,r)=>s+r[6]+r[7],0);
 out[lane].cpu={windows:cpu.length,wallMs:wallUs/1000,cpuMs:cpu100ns/10000,busyFraction:cpu100ns/(wallUs*10),records:cpu};
}
if(g.particle_sample)out.particleSample=Object.fromEntries(Object.entries(g.particle_sample).filter(([k])=>k!=='records'));
if(g.admission_survey)out.admissionSurvey=Object.fromEntries(Object.entries(g.admission_survey).filter(([k])=>k!=='rows'));
out.features=g.engine_features;out.boundary=g.particle_boundary;
const dir=path.join(project,'.cache/native-render-gap/analysis');fs.mkdirSync(dir,{recursive:true});const target=path.join(dir,run+'.pacing.json');fs.writeFileSync(target,JSON.stringify(out,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file:target,mainProcessMs:out.main.processMs.mean,mainCpuFraction:out.main.cpu.busyFraction,renderMs:out.render.totalMs.mean,renderCpuFraction:out.render.cpu.busyFraction,particleMs:out.particleSample?.success_mean_ms}));
