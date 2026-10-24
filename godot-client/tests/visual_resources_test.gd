extends SceneTree

const Resources = preload("res://systems/visual_resources.gd")
var checks := 0
var failures: Array = []
var output := ""

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)

func ids(node: Node) -> Array:
	var result: Array = [node.get_instance_id()]
	for child in node.get_children():
		result.append_array(ids(child))
	return result

func run() -> void:
	var source_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-report="):
			source_path = arg.substr(16)
		elif arg.begins_with("--report="):
			output = arg.substr(9)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	var envelope: Dictionary = source.get("visualDefinition", {})
	var cache := Resources.new()
	cache.configure(envelope.get("live", {}))
	var definition: Dictionary = cache.prepare_definition(str(envelope.get("file", "")), str(envelope.get("sha256", "")))
	expect(source.get("success", false), "Owned-local gameplay/installed-data probe completed")
	expect(not definition.is_empty(), "Authenticated installed effect definition and resources load")
	if definition.is_empty():
		failures.append(cache.error)
		finish(null, cache, {})
		return
	expect(cache.entries.size() == int(envelope.resourceCount), "Native cache retains each resolved original resource once")
	var other_scope: Dictionary = envelope.live.duplicate(true)
	other_scope.generation += 1
	var stale := Resources.new()
	stale.configure(other_scope)
	expect(stale.prepare_definition(envelope.file, envelope.sha256).is_empty() and stale.entries.is_empty() and stale.stats.imports == 0, "Retired definitions are rejected before native resource import")
	expect(cache.prepare_definition(envelope.file, "0".repeat(64)).is_empty(), "Metadata digest protects active table/phase decisions")
	var host := Node3D.new()
	root.add_child(host)
	var owned: Array = []
	for row in definition.state.models88:
		if row == null:
			continue
		var effect = cache.instantiate_model(str(row.resource), host)
		expect(effect != null, "Resolved original geometry slot creates a native private instance")
		if effect != null:
			owned.append(effect)
			effect.visible = false
			expect(effect.find_children("*", "CollisionObject3D", true, false).is_empty(), "Effect instance has no fabricated gameplay collision")
	var before := int(cache.stats.imports)
	expect(cache.prepare_resource("stone", source.visualResource), "Original stone model enters the same resource cache")
	expect(cache.prepare_resource("stone", source.visualResource) and cache.stats.imports == before + 1, "Repeated resource admission reuses its imported prefab")
	var changed: Dictionary = source.visualResource.duplicate(true)
	changed.metadataSha256 = "0".repeat(64)
	expect(not cache.prepare_resource("stone", changed) and cache.entries.has("stone"), "A changed same-name resource cannot replace the admitted world's prefab")
	var first = cache.instantiate_model("stone", host)
	var second = cache.instantiate_model("stone", host)
	expect(first != null and second != null, "Shared original prefab creates two independent instances")
	if first == null or second == null:
		failures.append(cache.error)
		host.free()
		finish(null, cache, {})
		return
	owned.append_array([first, second])
	first.rigs.set_process(false)
	second.rigs.set_process(false)
	second.visible = false
	var first_model: Dictionary = first.rigs.entities[0].models[0]
	var second_model: Dictionary = second.rigs.entities[0].models[0]
	expect(first_model.player != second_model.player, "Cached geometry does not share AnimationPlayer state")
	var name: String = first.meshes.meshes_by_name.keys()[0]
	var first_mesh: MeshInstance3D = first.meshes.meshes_by_name[name]
	var second_mesh: MeshInstance3D = second.meshes.meshes_by_name[name]
	expect(first_mesh.mesh == second_mesh.mesh, "Rigid geometry is shared rather than imported again")
	expect(first_mesh.get_active_material(0).albedo_texture == second_mesh.get_active_material(0).albedo_texture, "Original bitmap resources are shared")
	var clip: String = first_model.names.keys()[0]
	expect(first.play_clip(0, clip, false), "Original clip plays in a cached native instance")
	first.rigs._update(0.25)
	expect(first_model.player.current_animation_position > 0 and not second_model.player.is_playing() and second_model.player.current_animation.is_empty(), "Advancing one instance leaves its cached sibling unchanged")
	var bound := AABB()
	var initialized := false
	for mesh in first.meshes.meshes_by_name.values():
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		bound = bound.merge(box) if initialized else box
		initialized = true
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = bound.get_center() + Vector3(1, 0.6, 1.4).normalized() * maxf(2.0, bound.get_longest_axis_size()) * 1.8
	camera.look_at(bound.get_center())
	camera.current = true
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	environment.environment.ambient_light_sky_contribution = 0.0
	host.add_child(environment)
	cache.clear()
	expect(cache.entries.is_empty() and is_instance_valid(first_mesh.mesh), "Clearing the world cache leaves already-owned instances valid")
	await process_frame
	await RenderingServer.frame_post_draw
	var active := root.get_texture().get_image()
	first.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	var pixels := 0
	for y in active.get_height():
		for x in active.get_width():
			if active.get_pixel(x, y) != hidden.get_pixel(x, y):
				pixels += 1
	expect(pixels > 500, "Cached original geometry/bitmap still reaches Vulkan after cache release")
	active.save_png(output.get_basename() + "-active.png")
	var private_ids: Array = []
	for effect in owned:
		private_ids.append_array(ids(effect))
		effect.retire()
	await process_frame
	await process_frame
	expect(private_ids.all(func(id): return not is_instance_id_valid(id)), "All instantiated model/player/reference owners retire")
	finish(host, cache, {"visualId": definition.state.visualF8, "geometry_slots": definition.state.models88.filter(func(value): return value != null).size(), "original_resource_count": envelope.resourceCount, "changed_pixels": pixels, "retired_native_nodes": private_ids.size(), "retired_native_nodes_alive": private_ids.filter(func(id): return is_instance_id_valid(id)).size()})

func finish(host: Node, cache, details: Dictionary) -> void:
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "Installed visual-definition resource cache and actual native instances; not server effect spawning, phase playback integration or FPS acceptance", "passed": failures.is_empty(), "checks": checks, "failures": failures, "stats": cache.stats, "details": details}, "\t"))
	file.close()
	if host != null:
		host.free()
	quit(0 if failures.is_empty() else 1)
