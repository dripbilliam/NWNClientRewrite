extends RefCounted
# Direct translation of network_quickbar_items.js and item_quickbar.js.
# The owner supplies the current replicated world and active server tables.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const SpellMetadata=preload("res://systems/native_data/spell_metadata.gd")
const INVALID:=2130706432
var world_state
var tables: Dictionary={}
var failure: String=""
var feedback_code: int=-1
var presentation: Dictionary={}

func configure(source,active_tables: Dictionary) -> void:
	world_state=source; tables=active_tables

func _integer(value: Variant,label: String) -> int:
	if not value is int and not (value is float and is_finite(value) and value==floor(value)):
		if failure.is_empty():failure="Native item quickbar "+label+" is unavailable"
		return 0
	return int(value)

static func _row(source: Dictionary,name: String,index: int) -> Dictionary:
	var rows: Array=source.get(name,{}).get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() and rows[index] is Dictionary else {}

static func _field(row: Dictionary,name: String) -> int:
	return Rules.number(Rules.cell(row,name),0)

func controlled() -> Dictionary:
	return world_state.registry.get(int(world_state.local_object_id),{}) if world_state!=null else {}

func controlled_id() -> int:
	return int(world_state.local_object_id) if world_state!=null else INVALID

func item(id: int) -> Dictionary:
	if world_state==null:return {}
	var object: Dictionary=world_state.registry.get(id,{})
	var value: Variant=object.get("item")
	if int(object.get("objectType",0))!=6 or not value is Dictionary or bool(object.get("replicationRemoved",false)):return {}
	var result: Dictionary=value.duplicate()
	result.id=int(object.get("id",id)); result.canonical=object
	result.identified=int(value.get("identified",0))
	result.stackSize=value.get("stackSize") if value.get("stackSize")!=null else value.get("field454")
	var properties: Variant=value.get("properties")
	var active_properties: Array=[]
	if properties is Array:
		for property in properties:
			active_properties.append(property.duplicate() if property is Dictionary else {})
	result.activeProperties=active_properties
	return result

func base_info(value: Dictionary) -> Dictionary:
	var base: Dictionary=_row(tables,"baseitems",int(value.get("baseItem",-1)))
	if base.is_empty():return {}
	return {"equipableSlots":_field(base,"EquipableSlots")&0xffffffff,"container":_field(base,"Container"),"stacking":_field(base,"Stacking"),"qbBehaviour":_field(base,"QBBehaviour"),"weaponType":_field(base,"WeaponType"),"weaponSize":_field(base,"WeaponSize"),"weaponWield":_field(base,"WeaponWield")}

func size_category(actor: Dictionary) -> Dictionary:
	var appearance: Dictionary=actor.get("appearance",{})
	var row: Dictionary=_row(tables,"appearance",int(appearance.get("appearance",-1)))
	var cell: Variant=Rules.cell(row,"SIZECATEGORY")
	return {"status":0 if row.is_empty() or str(cell) in ["","****"] else 1,"value":Rules.number(cell,0)}

func relative_weapon_size(actor: Dictionary,value: Dictionary) -> int:
	if int(value.get("baseItem",-1))==111:return 0
	var size:=_integer(size_category(actor).value,"appearance size")
	var base:=base_info(value)
	if base.is_empty():failure="Native client relative weapon size dereferences missing base storage";return 0
	return ((_integer(base.weaponSize,"weapon size")&255)-size)

func wield(actor: Dictionary,value: Dictionary) -> int:
	var base:=base_info(value)
	if base.is_empty():return 0
	var kind:=int(value.get("baseItem",-1))
	if kind==57:
		var size:=size_category(actor)
		return 0 if int(size.status)==0 else int(_integer(size.value,"appearance size")>=3)
	if kind in [14,15,56]:return 1
	if (_integer(base.weaponType,"weapon type")&255)==0:return 0
	var relative:=relative_weapon_size(actor,value)
	if (_integer(base.weaponWield,"weapon wield")&255)!=0:return 0 if kind in [6,7,8,11] else 2
	return int(((relative+2)&0xffffffff)<=2)

