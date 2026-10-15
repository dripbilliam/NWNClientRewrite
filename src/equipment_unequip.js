import {OBJECT_INVALID} from './game_object_array.js';
import {createRoundAction} from './combat_action.js';
import {decrementRoundLength} from './combat_round.js';
import {actionPending} from './combat_timing.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native unequip ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native unequip provider ${n} is unavailable`);return p[n];};

// CanUnEquipWeapon1403d22b0. Return2 promotes the left weapon; it precedes
// the exact-one natural-weapon locks. Client LUO changes are a separate owner.
export async function canUnequipWeapon(actor,item,p){
  if(integer(actor.nativeEquipmentLock97c,'equipment lock')!==0)return 0;
  const right=required(p,'equipped')(actor,16),left=p.equipped(actor,32);
  if(right?.id===item.id&&left&&(integer(required(p,'baseInfo')(left).weaponType,'left weapon type')&255)!==0){
    const client=required(p,'client')(actor.id);if(client)await required(p,'clearWeaponSelection')(client);return 2;
  }
  for(const [field,slot] of [['nativeField868',2048],['nativeField86c',8192],['nativeField870',4096]])
    if(integer(actor[field],field)===1&&p.equipped(actor,slot)?.id===item.id)return 0;
  return 1;
}

// AddUnequipAction140374f80. Native duplicate handling scans to the tail
// and writes THAT record's target if any earlier match was seen. Preserve
// this observed quirk rather than replacing the matching record's fields.
export async function addRoundUnequipAction(actor,itemId,repositoryId,x,y,p){
  const r=actor.combatRound;itemId=integer(itemId,'item ID')>>>0;repositoryId=integer(repositoryId,'repository ID')>>>0;x=integer(x,'x')&255;y=integer(y,'y')&255;
  if(Number(r.started)===0)return;
  const item=required(p,'item')(itemId);if(item&&(integer(await required(p,'canUnequip')(actor,item),'gate')&255)===0)return;
  let found=false,last=null;
  for(const action of r.actions){last=action;if(action&&(action.nativeActionType&255)===7&&action.targetId===itemId)found=true;}
  if(found){if(!last)throw new Error('Native duplicate unequip tail is null');last.targetId=itemId;return;}
  decrementRoundLength(r,1500,true);
  r.actions.unshift(createRoundAction(7,itemId,{duration:1500,repositoryId,repositoryX:x,repositoryY:y}));
}

// AddUnequipActions140380bd0. Unlike AddEquipItemActions, a disabled +ec
// gate does not send cancellation. In-combat armor rejection does.
export async function addUnequipActions(actor,item,repositoryId,x,y,front,force,playerId,p){
  repositoryId=integer(repositoryId,'repository ID')>>>0;x=integer(x,'x')&255;y=integer(y,'y')&255;
  front=integer(front,'front');force=integer(force,'force');playerId=integer(playerId,'player ID')>>>0;
  const explicit=Number(playerId!==OBJECT_INVALID&&playerId!==actor.id),client=required(p,'client')(explicit?playerId:actor.id),message=required(p,'messageAvailable')();
  if(integer(actor.nativeFieldEc,'action gate')===0)return 0;
  const armor=integer(actor.nativeField700,'combat state')===1?required(p,'equipped')(actor,2):null;
  if(armor?.id===item.id){if(client&&message)await required(p,'cancel')(client,item.id,explicit);await required(p,'feedback')(actor,194,client);return 0;}
  const r=actor.combatRound;
  if(Number(r.started)===1&&Number(r.paused)===0&&force===0)await required(p,'roundUnequip')(actor,item.id,repositoryId,x,y);
  else await required(p,'queue')(actor,11,[{type:3,value:item.id},{type:3,value:repositoryId},{type:6,value:x},{type:6,value:y},{type:3,value:playerId}],front===0?'tail':Number(r.paused)===0?'front':'afterFront');
  return 1;
}

// ProcessPendingCombatActions14039be00. Due HEAD gates the whole traversal;
// then traverse from tail, convert valid equipment records and dispose each
// even when the request owner rejects. GetPrev precedes removal in native.
export async function processPendingEquipment(actor,p){
  const r=actor.combatRound;if(!actionPending(r))return;
  for(let index=r.actions.length-1;index>=0;index--){
    const action=r.actions[index],type=action.nativeActionType&255;if(type!==6&&type!==7)continue;
    const item=required(p,'item')(action.targetId);if(!item)continue;
    if(type===6)await required(p,'addEquip')(actor,item,action.equipmentSlot,1,1,OBJECT_INVALID);
    else await required(p,'addUnequip')(actor,item,integer(action.repositoryId,'pending repository ID')>>>0,integer(action.repositoryX,'pending x')&255,integer(action.repositoryY,'pending y')&255,1,1,OBJECT_INVALID);
    const at=r.actions.indexOf(action);if(at<0)throw new Error('Native pending equipment record lost ownership');
    r.actions.splice(at,1);await p.dispose?.(action);
  }
}

