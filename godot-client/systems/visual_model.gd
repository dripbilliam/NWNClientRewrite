extends Node3D

# Private render instance. Local rig handle 0 is never added to EntityRegistry,
# physics, picking or replicated object maps. Each instance owns its skeletons,
# AnimationPlayers, reference attachments, imported scene and eventual emitters.
const Rigs = preload("res://systems/model_rigs.gd")
const ReferenceState = preload("res://systems/model_reference_state.gd")
class MeshIndex:
	extends RefCounted
	var meshes_by_name: Dictionary = {}

var rigs
var metadata: Dictionary = {}
var meshes := MeshIndex.new()
var error := ""
var retired := false
var installed := false
var anchor: Node3D
var attached := false
var anchor_flags := 0
var anchor_scale := Vector3.ONE
var playback_limitations: Array = []
var reference_roots: Dictionary = {}

func prepare(scene_path: String, metadata_sha: String) -> bool:
	if installed or retired:
		return _fail("Visual instance is already installed or retired")
	var project := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/") + "/"
	if not scene_path.is_absolute_path() or scene_path.replace("\\", "/").begins_with(project):
		return _fail("Visual models must use external runtime bundles")
	var metadata_path := scene_path.get_basename() + ".json"
	if metadata_sha.length() != 64 or FileAccess.get_sha256(metadata_path) != metadata_sha:
		return _fail("Visual metadata hash mismatch")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not parsed is Dictionary or not _valid_metadata(parsed):
		return _fail("Invalid private visual model metadata")
	if FileAccess.get_sha256(scene_path) != parsed.get("sha256", ""):
		return _fail("Visual GLB hash mismatch")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(scene_path, state) != OK:
		return _fail("Visual GLB import failed")
	var room := document.generate_scene(state)
	if room == null:
		return _fail("Visual scene generation failed")
	return install(room, parsed)

func _valid_metadata(value: Dictionary) -> bool:
	var entries: Array = value.get("rigs", {}).get("entities", [])
	if value.get("version") != 1 or value.get("kind") != "visual-model" or not value.get("entities", []).is_empty() or entries.size() != 1 or entries[0].get("id", -1) != 0:
		return false
	if value.get("modelResources", []).size() != entries[0].models.size() or entries[0].models.is_empty():
		return false
	var nodes: Array = entries[0].get("nodes", [])
	if nodes.is_empty():
		return false
	for row in value.get("meshes", []):
		if row.get("objectId", -1) != 0 or (not row.get("particle", false) and (not row.has("rigNode") or int(row.rigNode) < 0 or int(row.rigNode) >= nodes.size())):
			return false
	for model in entries[0].models:
		if not model.has("root") or int(model.root) < 0 or int(model.root) >= nodes.size() or not model.has("partNames") or model.partNames.size() != model.parts.size() or model.parts.is_empty() or not model.has("rootPart") or int(model.rootPart) < 0 or int(model.rootPart) >= model.parts.size():
			return false
		for part in model.parts:
			if int(part) < 0 or int(part) >= nodes.size():
				return false
		if model.has("referenceGraph") and not _valid_reference_graph(model.referenceGraph,model,entries[0].models):return false
	return true

func _valid_reference_graph(graph: Variant,model: Dictionary,models: Array) -> bool:
	if not graph is Dictionary or graph.get("version") != 1 or not graph.get("parts") is Array or graph.parts.size() != model.parts.size() or int(graph.get("root",-1)) != int(model.rootPart):return false
	var count: int = graph.parts.size();var parents: Array = [];parents.resize(count);parents.fill(0)
	for index in count:
		var row: Variant = graph.parts[index]
		if not row is Dictionary or row.get("name") != model.partNames[index] or not row.get("reference") is bool or not row.get("children") is Array or not row.has("flags98") or not row.has("reattachableE0"):return false
		if float(row.flags98) != int(row.flags98) or float(row.reattachableE0) != int(row.reattachableE0):return false
		if row.get("model") != null:
			var child := int(row.model)
			if not row.reference or float(row.model) != child or child < 0 or child >= models.size() or int(models[child].root) <= int(model.root):return false
		for child in row.children:
			if float(child) != int(child) or int(child) < 0 or int(child) >= count:return false
			parents[int(child)] += 1
	for i in count:
		if parents[i] != (0 if i == int(graph.root) else 1):return false
	var queue: Array = [int(graph.root)];var seen := {}
	while not queue.is_empty():
		var index := int(queue.pop_front())
		if seen.has(index):return false
		seen[index] = true;queue.append_array(graph.parts[index].children)
	return seen.size() == count

