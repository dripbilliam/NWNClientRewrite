extends RefCounted
# Internal visual adapter, not another entity store. A visual carries only the
# scope/lifetime witness installed at its existing adoption/update boundary.
# Actual raw entities remain in Gameplay.text; actual poses remain in World.
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const Anchor=preload("res://systems/native_data/nameplate_anchor.gd")
const VisualDefinition=preload("res://systems/native_data/visual_definition.gd")
static func item_identity(row: Dictionary) -> bool:
	# Use the canonical merged item, never an individual packet's omitted map.
	# A missing projected field is unknown; explicit null is the native default.
	var item: Variant=row.get("item",row.get("replicated",{}).get("item"))
	return item is Dictionary and item.has("visualTransform") and VisualDefinition.identity(item.visualTransform)
static func item_main_ready(instance: Node3D) -> bool:
	var scopes: Variant=instance.get("body_model_scopes")
	return instance.get("retired")==false and instance.get("failure")=="" and is_instance_valid(instance.get("rigs")) and scopes is Dictionary and scopes.has(255)
static func witness(row: Dictionary) -> Array:
	if not Scope.integer(row.get("id"),0,Scope.MAX_ID) or not Scope.integer(row.get("nativeLifetime"),1,Scope.MAX_SAFE) or not Scope.integer(row.get("clientKnownLifetime"),1,Scope.MAX_SAFE):return []
	return [int(row.id),int(row.nativeLifetime),int(row.clientKnownLifetime)]
static func stamp(instance: Node3D,row: Dictionary,current: Dictionary) -> void:
	if not is_instance_valid(instance) or not Scope.current_context(current):return
	var identity:=witness(row)
	if identity.is_empty():return
	instance.set_meta("native_speech_identity",identity)
	instance.set_meta("native_speech_scope",[int(current.connection),int(current.generation),int(current.areaId)])
	# Item83dbd0 writes c0=.5 only after successful main selector255 loading.
	# Actor's creature-height metadata and arbitrary MDL transforms do not apply.
	if int(row.get("objectType",0))==6:
		if item_main_ready(instance) and item_identity(row):instance.set_meta("native_item_popup_height",0.5)
		elif instance.has_meta("native_item_popup_height"):instance.remove_meta("native_item_popup_height")
	# Placeable871440 stores the successful model's authored head_hit height.
	# Resolve once at visual installation; never scan mesh bounds or animation.
	if int(row.get("objectType",0))==9 and not instance.has_meta("native_speech_height"):
		var model_name:=str(instance.get_meta("native_model_name",""))
		var hook_name:=model_name.substr(4).to_lower()+"_head_hit"
		var parts: Variant=instance.get("parts")
		var height:=1.5
		if parts is Array:
			for part in parts:
				if is_instance_valid(part) and str(part.get_meta("native_part_name","")).to_lower()==hook_name:
					height=instance.to_local(part.global_position).y;break
		instance.set_meta("native_speech_height",height)
static func project(instance: Node3D,row: Dictionary,identity: Array,scope: Array,current: Dictionary,camera: Camera3D) -> Dictionary:
	if not Scope.current_context(current) or scope!=[int(current.connection),int(current.generation),int(current.areaId)]:return {"ready":false,"retired":true}
	if not is_instance_valid(instance) or not is_instance_valid(camera) or row.is_empty():return {"ready":false}
	if identity.is_empty() or identity!=witness(row) or instance.get_meta("native_speech_identity",[])!=identity or instance.get_meta("native_speech_scope",[])!=scope:return {"ready":false}
	if int(row.get("areaId",-1))!=int(current.areaId) or not instance.is_inside_tree():return {"ready":false}
	var type:=int(row.get("objectType",0));var height: float
	if type==5:
		if not instance.has_meta("native_nameplate_height"):return {"ready":false}
		height=float(instance.get_meta("native_nameplate_height"))
	elif type==6:
		if not instance.has_meta("native_item_popup_height") or not item_main_ready(instance) or not item_identity(row):return {"ready":false}
		height=float(instance.get_meta("native_item_popup_height"))
	elif type==9:
		if not instance.has_meta("native_speech_height"):return {"ready":false}
		height=float(instance.get_meta("native_speech_height"))
	elif type in [7,10]:height=2.1
	else:return {"ready":false}
	if not is_finite(height):return {"ready":false}
	# Native766ea0 identity root adds height in world Z (Godot Y); it does not
	# transform that vector by the item's model/parent scale or rotation.
	var head:=instance.global_position+Vector3(0,height,0) if type==6 else instance.to_global(Vector3(0,height,0))
	var point:=Anchor.lift(head,camera.global_position)
	var screen:=camera.unproject_position(point)
	if not point.is_finite() or not screen.is_finite():return {"ready":false}
	# Bubble.place owns the single native trunc(point+0.5). Returning a rounded
	# negative coordinate here would round it twice and drift offscreen speech.
	return {"ready":true,"point":point,"screen":screen}
