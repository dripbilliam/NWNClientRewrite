import {NativeMessageWriter} from './native_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
const f=Math.fround,uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff,byte=v=>Number.isInteger(v)&&v>=0&&v<=255;
const present=point=>{const[x,y,z]=point,s=f(f(f(x*x)+f(y*y))+f(z*z));return(s>0?f(Math.sqrt(s)):0)>=f(1e-5);};

// Original7c3870 /7c3960: preparation and clearing are requests, never local
// changes to replicated slots. The server alone decides whether to accept.
export function spellPreparationRequest({classIndex,spellId,slot,domainLevel=0,metamagic=0}){
 if(!uint(spellId)||![classIndex,slot,domainLevel,metamagic].every(byte))throw new Error('Invalid native spell preparation request');
 const w=new NativeMessageWriter(1);w.create(8,0xffffffff,1);w.writeByte(classIndex);w.writeDword(spellId);w.writeByte(slot);w.writeByte(domainLevel);w.writeByte(metamagic);w.setPrefix(Uint8Array.of(112,6,16));return Uint8Array.from(w.getWriteMessage().data);
}
export function spellPreparationClearRequest({classIndex,level,slot}){
 if(![classIndex,level,slot].every(byte))throw new Error('Invalid native spell preparation clear request');
 const w=new NativeMessageWriter(1);w.create(3,0xffffffff,1);w.writeByte(classIndex);w.writeByte(level);w.writeByte(slot);w.setPrefix(Uint8Array.of(112,6,17));return Uint8Array.from(w.getWriteMessage().data);
}

// Original7bf4e0 ->4531b0 subtype18. TargetType is the original spell's
// active-table WORD50, not a mask invented from the selected target. Both an
// object and a nonzero point may be present. NativeFLOAT magnitude decides
// presence before the original+0.3 Z adjustment. No gameplay resolves here.
export function spellCastRequest({spellId,classIndex=0,domainLevel=0,metamagic=0,spontaneous=false,targetId=OBJECT_INVALID,position=[0,0,0],targetType}){
 if(!uint(spellId)||!uint(targetId)||![classIndex,domainLevel,metamagic].every(byte)||![false,true,0,1].includes(spontaneous)||!Number.isInteger(targetType)||targetType<0||targetType>65535||!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(f(v))))throw new Error('Invalid native spell cast request');
 const point=position.map(f),[x,y,z]=point,hasPoint=present(point),hasTarget=targetId!==OBJECT_INVALID;
 const w=new NativeMessageWriter(1);w.create(4,0xffffffff,1);w.writeDword(spellId);w.writeByte(classIndex);w.writeByte(domainLevel);w.writeByte(metamagic);w.writeByte(Number(hasTarget)|Number(hasPoint)<<1|Number(Boolean(spontaneous))<<2);
 if(hasTarget)w.writeObjectIdClient(targetId);if(hasPoint)for(const v of [x,y,f(z+f(.3))])w.writeFloat(v,1,32);w.writeWord(targetType);w.setPrefix(Uint8Array.of(112,6,18));return Uint8Array.from(w.getWriteMessage().data);
}
// Ordinary innate sender7bf6e0 ->4531b0 subtype35. It has a caster-level BYTE,
// no class/domain/meta/TargetType fields, and the same target/point convention.
export function spellLikeCastRequest({spellId,casterLevel,targetId=OBJECT_INVALID,position=[0,0,0]}){
 if(!uint(spellId)||!byte(casterLevel)||!uint(targetId)||!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(f(v))))throw new Error('Invalid native innate cast request');
 const point=position.map(f),hasPoint=present(point),hasTarget=targetId!==OBJECT_INVALID,w=new NativeMessageWriter(1);w.create(4,0xffffffff,1);w.writeDword(spellId);w.writeByte(casterLevel);w.writeByte(Number(hasTarget)|Number(hasPoint)<<1);if(hasTarget)w.writeObjectIdClient(targetId);if(hasPoint)for(const v of [point[0],point[1],f(point[2]+f(.3))])w.writeFloat(v,1,32);w.setPrefix(Uint8Array.of(112,6,35));return Uint8Array.from(w.getWriteMessage().data);
}
