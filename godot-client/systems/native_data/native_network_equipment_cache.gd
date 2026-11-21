extends RefCounted
# src/network_equipment_cache.js. Private creature slot masks are separate
# from a canonical item's last inventory widget slot and repository position.
const OBJECT_INVALID:=0x7f000000
const CLIENT_EQUIPMENT_SLOTS=[1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072]
static func is_client_equipment_slot(slot: Variant) -> bool:
	return slot is int and slot in CLIENT_EQUIPMENT_SLOTS
static func client_equipment_item(actor: Variant,slot: Variant) -> int:
	if not is_client_equipment_slot(slot) or not actor is Dictionary:return OBJECT_INVALID
	var slots: Variant=actor.get("clientEquipmentSlots")
	return int(slots.get(str(slot),slots.get(slot,OBJECT_INVALID))) if slots is Dictionary else OBJECT_INVALID
static func live_item(item: Variant) -> bool:
	return item is Dictionary and int(item.get("objectType",0))==6 and not bool(item.get("replicationRemoved",false))

static func set_client_equipment_slot(actor: Variant,slot: Variant,item: Variant,lookup: Callable) -> bool:
	if not actor is Dictionary or int(actor.get("objectType",0))!=5 or bool(actor.get("replicationRemoved",false)) or not is_client_equipment_slot(slot) or item!=null and not live_item(item):return false
	var next:=int(item.id) if item is Dictionary else OBJECT_INVALID
	var previous:=client_equipment_item(actor,slot)
	if item is Dictionary:item.equipmentOwnerId=actor.id
	var other:=32 if slot==16 else 16 if slot==32 else 0
	var shared_new:=other!=0 and client_equipment_item(actor,other)!=OBJECT_INVALID and client_equipment_item(actor,other)==next
	if previous!=next and not shared_new:
		var old: Variant=lookup.call(previous)
		if live_item(old) and old.get("equipmentOwnerId")==actor.id:old.equipmentOwnerId=null
	var slots: Dictionary=actor.get("clientEquipmentSlots",{}) if actor.get("clientEquipmentSlots") is Dictionary else {}
	slots[str(slot)]=next;actor.clientEquipmentSlots=slots
	return true

static func _sync_appearance(actor: Dictionary,slot: int,value: Variant,item_id: int) -> void:
	var appearance: Variant=actor.get("appearance")
	if not appearance is Dictionary or not appearance.get("equipment") is Array:return
	var list: Array=appearance.equipment;var found:=-1
	for index in list.size():
		if int(list[index].get("slot",-1))==slot:found=index;break
	if value is Dictionary:
		if found>=0:
			var entry: Dictionary=list[found].duplicate();entry.id=value.id;entry.item=value.get("item");list[found]=entry
		else:list.append({"action":"A","slot":slot,"id":value.id,"item":value.get("item")})
	elif found>=0 and int(list[found].get("id",-1))==item_id:list.remove_at(found)
	appearance.equipment=list;actor.appearance=appearance

static func apply_inventory_equipment_result(registry: Dictionary,inventories: Dictionary,local_object_id: int,message: Dictionary) -> Dictionary:
	if str(message.get("kind",""))!="inventory-result" or bool(message.get("alternate",false)) or not bool(message.get("success",false)) or str(message.get("operation","")) not in ["equip","unequip"]:return {"applied":false}
	var original_actor: Variant=registry.get(local_object_id)
	var original_item: Variant=registry.get(int(message.get("itemId",-1)))
	if not original_actor is Dictionary or int(original_actor.get("objectType",0))!=5 or bool(original_actor.get("replicationRemoved",false)) or not live_item(original_item):return {"applied":false}
	var staged: Dictionary={}
	var lookup:=func(id):
		if not registry.has(id):return null
		if not staged.has(id):staged[id]=registry[id].duplicate(true)
		return staged[id]
	var actor: Dictionary=lookup.call(int(original_actor.id))
	var item: Dictionary=lookup.call(int(original_item.id))
	var cached: Variant=item.get("inventoryEquipmentSlot",-1)
	var operation:=str(message.operation)
	var view: Variant=null
	if operation=="equip":
		var slot: Variant=message.get("slot")
		if not is_client_equipment_slot(slot) or slot==1 or client_equipment_item(actor,cached)==int(item.id):return {"applied":false}
		var location: Variant=item.get("inventoryLocation")
		if item.get("equipmentOwnerId")!=null and item.equipmentOwnerId!=actor.id or location is Dictionary and location.get("ownerId")!=null and location.ownerId!=actor.id:return {"applied":false}
		if not set_client_equipment_slot(actor,slot,item,lookup):return {"applied":false}
		_sync_appearance(actor,int(slot),item,int(item.id))
	else:
		if not is_client_equipment_slot(cached) or client_equipment_item(actor,cached)!=int(item.id) or item.get("equipmentOwnerId")!=null and item.equipmentOwnerId!=actor.id:return {"applied":false}
		if cached!=1:
			set_client_equipment_slot(actor,cached,null,lookup)
			_sync_appearance(actor,int(cached),null,int(item.id))
		if inventories.has("I"):
			view=inventories["I"].duplicate(true)
			var entries: Array=[]
			for entry in view.get("entries",[]):
				if int(entry.get("id",-1))!=int(item.id) or int(entry.get("slot",-1))!=int(cached):entries.append(entry)
			view.entries=entries
		item.inventoryEquipmentSlot=-1
		var location: Variant=item.get("inventoryLocation")
		if location is Dictionary and str(location.get("channel",""))=="I" and location.get("ownerId")==actor.id and location.get("slot")==cached:item.inventoryLocationStatus="last-disclosed"
	return {"applied":true,"staged":staged,"view":view}
