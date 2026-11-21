'use strict';
// Stream filtered official Tracy exports; never materialize an entire capture's
// event table. Main/worker/render elapsed totals remain separate and overlapping.
const fs=require('node:fs'),path=require('node:path'),{spawn}=require('node:child_process'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),trace=path.resolve(process.argv[2]),out=path.resolve(process.argv[3]);
const exporter=path.join(root,'.cache/native-tracy/vendor/windows-0.13.0/tracy-csvexport.exe');
assert(trace.startsWith(root+path.sep)&&out.startsWith(root+path.sep));fs.mkdirSync(out,{recursive:true});
const frames=[],zones={},jobs=[];let mainThread;
const extra=process.argv.includes('--extra');
const refresh=process.argv.includes('--refresh-script-zones');
const sourceArg=process.argv.find(x=>x.startsWith('--source-project='));
const sourceProject=sourceArg?path.resolve(sourceArg.slice('--source-project='.length)):null;
const sourceLines={};
function canonical(row){
 const key=row.file+'|'+row.name;
 if(!(key in sourceLines)){
  const defaults={'res://systems/native_render/live_world.gd|_profile_process':629,'res://systems/model_rigs.gd|_profile_process':521,'res://systems/native_data/asset_service.gd|_profile_process':531,'res://systems/native_render/object_stream.gd|_profile_process':304,'res://systems/native_render/creature_stream.gd|_profile_process':168,'res://systems/native_render/area_stream.gd|_profile_process':163,'res://native_session_world.gd|commit_raw_snapshot':953};
  sourceLines[key]=sourceProject?fs.readFileSync(path.join(sourceProject,row.file.replace('res://','')),'utf8').split(/\r?\n/).findIndex(x=>x.startsWith('func '+row.name+'('))+1:defaults[key];
  assert(sourceLines[key]>0,'Canonical function declaration absent: '+key);
 }
 return row.line===sourceLines[key];
}
let preservedZones=[];
function frameAt(start){let lo=0,hi=frames.length;while(lo<hi){const mid=(lo+hi)>>>1;if(frames[mid].start<=start)lo=mid+1;else hi=mid;}return lo?frames[lo-1]:null;}
function credit(row,key){const f=frameAt(row.start);if(!f)return;f.cost[key]=(f.cost[key]||0)+row.duration;if(key==='world')f.world=true;if(key==='rigs')f.rigCalls=(f.rigCalls||0)+1;if(key==='asset_poll')f.assetCalls=(f.assetCalls||0)+1;}
function track(row){const key=row.name+'|'+row.file+'|'+row.line;let z=zones[key];if(!z)z=zones[key]={name:row.name,file:row.file,line:row.line,count:0,total:0,max:0,threads:{},durations:[],largest:[]};z.count++;z.total+=row.duration;z.max=Math.max(z.max,row.duration);z.threads[row.thread]=(z.threads[row.thread]||0)+1;z.durations.push(row.duration);if(z.largest.length<12||row.duration>z.largest.at(-1).duration){z.largest.push(row);z.largest.sort((a,b)=>b.duration-a.duration);z.largest.length=Math.min(12,z.largest.length);}}
async function job(label,filter,consume){
 const args=['-u','-f',filter,'-s','\t',trace],started=Date.now(),child=spawn(exporter,args,{windowsHide:true,stdio:['ignore','pipe','pipe']});console.log(JSON.stringify({job:label,pid:child.pid}));
 let pending='',header=false,rows=0,incomplete=0,bytes=0,error='',parseFailure;
 const timer=setTimeout(()=>child.kill(),210000);
 child.stderr.on('data',x=>{error+=x;if(error.length>65536)child.kill();});
 child.stdout.on('data',chunk=>{try{bytes+=chunk.length;assert(bytes<768*1024*1024,'Filtered export too large');pending+=chunk.toString('utf8');let at;while((at=pending.indexOf('\n'))>=0){const line=pending.slice(0,at).replace(/\r$/,'');pending=pending.slice(at+1);if(!header){assert.equal(line,'name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue');header=true;continue;}if(!line)continue;const c=line.split('\t');assert.equal(c.length,7);rows++;const duration=Number(c[4]);if(duration<0){incomplete++;continue;}consume({name:c[0],file:c[1],line:Number(c[2]),start:Number(c[3]),duration,thread:c[5]});}}catch(e){parseFailure=e;child.kill();}});
 await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',code=>{clearTimeout(timer);if(parseFailure)reject(parseFailure);else if(code!==0)reject(Error('Exporter '+label+' failed '+code+': '+error));else resolve();});});assert(header&&!pending.trim());
 const result={label,filter,rows,incomplete,bytes,seconds:(Date.now()-started)/1000,stderr:error};jobs.push(result);console.log(JSON.stringify(result));
}
function percentile(a,q){if(!a.length)return 0;return a[Math.min(a.length-1,Math.floor(q*a.length))];}
function stats(a){const b=a.slice().sort((x,y)=>x-y);return{count:b.length,mean_ms:b.reduce((s,x)=>s+x,0)/Math.max(1,b.length)/1e6,p50_ms:percentile(b,.5)/1e6,p95_ms:percentile(b,.95)/1e6,p99_ms:percentile(b,.99)/1e6,max_ms:(b.at(-1)||0)/1e6};}
(async()=>{
 if(extra){
  for(const frame of JSON.parse(fs.readFileSync(path.join(out,'frames.json'))))frames.push(frame);mainThread=JSON.parse(fs.readFileSync(path.join(out,'events-review.json'))).mainThread;
  const owners={'res://systems/native_data/asset_service.gd':'asset_poll','res://systems/native_render/object_stream.gd':'object_publication','res://systems/native_render/creature_stream.gd':'creature_publication','res://systems/native_render/area_stream.gd':'terrain_publication'};
  await job('publication-polling','_profile_process',row=>{const key=owners[row.file];if(key&&row.name==='_profile_process'&&row.thread===mainThread&&canonical(row)){track(row);credit(row,key);}});
  await job('physics','Physics Step',row=>{if(row.name==='Physics Step'&&row.thread===mainThread){track(row);credit(row,'physics_step');}});
 }else{
 if(refresh){const previous=JSON.parse(fs.readFileSync(path.join(out,'events-review.json')));for(const frame of JSON.parse(fs.readFileSync(path.join(out,'frames.json'))))frames.push(frame);mainThread=previous.mainThread;preservedZones=previous.zones.filter(z=>!(z.name==='_profile_process'&&['res://systems/native_render/live_world.gd','res://systems/model_rigs.gd'].includes(z.file))&&z.name!=='commit_raw_snapshot');for(const f of frames){delete f.cost.world;delete f.cost.rigs;delete f.cost.world_commit;delete f.rigCalls;f.world=false;}}
 else await job('frames','Main::iteration',row=>{if(row.name!=='Main::iteration')return;if(mainThread===undefined)mainThread=row.thread;assert.equal(row.thread,mainThread);frames.push({start:row.start,duration:row.duration,cost:{}});});
 frames.sort((a,b)=>a.start-b.start);
 await job('world-rigs','_profile_process',row=>{if(row.name!=='_profile_process'||row.thread!==mainThread)return;if(row.file==='res://systems/native_render/live_world.gd'&&canonical(row)){credit(row,'world');track(row);}else if(row.file==='res://systems/model_rigs.gd'&&canonical(row)){credit(row,'rigs');track(row);}});
 const nativeKeys={'NWNCapture/Particles/frame':'particles','NWNCapture/Particles/advance_batch':'particle_simulation','NWNCapture/Particles/geometry_batch':'particle_geometry','NWNCapture/Particles/counters_summary':'particle_counters','NWNCapture/Particles/sort_pack':'particle_sort','NWNCapture/Render/sync_scope':'render_sync','NWNCapture/Render/draw_cpu':'render_thread','NWNCapture/Lights/history_step':'light_solver','NWNCapture/Worker/wait_group_scope':'worker_group_wait','NWNCapture/Worker/wait_task_scope':'worker_task_wait'};
 if(!refresh)await job('native','NWNCapture/',row=>{if(nativeKeys[row.name]){track(row);if(row.thread===mainThread||row.name==='NWNCapture/Render/draw_cpu')credit(row,nativeKeys[row.name]);}});
 await job('world-commits','commit_raw_snapshot',row=>{if(row.name==='commit_raw_snapshot'&&row.file==='res://native_session_world.gd'&&canonical(row)){track(row);if(row.thread===mainThread)credit(row,'world_commit');}});
 if(!refresh)await job('movement','preview_drive',row=>{if(row.name==='preview_drive'&&row.file==='res://systems/native_render/live_world.gd'){track(row);if(row.thread===mainThread)credit(row,'movement_preview');}});
 }
 const active=frames.filter(x=>x.world),heavy=active.filter(x=>x.duration>15e6),windows=[];
 for(let i=0;i<frames.length;i++){const f=frames[i];f.period=i+1<frames.length?frames[i+1].start-f.start:f.duration;}
 const first=frames[0].start;
 for(let start=first;start<frames.at(-1).start;start+=10e9){const f=active.filter(x=>x.start>=start&&x.start<start+10e9);if(f.length<30)continue;const costs={};for(const x of f)for(const [k,v]of Object.entries(x.cost))costs[k]=(costs[k]||0)+v;windows.push({start_s:(start-first)/1e9,frames:f.length,main:stats(f.map(x=>x.duration)),period:stats(f.map(x=>x.period)),mean_cost_ms:Object.fromEntries(Object.entries(costs).map(([k,v])=>[k,v/f.length/1e6])),meanRigCalls:f.reduce((s,x)=>s+(x.rigCalls||0),0)/f.length,meanAssetCalls:f.reduce((s,x)=>s+(x.assetCalls||0),0)/f.length});}
 const ranked=Object.values(zones).map(z=>({...z,stats:stats(z.durations),durations:undefined,total_s:z.total/1e9,total:undefined,max:undefined,largest:z.largest.map(x=>({...x,start_s:(x.start-first)/1e9,duration_ms:x.duration/1e6,start:undefined,duration:undefined}))}));
 const result={trace,mainThread,sourceProject,sourceLines,allMainFrames:stats(frames.map(x=>x.duration)),activeMainFrames:stats(active.map(x=>x.duration)),activeFramePeriods:stats(active.map(x=>x.period)),activeFrames:active.length,windows,zones:[...preservedZones,...ranked],jobs,slowestFrames:frames.slice().sort((a,b)=>b.duration-a.duration).slice(0,30).map(x=>({start_s:(x.start-first)/1e9,main_ms:x.duration/1e6,period_ms:x.period/1e6,world:x.world===true,rigCalls:x.rigCalls||0,cost_ms:Object.fromEntries(Object.entries(x.cost).map(([k,v])=>[k,v/1e6]))})),scope:'Filtered CPU zones selected by actual source declaration line to exclude caller-site duplicate zones, exact same-thread Main::iteration ownership, and period intervals between main starts. Render-thread work overlaps main; nested native particle phases overlap their parent. No GPU timestamps or clean FPS acceptance.'};
 const report=extra?'extra-review.json':'events-review.json',frameFile=extra?'extra-frames.json':'frames.json';fs.writeFileSync(path.join(out,report),JSON.stringify(result,null,2)+'\n');fs.writeFileSync(path.join(out,frameFile),JSON.stringify(frames)+'\n');console.log(JSON.stringify({complete:true,activeFrames:active.length,windows:windows.length,file:path.join(out,report)}));
})().catch(e=>{console.error(e.stack);process.exitCode=1;});
