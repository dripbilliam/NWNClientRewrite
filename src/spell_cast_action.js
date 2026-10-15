import {OBJECT_INVALID} from './game_object_array.js';
import {actionParameter,setActionParameter} from './object_actions.js';
import {rulesetInt,rulesetFloat} from './combat_stats.js';
const f=Math.fround;
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native cast action ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native cast action provider ${n} is unavailable`);return p[n];};
const call=(p,n,...args)=>required(p,n)(...args);

// AIActionCastSpell1403ada70 ordinary path. Lower ownership gates must be
// established by preflight before dispatch: no special feat/counterspellers,
// spontaneous conversion or defensive/concentration lower providers.
// This coordinator does not invent a spell effect or animation clip name.
export async function executeOrdinaryCast(actor,node,rules,p){
  await call(p,'preflight',actor,node);
  actor.nativeAttackField748=6000;
  const cleanup=async(status)=>{await call(p,'removeRoundSpell',actor);await call(p,'pendingEquipment',actor);return status;};
  if(await call(p,'dead',actor)===1||await call(p,'dying',actor)===1)return cleanup(3);
  const id=actionParameter(node,0)>>>0,rawClass=actionParameter(node,1)>>>0,index=rawClass&255,domain=actionParameter(node,2)|0,
    meta=actionParameter(node,3)|0,requestedSpontaneous=actionParameter(node,4)|0,targetId=actionParameter(node,5)>>>0,
    point=[6,7,8].map(i=>actionParameter(node,i)),flags=actionParameter(node,9)>>>0,feat=actionParameter(node,10)|0,casterLevel=actionParameter(node,11)&255,
    instant=(flags>>>30)&1,cheat=Boolean(flags&0x80000000);
  let defensive=(rawClass>>>8)&255;
  if(requestedSpontaneous!==0||feat!==-1)throw new Error('Native non-ordinary cast action owner is unavailable');
  if(targetId!==OBJECT_INVALID)await call(p,'setLock',actor,targetId);else await call(p,'facePoint',actor,point);
  const spell=call(p,'spell',id);if(!spell)return cleanup(3);
  actor.nativeTarget740=targetId===OBJECT_INVALID?call(p,'areaId',actor):targetId;
  let components=null;
  if(!cheat){
    const uses=call(p,'uses',actor,id,index,domain&255,meta&255)&255;
    if(index!==254&&index!==255&&integer(actor.nativeField81c,'consumed flag')===0&&uses===0){
      if(spell.spontaneouslyCast&&call(p,'levelReady',actor,index,domain)!==0)throw new Error('Native spontaneous cast conversion owner is unavailable');
      actor.nativeField81c=0;await cleanup(3);await call(p,'feedback',actor,22);return 3;
    }
    components=await call(p,'components',actor,spell,index,domain,meta);
    if(!components||typeof components.accepted!=='boolean')throw new Error('Native cast component admission outcome is unavailable');
    if(!components.accepted){
      if(components.clearConsumed)actor.nativeField81c=0;
      await cleanup(3);if(components.feedback!==null)await call(p,'feedback',actor,components.feedback);return 3;
    }
  }
  const target=call(p,'object',targetId);
  if(targetId!==OBJECT_INVALID&&!target){actor.nativeField81c=0;return cleanup(3);}
  if(await call(p,'targetGate',actor,target)===false){actor.nativeField81c=0;return cleanup(3);}
  await call(p,'activityManager',actor,1);
  const quick=Boolean(call(p,'automaticQuicken',actor,spell,index,domain,meta));
  let conjure=integer(spell.conjureTime,'conjure time')>>>0,castTime=integer(spell.castTime,'cast time')>>>0;
  if(instant){conjure=0;castTime=0;}
  else if(meta===8||quick)conjure=Math.min(conjure,rulesetInt(rules,'QUICKENED_SPELL_MINIMUM_CONJURE_TIME',500)>>>0);
  else if(integer(actor.nativeHaste760,'haste flag')===1){
    const value=f(f(conjure)*rulesetFloat(rules,'HASTED_SPELL_CONJURE_TIME_MODIFIER',.5));
    conjure=(Number.isFinite(value)&&value>=-9223372036854775808&&value<9223372036854775808?Math.trunc(value):0)>>>0;
  }
  if(!instant&&Number(actor.combatRound.started)===0){
    const opportunity=async()=>{
      if((integer(actor.combatMode,'combat mode')&255)===9){defensive=1;setActionParameter(node,1,1,rawClass|256);}
      else if(integer(call(p,'hasFeat',actor,696),'casting opportunity feat')===0)await call(p,'opportunity',actor,OBJECT_INVALID,0);
    };
    if(actor.nativeHaste760===1&&index!==254&&spell.userType===1)await opportunity();
    await call(p,'broadcast',actor,id,index,feat&65535);
    const fast=meta===8||quick||actor.nativeHaste760===1,length=fast?rulesetInt(rules,'FAST_SPELLCAST_ROUND',3000)>>>0:6000;
    await call(p,'startRound',actor,length);
    const duration=(conjure+castTime+500)|0;
    await call(p,'decrementRound',actor,duration,0);await call(p,'pause',actor,1,actor.id);await call(p,'pauseTimer',actor,duration,0);
    if(actor.nativeHaste760!==1&&!fast&&index!==254&&spell.userType===1)await opportunity();
  }
  const elapsed=integer(call(p,'elapsed',actor),'elapsed time')>>>0;
  if(elapsed===0){
    actor.nativeSpellId218=id;actor.nativeSpellDomain21c=domain&255;actor.nativeSpellTarget214=targetId;actor.nativeSpellPoint208=[...point];
    actor.nativeSpellImpact224=0;actor.nativeSpellFeat23c=feat&65535;actor.nativeSpellMetamagic22d=meta&255;actor.nativeSpellSpontaneous228=0;
  }
  if(elapsed<conjure){await call(p,'setAnimation',actor,(spell.conjureAnimation&65535)===2?16:15);return 1;}
  if(integer(node.nativeField9c,'release flag')===1){
    node.nativeField9c=0;
    if(!cheat){
      if(await call(p,'lineOfSight',actor,target,point)===0){
        await call(p,'setAnimation',actor,1);await call(p,'setLock',actor,OBJECT_INVALID);actor.nativeField81c=0;
        if(!instant)await call(p,'feedback',actor,21);return cleanup(3);
      }
      if(index!==255&&actor.nativeField81c===0){
        if(await call(p,'consume',actor,id,index,domain&255,meta&255,casterLevel)===0)return cleanup(3);
        actor.nativeField81c=1;
      }
      const accepted=await call(p,'releaseChecks',actor,spell,index,meta,components,{instant,domain,defensive});
      if(typeof accepted!=='boolean')throw new Error('Native cast release outcome is unavailable');
      if(!accepted)return cleanup(3);
    }
    actor.nativeSpellClass22c=index;actor.nativeSpellTarget818=OBJECT_INVALID;actor.nativeSpellSpontaneous228=0;actor.nativeSpellMetamagic22d=meta&255;
    await call(p,'projectileTime',actor,flags&255);
  }
  if(!instant&&elapsed<((conjure+500)>>>0)){
    const animation=({1:17,2:18,3:19,4:20,6:61,7:89,8:96})[spell.castAnimation&65535];
    if(animation!==undefined)await call(p,'setAnimation',actor,animation);return 1;
  }
  if(!instant&&elapsed>=((conjure+castTime+500)>>>0)&&actor.nativeSpellImpact224!==0){
    await call(p,'setAnimation',actor,1);await call(p,'setLock',actor,OBJECT_INVALID);actor.nativeField81c=0;
    if(integer(actor.nativeField700,'combat state')===1)await call(p,'setCombatState',actor,1);
    return cleanup(2);
  }
  if(actor.nativeSpellImpact224===0)await call(p,'impact',actor,id,point,targetId,index,OBJECT_INVALID,0,0,flags&255,instant);
  if(!instant)return 1;
  // Original tail restores idle and clears its resource guard even when the
  // instant request reaches its impact on the first action traversal.
  await call(p,'setAnimation',actor,1);await call(p,'setLock',actor,OBJECT_INVALID);actor.nativeField81c=0;
  if(integer(actor.nativeField700,'combat state')===1)await call(p,'setCombatState',actor,1);
  return cleanup(2);
}
