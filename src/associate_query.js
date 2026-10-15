import {OBJECT_INVALID} from './game_object_array.js';
// GetAssociateId1403d4d70. Physical IDs, including duplicate/stale entries,
// retain order. Counting starts1; -1 is an immediate invalid result.
export function creatureAssociateId(actor,type,nth,getCreature){
  if(!actor)return OBJECT_INVALID;if(!Number.isInteger(type)||!Number.isInteger(nth))throw new Error('Native associate query INT is unavailable');
  type&=65535;nth|=0;if(nth===-1||actor.associateIds===null)return OBJECT_INVALID;
  if(!Array.isArray(actor.associateIds))throw new Error('Native associate ID list is unavailable');
  let count=1;for(const id of actor.associateIds){const o=getCreature(id);if(!o||(o.associateType&65535)!==type)continue;if(count===nth)return id>>>0;count=(count+1)|0;}
  return OBJECT_INVALID;
}
// ExecuteCommandGetAssociate14051f370 selects explicit1..4, otherwise the
// dominated/charmed branch1403d51a0 based on statsPCb0, not a guessed type.
export function scriptGetAssociate(actor,type,nth,getCreature){
  if(!actor)return OBJECT_INVALID;if(!Number.isInteger(type))throw new Error('Native associate query type is unavailable');type|=0;
  if(((type-1)>>>0)>3){if(!Number.isInteger(actor.nativeStatsIsPCb0))throw new Error('Native associate master PC storage is unavailable');type=actor.nativeStatsIsPCb0===0?6:5;}
  return creatureAssociateId(actor,type,nth,getCreature);
}
