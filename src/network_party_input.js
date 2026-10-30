import {NativeMessageWriter} from './native_message.js';
// Original7c3390 -> HandlePlayerToServerParty45b4a0. Full OBJECT_ID,
// never PLAYER_ID; membership and outcomes remain server-owned.
export const PARTY_INPUT_MINORS=Object.freeze({list:2,leave:6,kick:7,transfer:8,invite:9,ignore:10,accept:11,reject:12});
export function partyRequest({operation,targetId}){
 if(!Object.hasOwn(PARTY_INPUT_MINORS,operation))throw Error('Invalid native party operation');const minor=PARTY_INPUT_MINORS[operation];
 if(operation==='list'){if(targetId!==undefined)throw Error('A party-list refresh has no target');return Uint8Array.of(112,14,2);}
 if(!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff)throw Error('Invalid native party target');
 const w=new NativeMessageWriter(1);w.create(4,0xffffffff,1);w.writeObjectIdClient(targetId);w.setPrefix(Uint8Array.of(112,14,minor));return Uint8Array.from(w.getWriteMessage().data);
}
// Original player selection888ce0 and Tell889140 -> GUI7bdf30.
export function playerListGuiRequest({operation,targetId,includePosition}){
 const event=operation==='select'?12:operation==='tell'?28:null;
 if(event===null||!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff||typeof includePosition!=='boolean')throw Error('Invalid native player-list GUI request');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(event);w.writeWord(0);w.writeObjectIdClient(targetId);if(includePosition)for(const n of [0,0,0])w.writeFloat(n,1,32);w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
