extends Node

const NativeAnimation = preload("res://systems/model_native_animation.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const SkinPreparation=preload("res://systems/native_data/skin_preparation.gd")
static var scalar_values:=preload("res://systems/native_data/scalar_representation.gd").configured()

signal animation_event(id: int, name: String, serial: int)
signal model_event(id: int, model_index: int, name: String, serial: int)

var entities: Dictionary = {}
var registry
# This table is separate from entities: a publisher retains its input entry,
# and putting the publisher inside that entry would create a reference cycle.
static func configured_native_skin_publisher() -> bool:
	return ClassDB.class_exists("NwnRigSkinPublisher") and OS.get_cmdline_user_args().has("--rig-skin-publisher=native")
var use_native_skin_publisher: bool=configured_native_skin_publisher()
var native_skin_publishers: Dictionary={}
var native_skin_reentrant_fallbacks: int=0

func _publish_skin_native(id: int,entry: Dictionary) -> Variant:
	if not use_native_skin_publisher:return 1
	var binding: Array=native_skin_publishers.get(id,[])
	if binding.is_empty() or not is_same(binding[0],entry):
		var publisher: RefCounted=ClassDB.instantiate("NwnRigSkinPublisher")
		if not bool(publisher.call("configure",entry)):return 1
		binding=[entry,publisher];native_skin_publishers[id]=binding
	var status: int=int(binding[1].call("publish"))
	# Existing ModelRigs allows a force-update listener to recurse into _update.
	# The engine rejects before touching its outer scratch, so this nested call
	# must use the original script branch and its own local rigid array.
	if status==3:
		native_skin_reentrant_fallbacks+=1
		return 1
	if status==2:
		var continuation: Dictionary=binding[1].call("take_continuation")
		if not continuation.is_empty():return continuation
	if status>1:
		var message: String="Native skin publication interrupted at a callback boundary: "+str(status)
		if not stats.failures.has(message):stats.failures.append(message)
		push_error(message)
	return status

func native_skin_snapshot(id: int) -> Dictionary:
	var binding: Array=native_skin_publishers.get(id,[])
	return binding[1].call("inspect") if not binding.is_empty() else {}

func native_skin_publication_snapshot() -> Dictionary:
	var out: Dictionary={"enabled":use_native_skin_publisher,"publishers":native_skin_publishers.size(),"reentrant_fallbacks":native_skin_reentrant_fallbacks,"totals":{},"entries":[]}
	for id: int in native_skin_publishers:
		var row: Dictionary=native_skin_snapshot(id)
		for key: String in ["calls","completed","fallbacks","partial_failures","continuations","node_reads","bone_writes","force_calls"]:out.totals[key]=int(out.totals.get(key,0))+int(row.get(key,0))
		row.id=id;out.entries.append(row)
	return out


static func configured_prepared_clips() -> bool: return not OS.get_cmdline_user_args().has("--clip-preparation=main")
var use_prepared_clips:=configured_prepared_clips()
var stats := {"entities": 0, "nodes": 0, "players": 0, "clips": 0, "indexed_clip_models":0,"indexed_clip_metadata":0,"skin_meshes": 0, "skin_prepared_meshes":0,"skin_main_meshes":0,"rigid_meshes": 0, "skin_vertices": 0, "unsupported_channels": [], "pose_frames": 0, "missing_requested_clips": [], "failures": []}

func configure(value, pivots: Dictionary, metadata: Dictionary) -> void:
	registry = value
	var data: Dictionary = metadata.get("rigs", {})
	if data.get("version", 0) != 1:
		return
	for source in data.get("entities", []):
		var before := stats.duplicate(true)
		var id := int(source.id)
		if not pivots.has(id):
			continue
		var rig := Node3D.new()
		rig.name = "ModelRig"
		pivots[id].add_child(rig)
		var nodes: Array[Node3D] = []
		for index in source.nodes.size():
			var row: Dictionary = source.nodes[index]
			var node := Node3D.new()
			node.name = "part_%s" % index
			var parent := int(row.parent)
			if parent >= index or parent < -1:
				_fail("Model hierarchy contains an invalid parent")
				return
			(rig if parent == -1 else nodes[parent]).add_child(node)
			node.position = _vec(row.position)
			node.quaternion = _quat(row.quaternion)
			node.scale = _vec(row.scale)
			node.visible = row.get("visible", true)
			nodes.append(node)
		var entry := {"root": rig, "nodes": nodes, "parents": source.nodes.map(func(row): return int(row.parent)), "models": [], "animated_models":[], "skins": [], "attachments": source.get("attachments", []), "clip_map": source.get("clipMap", {}), "side_maps": source.get("sideMaps", {}), "context": source.get("context", {}).duplicate(true), "body_type": int(source.get("bodyType", 0)), "side": 0, "loop_map": source.get("loopMap", {}), "animation": -1}
		native_skin_publishers.erase(id)
		entities[id] = entry
		entry["authored_names"] = source.nodes.map(func(row): return str(row.name))
		entry["model_parts"] = source.models.map(func(model): return model.parts.duplicate())
		entry["manual_poses"] = {}
		entry["model18"] = bool(source.get("model18", false))
		entry["model18_unavailable"] = bool(source.get("model18Unavailable", false))
		for model in source.models:
			var asset: Dictionary = data.assets[int(model.asset)]
			var model_began:=FrameProfile.begin()
			var prepared: Dictionary = _model(rig, nodes, model, asset)
			FrameProfile.finish("actor_install_animation_ms",model_began)
			prepared["asset_source"] = asset
			prepared["part_source"] = model
			prepared["event_source"] = entry.models.size() == int(source.get("animationSource", 0))
			if prepared.player!=null: entry.animated_models.append(entry.models.size())
			entry.models.append(prepared)
		for row in metadata.get("meshes", []):
			if int(row.get("objectId", -1) if row.get("objectId") != null else -1) != id or not row.has("rigNode") or row.get("particle", false):
				continue
			var mesh: MeshInstance3D = registry.meshes_by_name.get(str(row.name))
			if mesh == null:
				_fail("An animated source mesh binding is missing")
				continue
			var target: Node3D = nodes[int(row.rigNode)]
			mesh.reparent(target, false)
			mesh.position = _vec(row.rigLocal.position)
			mesh.quaternion = _quat(row.rigLocal.quaternion)
			mesh.scale = _vec(row.rigLocal.scale)
			if row.has("skin"):
				var skin: Dictionary = row.skin
				var model: Dictionary = source.models[int(skin.model)]
				var skin_began:=FrameProfile.begin()
				var runtime := _skin(mesh, skin, model.parts)
				FrameProfile.finish("actor_install_skin_runtime_ms",skin_began)
				if not runtime.is_empty():
					entry.skins.append(runtime)
			else:
				stats.rigid_meshes += 1
				var body = mesh.get_meta("collision_body") if mesh.has_meta("collision_body") else null
				if is_instance_valid(body):
					body.reparent(target, true)
		stats.entities += 1
		stats.nodes += nodes.size()
		entry["counts"] = {}
		for key in ["entities", "nodes", "players", "clips", "indexed_clip_models", "indexed_clip_metadata", "skin_meshes", "skin_prepared_meshes", "skin_main_meshes", "rigid_meshes", "skin_vertices"]:
			entry.counts[key] = stats[key] - before[key]
		for model in entry.models: model["entity_counts"] = entry.counts
	_update(0.0)

func forget_entity(id: int) -> void:
	if not entities.has(id):
		return
	native_skin_publishers.erase(id)
	for model in entities[id].models:
		if model.has("native_owner"): model.native_owner.close()
	for key in entities[id].get("counts", {}):
		stats[key] -= entities[id].counts[key]
	entities.erase(id)

func sync_attachments(id: int) -> void:
	if not entities.has(id):return
	var entry: Dictionary = entities[id]
	for attachment in entry.attachments:
		var held: Node3D = entry.nodes[int(attachment.node)]
		var external: bool = attachment.has("external_anchor")
		var anchor = attachment.external_anchor if external else entry.nodes[int(attachment.anchor)]
		if not is_instance_valid(anchor) or anchor.is_queued_for_deletion():
			if external:held.visible = false
			continue
		if external:held.visible = bool(attachment.get("reference_visible",true))
		var rotation: Quaternion = (held.global_basis if int(attachment.get("flags",0)) == 3 else anchor.global_basis).orthonormalized().get_rotation_quaternion()
		held.global_transform = Transform3D(Basis(rotation).scaled(_vec(attachment.scale)),anchor.global_position)

func node_for(id: int, model_index: int, part_name: String = "root") -> Node3D:
	if not entities.has(id) or model_index < 0 or model_index >= entities[id].model_parts.size():
		return null
	var entry: Dictionary = entities[id]
	var parts: Array = entry.model_parts[model_index]
	var chosen := -1
	for part in parts:
		var index := int(part)
		var matches: bool = not parts.has(int(entry.parents[index])) if part_name.to_lower() == "root" else str(entry.authored_names[index]).to_lower() == part_name.to_lower()
		if matches and (chosen < 0 or index < chosen):
			chosen = index
	return entry.nodes[chosen] if chosen >= 0 else null
func node_at(id: int,index: int) -> Node3D:
	return entities[id].nodes[index] if entities.has(id) and index>=0 and index<entities[id].nodes.size() else null

func playback_state(id: int,model_index: int) -> Dictionary:
	if not entities.has(id) or model_index<0 or model_index>=entities[id].models.size(): return {}
	var model: Dictionary=entities[id].models[model_index]
	return {"clip":str(model.get("clip","")),"time":float(model.get("last_time",0.0)),"serial":int(model.get("play_serial",0))}

func set_manual_pose(id: int, node: Node3D, position: Vector3, quaternion: Quaternion) -> bool:
	if not entities.has(id) or not is_instance_valid(node):
		return false
	var entry: Dictionary = entities[id]
	var index: int = entry.nodes.find(node)
	if index < 0:
		return false
	entry.manual_poses[index] = {"position": position, "quaternion": quaternion, "scale": node.scale}
	for model in entry.models:
		if model.has("native_owner"): model.native_owner.pose.set_manual(index, position, quaternion)
	node.position = position
	node.quaternion = quaternion
	return true

func play_native(id: int, model_index: int, clip: Variant, speed: float, flags: int, time: float) -> bool:
	if not entities.has(id) or model_index < 0 or model_index >= entities[id].models.size(): return false
	var entry: Dictionary = entities[id]
	var model: Dictionary = entry.models[model_index]
	if not model.asset_source.get("nativeAnimation") is Dictionary: return false
	if not model.has("native_owner"):
		var native_owner := NativeAnimation.new()
		native_owner.configure(model.asset_source, model.part_source, entry)
		model["native_owner"] = native_owner
		if entry.has("animated_models") and not entry.animated_models.has(model_index): entry.animated_models.append(model_index)
		if model.player != null: model.player.stop()
	var result: bool = model.native_owner.play(clip, speed, flags, time)
	if result:
		model.play_serial = int(model.get("play_serial", 0)) + 1
		_native_clock(model)
		_emit_native_events(id, model_index, model)
	return result

func set_model_colour_scope(id: int,model_index: int,scope: int,rgb: Variant) -> bool:
	if not entities.has(id) or model_index<0 or model_index>=entities[id].models.size(): return false
	var entry: Dictionary=entities[id]; var model: Dictionary=entry.models[model_index]
	if not model.asset_source.get("nativeAnimation") is Dictionary: return false
	if not model.has("native_owner"):
		if rgb==null: return true
		# Preserve the held model's current clock when admitting its native Part
		# owner; this is a colour change, not another attack/animation event.
		var playing: bool=model.player!=null and model.player.is_playing() and not model.player.current_animation.is_empty()
		var at: float=model.player.current_animation_position if playing else float(model.get("last_time",0.0))
		var owner:=NativeAnimation.new(); owner.configure(model.asset_source,model.part_source,entry)
		if playing:
			if not owner.play(model.clip,float(model.speed),0 if model.loop else 1,at): owner.close(); return false
			owner.events.clear()
		model.native_owner=owner
		if model.player!=null: model.player.stop()
		if not entry.animated_models.has(model_index): entry.animated_models.append(model_index)
		_native_clock(model)
	return model.native_owner.pose.set_colour_scope(scope,rgb,entry.manual_poses)

func _emit_native_events(id: int, model_index: int, model: Dictionary) -> void:
	var pending: Array = model.native_owner.events.duplicate()
	model.native_owner.events.clear()
	for event in pending:
		model_event.emit(id, model_index, str(event), int(model.get("play_serial", 0)))
		if model.get("event_source", false): animation_event.emit(id, str(event), int(model.get("play_serial", 0)))

func _native_clock(model: Dictionary) -> void:
	var runs: Array = model.native_owner.gob.runsE0
	if not runs.is_empty():
		model.clip = str(runs[0].clip0.name)
		model.speed = float(runs[0].speed8)
		model.last_time = float(runs[0].time14)
		model.loop = not (int(runs[0].flagsC) & 1)

func adopt_entities(source, ids: Array) -> void:
	for id in ids:
		if not source.entities.has(id):
			continue
		native_skin_publishers.erase(id)
		entities[id] = source.entities[id]
		for key in entities[id].counts:
			stats[key] += entities[id].counts[key]
	for channel in source.stats.unsupported_channels:
		if not stats.unsupported_channels.has(channel):
			stats.unsupported_channels.append(channel)

func _model(root: Node3D, nodes: Array[Node3D], source: Dictionary, asset: Dictionary) -> Dictionary:
	if asset.clips.is_empty():
		return {"player": null, "names": {}, "clip": "", "loop": false, "speed": 1.0}
	var player := AnimationPlayer.new()
	root.add_child(player)
	player.root_node = NodePath("..")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	var names: Dictionary = {}
	var deferred: Dictionary = {}
	var defaults: Array = source.get("defaults", asset.defaults)
	var indexed_lazy: bool=use_prepared_clips and bool(asset.get("lazyClips",false)) and asset.get("clipIndex") is Dictionary
	# _clip_resource only reads this immutable source map; the bound tracks,
	# AnimationLibrary, event copies and playback clocks remain private.
	var controlled: Dictionary = asset.controlled if indexed_lazy and asset.has("controlled") else asset.get("controlled", {}).duplicate(true)
	for clip in ([] if asset.has("controlled") else asset.clips):
		for channel in clip.tracks:
			var key := str(int(channel.part)) + ":" + str(channel.property)
			var previous: Dictionary = controlled.get(key, {})
			controlled[key] = {"part": int(channel.part), "property": str(channel.property), "bezier": previous.get("bezier", false) or channel.get("sourceInterpolation") == "bezier"}
	for clip in ([] if indexed_lazy else asset.clips):
		if asset.get("lazyClips", false): deferred[str(clip.name)] = clip; continue
		var name := "clip_%s" % names.size()
		library.add_animation(name, _clip_resource(root, nodes, source, defaults, controlled, clip))
		names[str(clip.name)] = name
		stats.clips += 1
	player.add_animation_library("", library)
	stats.players += 1
	for unsupported in asset.get("unsupported", []):
		if not stats.unsupported_channels.has(unsupported):
			stats.unsupported_channels.append(unsupported)
	var event_map := {}
	var transitions := {}
	for clip in ([] if indexed_lazy else asset.clips):
		event_map[str(clip.name)] = clip.get("events", []).duplicate(true)
		transitions[str(clip.name)] = float(clip.get("transition", 0.0))
	var model := {"player": player, "names": names, "clip": "", "loop": false, "follow": source.get("follow", true), "speed": float(source.get("speed", 1.0)), "events": event_map, "transitions": transitions, "play_serial": 0, "last_time": float(source.get("time", 0.0))}
	if indexed_lazy: model["indexed_asset"]=asset; stats.indexed_clip_models+=1
	if indexed_lazy or not deferred.is_empty():
		if not indexed_lazy: model["deferred"] = deferred
		model["clip_builder"] = {"root": root, "nodes": nodes, "source": source, "defaults": defaults, "controlled": controlled, "library": library}
	_play(model, str(source.get("clip", "")), bool(source.get("loop", true)), model.speed, float(source.get("time", 0.0)))
	return model

func _clip_resource(root: Node3D, nodes: Array[Node3D], source: Dictionary, defaults: Array, controlled: Dictionary, clip: Dictionary) -> Animation:
	var animation := Animation.new()
	animation.length = maxf(0.001, float(clip.length))
	var channels: Dictionary = {}
	for channel in clip.tracks: channels[str(int(channel.part)) + ":" + str(channel.property)] = channel
	for channel_key in controlled:
		var part := int(controlled[channel_key].part)
		var property: String = controlled[channel_key].property
		var target_path: String
		var property_path: String
		if source.has("skeleton_target"):
			var skeleton_path:=str(root.get_path_to(source.skeleton_target))
			target_path=skeleton_path+":part_"+str(source.parts[part])
			property_path=skeleton_path+":bones/"+str(source.parts[part])+"/"+property
		else:
			var node: Node3D = nodes[int(source.parts[part])]
			target_path=str(root.get_path_to(node)); property_path=target_path+":"+property
		var channel: Dictionary = channels.get(channel_key, {"keys": [{"time": 0.0, "value": defaults[part][property]}], "sourceInterpolation": "linear"})
		var keys: Array = preload("res://systems/native_data/packed_animation_keys.gd").keys(channel)
		if controlled[channel_key].bezier and property != "quaternion":
			for axis in 3:
				var track := animation.add_track(Animation.TYPE_BEZIER)
				animation.track_set_path(track, NodePath(property_path + ":" + ["x", "y", "z"][axis]))
				for index in keys.size():
					var key: Dictionary = keys[index]
					var time := float(key.time)
					var value_at_key := float(key.value[axis])
					var incoming := Vector2.ZERO
					var outgoing := Vector2.ZERO
					if index > 0:
						incoming.x = -(time - float(keys[index - 1].time)) / 3.0
						incoming.y = float(key["in"][axis]) if channel.sourceInterpolation == "bezier" else (float(keys[index - 1].value[axis]) - value_at_key) / 3.0
					if index + 1 < keys.size():
						outgoing.x = (float(keys[index + 1].time) - time) / 3.0
						outgoing.y = float(key.out[axis]) if channel.sourceInterpolation == "bezier" else (float(keys[index + 1].value[axis]) - value_at_key) / 3.0
					animation.bezier_track_insert_key(track, time, value_at_key, incoming, outgoing)
			continue
		var type := Animation.TYPE_POSITION_3D if property == "position" else (Animation.TYPE_ROTATION_3D if property == "quaternion" else Animation.TYPE_SCALE_3D)
		var track := animation.add_track(type)
		animation.track_set_path(track, NodePath(target_path))
		for key in keys: animation.track_insert_key(track, float(key.time), _quat(key.value) if property == "quaternion" else _vec(key.value))
	return animation

func _deferred_clip(model: Dictionary,name: String) -> Dictionary:
	if model.has("indexed_asset"):
		var asset: Dictionary=model.indexed_asset
		return asset.clips[int(asset.clipIndex[name])] if asset.clipIndex.has(name) else {}
	return model.get("deferred",{}).get(name,{})

func _play(model: Dictionary, name: String, loop: bool, speed: float, time: float = 0.0, restart: bool = false) -> void:
	var deferred_clip: Dictionary=_deferred_clip(model,name) if not model.names.has(name) else {}
	if not model.names.has(name) and not deferred_clip.is_empty():
		var builder: Dictionary = model.clip_builder
		var prepared_key := "clip_%s" % model.names.size()
		builder.library.add_animation(prepared_key, _clip_resource(builder.root, builder.nodes, builder.source, builder.defaults, builder.controlled, deferred_clip))
		model.names[name] = prepared_key
		if model.has("indexed_asset"):
			model.events[name]=deferred_clip.get("events",[]).duplicate(true)
			model.transitions[name]=float(deferred_clip.get("transition",0.0))
			stats.indexed_clip_metadata+=1
			if model.has("entity_counts"): model.entity_counts.indexed_clip_metadata+=1
		stats.clips += 1
		if model.has("entity_counts"): model.entity_counts.clips += 1
	if not model.names.has(name):
		return
	var player: AnimationPlayer = model.player
	var key: String = model.names[name]
	if model.clip != name or model.loop != loop:
		player.get_animation(key).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	player.speed_scale = speed
	if model.clip != name or model.loop != loop or restart:
		model.play_serial = int(model.get("play_serial", 0)) + 1
		player.play(key, maxf(0.0, float(model.get("transitions", {}).get(name, 0.0))) if restart else 0.0)
		player.seek(time, true)
		model.last_time = time
	model.clip = name
	model.loop = loop
	model.speed = speed

func set_animation(id: int, animation: int, speed: float = 1.0) -> void:
	set_playback(id, animation, speed)

func clip_name(id: int, animation: int, side: int = -1) -> String:
	if not entities.has(id):
		return ""
	var entry: Dictionary = entities[id]
	var chosen := int(entry.side) if side < 0 else side
	return str(entry.side_maps.get(str(chosen), entry.clip_map).get(str(animation), ""))

func set_playback(id: int, animation: int, speed: float = 1.0, loop_override: Variant = null, restart: bool = false, side: int = -1) -> void:
	if not entities.has(id):
		return
	var entry: Dictionary = entities[id]
	if side >= 0:
		entry.side = side
	var name := clip_name(id, animation)
	if name.is_empty():
		return
	var loop: bool = entry.loop_map.get(str(animation), animation not in [5, 6, 7, 8, 9]) if loop_override == null else bool(loop_override)
	for model_index in entry.animated_models if entry.has("animated_models") else range(entry.models.size()):
		var model: Dictionary=entry.models[int(model_index)]
		if not model.get("follow", false):
			continue
		if not model.names.has(name) and _deferred_clip(model,name).is_empty() and not model.names.is_empty():
			var missing := "%s/%s/%s" % [id, animation, name]
			if not stats.missing_requested_clips.has(missing):
				stats.missing_requested_clips.append(missing)
		_play(model, name, loop, speed, 0.0, restart)
	entry.animation = animation

func clip_length(id: int, animation: int, side: int = -1) -> float:
	if not entities.has(id):
		return 0.0
	var entry: Dictionary = entities[id]
	var name := clip_name(id, animation, side)
	for model in entry.models:
		var deferred_clip: Dictionary=_deferred_clip(model,name) if model.get("follow",false) else {}
		if not deferred_clip.is_empty(): return maxf(0.001, float(deferred_clip.length))
		if model.get("follow", false) and model.names.has(name):
			return model.player.get_animation(model.names[name]).length
	return 0.0

func _skin(mesh: MeshInstance3D, source: Dictionary, parts: Array) -> Dictionary:
	var skeleton := Skeleton3D.new()
	mesh.get_parent().add_child(skeleton)
	var bind := Skin.new()
	var bones: Array[int] = []
	var inverses: Array[Transform3D] = []
	var accumulated: Dictionary = {}
	var root_seen := false
	var stopped := false
	for slot in 64:
		skeleton.add_bone("slot_%s" % slot)
		skeleton.set_bone_rest(slot, Transform3D.IDENTITY)
		var part := int(source.slots[slot]) if slot < source.slots.size() else -1
		if stopped:
			part = -1
		if part == 0:
			if root_seen:
				part = -1
				stopped = true
			else:
				root_seen = true
		var inverse := Transform3D.IDENTITY
		if part >= 0 and part < parts.size():
			var q: Array = source.inverseQuaternions[part]
			var p: Array = source.inversePositions[part]
			var step := Transform3D(Basis(Quaternion(float(q[1]), float(q[3]), -float(q[2]), float(q[0]))), Vector3(float(p[0]), float(p[2]), -float(p[1])))
			inverse = accumulated.get(part, Transform3D.IDENTITY) * step
			accumulated[part] = inverse
		bones.append(int(parts[part]) if part >= 0 and part < parts.size() else -1)
		inverses.append(inverse)
		bind.add_bind(slot, inverse)
	skeleton.add_bone("unweighted")
	skeleton.set_bone_rest(64, Transform3D.IDENTITY)
	bind.add_bind(64, Transform3D.IDENTITY)
	var rebuilt := ArrayMesh.new()
	var groups: Array = source.groups if not source.groups.is_empty() else [{"start": 0, "count": source.position.size() / 3, "materialIndex": 0}]
	var vertex_count := int(source.position.size() / 3)
	var prepared: Dictionary=source.get("native_upload",{})
	var use_prepared: bool=source.groups.is_empty() and str(prepared.get("revision",""))==SkinPreparation.REVISION
	if use_prepared:
		var invalid: bool=prepared.invalid_weights
		for slot in prepared.used_slots:
			if int(slot)<0 or int(slot)>=bones.size() or bones[int(slot)]<0: invalid=true
		if invalid:
			_fail("A native skin weight/slot needs an explicit nonstandard-weight adapter"); return {}
		stats.skin_prepared_meshes+=1
	else: stats.skin_main_meshes+=1
	for surface in groups.size():
		var group: Dictionary = groups[surface]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		var positions := PackedVector3Array()
		var normals := PackedVector3Array()
		var uv := PackedVector2Array()
		var indices := PackedInt32Array()
		var weights := PackedFloat32Array()
		if use_prepared:
			positions=prepared.positions; normals=prepared.normals; uv=prepared.uv; indices=prepared.bones; weights=prepared.weights
		for vertex in ([] if use_prepared else range(int(group.start), int(group.start + group.count))):
			positions.append(Vector3(float(source.position[vertex * 3]), float(source.position[vertex * 3 + 1]), float(source.position[vertex * 3 + 2])))
			normals.append(Vector3(float(source.normal[vertex * 3]), float(source.normal[vertex * 3 + 1]), float(source.normal[vertex * 3 + 2])))
			uv.append(Vector2(float(source.uv[vertex * 2]), float(source.uv[vertex * 2 + 1])))
			var total := 0.0
			for component in 4:
				total += maxf(0, float(source.weights[vertex * 4 + component]))
			for component in 4:
				var weight := maxf(0, float(source.weights[vertex * 4 + component]))
				var index := int(source.bones[vertex * 4 + component])
				if weight > 1.0 or weight > 0.0 and (index < 0 or index >= bones.size() or bones[index] < 0):
					_fail("A native skin weight/slot needs an explicit nonstandard-weight adapter")
					return {}
				indices.append(64 if total == 0.0 or weight == 0.0 else index)
				weights.append((1.0 if component == 0 else 0.0) if total == 0.0 else weight)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_BONES] = indices
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		rebuilt.surface_set_material(surface, mesh.get_active_material(surface))
	mesh.mesh = rebuilt
	mesh.skin = bind
	mesh.skeleton = mesh.get_path_to(skeleton)
	mesh.custom_aabb = rebuilt.get_aabb().grow(maxf(1.0, rebuilt.get_aabb().size.length()))
	stats.skin_meshes += 1
	stats.skin_vertices += vertex_count
	return {"mesh": mesh, "skeleton": skeleton, "bones": bones, "inverse": inverses, "part": int(parts[int(source.part)]), "source": source}

