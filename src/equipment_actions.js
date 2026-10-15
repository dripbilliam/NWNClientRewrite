import {OBJECT_INVALID} from './game_object_array.js';
import {createRoundAction} from './combat_action.js';
import {decrementRoundLength} from './combat_round.js';
import {actionParameter} from './object_actions.js';
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native equipment action provider ${n} is unavailable`);return p[n];};
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native equipment action ${n} is unavailable`);return v|0;};

// CNWSCombatRound::AddEquipAction140374930. Coalesce the first matching
// item OR slot in place. New records precede the head unless paused==1.
export async function addRoundEquipAction(actor,itemId,slot,p){
  const r=actor.combatRound;itemId=integer(itemId,'item ID')>>>0;slot=integer(slot,'slot')>>>0;
  if(Number(r.started)===0||!required(p,'item')(itemId))return;
  const existing=r.actions.find(a=>a.nativeActionType===6&&(a.equipmentSlot===slot||a.targetId===itemId));
  if(existing){
    if(required(p,'messageAvailable')()&&(integer(actor.nativeStatsIsPCb0,'stats PC')!==0||await required(p,'possessed')(actor)!==0))
      await required(p,'roundCancel')(actor,existing.targetId,existing.equipmentSlot,0);
    existing.targetId=itemId;existing.equipmentSlot=slot;return;
  }
  decrementRoundLength(r,1500,true);
  const action=createRoundAction(6,itemId,{duration:1500,equipmentSlot:slot});
  if(Number(r.paused)!==1&&r.actions.length)r.actions.unshift(action);else r.actions.push(action);
}

// AddEquipItemActions14037eb50. Immediate/front/after-front object actions
// and round actions are separate owners, with the same three raw parameters.
export async function addEquipItemActions(actor,item,slot,front,force,playerId,p){
  slot=integer(slot,'slot')>>>0;front=integer(front,'front');force=integer(force,'force');playerId=integer(playerId,'player ID')>>>0;
  const client=required(p,'client')(playerId)??p.client(actor.id),message=required(p,'messageAvailable')();
  if(integer(actor.nativeFieldEc,'action gate')===0||integer(actor.nativeField700,'combat state')===1&&slot===2){
    if(client&&message)await required(p,'cancel')(client,item.id,slot,0);
    if(actor.nativeFieldEc!==0)await required(p,'feedback')(actor,193,client);
    return 0;
  }
  const r=actor.combatRound;
  if(Number(r.started)===1&&Number(r.paused)===0&&force===0)await required(p,'roundEquip')(actor,item.id,slot);
  else await required(p,'queue')(actor,8,[{type:3,value:item.id},{type:1,value:slot},{type:3,value:playerId}],
    front===0?'tail':Number(r.paused)===0?'front':'afterFront');
  return 1;
}

// GetPauseState140560d10 / IsOnExclusionList140564590. The equip owner
// passes mask0; the exclusion arrays select which actors may keep running.
export function serverPauseState(state,mask){return Number(((integer(state.flags,'server pause flags')&255)&(integer(mask,'pause mask')&255))!==0);}
export function onServerExclusionList(state,id){
  const flags=integer(state.flags,'server pause flags')&255;
  if((flags&2)===0&&(flags&1)===0)return 1;
  const list=(flags&2)!==0?state.list100f8:state.list10100;
  if(!Array.isArray(list))throw new Error('Native server pause exclusion storage is unavailable');
  return Number(list.includes(integer(id,'object ID')>>>0));
}

// AIActionEquipItem1403bbb60: activity cleanup happens even for malformed
// nodes and paused actors; only result==1 updates encumbrance/completes.
export async function executeEquipAction(actor,node,p){
  await required(p,'activityManager')(actor,2);
  if((node.parameterCount&65535)<2)return 3;
  const itemId=actionParameter(node,0)>>>0,slot=actionParameter(node,1)>>>0;
  let playerId=(node.parameterCount&65535)>2?actionParameter(node,2)>>>0:OBJECT_INVALID;
  if(await required(p,'pauseState')(0)===0&&await required(p,'exclusion')(actor.id)===0)return 1;
  if(await required(p,'dead')(actor)===0&&await required(p,'dying')(actor)===0&&await required(p,'runEquip')(actor,itemId,slot,playerId)===1){
    await required(p,'encumbrance')(actor,1);return 2;
  }
  if(playerId===OBJECT_INVALID)playerId=actor.id;
  const client=required(p,'client')(playerId),message=required(p,'messageAvailable')();
  if(client&&message)await required(p,'cancel')(client,itemId,slot,0);return 3;
}

