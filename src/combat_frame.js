import { OBJECT_INVALID } from './game_object_array.js';
import { setCreatureCombatState } from './combat_lifecycle.js';

const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native combat frame ${name} is unavailable`);return value|0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native combat frame provider ${name} is unavailable`);return p[name];};

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
