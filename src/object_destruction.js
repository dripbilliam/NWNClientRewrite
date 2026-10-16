import {OBJECT_INVALID} from './game_object_array.js';

// CItemRepository::~140463120 and CNWSInventory::~140462880. Lookups are
// repeated after each deletion, so duplicate/stale IDs never create objects.
export async function destroyRepository(repo,p){
  while(repo?.head){const node=repo.head,id=node.id;repo.removeNode(node);const object=p.object(id);if(object)await p.destroy(object,1);}
}
export async function destroyEquipment(equipment,p){
  for(let n=0;n<18;n++){const item=p.item(equipment.ids[n]);if(item){await p.destroy(item,1);equipment.ids[n]=OBJECT_INVALID;}}
}

// Observable ownership phases of CNWSCreature::~14037b440. Memory-only
// members are released by local stage providers; world IDs use real owners.
export async function destroyCreature(actor,p){
  if(actor.masterId!==OBJECT_INVALID){const master=p.creature(actor.masterId);if(master)await p.removeAssociate(master,actor.id);}
  if(actor.chairId!==OBJECT_INVALID){const chair=p.placeable(actor.chairId);if(chair)chair.nativeOccupant36c=OBJECT_INVALID;actor.chairId=OBJECT_INVALID;}
  await p.releaseLocal(actor,'940');
  if(p.area(actor))await p.removeCreatureArea(actor,0);
  await p.releaseLocal(actor,'stats');await p.removeAI(actor);
  if(p.module())await p.removeTag(actor);
  await p.releaseLocal(actor,'path');await p.releaseLocal(actor,'round');
  if(p.repository(actor))await p.destroyRepository(p.repository(actor));
  await p.releaseLocal(actor,'repository');
  if(p.equipment(actor))await p.destroyEquipment(p.equipment(actor));
  await p.releaseLocal(actor,'equipment');await p.releaseLocal(actor,'creatureLists');
  await p.clearAutoMap(actor);await p.releaseLocal(actor,'creatureTail');
  await p.destroyBase(actor);
}

// CNWSItem::~1404631c0. No unequip/property-removal/acquire events belong to
// this destructor. Recursive container destruction precedes world area removal.
export async function destroyItem(item,p){
  if(p.module())await p.removeTag(item);
  if(p.repository(item))await p.destroyRepository(p.repository(item));
  await p.releaseLocal(item,'itemProperties');
  if(p.area(item))await p.removeItemArea(item);
  await p.removeAI(item);await p.releaseLocal(item,'itemLocal');
  await p.destroyBase(item);await p.releaseLocal(item,'itemTail');
}

// CNWSPlaceable::~1404afd70. Inventory children die BEFORE collision/spatial
// removal and AI/tag cleanup. There is no OnDeath or OnRemoveEffect callback.
export async function destroyPlaceable(object,p){
 if(p.repository(object))await p.destroyRepository(p.repository(object));
 await p.releaseLocal(object,'repository');
 if(p.area(object))await p.removePlaceableArea(object);
 await p.removeAI(object);if(p.module())await p.removeTag(object);
 await p.releaseLocal(object,'placeableLocal');await p.destroyBase(object);
}

// CNWSWaypoint::~140508dd0. No AI removal: its constructor did not register
// with AIMaster. Its two localized strings are released before the base owner.
export async function destroyWaypoint(object,p){
 if(p.area(object))await p.removeWaypointArea(object);
 if(p.module())await p.removeTag(object);
 await p.releaseLocal(object,'waypointLocal');await p.destroyBase(object);
}

// CNWSStore::~1404f9c20. Five physical repositories first; store-client records
// are traversed backwards through the LIVE array. A found client closes its
// store GUI; an absent client frees/nulls that record. Area clearing keeps XYZ.
export async function destroyStore(object,p){
 const repositories=p.storeRepositories(object);
 if(!Array.isArray(repositories)||repositories.length!==5)throw new Error('Native store destruction repositories are unavailable');
 for(const repository of repositories)if(repository)await p.destroyRepository(repository);
 if(!Array.isArray(object.nativeStoreClients350))throw new Error('Native store destruction client records are unavailable');
 for(let n=object.nativeStoreClients350.length-1;n>=0;n--){
  const record=object.nativeStoreClients350[n];if(!record)continue;
  const client=await p.client(record.playerId);
  if(client)await p.closeStore(client,1);
  else{await p.releaseStoreClient(record);object.nativeStoreClients350[n]=null;}
 }
 if(p.area(object)){
  if(p.area(object))await p.removeAreaObject(p.area(object),object.id);
  await p.setArea(object,null);
 }
 await p.removeAI(object);if(p.module())await p.removeTag(object);
 await p.releaseLocal(object,'storeLocal');await p.destroyBase(object);
}

// CNWSObject::~14048bf10. Stored effects are freed, NOT OnRemoveEffect'ed.
// Registry removal precedes effect/action destruction. ClearAllActions would
// incorrectly respect cancellation vetoes and run action-specific cleanup.
export async function destroyBaseObject(object,p){
  await p.releaseLocal(object,'objectHead');
  if(p.area(object)){await p.removeAreaObject(p.area(object),object.id);object.areaId=OBJECT_INVALID;}
  await p.releaseLocal(object,'listenStrings');await p.removeRegistry(object);
  const effects=object.effects??[];for(let n=effects.length-1;n>=0;n--)if(effects[n])await p.disposeEffect(effects[n]);
  object.effects=[];
  const list=object.objectActionState?.list;
  while(list?.head)await p.disposeAction(list.shift());
  await p.releaseLocal(object,'objectTail');
}
