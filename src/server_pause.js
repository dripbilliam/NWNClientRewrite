import {selectActiveTimer} from './combat_frame.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native pause ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native pause provider ${n} is unavailable`);return p[n](...a);};
const flags=s=>integer(s.flags,'flags')&255;
const list=(s,bit)=>{const v=s[bit===2?'list100f8':'list10100'];if(!Array.isArray(v))throw new Error('Native pause exclusion list dereferences unavailable storage');return v;};

// AddToExclusionList14055d010 prefers bit2. Remove140569c70 prefers bit1.
// Preserve that asymmetry for combined masks; duplicate IDs are not added.
export function addPauseExclusion(state,id,mask){
  mask=integer(mask,'mask')&255;id=integer(id,'object ID')>>>0;
  if((mask&3)===0)return;const ids=list(state,(mask&2)!==0?2:1);if(!ids.includes(id))ids.push(id);
}
export function removePauseExclusion(state,id,mask){
  mask=integer(mask,'mask')&255;id=integer(id,'object ID')>>>0;
  if((mask&3)===0)return;const ids=list(state,(mask&1)!==0?1:2),index=ids.indexOf(id);if(index>=0)ids.splice(index,1);
}
// GetActivePauseState14055f0b0 and IsOnActiveExclusionList140564530. A null
// ACTIVE list means admitted; the ordinary equip exclusion query is separate.
export function activePauseState(state){const f=flags(state);return(f&2)!==0?2:(f&1)!==0?1:0;}
export function activePauseExclusion(state,id){
  const bit=activePauseState(state);if(bit===0)return 1;
  const ids=state[bit===2?'list100f8':'list10100'];if(ids===null)return 1;
  if(!Array.isArray(ids))throw new Error('Native active pause exclusion storage is unavailable');
  return Number(ids.includes(integer(id,'object ID')>>>0));
}
export function activeObjectTimer(state,worldTimer,id){return selectActiveTimer(id,{pauseFlags:()=>flags(state),excluded:id=>activePauseExclusion(state,id),worldTimer:()=>worldTimer,timer1:()=>state.timer1,timer2:()=>state.timer2});}

// CNWSCreature::ResetUpdateTimes14039f0d0. Only these three pairs change.
export function resetCreatureUpdateTimes(actor,day,time){
  day=integer(day,'reset day')>>>0;time=integer(time,'reset time')>>>0;
  actor.nativeHeartbeatDay54c=actor.nativePerceptionDay578=actor.nativeLastUpdateDayBc=day;
  actor.nativeHeartbeatTime550=actor.nativePerceptionTime57c=actor.nativeLastUpdateTimeC0=time;
}
// ReprocessExclusionListActions14056a270. Uses the flags AFTER the caller
// clears its bit. Re-read live count/IDs; invalid IDs still query world time.
export async function reprocessPauseActions(state,mask,p){
  const ids=list(state,(integer(mask,'reprocess mask')&255)===2?2:1);
  for(let index=0;index<ids.length;index++){
    const id=integer(ids[index],'excluded object ID')>>>0,now=call(p,'activeTimer',id).time(),object=call(p,'object',id);
    if(object)await call(p,'resetObjectTimes',object,now.day,now.time);
  }
}

// Complete SetPauseState14056bd40. Lower timer operations, reprocessing and
// notification are explicit providers. A raw non1 value takes the OFF path,
// unless it equals the current BOOL exactly at the initial comparison.
export async function setServerPauseState(state,mask,value,p){
  mask=integer(mask,'mask')&255;value=integer(value,'enabled value');
  if(Number((flags(state)&mask)!==0)===value)return;
  const world=call(p,'worldTimer'),one=state.timer1,two=state.timer2;
  if(value===1){
    state.flags=flags(state)|mask;call(p,'pause',world);if((flags(state)&2)!==0)call(p,'pause',one);await call(p,'send',mask,1);return;
  }
  state.flags=flags(state)&(~mask&255);
  if(mask===2){
    call(p,'pause',two);await call(p,'reprocess',2);call(p,'reset',two,one);call(p,'snapshot',two);call(p,'snapshot',one);call(p,'syncPrevious',two);call(p,'syncPrevious',one);
    if((flags(state)&2)!==0||(flags(state)&1)===0){call(p,'snapshot',world);call(p,'syncPrevious',world);call(p,'unpause',world);}
    call(p,'unpause',one);call(p,'unpause',two);
  }else if(mask===1){
    call(p,'pause',one);call(p,'pause',two);await call(p,'reprocess',1);call(p,'reset',one,world);call(p,'reset',two,world);
    call(p,'snapshot',world);call(p,'snapshot',one);call(p,'snapshot',two);call(p,'syncPrevious',two);call(p,'syncPrevious',one);call(p,'syncPrevious',world);
    call(p,'unpause',world);call(p,'unpause',one);call(p,'unpause',two);
  }
  await call(p,'send',mask,value);
}
export function toggleServerPauseState(state,mask,p){return setServerPauseState(state,mask,Number((flags(state)&(integer(mask,'mask')&255))===0),p);}
