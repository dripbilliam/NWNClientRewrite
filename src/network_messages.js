import {isNetworkBytes} from './network_bytes.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
const diagnostic=({code,reason,...context})=>runtimeDiagnostics.record(code,reason,context,'warning');
const be16=(bytes,at)=>(bytes[at]<<8)|bytes[at+1];

// PacketizeSendMessageToPlayer24d1e0: native uncompressed fragment capacity948.
// Native small-message coalescing/500ms scheduling is supplied by another owner.
export function packetizeUncompressedMessage(payload,{highPriority=true}={}){
 if(!isNetworkBytes(payload)||payload.length<1||payload.length>948*65535)throw new Error('Invalid native outgoing game-message size');
 const count=Math.ceil(payload.length/948),frames=[];
 for(let i=0;i<count;i++){
  const part=payload.subarray(i*948,(i+1)*948),frame=new Uint8Array(12+part.length),view=new DataView(frame.buffer);
  frame[7]=(highPriority?8:0)|(i===0?2:0);if(i===0)view.setUint16(8,count,false);
  if(count===1)view.setUint16(10,part.length,false);frame.set(part,12);frames.push(frame);
 }return frames;
}

// Original UnpacketizeFullMessages2566d0: independent priority queues,
// count1 packed records and count>1 first-header + continuation-payload assembly.
// Output is the full native record; decompression has a separate owner.
export class NetworkMessageAssembler{
 constructor({onDiagnostic=diagnostic}={}){this.queues={high:[],low:[]};this.onDiagnostic=onDiagnostic;}
 push(frame){
  if(!isNetworkBytes(frame)||frame.length<12)throw new Error('Invalid native message frame');
  this.queues[frame[7]&8?'high':'low'].push(Uint8Array.from(frame));
 }
 drain(){const messages=[];for(const priority of ['high','low']){
  const queue=this.queues[priority];while(queue.length){
   const first=queue[0],count=be16(first,8);
   if(count===0){queue.shift();this.onDiagnostic({code:'network.message-rejected',reason:'Native message begins with a continuation frame',priority});continue;}
   if(queue.length<count)break;
   const frames=queue.splice(0,count);
   if(count>1){
    const size=frames.reduce((n,f,i)=>n+f.length-(i?12:0),0),bytes=new Uint8Array(size);let at=0;
    for(let i=0;i<frames.length;i++){const part=frames[i].subarray(i?12:0);bytes.set(part,at);at+=part.length;}
    messages.push({priority,bytes});continue;
   }
   let at=0;while(first.length-at>=12){
    const flags=first[at+7];let size=be16(first,at+10);
    if(flags&128){if(first.length-at<14){this.reject(priority);break;}size+=first[at+12]*0x1000000+first[at+13]*0x10000;}
    size+=12;if(size>first.length-at){this.reject(priority);break;}
    messages.push({priority,bytes:Uint8Array.from(first.subarray(at,at+size))});at+=size;
   }
   if(at<first.length&&first.length-at<12)this.reject(priority);
  }
 }return messages;}
 reject(priority){this.onDiagnostic({code:'network.message-rejected',reason:'Truncated native packed message record',priority});}
}