func _property(value: Dictionary,index: int) -> Dictionary:
	var values: Variant=value.get("activeProperties",[])
	return values[index] if values is Array and index>=0 and index<values.size() and values[index] is Dictionary else {}

func _cached_uses(value: Dictionary,index: int) -> int:
	var values: Variant=value.get("propertyUses") if value.get("propertyUses")!=null else value.get("field351",[])
	var selected: Variant=null
	if values is Array and index>=0 and index<values.size():selected=values[index]
	elif values is Dictionary:selected=values.get(index,values.get(str(index)))
	return int(selected) if selected!=null else 0

func property_spell(value: Dictionary,index: int) -> int:
	var property:=_property(value,index)
	if int(property.get("type",-1))!=15:return -1
	var row:=_row(tables,"iprp_spells",int(property.get("subtype",-1)))
	return _field(row,"SpellIndex") if not row.is_empty() else -1

func _spell(id: int) -> Dictionary:
	var spell: Variant=SpellMetadata.casting_spell(tables,id)
	if spell==null:return {}
	var talent: Variant=SpellMetadata.talent_spell(tables,id)
	spell.children=talent.children if talent!=null else []
	return spell

func _children(id: int) -> Array:
	return _spell(id).get("children",[])

func _equipped_owner(value: Dictionary) -> Dictionary:
	var object: Dictionary=value.get("canonical",{})
	var id: Variant=object.get("equipmentOwnerId")
	var location: Variant=object.get("inventoryLocation")
	if id==null and location is Dictionary and str(location.get("channel",""))=="I":id=location.get("ownerId")
	return world_state.registry.get(int(id),{}) if id!=null else {}

static func _icon(value: Dictionary,gender: int) -> Dictionary:
	return {"kind":"item","gender":gender,"appearance":{"baseItem":value.get("baseItem"),"parts":value.get("parts"),"colors":value.get("colors"),"partColors":value.get("partColors"),"properties":value.get("properties")}}

func _stack_count(value: Dictionary) -> void:
	var stack:=_integer(value.get("stackSize"),"stack size")
	presentation.uses=str(stack&65535); presentation.enabled=stack>0

func update_count(button: Dictionary) -> Dictionary:
	var value:=item(int(button.get("itemId",INVALID)))
	if value.is_empty():return presentation
	var base:=base_info(value)
	if base.is_empty():return presentation
	var index:=int(button.get("intParam",0))&65535; var property:=_property(value,index)
	if property.is_empty():
		if (_integer(base.stacking,"maximum stack")&65535)>1:_stack_count(value)
		return presentation
	var kind:=int(property.get("type",0))&65535
	if kind==15:
		var cost:=int(property.get("costValue",0))&65535
		if cost in [7,13]:presentation.uses="*";return presentation
		if cost!=1:
			var uses:=_integer(_cached_uses(value,index),"cached uses")&65535 if index<8 else 0
			presentation.uses=str(uses);presentation.enabled=uses!=0;return presentation
		var current:=base_info(value)
		if current.is_empty():return presentation
		if int(current.equipableSlots)!=0 and (int(current.stacking)&65535)<2:
			presentation.uses="";presentation.enabled=true;return presentation
		_stack_count(value);return presentation
	if kind in [55,70,80]:_stack_count(value)
	return presentation

