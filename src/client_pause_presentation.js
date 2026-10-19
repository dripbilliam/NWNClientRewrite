import {WorldTimer,subtractWorldTimes} from './world_timer.js';
import {ClientObjectArray} from './client_object_array.js';
import {serverObjectIdForClient} from './client_projectile_message.js';
import {setClientPauseState,receiveClientPauseMessage,clientActiveTimer} from './client_pause.js';
// Scalar projection of sender4dd0c0. BOOL and2-bit BYTE narrow independently;
// all IDs are written even if the WORD count wraps. No raw packet framing.
export function localPauseFields(data){
 if(!Number.isInteger(data.mask)||!Number.isInteger(data.value)||!Array.isArray(data.exclusionIds))throw new Error('Native local pause message fields are unavailable');
 return{mask:data.mask&3,value:data.value&1,count:data.exclusionIds.length&65535,ids:data.exclusionIds.map(serverObjectIdForClient)};
}
export class ClientPausePresentation{
 constructor({session,report,scene=()=>null}){Object.assign(this,{session,report,scene});this.pending=[];this.events=[];this.reported=new Set();this.state=null;}
 once(code,message,context){const key=JSON.stringify([code,context]);if(!this.reported.has(key)){this.reported.add(key);this.report(code,message,context);}}
 initialize(){
  if(this.state)return;const s=this.session(),clock=()=>BigInt(Math.trunc(s.scheduler.time*1000)),world=new WorldTimer(clock),one=new WorldTimer(clock),two=new WorldTimer(clock);
  world.setMinutesPerHour(s.worldTimer.minutesPerHour);const now=s.worldTimer.time();world.setTime(now.day,now.time);one.reset(world);two.reset(world);
  this.state={world,timer1:one,timer2:two,flags:0,exclusions:[],gui:null,profileMode:0,controlledId:serverObjectIdForClient(s.player.id)};
  this.objects=new ClientObjectArray({objects:()=>s.registry.objects.values(),render:()=>null});this.objects.sync();
 }
 receive(event){
  if(event.type!=='module-pause-state')return false;const s=this.session();if(event.recipientId!==s.player?.id)return true;
  try{this.pending.push({session:s,fields:localPauseFields(event.data)});}catch(error){this.report('client.pause-message-failed',error.message,{recipientId:event.recipientId});}return true;
 }
 snapshotClocks(){this.initialize();for(const timer of [this.state.world,this.state.timer1,this.state.timer2])timer.snapshot();}
 providers(){return{
  pause:t=>t.pause(),unpause:t=>t.unpause(),snapshot:t=>t.snapshot(),syncPrevious:t=>{t.previousCounter=t.counter;},reset:(t,from)=>t.reset(from),
  object:id=>this.objects.get(id)??null,asObject:o=>o.objectType>=5&&o.objectType<=14?o:null,scene:o=>this.scene(o.canonical.id),
  sceneVirtual:(_scene,offset)=>this.once('client.pause-scene-adapter-incomplete','Native pause scene virtuals require further scene-owner parity checks',{offset}),
  resetObjectTimes:(o,day,time)=>{if(o.objectType===5){o.nativeFrameDay50=day>>>0;o.nativeFrameTime54=time>>>0;}else this.once('client.pause-object-reset-incomplete','Native pause reset for this client object type is unavailable',{objectType:o.objectType,objectId:o.id});},
  disposeIncoming:owned=>{owned.ids=[];owned.capacity=0;owned.disposed=true;},
  pauseText:messageId=>this.once('client.pause-gui-adapter-incomplete','Native manual-pause text and GUI pause ownership are not connected',{messageId}),
  audio:paused=>this.once('client.pause-audio-adapter-incomplete','Native pause audio callbacks are not connected',{paused}),
  guiActive:()=>0,guiBlocked:()=>{},guiSetFlags:()=>{},guiClearFlags:()=>{}
 };}
 flush(){
  this.snapshotClocks();this.objects.sync();
  for(const message of this.pending.splice(0)){
   if(message.session!==this.session())continue;const fields=message.fields;let index=0;
   receiveClientPauseMessage({allocateIncoming:()=>{},byte:()=>fields.mask,bool:()=>fields.value,word:()=>fields.count,objectId:()=>fields.ids[index++]??0,overflow:()=>Number(index>fields.ids.length),
    apply:(mask,value,owned)=>setClientPauseState(this.state,mask,value,owned,this.providers()),gui:()=>null,refreshGui:()=>{},
    unconsumedIncoming:(owned,reason)=>this.once('client.pause-unconsumed-exclusions','Native receiver left an incoming exclusion list unconsumed; JS ownership is released by GC',{reason,count:owned.ids.length})});
   this.events.push({mask:fields.mask,value:fields.value,flags:this.state.flags,exclusions:[...this.state.exclusions]});if(this.events.length>100)this.events.shift();
  }
 }
 // Original creature AI7fbd10 selects a client active clock, subtracts its
 // previous50/54 pair, then stores a freshly selected pair. This local render
 // projection accumulates that delta so model clips survive native rebasing.
 now(canonicalId){
  if(!this.state)this.initialize();const id=serverObjectIdForClient(canonicalId);let o=this.objects.get(id);if(!o){this.objects.sync();o=this.objects.get(id);}if(!o)throw new Error('Client animation canonical mirror is unavailable');const timer=clientActiveTimer(this.state,id),now=timer.time();
  if(o.presentationTime===undefined){o.presentationTime=this.session().scheduler.time;o.nativeFrameDay50=now.day;o.nativeFrameTime54=now.time;return o.presentationTime;}
  const delta=subtractWorldTimes(now,{day:o.nativeFrameDay50,time:o.nativeFrameTime54},this.state.world.dayLength);
  if(delta.status!==0){
   this.report('client.pause-clock-undefined','Native client creature elapsed output is unwritten after backwards time; preserving the pose and rebasing the local render stamp',{objectId:id,now,previous:{day:o.nativeFrameDay50,time:o.nativeFrameTime54},status:delta.status});
   o.nativeFrameDay50=now.day;o.nativeFrameTime54=now.time;return o.presentationTime;
  }
  o.presentationTime+=delta.time;o.nativeFrameDay50=now.day;o.nativeFrameTime54=now.time;return o.presentationTime;
 }
 snapshot(){if(!this.state)return null;const s=this.state;return{flags:s.flags,exclusions:[...s.exclusions],world:s.world.time(),one:s.timer1.time(),two:s.timer2.time(),events:this.events};}
}
