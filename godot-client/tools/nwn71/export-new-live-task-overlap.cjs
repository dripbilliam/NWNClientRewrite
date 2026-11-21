'use strict';
// Read-only, one trace, selected unlabeled task scopes overlapping long render waits.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'../..');
const mode=process.argv[2];assert(['control','candidate'].includes(mode));
const base=path.join(root,'.cache/native-tracy/arelith-review-cache-a');
const trace=path.join(base,mode==='control'?'control-live.tracy':'candidate-live-20261112.tracy');
const workerFile=path.join(root,'.cache/nwn71/live-worker-20261112-'+mode,'worker.json');
const output=path.join(root,'.cache/nwn71/live-worker-20261112-'+mode,'task-overlap.json');
assert(!fs.existsSync(output));
const worker=JSON.parse(fs.readFileSync(workerFile,'utf8'));
const waits=worker.rows.filter(row=>row.name==='NWNCapture/Worker/wait_group_scope'&&row.duration_ms>=20);
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const exporter=path.join(root,'.cache/native-tracy/vendor/windows-0.13.0/tracy-csvexport.exe');
assert.equal(sha(exporter),'345f15cdeeadee9aeba5681c72af1af1129a611204971db1ee52e35bba93c519');
let header=false,pending='',bytes=0,scanned=0,incomplete=0,stderr='',failure='';
const rows=[];
const intersect=(a,b)=>Math.max(0,Math.min(a.end_ns,b.end_ns)-Math.max(a.start_ns,b.start_ns));
const child=spawn(exporter,['-u','-f','NWNCapture/Worker/task_scope','-s','\t',trace],{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
const stop=reason=>{failure||=reason;if(child.exitCode===null&&!child.killed)child.kill()};
function line(value){
 if(!header){assert.equal(value,'name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue');header=true;return}
 if(!value)return;
 const c=value.split('\t');assert.equal(c.length,7);scanned++;
 const start=Number(c[3]),length=Number(c[4]);if(length<0){incomplete++;return}
 assert(Number.isSafeInteger(start)&&Number.isSafeInteger(length));
 const row={start_ns:start,end_ns:start+length,duration_ms:length/1e6,thread:c[5],value:c[6]};
 const matches=waits.filter(w=>intersect(row,w)>0).map(w=>({wait_start_ns:w.start_ns,overlap_ms:intersect(row,w)/1e6}));
 if(matches.length){assert(rows.length<10000,'Selected task cap');rows.push({...row,matches})}
}
child.stdout.on('data',chunk=>{try{bytes+=chunk.length;assert(bytes<1024*1024*1024,'CSV byte cap');pending+=chunk.toString('utf8');let i;while((i=pending.indexOf('\n'))>=0){line(pending.slice(0,i).replace(/\r$/,''));pending=pending.slice(i+1)}assert(pending.length<8192)}catch(e){stop(e.stack)}});
child.stderr.on('data',chunk=>stderr=(stderr+chunk).slice(-65536));
const timer=setTimeout(()=>stop('120-second exporter bound'),120000);
child.on('error',error=>stop(error.stack));
child.on('close',code=>{clearTimeout(timer);try{
 assert(!failure&&code===0&&header&&!pending.trim(),failure||stderr||'Exporter failed');
 const summary=waits.map(w=>{const selected=rows.filter(r=>r.matches.some(m=>m.wait_start_ns===w.start_ns));const top=selected.slice().sort((a,b)=>Math.max(...b.matches.filter(m=>m.wait_start_ns===w.start_ns).map(m=>m.overlap_ms))-Math.max(...a.matches.filter(m=>m.wait_start_ns===w.start_ns).map(m=>m.overlap_ms))).slice(0,8);return {wait_start_ns:w.start_ns,wait_ms:w.duration_ms,render_thread:w.thread,overlapping_task_count:selected.length,longest_overlap:top.map(t=>({thread:t.thread,task_ms:t.duration_ms,overlap_ms:t.matches.find(m=>m.wait_start_ns===w.start_ns).overlap_ms,value:t.value}))}});
 const receipt={issue:'NWN-71',mode,trace,traceBytes:fs.statSync(trace).size,workerSha256:sha(workerFile),exporterSha256:sha(exporter),scanned,incomplete,bytes,waits:summary,selectedRows:rows.length,allTaskValuesEmpty:rows.every(r=>r.value===''),scope:'Temporal task overlap only; task/group IDs absent in this engine. No exact producer assignment or CPU-on-core inference.'};
 fs.writeFileSync(output,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({file:output,sha256:sha(output),scanned,selectedRows:rows.length,waits:summary}));
 }catch(e){console.error(e.stack);process.exitCode=1}});
