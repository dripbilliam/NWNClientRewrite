import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native world destruction ${n} is unavailable`);return v|0;};

// EventHandler branches1404b3898..38cb /140509c32..9c62 /
//1404fb4ca..b50f. Only the waypoint tests destroyable; placeable inventory
// closure and loot transfer precede area removal and virtual destruction.
export async function receiveWorldDestroy(object,p){
 if(object.objectType===9){
  await p.closeInventory(object);await p.spawnBag(object);await p.removePlaceableArea(object);
 }else if(object.objectType===12){
  if(integer(object.nativeDestroyableF0,'destroyable')===0)return;
  await p.removeWaypointArea(object);
 }else if(object.objectType===14){
  if(await p.area(object))await p.removeAreaObject(await p.area(object),object.id);
  await p.setArea(object,null);
 }else throw new Error('Native world destruction event object type is unavailable');
 await p.destroy(object,1);
}

// Full CloseInventory1404b1fa0..2197. Enumeration bounds are captured once;
// clients and the second inventory owner are live reads. Missing live clients
// still consume the retained open count. Last observer queues OnClosed23.
export async function closePlaceableInventory(object,p){
 const clients=p.clients(),end=clients.length;
 for(let n=0;n<end;n++){
  const controlled=p.clientObject(clients[n]);if(!controlled)continue;
  if((p.inventory(clients[n]).ownerId>>>0)!==(object.id>>>0))continue;
  if(integer(object.nativeHasInventory4f8,'HasInventory')===0||integer(object.nativeField508,'open count')===0)continue;
  const caller=controlled.id>>>0,client=p.client(caller);
  if(client){
   if((p.inventory(client).ownerId>>>0)!==(object.id>>>0))continue;
   if(integer(p.inventory(client).open,'inventory open flag')!==0){
    await p.inventoryStatus(client,0,OBJECT_INVALID);await p.setInventoryOpen(client,0,0);
   }
   await p.clearInventory(client,OBJECT_INVALID,0);await p.guiMessage(client,OBJECT_INVALID,1);
  }
  if(integer(object.nativeField508,'open count')===1){
   await p.enqueue(caller,object.id,10,{type:23});await p.setAnimation(object,76);
  }
  object.nativeField508=(integer(object.nativeField508,'open count')-1)|0;
 }
}

// GetItemCount1404b3db0..3e3b: HasInventory is a nonzero gate, direct
// repository nodes only, optional droppable filter; no container recursion.
export function placeableItemCount(object,filter,p){
 filter=integer(filter,'item filter');if(integer(object.nativeHasInventory4f8,'HasInventory')===0)return 0;
 let count=0;const repository=p.repository(object);
 for(let node=repository?.head??null;node;node=node.next){const item=p.repositoryItem(repository,node);
  if(item&&(filter===0||integer(item.droppable,'droppable')!==0))count=(count+1)|0;
 }
 return count;
}
