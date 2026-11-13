extends SceneTree
# Actual installed source -> native worker preparation -> physical rig. No
# renderer frames, original client attach, public/local server or optimistic state.
const Catalog = preload("res://systems/native_data/resource_catalog.gd")
const Assets = preload("res://systems/native_data/asset_service.gd")
const Store = preload("res://systems/native_data/preparation_store.gd")
const Pool = preload("res://systems/native_render/resource_pool.gd")
const Placeable = preload("res://systems/native_render/placeable_instance.gd")
var checks := 0
var failures: Array = []
var completed: Dictionary = {}
func check(value: bool, label: String) -> void:
	checks += 1
	if not value and failures.size() < 30: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := ""
	var install_path := ""
	var cache_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output = argument.substr(9)
		elif argument.begins_with("--install="): install_path = argument.substr(10)
		elif argument.begins_with("--cache="): cache_path = argument.substr(8)
	if output.is_empty() or install_path.is_empty() or cache_path.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog := Catalog.new()
	check(catalog.mount_install(install_path), "installed original catalog mounts read-only")
	if catalog.layers.is_empty(): quit(3); return
	catalog.decoder_store = Store.new()
	var service := Assets.new()
	root.add_child(service)
	service.maximum_workers = 1
	service.cache_directory = cache_path
	service.configure(catalog)
	service.completed.connect(func(id, result): completed[id] = result)
	var request: int = service.request("pwc_block_01", 2002, "actor-model", {"relevant_tracks": true})
	check(request >= 0, "original blocker actor-model request accepted")
	var deadline := Time.get_ticks_msec() + 30000
	while request >= 0 and not completed.has(request) and Time.get_ticks_msec() < deadline: await process_frame
	check(completed.has(request), "bounded original worker completes")
	var bundle: Dictionary = completed.get(request, {})
	check(not bundle.is_empty() and str(bundle.get("error", "missing")).is_empty(), "actual blocker model decodes: " + str(bundle.get("error")))
	var snapshot: Dictionary = {}
	if not bundle.is_empty() and str(bundle.get("error", "missing")).is_empty():
		var model: Dictionary = bundle.value
		var plane_index := -1
		for index in model.nodes.size():
			var mesh: Dictionary = model.nodes[index].get("mesh", {})
			if not mesh.is_empty() and mesh.get("render", false) and not mesh.get("indices", PackedInt32Array()).is_empty():
				check(plane_index == -1, "original blocker has one rendered source plane")
				plane_index = index
		check(plane_index >= 0, "actual source rendered plane identified without name heuristic")
		var pool := Pool.new()
		pool.unshaded = true
		var instance := Placeable.new()
		root.add_child(instance)
		var state := {"animation": 74, "animationTime": 1.0}
		var original := state.duplicate(true)
		check(Placeable.requires_animation(state), "received74 requires physical animation owner")
		check(not Placeable.requires_animation({"animation": 0}) and not Placeable.requires_animation({}), "ordinary default/absent state retains static path")
		check(instance.install_placeable(bundle, pool, 43000, state), "actual original actor installs: " + instance.failure)
		if is_instance_valid(instance.rigs) and plane_index >= 0:
			instance.rigs.set_process(false)
			instance.rigs._update(0.0)
			var entry: Dictionary = instance.rigs.entities[43000]
			var part: Node3D = instance.rigs.node_at(43000, int(entry.model_parts[0][plane_index]))
			check(entry.models[0].clip == "off", "initial received74 selects original OFF before publication")
			check(absf(part.position.y - (-10.95)) < 0.00001, "actual original OFF lowers plane to nativeZ-10.95")
			var serial: int = entry.models[0].play_serial
			instance.observe_placeable(state)
			instance.observe_placeable({"lightOn": false})
			check(entry.models[0].play_serial == serial, "repeated/unrelated deltas do not restart clip")
			instance.observe_placeable({"animation": 73})
			instance.rigs._update(0.0)
			check(entry.models[0].clip == "on" and absf(part.position.y - 0.05) < 0.00001, "received73 samples actual ON at nativeZ+.05")
			instance.observe_placeable({"animation": 74})
			instance.rigs._update(0.0)
			check(entry.models[0].clip == "off" and absf(part.position.y + 10.95) < 0.00001, "received74 returns to authored OFF")
			check(state == original, "presentation never mutates received state")
			check(instance.identified_blocker,"diagnostic blocker category requires exact original resource/hash")
			instance.set_show_blockers(true);instance.rigs._update(0.0)
			check(absf(part.position.y-0.05)<0.00001 and instance.received_animation==74,"explicit diagnostic shows verified helper without changing received OFF")
			instance.set_show_blockers(false);instance.rigs._update(0.0)
			check(absf(part.position.y+10.95)<0.00001 and state==original,"diagnostic off restores authored OFF and leaves received state intact")
			var changed_bundle:=bundle.duplicate();changed_bundle.sha256="other-server-content"
			check(not preload("res://systems/native_data/blocker_helper.gd").identified(changed_bundle),"same resource name with other server content is not classified")
			check(instance.placeable_stats.missing_clips.is_empty(), "actual requested OFF/ON clips exist")
			snapshot = instance.snapshot_placeable()
			snapshot.stats.updates = -100
			check(instance.placeable_stats.updates >= 0, "snapshot detached")
			snapshot = instance.snapshot_placeable()
			var old_updates: int = instance.placeable_stats.updates
			instance.retire()
			instance.observe_placeable({"animation": 73})
			check(instance.placeable_stats.updates == old_updates, "retired lifetime rejects late update")
		else: instance.retire()
		await process_frame
		pool.clear()
	service.close()
	service.free()
	await process_frame
	await process_frame
	var report := {"checks": checks, "failures": failures, "snapshot": snapshot, "source": {"resource": "pwc_block_01", "sha256": bundle.get("sha256"), "animation_sources": bundle.get("animation_sources", [])}, "scope": "Actual installed source/worker/physical rig OFF and ON; no world-stream binding, public server, GPU or general transition-rest policy"}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
