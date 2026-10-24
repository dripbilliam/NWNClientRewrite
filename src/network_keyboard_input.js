import {driveTurnFacing,partialDriveSendTimestamp} from './network_drive_preview.js';
import {worldDriveKeys as keys,isTextEntry,isControlArrow} from './game_input.js';
// Keyboard drive protocol: original UI6f1e40, drive7bf980/452ec0,
// abort7bf040/452ba0, turn-only7c03b0. No replicated state is written.
export function keyboardDriveFlags(held,walk=false){
 const axis=(a,b)=>Number(held.has(a))-Number(held.has(b)),forward=axis('forward','back'),strafe=axis('strafeLeft','strafeRight'),turn=axis('left','right');
 return(forward>0?(walk?1:3):forward<0?2:0)|(strafe>0?4:strafe<0?8:0)|(turn>0?16:turn<0?32:0);
}
const identity=c=>c?`${c.sessionId}:${c.areaGeneration}:${c.areaId}:${c.actorId}:${c.motionLifetime??''}`:null;
const degrees=orientation=>Math.atan2(orientation[1],orientation[0])*180/Math.PI;
const quantize=angle=>Math.round(((angle%360)+360)%360*10)%3600;
export function keyboardActorContext(frontend){
 const world=frontend?.world,actor=world?.registry.get(world.localObjectId),position=actor?.replicated?.position,raw=actor?.replicated?.orientation,angle=raw?.yaw*Math.PI/180,orientation=Array.isArray(raw)?raw:raw?.vector??(Number.isFinite(angle)?[Math.fround(-Math.sin(angle)),Math.fround(Math.cos(angle)),0]:null);
 if(!frontend?.id||!Array.isArray(position)||position.length!==3||!position.every(Number.isFinite)||!Array.isArray(orientation)||orientation.length<2||!orientation.every(Number.isFinite))return null;
 return{sessionId:frontend.id,areaGeneration:frontend.areaGeneration,areaId:world.areaId,actorId:world.localObjectId,position,orientation};
}
export class NetworkKeyboardInput{
 constructor({context,enabled,send,preview=()=>{},stopPreview=()=>{},onSent=()=>{},onDriveHeading=()=>{},report=()=>{},events=window,document:doc=document,now=()=>performance.now()}){
  Object.assign(this,{context,enabled,send,preview,stopPreview,onSent,onDriveHeading,report,now});this.keys=new Set();this.queue=Promise.resolve();this.moving=false;this.lastFlags=0;this.lastAt=-Infinity;this.previewAt=-Infinity;this.inputPending=false;
  events.addEventListener('keydown',event=>{
   const current=this.context();if(!current)return;
   if(event.key==='Shift'){this.walk=event.shiftKey;return;}
   const key=keys[event.code];if(!key)return;
   if(event.defaultPrevented||!this.enabled()||event.altKey||event.ctrlKey||event.metaKey||isTextEntry(event.target)||isControlArrow(event))return;
   if(identity(current)!==identity(this.owner)){this.clear();this.owner={...current};}
   // Native16f880 admits SDL repeated key-downs;6ed720 sets input1b0
   // even when its held flag already has the same value.6f1e40 then
   // refreshes immediately instead of waiting for the periodic timers.
   event.preventDefault();event.stopImmediatePropagation();this.walk=event.shiftKey;this.keys.add(event.code);this.inputPending=true;this.update();
  },true);
  events.addEventListener('keyup',event=>{
   if(event.key==='Shift')this.walk=false;
   const key=keys[event.code];if(!key||!this.keys.has(event.code))return;
   this.keys.delete(event.code);event.preventDefault();event.stopImmediatePropagation();this.update();
  },true);
  events.addEventListener('blur',()=>this.clear());
  doc.addEventListener('visibilitychange',()=>{if(doc.hidden)this.clear();});
  events.addEventListener('focusin',event=>{if(isTextEntry(event.target))this.clear();});
 }
 enqueue(context,request){
  const token=identity(context);
  this.queue=this.queue.then(async()=>{
   if(identity(this.context())!==token)return;
   const result=await this.send(context,request);if(identity(this.context())===token)this.onSent(context,request,result);
  }).catch(error=>{if(identity(this.context())!==token)return;this.keys.clear();this.lastFlags=0;this.report(error);});
 }
 stop(){if(this.owner)this.stopPreview(this.owner);if(this.moving&&this.owner)this.enqueue(this.owner,{operation:'stop'});this.moving=false;}
 clear(){this.previewTicket=(this.previewTicket??0)+1;this.keys.clear();this.walk=false;this.inputPending=false;this.stop();this.lastFlags=0;this.lastAt=this.previewAt=-Infinity;}
 update(){
  const context=this.context();
  if(identity(context)!==identity(this.owner)){this.clear();this.owner=context?{...context}:null;}
  if(!context||!this.enabled()){this.clear();return;}
  const flags=keyboardDriveFlags(new Set([...this.keys].map(code=>keys[code])),this.walk),time=this.now();
  if(!flags){this.stop();this.inputPending=false;this.lastFlags=0;this.lastAt=this.previewAt=-Infinity;return;}
  const turnOnly=(flags&15)===0;
  const changed=this.inputPending||flags!==this.lastFlags,sendDue=changed||time-this.lastAt>=(turnOnly?250:500),previewDue=changed||sendDue||time-this.previewAt>=250;
  if(!previewDue)return;
  const facing=degrees(context.orientation);
  if(turnOnly){
   if(sendDue){this.stop();const direction=driveTurnFacing(context.orientation,flags);this.enqueue(context,{operation:'turn',position:direction.slice(0,2)});}
  }else{
   //6f1e40 advances2d2/last-input2d3 on every local tick, including ticks
   // that send no packet. Old server idle/path replies must remain stale.
   const heading=quantize(facing);this.enqueue(context,{operation:'drive',position:context.position.slice(0,2),heading,flags,transmit:sendDue});if(sendDue)this.onDriveHeading(context,heading);this.moving=true;
  }
  this.lastFlags=flags;this.inputPending=false;if(sendDue)this.lastAt=time;
  if(previewDue){
   this.previewAt=time;const ticket=this.previewTicket=(this.previewTicket??0)+1,token=identity(context),current=()=>ticket===this.previewTicket&&identity(this.context())===token&&identity(this.owner)===token&&this.lastFlags===flags&&this.enabled();
   // Original6f1bc0 brings the next wire tick forward after a shortened
   // direct path. It can precede the ordinary250ms local-preview interval.
   const complete=result=>{const fraction=result?.resendFraction;if(current()&&Number.isFinite(fraction)&&fraction>=0&&fraction<=1)this.lastAt=partialDriveSendTimestamp(this.now(),fraction);};
   try{const result=this.preview(context,flags);if(result&&typeof result.then==='function')void result.then(complete).catch(error=>{if(current())this.report(error);});else complete(result);}catch(error){if(current())this.report(error);}
  }
 }
}
