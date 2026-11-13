import {NativeMessageWriter} from './native_message.js';
// Original client7bfe30: WORD animation, raw client OBJECT_ID, position XYZ
// and duration, sent6/4. Selection, model timings and presentation stay native.
export function emoteAnimationRequest({actorId,animation,position,duration}){
 if(!Number.isInteger(actorId)||actorId<0||actorId>0xffffffff||!Number.isInteger(animation)||animation<0||animation>65535||!Array.isArray(position)||position.length!==3||!position.every(v=>Number.isFinite(v)&&Number.isFinite(Math.fround(v)))||!Number.isFinite(duration)||!Number.isFinite(Math.fround(duration))||duration<0)throw Error('Invalid native emote animation request');
 const w=new NativeMessageWriter(1);w.create(18,0xffffffff,1);w.writeWord(animation);w.writeObjectIdClient(actorId);for(const v of position)w.writeFloat(v,1,32);w.writeFloat(duration,1,32);w.setPrefix(Uint8Array.of(112,6,4));return Uint8Array.from(w.getWriteMessage().data);
}
