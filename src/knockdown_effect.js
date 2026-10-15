import {OBJECT_INVALID} from './game_object_array.js';
import {normalizeOrientation} from './combat_lifecycle.js';

const f=Math.fround;
// OnApplySetAIState140431690 / OnRemoveSetAIState140438370 operate
// on the same native WORD+8d4 used by death, movement and perception.
export function applyAIStateEffect(actor,effect,p){
  if(actor.objectType!==5)return;
  actor.nativeField8d4=(actor.nativeField8d4&effect.integers[0])&65535;
  p.refreshDex(actor);actor.combatInformationDirty=1;
}
export function removeAIStateEffect(actor,effect,p){
  if(actor.objectType!==5)return;
  if((actor.nativeField8d4&65535)!==0){
    let mask=65535;
    // Native +d9c is the first type23 index in the sorted active array.
    const active=actor.effects??[],start=active.findIndex(e=>e.type>=23);
    if(start>=0)for(let i=start;i<active.length&&active[i].type===23;i++)if(active[i]!==effect)mask&=active[i].integers[0];
    actor.nativeField8d4=mask&65535;
  }
  p.refreshDex(actor);actor.combatInformationDirty=1;
}
// OnApplyKnockdown14042e980. Script ApplyEffect passes applyFlag0;
// flag1's dead gate has duration3/4 exceptions. Instant becomes TEMP3s
// even on a noncreature, before immunity/plot/dying checks.
export async function applyKnockdown(actor,effect,p,applyFlag=0){
  if(applyFlag!==0&&p.dead(actor)!==0&&![3,4].includes(effect.durationType))return 1;
  if(effect.durationType===0){effect.durationType=1;effect.duration=f(3);}
  if(actor.objectType!==5)return 0;
  const creator=p.object(effect.creatorId),source=creator?.objectType===5?creator:null;
  if(effect.bypassImmunity===0&&p.immunity(actor,28,source)!==0){
    const data={type:0,objects:[actor.id]};
    if(source)await p.feedback(source,129,structuredClone(data));
    await p.feedback(actor,129,data);return 1;
  }
  if(actor.plot)return 1;
  if(p.dying(actor)!==0)return 0;
  const round=actor.combatRound;
  if(!round)throw new Error('Native knockdown combat round is unavailable');
  round.paused=1;round.pausedBy=effect.creatorId;round.infinitePause=1;round.pauseTimer=0;
  // Native copy ctor deliberately keeps the SAME uint64 ID, exposed=0.
  // The linked record lasts1.5s longer, but RemoveEffectById removes all
  // records sharing an ID when either one expires or is explicitly removed.
  const linked={...structuredClone(effect),type:23,integers:[-257],exposed:false,duration:f(effect.duration+f(1.5))};
  await p.applyLinked(actor,linked);
  await p.clearActions(actor);actor.nativeFieldEc=0;
  let forward=!creator;
  if(source){
    const direction=normalizeOrientation(source.position.map((n,i)=>f(f(n)-f(actor.position[i])))),orientation=normalizeOrientation(actor.orientation);
    const dot=f(f(f(direction[2]*orientation[2])+f(direction[0]*orientation[0]))+f(direction[1]*orientation[1]));
    forward=dot>=.707;
  }
  actor.nativeBodyState=forward?5:6;p.setAnimation(actor,forward?7:5);
  return 0;
}
// RecomputeAmbientAnimationState14039db40 and OnRemoveKnockdown140437770.
export function removeKnockdown(actor,_effect,p){
  if(actor.objectType!==5)return;
  const round=actor.combatRound;if(!round)throw new Error('Native knockdown combat round is unavailable');
  if(Number(round.paused)!==0){
    round.paused=0;round.pausedBy=OBJECT_INVALID;if(Number(round.infinitePause)!==0)round.infinitePause=0;
    // SetPauseTimer(0,0) adds0 to a positive timer, otherwise writes0.
    if((round.pauseTimer|0)<=0)round.pauseTimer=0;
  }
  if(p.dead(actor)!==0||p.dying(actor)!==0)return;
  const state=actor.nativeField771&255;
  if(actor.chairId!==OBJECT_INVALID)actor.nativeBodyState=1;
  else if(state!==9)actor.nativeBodyState=state===5||state===6?2:0;
  else actor.nativeBodyState=4;
  p.setAnimation(actor,0);actor.nativeFieldEc=1;
}
