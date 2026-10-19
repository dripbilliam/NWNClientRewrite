import { OBJECT_INVALID } from './game_object_array.js';
import { setCreatureCombatState } from './combat_lifecycle.js';
import { subtractWorldTimes } from './reputation.js';

const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native combat frame ${name} is unavailable`);return value|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native combat frame provider ${name} is unavailable`);return p[name];};

// GetActiveTimer14055f0d0: canonical OBJECT_INVALID bypasses exclusion
// checks; bit2 takes precedence and only an EXACT exclusion result1 selects
// its timer. The world timer is distinct from either exclusion timer.
export function selectActiveTimer(id,p){
  id=integer(id,'active timer object ID')>>>0;
  if(id!==OBJECT_INVALID){
    const flags=integer(required(p,'pauseFlags')(),'active pause flags')&255;
    if((flags&3)!==0&&integer(required(p,'excluded')(id),'exclusion result')===1)
      return required(p,(flags&2)!==0?'timer2':'timer1')();
  }
  return required(p,'worldTimer')();
}

// Creature constructor14037aa18..14037aa2f captures WORLD time for+bc/c0,
// even when a later AI update selects a different active timer.
export function initializeCreatureFrame(actor,now){
  actor.nativeLastUpdateDayBc??=integer(now.day,'constructor day')>>>0;
  actor.nativeLastUpdateTimeC0??=integer(now.time,'constructor time')>>>0;
  actor.nativeQueueUpdateDay594??=0;actor.nativeQueueUpdateTime598??=0;
}

export function initializeSkillTimers(actor,rules){
  const table=rules.skills;if(!table)throw new Error('Native skill timer rules are unavailable');
  // LoadSkillInfo1402ac81b stores PHYSICAL Skills row count in BYTE+107.
  const count=integer(table.orderedRows?.length??table.rows.size,'skill row count')&255;
  if(actor.nativeSkillTimers878===undefined)actor.nativeSkillTimers878=new Uint32Array(count);
  if(!(actor.nativeSkillTimers878 instanceof Uint32Array)||actor.nativeSkillTimers878.length!==count)
    throw new Error('Native skill timer storage does not match active rules');
}

export function advanceSkillTimers(actor,delta,count){
  delta=integer(delta,'skill timer elapsed')>>>0;count=integer(count,'skill timer count')&255;
  if(count===0)return;
  const timers=actor.nativeSkillTimers878;
  if(!(timers instanceof Uint32Array)||timers.length<count)throw new Error('Native skill timer storage is unavailable');
  for(let index=0;index<count;index++){const timer=timers[index];if(timer!==0)timers[index]=delta<timer?(timer-delta)>>>0:0;}
}

