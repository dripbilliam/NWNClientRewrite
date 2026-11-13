extends RefCounted
# Frozen pre-worker algorithms. Do not update this oracle with the implementation.
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const EntityLifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
func signature(object: Dictionary) -> String:
	var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
	var appearance: Variant=object.get("appearance",{})
	# Native creature P400 updates names/popups without marking the model dirty.
	# Keep the received row intact for name/state consumers and retain all other
	# opaque appearance/equipment bytes in the model key.
	if int(object.get("objectType",0))==5 and appearance is Dictionary and appearance.has("name"):
		appearance=appearance.duplicate(); appearance.erase("name")
	var animated_placeable: bool=int(object.get("objectType",0))==9 and preload("res://systems/native_render/placeable_instance.gd").requires_animation(state)
	return Cache.digest(var_to_bytes([EntityLifetime.token(object),animated_placeable,object.get("objectType"),appearance,object.get("item",state.get("item",{})),state.get("appearance",fixed.get("appearance")),state.get("doorType"),state.get("genericType")]))

static func creature_pose(object: Dictionary) -> Dictionary:
	var state: Dictionary=object.get("replicated",{}); var position: Variant=state.get("position")
	if not position is Array or position.size()<3: return {}
	var orientation: Variant=state.get("orientation"); var vector: Variant=orientation.get("vector") if orientation is Dictionary else orientation; var rotation:=0.0
	if vector is Array and vector.size()>=2: rotation=-atan2(float(vector[0]),float(vector[1]))
	elif orientation is Dictionary: rotation=deg_to_rad(float(orientation.get("yaw",0)))
	return {"position":Vector3(position[0],position[2],-position[1]),"rotation":rotation}

static func static_pose(object: Dictionary) -> Dictionary:
	var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
	var position: Variant=state.get("position",fixed.get("position"))
	if not position is Array or position.size()<3: return {}
	var orientation: Variant=state.get("orientation",fixed.get("orientation")); var rotation:=0.0
	var vector: Variant=orientation.get("vector") if orientation is Dictionary else orientation
	if vector is Array and vector.size()>=2: rotation=-atan2(float(vector[0]),float(vector[1]))
	elif orientation is Dictionary: rotation=deg_to_rad(float(orientation.get("yaw",0)))
	return {"position":Vector3(position[0],position[2],-position[1]),"rotation":rotation}

static func object_pose(object: Dictionary) -> Dictionary:
	return creature_pose(object) if int(object.get("objectType",0)) in [5,6] else static_pose(object)
