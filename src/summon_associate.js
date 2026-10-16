import {OBJECT_INVALID} from './game_object_array.js';

// AddAssociate1403d0410, native type4 path. Other associate categories have
// separate henchman/charm/domination owners and must not use this path.
export async function addSummonedAssociate(actor,id,p){
  id>>>=0;if(id===actor.id)return;
  p.module();let previous=OBJECT_INVALID;
  if(actor.associateIds)for(let n=0;n<actor.associateIds.length;n++){
    const candidate=p.creature(actor.associateIds[n]);
    if(candidate&&(candidate.associateType&65535)===4){previous=actor.associateIds[n];break;}
  }
  const old=p.creature(previous);if(old)await p.unsummon(old);
  const target=p.creature(id);if(!target)return;
  const rate=target.nativeMovementRate|0;
  if(((rate-2)>>>0)<3||rate===7)await p.setMovementRate(target,0);
  await p.listenPatterns(target);await p.setType(target,4);await p.setMaster(target,actor.id);
  actor.associateIds??=[];if(!actor.associateIds.includes(id))actor.associateIds.push(id);
  if(p.faction(actor.factionId))await p.addFactionMember(p.faction(actor.factionId),id,0);
}

// UnsummonMyself1403daee0. Actual destruction is deferred through event11;
// this owner never removes the associate ID immediately.
export async function unsummonCreature(actor,p){
  const message=p.message();await p.clearActions(actor);
  const area=p.area(actor);
  if(area){
    let visual=99,show=true;
    const master=p.creature(actor.masterId);
    if(master){
      for(let n=0;n<master.effects.length;n++){
        const effect=master.effects[n];
        if(effect.type!==6||effect.objectIds[1]!==actor.id)continue;
        if(effect.integers[2]===1){visual=effect.integers[3]|0;if(visual<0)show=false;}
        break;
      }
    }
    if(show)await p.visual(area,visual,p.position(actor),p.orientation(actor));
    if((actor.nativeField540|0)>0){
      const client=p.client(actor.masterId),sheet=client?p.sheet(client):null;
      if(sheet){await p.setDisplayed(sheet,OBJECT_INVALID);if(message)await p.notPermitted(message,client,actor.id);}
    }
  }
  const master=p.creature(actor.masterId);if(master)await p.feedback(master,155,{objects:[actor.id]});
  await p.enqueue(0,0,actor.id,actor.id,11,null);
}

// RemoveAssociate1403d6e10. The 7/8 possession branch deliberately leaves
// the master's list/GUI state alone; ordinary branches remove only one ID.
export async function removeAssociate(actor,id,p){
  id>>>=0;const message=p.message(),target=p.creature(id);if(!target)return;
  const type=target.associateType&65535;
  if(((type-7)&65535)<2){
    await p.setType(target,0);
    if(target.id===OBJECT_INVALID)await p.warning('SetMasterId: cannot be own master');else target.masterId=OBJECT_INVALID;
    return;
  }
  if(((type-2)&65535)<3){
    if(p.faction(actor.factionId))await p.addFactionMember(p.defaultFaction(),id,0);
    if((target.associateType&65535)===3)actor.nativeField914=0;
  }else if(type===5){
    const faction=p.faction(target.nativeOriginalFactionCC);if(faction)await p.addFactionMember(faction,id,0);
    target.nativeOriginalFactionCC=-1;await p.feedback(actor,159,{objects:[id]});
  }else if(type!==6){const faction=p.faction(target.originalFactionId);if(faction)await p.addFactionMember(faction,id,0);}
  if(actor.associateIds){const index=actor.associateIds.indexOf(id);if(index>=0)actor.associateIds.splice(index,1);}
  await p.setType(target,0);await p.setMaster(target,OBJECT_INVALID);
  const client=p.client(actor.id);
  if((target.nativeField540|0)>0){
    if(!client)return;
    const sheet=p.sheet(client);if(sheet){await p.setDisplayed(sheet,OBJECT_INVALID);if(message)await p.notPermitted(message,client,id);}
  }
  if(client&&p.inventoryOpen(client)!==0&&p.inventoryOwner(client)===target.id){
    await p.inventoryStatus(message,client,0,target.id);await p.setInventoryOpen(client,0,0);
  }
}