// RunUnequip14039fff0..1403a059f. Repository fitting/acquisition, property
// effects, drops and client presentation remain explicit provider boundaries.
export async function runUnequip(actor,itemId,repositoryId,x,y,flag,playerId,p){
  itemId=integer(itemId,'item ID')>>>0;repositoryId=integer(repositoryId,'repository ID')>>>0;x=integer(x,'x')&255;y=integer(y,'y')&255;
  flag=integer(flag,'repository flag');playerId=integer(playerId,'player ID')>>>0;
  const explicit=Number(playerId!==OBJECT_INVALID),client=required(p,'client')(explicit?playerId:actor.id),gui=client?required(p,'inventoryGUI')(client,explicit):null,message=required(p,'messageAvailable')();
  const cancel=async()=>{if(client&&message)await required(p,'cancel')(client,itemId,explicit);return 0;};
  const ref={item:required(p,'item')(itemId)};
  if(!ref.item||ref.item.possessorId!==actor.id||await required(p,'inEquipment')(actor,ref.item)!==1)return cancel();
  let other=null,repo;
  if(repositoryId===OBJECT_INVALID||repositoryId===actor.id)repo=required(p,'repository')(actor);
  else{
    const bag=p.item(repositoryId);
    if(bag&&bag.possessorId===actor.id)repo=p.repository(bag);
    else{other=required(p,'creature')(repositoryId);if(!other)return cancel();repo=p.repository(other);}
  }
  if(!repo)return cancel();
  const gate=integer(await required(p,'canUnequip')(actor,ref.item),'gate')&255;if(gate!==1&&gate!==2)return cancel();
  await required(p,'unequip')(actor,ref.item,0,1);
  const placed=gate===2?await required(p,'addItem')(repo,ref,x,y,flag,0):other?
    await required(p,'acquire')(other,ref,actor.id,repositoryId,x,y,0,1):await required(p,'addItem')(repo,ref,x,y,0,flag);
  const dropped=placed===0;
  if(dropped){await required(p,'removeItem')(actor,ref.item,0,1,1,1);await required(p,'drop')(actor,ref.item);}
  let promoted=null;
  if(gate===2){promoted=required(p,'equipped')(actor,32);if(promoted){await p.unequip(actor,promoted,0,1);await required(p,'equip')(actor,16,promoted,1,0,1);}}
  if(!dropped){
    await required(p,'setPossessor')(ref.item,repositoryId===OBJECT_INVALID?actor.id:repositoryId,0,0,0);
    if(repositoryId===OBJECT_INVALID){x=integer(ref.item.repositoryX,'placed x')&255;y=integer(ref.item.repositoryY,'placed y')&255;}
  }
  if(!client)return 0;if(!message)return cancel();
  if(!dropped&&repositoryId===OBJECT_INVALID){
    const page=integer(await required(p,'page')(repo,x,y),'page')&255;
    if(integer(gui.field8,'GUI open')!==0&&page!==(integer(gui.fieldC,'GUI panel')&255))await required(p,'selectPanel')(client,gui,page);
  }
  if(promoted)await required(p,'unequippedMessage')(client,promoted.id,explicit);
  await required(p,'unequippedMessage')(client,gate===2?ref.item.id:itemId,explicit);
  if(promoted)await required(p,'equippedMessage')(client,promoted.id,16,explicit);
  return 1;
}

// AIActionUnequipItem1403cef60; native reads the zeroed raw parameter slots
// even for short parameterCount. Successful unequip has no encumbrance call.
export async function executeUnequipAction(actor,node,p){
  if((integer(actor.associateType,'associate type')&65535)===3&&await required(p,'controlled')(actor.id)!==0&&await required(p,'associatesCanInteract')()===0){await required(p,'feedback')(actor,176,null);return 3;}
  await required(p,'activityManager')(actor,2);
  const itemId=node.parameterData[0]>>>0,repositoryId=node.parameterData[1]>>>0,x=node.parameterData[2]&255,y=node.parameterData[3]&255;
  let playerId=(node.parameterCount&65535)>=5?node.parameterData[4]>>>0:OBJECT_INVALID;
  if(await required(p,'pauseState')(0)===0&&await required(p,'exclusion')(actor.id)===0)return 1;
  if(await required(p,'dead')(actor)===0&&await required(p,'dying')(actor)===0&&await required(p,'runUnequip')(actor,itemId,repositoryId,x,y,0,playerId)===1)return 2;
  if(playerId===OBJECT_INVALID)playerId=actor.id;
  const client=required(p,'client')(playerId),message=required(p,'messageAvailable')();if(client&&message)await required(p,'cancel')(client,itemId,0);return 3;
}

// ClearAction140387172..189 and shared tail140387778. No attack cleanup.
export async function clearUnequipAction(actor,node,head,p){
  if(integer(node.nativeField9c,'cancellation flag')===0)return 0;
  const message=required(p,'messageAvailable')(),client=required(p,'client')(actor.id);
  if(client&&message)await required(p,'cancel')(client,node.parameterData[0]>>>0,0);
  if((integer(actor.lockOrientationId,'orientation lock')>>>0)!==OBJECT_INVALID)await required(p,'setLock')(actor,OBJECT_INVALID);
  if(Number(head)===1)actor.objectActionState.startDay=actor.objectActionState.startTime=0;return 1;
}

// ExecuteCommandEquipItem14051ca60 / UnequipItem14054a590, after VM pops.
// The optional third equip object is consumed but unused in this build.
// Signed input is checked as UINT; all accepted powers of2 are exact FLOATs.
export async function scriptEquipItem(actorId,itemId,slot,p){
  slot=integer(slot,'script slot')>>>0;if(slot>=18)return;
  const actor=required(p,'creature')(actorId);if(!actor)return;
  const item=required(p,'item')(itemId);if(item)await required(p,'addEquip')(actor,item,2**slot,0,0,OBJECT_INVALID);
}
export async function scriptUnequipItem(actorId,itemId,p){
  const actor=required(p,'creature')(actorId);if(!actor)return;
  const item=required(p,'item')(itemId);if(item)await required(p,'addUnequip')(actor,item,OBJECT_INVALID,255,255,0,0,OBJECT_INVALID);
}
