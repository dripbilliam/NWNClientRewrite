'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function parse(text){
 return JSON.parse(text,(key,value,context)=>{
  if(key!=='createdFileTimeUtc'||typeof value!=='number')return value;
  if(context?.source&&/^\d+$/.test(context.source))return context.source;
  if(Number.isSafeInteger(value))return String(value);
  throw Error('Exact Windows creation timestamp unavailable in this JSON runtime');
 });
}
function summarize(input){
 if(input.version!==1||input.success!==true||input.sourceUnchanged!==true||!Array.isArray(input.samples)||input.samples.length<3)throw Error('Successful unchanged owned-thread receipt required');
 const logical=input.identity?.logicalProcessors;if(!Number.isInteger(logical)||logical<1)throw Error('Logical processor count unavailable');
 const first=input.samples[0],last=input.samples.at(-1),wallMs=last.elapsedMs-first.elapsedMs,processCpuMs=last.processCpuMs-first.processCpuMs;
 if(!Number.isFinite(wallMs)||wallMs<=0||!Number.isFinite(processCpuMs)||processCpuMs<0)throw Error('Invalid sampled process interval');
 const threads=new Map();let previousElapsed=-Infinity,previousProcess=-Infinity;
 for(const sample of input.samples){
  if(!Number.isFinite(sample.elapsedMs)||sample.elapsedMs<=previousElapsed||!Number.isFinite(sample.processCpuMs)||sample.processCpuMs<previousProcess)throw Error('Nonmonotonic process samples');
  previousElapsed=sample.elapsedMs;previousProcess=sample.processCpuMs;
  for(const row of sample.threads??[]){
   if(!Number.isInteger(row.id)||row.id<=0||typeof row.createdFileTimeUtc!=='string'||!/^\d+$/.test(row.createdFileTimeUtc))throw Error('Exact thread incarnation unavailable');
   if(!Number.isFinite(row.kernelMs)||row.kernelMs<0||!Number.isFinite(row.userMs)||row.userMs<0)throw Error('Invalid thread CPU counters');
   const key=row.id+'/'+row.createdFileTimeUtc,cpu=row.kernelMs+row.userMs;
   if(!threads.has(key))threads.set(key,{id:row.id,createdFileTimeUtc:row.createdFileTimeUtc,name:row.name??null,firstCpuMs:cpu,lastCpuMs:cpu,firstElapsedMs:sample.elapsedMs,lastElapsedMs:sample.elapsedMs,observations:0,stateSnapshots:{},waitReasonSnapshots:{}});
   const thread=threads.get(key);if(cpu<thread.lastCpuMs)throw Error('Thread CPU counter moved backwards');
   thread.lastCpuMs=cpu;thread.lastElapsedMs=sample.elapsedMs;thread.observations++;if(!thread.name&&row.name)thread.name=row.name;
   if(row.state)thread.stateSnapshots[row.state]=(thread.stateSnapshots[row.state]??0)+1;
   if(row.waitReason)thread.waitReasonSnapshots[row.waitReason]=(thread.waitReasonSnapshots[row.waitReason]??0)+1;
  }
 }
 const list=[...threads.values()].map(row=>{const cpuMs=row.lastCpuMs-row.firstCpuMs,observedMs=row.lastElapsedMs-row.firstElapsedMs;return {...row,cpuMs,observedMs,oneCorePercent:observedMs>0?100*cpuMs/observedMs:null,processCpuSharePercent:processCpuMs>0?100*cpuMs/processCpuMs:null};}).sort((a,b)=>b.cpuMs-a.cpuMs);
 const equivalentBusyLogicalProcessors=processCpuMs/wallMs;
 return {version:1,run:input.run,identity:input.identity,interval:{wallMs,processCpuMs,samples:input.samples.length,equivalentBusyLogicalProcessors,approximateTotalCpuPercent:100*equivalentBusyLogicalProcessors/logical},watcherCpuMs:input.watcherCpuMs,threadCount:list.length,observedThreadCpuMs:list.reduce((sum,row)=>sum+row.cpuMs,0),threads:list,scope:'Only the sampled interval of the exact owned process. Thread CPU is last minus first observed cumulative counters for the same Windows ID/creation timestamp; short-lived or single-sample threads can be missed. Process and thread reads are not simultaneous, so coverage sums can differ. One-core percentage is CPU time divided by observed wall time; aggregate CPU divides by logical processors and is not a physical-throughput measure on hybrid/SMT hardware. Scheduling-state/wait-reason entries are snapshot counts, not wait durations or stacks. Names are OS labels; Godot internal IDs are different. No claim that a thread was continuously saturated or that all wait causes are identified.'};
}
module.exports={parse,summarize};
if(require.main===module){
 const run=process.argv[2],observation=process.argv[3];if(!/^[a-z0-9-]+$/.test(run??'')||observation!==undefined&&!/^[a-z0-9-]+$/.test(observation))throw Error('Owned run and optional observation labels required');
 const file=path.resolve(__dirname,'../reports',run+'.thread-cpu'+(observation?'.'+observation:'')+'.json'),bytes=fs.readFileSync(file),result=summarize(parse(bytes.toString('utf8')));
 result.input={file,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};process.stdout.write(JSON.stringify(result,null,2)+'\n');
}