// ClearAction1403870b0 action8 and shared tail. Equipment cancellation
// reports the old raw item/slot but does not force a new body animation.
export async function clearEquipAction(actor,node,head,p){
  if(integer(node.nativeField9c,'cancellation flag')===0)return 0;
  if(node.actionId!==8)throw new Error('Native non-equip cancellation is unavailable');
  const message=required(p,'messageAvailable')(),client=required(p,'client')(actor.id);
  if(client&&message)await required(p,'cancel')(client,node.parameterData[0]>>>0,node.parameterData[1]>>>0,0);
  if((integer(actor.lockOrientationId,'orientation lock')>>>0)!==OBJECT_INVALID)await required(p,'setLock')(actor,OBJECT_INVALID);
  if(Number(head)===1)actor.objectActionState.startDay=actor.objectActionState.startTime=0;
  return 1;
}

// RunEquip14039f960. Repository ownership, replacement/stack merging,
// drops and mode cleanup remain separate explicit providers.
export async function runEquip(actor,itemId,slot,playerId,p){
  itemId=integer(itemId,'item ID')>>>0;slot=integer(slot,'slot')>>>0;playerId=integer(playerId,'player ID')>>>0;
  const explicit=Number(playerId!==OBJECT_INVALID);if(!explicit)playerId=actor.id;
  const client=required(p,'client')(playerId),message=required(p,'messageAvailable')(),incoming={item:required(p,'item')(itemId)},ref={slot};
  const cancel=async()=>{if(client&&message)await required(p,'cancel')(client,itemId,ref.slot,explicit);return 0;};
  if(!incoming.item)return cancel();
  let bag=null,repository;
  if(incoming.item.possessorId===actor.id)repository=required(p,'repository')(actor);
  else{
    bag=p.item(incoming.item.possessorId);
    if(bag){
      if(bag.possessorId!==actor.id){if(!client)return 0;if(bag.possessorId!==required(p,'controlledId')(client))return cancel();}
      repository=p.repository(bag);
    }else{
      const owner=incoming.item.possessorId===OBJECT_INVALID?null:required(p,'creature')(incoming.item.possessorId);
      if(!owner)return cancel();if(!client)return 0;
      const controlled=required(p,'controlledId')(client);if(controlled!==actor.id&&controlled!==owner.id)return cancel();
      if(await required(p,'acquire')(actor,incoming,incoming.item.possessorId,OBJECT_INVALID,255,255,0,1)===0)return cancel();
      repository=p.repository(actor);
    }
  }
  const allowed=integer(await required(p,'canEquip')(actor,incoming.item,ref,1,0,1,client),'equip result')&255;
  const stash=async item=>{
    await required(p,'unequip')(actor,item,0,1);const old={item};
    if(await required(p,'stash')(actor,old,255,255,0,1)===0){await required(p,'removeItem')(actor,old.item,0,1,1,1);await required(p,'drop')(actor,old.item);}
  };
  if(allowed===2){
    const old=required(p,'equipped')(actor,ref.slot);if(!old)return cancel();
    if((integer(required(p,'baseInfo')(incoming.item).stacking,'stacking')&65535)>1){
      if(old===incoming.item)return 1;
      if(await required(p,'merge')(old,incoming.item)!==0){
        const target=bag&&bag.possessorId===actor.id?p.repository(bag):p.repository(actor);
        if(!target)return cancel();await required(p,'remove')(target,incoming.item);await required(p,'destroy')(incoming.item);incoming.item=null;return cancel();
      }
    }
    await stash(old);
  }else if(allowed===3){
    const right=required(p,'equipped')(actor,16);if(right)await stash(right);
    const left=p.equipped(actor,32);if(left)await stash(left);else if(!right)return cancel();
  }else if(allowed!==1)return cancel();
  if(await required(p,'contains')(repository,incoming.item,0)===1)await required(p,'remove')(repository,incoming.item);
  if(incoming.item.possessorId!==actor.id)await required(p,'setPossessor')(incoming.item,actor.id,0,0,0);
  await required(p,'equip')(actor,ref.slot,incoming.item,1,0,1);
  if(client&&message)await required(p,'equippedMessage')(client,itemId,ref.slot,explicit);
  const right=p.equipped(actor,16),left=p.equipped(actor,32),mode=integer(actor.combatMode,'combat mode')&255;
  if(mode===5){
    if(!right)return 1;
    if(required(p,'monkWeapon')(right)!==0&&!left)return 1;
    if(await required(p,'hasFeat')(actor,899)!==0)return 1;
    if(await required(p,'relativeSize')(actor,right)<0&&await p.hasFeat(actor,866)!==0)return 1;
  }else if(mode===6){if(right&&required(p,'baseInfo')(right).ranged!==0)return 1;}
  else if(mode>11||(0xd8e>>>mode&1)===0||!right||required(p,'baseInfo')(right).ranged===0)return 1;
  await required(p,'setCombatMode')(actor,0,1);return 1;
}
