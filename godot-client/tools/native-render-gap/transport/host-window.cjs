'use strict';
const fs=require('node:fs'),path=require('node:path');
const {AggregateProbe}=require('./aggregate-probe.cjs');
const apply=Reflect.apply,NO_ARGS=Object.freeze([]);
function readControlBounded(file,io=fs){const fd=io.openSync(file,'r');try{const bytes=Buffer.alloc(16385);let used=0;while(used<bytes.length){const n=io.readSync(fd,bytes,used,bytes.length-used,null);if(n===0)break;used+=n;}return bytes.subarray(0,used);}finally{io.closeSync(fd);}}
function* measuredFrames(iterable,begin,end){
 const iterator=iterable[Symbol.iterator]();if(iterator===null||(typeof iterator!=='object'&&typeof iterator!=='function'))throw TypeError('Iterator is not an object');const next=iterator.next;let done=false,nextFailed=false;
 try{for(;;){let value;const token=begin();try{const item=apply(next,iterator,NO_ARGS);if(item===null||(typeof item!=='object'&&typeof item!=='function'))throw TypeError('Iterator result is not an object');if(item.done){done=true;return;}value=item.value;}catch(error){nextFailed=true;throw error;}finally{end(token);}yield value;}}
 finally{if(!done&&!nextFailed){const close=iterator.return;if(close!==undefined&&close!==null){if(typeof close!=='function')throw TypeError('Iterator return is not callable');const result=apply(close,iterator,NO_ARGS);if(result===null||(typeof result!=='object'&&typeof result!=='function'))throw TypeError('Iterator return is not an object');}}}
}
class HostWindow {
 constructor({project,enabled=false,controlFile='',send,env=process.env,readFile=readControlBounded,pid=process.pid}={}){
  this.enabled=enabled===true;this.active=false;this.project=project;this.send=send;this.readFile=readFile;this.pid=pid;this.status='disabled';this.probe=new AggregateProbe({enabled:this.enabled,pid});this.proof=null;this.finished=false;
  if(!this.enabled)return;
  const base=path.resolve(project,'.cache/native-transport');this.file=path.resolve(controlFile||env.NWN_PRIVATE_TRANSPORT_CONTROL||path.join(base,'window.json'));
  if(this.file===base||!this.file.startsWith(base+path.sep))throw Error('Private transport control must stay inside the private project cache');this.status='waiting-for-independent-lifetimes';
 }
 valid(proof,context){return proof&&typeof proof==='object'&&proof.version===1&&proof.host?.pid===this.pid&&proof.native?.pid===context.nativePid&&typeof proof.host.createdFileTimeUtcExact==='string'&&typeof proof.native.createdFileTimeUtcExact==='string'&&/^\d{16,20}$/.test(proof.host.createdFileTimeUtcExact)&&/^\d{16,20}$/.test(proof.native.createdFileTimeUtcExact)&&typeof proof.window==='string'&&/^[a-z0-9-]{1,80}$/.test(proof.window)&&proof.connection===context.connection&&proof.generation===context.generation&&Number.isSafeInteger(proof.connection)&&proof.connection>=0&&Number.isSafeInteger(proof.generation)&&proof.generation>=0;}
 observe(context){
  if(!this.enabled||this.finished)return null;
  let proof;try{const bytes=this.readFile(this.file);if(bytes.length>16384){this.status='rejected-control-bound';return null;}proof=JSON.parse(bytes.toString('utf8'));}catch(error){if(error.code!=='ENOENT')this.status='rejected-control-read';return null;}
  if(!this.valid(proof,context)){this.status='rejected-control-scope';return null;}
  if(!this.proof&&proof.command==='begin'){this.proof=Object.freeze({version:1,command:'begin',connection:proof.connection,generation:proof.generation,window:proof.window,host:Object.freeze({pid:proof.host.pid,createdFileTimeUtcExact:proof.host.createdFileTimeUtcExact}),native:Object.freeze({pid:proof.native.pid,createdFileTimeUtcExact:proof.native.createdFileTimeUtcExact})});this.status='awaiting-native-open';this.send({kind:'transport-window-begin',connection:proof.connection,generation:proof.generation,proof:{...this.proof.native,connection:proof.connection,generation:proof.generation,window:proof.window}});}
  else if(this.proof&&proof.command==='end'&&proof.window===this.proof.window&&this.status==='active'){this.active=false;this.hostResult=this.probe.finishWindow(this.probe.scope);this.status='awaiting-native-close';this.send({kind:'transport-window-end',connection:proof.connection,generation:proof.generation,window:proof.window});}
  return null;
 }
 receive(message,context){
  if(!this.enabled||!this.proof||!this.valid(this.proof,context)||message.connection!==this.proof.connection||message.generation!==this.proof.generation||message.window!==this.proof.window||message.process_id!==this.proof.native.pid||message.expected_created_filetime_exact!==this.proof.native.createdFileTimeUtcExact)return null;
  if(message.kind==='transport-window-opened'&&this.status==='awaiting-native-open'&&message.success===true){this.probe.beginWindow({...this.proof.host,window:this.proof.window,connection:this.proof.connection,generation:this.proof.generation});this.active=true;this.status='active';}
  else if(message.kind==='transport-window-closed'&&this.status==='awaiting-native-close'){this.finished=true;const r=message.result,names=['native_commit','native_snapshot','native_protocol_encode'];const valid=r&&r.enabled===true&&r.process_id===this.proof.native.pid&&r.expected_created_filetime_exact===this.proof.native.createdFileTimeUtcExact&&r.connection===this.proof.connection&&r.generation===this.proof.generation&&r.window===this.proof.window&&r.dropped===0&&Array.isArray(r.phases)&&r.phases.length===3&&r.phases.every((p,i)=>p.name===names[i]&&Number.isSafeInteger(p.count)&&p.count>=0&&p.count<=100000&&Number.isFinite(p.sum_usec)&&p.sum_usec>=0&&Number.isFinite(p.maximum_usec)&&p.maximum_usec>=0);this.status=valid?'closed':'rejected-native-close';this.nativeResult=valid?{enabled:true,process_id:r.process_id,expected_created_filetime_exact:r.expected_created_filetime_exact,connection:r.connection,generation:r.generation,window:r.window,dropped:0,phases:r.phases.map((p,i)=>({name:names[i],count:p.count,sum_usec:p.sum_usec,maximum_usec:p.maximum_usec}))}:null;return this.receipt();}
  return null;
 }
 scope(connection,generation){return this.active&&connection===this.proof.connection&&generation===this.proof.generation?this.probe.scope:null;}
 measure(phase,connection,generation,fn){return this.probe.measure(phase,this.scope(connection,generation),fn);}
 frames(iterable,connection,generation){return measuredFrames(iterable,()=>this.probe.begin(2,this.scope(connection,generation)),token=>this.probe.end(2,token));}
 abort(){if(!this.enabled)return null;if(this.active)this.hostResult=this.probe.finishWindow(this.probe.scope);this.active=false;if(!this.finished)this.status='aborted-before-matched-close';return this.receipt();}
 receipt(){return{version:1,enabled:this.enabled,status:this.status,expectedProof:this.proof,host:this.hostResult??null,native:this.nativeResult??null,performanceAccepted:false,diagnosticOnly:true,requiresExternalLifetimeJoin:true,scope:'Bounded private local diagnostic; supplied FILETIMEs require exact independent watcher joins. Host and native monotonic clocks are separate.'};}
}
module.exports={HostWindow,measuredFrames,readControlBounded};
