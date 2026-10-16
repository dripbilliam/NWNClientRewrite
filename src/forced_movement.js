import {OBJECT_INVALID} from './game_object_array.js';
import {createObjectAction,setActionParameter,disposeObjectAction} from './object_actions.js';
const f=Math.fround;
const bits=value=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,value,true);return d.getInt32(0,true);};
// MoveToPoint1403c4071..1403c4134 allocates a separate owned timeout payload.
// The remaining movement is requeued with the force bit cleared by its caller.
export async function queueForcedMove(actor,group,areaId,point,targetId,seconds,p){
  const payload={type:1,group:group&65535,areaId:areaId>>>0,position:point.map(f),targetId:targetId>>>0};
  const delta=await p.delta(f(seconds));await p.event(delta.day,delta.time,actor.id,actor.id,18,payload);
}

// Creature event18 at14038f22d..14038f440. Only a successful cancellation of
// the original group invokes the forced jump. A later follow cycle has a new
// group and must not be teleported by this expired earlier timeout.
export async function receiveForcedMove(actor,payload,p){
  if(await p.cancel(actor,0,payload.group)!==1||payload.type!==1)return;
  const point=payload.position,node=createObjectAction(payload.targetId===OBJECT_INVALID?5:48,payload.group),
    params=payload.targetId===OBJECT_INVALID?[
      [2,bits(point[0])],[2,bits(-point[2])],[2,bits(point[1])],[3,payload.areaId],[1,1],[2,bits(1)],[2,bits(0)]
    ]:[[3,payload.targetId],[1,1]];
  params.forEach(([type,value],index)=>setActionParameter(node,index,type,value));
  try{if(node.actionId===5)await p.jumpPoint(actor,node);else await p.jumpObject(actor,node);}
  finally{await disposeObjectAction(node);}
}
