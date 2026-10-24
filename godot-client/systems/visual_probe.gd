extends RefCounted

var running := true
var client
var scope: Dictionary
var checks: Array = []
var effect_models: Dictionary = {}

func stop() -> void:
	running = false

func valid() -> bool:
	return running and is_instance_valid(client) and client.world_scope.admitted and client.world_scope.matches(scope) and is_instance_valid(client.effects)

func check(value: bool, label: String) -> void:
	checks.append({"name": label, "passed": value})

func wait_until(predicate: Callable, seconds: float) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while valid() and Time.get_ticks_msec() < until:
		if predicate.call(): return true
		await client.get_tree().process_frame
	return false

func private_vertices(effect_id: int = -1) -> int:
	var total := 0
	for id in client.particles.rows:
		var row: Dictionary = client.particles.rows[id]
		if row.has("visualModel") and (effect_id < 0 or (client.effects.models.has(int(row.visualModel)) and int(client.effects.models[int(row.visualModel)].effect) == effect_id)):
			total += client.particles.surfaces[id].vertex_count
	return total

func effect_released(effect_id: int) -> bool:
	if client.effects.entries.has(effect_id): return false
	for record in client.effects.models.values():
		if int(record.effect) == effect_id: return false
	for row in client.particles.rows.values():
		if int(row.get("visualModel", -1)) in effect_models.get(effect_id, []): return false
	return true

func remember_models(effect_id: int) -> void:
	effect_models[effect_id] = client.effects.models.keys().filter(func(id): return int(client.effects.models[id].effect) == effect_id)

func find_effect(visual: int):
	for entry in client.effects.entries.values():
		if entry.visual == visual and entry.actor == client.controlled_id and entry.runtime != null: return entry
	return null

func run(owner, message: Dictionary) -> void:
	client = owner
	scope = {"connection": client.connection, "areaId": client.area_id, "generation": client.generation, "transferId": client.world_scope.ticket}
	client.command({"kind": "chat", "channel": 1, "text": "-native-vfx"})
	var began: bool = await wait_until(func(): return find_effect(1) != null and private_vertices() > 0, 12)
	check(began, "Actual server duration effect creates native geometry and live private particle vertices")
	var maximum_vertices := private_vertices() if valid() else 0
	var pixels := 0
	var instant_animation := {}
	var audio_result := {}
	if began and valid():
		var entry: Dictionary = find_effect(1)
		var duration_id: int = entry.id
		remember_models(duration_id)
		var model = entry.runtime.state.models88[0]
		var anchor: Node3D = client.model_rigs.node_for(client.controlled_id, 0, "root")
		check(model != null and model.anchor == anchor and model.global_position.distance_to(anchor.global_position) < 0.001, "Original effect attaches to the current native creature root")
		check(model.rigs.entities[0].manual_poses.size() > 0, "Non-oriented visual uses a persistent manual part gate")
		var frame: int = client.particles.stats.frames
		check(await wait_until(func(): return client.particles.stats.frames >= frame + 5, 3), "Shared workers continue original effect simulation after native creation")
		maximum_vertices = maxi(maximum_vertices, private_vertices())
		pixels = await capture(message.screenshot, duration_id)
		check(pixels > 32, "Actual private effect geometry/particles alter Vulkan pixels")
		check(await wait_until(func(): return effect_released(duration_id), 14), "Expired test effect releases its private models while retaining pre-existing buffs")
	check(await wait_until(func(): return client.effects.stats.removed >= 1 and find_effect(1) == null, 14), "Real server duration expiry drives removal, cessation and retirement")
	if not valid(): return
	client.command({"kind": "chat", "channel": 1, "text": "-native-vfxi"})
	check(await wait_until(func(): return find_effect(69) != null, 10), "Actual server instant visual enters the native transient list")
	var instant = find_effect(69)
	if instant != null:
		var instant_id: int = instant.id
		remember_models(instant_id)
		check(instant.runtime.state.models88.any(func(original): return is_instance_valid(original) and original.rigs.entities[0].models[0].has("native_owner")), "Actual installed binary instant effect uses native run/controller playback")
		instant_animation = client.effects.sample().nativeAnimation
		check(instant.transient and instant.runtime.state.durationFc == 0, "Instant routing retains original non-duration phase semantics")
		check(await wait_until(func(): return effect_released(instant_id), 10), "Instant visual retires naturally without a fabricated server removal")
	if not valid(): return
	check(client.particles.stats.failures == 0, "Native particle buffers remain valid across effect creation/removal")
	var point_result := {}
	if message.get("points",false):
		point_result.area = await run_area(message)
		if valid(): point_result.dummy = await run_point(message)
	if message.get("audio",false) and valid():
		audio_result = await run_audio_loop()
		if not valid():return
		client.command({"kind":"chat","channel":1,"text":"-native-sound"})
		check(await wait_until(func():return client.world_audio.history.any(func(row):return int(row.effectId) == 0),8),"Actual server script-sound packet starts positional native output")
		var state: Dictionary = client.world_audio.snapshot()
		check(state.history.any(func(row):return row.profile.priority == 8 and row.effectId == 0),"Actual script sound retains original priority8 source profile")
		check(state.history.any(func(row):return row.name == "sim_heal01" and row.effectId > 0),"Original instant and area visual impact sounds reach native playback")
		check(state.driver == "WASAPI" and state.stats.failed == 0,"Owned live effect/script audio uses WASAPI without failed resource transfers")
		audio_result.final = state
	if not valid(): return
	client.command({"kind": "visual-tested", "result": {"completed": true, "checks": checks, "native": client.effects.sample(), "audio":audio_result, "point":point_result, "instantAnimation": instant_animation, "maximumPrivateVertices": maximum_vertices, "changedPixels": pixels, "screenshot": message.screenshot}})

