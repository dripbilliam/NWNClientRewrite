extends SceneTree

const Actor = preload("res://systems/native_render/actor_instance.gd")
const Assets = preload("res://systems/native_data/asset_service.gd")
const Catalog = preload("res://systems/native_data/resource_catalog.gd")
const Pool = preload("res://systems/native_render/resource_pool.gd")
const Targets = preload("res://systems/entity_registry.gd")
const ItemAppearance = preload("res://systems/native_data/item_appearance.gd")

const MODELS = ["c_curst", "c_ogre35"]
const HANDS = ["rhand", "rhand_g", "rhanddummy", "rhand_dummy", "handconjure"]
const STEP := 1.0 / 30.0
const MAX_VERTEX_ERROR := 0.002
const OFFSET := Vector3(10.0, 0.0, 0.0)

var failures: Array[String] = []
var results: Dictionary = {}
var output := ""
var headless := true
var pool = Pool.new()
var service = Assets.new()

func _initialize() -> void:
	run.call_deferred()

func check(accepted: bool, description: String) -> void:
	if not accepted and not failures.has(description):
		failures.append(description)

func finish() -> void:
	if is_instance_valid(service):
		service.close()
		service.free()
	pool.clear()
	var report := {"passed":failures.is_empty(), "failures":failures, "models":results,
		"deformationSource":"published-bone-palette" if headless else "godot-renderer-baked-mesh"}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Could not save skin parity report")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	headless = DisplayServer.get_name() == "headless"
	if args.size() != 2 or not args[0].is_absolute_path() or not args[1].is_absolute_path() or FileAccess.file_exists(args[1]):
		printerr("Pass the original-game installation and a new absolute JSON report path")
		quit(2)
		return
	output = args[1]
	if not headless:
		root.unfocusable = true
	var catalog = Catalog.new()
	if not catalog.mount_install(args[0]):
		check(false, catalog.failure)
		finish()
		return
	catalog.build_resource_index()
	var base_items: Dictionary = service.decode(catalog.get_resource("baseitems", 2017), 2017, "2da", "")
	var planner := ItemAppearance.new()
	var weapon_parts := planner.select(planner.plan({"baseItem":0, "parts":[1, 1, 1]}, {"baseitems":base_items.get("value", {})}), catalog)
	if weapon_parts.is_empty():
		check(false, "An original held weapon model is unavailable: " + planner.failure)
		finish()
		return
	var weapon := str(weapon_parts[0].name)
	root.add_child(service)
	service.configure(catalog)
	pool.unshaded = true
	var jobs: Dictionary = {}
	var bundles: Dictionary = {}
	service.completed.connect(func(id: int, result: Dictionary): bundles[jobs[id]] = result)
	for model: String in MODELS + [weapon]:
		jobs[service.request(model, 2002, "actor-model")] = model
	var deadline := Time.get_ticks_msec() + 30000
	while bundles.size() < jobs.size() and Time.get_ticks_msec() < deadline:
		await process_frame
	for model in jobs.values():
		check(bundles.has(model) and str(bundles.get(model, {}).get("error", "")).is_empty(), "Original actor-model preparation failed: " + model)
	if failures.is_empty():
		for model: String in MODELS:
			await compare_model(model, bundles[model], bundles[weapon])
	finish()

func install_actor(host: Node3D, pieces: Array, maps: Dictionary, id: int, gpu: bool):
	var actor = Actor.new()
	host.add_child(actor)
	actor.position = OFFSET if gpu else Vector3.ZERO
	actor.rotation.y = 0.35
	actor.scale = Vector3.ONE * 1.17
	if not actor.begin_install(pieces, pool, id, maps):
		return actor
	# The staged actor creates the real rig before constructing its meshes.
	# Select the production skin option at that boundary for a paired test.
	while actor.rigs == null and not actor.installation_complete:
		if actor.install_step(1, 0).status != "pending":
			break
	if actor.rigs != null:
		actor.rigs.use_cpu_skin = not gpu
		while actor.install_step(256, 0).status == "pending":
			pass
		actor.rigs.set_process(false)
	return actor

