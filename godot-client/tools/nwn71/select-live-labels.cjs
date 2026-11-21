'use strict';
// STDIN ONLY: never launches or loads Tracy. Root owns the one CSV exporter.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{fields,key,taskKey,analyze}=require('./group-analysis.cjs');
const arg=n=>process.argv.find(v=>v.startsWith('--'+n+'='))?.slice(n.length+3),mode=arg('mode'),report=arg('report'),workerFile=arg('worker');
assert(['worker','pipeline'].includes(mode)&&report&&!fs.existsSync(report),'Require worker|pipeline mode and fresh report');
const LIMITS={inputBytes:1024*1024*1024,lineBytes:8192,producers:400000,waitsPerKind:128,selectedRows:10000,outputBytes:16*1024*1024,minimumWaitNs:250000};
const workers=mode==='pipeline'?JSON.parse(fs.readFileSync(workerFile)):null,producerRows=workers?.rows.filter(r=>r.name==='NWNCapture/Worker/task_scope')??[],groupKeys=new Set(workers?.rows.filter(r=>r.name==='NWNCapture/Worker/wait_group_scope').map(r=>key(fields(r.value))))??[];
let pending='',header=false,inputBytes=0,inputRows=0,incomplete=0,discardedBelowThreshold=0,selected=0;const tasks=[],groupWaits=[],taskWaits=[],pipelineRows=[],unparented=[];
function top(rows,row){rows.push(row);rows.sort((a,b)=>b.duration_ms-a.duration_ms||a.start_ns-b.start_ns);if(rows.length>LIMITS.waitsPerKind)rows.pop();}
function consume(line){
	assert(Buffer.byteLength(line)<=LIMITS.lineBytes,'TSV line bound');if(!header){assert.equal(line,'name\tsrc_file\tsrc_line\tns_since_start\texec_time_ns\tthread\tvalue');header=true;return;}
	if(!line)return;const c=line.split('\t');assert.equal(c.length,7,'Exact pinned0.13 TSV framing required');inputRows++;
	const start=Number(c[3]),duration=Number(c[4]);assert(Number.isSafeInteger(start)&&Number.isSafeInteger(duration),'Unsafe numeric timestamp');if(duration<0){incomplete++;return;}
	const row={name:c[0],file:c[1],line:Number(c[2]),start_ns:start,end_ns:start+duration,duration_ms:duration/1e6,thread:c[5],value:c[6]};assert(Number.isSafeInteger(row.end_ns));
	if(mode==='worker'){
		if(row.name==='NWNCapture/Worker/task_scope'){assert(tasks.length<LIMITS.producers,'Producer cap exceeded; root must narrow/review, never silently drop fast producers');tasks.push(row);}
		else if(row.name==='NWNCapture/Worker/wait_group_scope'||row.name==='NWNCapture/Worker/wait_task_scope'){
			if(duration<LIMITS.minimumWaitNs){discardedBelowThreshold++;return;}top(row.name.endsWith('wait_group_scope')?groupWaits:taskWaits,row);
		}
	}else{
		const label=fields(row.value),inside=producerRows.some(p=>p.thread===row.thread&&p.start_ns<=row.start_ns&&p.end_ns>=row.end_ns);
		if(row.name==='NWN71/Shader/compile_group_wait'&&groupKeys.has(key(label))||inside&&(row.name==='NWN71/Shader/compile_variant'||row.name.startsWith('NWN71/Pipeline/'))){assert(pipelineRows.length<LIMITS.selectedRows,'Selected pipeline row bound');pipelineRows.push(row);}
		else if(row.name.startsWith('NWN71/Pipeline/')&&duration>=LIMITS.minimumWaitNs)top(unparented,row);
	}
}
process.stdin.setEncoding('utf8');process.stdin.on('data',chunk=>{try{inputBytes+=Buffer.byteLength(chunk);assert(inputBytes<=LIMITS.inputBytes,'Bounded filtered TSV input exceeded1GB');pending+=chunk;let i;while((i=pending.indexOf('\n'))>=0){consume(pending.slice(0,i).replace(/\r$/,''));pending=pending.slice(i+1);}assert(Buffer.byteLength(pending)<=LIMITS.lineBytes);}catch(e){console.error(e.stack);process.exit(1);}});
process.stdin.on('end',()=>{try{
	assert(header&&!pending.trim(),'Missing header or truncated final row');let rows;
	if(mode==='worker'){
		const groups=new Set(groupWaits.map(r=>key(fields(r.value)))),ids=new Set(taskWaits.map(r=>taskKey(fields(r.value))));groups.delete(null);ids.delete(null);
		const selectedProducers=tasks.filter(r=>groups.has(key(fields(r.value)))||ids.has(taskKey(fields(r.value))));
		// Worker help/yield may run an unrelated nested task inside a selected
		// producer. Preserve that context so innermost containment never assigns
		// the nested task's driver call to the outer selected dependency.
		const context=tasks.filter(row=>selectedProducers.some(p=>p.thread===row.thread&&p.start_ns<=row.start_ns&&p.end_ns>=row.end_ns));
		rows=[...groupWaits,...taskWaits,...context];assert(rows.length<=LIMITS.selectedRows,'Selected producer/context row cap');
	}else rows=[...workers.rows,...pipelineRows];selected=rows.length;
	const result={schema:'nwn71-bounded-real-live-labels-v1',mode,input:{bytes:inputBytes,rows:inputRows,incomplete,discardedBelowThreshold},limits:LIMITS,producerRowsScanned:mode==='worker'?tasks.length:producerRows.length,rows,unparentedSlowPipelineStages:unparented,analysis:analyze(rows),scope:'Root-owned official exporter TSV reduced on stdin only. Top128 completed waits per kind >=0.25ms. ALL fast producer records retained before selected exact-ID join, or explicit cap failure. Only selected same-thread producer-contained stages are assigned. Unparented slow stages stay unassigned. CPU elapsed dependency spans overlap; never summed; no GPU/normal-engine gain inference.'};
	const bytes=Buffer.from(JSON.stringify(result,null,2)+'\n');assert(bytes.length<=LIMITS.outputBytes,'Small JSON output cap');fs.mkdirSync(path.dirname(path.resolve(report)),{recursive:true});fs.writeFileSync(report,bytes,{flag:'wx'});console.log(JSON.stringify({report,mode,inputRows,selectedRows:selected,bytes:bytes.length,counts:result.analysis.counts,largestGroups:result.analysis.groups.slice(0,6).map(g=>({key:g.key,description:g.descriptions,shaders:g.shaders,waitMs:g.wait_max_ms})),largestIndividualTasks:result.analysis.individual_tasks.slice(0,6).map(t=>({key:t.key,identified:t.producerIdentified,descriptions:t.descriptions,waitMs:t.wait.duration_ms}))}));
}catch(e){console.error(e.stack);process.exitCode=1;}});
