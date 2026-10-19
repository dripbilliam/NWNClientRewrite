// Probe utility: advance the local host and snapshot its real clocks. This is
// not an engine timing adapter; game effects own native day/time deadlines.
import {subtractWorldTimes} from '../src/world_timer.js';
export function advanceLocalClocks(session,milliseconds){
 if(!Number.isSafeInteger(milliseconds)||milliseconds<0)throw new Error('Probe clock advance requires nonnegative integer milliseconds');
 session.scheduler.advance(milliseconds);for(const timer of [session.worldTimer,session.nativeServerPause.timer1,session.nativeServerPause.timer2])timer.snapshot();
}
export function advanceToEffectExpiry(session,effect){
 if(session.nativeServerPause.flags!==0)throw new Error('Unpaused probe deadline advance cannot cross an active server pause');
 const delta=subtractWorldTimes({day:effect.expiryDay,time:effect.expiryTime},session.worldTimer.time(),session.worldTimer.dayLength);
 if(delta.status!==0)throw new Error('Probe effect deadline is backwards or invalid');
 advanceLocalClocks(session,delta.day*session.worldTimer.dayLength+delta.time);
}
