extends "res://native_direct_session_world.gd"

const FrameSummary = preload("res://systems/native_render/frame_summary_job.gd")
const PreparedCache = preload("res://systems/native_data/prepared_cache.gd")
const Actor = preload("res://systems/native_render/actor_instance.gd")
const Placeable = preload("res://systems/native_render/placeable_instance.gd")
const Door = preload("res://systems/native_render/door_instance.gd")
const ParticleEmitter = preload("res://systems/native_render/particle_emitter.gd")
const JoinDiagnostics = preload("res://systems/native_render/join_publication_diagnostics.gd")
const ARRIVAL_RADIUS := 0.45
const MAX_FRAME_SAMPLES := 8192
const MAX_WITNESSES := 512
const POINTER_RAYS := 8
const CPU_PICK_COUNTERS := ["cpuCommits", "cpuRefits", "cpuReuses"]
const POINTER_INTERVAL_US := 160000
const POINTER_OFFSETS := [Vector2.ZERO, Vector2(-8, 0), Vector2(8, 0), Vector2.ZERO]
const MAX_ROUTE_LAPS := 12
const STRESS_EVIDENCE_GRACE_US := 6000000
const STRESS_LEVER_APPEARANCES := [22, 23, 26, 27]
const STRESS_PROP_TEXTURES := ["plc_rugdmtlbrk", "plc_creats", "plc_crpsbksrp", "plc_trans",
	"fxpa_flame00", "fxpa_ripple", "fxpa_splash", "plc_test"]

var fixture: Dictionary
var repository_spec: Dictionary
var bench_mode := "validate"
var bench_phase := "cold"
var output := ""
var target := Vector3.ZERO
var port := 0
var idle_ms := 6000
var route_laps := 1
var current_lap: Dictionary
var completed_laps: Array[Dictionary] = []
var deadline := 0
var started := 0
var bench_stage := "startup"
var choice_key := ""
var sample_at := 0
var stage_deadline := 0
var post_route_ready_since := 0
var last_draw := 0
var draw_intervals: Array[float] = []
var draw_count := 0
var capture_started := 0
var window_start: Dictionary
var movement_origin := Vector3.ZERO
var spawn_position := Vector3.ZERO
var checked_tile_models: Dictionary = {}
var terrain_bindings: Dictionary = {}
var terrain_textures: Dictionary = {}
var prop_textures: Dictionary = {}
var prop_bindings: Dictionary = {}
var stress_entry_animations: Dictionary = {}
var stress_route_lever_plays: Dictionary = {}
var pointer_probe := false
var pointer_state: Dictionary = {}
var pointer_cpu_baseline: Dictionary = {}
var next_pointer_ray := 0
var receipt := {"format":"dense-local-client-v1", "success":false, "milestones":{}, "sessionPhases":{}, "nwsyncProgress":{}, "witnesses":[], "windows":{}}

func run() -> void:
	var inputs: Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			inputs[pair[0]] = pair[1]
	output = str(inputs.get("benchmark-receipt", ""))
	bench_mode = str(inputs.get("benchmark-mode", "validate"))
	bench_phase = str(inputs.get("benchmark-phase", "cold"))
	pointer_probe = inputs.get("benchmark-pointer-probe") == "true"
	var route_lap_input := str(inputs.get("benchmark-route-laps", "1"))
	route_laps = route_lap_input.to_int()
	fixture = read_descriptor(str(inputs.get("benchmark-world", "")))
	repository_spec = read_descriptor(str(inputs.get("benchmark-nwsync", "")))
	port = int(fixture.get("port", 0))
	var point: Variant = fixture.get("movementTarget")
	var manifest_hash := str(repository_spec.get("manifestHash", ""))
	var repository_url := str(repository_spec.get("url", ""))
	var ready: bool = output.is_absolute_path() and not FileAccess.file_exists(output) \
		and inputs.get("direct-local-only") == "true" and not inputs.has("direct-host") \
		and bench_mode in ["validate", "frame", "profile"] and bench_phase in ["cold", "warm"] \
		and route_lap_input.is_valid_int() and route_laps >= 1 and route_laps <= MAX_ROUTE_LAPS \
		and (route_laps == 1 or bench_mode == "validate") \
		and (bench_mode == "validate") == (DisplayServer.get_name() == "headless") \
		and port >= 1024 and port <= 65535 and not str(fixture.get("area", "")).is_empty() \
		and valid_point(point) and valid_point(fixture.get("spawn")) \
		and fixture.get("assets") is Array and not fixture.assets.is_empty() and fixture.assets.size() <= MAX_WITNESSES \
		and repository_spec.get("format") == "dense-local-nwsync-v1" and manifest_hash.length() == 40 \
		and repository_url.begins_with("http://127.0.0.1:") and repository_spec.get("entries") is Array
	if not ready:
		printerr("Invalid local benchmark arguments or fixture descriptors")
		quit(2)
		return
	target = Vector3(float(point[0]), float(point[1]), float(point[2]))
	var spawn: Array = fixture.spawn
	spawn_position = Vector3(float(spawn[0]), float(spawn[1]), float(spawn[2]))
	for asset in fixture.assets:
		if int(asset.get("type", -1)) != 3:
			continue
		var role := str(asset.get("role", ""))
		if role in ["prop-texture", "prop-particle-texture"]:
			prop_textures[str(asset.resref)] = {"sha256":str(asset.sha256), "role":role}
		else:
			terrain_textures[str(asset.resref)] = str(asset.sha256)
	idle_ms = clampi(int(inputs.get("benchmark-idle-ms", 6000)), 2000, 30000)
	receipt.mode = bench_mode
	receipt.phase = bench_phase
	receipt.pointerProbe = pointer_probe
	receipt.routeLaps = route_laps
	receipt.laps = completed_laps
	receipt.manifestHash = manifest_hash
	started = Time.get_ticks_usec()
	deadline = started + clampi(int(inputs.get("benchmark-timeout", 180)), 30, 600) * 1000000
	if inputs.get("benchmark-join-diagnostics") == "true":
		JoinDiagnostics.start(started)
	if DisplayServer.get_name() != "headless":
		root.unfocusable = true
	super.run()
	# The ordinary browser does the join. Only its private endpoint allowlist is
	# selected here so the benchmark can coexist with other owned test ports.
	direct_browser_local_port = port

