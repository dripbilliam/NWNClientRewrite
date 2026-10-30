import {Worker} from 'node:worker_threads';
import {performance} from 'node:perf_hooks';
export const frameKinds=new Set(['session-reset','setup','raw-world-begin','raw-world-chunk','raw-world-end','movement','raw-visual-events','raw-combat-events','raw-voice-events','raw-script-sounds','ui-protocol']);
export const ackKinds=new Set(['catalog-ready','area-ready','raw-world-accepted']);
export function ackKey(value){return JSON.stringify([value.kind,value.connection??0,value.generation??null,value.serial??null]);}
export class NativeLoadingRecording {
 constructor(directory,{maximumQueued=256*1024*1024}={}){
  this.directory=directory;this.maximumQueued=maximumQueued;this.pending=0;this.serial=0;this.started=performance.now();this.failure=null;this.closed=false;
  this.worker=new Worker(new URL('./native-loading-writer.mjs',import.meta.url),{workerData:{directory}});
  this.worker.on('message',message=>{if(message.kind==='ack')this.pending-=message.bytes;else if(message.kind==='failure')this.failure=message.reason;else if(message.kind==='sealed'){this.sealed=message;this.resolve?.(message);}});
  this.worker.on('error',error=>{this.failure=error.message;this.resolve?.({complete:false,reason:error.message});});
  this.worker.on('exit',()=>{if(!this.sealed){this.failure??='Recording writer exited before sealing';this.resolve?.({complete:false,reason:this.failure});}});
 }
 write(kind,text){
  if(this.closed||this.failure)return false;const bytes=Buffer.byteLength(text);
  if(bytes>1024*1024+1||this.pending+bytes>this.maximumQueued){this.failure='Native loading recording queue/frame bound exceeded';return false;}
  this.pending+=bytes;this.worker.postMessage({kind,text,bytes,sequence:++this.serial,at:performance.now()-this.started});return true;
 }
 frame(value,text){return frameKinds.has(value.kind)?this.write('frame',text):false;}
 acknowledgement(value){return ackKinds.has(value.kind)?this.write('acknowledgement',JSON.stringify({kind:value.kind,connection:value.connection??0,generation:value.generation??null,serial:value.serial??null})):false;}
 view(value){return value?.position?.length===3?this.write('view',JSON.stringify(value)):false;}
 baseline(value){return this.write('baseline',JSON.stringify(value));}
 async close(metadata={}){
  if(this.closing)return this.closing;this.closed=true;
  this.closing=new Promise(resolve=>{this.resolve=resolve;if(this.sealed)resolve(this.sealed);else if(this.worker.threadId===-1)resolve({complete:false,reason:this.failure});else this.worker.postMessage({kind:'close',failure:this.failure,metadata});});
  const result=await this.closing;await this.worker.terminate();return result;
 }
}
