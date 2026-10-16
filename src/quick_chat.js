import {OBJECT_INVALID} from './game_object_array.js';
const f=Math.fround;
// VM42114054b060. The target fallback is OBJECT_INVALID, not every absent ID.
export async function scriptVoiceChat(selfId,code,targetId,p){
  if((targetId>>>0)===OBJECT_INVALID)targetId=selfId;
  const actor=await p.creature(targetId>>>0);if(!actor)return;
  const message=await p.message();if(message)await p.quickChat(message,actor.id,code&65535);
}

// SendServerToPlayerQuickChatMessage1404df1c0. Player-list endpoints are
// sampled once. Delivery stops after the first zero bitwise accumulated result.
// Null areas can compare equal; no additional area-presence rule is invented.
export async function sendQuickChatMessage(objectId,code,p){
  let ok=1,area=null,point=[0,0,0];const object=await p.object(objectId>>>0);
  if(object&&await p.asCreature(object)){
    area=await p.area(await p.asCreature(object));point=(await p.asCreature(object)).position.slice();
  }else ok=0;
  const clients=await p.players(),end=clients.length;
  for(let i=0;i<end&&ok!==0;i++){
    const client=clients[i],viewer=await p.clientObject(client);
    if(!viewer||area!==await p.area(viewer))continue;
    const dx=f(f(viewer.position[0])-f(point[0])),dy=f(f(viewer.position[2])-f(point[2])),dz=f(f(viewer.position[1])-f(point[1]));
    if(!(f(f(f(dy*dy)+f(dx*dx))+f(dz*dz))<=f(20*20)))continue;
    ok=(ok&(await p.send(client,objectId>>>0,code&65535)))>>>0;
  }
  return ok;
}
