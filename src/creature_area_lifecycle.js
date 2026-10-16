// AddObjectToArea14035bc80..14035bd23. Repeated virtual casts are
// intentional. Door selector5 is OnHeartbeat's CExoString, not trap data.
export function activateOnFirstClient(object,p){
  if(p.asCreature(object)||p.asAreaEffect(object)||p.asTrigger(object))return true;
  if(p.asDoor(object))return(p.scriptName(p.asDoor(object),5).length>>>0)>0;
  if(p.asPlaceable(object))return p.asPlaceable(object).nativeStatic5a0===0;
  return false;
}

// Placeable Load1404b4f07..1404b4f68. Area LoadPlaceables140361b4f sets
// override5a4 to0 first. A missing Static falls back to !Useable;
// override exactly1 forces static0. BYTEasBOOL fields narrow first.
export function importPlaceableStatic(object,data,override=0){
  for(const name of ['Useable','Static'])if(Object.hasOwn(data,name)&&!Number.isInteger(data[name]))throw new Error(`Native placeable BYTE ${name} is unavailable`);
  const usable=Number(((data.Useable??0)&255)!==0),hasStatic=Object.hasOwn(data,'Static'),value=Number(((data.Static??0)&255)!==0);
  object.nativeUseable264=usable;object.usable=usable!==0;object.nativeStaticLoadOverride5a4=override|0;
  object.nativeStatic5a0=object.nativeStaticLoadOverride5a4===1?0:hasStatic?value:Number(usable!==1);
}

// IncrementPlayersInArea14035f2c0 / DecrementPlayersInArea14035ce70.
// Native asymmetry is intentional: only noncreatures demote on final exit.
export async function incrementAreaPlayers(area,p){
  if(area.nativePlayerCount150===0)for(let n=0;n<p.ids(area).length;n++){
    const object=p.object(p.ids(area)[n]);
    if(object&&object.objectType>4&&object.nativeAILevel7c===0&&await p.activateOnEntry(object))await p.setAILevel(object,1);
  }
  area.nativePlayerCount150=(area.nativePlayerCount150+1)|0;
}
export async function decrementAreaPlayers(area,p){
  area.nativePlayerCount150=(area.nativePlayerCount150-1)|0;
  if(area.nativePlayerCount150===0)for(let n=0;n<p.ids(area).length;n++){
    const object=p.object(p.ids(area)[n]);
    if(object&&object.objectType>4&&!p.asCreature(object)&&object.nativeAILevel7c===1)await p.setAILevel(object,0);
  }
}

// AddObjectToArea14035ba90. Spatial membership/canonical area are distinct.
export async function addAreaObject(area,id,flag,p){
  id>>>=0;const object=p.object(id);if(!object)return 0;
  if(p.ids(area).includes(id))await p.removeObject(area,id);
  await p.insertSpatial(area,id);
  const current=p.object(id),creature=current?p.asCreature(current):null;
  if(creature){
    if(p.client(id))await incrementAreaPlayers(area,p);
    if(flag===1&&p.exitSuppressed(p.asCreature(current))===0)
      await p.enqueue(0,0,id,area.id,10,{type:12,integers:[],objectIds:[]});
  }
  return 1;
}

export async function removeAreaObject(area,id,p){
  id>>>=0;await p.removeSpatial(area,id);
  if(p.client(id))await decrementAreaPlayers(area,p);
  const creature=p.creature(id);
  if(creature&&p.exitSuppressed(creature)===0&&await p.dead(creature)===0)
    await p.enqueue(0,0,id,area.id,10,{type:13,integers:[],objectIds:[]});
  return 1;
}

// Creature RemoveFromArea14039e6b0. The old area remains visible until after
// perception/AoE callbacks; world XYZ is reset even when no old area exists.
export async function removeCreatureFromArea(actor,skipPerception,p){
  if(p.area(actor))await p.removeObject(p.area(actor),actor.id);
  if(skipPerception===0){
    await p.clearVisible(actor);
    if(p.area(actor)){
      const area=p.area(actor);
      for(let n=0;n<p.ids(area).length;n++){
        const viewer=p.creature(p.ids(area)[n]);if(!viewer)continue;
        const node=p.visibilityNode(viewer,actor.id);if(!node)continue;
        if(node.flags&2)await p.enqueue(0,0,actor.id,viewer.id,10,{type:1,integers:[1],objectIds:[actor.id]});
        if(node.flags&1)await p.enqueue(0,0,actor.id,viewer.id,10,{type:1,integers:[3],objectIds:[actor.id]});
        await p.removeVisible(viewer,actor.id);
      }
      if(p.statsPC(actor)!==0&&p.areaService(area))await p.playerLeft(p.areaService(area));
    }
  }
  for(let n=0;n<p.followingIds(actor).length;n++){
    const object=p.object(p.followingIds(actor)[n]);
    if(object&&p.asAreaEffect(object))await p.removeAreaEffect(p.asAreaEffect(object));
  }
  await p.setArea(actor,null);await p.position(actor,[0,0,0]);
  if(p.barter(actor))await p.cleanBarter(p.barter(actor));
}

// Creature AddToArea140380470. The client-area handshake and auto-map owners
// remain supplied boundaries, rather than silently treating PCs as NPCs.
export async function addCreatureToArea(actor,area,x,y,z,force,flag,p){
  const point=[x,y,z].map(Math.fround),client=p.client(actor.id);
  if(p.area(actor)!==area||force===1)await p.removeCreature(actor,0);
  for(let n=0;n<p.followingIds(actor).length;n++){
    const object=p.object(p.followingIds(actor)[n]);
    if(object&&p.asAreaEffect(object))await p.addAreaEffect(p.asAreaEffect(object),area,...point,1);
  }
  if(!area)return;
  for(let n=0;n<p.ids(area).length;n++){
    const other=p.creature(p.ids(area)[n]);
    if(other&&other.id!==actor.id&&await p.dead(other)===0)await p.dying(other);
  }
  if(p.area(actor)!==area&&p.autoMapEnabled(actor)!==0)await p.reconcileMap(actor,area.id);
  if(p.area(actor)!==area&&area.id!==actor.nativeLastClientArea4f4&&client){
    const message=p.message();if(message){
      actor.nativePendingAreaPosition4f8=[...point];actor.nativeLastClientArea4f4=area.id;actor.nativeField504=0;
      if(p.moduleInfoSucceeded(client)===0)await p.warning('AddToArea: ClientArea before module info');
      await p.clientArea(message,client,area,point,p.orientation(actor),0);
      await p.setArea(actor,null);await p.position(actor,point);return;
    }
  }
  await p.position(actor,point);
  if(p.area(actor)!==area||force===1)await p.addObject(area,actor.id,flag);
  await p.setArea(actor,area);
  if(actor.nativeAILevel7c===0&&area.nativePlayerCount150>=1&&p.hasAI())await p.setAILevel(actor,1);
  if(actor.nativeAILevel7c===1&&area.nativePlayerCount150===0&&p.hasAI())await p.setAILevel(actor,0);
  if(client)await p.updateMap(actor,actor.id);
}
