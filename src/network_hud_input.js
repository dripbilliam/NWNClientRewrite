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
// Original character-sheet9bf640 ->6f9bd0 ->7bdf30: GUI event3,
// selected skill WORD, displayed character OBJECT_ID and versioned zero XYZ.
// This is inspection only, not a skill-use action or a local stat calculation.
export function skillDescriptionGuiRequest({skillId,targetId,includePosition}){
 if(!Number.isInteger(skillId)||skillId<0||skillId>65535||!uint(targetId)||typeof includePosition!=='boolean')throw Error('Invalid native skill-description GUI request');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(3);w.writeWord(skillId);w.writeObjectIdClient(targetId);if(includePosition)for(const n of [0,0,0])w.writeFloat(n,1,32);w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Original CCharPageFeats9c04b0 -> GetDescriptionText2a1200 -> GUI7bdf30:
// event4, selected feat WORD, displayed character OBJECT_ID, versioned zeroXYZ.
// This inspects server help; it never activates a feat or computes its effect.
export function featDescriptionGuiRequest({featId,targetId,includePosition}){
 if(!Number.isInteger(featId)||featId<0||featId>65535||!uint(targetId)||typeof includePosition!=='boolean')throw Error('Invalid native feat-description GUI request');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(4);w.writeWord(featId);w.writeObjectIdClient(targetId);if(includePosition)for(const n of [0,0,0])w.writeFloat(n,1,32);w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
// CPanelPlayerStateBar895770 -> GUI7bdf30 -> module GUI event451b30.
// The original effect button sends event5, effect WORD, invalid object, zero XYZ.
export function effectIconGuiRequest({effectId,includePosition}){
 if(!Number.isInteger(effectId)||effectId<0||effectId>65535||typeof includePosition!=='boolean')throw Error('Invalid native effect-icon GUI request');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(5);w.writeWord(effectId);w.writeObjectIdClient(0x7f000000);if(includePosition)for(const n of [0,0,0])w.writeFloat(n,1,32);w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Original87b450/87b4b0: GUI event1/2, original five-mode list index.
export function chatFocusGuiRequest({mode,focused,includePosition}){
 if(!Number.isInteger(mode)||mode<0||mode>=5||typeof focused!=='boolean'||typeof includePosition!=='boolean')throw Error('Invalid native chat-focus GUI request');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(focused?1:2);w.writeWord(mode);w.writeObjectIdClient(0x7f000000);if(includePosition)for(const n of [0,0,0])w.writeFloat(n,1,32);w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Original CReplyButton879ba0: event27, zero WORD, current player character.
export function chatReplyGuiRequest({targetId,includePosition}){
 if(!uint(targetId)||typeof includePosition!=='boolean')throw Error('Invalid native chat-reply GUI request');
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeWord(27);w.writeWord(0);w.writeObjectIdClient(targetId);if(includePosition)for(const n of [0,0,0])w.writeFloat(n,1,32);w.setPrefix(Uint8Array.of(112,53,1));return Uint8Array.from(w.getWriteMessage().data);
}
// Original7c31b0 resolves PLAYER_ID -> player character (+34), distinct
// from the controlled object (+38), before writing OBJECT_ID and BOOL.
export function playerAttitudeRequest({targetId,likes}){
 if(!uint(targetId)||typeof likes!=='boolean')throw new Error('Invalid native player attitude request');
 const w=new NativeMessageWriter(1);w.create(8,0xffffffff,1);w.writeObjectIdClient(targetId);w.writeBool(Number(likes));w.setPrefix(Uint8Array.of(112,41,3));return Uint8Array.from(w.getWriteMessage().data);
}