func run_audio_loop() -> Dictionary:
	var result := {}
	client.command({"kind":"chat","channel":1,"text":"-native-vfxloop"})
	var loop_voice := func():
		for voice in client.world_audio.voices.values():
			if voice.profile.loop and voice.name == "sdr_eleshieldlp" and is_instance_valid(voice.player) and voice.player.playing:return voice
		return null
	check(await wait_until(func():return loop_voice.call() != null,6),"Actual server Elemental Shield VFX starts original native positional looping sound")
	var voice = loop_voice.call()
	if voice == null:return result
	await client.get_tree().create_timer(0.12).timeout
	check(is_instance_valid(voice.player) and voice.player.get_playback_position() > 0,"Original effect audio playback clock advances on the actual native driver")
	check(voice.profile.priority == 11 and voice.profile.positional and voice.profile.volume == 127,"Original effect phase retains native priority/positional/volume defaults")
	var point: Vector3 = client.pivots[client.controlled_id].global_position
	check(client.world_audio.render(voice.position).distance_to(point) < 0.001,"Original duration sound follows native effect actor updates")
	result.duration = client.world_audio.snapshot();result.durationSoundId = voice.id
	check(await wait_until(func():return not client.world_audio.voices.has(voice.id),14),"Real server effect removal stops and destroys its native looping sound")
	return result

func run_point(message: Dictionary) -> Dictionary:
	var canonical_ids: Array = client.pivots.keys()
	var registry_ids: Array = client.owner_scene.registry.entities.keys()
	client.command({"kind":"client-dummy-probe","transferId":client.world_scope.ticket})
	var find_point := func():
		for entry in client.effects.entries.values():
			if not entry.areaVisual and entry.privateToken > 0 and entry.runtime != null: return entry
		return null
	check(await wait_until(func(): return find_point.call() != null,12),"Authored adapter probe routes original invalid-target object visual to private native point host")
	var entry = find_point.call()
	if entry == null: return {"failed":"No native point effect"}
	var id: int = entry.actor;var token: int = entry.privateToken;var effect_id: int = entry.id
	var model = client.client_dummies.host(id,token)
	check(model != null and model.metadata.modelResources[0].to_lower() == "c_dummy","Point host imports original c_dummy and physical anchors")
	check(model != null and model.metadata.counts.meshes == 0,"Original zero-mesh dummy is an invisible private render host")
	var point: Vector3 = client.pivots[client.controlled_id].global_position
	check(model != null and model.global_position.distance_to(point) < 0.2,"Point host preserves actual server location and coordinate conversion")
	check(client.pivots.keys() == canonical_ids and client.owner_scene.registry.entities.keys() == registry_ids,"Private dummy does not enter canonical pivots, picking or replicated registry")
	check(entry.runtime.state.target54 == id and entry.runtime.state.source58 == 0x7f000000,"Point visual retains original invalid-source routing and internal target ID")
	remember_models(effect_id)
	var changed := await capture(message.screenshot.replace(".png","-point.png"),effect_id)
	check(changed > 32,"Real point effect changes Vulkan pixels on the original dummy anchors")
	check(await wait_until(func():return effect_released(effect_id),10),"Point effect completes its original transient phases independently of dummy expiry")
	check(await wait_until(func():return client.client_dummies.host(id,token) == null,12),"Original point dummy expires after its native delay and releases the private model")
	client.command({"kind":"client-dummy-probe","transferId":client.world_scope.ticket})
	check(await wait_until(func():return find_point.call() != null,10),"A second authored dummy probe can create a new private host")
	var next = find_point.call()
	check(next != null and next.actor > id and next.privateToken > token,"Expired private dummy IDs/tokens are never recycled")
	return {"firstId":id,"firstToken":token,"changedPixels":changed,"state":client.client_dummies.sample(),"canonicalIdsUnchanged":client.pivots.keys() == canonical_ids}

