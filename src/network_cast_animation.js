import {OBJECT_INVALID} from './game_object_array.js';
const f=Math.fround;
// Receiver7833ae..78345e changes the looping base before submitting type4.
export const networkCastReleaseBase=animation=>({17:250,18:251,19:252,20:253,61:261})[animation]??null;
export function networkCastAnimationRecord(cast){return{type:4,targetType:cast.targetType,targetId:cast.targetType===1?cast.target:OBJECT_INVALID,position:cast.targetType===2?[...cast.position]:[0,0,0],spellId:cast.spell>>>0,field38:cast.field220>>>0};}
// PlayAnimation7fc7d0 type4 uses500ms independent of clip length. The next
// server base can change while this client-only fire-and-forget cue finishes.
export function clientCastAnimationCue(animation,length,record){
 if(networkCastReleaseBase(animation)===null||record.type!==4||!Number.isFinite(length))throw new Error('Invalid native cast animation cue');
 return{animation,duration:500,speed:f(f(length)/f(500)),record,delay:0};
}
