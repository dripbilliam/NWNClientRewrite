import {readReliableFrame,writeReliableFrame,frameNumberBetween} from './network_frames.js';
import {isNetworkBytes} from './network_bytes.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

const diagnostic=({code,reason,...context})=>runtimeDiagnostics.record(code,reason,context,'warning');
// Original FrameReceive23c5d0, FrameSend23d1e0, Initialize245990. Message
// assembly/compression and UDP encryption are distinct owners. Window sizes and
// initial timers are native defaults; adaptive resizing is still a separate task.
export class NetworkWindow{
 constructor({now=0,onDiagnostic=diagnostic}={}){
  this.onDiagnostic=onDiagnostic;this.first=0;this.next=0;this.expected=0;this.end=16;this.capacity=16;
  this.outgoing=new Map();this.incoming=new Map();this.queued=[];this.nakEnabled=true;this.compression=false;
  this.ackDelay=2000;this.resendDelay=3500;this.ackAt=now+this.ackDelay;this.lastReceived=now;
 }
 sendFrame(kind,sequence,frame,now){
  const bytes=writeReliableFrame({kind,sequence,expected:this.expected,compression:this.compression,frame});
  this.ackAt=now+this.ackDelay;if(kind===2)this.nakEnabled=false;
  if(kind===0){const pending=this.outgoing.get(sequence);if(pending)pending.deadline=now+this.resendDelay;}
  return bytes;
 }
 enqueue(frame,now){
  if(!isNetworkBytes(frame)||frame.length<12||frame.length>65466)throw new Error('Invalid native outgoing frame');
  this.queued.push(Uint8Array.from(frame));return this.load(now);
 }
 load(now){
  const send=[];while(this.queued.length&&this.outgoing.size<this.capacity){
   const frame=this.queued.shift(),sequence=this.next;this.next=(this.next+1)&65535;
   this.outgoing.set(sequence,{frame,deadline:0});send.push(this.sendFrame(0,sequence,frame,now));
  }return send;
 }
 receive(bytes,now){
  let frame;try{frame=readReliableFrame(bytes);}catch{this.onDiagnostic({code:'network.frame-rejected',reason:'Malformed, unsupported or corrupt native reliable frame'});return{accepted:false,send:[],delivered:[]};}
  this.lastReceived=now;const {kind,sequence,acknowledgement}=frame,send=[],delivered=[];
  if(kind===0){
   const within=frameNumberBetween(this.expected,sequence,this.end);
   if(within&&sequence!==this.expected&&this.nakEnabled)send.push(this.sendFrame(2,0,null,now));
   if(within&&!this.incoming.has(sequence)){
    this.incoming.set(sequence,frame);
    while(this.incoming.has(this.expected)){
     delivered.push(this.incoming.get(this.expected));this.incoming.delete(this.expected);
     this.expected=(this.expected+1)&65535;this.end=(this.end+1)&65535;this.nakEnabled=true;
    }
   }
  }else if(kind===2){
   const requested=(acknowledgement+1)&65535;
   if(frameNumberBetween(this.first,requested,this.next)){
    const pending=this.outgoing.get(requested);if(pending)send.push(this.sendFrame(0,requested,pending.frame,now));
   }
  }
  const acknowledged=[];
  while(frameNumberBetween(this.first,acknowledgement,this.next)){
   acknowledged.push(this.first);this.outgoing.delete(this.first);this.first=(this.first+1)&65535;
  }
  send.push(...this.load(now));return{accepted:true,send,delivered,acknowledged};
 }
 poll(now){
  const send=[];let expired=null;
  for(const [sequence,frame]of this.outgoing)if(frame.deadline<now&&(!expired||frame.deadline<expired.frame.deadline))expired={sequence,frame};
  if(expired)send.push(this.sendFrame(0,expired.sequence,expired.frame.frame,now));
  if(this.ackAt<now)send.push(this.sendFrame(1,0,null,now));return send;
 }
}
