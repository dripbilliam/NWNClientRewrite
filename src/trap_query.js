import {OBJECT_INVALID} from './game_object_array.js';
import {nativeDistanceSquared} from './nearest_objects.js';
import {NativeIdList} from './native_id_list.js';

// DoorLoad4208a0 / PlaceableLoad4b4900 read TrapFlag as BYTEasBOOL.
// TriggerLoad502ac0 sets +3dc when the authored Type DWORD is exactly2.
// Known lists are ctor-owned: trigger+3c8, door+458, placeable+4e8.
export function initializeTrapQuery(object){
  if(![7,9,10].includes(object.objectType))return;
  object.nativeTrapKnownIds??=new NativeIdList();
  object.trapped??=object.objectType===7?Number((object.authored?.Type>>>0)===2):Number(((object.authored?.TrapFlag??0)&255)!==0);
}
// AreaLoadDoors360c3c / Placeables361d4a / Triggers362f5c append IDs
// after AddToArea, when their live trap flag is nonzero. This is separate
// from spatial order and TrapActive/TrapDetectable flags.
export function appendLoadedTrap(area,object){
  if([7,9,10].includes(object.objectType)&&(object.trapped|0)!==0)area.nativeTrapIds158.append(object.id);
}
// ExecuteCommandGetNearestTrap14052ceb0. Exactly1 requests detected-only;
// other integer values consider every live entry. Initial squared radius
// is10000, strict comparison preserves physical list order on ties.
export function nearestTrap(session,reference,detected=1){
  if(!reference||reference.objectType<=4)return OBJECT_INVALID;
  const area=session.registry.get(reference.areaId);
  if(!area)return OBJECT_INVALID;
  if(!area.nativeTrapIds158)throw new Error('Native area trap ID list is unavailable');
  let result=OBJECT_INVALID,distance=10000;
  for(const id of area.nativeTrapIds158.view()){
    const object=session.registry.get(id);if(!object)continue;
    if((detected|0)===1){
      if(![7,9,10].includes(object.objectType))continue;
      if(!object.nativeTrapKnownIds)throw new Error('Native known-trap ID list is unavailable');
      if(object.nativeTrapKnownIds.indexOf(reference.id)<0)continue;
    }
    if(!reference.position||!object.position)throw new Error('Native trap query position is unavailable');
    const squared=nativeDistanceSquared(reference.position,object.position);
    if(squared<distance){distance=squared;result=id;}
  }
  return result;
}
