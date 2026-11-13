import {NativeMessageWriter} from '../../src/native_message.js';
// Original client input wrapper8055c0 -> sender7c02e0 -> input6/10 BYTE.
// Search0, stealth1, counterspell5 and defensive casting10; activity outcomes
// remain authoritative. The caller supplies a current actor/area scope.
export function activityRequest(activityId,targetId=0x7f000000){
 if(![0,1,5,10].includes(activityId)||activityId===5&&(!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff))throw Error('Invalid native radial activity');
 const writer=new NativeMessageWriter(1);writer.create(4,0xffffffff,1);writer.writeByte(activityId);if(activityId===5)writer.writeObjectIdClient(targetId);writer.setPrefix(Uint8Array.of(112,6,10));return Uint8Array.from(writer.getWriteMessage().data);
}
export async function submitNativeActivity(session,scope,input){
 const actor=session.controlledActor(scope.areaId,scope.areaGeneration);
 if(actor!==scope.actor||actor.id!==scope.actorId)throw Error('Activity input belongs to a retired actor');
 if(input.activityId===5){
  if(input.targetId===undefined||input.targetId===0x7f000000){if(!Number.isInteger(actor.playerState?.playerFlags)||(actor.playerState.playerFlags&512)===0)throw Error('Counterspell cancellation requires current server mode4');}
  else{const target=session.world.registry.get(input.targetId);if(!target||target.id===actor.id||target.objectType!==5||target.replicationRemoved||target.areaId!==scope.areaId)throw Error('Counterspell target is not a current creature');}
 }
 await session.peer.sendGameMessage(activityRequest(input.activityId,input.targetId));return{sent:true};
}