func run_area(message: Dictionary) -> Dictionary:
	var canonical: Array = client.pivots.keys()
	client.command({"kind":"chat","channel":1,"text":"-native-vfxp"})
	var find_area := func():
		for entry in client.effects.entries.values():
			if entry.areaVisual and entry.runtime != null: return entry
		return null
	check(await wait_until(func():return find_area.call() != null,12),"Real server ApplyEffectAtLocation enters independent native type11 area-effect owner")
	var entry = find_area.call()
	if entry == null: return {"failed":"No area visual"}
	var id: int = entry.id;var internal_id: int = entry.actor
	var state: Dictionary = entry.runtime.state
	check(state.instant190 == 1 and state.destroy194 == 1 and state.phase184 == 1,"Actual area effect retains original instant, destruction and impact-phase semantics")
	check(is_instance_valid(state.model) and state.model.rigs.entities[0].models[0].has("native_owner"),"Original area model plays through native animation run/controller owner")
	var point: Vector3 = client.pivots[client.controlled_id].global_position
	check(is_instance_valid(state.model) and state.model.global_position.distance_to(point) < 0.2,"Real server area effect retains world position without a creature attachment")
	check(client.pivots.keys() == canonical and client.client_dummies.entries.is_empty(),"Area effects allocate internal type11 identity without dummy creature or canonical registry changes")
	remember_models(id)
	var pixels := await capture(message.screenshot.replace(".png","-area.png"),id)
	check(pixels > 32,"Actual server area effect changes Vulkan pixels")
	check(await wait_until(func():return effect_released(id),12),"Native area impact countdown and retirement tail release models and particles")
	return {"internalId":internal_id,"changedPixels":pixels,"canonicalIdsUnchanged":client.pivots.keys() == canonical}

func capture(path: String, effect_id: int) -> int:
	if DisplayServer.get_name() == "headless": return 0
	if not await wait_until(func(): return client.particles.waiting < 0, 2): return 0
	var particles = client.particles
	var effects = client.effects
	var body = client.model_rigs
	var camera: Camera3D = client.owner_scene.camera
	var controller = client.owner_scene.camera_controller
	var previous := camera.global_transform
	var center: Vector3 = client.pivots[client.controlled_id].global_position
	controller.set_process(false)
	camera.global_position = center + Vector3(7, 7, 9)
	camera.look_at(center + Vector3(0, 0.7, 0))
	particles.set_process(false)
	effects.set_process(false)
	body.set_process(false)
	var owned: Array = []
	for record in effects.models.values():
		if int(record.effect) != effect_id: continue
		var model = record.model
		owned.append({"model": model, "visible": model.visible})
		model.rigs.set_process(false)
	await client.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var active: Image = client.get_viewport().get_texture().get_image()
	for record in owned:
		if is_instance_valid(record.model): record.model.visible = false
	for id in particles.rows:
		var row: Dictionary = particles.rows[id]
		if row.has("visualModel") and effects.models.has(int(row.visualModel)) and int(effects.models[int(row.visualModel)].effect) == effect_id: particles.surfaces[id].visible = false
	await client.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = client.get_viewport().get_texture().get_image()
	var pixels := 0
	for y in active.get_height():
		for x in active.get_width():
			if active.get_pixel(x, y) != hidden.get_pixel(x, y): pixels += 1
	active.save_png(path)
	for record in owned:
		if is_instance_valid(record.model):
			record.model.visible = record.visible
			record.model.rigs.set_process(true)
	particles.set_process(true)
	effects.set_process(true)
	body.set_process(true)
	camera.global_transform = previous
	controller.set_process(true)
	return pixels
