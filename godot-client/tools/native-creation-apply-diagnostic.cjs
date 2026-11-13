'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
class CreationApplyDiagnostic{
 constructor(prefix,{clock=Date.now}={}){
  this.prefix=prefix;this.clock=clock;this.rows=[];this.dropped=0;this.lifecycle=[];this.lifecycleDropped=0;this.setup=null;this.snapshot=null;this.acknowledged=false;this.stackStarted=false;
  if(fs.existsSync(prefix+'.phases.json'))throw Error('Existing creation diagnostic retained');
 }
 record(direction,value){
  const row={at:this.clock(),direction,kind:String(value.kind??'').slice(0,64),phase:String(value.phase??'').slice(0,160)};
  for(const key of ['checks','sequence','ticks_ms','epoch','serial','generation','connection','areaId'])if(Number.isSafeInteger(value[key]))row[key]=value[key];
  if(this.rows.length<256)this.rows.push(row);else this.dropped++;
  this.flush();
 }
 flush(){fs.writeFileSync(this.prefix+'.phases.json',JSON.stringify(this.summary(),null,2)+'\n');}
 boundary(direction,phase,value={}){
  if(this.lifecycle.length>=32){this.lifecycleDropped++;this.flush();return;}
  const row={at:this.clock(),direction:String(direction).slice(0,16),phase:String(phase).slice(0,80)};
  for(const key of ['connection','queued','read','written','exitCode'])if(Number.isSafeInteger(value[key]))row[key]=value[key];
  for(const key of ['success','ending','hadError'])if(typeof value[key]==='boolean')row[key]=value[key];
  if(typeof value.code==='string'&&/^[A-Z0-9_]{1,32}$/.test(value.code))row.code=value.code;
  this.lifecycle.push(row);this.flush();
 }
 summary(){return {version:2,rows:this.rows,dropped:this.dropped,lifecycle:this.lifecycle,lifecycleDropped:this.lifecycleDropped,setup:this.setup,snapshot:this.snapshot,acknowledged:this.acknowledged,stackStarted:this.stackStarted,scope:'Owned CreationCheck diagnostic only; bounded phase/scalar lifecycle ledgers plus exact first setup/raw frames. No authentication frames or credentials captured.'};}
 setupFrame(text){
  if(this.setup)return;
  if(Buffer.byteLength(text)>1024*1024||JSON.parse(text).kind!=='setup')throw Error('Invalid bounded diagnostic setup');
  const file=this.prefix+'.setup.jsonl';fs.writeFileSync(file,text,{flag:'wx'});this.setup={file,sha256:hash(text),bytes:Buffer.byteLength(text)};this.flush();
 }
 rawFrames(frames,scope){
  if(this.snapshot)return;
  const bytes=Buffer.from(frames.join(''));if(bytes.length>8*1024*1024)throw Error('Creation diagnostic first snapshot exceeds8MiB');
  const values=frames.map(line=>JSON.parse(line));
  if(values[0]?.kind!=='raw-world-begin'||values.at(-1)?.kind!=='raw-world-end'||values[0].data?.bridgeMode==='delta')throw Error('Creation diagnostic requires the real complete first full frame sequence');
  const file=this.prefix+'.raw.jsonl';fs.writeFileSync(file,bytes,{flag:'wx'});
  this.snapshot={file,sha256:hash(bytes),bytes:bytes.length,frames:frames.length,objects:values[0].count,at:this.clock(),...scope};this.flush();
 }
 accepted(value){if(this.snapshot&&value.serial===this.snapshot.serial&&value.generation===this.snapshot.generation&&value.connection===this.snapshot.connection){this.acknowledged=true;this.record('native',value);}}
 shouldStack(now=this.clock()){return Boolean(this.snapshot&&!this.acknowledged&&!this.stackStarted&&now-this.snapshot.at>=60000);}
 armStack(){this.stackStarted=true;this.record('host',{kind:'owned-stack-trigger',phase:'First full snapshot has no ACK after60s; unchanged overall test cap'});}
}
function cpuDelta(before,after){
 if(!before?.success||!after?.success||!before.exactLaunchIdentity||!after.exactLaunchIdentity)return {ready:false,reason:'Exact owned CPU samples unavailable'};
 const result={ready:true,scope:'Descriptive cumulative native/debugger CPU between exact owned launch samples; not a benchmark'};
 const start=Date.parse(before.cpu?.atUtc),end=Date.parse(after.cpu?.atUtc);
 if(!Number.isFinite(start)||!Number.isFinite(end)||end<=start)return {ready:false,reason:'CPU sample clock is invalid'};
 result.elapsedMs=end-start;
 for(const role of ['native','debugger']){
  const a=before.cpu?.[role],b=after.cpu?.[role];
  if(!a||!b||!Number.isSafeInteger(a.processId)||a.processId!==b.processId||!a.startedUtc||a.startedUtc!==b.startedUtc||!Number.isFinite(a.cpuSeconds)||!Number.isFinite(b.cpuSeconds)||b.cpuSeconds<a.cpuSeconds)return {ready:false,reason:'Owned CPU launch identity or counter changed'};
  result[role+'CpuSeconds']=b.cpuSeconds-a.cpuSeconds;
 }
 return result;
}
function runtimeTraceReady(value){
 return Boolean(value&&value.enabled===true&&value.armed===true&&value.failure===''&&value.maximum_rows===256&&value.sample_interval_ms===2000&&Number.isSafeInteger(value.rows)&&value.rows>0&&value.rows<=256&&Number.isSafeInteger(value.dropped)&&value.dropped>=0&&Number.isSafeInteger(value.samples)&&value.samples>=0);
}
module.exports={CreationApplyDiagnostic,cpuDelta,runtimeTraceReady};
