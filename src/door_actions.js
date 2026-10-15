import {addObjectAction,actionParameter} from './object_actions.js';

// Door EventHandler14041e760: strict positive native XYZ dot.
// Canonical orientation is stored in renderer XYZ, so native Y is -renderZ.
export function doorEventOpenState(door,caller){
  if(!caller)return 2;
  const f=Math.fround,d=caller.position.map((v,i)=>f(f(v)-f(door.position[i]))),o=door.orientation;
  return f(f(f(d[0]*o[0])+f(d[2]*o[2]))+f(d[1]*o[1]))>0?1:2;
}

// OpenDoor1405379f0 / CloseDoor140512190 call CNWSObject queue owners.
// These are internal action20/21, distinct from script-visible ACTION5/6.
export function scriptDoorAction(actor,targetId,run,open,p){
  if(!actor?.objectActionState||!p.area(actor))return;
  if(open&&actor.nativeFieldEc!==1)return;
  addObjectDoorAction(actor,targetId,run,open);
}
export function addObjectDoorAction(actor,targetId,run,open){
  if(actor.nativeFieldEc===0)return 0;
  addObjectAction(actor.objectActionState,open?20:21,65535,[{type:3,value:targetId},{type:1,value:run|0}]);return 1;
}
// AIActionOpenDoor1404a2fb0 / CloseDoor14049eb30 noncreature branch.
// The deferred door event owns state, linked-door propagation and OnOpen/Closed.
export async function executeObjectDoorAction(actor,node,p){
  if(await p.dead(actor)===1||await p.dying(actor)===1){if(node.actionId===20)actor.nativeDoorActionPhase250=0;return 3;}
  const targetId=actionParameter(node,0)>>>0,target=p.object(targetId);
  if(!target){if(node.actionId===20)actor.nativeDoorActionPhase250=0;return 3;}
  if(actor.objectType===5)return p.creatureAction(actor,node,target);
  if(node.actionId===20)actor.nativeDoorActionPhase250=0;
  p.enqueue(node.actionId===20?7:6,actor.id,targetId);
  // Native pushes Wait(.5) with the same group, then returns completed2.
  addObjectAction(actor.objectActionState,30,node.groupId,[{type:2,value:0x3f000000}],true);
  return 2;
}