func _reference_root(model_index: int):
	if reference_roots.has(model_index):return reference_roots[model_index]
	var graph: Dictionary = metadata.rigs.entities[0].models[model_index].get("referenceGraph",{})
	if graph.is_empty():return null
	var parts: Array = []
	for row in graph.parts:parts.append({"name":row.name,"reference":row.reference,"header8":{"flags98":row.flags98,"reattachableE0":row.reattachableE0},"model68":null if row.model == null else {"index":int(row.model)},"children38":[]})
	for index in parts.size():
		for child in graph.parts[index].children:parts[index].children38.append(parts[int(child)])
	reference_roots[model_index] = parts[int(graph.root)];return reference_roots[model_index]

func retarget_reference(model_index: int,target: Node3D) -> bool:
	if not installed or retired or not is_instance_valid(target):return false
	var root := model_root(model_index)
	if root == null:return false
	for attachment in rigs.entities[0].attachments:
		if rigs.entities[0].nodes[int(attachment.node)] != root:continue
		if not attachment.has("reference_visible"):attachment.reference_visible = root.visible
		attachment.external_anchor = target;attachment.flags = 0
		rigs.sync_attachments(0);return true
	return false

func reattach_references(target: Node3D,model_index: int = 0) -> bool:
	if not installed or retired or _reference_root(model_index) == null:return false
	var valid := {"value":true}
	ReferenceState.reattach(self,target,"",{"root":func(_owner):return _reference_root(model_index),"asReference":func(part):return part if part.reference else null,"name":func(part):return part.name,
		"attach":func(child,parent,name,_flags):
			var node: Node3D = node_for(model_index,name) if is_same(parent,self) else parent
			if not retarget_reference(int(child.index),node):valid.value = false,
		"position":func(owner):
			var point: Vector3 = global_position if is_same(owner,self) else model_root(int(owner.index)).global_position
			return [point.x,-point.z,point.y],
		"orientation":func(_owner):
			var q := global_basis.orthonormalized().get_rotation_quaternion();return [q.w,q.x,-q.z,q.y],
		"setOrientation":func(_owner,value):
			global_basis = Basis(Quaternion(float(value[1]),float(value[3]),-float(value[2]),float(value[0]))).scaled(global_basis.get_scale())
			rigs.sync_attachments(0)})
	return valid.value

func install(room: Node3D, value: Dictionary) -> bool:
	if installed or retired or not _valid_metadata(value):
		room.free()
		return _fail("Invalid or reused private visual instance")
	metadata = value.duplicate(true)
	add_child(room)
	_index(room)
	if meshes.meshes_by_name.size() != int(metadata.get("counts", {}).get("meshes", -1)):
		room.free()
		meshes.meshes_by_name.clear()
		return _fail("Visual mesh count mismatch")
	for row in metadata.meshes:
		if not meshes.meshes_by_name.has(str(row.name)):
			room.free()
			meshes.meshes_by_name.clear()
			return _fail("Visual mesh binding is missing")
	rigs = Rigs.new()
	rigs.process_priority = 60
	add_child(rigs)
	rigs.configure(meshes, {0: self}, metadata)
	if not rigs.stats.failures.is_empty():
		return _fail("Visual native rig/skin preparation failed")
	installed = true
	process_priority = 50 # After canonical animation, before particle sampling.
	return true

func _index(node: Node) -> void:
	if node is MeshInstance3D:
		meshes.meshes_by_name[str(node.name)] = node
	for child in node.get_children():
		_index(child)

func node_for(model_index: int, part_name: String = "root") -> Node3D:
	if not installed or retired or model_index < 0 or model_index >= metadata.modelResources.size():
		return null
	var model: Dictionary = metadata.rigs.entities[0].models[model_index]
	var part: int = int(model.rootPart) if part_name.to_lower() == "root" else -1
	if part < 0:
		# Exported rig indices follow physical DFS traversal, preserving the
		# original first matching part even when names repeat in node storage.
		for index in model.parts.size():
			if str(model.partNames[index]).to_lower() == part_name.to_lower() and (part < 0 or int(model.parts[index]) < int(model.parts[part])):
				part = index
	return null if part < 0 else rigs.entities[0].nodes[int(model.parts[part])]

func model_root(model_index: int) -> Node3D:
	if not installed or retired or model_index < 0 or model_index >= metadata.modelResources.size():
		return null
	return rigs.entities[0].nodes[int(metadata.rigs.entities[0].models[model_index].root)]