func _process(delta: float) -> void:
	var began:=FrameProfile.begin()
	_profile_process(delta)
	FrameProfile.finish("callback_rigs",began)
func _profile_process(delta: float) -> void:
	_update(delta)

func _exit_tree() -> void:
	native_skin_publishers.clear()
	var began:=FrameProfile.begin()
	for entry in entities.values():
		for model in entry.models:
			if model.has("native_owner"): model.native_owner.close()
	FrameProfile.finish("rig_exit_close_ms",began)

static func model_events(events: Array, from: float, to: float, flags: int = 0) -> Array:
	from = Color(from,0,0,0).r if scalar_values else PackedFloat32Array([from])[0]
	to = Color(to,0,0,0).r if scalar_values else PackedFloat32Array([to])[0]
	var result: Array = []
	if flags & 2:
		from = -1e9
		to = 1e9
		flags &= ~2
	if flags & 1:
		if to > from:
			result.append_array(model_events(events, from, -1e9, flags))
			from = 1e9
		for i in range(events.size() - 1, -1, -1):
			var time: float = Color(float(events[i].time),0,0,0).r if scalar_values else PackedFloat32Array([float(events[i].time)])[0]
			if time >= to and from > time:
				result.append(str(events[i].name))
	else:
		if from > to:
			result.append_array(model_events(events, from, 1e9, flags))
			from = -1e9
		for event in events:
			var time: float = Color(float(event.time),0,0,0).r if scalar_values else PackedFloat32Array([float(event.time)])[0]
			if to >= time and time > from:
				result.append(str(event.name))
	return result

