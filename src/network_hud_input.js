import {NativeMessageWriter} from './native_message.js';
// Original7bffb0 calls7c25c0(6,13,null,0). Rest admission, animation,
// cancellation, healing and resource recovery belong to the server.
export const restRequest=()=>Uint8Array.of(112,6,13);
const uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff;

// Character-sheet sender7bddd0; closing6f7e10 sends signed page-1.
export function characterSheetRequest({targetId,page}){
 if(!uint(targetId)||!Number.isInteger(page)||page< -128||page>127)throw new Error('Invalid native character-sheet request');
 // Full-width CHAR has the same raw byte as BYTE in format1 (no type tag).
 const w=new NativeMessageWriter(1);w.create(5,0xffffffff,1);w.writeByte(page&255);w.writeObjectIdClient(targetId);w.setPrefix(Uint8Array.of(112,21,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Server456d30 subscription branches10/11 have no fields.
export const journalWindowRequest=open=>{if(typeof open!=='boolean')throw new Error('Invalid native journal window request');return Uint8Array.of(112,28,open?10:11);};
// Original7c31b0 resolves PLAYER_ID -> player character (+34), distinct
// from the controlled object (+38), before writing OBJECT_ID and BOOL.
export function playerAttitudeRequest({targetId,likes}){
 if(!uint(targetId)||typeof likes!=='boolean')throw new Error('Invalid native player attitude request');
 const w=new NativeMessageWriter(1);w.create(8,0xffffffff,1);w.writeObjectIdClient(targetId);w.writeBool(Number(likes));w.setPrefix(Uint8Array.of(112,41,3));return Uint8Array.from(w.getWriteMessage().data);
}
