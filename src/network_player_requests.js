import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';

const uint=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
// Original sender1407c0970; receiver140455860; envelope dispatcher458b90.
// Preserve the native client namespace on the wire. No path, movement, action
// queue, animation or combat state is resolved by this encoder.
export function walkToWaypointRequest({areaId,position,sequence,run,clientPath=false,fractional=0,targetId=OBJECT_INVALID}){
 if(!uint(areaId)||!uint(targetId)||!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(Math.fround(v)))||!Number.isInteger(sequence)||sequence<0||sequence>255||![true,false,0,1].includes(run)||![true,false,0,1].includes(clientPath)||!Number.isInteger(fractional)||fractional<0||fractional>255)throw new Error('Invalid native waypoint request');
 const writer=new NativeMessageWriter(1);writer.create(0x12,0xffffffff,1);writer.writeObjectIdClient(areaId);
 for(const value of position)writer.writeFloat(value,1,32);
 writer.writeByte(sequence);writer.writeBool(Number(run));writer.writeBool(Number(clientPath));writer.writeByte(fractional);writer.writeObjectIdClient(targetId);writer.setPrefix(Uint8Array.of(112,6,1));
 return Uint8Array.from(writer.getWriteMessage().data);
}

function targetRequest(targetId,minor,size,fields=()=>{}){
 if(!uint(targetId))throw new Error('Invalid native interaction target');
 const writer=new NativeMessageWriter(1);writer.create(size,0xffffffff,1);writer.writeObjectIdClient(targetId);fields(writer);writer.setPrefix(Uint8Array.of(112,6,minor));return Uint8Array.from(writer.getWriteMessage().data);
}
// Original senders bf860/bf900/c07c0; server dispatcher4531b0. No local
// target rules, action execution or invented object identifiers.
export function doorActionRequest({targetId,action}){
 if(!Number.isInteger(action)||action<0||action>65535)throw new Error('Invalid native door action');
 return targetRequest(targetId,3,6,w=>w.writeWord(action));
}
export const talkToRequest=({targetId})=>targetRequest(targetId,8,4);
export const attackRequest=({targetId})=>targetRequest(targetId,2,4);
// Client7bfa80 -> server4531b0 subtype5. Lore/identification and all
// description/stat disclosure remain server-authoritative.
export const examineRequest=({targetId})=>targetRequest(targetId,5,4);
export function useObjectRequest({targetId,flag0=false,flag1=false}){
 if(![true,false,0,1].includes(flag0)||![true,false,0,1].includes(flag1))throw new Error('Invalid native object-use flags');
 return targetRequest(targetId,11,12,w=>{w.writeBool(Number(flag0));w.writeBool(Number(flag1));});
}
// Sender7bbc50 -> server448a00/ReplyDialog. Reply IDs are wire IDs, not a
// client-reconstructed DLG index. entryId echoes the current server reply set.
export function dialogReplyRequest({ownerId,replyId,abort=false,entryId}){
 if(!uint(ownerId)||!uint(replyId)||!uint(entryId)||![true,false,0,1].includes(abort))throw new Error('Invalid native dialog reply');
 const w=new NativeMessageWriter(1);w.create(9,0xffffffff,1);w.writeObjectIdClient(ownerId);w.writeDword(replyId);w.writeByte(Number(abort));w.writeDword(entryId);w.setPrefix(Uint8Array.of(112,20,3));return Uint8Array.from(w.getWriteMessage().data);
}

// Original inventory GUI senders7be110/7be060, server451db0. Opening a
// window requests replication; it does not create or move any client items.
export function inventoryWindowRequest({ownerId,open}){
 if(!uint(ownerId)||![true,false,0,1].includes(open))throw new Error('Invalid native inventory window request');
 const w=new NativeMessageWriter(1);w.create(8,0xffffffff,1);w.writeBool(Number(open));w.writeObjectIdClient(ownerId);w.setPrefix(Uint8Array.of(112,13,1));return Uint8Array.from(w.getWriteMessage().data);
}
export function inventoryPanelRequest({panel,self=true}){
 if(!Number.isInteger(panel)||panel<0||panel>255||![true,false,0,1].includes(self))throw new Error('Invalid native inventory panel request');
 const w=new NativeMessageWriter(1);w.create(5,0xffffffff,1);w.writeByte(panel);w.writeBool(Number(self));w.setPrefix(Uint8Array.of(112,13,2));return Uint8Array.from(w.getWriteMessage().data);
}

function itemActionRequest(itemId,minor,size,fields){
 if(!uint(itemId))throw new Error('Invalid native item action ID');
 const w=new NativeMessageWriter(1);w.create(size,0xffffffff,1);w.writeObjectIdClient(itemId);fields(w);w.setPrefix(Uint8Array.of(112,12,minor));return Uint8Array.from(w.getWriteMessage().data);
}
// Original client7c0d70 / server455f50. Server queues equip actions and
// owns all slot/ownership/feat/cursed-item/rules checks and resulting state.
export function equipItemRequest({itemId,destinationId=OBJECT_INVALID,slot}){
 if(!uint(destinationId)||!uint(slot))throw new Error('Invalid native equip request');
 return itemActionRequest(itemId,1,12,w=>{w.writeObjectIdClient(destinationId);w.writeDword(slot);});
}
export function dropItemRequest({itemId,position}){
 if(!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(Math.fround(v))))throw new Error('Invalid native item drop position');
 return itemActionRequest(itemId,3,16,w=>{for(const v of position)w.writeFloat(v,1,32);});
}
function repositoryRequest(value,minor){
 const {itemId,destinationId=OBJECT_INVALID,x=255,y=255}=value;
 if(!uint(destinationId)||![x,y].every(v=>Number.isInteger(v)&&v>=0&&v<=255))throw new Error('Invalid native repository request');
 return itemActionRequest(itemId,minor,10,w=>{w.writeObjectIdClient(destinationId);w.writeByte(x);w.writeByte(y);});
}
// Original pickup7c0f60, unequip7c1100, repository move7c1030.
export const pickupItemRequest=value=>repositoryRequest(value,5);
export const unequipItemRequest=value=>repositoryRequest(value,7);
export const moveItemRequest=value=>repositoryRequest(value,9);
// Client805500/7c0e20 -> server455f50 subtype11 owns the auto-equip slot
// scan and toggle. Optional second ID is the native paired-item input.
export function toggleItemEquipmentRequest({itemId,secondId=OBJECT_INVALID}){
 if(!uint(secondId))throw new Error('Invalid native equipment toggle');
 return itemActionRequest(itemId,11,4,w=>{w.writeBool(Number(secondId!==OBJECT_INVALID));if(secondId!==OBJECT_INVALID)w.writeObjectIdClient(secondId);});
}
