import {normalizeTileVector} from './tile_surface_mesh.js';
const f=Math.fround;
const vector=value=>{
 if(!Array.isArray(value)||value.length!==3||!value.every(Number.isFinite))throw new Error('Native creature displacement vector is unavailable');
 return value.map(f);
};

// CNWSArea::BudgeCreatures14035c260..14035c58c. Reads the LIVE spatial list:
// SetPosition may reorder that list during traversal. The initial X seek uses
// originX-minX-5, while the later rectangle checks use the world bounds +/-5.
// Preserve that asymmetry, strict boundaries and early sorted-X termination.
export async function budgeCreatures(area,origin,min,max,id,flag,p){
 origin=vector(origin);min=vector(min);max=vector(max);id>>>=0;flag|=0;
 let index=await p.firstByX(area,f(f(origin[0]-min[0])-5))??0;
 const candidate=[0,0,0]; // Persists across iterations, including failed placement.
 while(index<p.ids(area).length){
  const creature=await p.creature(p.ids(area)[index++]);if(!creature)continue;
  const point=vector(p.position(creature));
  if(point[0]>=f(max[0]+5))break;
  if(f(min[0]-5)>=point[0]||f(min[1]-5)>=point[1]||point[1]>=f(max[1]+5))continue;
  if(await p.safePoint(area,[...point],creature.nativePathInfo,0)!==0)continue;
  if(flag!==0){
   const door=await p.door(id);
   if(door)candidate.splice(0,3,...await p.doorPoint(door,[...point],0));
   else{
    const placeable=await p.placeable(id);
    if(placeable)candidate.splice(0,3,...await p.placeablePoint(placeable,[...point]));
   }
  }else{
   const direction=normalizeTileVector(point.map((v,i)=>f(v-origin[i])));
   candidate.splice(0,3,...point.map((v,i)=>f(v+direction[i])));
  }
  if(await p.safeLocation(area,[...candidate],10,creature.nativePathInfo,0,candidate)!==0)
   await p.setPosition(creature,[...candidate],0);
 }
}

// CNWSDoor::SetOpenState140423230..140423396. Map updates happen for1/2/3
// even when the state is unchanged. Displacement happens only for a changed
// non3 state; closing passes1, opening passes0. Unknown BYTE states still budge.
export async function setDoorOpenState(door,state,p){
 const old=door.animationState&255;state=door.nativeDoorField498===0?3:state&255;door.animationState=state;
 const animation=({0:22,1:50,2:51,3:72})[state];
 if(animation!==undefined){
  await p.animation(door,animation);
  if(state!==0&&await p.area(door))await p.updateMaps(await p.area(door));
 }
 if(state!==old&&state!==3){
  const area=await p.area(door);
  if(area){
   if(!Array.isArray(door.nativeDoorBounds4c8)||door.nativeDoorBounds4c8.length!==2)throw new Error('Native door displacement bounds are unavailable');
   await p.budge(area,p.position(door),door.nativeDoorBounds4c8[0],door.nativeDoorBounds4c8[1],door.id,Number(state===0));
  }
 }
}

// CNWSArea::UpdatePlayerAutomaps140372900..1403729ac. Flags low bits gate
// client enumeration; each same-area canonical creature updates its OWN map.
export async function updatePlayerAutomaps(area,p){
 if((area.flags&3)===0)return;
 const clients=await p.clients();
 for(const client of clients){
  const object=await p.clientObject(client);
  if(object&&(object.areaId>>>0)===(area.id>>>0)){
   const creature=await p.asCreature(object);
   if(creature)await p.update(creature,creature.id);
  }
 }
}
