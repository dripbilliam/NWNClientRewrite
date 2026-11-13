// Optional diagnostic companion to the existing original-byte loading capture.
// No sockets, credentials, world store, physics or rendering are owned here.
import {createHash} from 'node:crypto';
import {NativeLoadingRecording} from './native-loading-recording.mjs';
export const movementEventKinds=new Set(['movement-input','movement-dispatch','movement-sample','network-game-packet']);
const integer=(v,max=0xffffffff)=>Number.isSafeInteger(v)&&v>=0&&v<=max;
const scope=v=>integer(v?.connection)&&integer(v?.generation)&&integer(v?.areaId);
const vector=v=>Array.isArray(v)&&v.length>=2&&v.length<=3&&v.every(Number.isFinite);
export function movementInput(value){
 if(value?.kind!=='drive'||!scope(value)||!integer(value.actorId)||!integer(value.lifetime)||!integer(value.requestId)||!['drive','turn','stop'].includes(value.operation))return null;
 if(value.operation==='drive'&&(!integer(value.flags,63)||value.flags===0||!integer(value.heading,3599)||!vector(value.position)||typeof value.transmit!=='boolean'))return null;
 if(value.operation==='turn'&&!vector(value.position))return null;
 const out={kind:'drive',connection:value.connection,generation:value.generation,areaId:value.areaId,actorId:value.actorId,lifetime:value.lifetime,requestId:value.requestId,operation:value.operation};
 for(const name of ['position','flags','heading','transmit'])if(value[name]!==undefined)out[name]=structuredClone(value[name]);
 if(value.movementTrace&&typeof value.movementTrace==='object')out.movementTrace=structuredClone(value.movementTrace);
 return out;
}
export function validMovementEvent(kind,value){
 if(!movementEventKinds.has(kind)||!scope(value))return false;
 if(kind==='movement-input'||kind==='movement-dispatch')return movementInput(value)!==null;
 if(kind==='movement-sample')return value.kind==='movement-sample'&&integer(value.native_ticks_us,Number.MAX_SAFE_INTEGER)&&integer(value.native_frame,Number.MAX_SAFE_INTEGER)&&integer(value.actorId)&&integer(value.lifetime)&&value.state!==null&&typeof value.state==='object';
 if(!['received','sent'].includes(value.direction)||!integer(value.bytes,786400)||value.bytes<3||typeof value.base64!=='string'||!/^[0-9a-f]{64}$/.test(value.sha256))return false;
 const bytes=Buffer.from(value.base64,'base64');
 return bytes.length===value.bytes&&bytes[0]===(value.direction==='received'?80:112)&&createHash('sha256').update(bytes).digest('hex')===value.sha256&&(value.direction!=='sent'||bytes[1]===6&&[1,28,29,33].includes(bytes[2]));
}
export class MovementTimingRecording extends NativeLoadingRecording {
 constructor(directory,options){super(directory,options);this.attached=new WeakSet();this.timingCounts={input:0,dispatch:0,samples:0,received:0,sent:0};}
 input(value){const row=movementInput(value);if(!row)return false;this.timingCounts.input++;return this.write('movement-input',JSON.stringify(row));}
 dispatch(value){const row=movementInput(value);if(!row)return false;this.timingCounts.dispatch++;return this.write('movement-dispatch',JSON.stringify(row));}
 movementSample(value){
  if(!validMovementEvent('movement-sample',value))return false;
  // Deliberately project named fields; do not serialize arbitrary client input.
  const row={kind:'movement-sample',connection:value.connection,generation:value.generation,areaId:value.areaId,actorId:value.actorId,lifetime:value.lifetime,native_ticks_us:value.native_ticks_us,native_frame:value.native_frame,state:value.state,keyboard:value.keyboard??{}};
  this.timingCounts.samples++;return this.write('movement-sample',JSON.stringify(row));
 }
 packet(direction,current,connection,bytes){
  if(!['received','sent'].includes(direction)||current.closed||current.phase!=='playing'||!integer(connection)||!integer(current.areaGeneration)||!integer(current.world?.areaId)||!bytes||bytes.length<3||bytes.length>786400||bytes[0]!==(direction==='received'?80:112))return false;
  // Login, keys, handshake and arbitrary outgoing chat/actions are excluded.
  if(direction==='sent'&&(bytes[1]!==6||![1,28,29,33].includes(bytes[2])))return false;
  const copy=Buffer.from(bytes),row={direction,connection,generation:current.areaGeneration,areaId:current.world.areaId,bytes:copy.length,major:copy[1],minor:copy[2],base64:copy.toString('base64'),sha256:createHash('sha256').update(copy).digest('hex')};
  this.timingCounts[direction]++;return this.write('network-game-packet',JSON.stringify(row));
 }
 attach(current,connection){
  if(this.attached.has(current))return;this.attached.add(current);
  const recorder=this,peer=current.peer,original=peer.sendGameMessage;
  const observe=(direction,bytes)=>{try{recorder.packet(direction,current,connection,bytes);}catch(error){recorder.failure??='Movement capture: '+error.message;}};
  peer.prependListener('message',bytes=>observe('received',bytes));
  peer.sendGameMessage=function(bytes,...options){observe('sent',bytes);return original.call(this,bytes,...options);};
 }
 close(metadata={}){return super.close({...metadata,movementTiming:true,movementCounts:{...this.timingCounts},movementPolicy:'Original reliable gameplay-message arrival/send boundaries after decryption, playing phase only; outgoing movement only. Also original presentation delivery, native movement decisions/frame samples, command dispatch and drive replies. No UDP authentication/retransmission emulation or automated public gameplay.'});}
}

// A cold replay may finish resource preparation later than the recording.
// Shift at recorded loading-readiness gates; never remove subsequent network
// gaps or silently replay the user's input in a burst after a slow load.
export class MovementReplayClock {
 constructor(){this.shift=0;this.gates=0;this.maxLate=0;this.lateEvents=0;}
 due(row){return row.at+this.shift;}
 ready(row,elapsed){return elapsed>=this.due(row);}
 consume(row,elapsed){
  const late=Math.max(0,elapsed-this.due(row));this.maxLate=Math.max(this.maxLate,late);if(late>25)this.lateEvents++;
  if(row.kind==='acknowledgement'&&['catalog-ready','area-ready'].includes(row.value.kind)&&late>0){this.shift+=late;this.gates++;}
 }
 snapshot(){return {loadingShiftMs:this.shift,loadingGates:this.gates,maxDeliveryLatenessMs:this.maxLate,eventsOver25msLate:this.lateEvents,policy:'Recorded gaps on a monotonic clock; shift only for loading-readiness gates. Late runtime events remain measured, not claimed to match the original network.'};}
}
