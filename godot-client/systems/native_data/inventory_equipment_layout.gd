extends RefCounted
# CPanelInvEquip140854c30 and its fourteen-row table140e4ffa0. No server item
# definitions or coordinates are compiled here: active GUI/MDL provide them.
const SLOTS=[{"tag":"AmmoBox1","polygon":"INV_EQPOL_AMMO","empty":"inv_slot_sling","width":1,"height":1,"slot":4096},{"tag":"AmmoBox2","polygon":"INV_EQPOL_AMMO","empty":"inv_slot_bolts","width":1,"height":2,"slot":8192},{"tag":"AmmoBox3","polygon":"INV_EQPOL_AMMO","empty":"inv_slot_arrow","width":1,"height":2,"slot":2048},{"tag":"RingBox1","polygon":"INV_EQPOL_RING","empty":"inv_slot_ring","width":1,"height":1,"slot":128},{"tag":"RightWeaponBox","polygon":"INV_EQPOL_RHAND","empty":"inv_slot_right","width":2,"height":5,"slot":16},{"tag":"BeltBox","polygon":"INV_EQPOL_BELT","empty":"inv_slot_belt","width":2,"height":1,"slot":1024},{"tag":"HelmetBox","polygon":"INV_EQPOL_HELMET","empty":"inv_slot_helm","width":2,"height":2,"slot":1},{"tag":"ArmorBox","polygon":"INV_EQPOL_ARMOR","empty":"inv_slot_armor","width":2,"height":3,"slot":2},{"tag":"BootBox","polygon":"INV_EQPOL_BOOT","empty":"inv_slot_boots","width":2,"height":2,"slot":4},{"tag":"RingBox2","polygon":"INV_EQPOL_RING","empty":"inv_slot_ring","width":1,"height":1,"slot":256},{"tag":"LeftWeaponBox","polygon":"INV_EQPOL_LHAND","empty":"inv_slot_left","width":2,"height":4,"slot":32},{"tag":"GauntletBox","polygon":"INV_EQPOL_GUANT","empty":"inv_slot_gloves","width":2,"height":1,"slot":8},{"tag":"CloakBox","polygon":"INV_EQPOL_CLOAK","empty":"inv_slot_cloak","width":2,"height":3,"slot":64},{"tag":"AmuletBox","polygon":"INV_EQPOL_AMMO","empty":"inv_slot_amulet","width":1,"height":2,"slot":512}]
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
static func model(value: Dictionary) -> Dictionary: return Geometry.model(value)
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	var entries: Dictionary={}; var children: Array=root.get("Obj_ChildList",[])
	for child in children:
		var tag:=str(child.get("Obj_Tag","")).to_lower()
		if entries.has(tag): return {"error":"Ambiguous original equipment GUI tag"}
		entries[tag]=child
	var slots: Array=[]; var total:=Rect2(); var drawn:=false
	for definition in SLOTS:
		var tag:=str(definition.tag).to_lower()
		if not entries.has(tag): return {"error":"Missing original equipment GUI tag: "+tag}
		var entry: Dictionary=entries[tag]; var resource:=str(entry.get("Obj_ResRef","")).to_lower()
		if not models.has(resource): return {"error":"Missing original equipment model: "+resource}
		var data:=model(models[resource])
		if not str(data.error).is_empty(): return data
		if not data.drawn or not data.hooks.has("icon"): return {"error":"Missing original equipment box/icon hook: "+resource}
		var offset:=Vector2(float(entry.get("Obj_X",0)),-float(entry.get("Obj_Y",0)))*100.0
		if not offset.is_finite(): return {"error":"Invalid original equipment GUI offset"}
		var rect: Rect2=data.bounds; rect.position+=offset
		var slot: Dictionary=definition.duplicate(); slot.merge({"resource":resource,"rect":rect,"model_offset":offset,"icon":offset+data.hooks.icon,"layer":int(entry.get("Obj_Layer",0)),"label":definition.tag},true)
		slots.append(slot); total=total.merge(rect) if drawn else rect; drawn=true
	var labels: Dictionary={}
	for child in children:
		var parent:=str(child.get("Obj_Tag","")).to_lower()
		if not models.has(str(child.get("Obj_ResRef","")).to_lower()): continue
		for label in child.get("Obj_ChildList",[]):
			if int(label.get("Obj_Type",-1))!=5: continue
			var rect:=Rect2(Vector2(float(child.get("Obj_X",0))+float(label.get("Obj_Label_X",0)),-float(child.get("Obj_Y",0))-float(label.get("Obj_Label_Y",0)))*100.0,Vector2(float(label.get("Obj_Label_Width",0)),float(label.get("Obj_Label_Height",0)))*100.0)
			labels[str(label.get("Obj_Tag","")).to_lower()]={"rect":rect,"caption":label.get("Obj_Caption",{}),"parent":parent}
	return {"error":"","slots":slots,"bounds":total,"labels":labels}