# Explicit ordinary clip playback; original stacked-run flags are not reduced
# to a boolean here. Their separate controller adapter remains required.
func play_clip(model_index: int, clip: String, loop: bool, speed: float = 1.0, time: float = 0.0) -> bool:
	if model_root(model_index) == null or not is_finite(speed) or not is_finite(time):
		return false
	var model: Dictionary = rigs.entities[0].models[model_index]
	if not model.names.has(clip.to_lower()):
		return false
	rigs._play(model, clip.to_lower(), loop, speed, time, true)
	return true

func play_effect_clip(clip: Variant, speed: float, flags: int, time: float) -> bool:
	if installed and not retired and metadata.rigs.assets[int(metadata.rigs.entities[0].models[0].asset)].get("nativeAnimation") is Dictionary:
		return rigs.play_native(0, 0, clip, speed, flags, time)
	# Initial single-clip presentation profile. Preserve requested flags and
	# diagnose the missing stacked native run/controller owner explicitly.
	if flags not in [0, 1, 3]:
		return false
	if not playback_limitations.has("stacked-run/blend/controller parity pending"):
		playback_limitations.append("stacked-run/blend/controller parity pending")
	return play_clip(0, clip, (flags & 1) == 0, speed, time)

func clip_length(clip: String) -> float:
	if not installed or retired:
		return 0.0
	var model: Dictionary = rigs.entities[0].models[0]
	if not model.names.has(clip.to_lower()):
		return 0.0
	var source: Dictionary = metadata.rigs.entities[0].models[0]
	for original in metadata.rigs.assets[int(source.asset)].clips:
		if str(original.name).to_lower() == clip.to_lower():
			return float(original.length)
	return 0.0

func sample_weather_clip(clip: String,fraction: float) -> bool:
	# Original weather setter: delete same run, play at intensity/100,
	# externally advance by original clip length, freeze by setting speed0.
	var length := clip_length(clip)
	if length <= 0 or not metadata.rigs.assets[int(metadata.rigs.entities[0].models[0].asset)].get("nativeAnimation") is Dictionary: return false
	play_effect_clip(clip,0,128,0)
	if not play_effect_clip(clip,fraction,0,0): return false
	var model: Dictionary = rigs.entities[0].models[0]
	model.native_owner.advance(length)
	rigs._native_clock(model)
	return play_effect_clip(clip,0,0,0)

func set_part_local_pose(part_name: String, position_value: Array, quaternion_value: Array) -> bool:
	var node := node_for(0, part_name)
	if node == null:
		return false
	var q := Quaternion(float(quaternion_value[1]), float(quaternion_value[3]), -float(quaternion_value[2]), float(quaternion_value[0]))
	return rigs.set_manual_pose(0, node, Vector3(float(position_value[0]), float(position_value[2]), -float(position_value[1])), q)

func reset_part_world_orientation(part_name: String) -> bool:
	var node := node_for(0, part_name)
	if node == null:
		return false
	var position := node.global_position
	node.position = Vector3.ZERO
	node.quaternion = Quaternion.IDENTITY
	var base_position := node.global_position
	var base_q := node.global_basis.orthonormalized().get_rotation_quaternion()
	# The original lower setter rotates displacement without dividing by the
	# parent scale. This is deliberately not affine_inverse().
	var inverse := base_q.inverse()
	return rigs.set_manual_pose(0, node, inverse * (position - base_position), inverse.normalized())

func attach_to(value: Node3D, flags: int = 0) -> bool:
	if not installed or retired or not is_instance_valid(value) or flags not in [0, 3]:
		return false
	anchor = value
	attached = true
	anchor_flags = flags
	anchor_scale = scale
	# AttachToObject copies anchor P/Q on the initial call even in mode 3;
	# subsequent updates in mode 3 retain the resulting current orientation.
	global_transform = Transform3D(Basis(anchor.global_basis.orthonormalized().get_rotation_quaternion()).scaled(anchor_scale), anchor.global_position)
	_sync_anchor()
	return true

func detach() -> void:
	anchor = null # Keep the current world pose, as native unparenting does.
	attached = false

func _sync_anchor() -> void:
	var rotation := (global_basis if anchor_flags == 3 else anchor.global_basis).orthonormalized().get_rotation_quaternion()
	global_transform = Transform3D(Basis(rotation).scaled(anchor_scale), anchor.global_position)

func _process(_delta: float) -> void:
	if not attached:
		return
	if not is_instance_valid(anchor) or anchor.is_queued_for_deletion():
		retire()
		return
	_sync_anchor()

func retire() -> void:
	if retired:
		return
	retired = true
	visible = false
	set_process(false)
	if is_instance_valid(rigs):
		rigs.set_process(false)
		rigs.forget_entity(0)
	anchor = null
	attached = false
	meshes.meshes_by_name.clear()
	reference_roots.clear()
	queue_free()

func _fail(reason: String) -> bool:
	error = reason
	return false