func _update(delta: float) -> void:
	for id in entities.keys():
		var entry: Dictionary = entities[id]
		var phase_began:=FrameProfile.begin()
		var emitted: Array = []
		for model_index in entry.animated_models if entry.has("animated_models") else range(entry.models.size()):
			var model: Dictionary = entry.models[model_index]
			if model.has("native_owner"):
				model.native_owner.advance(delta)
				_native_clock(model)
				for event in model.native_owner.events:
					emitted.append({"name": event, "serial": int(model.get("play_serial", 0)), "model": model, "index": model_index})
				model.native_owner.events.clear()
				continue
			if model.player != null:
				var player: AnimationPlayer = model.player
				if not player.is_playing() or player.current_animation.is_empty():
					player.advance(delta)
					continue
				var before: float = player.current_animation_position
				var length: float = player.current_animation_length
				var serial := int(model.get("play_serial", 0))
				player.advance(delta)
				var after: float = player.current_animation_position if player.is_playing() and not player.current_animation.is_empty() else (length if model.speed >= 0 else 0.0)
				model.last_time = after
				for event in model_events(model.get("events", {}).get(model.clip, []), before, after, 1 if model.speed < 0 else 0):
					emitted.append({"name": event, "serial": serial, "model": model, "index": model_index})
		# Native Part60 gates the entire part's control while its children still
		# animate. Apply saved manual fields before events/attachments/skin work.
		for index in entry.manual_poses:
			var manual: Dictionary = entry.manual_poses[index]
			entry.nodes[index].position = manual.position
			entry.nodes[index].quaternion = manual.quaternion
			entry.nodes[index].scale = manual.scale
		for event in emitted:
			if int(event.model.get("play_serial", -1)) == int(event.serial):
				model_event.emit(int(id), int(event.index), str(event.name), int(event.serial))
				if event.model.get("event_source", false):
					animation_event.emit(int(id), str(event.name), int(event.serial))
		FrameProfile.finish("actor_animation",phase_began)
		phase_began=FrameProfile.begin()
		sync_attachments(int(id))
		FrameProfile.finish("actor_attachments",phase_began)
		if entry.skins.is_empty():
			continue
		phase_began=FrameProfile.begin()
		var native_skin_result: Variant=_publish_skin_native(int(id),entry)
		if native_skin_result is int and int(native_skin_result)!=1:
			FrameProfile.finish("actor_skin",phase_began)
			if int(native_skin_result)>1:return
			continue
		var rigid: Array[Transform3D] = []
		var skin_rows: Array=entry.skins
		var skin_start: int=0
		if native_skin_result is Dictionary:
			rigid.assign(native_skin_result.rigid);skin_rows=native_skin_result.skins;skin_start=int(native_skin_result.start)
		else:
			for index in entry.nodes.size():
				var node: Node3D = entry.nodes[index]
				var local := Transform3D(Basis(node.quaternion), node.position)
				var parent := int(entry.parents[index])
				rigid.append(local if parent == -1 else rigid[parent] * local)
		var skin_cursor: int=0
		for skin in skin_rows:
			if skin_cursor<skin_start:
				skin_cursor+=1;continue
			skin_cursor+=1
			var inverse: Transform3D = rigid[skin.part].affine_inverse()
			var skeleton: Skeleton3D = skin.skeleton
			for slot in skin.bones.size():
				var index := int(skin.bones[slot])
				var transform: Transform3D = Transform3D.IDENTITY if index < 0 else inverse * rigid[index]
				skeleton.set_bone_pose_position(slot, transform.origin)
				skeleton.set_bone_pose_rotation(slot, transform.basis.get_rotation_quaternion())
				skeleton.set_bone_pose_scale(slot, Vector3.ONE)
			skeleton.force_update_all_bone_transforms()
		FrameProfile.finish("actor_skin",phase_began)
	stats.pose_frames += 1

