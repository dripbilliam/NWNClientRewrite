extends RefCounted
# Pure presentation metadata for privately borrowed, immutable decoded JSON.
# Does not retain received rows or read Nodes, resources, indices or clocks.
const EntityLifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const BaseScenery=preload("res://systems/native_render/base_world_scenery.gd")
const Names=preload("res://systems/native_data/object_animation.gd")
const VERSION:=1

static func requires_animation(state: Dictionary) -> bool:
	if not state.has("animation"): return false
	var value: Variant = state.animation
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or value < 0 or value > 65535: return false
	return Names.name(9, int(value)) != "default"

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()

static func signature(object: Dictionary) -> String:
	var state: Dictionary=object.get("replicated",{}); var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
	var appearance: Variant=object.get("appearance",{})
	# Native creature P400 updates names/popups without marking the model dirty.
	# Keep the received row intact for name/state consumers and retain all other
	# opaque appearance/equipment bytes in the model key.
	if int(object.get("objectType",0))==5 and appearance is Dictionary and appearance.has("name"):
		appearance=appearance.duplicate(); appearance.erase("name")
	var animated_placeable: bool=int(object.get("objectType",0))==9 and requires_animation(state)
	return digest(var_to_bytes([EntityLifetime.token(object),animated_placeable,object.get("objectType"),appearance,object.get("item",state.get("item",{})),state.get("appearance",fixed.get("appearance")),state.get("doorType"),state.get("genericType")]))

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

static func validation_error(value: Variant) -> String:
	# This is a conservative worker-safety guard, not a protocol admission rule.
	# Unsupported shapes fall back to the original synchronous implementation
	# after all borrowers have completed; they are never silently normalized.
	if not value is Dictionary:return "row-not-dictionary"
	for field in ["id","areaId","objectType"]:
		# Non-world rows (for example inventory objects) may omit areaId. The
		# original receive filter uses -1 and skips them; this is safe to prepare
		# as an omitted slot, rather than rejecting an otherwise valid full batch.
		var number: Variant=value.get(field,-1 if field=="areaId" else null)
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number))>9007199254740991.0:return "identity-shape-unsupported"
	var state: Variant=value.get("replicated",{})
	var fixed: Variant=value.get("staticState",value.get("lightState",{}))
	if not state is Dictionary or not fixed is Dictionary:return "state-shape-unsupported"
	var position: Variant=state.get("position") if int(value.objectType) in [5,6] else state.get("position",fixed.get("position"))
	if not position is Array or position.size()<3:return ""
	for index in 3:
		if not (position[index] is int or position[index] is float) or not is_finite(float(position[index])):return "position-shape-unsupported"
	var orientation: Variant=state.get("orientation") if int(value.objectType) in [5,6] else state.get("orientation",fixed.get("orientation"))
	var vector: Variant=orientation.get("vector") if orientation is Dictionary else orientation
	if vector is Array and vector.size()>=2:
		for index in 2:
			if not (vector[index] is int or vector[index] is float) or not is_finite(float(vector[index])):return "orientation-shape-unsupported"
	elif orientation is Dictionary:
		var yaw: Variant=orientation.get("yaw",0)
		if not (yaw is int or yaw is float) or not is_finite(float(yaw)):return "orientation-shape-unsupported"
	return ""

static func prepare(rows: Array,area_id: int,offset: int=0) -> Array:
	var output: Array=[]
	for index in rows.size():
		var object: Dictionary=rows[index]
		var accepted: bool=int(object.get("areaId",-1))==area_id and not object.get("replicationRemoved",false) and int(object.get("objectType",0)) in [5,6,9,10]
		var pose: Dictionary=object_pose(object) if accepted else {}
		accepted=accepted and not pose.is_empty()
		# Keep source order and duplicates. The synchronous admission loop owns
		# last-row-wins replacement, retirements and every canonical row reference.
		output.append({"index":offset+index,"id":int(object.get("id",-1)),"accepted":accepted,"pose":pose,"key":signature(object) if accepted else "","classification":BaseScenery.classify(object,area_id) if accepted else {},"omission":BaseScenery.omitted_reason(object,area_id) if not accepted else ""})
	return output