func activate_window_from_click(_event: InputEvent) -> void:
	pass

func read_descriptor(path: String) -> Dictionary:
	if not path.is_absolute_path():
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 16777216:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

func valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(func(v): return (v is float or v is int) and is_finite(float(v)))

func mark(name: String) -> void:
	if not receipt.milestones.has(name):
		receipt.milestones[name] = (Time.get_ticks_usec() - started) / 1000.0

func direct_phase_changed(phase: String) -> void:
	super.direct_phase_changed(phase)
	if not receipt.sessionPhases.has(phase):
		receipt.sessionPhases[phase] = (Time.get_ticks_usec() - started) / 1000.0

func direct_present_area() -> void:
	super.direct_present_area()
	if direct_area_presented and is_instance_valid(world) and is_instance_valid(world.terrain) and not world.terrain.tile_published.is_connected(observe_tile):
		world.terrain.tile_published.connect(observe_tile)
	if JoinDiagnostics.enabled and JoinDiagnostics.owns_area(world) and not world.instance_ready.is_connected(observe_join_publication):
		world.instance_ready.connect(observe_join_publication)

func observe_join_publication(_id: int, source: Dictionary, instance: Node) -> void:
	JoinDiagnostics.published(source, instance)

func stop_join_diagnostics(reason: String) -> void:
	if not JoinDiagnostics.enabled:
		return
	if is_instance_valid(world) and world.instance_ready.is_connected(observe_join_publication):
		world.instance_ready.disconnect(observe_join_publication)
	receipt.joinPublication = JoinDiagnostics.stop(reason)

func observe_tile(index: int, instance: Node3D) -> void:
	var model_name := str(world.terrain.definition.tiles[index].model)
	if checked_tile_models.has(model_name):
		return
	checked_tile_models[model_name] = true
	var bundle: Dictionary = world.terrain.bundles.get(model_name, {})
	for candidate in instance.get("meshes"):
		if not candidate is MeshInstance3D:
			continue
		var source: Dictionary = candidate.get_meta("native_mesh_source", {})
		var name := str(source.get("texture_name", "")).to_lower()
		if not terrain_textures.has(name) or terrain_bindings.has(name):
			continue
		var raster: Dictionary = bundle.get("textures", {}).get(name, {})
		var digest := str(raster.get("sha256", ""))
		if digest != terrain_textures[name] or int(catalog.raster_location(name).get("type", -1)) != 3:
			continue
		var material: Material = candidate.material_override
		var bound: Variant = null
		if material is ShaderMaterial:
			bound = material.get_shader_parameter("native_texture")
		elif material is StandardMaterial3D:
			bound = material.albedo_texture
		var pool = world.terrain.pool
		var cached: Variant = pool.textures.get(pool.template_binding_key(digest))
		if bound is Texture2D and is_same(bound, cached):
			terrain_bindings[name] = {"tile":index, "model":model_name, "sha256":digest}

func direct_resource_progress(detail: Dictionary) -> void:
	super.direct_resource_progress(detail)
	var stage := str(detail.get("phase", ""))
	if stage not in ["server-manifest", "server-content"]:
		return
	var time := (Time.get_ticks_usec() - started) / 1000.0
	var stage_state: Dictionary = receipt.nwsyncProgress.get(stage, {"firstMs":time, "observations":0, "maximumDownloadedBytes":0})
	stage_state.observations += 1
	stage_state.lastMs = time
	stage_state.completed = int(detail.get("completed", 0))
	stage_state.total = int(detail.get("total", 0))
	stage_state.maximumDownloadedBytes = maxi(int(stage_state.maximumDownloadedBytes), int(detail.get("downloadedBytes", 0)))
	receipt.nwsyncProgress[stage] = stage_state

func direct_connection_failed(reason: String) -> void:
	super.direct_connection_failed(reason)
	if bench_stage != "finished":
		finish_benchmark.call_deferred(reason)

