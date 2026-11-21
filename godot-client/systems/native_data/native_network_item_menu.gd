extends RefCounted
# src/network_item_menu.js::prepareNetworkItemMenu, with Godot's synchronous
# active 2DA/TLK owners in place of the old Promise.all table/text reads.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const ItemRadial=preload("res://systems/native_data/item_radial.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
var inventory
var item_id: int
var actor_id: int
var area_id: int
var generation: int
var quickbar_token: int
var policy=ItemRadial.new()
var ready:=false

func _failure(reason: String) -> Dictionary:
	if is_instance_valid(inventory.text_owner) and inventory.text_owner.diagnostics.size()<100:
		inventory.text_owner.diagnostics.append({"code":"network.item-menu-presentation-failed","reason":reason,"itemId":item_id})
	return {"ok":false,"error":reason}

func _item() -> Dictionary:
	if not ready or not is_instance_valid(inventory):return {}
	if inventory.generation!=generation or inventory.area_id!=area_id or inventory.controlled_id!=actor_id:return {}
	if not inventory.ui.wanted or inventory.item_context.current_row().is_empty():return {}
	var object: Dictionary=inventory.objects.get(item_id,{})
	if int(object.get("objectType",0))!=6 or bool(object.get("replicationRemoved",false)):return {}
	var item: Variant=object.get("item")
	return item if item is Dictionary else {}

func _warning(message: String) -> void:
	if is_instance_valid(inventory.text_owner) and inventory.text_owner.diagnostics.size()<100:
		inventory.text_owner.diagnostics.append({"code":"network.item-menu-warning","reason":message,"itemId":item_id})

func prepare(owner,id: int,active_rules) -> Dictionary:
	inventory=owner;item_id=id;actor_id=int(owner.controlled_id);area_id=int(owner.area_id);generation=int(owner.generation)
	policy.rules=active_rules;policy.warning_report=_warning;policy.resolved_only=true
	var actor: Dictionary=inventory.objects.get(actor_id,{})
	var object: Dictionary=inventory.objects.get(item_id,{})
	var item: Dictionary=object.get("item",{}) if object.get("item") is Dictionary else {}
	if actor.is_empty() or item.is_empty() or int(object.get("objectType",0))!=6 or bool(object.get("replicationRemoved",false)):return {"ok":true}
	if not inventory.text_owner.tables.has("baseitems"):return _failure("Native base item rules are unavailable")
	var desktop=inventory.get_parent().desktop if inventory.get_parent()!=null else null
	quickbar_token=int(desktop.quickbar.quickbar_id) if desktop!=null and is_instance_valid(desktop.quickbar) else -1
	var refs: Dictionary={554:true,67530:true,53135:true,285:true,278:true,273:true}
	var properties: Array=item.get("properties",[])
	var first: Dictionary=properties[0] if not properties.is_empty() and properties[0] is Dictionary else {}
	if int(item.get("baseItem",-1))==75 and int(first.get("type",-1)) not in [70,55,80] and not actor.get("replicated",{}).get("stats",{}).get("classes",[]).is_empty() and not inventory.text_owner.tables.has("classes"):return _failure("Native class rules are unavailable")
	for index in properties.size():
		var property: Dictionary=properties[index] if properties[index] is Dictionary else {}
		if int(property.get("type",-1))!=15:continue
		if not inventory.text_owner.tables.has("iprp_spells") or not inventory.text_owner.tables.has("spells"):return _failure("Native item spell rules are unavailable")
		var property_table: Dictionary=inventory.text_owner.tables.get("iprp_spells",{})
		var spell_table: Dictionary=inventory.text_owner.tables.get("spells",{})
		var subtype:=int(property.get("subtype",-1))
		refs[int(SpellMetadata._integer(property_table,subtype,"Name").value)&0xffffffff]=true
		var spell_entry: Dictionary=SpellMetadata._integer(property_table,subtype,"SpellIndex")
		var spell_id:=int(spell_entry.value) if spell_entry.found else -1
		var spell: Variant=active_rules.casting_spell(spell_id)
		if spell is Dictionary:
			refs[int(SpellMetadata._integer(spell_table,spell_id,"Name").value)&0xffffffff]=true
			for child_id in policy.children(spell_id):
				var child: Variant=active_rules.casting_spell(int(child_id))
				if child is Dictionary:refs[int(SpellMetadata._integer(spell_table,int(child_id),"Name").value)&0xffffffff]=true
	for ref in refs:
		var reference:=int(ref)
		var actor_gender:=int(actor.get("appearance",{}).get("gender",0))
		var text=inventory.text_owner
		var table=(text.custom_female if actor_gender!=0 and text.custom_female.count>0 else text.custom) if reference&0x01000000 else (text.female if actor_gender!=0 and text.female.count>0 else text.base)
		# A missing TLK row resolves to empty text; malformed table data sets
		# TalkTable.failure and rejected the old Promise.all preparation.
		if not text.overrides.has(reference) and reference!=0xffffffff:
			text.fetch_reference(reference,actor_gender)
			if not str(table.failure).is_empty():return _failure(str(table.failure))
		for active_table in [text.base,text.female,text.custom,text.custom_female]:active_table.failure=""
		policy.resolved_text[reference]=text.resolve({"strRef":reference},actor_id)
		for active_table in [text.base,text.female,text.custom,text.custom_female]:
			if not str(active_table.failure).is_empty():return _failure(str(active_table.failure))
	ready=true
	return {"ok":true}

func _map(source: Array) -> Array:
	var result: Array=[]
	for entry in source:
		if not entry is Dictionary:continue
		var row: Dictionary=entry.duplicate()
		match str(row.get("action","")):
			"more":
				var start:=int(row.get("payload",0))
				row.kind="more"
				row.children=func():return {"title":"Item powers","entries":_map(policy.page(_item(),start)) if not _item().is_empty() else []}
			"variants":
				var index:=int(row.get("index",-1))
				row.kind="variants"
				row.children=func():return {"title":str(row.get("label","")),"entries":_map(policy.variants(_item(),index)) if not _item().is_empty() else []}
			"learn":
				row.kind="learn";row.action="item.learn"
			_:
				row.kind="use"
				var index:=int(row.get("index",0));var variant:=int(row.get("payload",0))>>16
				var packed: int=(index|(variant<<16))&0xffffffff
				if packed&0x80000000:packed-=0x100000000
				row.action="item.use"
				row.binding={"actorId":actor_id,"itemId":item_id,"packed":packed}
				row.quickbarBinding={"type":1,"itemId":item_id,"intParam":packed}
				row.networkQuickbarToken=quickbar_token
		result.append(row)
	return result

func entries() -> Array:
	var item: Dictionary=_item()
	if item.is_empty():return []
	return _map(policy.powers(item,false,_has_learning_class()))

func _has_learning_class() -> bool:
	var actor: Dictionary=inventory.objects.get(actor_id,{})
	for cls in actor.get("replicated",{}).get("stats",{}).get("classes",[]):
		var entry: Dictionary=SpellMetadata._integer(inventory.text_owner.tables.get("classes",{}),int(cls.get("id",-1)),"LearnScroll")
		if int(entry.value)!=0:return true
	return false
