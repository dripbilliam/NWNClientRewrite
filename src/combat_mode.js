const modeMask=[0,0x1000,0x400,0x800,0x2000,0x4000,0x8000,0x10000,0x20000,0x40000,0x80000,0x100000];
const combatBits=[0x400,0x800,0x1000,0x2000,0x40000,0x4000,0x8000,0x10000,0x20000,0x80000,0x100000];
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native ${n} is unavailable`);return v|0;};

// ClearActivities1403877e0: fixed order, ignores bits4/16 and other unlisted
// flags. Re-read activity/lock cells after each SetActivity side effect.
export async function clearCreatureActivities(actor,mask,setActivity){
  mask=integer(mask,'clear activity mask')>>>0;
  if(typeof setActivity!=='function')throw new Error('Native clear activity mutation owner is unavailable');
  for(const bit of [1,2,8,32,64,128,256,512,...combatBits])
    if((mask&bit)!==0&&(integer(actor.activities,'activity mask')&bit)!==0&&(integer(actor.lockedActivities,'locked activity mask')&bit)===0)await setActivity(actor,bit,0);
}

// GetMode140391e70..140391fd8; the script wrapper narrows the requested
// mode to BYTE. Detect's Keen Senses/idle rules are supplied by GetDetectMode.
export async function getActionMode(actor,requested,detect){
  requested=integer(requested,'requested action mode')&255;
  if(requested===0){if(typeof detect!=='function')throw new Error('Native detect mode provider is unavailable');return Number((integer(await detect(actor),'detect mode')&255)===1);}
  if(requested===1)return Number((integer(actor.nativeField6ed,'stealth byte')&255)===1);
  if(requested<=12)return Number((integer(actor.combatMode,'combat mode')&255)===requested-1);
  return 0;
}

// SetActivity 1403a275d..1403a2abe, combat-mask branch only. Enabling a
// combat bit clears unlocked combat bits first, including the same bit.
// Defensive stance effects are explicit callbacks; locked bits veto a change.
export async function setCombatActivity(actor,mask,value,p){
  mask=integer(mask,'combat activity mask')>>>0;value=integer(value,'activity value');
  if(mask===0||(mask&~0x1ffc00)!==0)throw new Error('Native noncombat activity mutation is unavailable');
  if((integer(actor.lockedActivities,'locked activity mask')&mask)===mask)return;
  if(value===1||mask===0x1ffc00&&value===0){
    for(const bit of combatBits){
      if((integer(actor.activities,'activity mask')&bit)!==0&&(actor.lockedActivities&bit)===0)
        await setCombatActivity(actor,bit,0,p);
    }
  }
  const old=integer(actor.activities,'activity mask')>>>0;
  const changed=value===1?(old&mask)===0:(old&mask)!==0;
  await p.preflight?.(actor,mask,value,changed);
  actor.activities=value===1?(old|mask)>>>0:(old&~mask)>>>0;
  if(!changed)return;
  if(mask&0x40000)await p.defensiveCasting(actor,value!==0);
  if(mask&0x100000){
    if(value!==0)await p.applyStance(actor);
    else{const effect=actor.effects?.find(e=>e.type===95);if(effect)await p.removeStance(actor,effect.id);}
  }
}

// SetCombatMode 1403d8c50..1403d915f. Queue a pending byte only when
// force==0 and started==1; validation rejection leaves the old mode intact.
// Force values other than zero/one retain the native conditional behavior.
export async function setCombatMode(actor,requested,force,p){
  requested=integer(requested,'requested combat mode')&255;force=integer(force,'combat mode force');
  const mode=integer(actor.combatMode,'combat mode')&255;
  if(force===1||requested!==mode){
    if(force===0&&Number(actor.combatRound?.started)===1){actor.pendingCombatMode=requested;return;}
    const right=await p.item(actor,16);
    if([1,2,3,7,8,10,11].includes(requested)&&right&&await p.ranged(right)!==0){await p.feedback(actor,188);return;}
    if(requested===5&&right){
      if(await p.classIndex(actor,5)===255&&await p.classIndex(actor,40)===255){await p.feedback(actor,188);return;}
      const left=await p.item(actor,32);
      let allowed=await p.monkWeapon(right)!==0&&(!left||await p.monkWeapon(left)!==0);
      if(!allowed)allowed=await p.relativeSize(actor,right)<0&&await p.hasFeat(actor,866)!==0;
      if(!allowed)allowed=await p.hasFeat(actor,899)!==0;
      if(!allowed){await p.feedback(actor,188);return;}
    }
    if(requested===6&&(!right||await p.ranged(right)===0||((right.data.BaseItem-6)>>>0)<2)){
      await p.feedback(actor,188);return;
    }
  }
  await p.preflight?.(actor,requested,force);
  if(modeMask[mode])await p.activity(actor,modeMask[mode],0);
  else if(mode!==0)await p.warning('Native warning: Attempted to unset an unknown combat mode');
  actor.combatMode=0;
  if(requested===11){
    if((integer(await p.remainingUses(actor,947),'defensive stance uses')&255)===0){await p.feedback(actor,199);return;}
    await p.activity(actor,modeMask[requested],1);await p.decrementUses(actor,947);
  }else if(modeMask[requested])await p.activity(actor,modeMask[requested],1);
  else if(requested!==0)await p.warning('Native warning: Attempted to set an unknown combat mode');
  actor.combatMode=requested;
}