func _profile_tick() -> void:
	timeout_check()
	super._profile_tick()
	if closing or bench_stage == "finished":
		return
	var now := Time.get_ticks_usec()
	match bench_stage:
		"startup":
			if not bool(report.get("startup_menu", {}).get("ready", false)):
				return
			mark("mainMenu")
			server_browser.open(false, true)
			if not bool(server_browser.state.get("canJoin", false)):
				finish_benchmark("Local Direct Connect was unavailable")
				return
			bench_stage = "roster"
			mark("joinRequested")
			server_browser.confirm_direct("127.0.0.1:%d" % port, "", [server_browser.connection, server_browser.view_id])
		"roster":
			if direct_session == null or direct_session.phase != "character-selection":
				return
			if str(direct_lobby_state.get("phase", "")) != "character-selection":
				return
			mark("characterRoster")
			var expected_source := str(fixture.get("characterSource", "server" if bool(fixture.get("serverVault", true)) else "installed"))
			var resref := str(fixture.get("characterResref", "fighter" if expected_source == "installed" else ""))
			var choices: Array = direct_lobby_choices.keys().filter(func(key):
				var row: Dictionary = direct_lobby_choices[key]
				return row.get("source") == expected_source and (resref.is_empty() or str(row.get("resref", row.get("catalogStem", ""))) == resref))
			if choices.size() != 1:
				finish_benchmark("Expected one matching fixture character at the native chooser")
				return
			choice_key = str(choices[0])
			bench_stage = "preview"
			if direct_lobby_state.get("selected") != choice_key:
				lobby_request({"kind":"lobby-choose", "key":choice_key, "requestId":7001})
		"preview":
			if direct_lobby_state.get("selected") != choice_key or not direct_lobby_state.get("preview") is Dictionary:
				return
			if direct_lobby_state.preview.has("error"):
				finish_benchmark("Fixture character preview failed")
				return
			mark("characterPreview")
			bench_stage = "world"
			mark("playRequested")
			lobby_request({"kind":"lobby-play", "key":choice_key})
		"world":
			if now < sample_at:
				return
			sample_at = now + 100000
			if not direct_area_presented or direct_session == null or direct_session.phase != "playing" or not is_instance_valid(world):
				return
			if world.ready_for_control() and not graphics_pending:
				if JoinDiagnostics.enabled and not receipt.milestones.has("worldControllable"):
					JoinDiagnostics.controllable()
				mark("worldControllable")
			else:
				return
			if not world.batches.is_empty() or snapshot_commit_running or world.received_snapshot_active():
				return
			mark("worldSettled")
			stop_join_diagnostics("world-settled")
			var entry_error := validate_world()
			if not entry_error.is_empty():
				finish_benchmark(entry_error)
				return
			bench_stage = "settle"
			stage_deadline = now + 1000000
		"settle":
			if now >= stage_deadline:
				bench_stage = "idle"
				begin_window()
		"idle":
			if now - capture_started >= idle_ms * 1000:
				bench_stage = "move-setup"
				if not end_window("idle"):
					return
				# Keep report aggregation out of the movement sampling window.
				stage_deadline = Time.get_ticks_usec() + 200000
			elif pointer_probe:
				sample_pointer(now)
		"move-setup":
			if now < stage_deadline:
				return
			var position: Variant = player_position()
			if not position is Vector3 or position.distance_to(target) < 1.0:
				finish_benchmark("Fixture player was unavailable or too close to the movement target")
				return
			movement_origin = position
			if receipt.has("stressEvidence"):
				receipt.stressEvidence.routeStart = sample_stress_scene("route-start")
			bench_stage = "moving"
			mark("waypointRequested")
			begin_window()
			stage_deadline = now + 25000000
			send_waypoint(target)
		"moving":
			var position: Variant = player_position()
			if position is Vector3 and position.distance_to(movement_origin) > 0.12:
				mark("authoritativeMovement")
			if position is Vector3 and position.distance_to(target) <= ARRIVAL_RADIUS:
				bench_stage = "finish-pending"
				mark("waypointArrived")
				receipt.route = {"from": vector_row(movement_origin), "to": vector_row(target), "arrived": vector_row(position), "distance": movement_origin.distance_to(position)}
				if end_window("movement"):
					current_lap = receipt.route.duplicate()
					current_lap.requestedMs = receipt.milestones.waypointRequested
					current_lap.arrivedMs = receipt.milestones.waypointArrived
					begin_route_return()
			elif now >= stage_deadline:
				finish_benchmark("The server did not move the character to the fixture waypoint")
			elif pointer_probe:
				sample_pointer(now)
		"lap-outbound":
			var position: Variant = player_position()
			if position is Vector3 and position.distance_to(target) <= ARRIVAL_RADIUS:
				current_lap.arrived = vector_row(position)
				current_lap.distance = movement_origin.distance_to(position)
				current_lap.arrivedMs = (now - started) / 1000.0
				begin_route_return()
			elif now >= stage_deadline:
				finish_benchmark("The server did not reach the waypoint on lap %d" % (completed_laps.size() + 1))
		"returning":
			var position: Variant = player_position()
			if position is Vector3 and position.distance_to(spawn_position) <= ARRIVAL_RADIUS:
				mark("returnedToSpawn")
				current_lap.returned = vector_row(position)
				current_lap.returnDistance = position.distance_to(Vector3(
					current_lap.arrived[0], current_lap.arrived[1], current_lap.arrived[2]))
				current_lap.returnedMs = (now - started) / 1000.0
				bench_stage = "post-route-settle"
				post_route_ready_since = 0
				sample_at = now
			elif now >= stage_deadline:
				finish_benchmark("The server did not return the fixture character to spawn")
		"post-route-settle":
			if now < sample_at:
				return
			sample_at = now + 100000
			var pending := post_route_pending()
			receipt.postRoutePending = pending
			if not pending.is_empty():
				post_route_ready_since = 0
			elif post_route_ready_since == 0:
				post_route_ready_since = now
			elif now - post_route_ready_since >= 200000:
				current_lap.settledMs = (now - started) / 1000.0
				current_lap.settledWorld = receipt.postRouteWorld
				completed_laps.append(current_lap)
				if completed_laps.size() == route_laps:
					mark("postRouteSettled")
					if receipt.has("stressEvidence"):
						bench_stage = "stress-evidence"
						stage_deadline = now + STRESS_EVIDENCE_GRACE_US
						sample_at = now
					else:
						finish_benchmark("")
				else:
					# Sustained validation starts each lap with a settled scene
					# and never reopens the single-lap frame timing window.
					movement_origin = player_position()
					current_lap = {"from": vector_row(movement_origin), "to": vector_row(target),
						"requestedMs": (now - started) / 1000.0}
					bench_stage = "lap-outbound"
					stage_deadline = Time.get_ticks_usec() + 25000000
					send_waypoint(target)
		"stress-evidence":
			if now < sample_at:
				return
			if not is_instance_valid(world) or not is_instance_valid(direct_session) or direct_session.phase != "playing":
				finish_benchmark("Stress fixture lost the playing scene before its evidence was complete")
				return
			sample_at = now + 500000
			var sample := sample_stress_scene("after-route")
			var missing := missing_stress_evidence(sample)
			receipt.stressEvidence.afterRoute = sample
			receipt.stressEvidence.missing = missing
			if missing.is_empty():
				mark("stressEvidenceAccepted")
				finish_benchmark("")
			elif now >= stage_deadline:
				finish_benchmark("Stress fixture evidence missing (" + " | ".join(missing) + ")")

