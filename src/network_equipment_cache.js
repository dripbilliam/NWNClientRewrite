import {GAME_OBJECT_TYPE,OBJECT_INVALID} from './game_object_array.js';

// Original800dd0/80a460 private creature slots. These are mask-valued DWORDs
// in BOTH GE appearance and GI equipment records, not UI list ordinals.
export const CLIENT_EQUIPMENT_SLOTS=Object.freeze(Array.from({length:18},(_,i)=>2**i));
export const isClientEquipmentSlot=slot=>Number.isInteger(slot)&&CLIENT_EQUIPMENT_SLOTS.includes(slot);
export const clientEquipmentItem=(actor,slot)=>isClientEquipmentSlot(slot)?actor?.clientEquipmentSlots?.[slot]??OBJECT_INVALID:OBJECT_INVALID;
const liveItem=item=>item?.objectType===GAME_OBJECT_TYPE.item&&!item.replicationRemoved;

// Original7fff10 ->83ef40/80a770. The private equipment cache and attachment
// owner are distinct from item24c's last GI widget slot and repository coords.
export function setClientEquipmentSlot(actor,slot,item,lookup){
 if(actor?.objectType!==GAME_OBJECT_TYPE.creature||actor.replicationRemoved||!isClientEquipmentSlot(slot)||item!==null&&!liveItem(item))return false;
 const next=item?.id??OBJECT_INVALID,previous=clientEquipmentItem(actor,slot);
 if(item)item.equipmentOwnerId=actor.id;
 const other=slot===16?32:slot===32?16:0,sharedNew=other&&clientEquipmentItem(actor,other)!==OBJECT_INVALID&&clientEquipmentItem(actor,other)===next;
 if(previous!==next&&!sharedNew){const old=lookup(previous);if(liveItem(old)&&old.equipmentOwnerId===actor.id)old.equipmentOwnerId=null;}
 actor.clientEquipmentSlots??={};actor.clientEquipmentSlots[slot]=next;return true;
}

// Received12/1 and12/7 reconcile native private equipment, even with the GUI
// closed. No proxies, ownership predictions or repository coordinates arise
// from acknowledgments. Alternate GUI ownership is not bound by this adapter.
export function applyInventoryEquipmentResult(world,message){
 if(message.kind!=='inventory-result'||message.alternate||!message.success||!['equip','unequip'].includes(message.operation))return false;
 const originalActor=world.registry.get(world.localObjectId),originalItem=world.registry.get(message.itemId);
 if(originalActor?.objectType!==GAME_OBJECT_TYPE.creature||originalActor.replicationRemoved||!liveItem(originalItem))return false;
 // Stage only existing objects touched by this received result. Nothing is
 // published until all slot/identity/ownership checks have succeeded.
 const staged=new Map(),lookup=id=>{const original=world.registry.get(id);if(!original)return null;if(!staged.has(id))staged.set(id,structuredClone(original));return staged.get(id);};
 const actor=lookup(originalActor.id),item=lookup(originalItem.id);
 const cached=item.inventoryEquipmentSlot??-1;
 let view=null;
 const commit=()=>{for(const [id,value]of staged)Object.assign(world.registry.get(id),value);if(view)world.inventories.set('I',view);return true;};
 const syncAppearance=(slot,value)=>{
  const list=actor.appearance?.equipment;if(!list)return;
  const index=list.findIndex(entry=>entry.slot===slot);
  if(value){if(index>=0)list[index]={...list[index],id:value.id,item:value.item};else list.push({action:'A',slot,id:value.id,item:value.item});}
  else if(index>=0&&list[index].id===item.id)list.splice(index,1);
 };
 if(message.operation==='equip'){
  if(!isClientEquipmentSlot(message.slot)||message.slot===1||clientEquipmentItem(actor,cached)===item.id)return false;
  // A stale/foreign canonical item cannot be attached by an unrelated ACK.
  if(item.equipmentOwnerId!=null&&item.equipmentOwnerId!==actor.id||item.inventoryLocation?.ownerId!=null&&item.inventoryLocation.ownerId!==actor.id)return false;
  if(!setClientEquipmentSlot(actor,message.slot,item,lookup))return false;
  syncAppearance(message.slot,item);return commit();
 }
 if(!isClientEquipmentSlot(cached)||clientEquipmentItem(actor,cached)!==item.id||item.equipmentOwnerId!=null&&item.equipmentOwnerId!==actor.id)return false;
 // The original helmet exception clears its GUI cachedslot while leaving
 // attachment/visual ownership to the separate appearance update.
 if(cached!==1){setClientEquipmentSlot(actor,cached,null,lookup);syncAppearance(cached,null);}
 if(world.inventories.has('I')){view=structuredClone(world.inventories.get('I'));view.entries=view.entries.filter(entry=>entry.id!==item.id||entry.slot!==cached);}
 item.inventoryEquipmentSlot=-1;
 if(item.inventoryLocation?.channel==='I'&&item.inventoryLocation.ownerId===actor.id&&item.inventoryLocation.slot===cached)item.inventoryLocationStatus='last-disclosed';
 return commit();
}
