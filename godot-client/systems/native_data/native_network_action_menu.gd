extends RefCounted
const Transition=preload("res://systems/native_data/transition_surface.gd")
const RadialActions=preload("res://systems/native_data/native_radial_actions.gd")
const NetworkDoor=preload("res://systems/native_data/native_network_door.gd")
static func object_label(object: Dictionary) -> String:
	var item: Dictionary=object.get("item",{}) if object.get("item") is Dictionary else {}
	var replicated: Dictionary=object.get("replicated",{}) if object.get("replicated") is Dictionary else {}
	var appearance: Dictionary=object.get("appearance",{}) if object.get("appearance") is Dictionary else {}
	var authored: Dictionary=object.get("staticState",{}) if object.get("staticState") is Dictionary else {}
	var name: Variant=item.get("name")
	if name==null:name=replicated.get("name")
	if name==null:name=appearance.get("name")
	if name==null:name=authored.get("name")
	if name is Dictionary:
		if not str(name.get("text","")).is_empty():return str(name.text)
		var parts:=PackedStringArray()
		for part in [name.get("firstName"),name.get("lastName")]:
			if part is Dictionary and not str(part.get("text","")).is_empty():parts.append(str(part.text))
		if not parts.is_empty():return " ".join(parts)
	return "Object %x"%int(object.get("id",0))
static func door_state(animation: Variant) -> Variant:
	return NetworkDoor.state(animation)
static func placeable_usable(object: Dictionary) -> bool:
	if int(object.get("objectType",0))!=9:return false
	var state: Dictionary=object.get("replicated",{}) if object.get("replicated") is Dictionary else {}
	var authored: Dictionary=object.get("authored",{}) if object.get("authored") is Dictionary else {}
	for value in [state.get("field264"),object.get("nativeUseable264"),object.get("usable"),authored.get("Useable")]:
		if value!=null:return bool(value)
	return false
static func menu_object(object: Dictionary) -> Dictionary:
	var state: Dictionary=object.get("replicated",{}) if object.get("replicated") is Dictionary else {}
	var location: Dictionary=object.get("inventoryLocation",{}) if object.get("inventoryLocation") is Dictionary else {}
	var item: Dictionary=object.get("item",{}) if object.get("item") is Dictionary else {}
	var kind:=int(object.get("objectType",0))
	var result: Dictionary={"id":object.get("id"),"kind":{5:"creature",6:"item",7:"trigger",9:"placeable",10:"door"}.get(kind,"object"),"name":object_label(object),"animationState":door_state(state.get("animation")),"locked":bool(state.get("field424",false)),"equipped":str(location.get("channel",""))=="I","player":false}
	if state.has("field428"):result.lockable=bool(state.field428)
	if kind==9:result.usable=placeable_usable(object)
	elif kind==10 and state.has("fieldFC"):result.usable=bool(state.fieldFC)
	if location.has("ownerId"):result.ownerId=location.ownerId
	if item.get("stackSize")!=null:result.stackSize=item.stackSize
	elif item.has("field454"):result.stackSize=item.field454
	if state.has("master"):result.masterId=state.master
	if state.has("field908"):result.associateType=state.field908
	return result
static func transition_trigger(object: Dictionary) -> bool:
	return Transition.network_transition_trigger(object)
static func radial_override(target: Variant,menu: Dictionary) -> Dictionary:
	if target is Dictionary and transition_trigger(target):
		return {"title":object_label(target),"entries":[{"slot":2,"label":"Enter","icon":"IR_USE","action":"trigger.transition"}]}
	if target is Dictionary and int(target.get("objectType",0))==10:
		var result: Dictionary=menu.duplicate(true)
		var state: Dictionary=target.get("replicated",{}) if target.get("replicated") is Dictionary else {}
		for entry in result.get("entries",[]):
			if str(entry.get("action",""))=="door.toggle":entry.action="door.open" if door_state(state.get("animation"))==0 else "door.close"
		return result
	return menu
static func network_radial_actions(target: Variant,actor: Dictionary,options: Dictionary={}) -> Dictionary:
	var projected_actor: Dictionary=menu_object(actor)
	if target is Dictionary:
		var projected_target: Dictionary=menu_object(target)
		var actual_options: Dictionary=options.duplicate()
		actual_options.commandMenu=options.get("commandMenu")
		actual_options.unpossessFamiliar=int(projected_actor.get("associateType",-1))==3
		return radial_override(target,RadialActions.build_radial_actions(projected_target,projected_actor,actual_options))
	return RadialActions.build_ground_radial_actions(projected_actor,options)
static func default_interaction(target: Dictionary) -> Variant:
	if transition_trigger(target):return "trigger.transition"
	var kind:=int(target.get("objectType",0));var state: Dictionary=target.get("replicated",{}) if target.get("replicated") is Dictionary else {}
	if kind==10:
		var animation_state: Variant=door_state(state.get("animation"))
		var click: Variant=NetworkDoor.click_state(target)
		if click!=null and int(click)!=0 and bool(state.get("hasTransition",false)):return "door.transition"
		if animation_state==0:return "door.open"
		if animation_state==1 or animation_state==2:return "door.close"
		return null
	if kind==5:return "combat.attack" if int(state.get("reaction",0))>1 else "conversation.start"
	if kind==9:return "object.use"
	if kind==6:return "item.pickup"
	return null