func begin_route_return() -> void:
	# Restore the saved character's start before the next lap or owned run.
	bench_stage = "returning"
	stage_deadline = Time.get_ticks_usec() + 25000000
	send_waypoint(spawn_position)

func post_route_pending() -> String:
	var position: Variant = player_position()
	if not position is Vector3 or position.distance_to(spawn_position) > ARRIVAL_RADIUS:
		return "authoritative character position"
	if direct_session.phase != "playing" or not direct_area_presented or graphics_pending or not world.ready_for_control():
		return "world control or graphics"
	if direct_raw_refresh_pending or not direct_raw_deltas.pending.is_empty() or snapshot_preparation.active \
		or not pending_prepared_snapshot.is_empty() or not entry_snapshot_commit.is_empty() \
		or snapshot_commit_running or snapshot_backlog.size() > 0 or world.received_snapshot_active():
		return "snapshot or received deltas"
	if not world.batches.is_empty():
		return "object publication (%d batches)" % world.batches.size()
	var state: Dictionary = world.snapshot(false)
	receipt.postRouteWorld = {"desired":int(state.desired), "instances":int(state.entities), "hidden":int(state.hidden),
		"objectVisualsComplete":bool(state.object_visuals_complete), "environmentAccepted":bool(report.get("environment_accepted", false))}
	if not receipt.postRouteWorld.objectVisualsComplete:
		return "object visuals (%d failed objects)" % world.failed_objects.size()
	if not receipt.postRouteWorld.environmentAccepted:
		return "world environment"
	return ""

func send_waypoint(position: Vector3) -> void:
	world_action({"id":-1, "position":Vector3(position.x, position.z, -position.y), "run":true})

func timeout_check() -> void:
	if started > 0 and not closing and bench_stage != "finished" and Time.get_ticks_usec() > deadline:
		var suffix := " (%s)" % str(receipt.get("postRoutePending", "")) if bench_stage == "post-route-settle" else ""
		if bench_stage == "stress-evidence":
			suffix = " (%s)" % " | ".join(receipt.stressEvidence.get("missing", []))
		finish_benchmark("Timed out at %s%s" % [bench_stage, suffix])

func player_position() -> Variant:
	if not is_instance_valid(direct_session) or not is_instance_valid(world) or direct_session.world_state.area_id != world.area_id:
		return null
	var row: Variant = direct_scene_row(direct_session.world_state.local_object_id)
	var point: Variant = row.get("replicated", {}).get("position") if row is Dictionary else null
	return Vector3(float(point[0]), float(point[1]), float(point[2])) if valid_point(point) else null

