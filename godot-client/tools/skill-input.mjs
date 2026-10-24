import {NativeMessageWriter} from '../../src/native_message.js';
import {OBJECT_INVALID} from '../../src/game_object_array.js';

const packed=value=>Number.isInteger(value)&&value>=-0x80000000&&value<=0xffffffff;
// Original wrapper805480 splits the packed INT into skill BYTE and the low
// BYTE of its high WORD. Sender7c0860 always writes XYZ, including zero.
export function skillUseRequest({packedSkill,targetId,position=[0,0,0]}){
 if(!packed(packedSkill)||!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff||!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(Math.fround(v))))throw Error('Invalid native skill request');
 const writer=new NativeMessageWriter(1);writer.create(18,0xffffffff,1);
 writer.writeByte(packedSkill&255);writer.writeByte((packedSkill>>>16)&255);writer.writeObjectIdClient(targetId);
 for(const value of position)writer.writeFloat(Math.fround(value),1,32);
 writer.setPrefix(Uint8Array.of(112,6,7));return Uint8Array.from(writer.getWriteMessage().data);
}
export async function submitNativeSkill(session,scope,{packedSkill,targetId}){
 const actor=session.controlledActor(scope.areaId,scope.areaGeneration);
 if(actor!==scope.actor||actor.id!==scope.actorId||targetId===OBJECT_INVALID)throw Error('Skill input belongs to a retired actor or invalid target');
 session.validateCastTarget(scope.areaId,actor,targetId);
 await session.peer.sendGameMessage(skillUseRequest({packedSkill,targetId}));
 return{sent:true};
}
