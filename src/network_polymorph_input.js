import {NativeMessageWriter} from './native_message.js';

// Original804cc0 ->7bf460: Input6/30 contains only the current client actor ID.
// Shape/lock/effect eligibility belongs to the authoritative server handler.
export function cancelPolymorphRequest({actorId}){
 if(!Number.isInteger(actorId)||actorId<0||actorId>0xffffffff)throw new Error('Invalid native polymorph actor');
 const writer=new NativeMessageWriter(1);writer.create(4,0xffffffff,1);writer.writeObjectIdClient(actorId);writer.setPrefix(Uint8Array.of(112,6,30));return Uint8Array.from(writer.getWriteMessage().data);
}
