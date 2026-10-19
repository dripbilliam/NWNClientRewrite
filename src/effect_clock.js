import {secondsToWorldDelta,addWorldTimes,compareWorldTimes} from './world_timer.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native effect clock ${n} is unavailable`);return v>>>0;};
export function setEffectExpiry(effect,expiry){effect.expiryDay=integer(expiry.day,'expiry day');effect.expiryTime=integer(expiry.time,'expiry time');}
// ApplyEffect14048e68b..14048e739: after OnEffectApplied returns0, use WORLD
// time captured BEFORE that callback. Loading preserves the stored deadline.
export function initializeEffectExpiry(effect,loading,capturedWorldTime,timer){
  if((integer(effect.durationType,'duration type')&7)!==1||loading!==0)return;
  const delta=secondsToWorldDelta(effect.duration,timer.secondsPerDay),expiry=addWorldTimes(capturedWorldTime,delta,timer.dayLength);
  if(expiry.status!==0)throw new Error('Native effect expiry is unwritten after invalid world-time addition');
  setEffectExpiry(effect,expiry);
}
// Common UpdateEffectList14049e04a..14049e0b8: native compares against caller's
// captured time and expires only on EXACT CompareWorldTimes result1.
export function effectHasExpired(effect,now,timer){return effect!==null&&(effect.durationType&7)===1&&compareWorldTimes(now,{day:integer(effect.expiryDay,'expiry day'),time:integer(effect.expiryTime,'expiry time')},timer.dayLength)===1;}