func _vec(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func diagnostic_sample(ids: Array = [],include_skins: bool=true) -> Dictionary:
	# Explicit regression probe only. Production animation never reads GPU
	# geometry back; these arrays stay in memory and only deltas enter reports.
	var sample := {"nodes": {}, "skins": {}, "clocks": {}}
	for id in entities:
		if not ids.is_empty() and not ids.has(id):
			continue
		var entry: Dictionary = entities[id]
		for index in entry.nodes.size():
			sample.nodes[str(id) + ":" + str(index)] = entry.nodes[index].transform
		for index in entry.models.size():
			var player: AnimationPlayer = entry.models[index].player
			if player != null and player.is_playing():
				sample.clocks[str(id) + ":" + str(index)] = {"clip": entry.models[index].clip, "time": player.current_animation_position}
		if not include_skins: continue
		for index in entry.skins.size():
			var mesh: MeshInstance3D = entry.skins[index].mesh
			var baked := mesh.bake_mesh_from_current_skeleton_pose()
			var vertices := PackedVector3Array()
			for surface in baked.get_surface_count():
				vertices.append_array(baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			sample.skins[str(id) + ":" + str(index)] = vertices
	return sample

func compare_samples(before: Dictionary, after: Dictionary) -> Dictionary:
	var changed_nodes := 0
	var changed_clocks := 0
	var vertex_delta := 0.0
	for key in before.get("nodes", {}):
		if after.nodes.has(key) and not before.nodes[key].is_equal_approx(after.nodes[key]):
			changed_nodes += 1
	for key in before.get("clocks", {}):
		if after.clocks.has(key) and (before.clocks[key].clip != after.clocks[key].clip or absf(float(before.clocks[key].time) - float(after.clocks[key].time)) > 0.0001):
			changed_clocks += 1
	for key in before.get("skins", {}):
		if not after.skins.has(key):
			continue
		var a: PackedVector3Array = before.skins[key]
		var b: PackedVector3Array = after.skins[key]
		for index in mini(a.size(), b.size()):
			vertex_delta = maxf(vertex_delta, a[index].distance_to(b[index]))
	var active_clips: Array = []
	for key in after.clocks:
		active_clips.append({"model": key, "clip": after.clocks[key].clip, "time": after.clocks[key].time})
	var requested: Array = []
	for id in entities:
		requested.append({"id": id, "animation": entities[id].animation, "clip": entities[id].clip_map.get(str(entities[id].animation), "")})
	return {"changed_local_parts": changed_nodes, "advanced_model_clocks": changed_clocks, "maximum_local_skin_vertex_delta": vertex_delta, "skin_meshes_sampled": before.get("skins", {}).size(), "pose_frames": stats.pose_frames, "active_clips": active_clips, "requested": requested, "missing_requested_clips": stats.missing_requested_clips}

func _quat(value: Array) -> Quaternion:
	return Quaternion(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

func _fail(message: String) -> void:
	stats.failures.append(message)
	push_error(message)
