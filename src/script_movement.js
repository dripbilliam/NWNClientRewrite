import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction} from './object_actions.js';
import {addMoveToPointBack} from './movement_actions.js';
const f=Math.fround;
const bits=value=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,value,true);return v.getInt32(0,true);};
// ExecuteCommandWait14054b100 accepts any CNWSObject with Ec != 0.
export function scriptWait(actor,seconds){
  if(actor?.objectType>4&&actor.nativeFieldEc!==0)addObjectAction(actor.objectActionState,30,65535,[{type:2,value:bits(seconds)}]);
}

// ExecuteCommandMoveToObject1405365f0: use-range chooses the stopping
// distance, but the move point is the target's actual stored position.
export async function scriptMoveToObject(actor,target,run,range,timeout,p){
  if(actor?.objectType!==5||!target||actor.nativeFieldEc===0)return;
  const out={point:[0,0,0],range:0};await p.useRange(actor,target.id,out);
  const distance=out.range>f(range)?f(out.range):f(range),area=await p.area(target);
  if(!area)return;
  await addMoveToPointBack(actor,65535,target.position,area.id,target.id,run|0,distance,f(timeout),0,0,0,0,0,0,p);
  addObjectAction(actor.objectActionState,17,65534,[{type:3,value:target.id},{type:1,value:run|0},
    {type:2,value:bits(distance)},{type:2,value:bits(distance)},{type:1,value:1}]);
}

// ExecuteCommandMoveToPoint140536910: no commandability gate. An absent
// location area is checked against the actor's area, without rewriting the
// area ID in the queued action. Location vectors are native XYZ.
export async function scriptMoveToLocation(actor,location,run,timeout,p){
  if(actor?.objectType!==5||!location)return;
  const found=await p.object(location.areaId),area=found??await p.area(actor);
  if(area?.objectType!==4)return;
  const point=[location.position[0],location.position[2],-location.position[1]];
  await addMoveToPointBack(actor,65535,point,location.areaId,OBJECT_INVALID,run|0,0,f(timeout),0,0,0,0,0,0,p);
}