func compare_model(name: String, bundle: Dictionary, weapon: Dictionary) -> void:
	var hand := ""
	var part_names: Array = bundle.value.nodes.map(func(row): return str(row.name).to_lower())
	for candidate: String in HANDS:
		if candidate in part_names:
			hand = candidate
			break
	var clips: Array = bundle.value.rig_asset.get("clips", []).map(func(row): return str(row.name).to_lower())
	var walk := ""
	for candidate: String in ["cwalk", "walk", "crun", "run"]:
		if candidate in clips:
			walk = candidate
			break
	check(not hand.is_empty(), name + " has an original weapon attachment anchor")
	check(not walk.is_empty(), name + " has an original movement animation")
	if hand.is_empty() or walk.is_empty():
		results[name] = {"originalClips":clips, "handCandidates":part_names.filter(func(part): return "hand" in part)}
		return
	var pieces := [{"bundle":bundle, "anchor":"", "follow":true},
		{"bundle":weapon, "anchor":hand, "attachment":"pq", "equipmentSlot":16, "follow":true}]
	var maps := {"0":{"1":walk}}
	var host := Node3D.new()
	root.add_child(host)
	var reference = install_actor(host, pieces, maps, 1, false)
	var candidate = install_actor(host, pieces, maps, 2, true)
	check(reference.installation_complete and candidate.installation_complete,
		name + " installed both original skin paths: " + reference.failure + " " + candidate.failure)
	if not reference.installation_complete or not candidate.installation_complete:
		host.free()
		return
	var cpu: Dictionary = reference.rigs.entities[1]
	var gpu: Dictionary = candidate.rigs.entities[2]
	var skin_count: int = cpu.skins.size()
	var ready: bool = skin_count > 0 and skin_count == gpu.skins.size() and cpu.attachments.size() == 1 and gpu.attachments.size() == 1
	check(ready, name + " has matching installed skins and a held model")
	if not ready:
		host.free()
		return
	var registry = Targets.new()
	host.add_child(registry)
	for actor in [reference, candidate]:
		registry.register_native(actor.object_id, {"type":5, "eligible":true}, actor)
		actor.set_animation(1, 1.0, true)
	var view := Camera3D.new()
	view.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.size = 16.0
	view.far = 50.0
	host.add_child(view)
	view.position = Vector3(5.0, 5.0, 14.0)
	view.look_at(Vector3(5.0, 1.25, 0.0))
	view.current = true

	var evidence := {"clip":walk, "anchor":hand, "skinMeshes":skin_count, "verticesCompared":0,
		"maximumVertexError":0.0, "maximumVertexMovement":0.0, "maximumAttachmentMovement":0.0,
		"maximumTransformError":0.0, "picking":[], "animatedClockTimes":[]}
	var first_vertices: Array = []
	var first_hold := Vector3.ZERO
	for frame in 24:
		reference.rigs._update(STEP)
		candidate.rigs._update(STEP)
		if frame not in [0, 7, 15, 23]:
			continue
		await physics_frame
		await process_frame
		if not headless:
			await RenderingServer.frame_post_draw
		var pose_bounds := AABB()
		var have_bounds := false
		for index in skin_count:
			var old: Dictionary = cpu.skins[index]
			var next: Dictionary = gpu.skins[index]
			var posed: PackedVector3Array = old.pick.vertices
			var deformed := candidate_vertices(next)
			check(not posed.is_empty() and posed.size() == deformed.size(), name + " publishes corresponding weighted vertices")
			if posed.size() != deformed.size() or posed.is_empty():
				continue
			if frame == 0:
				first_vertices.append(posed)
			for vertex in posed.size():
				var expected: Vector3 = old.mesh.global_transform * posed[vertex]
				var actual: Vector3 = next.mesh.global_transform * deformed[vertex] - OFFSET
				evidence.maximumVertexError = maxf(evidence.maximumVertexError, expected.distance_to(actual))
				var bounded: bool = next.mesh.custom_aabb.has_point(deformed[vertex])
				check(bounded, name + " keeps its posed skin inside GPU culling bounds")
				evidence.verticesCompared += 1
				if frame > 0 and first_vertices.size() > index:
					evidence.maximumVertexMovement = maxf(evidence.maximumVertexMovement, posed[vertex].distance_to(first_vertices[index][vertex]))
			var box: AABB = old.mesh.global_transform * old.pick.bounds
			pose_bounds = pose_bounds.merge(box) if have_bounds else box
			have_bounds = true
		var before: Dictionary = reference.rigs.playback_state(1, 0)
		var after: Dictionary = candidate.rigs.playback_state(2, 0)
		check(before == after and before.get("clip") == walk, name + " preserves the original clock and clip")
		evidence.animatedClockTimes.append(float(after.get("time", 0.0)))
		for index in cpu.nodes.size():
			var old_pose: Transform3D = cpu.nodes[index].global_transform
			var new_pose: Transform3D = gpu.nodes[index].global_transform
			new_pose.origin -= OFFSET
			evidence.maximumTransformError = maxf(evidence.maximumTransformError, old_pose.origin.distance_to(new_pose.origin))
			check(old_pose.basis.is_equal_approx(new_pose.basis), name + " preserves the physical node and attachment orientation")
		var held: Node3D = gpu.nodes[int(gpu.attachments[0].node)]
		var anchor: Node3D = gpu.nodes[int(gpu.attachments[0].anchor)]
		check(held.global_position.is_equal_approx(anchor.global_position), name + " retains the animated held-model anchor")
		if frame == 0:
			first_hold = held.global_position
		evidence.maximumAttachmentMovement = maxf(evidence.maximumAttachmentMovement, held.global_position.distance_to(first_hold))
		if have_bounds:
			evidence.picking.append(pick_sample(registry, view, pose_bounds, frame))
	check(evidence.verticesCompared > 0 and evidence.maximumVertexError < MAX_VERTEX_ERROR, name + " CPU and GPU posed geometry agree")
	check(evidence.maximumVertexMovement > 0.01 and evidence.maximumAttachmentMovement > 0.01, name + " actually animates a skin and held model")
	check(evidence.maximumTransformError < 0.0001, name + " preserves the placement of physical nodes and equipment")
	check(evidence.animatedClockTimes.max() - evidence.animatedClockTimes.min() > 0.1, name + " advances the original animation clock")
	check(not evidence.picking.is_empty() and evidence.picking.all(func(sample): return sample.cpuCenter and sample.gpuCenter), name + " remains targetable at the posed body center")
	check(reference.rigs.stats.failures.is_empty() and candidate.rigs.stats.failures.is_empty(), name + " reports no rig publication failures")
	results[name] = evidence
	registry.forget_entity(1)
	registry.forget_entity(2)
	host.free()

