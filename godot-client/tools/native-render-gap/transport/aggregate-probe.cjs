'use strict';
const {performance}=require('node:perf_hooks');
const PHASES=Object.freeze(['registry_projection','delta_plan','frame_encode_pull','socket_enqueue','native_commit','native_snapshot','native_protocol_encode']);
// PRIVATE diagnostic only. The caller supplies an independently watched exact
// lifetime; this module reports it as expected identity, never as a Win32 read.
class AggregateProbe {
 constructor({enabled=false,now=()=>performance.now()*1000,pid=process.pid,maximum=100000}={}){
  if(!Number.isSafeInteger(maximum)||maximum<1||maximum>1000000)throw Error('Invalid bound');
  this.enabled=enabled===true;this.now=now;this.pid=pid;this.maximum=maximum;this.active=false;this.sequence=0;this.dropped=0;
  this.starts=new Float64Array(PHASES.length);this.tokens=new Float64Array(PHASES.length);this.counts=new Float64Array(PHASES.length);this.sums=new Float64Array(PHASES.length);this.maxima=new Float64Array(PHASES.length);this.items=new Float64Array(PHASES.length);
 }
 beginWindow(proof){
  if(!this.enabled)return false;
  if(this.scope||!proof||proof.pid!==this.pid||typeof proof.createdFileTimeUtcExact!=='string'||!/^\d{16,20}$/.test(proof.createdFileTimeUtcExact)||!/^[a-z0-9-]{1,80}$/.test(proof.window??'')||!Number.isSafeInteger(proof.connection)||proof.connection<0||!Number.isSafeInteger(proof.generation)||proof.generation<0)throw Error('Invalid independently watched window');
  this.scope=Object.freeze({pid:proof.pid,createdFileTimeUtcExact:proof.createdFileTimeUtcExact,window:proof.window,connection:proof.connection,generation:proof.generation});this.active=true;return true;
 }
 matches(scope){return this.active&&scope&&scope.connection===this.scope.connection&&scope.generation===this.scope.generation&&scope.window===this.scope.window;}
 clock(){try{const n=this.now();if(Number.isFinite(n)&&n>=0)return n;}catch{}this.dropped++;this.active=false;return -1;}
 begin(phase,scope){
  if(!this.enabled||!this.matches(scope))return 0;
  if(!Number.isInteger(phase)||phase<0||phase>=PHASES.length||this.tokens[phase]||this.counts[phase]>=this.maximum){this.dropped++;return 0;}
  const start=this.clock();if(start<0)return 0;this.starts[phase]=start;return this.tokens[phase]=++this.sequence;
 }
 end(phase,token,items=0){
  if(!token)return;
  if(!this.active||this.tokens[phase]!==token){this.dropped++;return;}
  this.tokens[phase]=0;const end=this.clock(),elapsed=end-this.starts[phase];
  if(end<0||elapsed<0||!Number.isSafeInteger(items)||items<0){this.dropped++;return;}
  const sum=this.sums[phase]+elapsed,total=this.items[phase]+items;if(!Number.isFinite(sum)||!Number.isSafeInteger(total)){this.dropped++;this.active=false;return;}
  this.counts[phase]++;this.sums[phase]=sum;this.maxima[phase]=Math.max(this.maxima[phase],elapsed);this.items[phase]=total;
 }
 measure(phase,scope,fn){const token=this.begin(phase,scope);try{return fn();}finally{this.end(phase,token);}}
 finishWindow(scope){if(!this.enabled)return null;if(!this.matches(scope))return null;for(const t of this.tokens)if(t)this.dropped++;this.active=false;return this.inspect();}
 inspect(){return{version:1,enabled:this.enabled,active:this.active,expectedIdentity:this.scope??null,identitySource:'Caller expected lifetime; MUST externally join exact watcher PID/FILETIME before acceptance',maximum:this.maximum,dropped:this.dropped,phases:PHASES.map((name,id)=>({id,name,count:this.counts[id],sum_usec:this.sums[id],maximum_usec:this.maxima[id],items:this.items[id]})),clockDomain:'local producer monotonic; never add host and native elapsed as one serial frame',perObjectTiming:false,objectPayloadsRetained:false};}
}
module.exports={AggregateProbe,PHASES};
