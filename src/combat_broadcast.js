import { nativeDistanceSquared } from './nearest_objects.js';
import { copyAttackData } from './combat_attack_data.js';
import { intEntry } from './combat_stats.js';
import { OBJECT_INVALID } from './game_object_array.js';

const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native combat broadcast ${name} is unavailable`);return value|0;};
const required=(p,names)=>{for(const name of names)if(typeof p[name]!=='function')throw new Error(`Native combat broadcast provider ${name} is unavailable`);};
function near(a,b){
  if(![a,b].every(o=>Array.isArray(o.position)&&o.position.length===3&&o.position.every(Number.isFinite)))throw new Error('Native combat broadcast position is unavailable');
  return nativeDistanceSquared(a.position,b.position)<=900; // DAT_140d856cc.
}

// BroadcastCombatStateToParty 1403837d0. This does not clear round actions
// or change initiative; it writes +700/+704 directly, then nearby clients.
export async function broadcastCombatState(actor,p){
  required(p,['members','client','excited']);
  actor.nativeField704=8000;actor.nativeField700=1;
  if(Number(actor.plot)!==0)return;
  const members=await p.members(actor);if(members===null)return;
  if(!Array.isArray(members))throw new Error('Native combat faction member list is unavailable');
  for(let i=0;;i++){
    const live=await p.members(actor);
    if(live===null)return;
    if(!Array.isArray(live))throw new Error('Native combat faction member list is unavailable');
    if(i>=live.length)break;
    const client=await p.client(live[i]),object=client?.object;
    if(object&&actor.areaId===object.areaId&&near(actor,object)){
      if(object.objectType!==5)throw new Error('Native faction client creature cast failed');
      object.nativeField704=8000;object.nativeField700=1;await p.excited(object,1);
    }
  }
}

// BroadcastBattleCry 140383630..7c5. Area's live X-sorted object list,
// client lookup and 30m 3D gate precede EACH recipient's separate rand draw.
export async function broadcastBattleCry(actor,p){
  required(p,['areaIds','client','voice']);
  let ids=await p.areaIds(actor);if(ids===null)return;
  if(!Array.isArray(ids))throw new Error('Native battle-cry area object list is unavailable');
  for(let i=0;;i++){
    ids=await p.areaIds(actor);if(ids===null)return;
    if(!Array.isArray(ids))throw new Error('Native battle-cry area object list is unavailable');
    if(i>=ids.length)return;
    const client=await p.client(ids[i]),viewer=client?.object;
    if(!viewer||viewer.areaId!==actor.areaId||!near(actor,viewer))continue;
    if(typeof p.random?.next!=='function')throw new Error('Native battle-cry RNG is unavailable');
    const code=(integer(p.random.next(),'battle-cry draw')%3)+1;
    await p.voice(client,actor.id>>>0,code);
  }
}

// SetExcitedState 1403a3000..1403a3176: unsigned duration comparison.
// Rest cancellation remains an explicit provider when a live controller exists.
export async function setExcitedState(actor,state,rules,p){
  if(!rules.excitedduration)throw new Error('Native ExcitedDuration table is unavailable');
  const entry=intEntry(rules.excitedduration,state&255,'DURATION');if(!entry.found)return;
  const duration=entry.value>>>0,current=integer(actor.excitedDuration,'excited duration')>>>0;
  if(duration<=current)return;
  actor.excitedDuration=duration;
  required(p,['client','area','restController','nearestEnemy','cancelRest']);
  const client=await p.client(actor.id),area=await p.area(actor);
  if(!area||!client)return;
  const controller=await p.restController(area);if(!controller)return;
  if((await p.nearestEnemy(actor))!==OBJECT_INVALID)await p.cancelRest(controller,1);
}

// BroadcastAttackDataToParty 140382c30..140382eae. Recipient list comes
// from server clients, not nearby NPCs; either endpoint's faction/range admits
// the client. These are internal delivery records, not encoded NWN packets.
export async function broadcastAttackData(target,caller,callerId,data,p){
  required(p,['clients','faction','dm','send']);
  const clients=await p.clients();if(!Array.isArray(clients))throw new Error('Native combat client list is unavailable');
  for(const client of clients){
    const viewer=client?.object;if(!viewer||viewer.objectType!==5)continue;
    if(viewer.areaId!==target.areaId&&(!caller||viewer.areaId!==caller.areaId))continue;
    const faction=integer(await p.faction(viewer),'viewer faction');
    if(faction!==integer(await p.faction(target),'target faction')&&(!caller||faction!==integer(await p.faction(caller),'caller faction'))&&
      integer(await p.dm(viewer),'viewer DM')===0&&((integer(viewer.associateType,'associate type')-7)&65535)>1)continue;
    if(!near(viewer,target)&&(!caller||!near(viewer,caller)))continue;
    const type=data.attackType===0||data.attackType===65002||data.coupDeGrace===1?5:6;
    await p.send(client,type,{objects:[callerId>>>0,target.id>>>0]},copyAttackData(data,1));
  }
}

// BroadcastSavingThrowData 140384000 sends to owner (+8fc) in range, then
// directly to this creature's client without area/range or duplicate filtering.
export async function broadcastSavingThrow(actor,data,p){
  return broadcastOwnedCheck(actor,data,7,p);
}
// BroadcastSkillData 140384150 has the same owner/direct delivery rules,
// but message type9. Native recipient duplicates are retained.
export async function broadcastSkillData(actor,data,p){
  return broadcastOwnedCheck(actor,data,9,p);
}
// BroadcastFloatyData140383e60 uses faction membership and the30m gate,
// then type11 delivery. NPCs without clients never receive a UI record.
export async function broadcastFloatyData(actor,data,p){
  required(p,['members','client','send']);let members=await p.members(actor);if(members===null)return;
  if(!Array.isArray(members))throw new Error('Native floating feedback faction list is unavailable');
  for(let index=0;;index++){
    members=await p.members(actor);if(members===null)return;if(index>=members.length)return;
    const client=await p.client(members[index]),viewer=client?.object;
    if(viewer&&viewer.areaId===actor.areaId&&near(actor,viewer))await p.send(client,11,structuredClone(data));
  }
}
async function broadcastOwnedCheck(actor,data,type,p){
  required(p,['client','ownerId','send']);
  const owner=integer(await p.ownerId(actor),'save owner ID')>>>0;
  if(owner!==OBJECT_INVALID){const client=await p.client(owner),viewer=client?.object;
    if(viewer&&viewer.areaId===actor.areaId&&near(viewer,actor))await p.send(client,type,structuredClone(data),null);}
  const client=await p.client(actor.id);if(client)await p.send(client,type,structuredClone(data),null);
}

// SendFeedbackMessage 1403a2480 stores feedback ushort in integer slot9
// and sends type11 only when the creature actually has a client.
export async function sendCombatFeedback(actor,code,data,p){
  required(p,['client','send']);const client=await p.client(actor.id);if(!client)return;
  const copy=structuredClone(data??{type:0});copy.integers??=[];copy.integers[9]=integer(code,'feedback code')&65535;
  await p.send(client,11,copy,null);
}

// Creature event22 14038e95f..14038ea9d. Type1 deliberately broadcasts to
// BOTH endpoints, including an identical caller/target. Default types clone the
// message before receiver delivery so native feedback slot9 cannot leak across.
export async function receiveCombatFeedback(target,callerId,data,p){
  if(!data)return;
  required(p,['creature','savingThrow','feedback']);
  const caller=await p.creature(callerId>>>0),type=integer(data.type,'message type')&255;
  const code=integer(data.integers?.[0]??0,'message integer zero');
  if(type===1){await p.savingThrow(target,data);if(caller)await p.savingThrow(caller,data);}
  else if(type===3){if(caller)await p.feedback(caller,code,data);}
  else if(type===4)await p.feedback(target,code,data);
  else{const copy=structuredClone(data);await p.feedback(target,code,data);if(caller)await p.feedback(caller,code,copy);}
}

// RemoveCombatInvisibilityEffects 14039e500..14039e5a2. +da2 is a live
// effect-array index, NOT an invisibility flag. Requery it after each removal.
export async function removeCombatInvisibility(actor,p){
  required(p,['effects','index','integer','remove']);let index=integer(await p.index(actor),'invisibility effect index')&65535;
  while(index<(await p.effects(actor)).length){
    const effect=(await p.effects(actor))[index],type=integer(effect?.type,'effect type')&65535;
    if(type>63)return;
    if(type===47&&integer(await p.integer(effect,0),'invisibility kind')===1||type===63){
      await p.remove(actor,effect);index=integer(await p.index(actor),'invisibility effect index')&65535;
    }else index++;
  }
}
