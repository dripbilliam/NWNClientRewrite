import {secondsToWorldDelta,addWorldTimes} from './world_timer.js';
import {setEffectExpiry} from './effect_clock.js';
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native Time Stop provider ${n} is unavailable`);return p[n](...a);};
const type=e=>e.type&65535;
// OnApplyTimestop140434810: re-query pause state on the nonzero path. Recasts
// scan the whole live list, including past higher types, and update ONLY the
// first64 deadline. Loading/dead/creature/duration-kind are not admission gates.
export async function applyTimeStop(object,effect,p,_loading=0){
 if((call(p,'pauseState')&255)===0){call(p,'addExclusion',object.id,1);await call(p,'togglePause',1);return 0;}
 if((call(p,'pauseState')&255)===1){
  const day=secondsToWorldDelta(effect.duration,call(p,'worldTimer').secondsPerDay).day;
  const time=secondsToWorldDelta(effect.duration,call(p,'worldTimer').secondsPerDay).time;
  const now=call(p,'activeTimer',object.id).time(),expiry=addWorldTimes(now,{day,time},call(p,'worldTimer').dayLength);
  for(const existing of call(p,'effects',object))if(type(existing)===64){
   // Original ignores Add's failure then passes unwritten stack outputs to
   // SetExpiryTime. Diagnose that undefined branch rather than invent a date.
   if(expiry.status!==0)throw new Error('Native Time Stop recast expiry is unwritten after invalid world-time addition');
   setEffectExpiry(existing,expiry);return 1;
  }
 }
 return 0;
}
// OnRemoveTimestop140439240 toggles unconditionally, before the sorted scan.
// Any98 retains the exclusion. It does not preserve exclusion for another64.
export async function removeTimeStop(object,_effect,p){
 await call(p,'togglePause',1);
 for(const existing of call(p,'effects',object)){if(type(existing)>98)break;if(type(existing)===98)return 1;}
 call(p,'removeExclusion',object.id,1);return 1;
}
// OnApplyTimeStopImmunity1404347e0, including loading/non-creature targets.
export function applyTimeStopImmunity(object,_effect,p,_loading=0){call(p,'addExclusion',object.id,1);return 0;}
// OnRemoveTimeStopImmunity1404391b0 excludes the removed POINTER, scans only
// through type98, then preserves DM exclusions for any nonzero native DM INT.
export function removeTimeStopImmunity(object,effect,p){
 for(const existing of call(p,'effects',object)){if(type(existing)>98)break;if(existing!==effect&&type(existing)===98)return 1;}
 const actor=call(p,'asCreature',object);if(actor&&call(p,'isDM',actor)!==0)return 1;
 call(p,'removeExclusion',object.id,1);return 1;
}
