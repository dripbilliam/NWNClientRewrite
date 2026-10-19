import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {featInfo} from './feat_uses.js';
const uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff,word=v=>Number.isInteger(v)&&v>=0&&v<=65535;

// Ordinary sender7c04e0 ->4531b0 subtype6. An object target omits the point;
// a location always carries XYZ, including zero, without the spell Z offset.
export function featUseRequest({featId,auxiliary=0,targetId=OBJECT_INVALID,position=null}){
 if(!word(featId)||!word(auxiliary)||!uint(targetId)||targetId===OBJECT_INVALID&&(!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(Math.fround(v)))))throw new Error('Invalid native feat request');
 const w=new NativeMessageWriter(1);w.create(4,0xffffffff,1);w.writeWord(featId);w.writeWord(auxiliary);w.writeObjectIdClient(targetId);if(targetId===OBJECT_INVALID)for(const v of position)w.writeFloat(Math.fround(v),1,32);w.setPrefix(Uint8Array.of(112,6,6));return Uint8Array.from(w.getWriteMessage().data);
}
// Mode sender7c02e0 ->6/10. Only mode5 carries a target ID.
export function modeChangeRequest({modeId,targetId=OBJECT_INVALID}){
 if(!Number.isInteger(modeId)||modeId<0||modeId>255||modeId===5&&!uint(targetId))throw new Error('Invalid native mode request');
 const w=new NativeMessageWriter(1);w.create(4,0xffffffff,1);w.writeByte(modeId);if(modeId===5)w.writeObjectIdClient(targetId);w.setPrefix(Uint8Array.of(112,6,10));return Uint8Array.from(w.getWriteMessage().data);
}
// Native7bff40 sends an empty6/19. The server chooses/validates the familiar.
export const possessFamiliarRequest=()=>Uint8Array.of(112,6,19);
// Replicated remaining uses only. Unlimited/native no-counter feats display
//100; finite missing counters stay unavailable. This never spends/grants uses.
export function networkFeatUses(actor,rules,id){
 id&=65535;if(![...(actor?.playerState?.feats??[]),...(actor?.playerState?.bonusFeats??[])].includes(id))return 0;
 return actor.playerState.featUses?.[id]??(featInfo(rules,id)?.uses===0?100:0);
}
