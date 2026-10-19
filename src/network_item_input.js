import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
const uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff,byte=v=>Number.isInteger(v)&&v>=0&&v<=255;

// Original7c0610 ->4531b0 subtype9. Item powers use their physical active
// property BYTE and optional variant, not ordinary class spell slots. Presence
// tests exact FLOAT zero; there is no spell sender epsilon or +.3 Z adjustment.
export function itemUseRequest({itemId,propertyIndex,variant=255,targetId=OBJECT_INVALID,position=[0,0,0]}){
 if(!uint(itemId)||!byte(propertyIndex)||!byte(variant)||!uint(targetId)||!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(Math.fround(v))))throw new Error('Invalid native item-use request');
 const point=position.map(Math.fround),hasVariant=variant!==255,hasTarget=targetId!==OBJECT_INVALID,hasPoint=point.some(v=>v!==0),w=new NativeMessageWriter(1);
 w.create(21,0xffffffff,1);w.writeObjectIdClient(itemId);w.writeByte(propertyIndex);w.writeBool(Number(hasVariant));if(hasVariant)w.writeByte(variant);w.writeBool(Number(hasTarget));if(hasTarget)w.writeObjectIdClient(targetId);w.writeBool(Number(hasPoint));if(hasPoint)for(const value of point)w.writeFloat(value,1,32);w.setPrefix(Uint8Array.of(112,6,9));return Uint8Array.from(w.getWriteMessage().data);
}