func candidate_vertices(skin: Dictionary) -> PackedVector3Array:
	var mesh: MeshInstance3D = skin.mesh
	var vertices := PackedVector3Array()
	if not headless:
		var baked := mesh.bake_mesh_from_current_skeleton_pose()
		if baked != null:
			for surface in baked.get_surface_count():
				vertices.append_array(baked.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		return vertices
	# The dummy renderer cannot read back weighted geometry. Resolve the
	# published Skeleton3D palette with the original weight stream instead.
	var skeleton: Skeleton3D = skin.skeleton
	var source: Dictionary = skin.source
	var palette: Array[Transform3D] = []
	for slot in mesh.skin.get_bind_count():
		palette.append(skeleton.get_bone_global_pose(mesh.skin.get_bind_bone(slot)) * mesh.skin.get_bind_pose(slot))
	for i in range(0, source.position.size(), 3):
		var original := Vector3(source.position[i], source.position[i + 1], source.position[i + 2])
		var weighted := Vector3.ZERO
		var total := 0.0
		for component in 4:
			var at := (i / 3) * 4 + component
			var weight := float(source.weights[at])
			if weight > 0.0:
				weighted += (palette[int(source.bones[at])] * original) * weight
				total += weight
		vertices.append(weighted if total > 0.0 else original)
	return vertices

func pick_sample(registry, view: Camera3D, bounds: AABB, frame: int) -> Dictionary:
	var screen := Rect2(view.unproject_position(bounds.position), Vector2.ZERO)
	for endpoint in 8:
		screen = screen.expand(view.unproject_position(bounds.get_endpoint(endpoint)))
	var eye_shift := view.unproject_position(bounds.get_center() + OFFSET) - view.unproject_position(bounds.get_center())
	var center := view.unproject_position(bounds.get_center())
	var data := {"frame":frame, "cpuCenter":registry.pick(view, center, true, true).get("id", -1) == 1,
		"gpuCenter":registry.pick(view, center + eye_shift, true, true).get("id", -1) == 2,
		"matchedHits":0, "cpuOnlyHits":0, "gpuOnlyHits":0, "sampledRays":0}
	for y in 16:
		for x in 16:
			var sample := screen.position + screen.size * Vector2((x + 0.5) / 16.0, (y + 0.5) / 16.0)
			var cpu_hit: bool = registry.pick(view, sample, true, true).get("id", -1) == 1
			var gpu_hit: bool = registry.pick(view, sample + eye_shift, true, true).get("id", -1) == 2
			if cpu_hit and gpu_hit:
				data.matchedHits += 1
			elif cpu_hit:
				data.cpuOnlyHits += 1
			elif gpu_hit:
				data.gpuOnlyHits += 1
			data.sampledRays += 1
	return data
