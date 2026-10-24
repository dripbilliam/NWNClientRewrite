import {GameplayText,richText} from './gameplay-text.mjs';
import {NetworkFeedbackView,nativeDamageFeedbackOptions} from '../../src/network_feedback_view.js';

// Presentation IO cannot hold authoritative packet decoding or asset staging.
// Independent queues preserve speech/dialog order without blocking examination
// on portraits. Every completion retains its session + area-generation owner.
export class GameplayDelivery {
 constructor({session,connection,text,active,send,portrait=async()=>null,feedbackOptions=()=>({}),diagnose=()=>{}}){
  Object.assign(this,{session,connection,text,active,send,portrait,feedbackOptions,diagnose});
  this.adapter=new GameplayText({world:session.world,text});this.epoch=0;this.dialogRevision=0;this.examineRevision=0;this.lanes=new Map();
 }
 reset(){this.epoch++;this.dialogRevision++;this.examineRevision++;this.feedback?.reset();this.feedback=null;this.feedbackKey=null;this.lanes.clear();}
 receive(message,generation){
  const scope={connection:this.connection,areaId:this.session.world.areaId,generation},epoch=this.epoch;
  const current=()=>epoch===this.epoch&&this.active()&&!this.session.closed&&this.session.areaGeneration===generation&&this.session.world.areaId===scope.areaId;
  const send=payload=>{if(payload&&current())this.send({...payload,...scope});};
  if(message.kind==='dialog-close'){this.dialogRevision++;send({kind:'dialog-close'});return Promise.resolve();}
  const dialog=message.kind.startsWith('dialog-'),examine=message.kind==='examine';
  if(dialog&&message.kind==='dialog-entry')this.dialogRevision++;
  const version=examine?++this.examineRevision:this.dialogRevision;
  const lane=examine?'examine':dialog?'dialog':message.kind==='server-speech'||message.kind==='system-notice'?'speech':'feedback';
  // Examination responses supersede previous slow ones, so don't queue them.
  const previous=examine?Promise.resolve():this.lanes.get(lane)??Promise.resolve();
  const task=previous.then(async()=>{
   if(!current()||dialog&&version!==this.dialogRevision||examine&&version!==this.examineRevision)return;
   if(message.kind==='server-speech')send(await this.adapter.speech(message));
   else if(message.kind==='system-notice')send(await this.adapter.notice(message));
   else if(dialog){const payload=await this.adapter.dialog(message);if(version===this.dialogRevision)send(payload);}
   else if(examine){
    const payload=await this.adapter.examine(message);
    if(!current()||version!==this.examineRevision)return;
    send({...payload,revision:version});
    if(payload.detailError)this.diagnose('godot.examine-detail-unavailable',payload.detailError);
    if(payload.portrait)void this.portrait(payload.portrait).then(image=>{if(image&&version===this.examineRevision)send({kind:'examine-portrait',targetId:message.targetId,revision:version,image});}).catch(()=>{if(current()&&version===this.examineRevision)this.diagnose('godot.examine-portrait-unavailable','Portrait preparation failed');});
   }else{
    const key=scope.areaId+':'+generation;
    if(this.feedbackKey!==key){
     this.feedback?.reset();this.feedbackKey=key;
     this.feedback=new NetworkFeedbackView({world:()=>current()?this.session.world:null,text:()=>this.text,tables:()=>null,
      options:()=>({...nativeDamageFeedbackOptions(),...this.feedbackOptions()}),
      display:row=>send({kind:'chat',system:true,rich:{text:row.text,spans:row.richText},category:row.category}),
      floating:event=>send({kind:'floating',objectId:event.objectId,rich:richText(event.raw),rgb:event.rgb,font:event.font,flags:event.flags}),
      report:(code,reason)=>this.diagnose(code,reason)});
    }
    await this.feedback.receive(message);
   }
  }).catch(error=>{if(current()){this.diagnose('godot.gameplay-text-unavailable',error.message);send({kind:'error',text:'Some server text could not be resolved.'});}});
  this.lanes.set(lane,task);return task;
 }
}
