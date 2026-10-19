import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction,actionParameter} from './object_actions.js';
// VM ActionUnlockObject483,14050e340; AddUnlockObjectAction14048ddf0.
// No area/death/target validation until execution. Only commandability==0
// rejects append. Tool/property slots remain canonical IDs/raw INT data.
export function addUnlockAction(actor,targetId,itemId=OBJECT_INVALID,property=0){
 if(actor.nativeFieldEc===0)return 0;
 addObjectAction(actor.objectActionState,38,65535,[{type:3,value:targetId},{type:3,value:itemId},{type:1,value:property}]);return 1;
}
export function scriptUnlockAction(actor,targetId){if(actor&&actor.objectType>=5&&actor.objectType<=14)return addUnlockAction(actor,targetId);}
// Noncreature branch of AIActionUnlockObject1404a80f0. The same action is used
// by doors/placeables unlocking themselves from ordinary authored scripts.
// Creature range/skill/tool/animation owners remain explicit lower omissions.
export async function executeUnlockAction(actor,node,p){
 if(await p.dead(actor)===1||await p.dying(actor)===1)return 3;
 const item=p.item(actionParameter(node,1)>>>0),target=p.object(actionParameter(node,0)>>>0);
 if(!target||!p.asWorld(target))return 3;
 if(actor.objectType===5)return p.creatureAction(actor,node,target,item);
 const door=p.door(target),placeable=door?null:p.placeable(target),lock=door??placeable;
 if(!lock)return 2;
 if(p.locked(lock)===0)return 3;
 if(p.keyRequired(lock)!==0){await p.event(actor,target,34);return 3;}
 if((actor.id>>>0)===(target.id>>>0)){p.unlock(lock);await p.event(actor,target,29);}
 return 2;
}