// AIUpdate14037c4c6..14037cb4b ordinary owner order. Action execution gets
// the microsecond time captured BEFORE spawn/perception, not a fresh budget.
// Exact engine dependencies remain explicit providers; this coordinator does
// not substitute an implementation for trap/effect/queue/dirty-stat owners.
export async function updateCreatureFrame(actor,p){
  const startedAt=required(p,'microseconds')();
  await required(p,'beforeTimer')(actor);
  const now=required(p,'activeTimer')(actor.id>>>0).time();
  const elapsed=subtractWorldTimes(now,{day:integer(actor.nativeLastUpdateDayBc,'last update day')>>>0,
    time:integer(actor.nativeLastUpdateTimeC0,'last update time')>>>0},p.dayLength);
  // Native main AI initializes both subtraction outputs0, unlike module AI.
  actor.nativeFrameElapsedD4=elapsed.status===0?elapsed.milliseconds:0;
  if(actor.combatRound)await required(p,'roundTimer')(actor,actor.nativeFrameElapsedD4|0);
  await required(p,'excited')(actor,actor.nativeFrameElapsedD4);
  await required(p,'effects')(actor,now);
  await required(p,'actions')(actor,now,startedAt);
  actor.nativeLastUpdateDayBc=now.day;actor.nativeLastUpdateTimeC0=now.time;
  if(required(p,'area')(actor)!==null){
    const area=required(p,'area')(actor);await required(p,'height')(actor,area);
  }
  await required(p,'computeAIState')(actor);
  if(required(p,'area')(actor)!==null)await required(p,'traps')(actor);
  // Read+d4 again: scripts/action providers may mutate the native field.
  await required(p,'combatStateTimers')(actor,integer(actor.nativeFrameElapsedD4,'frame elapsed')|0);
  if(actor.isPC||integer(required(p,'possessed')(actor),'possessed result')!==0){
    const queueNow=required(p,'pauseTimer')().time(),queueElapsed=subtractWorldTimes(queueNow,
      {day:integer(actor.nativeQueueUpdateDay594,'queue update day')>>>0,time:integer(actor.nativeQueueUpdateTime598,'queue update time')>>>0},p.dayLength);
    // Native ignores failed subtraction and branches on unwritten caller
    // scratch. Report that unavailable GUI decision without inventing elapsed
    // time or changing its timestamp; the remaining gameplay frame still runs.
    if(queueElapsed.status!==0)await required(p,'queueClockUndefined')(actor,{now:queueNow,previous:{day:actor.nativeQueueUpdateDay594,time:actor.nativeQueueUpdateTime598},status:queueElapsed.status});
    else if(queueElapsed.milliseconds>=300){
      await required(p,'actionQueue')(actor);
      actor.nativeQueueUpdateDay594=queueNow.day;actor.nativeQueueUpdateTime598=queueNow.time;
    }
  }
  advanceSkillTimers(actor,actor.nativeFrameElapsedD4,required(p,'skillCount')());
  await required(p,'refreshStats')(actor);
  if(integer(actor.nativeField700,'combat state')===1){
    if((integer(actor.nativeAILevel7c,'AI level')>>>0)<=1)await required(p,'setAILevel')(actor,2);
  }else if(integer(actor.nativeAILevel7c,'AI level')===2&&required(p,'area')(actor)!==null){
    const area=required(p,'area')(actor);await required(p,'setAILevel')(actor,integer(area.nativePlayerCount150,'area player count')===0?0:1);
  }
}

// AIUpdate 14037c641..6d6, AFTER round timer and BEFORE UpdateEffectList.
export async function advanceExcitedDuration(actor,delta,p){
  delta=integer(delta,'elapsed milliseconds')>>>0;
  const duration=integer(actor.excitedDuration,'excited duration')>>>0;
  if(duration===0)return;
  if(delta<duration){actor.excitedDuration=(duration-delta)>>>0;return;}
  actor.excitedDuration=0;
  await required(p,'expired')(actor);
}

// AIUpdate 14037c76c..8c9, AFTER RunActions/height/AI summary/trap work.
// Expiry checks precede subtraction. Crossing zero takes effect NEXT frame.
// This helper is not a replacement for native perception or RunActions.
export async function advanceCombatStateTimers(actor,delta,p){
  delta=integer(delta,'elapsed milliseconds');
  if(integer(actor.nativeField700,'combat state')===1){
    const timer=integer(actor.nativeField704,'combat idle timer');
    if(timer<1)setCreatureCombatState(actor,0);
    else{
      actor.nativeField704=(timer-delta)|0;
      if(!actor.isPC&&!actor.isPossessedFamiliar){
        let heartbeat=integer(actor.nativeAttackField748,'combat heartbeat timer');
        if(heartbeat<1){
          if(integer(await required(p,'dead')(actor),'dead result')===0)await required(p,'heartbeat')(actor);
          heartbeat=6000;
        }
        actor.nativeAttackField748=(heartbeat-delta)|0;
      }
    }
  }
  let suppressed=integer(actor.nativeField750,'opportunity suppression flag');
  if(suppressed===1){
    const remaining=integer(actor.nativeField754,'opportunity suppression timer');
    if(remaining<1){actor.nativeField750=actor.nativeField754=0;suppressed=0;}
    else actor.nativeField754=(remaining-delta)|0;
  }
  if(![4,86,87].includes(integer(actor.animationState,'animation state')))return;
  const movement=integer(actor.nativeMovementField74c,'movement opportunity timer');
  if(movement<1){
    if(suppressed===0&&(integer(await required(p,'hasFeat')(actor,392),'feat result')===0||actor.nativeField700===0))
      await required(p,'opportunity')(actor,OBJECT_INVALID,1);
    actor.nativeMovementField74c=1500;
  }else actor.nativeMovementField74c=(movement-delta)|0;
}
