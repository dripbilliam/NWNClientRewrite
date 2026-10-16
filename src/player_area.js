// These owners consume decoded local state. Packet serialization/loading-screen
// presentation and lower area/automap owners remain separate boundaries.

// AIActionAreaWait1403ac840..1403acf89, native internal action60.
// It checks player ownership and area readiness, without dead/dying guards.
export async function executeAreaWait(o,_node,p){
  if(o.nativeField89c!==0||((o.associateType&65535)===3&&await p.controlled(o.id)!==0))return await p.area(o)?2:1;
  return 3;
}

// HandlePlayerToServerAreaMessage1404435a0..140443803. Area subtype3 is
// the load acknowledgement. First-entry lists are sent before placement;
// results combine bitwise, and pause state is sampled after placement.
export async function receiveAreaReady(client,subtype,p){
  if(await p.overflow()!==0||(subtype&255)!==3)return 0;
  let result=1;
  if(client.nativeLoadState50===1){
    client.nativeLoadState50=2;
    if((await p.serverMode()&65535)===2&&await p.clientObject(client)){
      const a=await p.addPlayer(p.addAudience,client),b=await p.addPlayer(p.otherAudience,client),c=await p.allPlayers(client);
      result=(a&1&b&c)>>>0;
    }
  }
  if((await p.serverMode()&65535)===2&&await p.clientObject(client)){
    await p.movePlayer(client);result=(result&await p.updateParty(p.otherAudience))>>>0;
    if(await p.pauseState(1)===1)await p.sendPause(1,1);
    if(await p.pauseState(2)===1)await p.sendPause(2,1);
  }
  return result;
}

// CServerExoAppInternal::MovePlayerToArea140568520..140568720.
// Failed safe search (exact0) falls back to the copied pending destination;
// nonzero uses the lower owner's output. Associates/visibility still run when
// the pending area lookup fails. No new IDs are allocated by this owner.
export async function movePlayerToArea(client,p){
  if(!await p.clientObject(client))return;
  const actor=p.asCreature(await p.clientObject(client)),point=actor.nativePendingAreaPosition4f8.slice(),areaId=actor.nativeLastClientArea4f4,
    object=await p.lookup(p.moduleId()),module=object?p.asModule(object):null,area=await p.moduleArea(module,areaId);
  if(!actor.nativePathInfo)throw new Error('Native player placement path information is unavailable');
  actor.nativePathInfo.raw.setUint32(0x24,actor.id,true);
  if(area){
    const out={point:[0,0,0]};if(await p.safeLocation(area,point,20,actor.nativePathInfo,1,out)===0)out.point=point.slice();
    await p.subareas(actor,out.point,area.id);await p.addToArea(actor,area,...out.point,0,1);
  }
  await p.realizeAssociates(actor);await p.updateVisible(actor);
  if(actor.nativeField89c!==0||await p.possessedFamiliar(actor)!==0)await p.updateAutoMap(actor,actor.id);
}

// RealizeAssociateList14039d820..14039db3b. One zeroed safe-location output
// survives the whole physical list; the native ignores each search result.
// A failed search can therefore retain the previous associate's output.
export async function realizeAssociates(actor,p){
  const out={point:[0,0,0]};if(!p.associates(actor))return;
  for(let i=0;i<p.associates(actor).length;i++){
    const o=await p.creature(p.associates(actor)[i]);
    if(!o){await p.warning('Could not find Associate.');continue;}
    let area=await p.moduleArea(await p.module(),o.nativeLastClientArea4f4),point;
    if(area)point=o.nativePendingAreaPosition4f8.slice();
    else{
      area=await p.area(actor);point=p.position(actor).slice();
      if(!area){area=await p.moduleArea(await p.module(),actor.nativeLastClientArea4f4);point=actor.nativePendingAreaPosition4f8.slice();}
    }
    if(!area)await p.warning('pArea');
    await p.safeLocation(area,point,20,o.nativePathInfo,1,out);
    await p.addToArea(o,area,...out.point,0,1);await p.realizeAssociates(o);await p.updateVisible(o);
    if(o.nativeField89c!==0||await p.possessedFamiliar(o)!==0)await p.updateAutoMap(o,o.id);
    o.nativeField58c=0;await p.clearActions(o);o.nativeField54c=0;o.nativeField550=1;
  }
}
