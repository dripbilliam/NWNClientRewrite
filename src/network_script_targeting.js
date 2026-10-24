import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
// Client receiver770c80 branch77a378 reads three DWORDs. EnterTargetingMode
// 98d5f0 maps script object-mask bits to client object kinds, including ground2.
export function readScriptTargeting(r){return{kind:'script-targeting',objectMask:r.readDword(),cursor:r.readDword(),badCursor:r.readDword()};}
export function readSpellTargetingData(r){return{kind:'spell-targeting-data',spellId:r.readInt(),shape:r.readInt(),sizeX:r.readFloat(1,32),sizeY:r.readFloat(1,32),flags:r.readInt()};}
export function readScriptTargetingData(r){return{kind:'script-targeting-data',shape:r.readInt(),sizeX:r.readFloat(1,32),sizeY:r.readFloat(1,32),flags:r.readInt(),range:r.readFloat(1,32),spellId:r.readInt(),featId:r.readInt()};}
export const scriptTargetKinds=mask=>[5,6,7,10,11,12,9,14,13,2].filter((_,bit)=>(mask>>>bit)&1);
export function scriptTargetAllowed(mode,target){return scriptTargetKinds(mode.objectMask).includes(target?.objectType??2);}
// Original client7c0110 sends6/37: raw client OBJECT_ID plus three FLOATs.
// This reports a script selection; it is not a client-authored spell cast.
export function scriptTargetSelectionRequest({targetId=OBJECT_INVALID,position}){
 if(!Number.isInteger(targetId)||targetId<0||targetId>0xffffffff||!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(Math.fround(v))))throw Error('Invalid native script target selection');
 const w=new NativeMessageWriter(1);w.create(16,0xffffffff,1);w.writeObjectIdClient(targetId);for(const v of position)w.writeFloat(Math.fround(v),1,32);w.setPrefix(Uint8Array.of(112,6,37));return Uint8Array.from(w.getWriteMessage().data);
}