func vector_row(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

func validate_world() -> String:
	var area: Dictionary = direct_session.world_state.area
	var resref := str(area.get("resRef", ""))
	if resref.to_lower() != str(fixture.area).to_lower():
		return "Expected area %s, received %s" % [fixture.area, resref]
	var position: Variant = player_position()
	if not position is Vector3 or position.distance_to(spawn_position) > 1.0:
		return "The authoritative player was outside the fixture spawn corridor"
	var manifest: Dictionary = direct_session.content_store.manifest(str(repository_spec.manifestHash))
	if manifest.has("error") or not manifest.get("entries") is Dictionary or manifest.entries.size() != repository_spec.entries.size():
		return "The server's NWSync manifest was not mounted"
	var published: Dictionary = {}
	var manifest_hashes: Dictionary = {}
	for entry in repository_spec.entries:
		published["%s:%d" % [entry.name, int(entry.type)]] = entry
	for entry in manifest.entries.values():
		manifest_hashes[str(entry.get("hash", ""))] = true
	var terrain_witnesses := 0
	for asset in fixture.assets:
		var name := str(asset.get("resref", "")).to_lower()
		var type := int(asset.get("type", -1))
		var key := "%s:%d" % [name, type]
		var binding: Dictionary = catalog.location(name, type)
		var layer: Dictionary = binding.get("layer", {})
		var source := str(layer.get("kind", ""))
		if source not in ["nwsync", "nwsync-erf"]:
			return "Fixture asset resolved outside NWSync: %s" % key
		var bytes: PackedByteArray = catalog.read_resource(name, type)
		var sha256 := PreparedCache.digest(bytes)
		if bytes.is_empty() or sha256 != str(asset.get("sha256", "")):
			return "Fixture asset bytes differ after admission: %s" % key
		var archive_hash := ""
		if source == "nwsync":
			var expected_entry: Dictionary = published.get(key, {})
			var manifest_entry: Dictionary = manifest.entries.get(key, {})
			if expected_entry.is_empty() or str(manifest_entry.get("hash", "")) != str(expected_entry.hash) or int(manifest_entry.get("size", -1)) != int(expected_entry.size) or bytes.size() != int(expected_entry.size) or NWSyncStore.sha1(bytes) != str(expected_entry.hash):
				return "Manifest identity does not match fixture asset %s" % key
		else:
			archive_hash = str(layer.get("source_entry", {}).get("hash", ""))
			if archive_hash.is_empty() or not manifest_hashes.has(archive_hash):
				return "Mounted archive for fixture asset %s was not in the advertised manifest" % key
		var terrain_binding: Dictionary = terrain_bindings.get(name, {})
		var used_in_terrain := str(terrain_binding.get("sha256", "")) == sha256
		if type == 2013:
			used_in_terrain = str(world.terrain.definition.get("set_sha256", "")) == sha256
		if used_in_terrain:
			terrain_witnesses += 1
		receipt.witnesses.append({"resref":name, "type":type, "role":str(asset.get("role", "")), "sha256":sha256, "source":source, "archiveHash":archive_hash, "usedInTerrain":used_in_terrain, "terrainBinding":terrain_binding})
	if terrain_witnesses == 0:
		return "No custom NWSync asset matched a published terrain dependency"
	var received_types: Dictionary = {}
	for row in direct_session.world_state.registry.values():
		if int(row.get("areaId", -1)) == world.area_id and not bool(row.get("replicationRemoved", false)):
			record_type(received_types, int(row.get("objectType", -1)))
	var presented_types: Dictionary = {}
	var primary_rig_types: Dictionary = {}
	var nested_rig_types: Dictionary = {}
	for id in world.instances:
		var instance: Node = world.instances[id]
		if not is_instance_valid(instance) or not world.desired.has(id):
			continue
		var type := int(world.desired[id].object.get("objectType", -1))
		record_type(presented_types, type)
		var pending: Array[Node] = [instance]
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			if node is Actor and is_instance_valid(node.rigs) and node.rigs.is_processing() and node.rigs.can_process():
				record_type(primary_rig_types if node == instance else nested_rig_types, type)
			pending.append_array(node.get_children())
	var snapshot: Dictionary = world.snapshot(false)
	var placement_lights: Dictionary = snapshot.get("placeable_lights", {})
	var focus: Dictionary = world.focus_lighting.renderer_result if is_instance_valid(world.focus_lighting) else {}
	receipt.world = {
		"resref":resref,
		"tiles":world.terrain.definition.tiles.size(),
		"authored":fixture.get("density", {}).get(resref, {}),
		"objectRows":world.desired.size(),
		"instances":world.instances.size(),
		"receivedTypes":received_types,
		"presentedTypes":presented_types,
		"activeRigs":primary_rig_types.values().reduce(func(total, count): return total + count, 0),
		"activePrimaryRigsByType":primary_rig_types,
		"activeNestedRigsByType":nested_rig_types,
		"animatedPlaceables":int(primary_rig_types.get("9", 0)),
		"skins":int(snapshot.get("actor_rigs", {}).get("skin_meshes", 0)),
		"emitters":int(snapshot.get("native_particles", {}).get("emitters", 0)),
		"placementLights":int(placement_lights.get("count", 0)),
		"litInstances":int(focus.get("admitted", 0)),
		"objectVisualsComplete":bool(snapshot.get("object_visuals_complete", false)),
		"failedObjects":world.failed_objects.size(),
		"terrainWitnesses":terrain_witnesses,
		"manifestEntries":manifest.entries.size(),
		"spawn":vector_row(position),
	}
	if int(fixture.get("densityMultiplier", 1)) >= 3:
		receipt.stressEvidence = {"entry":sample_stress_scene("entry"), "propBindings":prop_bindings}
	return ""

func sample_stress_scene(stage: String) -> Dictionary:
	# Sample settled scene owners outside the idle/movement timing windows.
	# The pool key identifies the accepted raster, while the bound texture
	# identity proves a published model actually owns that raster.
	var resident: Dictionary = {}
	for name in prop_textures:
		var digest: String = prop_textures[name].sha256
		var texture: Variant = world.pool.textures.get(world.pool.template_binding_key(digest))
		if texture is Texture2D and is_instance_valid(texture):
			resident[name] = texture
	var sample := {"residentPropTextures":resident.keys(), "placeablePlays":0, "doorTransitions":0,
		"placeablePlaysSinceEntry":0, "doorTransitionsSinceEntry":0, "availableDoorTransitionsSinceEntry":0,
		"leverPlays":0, "leverPlaysSinceRouteStart":0, "placeablesByAppearance":{}, "doorsByType":{}}
	for name in prop_bindings:
		resident.erase(name)
	for id in world.instances:
		var instance: Node = world.instances[id]
		if not is_instance_valid(instance) or not world.desired.has(id):
			continue
		var desired: Dictionary = world.desired[id]
		var object: Dictionary = desired.object
		var type := int(object.get("objectType", -1))
		if type not in [9, 10]:
			continue
		var state: Dictionary = object.get("replicated", {})
		var fixed: Dictionary = object.get("staticState", object.get("lightState", {}))
		var appearance := int(state.get("appearance", fixed.get("appearance", -1))) if type == 9 else int(state.get("doorType", 0))
		if type == 9 and not resident.is_empty():
			observe_prop_bindings(resident, instance, appearance, str(desired.get("model", "")), stage)
		var stats: Dictionary
		var groups: Dictionary
		var family: String
		var action: String
		var total: String
		var door_state := -1
		if instance is Placeable and not instance.retired:
			stats = instance.placeable_stats
			groups = sample.placeablesByAppearance
			family = str(appearance)
			action = "plays"
			total = "placeablePlays"
		elif instance is Door and not instance.retired:
			stats = instance.door_stats
			groups = sample.doorsByType
			family = "generic:%d" % int(state.get("genericType", 0)) if appearance == 0 else "appearance:%d" % appearance
			action = "transitions"
			total = "doorTransitions"
			door_state = instance.received_state
		else:
			continue
		var count := int(stats.get(action, 0))
		var instance_id := instance.get_instance_id()
		if stage == "entry":
			stress_entry_animations[instance_id] = count
		var since_entry := count - int(stress_entry_animations.get(instance_id, count))
		if type == 9 and appearance in STRESS_LEVER_APPEARANCES:
			if stage == "route-start":
				stress_route_lever_plays[instance_id] = count
			sample.leverPlays += count
			sample.leverPlaysSinceRouteStart += count - int(stress_route_lever_plays.get(instance_id, count))
		elif type == 10 and stats.get("missing_clips", []).is_empty():
			sample.availableDoorTransitionsSinceEntry += since_entry
		var group: Dictionary = groups.get(family, {"instances":0, "updates":0, "sinceEntry":0,
			"receivedCodes":{}, "clips":{}, "missingClips":[]})
		group.instances += 1
		group.updates += int(stats.get("updates", 0))
		group[action] = int(group.get(action, 0)) + count
		group.sinceEntry += since_entry
		record_type(group.receivedCodes, int(instance.received_animation))
		if type == 10:
			if not group.has("receivedStates"):
				group.receivedStates = {}
			record_type(group.receivedStates, door_state)
		if is_instance_valid(instance.rigs):
			var playback: Dictionary = instance.rigs.playback_state(int(id), 0)
			var clip := str(playback.get("clip", ""))
			if not clip.is_empty():
				group.clips[clip] = int(group.clips.get(clip, 0)) + 1
		for clip in stats.get("missing_clips", []):
			if not group.missingClips.has(clip):
				group.missingClips.append(clip)
		groups[family] = group
		sample[total] += count
		sample[total + "SinceEntry"] += since_entry
	for witness in receipt.witnesses:
		var name := str(witness.resref)
		if prop_textures.has(name):
			witness.usedByProp = prop_bindings.has(name)
			witness.propBinding = prop_bindings.get(name, {})
	return sample

func missing_stress_evidence(sample: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	if int(sample.availableDoorTransitionsSinceEntry) < 1:
		missing.append("no door transition with an available clip after settled entry")
	if int(sample.leverPlaysSinceRouteStart) < 1:
		missing.append("no authored lever animation play after route start")
	var unbound: Array[String] = []
	for name in STRESS_PROP_TEXTURES:
		if not prop_bindings.has(name):
			unbound.append(name)
	if not unbound.is_empty():
		missing.append("unbound NWSync prop textures " + ", ".join(unbound))
	return missing

func observe_prop_bindings(resident: Dictionary, instance: Node, appearance: int, fallback_model: String, stage: String) -> void:
	var pending: Array[Node] = [instance]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var name := ""
		var mode := ""
		var model := fallback_model
		var bound: Texture2D
		if node is ParticleEmitter:
			name = str(node.original_properties.get("texture", "")).to_lower()
			mode = "emitter-source"
			if not str(node.origin_resource).is_empty():
				model = str(node.origin_resource)
			bound = node.original_texture
		elif node is MeshInstance3D and node.mesh != null:
			var source: Dictionary = node.get_meta("native_mesh_source", {})
			name = str(source.get("texture_name", "")).to_lower()
			mode = "mesh-material"
			model = str(source.get("resource", fallback_model))
			var material: Material = node.material_override
			if material is ShaderMaterial:
				bound = material.get_shader_parameter("native_texture") as Texture2D
			elif material is StandardMaterial3D:
				bound = material.albedo_texture
		var role := "prop-particle-texture" if mode == "emitter-source" else "prop-texture"
		if resident.has(name) and prop_textures[name].role == role and is_same(bound, resident[name]):
			prop_bindings[name] = {"stage":stage, "mode":mode, "appearance":appearance, "model":model,
				"sha256":prop_textures[name].sha256, "visibleInTree":node.is_visible_in_tree()}
			resident.erase(name)
			if resident.is_empty():
				return
		pending.append_array(node.get_children())

func record_type(counts: Dictionary, type: int) -> void:
	var key := str(type)
	counts[key] = int(counts.get(key, 0)) + 1

func begin_window() -> void:
	window_start = {"position": vector_row(player_position()), "cameraPosition":vector_row(camera.global_position), "cameraFov":camera.fov}
	var orientation := camera.global_basis.get_rotation_quaternion()
	window_start.cameraOrientation = [orientation.x, orientation.y, orientation.z, orientation.w]
	if pointer_probe:
		pointer_state = {
			"targets":pointer_targets(), "samples":[], "queries":0, "hitsTarget":0, "hitsOther":0,
			"misses":0, "totalQueryUs":0, "maxQueryUs":0,
			"gpu": {"surfacesAtStart":registry.gpu_skin_pick.surfaces.size() if registry.gpu_skin_pick != null else 0,
				"refits":0, "reuses":0, "boundsMisses":0, "unavailable":0},
		}
		pointer_cpu_baseline.clear()
		var picker = registry.gpu_skin_pick
		for counter in CPU_PICK_COUNTERS:
			pointer_cpu_baseline[counter] = int(picker.stats.get(counter, 0)) if picker != null else 0
	capture_started = Time.get_ticks_usec()
	next_pointer_ray = capture_started + POINTER_INTERVAL_US
	draw_intervals.clear()
	draw_count = 0
	last_draw = 0
	if bench_mode == "profile" and is_instance_valid(frame_profile):
		frame_profile.rows.clear()
		frame_profile.previous = 0
		frame_profile.maximum_rows = MAX_FRAME_SAMPLES

func pointer_aim(actor: Node3D) -> Vector3:
	return actor.to_global(Vector3(0.0, float(actor.get_meta("native_nameplate_height", 1.5)) * 0.55, 0.0))

func pointer_targets() -> Array:
	var ranked: Array = []
	var scene_spawn := Vector3(spawn_position.x, spawn_position.z, -spawn_position.y)
	for id in world.instances:
		var actor: Node = world.instances[id]
		var registered: Dictionary = registry.entities.get(id, {})
		if id == world.controlled_id or not is_instance_valid(actor) or not actor is Actor \
			or registered.get("type", -1) != 5 or not registered.get("eligible", false) \
			or not actor.is_visible_in_tree() or not is_instance_valid(actor.rigs):
			continue
		var entry: Dictionary = actor.rigs.entities.get(id, {})
		if entry.get("skins", []).is_empty() or actor.model_resource_names.is_empty() or not camera.is_position_in_frustum(pointer_aim(actor)):
			continue
		ranked.append({"id":int(id),"model":str(actor.model_resource_names[0]),
			"start":vector_row(actor.global_position),"distanceSq":scene_spawn.distance_squared_to(actor.global_position)})
	ranked.sort_custom(func(a, b): return a.id < b.id if a.distanceSq == b.distanceSq else a.distanceSq < b.distanceSq)
	return ranked.slice(0, 3)

func sample_pointer(now: int) -> void:
	if now < next_pointer_ray or pointer_state.targets.is_empty() or pointer_state.samples.size() >= POINTER_RAYS:
		return
	next_pointer_ray += POINTER_INTERVAL_US
	var index: int = pointer_state.samples.size()
	var rank: int = index % pointer_state.targets.size()
	var id: int = pointer_state.targets[rank].id
	var actor: Node = world.instances.get(id)
	var sample := {"rank":rank, "targetId":id, "sampleMs":(now - capture_started) / 1000.0}
	pointer_state.samples.append(sample)
	if not is_instance_valid(actor) or not actor.is_visible_in_tree():
		sample.skipped = true
		return
	var offset: Vector2 = POINTER_OFFSETS[index % POINTER_OFFSETS.size()]
	var screen: Vector2 = camera.unproject_position(pointer_aim(actor)) + offset
	sample.offset = [offset.x, offset.y]
	var picker = registry.gpu_skin_pick
	var before: Dictionary = picker.stats.duplicate() if picker != null else {}
	var began := Time.get_ticks_usec()
	var hit: Dictionary = registry.pick(camera, screen, false, true, world.controlled_id)
	var elapsed := Time.get_ticks_usec() - began
	if FrameProfile.enabled:
		FrameProfile.record("benchmark_pointer_pick_ms", elapsed / 1000.0)
	sample.hitId = int(hit.get("id", -1))
	pointer_state.queries += 1
	pointer_state.totalQueryUs += elapsed
	pointer_state.maxQueryUs = maxi(pointer_state.maxQueryUs, elapsed)
	if sample.hitId == id:
		pointer_state.hitsTarget += 1
	elif sample.hitId >= 0:
		pointer_state.hitsOther += 1
	else:
		pointer_state.misses += 1
	if picker != null:
		for counter in before:
			pointer_state.gpu[counter] = int(pointer_state.gpu.get(counter,0)) + int(picker.stats[counter]) - int(before[counter])

func record_render_frame() -> void:
	super.record_render_frame()
	if bench_mode == "validate" or bench_stage not in ["idle", "moving"]:
		return
	var now := Time.get_ticks_usec()
	if last_draw > 0:
		draw_count += 1
		if draw_intervals.size() < MAX_FRAME_SAMPLES:
			draw_intervals.append((now - last_draw) / 1000.0)
	last_draw = now

func end_window(name: String) -> bool:
	var window := {"elapsedMs": (Time.get_ticks_usec() - capture_started) / 1000.0, "start":window_start}
	if bench_mode != "validate":
		if draw_intervals.size() < 10 or draw_count > MAX_FRAME_SAMPLES:
			finish_benchmark("Frame window %s was too short or exceeded its sample bound" % name)
			return false
		var sorted := draw_intervals.duplicate()
		sorted.sort()
		var total := 0.0
		for interval in sorted:
			total += interval
		window.drawIntervals = {"samples":sorted.size(), "meanMs":total / sorted.size(), "p95Ms":sorted[ceili(sorted.size() * 0.95) - 1], "maxMs":sorted.back()}
	if bench_mode == "profile":
		if not is_instance_valid(frame_profile) or not FrameProfile.enabled or frame_profile.rows.size() >= MAX_FRAME_SAMPLES:
			finish_benchmark("Detailed in-process profiling was unavailable or exceeded its sample bound")
			return false
		var rows: Array = frame_profile.rows.filter(func(row): return float(row.get("wall_ms", 0.0)) > 0.0)
		window.profile = FrameSummary.calculate(rows)
	if pointer_probe:
		pointer_state.cpu = {}
		var picker = registry.gpu_skin_pick
		for counter in CPU_PICK_COUNTERS:
			var count := int(picker.stats.get(counter, 0)) if picker != null else 0
			pointer_state.cpu[counter] = count - int(pointer_cpu_baseline[counter])
		window.pointerProbe = pointer_state
	receipt.windows[name] = window
	if pointer_probe and pointer_state.queries != POINTER_RAYS:
		finish_benchmark("Pointer workload did not finish %d rays in the %s window" % [POINTER_RAYS, name])
		return false
	return true

func finish_benchmark(reason: String) -> void:
	if bench_stage == "finished":
		return
	bench_stage = "finished"
	stop_join_diagnostics("benchmark-ended")
	receipt.success = reason.is_empty()
	receipt.failure = reason
	var headless := DisplayServer.get_name() == "headless"
	receipt.render = {"headless":headless, "method":RenderingServer.get_current_rendering_method(), "driver":RenderingServer.get_current_rendering_driver_name(), "size":[root.size.x, root.size.y], "maximumFps":Engine.max_fps, "vsync":null if headless else DisplayServer.window_get_vsync_mode(root.get_window_id()), "skinDeformGpu":OS.get_cmdline_user_args().has("--skin-deform=gpu"), "gpuSkinPick":OS.get_cmdline_user_args().has("--gpu-skin-pick=on-demand"), "profiling":FrameProfile.enabled}
	receipt.render.cpuSkinPick = OS.get_cmdline_user_args().has("--cpu-skin-pick=on-demand")
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		report.failure = "Could not write the local benchmark receipt"
	else:
		file.store_string(JSON.stringify(receipt, "\t") + "\n")
		file.close()
		if not reason.is_empty():
			report.failure = reason
	# The fixture never exports the disposable character into a local vault.
	direct_shutdown_export_complete = true
	shutdown.call_deferred()
