import { OBJECT_INVALID } from './game_object_array.js';
import { actionByGroupId } from './object_actions.js';

// ClearHostileActionsVersus140387bf0. Native group count is a snapshot;
// after removal enumeration restarts at index1, preserving that quirk.
export async function clearHostileActionsVersus(actor,target,p){
  const list=actor.objectActionState?.list;if(!list)throw new Error('Native hostile action list is unavailable');
  const groups=()=>{const result=[];let previous=-1;for(const node of list){const group=node.groupId&65535;
    if(group!==previous)result.push(node);previous=group;}return result;};
  const count=groups().length;
  for(let index=0;index<count;index++){
    const node=groups()[index];if(!node)continue;
    const action=actionByGroupId(actor.objectActionState,node.groupId);if(!action)continue;
    const id=action.actionId|0,slot=id===12?0:id===15?5:id===46?3:-1;
    if(slot<0||(action.parameterData[slot]>>>0)!==(target.id>>>0))continue;
    if(typeof p.removeGroup!=='function')throw new Error('Native hostile action group removal is unavailable');
    await p.removeGroup(actor,node.groupId);index=0;
    if(id===15){
      if(typeof p.cancelSpell!=='function')throw new Error('Native hostile spell cancellation is unavailable');
      await p.cancelSpell(actor);
    }
  }
}

// CNWSObject::SetLastHostileActor 0x14049b070..0x14049b254. Lookup failure
// and the same-faction PVP veto retain history; invalid existing actors clear
// it. The AoE branch intentionally has no second self-ID check.
export function setLastHostileActor(object, callerId, force, providers) {
  if (![callerId, force].every(Number.isInteger)) throw new Error('Native hostile actor arguments are unavailable');
  callerId >>>= 0; force |= 0;
  if (force === 1) {
    if (callerId !== OBJECT_INVALID) providers.warning?.('Native warning: forced hostile assignment should only clear to OBJECT_INVALID');
    object.lastHostileActorId = callerId; return;
  }
  const clear = () => { object.lastHostileActorId = OBJECT_INVALID; };
  if (Number(object.plot) === 1) { clear(); return; }
  const caller = providers.object(callerId);
  if (!caller) return;
  let creature;
  if (caller.objectType === 11) {
    if (!Number.isInteger(caller.creatorId)) throw new Error('Native area-of-effect hostile creator ID is unavailable');
    creature = providers.creature(caller.creatorId);
  }
  else if (caller.objectType === 5 && caller.id !== object.id) creature = providers.creature(caller.id);
  else { clear(); return; }
  if (!creature || providers.dead(creature) === 1) { clear(); return; }
  if (creature.isPC || creature.isPossessedFamiliar) {
    if (providers.hitPoints(creature) < 1 && providers.hitPoints(creature) > -10) { clear(); return; }
  }
  if (providers.dm(creature) !== 0) { clear(); return; }
  if (object.objectType === 5) {
    const area = providers.area(object);
    if (area && (providers.pvp(area) & 255) < 2 && providers.faction(creature) === providers.faction(object)) return;
  }
  object.lastHostileActorId = creature.id >>> 0;
}