func configure_item(button: Dictionary,id: Variant,packed: Variant,force: Variant=0) -> bool:
	id=_integer(id,"item ID")&0xffffffff;packed=_integer(packed,"packed property");force=_integer(force,"force")
	var actor:=controlled()
	if actor.is_empty():return false
	var value:=item(id)
	if value.is_empty():return false
	if _integer(value.get("identified"),"identified flag")==0:feedback_code=97;return false
	var base:=base_info(value)
	if base.is_empty():feedback_code=23;return false
	if force==0:
		var can_use: Variant=value.get("canUse")
		if can_use not in [0,1,false,true]:failure="Replicated CanUseItem flag is unavailable";return false
		if int(can_use)==0:feedback_code=23;return false
	if int(base.container)==0 and int(base.equipableSlots)==0 and value.activeProperties.is_empty():feedback_code=23;return false
	var paired:=false
	if int(button.get("type",0))==1 and int(button.get("secondaryItemId",INVALID))==INVALID and (int(button.get("intParam",0))&65535)==255 and (packed&255)==255 and id!=int(button.get("itemId",INVALID)):
		var previous:=item(int(button.get("itemId",INVALID)))
		if not previous.is_empty():
			var old_base:=base_info(previous)
			if old_base.is_empty():return false
			var old_wield:=wield(actor,previous)&255
			if old_wield!=0:
				var new_wield:=wield(actor,value)&255
				var compatible:=false
				if old_wield==2:compatible=new_wield!=2 and int(value.baseItem) in [14,15,56,57]
				else:compatible=new_wield!=2 or int(previous.baseItem) in [14,15,56,57]
				if new_wield!=0 and compatible:
					var normal: bool=(int(old_base.equipableSlots)&16)!=0 and (int(base.equipableSlots)&32)!=0
					var swapped: bool=not normal and (int(old_base.equipableSlots)&32)!=0 and (int(base.equipableSlots)&16)!=0
					if normal or swapped:
						button.secondaryItemId=int(button.itemId) if swapped else id
						if swapped:button.itemId=id
						value=item(int(button.itemId));var second:=item(int(button.secondaryItemId))
						if not value.is_empty() and not second.is_empty():
							presentation.icon=_icon(value,int(actor.get("appearance",{}).get("gender",0)))
							presentation.secondaryIcon=_icon(second,int(actor.get("appearance",{}).get("gender",0)))
						paired=true
	if not paired:
		presentation={"icon":null,"secondaryIcon":null,"uses":"","enabled":true,"animation":null}
		button.type=1;button.itemId=id;button.secondaryItemId=INVALID;button.intParam=packed
		if (packed&255)==255:
			if (((int(base.qbBehaviour)&255)-1)&255)<=1:
				for index in value.activeProperties.size():
					var spell_id:=property_spell(value,index)
					if spell_id==-1:continue
					var spell:=_spell(spell_id)
					if spell.is_empty():continue
					button.intParam=index if not _children(spell_id).is_empty() else index|0xff0000
					break
			elif int(base.equipableSlots)==0 and not value.activeProperties.is_empty():button.intParam=0xff0000
		var index:=int(button.intParam)&255;var variant:=(int(button.intParam)>>16)&255
		var spell_id:=property_spell(value,index);var spell:=_spell(spell_id)
		if not spell.is_empty() and variant!=255:
			var children:=_children(spell_id)
			if not children.is_empty():spell=_spell(int(children[variant])) if variant<children.size() else {}
		var gender:=int(actor.get("appearance",{}).get("gender",0))
		if spell.is_empty() or int(value.baseItem) in [49,54,75,104]:
			presentation.icon=_icon(value,gender);presentation.secondaryIcon=null
		else:
			presentation.icon=SpellMetadata.spell_string_entry(tables.get("spells",{}),int(spell.id),"IconResRef");presentation.secondaryIcon=_icon(value,gender)
		update_count(button)
	var owner:=_equipped_owner(value)
	if not owner.is_empty() and int(owner.get("id",INVALID))==controlled_id():
		var second:=item(int(button.get("secondaryItemId",INVALID)))
		var other:=_equipped_owner(second) if not second.is_empty() else {}
		if second.is_empty() or not other.is_empty() and int(other.get("id",INVALID))==controlled_id():presentation.animation="qbEquip"
	else:presentation.animation=null
	return failure.is_empty()

func configure_shortcut(previous: Dictionary,binding: Dictionary,force: int=0) -> Dictionary:
	failure="";feedback_code=-1;presentation={}
	var button:=previous.duplicate(true)
	var ok:=configure_item(button,binding.get("itemId",INVALID),binding.get("intParam",0xff00ff),force)
	return {"ok":ok and failure.is_empty(),"button":button,"presentation":presentation.duplicate(true),"feedback":feedback_code,"error":failure}
