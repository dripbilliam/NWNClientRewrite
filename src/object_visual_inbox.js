import {deliverObjectVisual,snapshotObjectVisual} from './object_visual_delivery.js';
import {nativeStringEntry} from './spell_metadata.js';

// Local server message boundary. Capture sender positions immediately; browser
// asset latency must not turn a visual addressed to one actor into a new actor
// that later reuses its ID. Client-only dummy allocation is a separate owner.
export class ObjectVisualInbox{
 constructor({session,report}){this.session=session;this.report=report;this.pending=[];}
 receive(event){
  if(event.type!=='visualEffect')return false;
  const session=this.session();
  if(event.recipientId!==session.player?.id)return true;
  try{
   if(event.data.targetId===undefined){
    this.report('visual.area-message-unimplemented','Native area visual receiver and point ownership are not connected',{visualId:event.data.visualId,position:event.data.position});return true;
   }
   const message=snapshotObjectVisual(event.data,session.registry),target=session.registry.get(message.targetId);
   this.pending.push({message,target,areaId:target?.areaId??session.player.areaId,reported:false});
  }catch(error){this.report('visual.message-failed',error.message,{visualId:event.data?.visualId,stack:error.stack});}
  return true;
 }
 flush({session,objects,presentation}){
  if(session!==this.session()||objects.registry!==session.registry||!presentation)return;
  this.pending=this.pending.filter(entry=>{
   const {message,target,areaId}=entry,data={visualId:message.visualId,targetId:message.targetId,sourceId:message.sourceId};
   if(target&&session.registry.get(target.id)!==target){this.report('visual.message-target-stale','Visual target was destroyed or replaced before presentation',data);return false;}
   if(areaId!==objects.areaId||target&&target.areaId!==areaId){this.report('visual.message-area-stale','Visual message belongs to a previous area',data);return false;}
   if(target&&!objects.renderBindings.has(target.id)){
    if(!entry.reported){entry.reported=true;this.report('visual.message-binding-pending','Visual is waiting for its canonical target render binding',data);}
    return true;
   }
   try{
    let dummyFailure=false;
    const result=deliverObjectVisual(message,{visualType:id=>nativeStringEntry(session.characterRules.visualeffects,id,'Type_FD'),object:id=>session.registry.get(id),renderObject:o=>o,
     createDummy:(role,position,lifetime)=>{dummyFailure=true;this.report('visual.client-dummy-unimplemented','Native client-only dummy registration and lifetime are not connected',{...data,role,position,lifetime});return null;},
     add:(actor,record)=>presentation.addTransient(actor,record)});
    if(result!==1&&!dummyFailure)this.report('visual.message-target-unavailable','Native visual receiver could not resolve its target',data);
   }catch(error){this.report('visual.message-failed',error.message,{...data,stack:error.stack});}
   return false;
  });
 }
}
