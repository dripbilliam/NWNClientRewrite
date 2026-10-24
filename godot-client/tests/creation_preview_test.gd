extends SceneTree
const Preview = preload("res://systems/creation_preview.gd")
const EffectModel = preload("res://systems/visual_model.gd")
const Creator = preload("res://systems/server_creation.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text)
func vector(value: Array, at: int = 0) -> Vector3: return Vector3(float(value[at]), float(value[at+1]), float(value[at+2]))
func matrix(value: Array) -> Transform3D: return Transform3D(Basis(vector(value), vector(value, 4), vector(value, 8)), vector(value, 12))
func distance(a: Transform3D, b: Transform3D) -> float: return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))
func run() -> void:
	var output := "res://reports/creation-preview-native-v1.json"
	var fixture_path := "res://reports/creation-preview-authored-v1.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output = argument.trim_prefix("--report=")
		if argument.begins_with("--fixture="): fixture_path = argument.trim_prefix("--fixture=")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	root.size = Vector2i(1200, 850)
	var ui := Preview.new(); root.add_child(ui); ui.set_active(true)
	for packet in fixture.packets: ui.receive(packet)
	check(is_instance_valid(ui.model) and ui.model.installed, "Two-part chunk transfer imports an actual private GLB into the native viewport")
	if not is_instance_valid(ui.model): finish(output, ui); return
	check(ui.model.meshes.meshes_by_name.size() == 3 and ui.model.rigs.entities.size() == 1 and fixture.metadata.entities.is_empty(), "All authored meshes use only the private rig handle and no gameplay registry")
	check(ui.model.find_children("*", "CollisionObject3D", true, false).is_empty(), "Preview creates no physics or picking bodies")
	check(ui.model.rigs.entities[0].skins.size() == 1 and ui.model.rigs.entities[0].models.size() == 2, "Native preview retains its skin and nested body-part model owners")
	var effect := EffectModel.new(); check(not effect._valid_metadata(fixture.metadata), "Effect-model validation still rejects the creator's separate envelope"); effect.free()
	ui.model.rigs.set_process(false)
	if DisplayServer.get_name() != "headless": await process_frame; await RenderingServer.frame_post_draw
	var before := ui.animation_sample(); ui.model.rigs._update(0.25)
	if DisplayServer.get_name() != "headless": await process_frame; await RenderingServer.frame_post_draw
	var after := ui.animation_sample(); var changes: Dictionary = ui.model.rigs.compare_samples(before, after)
	if DisplayServer.get_name() != "headless": check(float(changes.maximum_local_skin_vertex_delta) > 0.0001, "Rendered private skin vertices deform during the original idle clip")
	check(int(changes.changed_local_parts) > 0 and int(changes.advanced_model_clocks) > 0, "Original idle animation advances native model clocks and part transforms")
	var local: Transform3D = ui.model.global_transform.affine_inverse() * ui.model.model_root(1).global_transform
	check(distance(local, matrix(fixture.oracle.part)) < 0.0004, "Nested body-part P/Q/scale agrees with the independent original hierarchy oracle")
	check(ui.snapshot().pendingParts == 0 and ui.snapshot().bufferParts == 0, "Completed model transfer releases its staging buffers")
	var angle: float = ui.pivot.rotation.y; ui._process(0.5); check(absf(ui.pivot.rotation.y - angle) > 0.1, "Native preview rotates without a browser frame or new transfer")
	var motion := InputEventMouseMotion.new(); motion.button_mask = MOUSE_BUTTON_MASK_LEFT; motion.relative = Vector2(25, 0); ui._surface_input(motion)
	check(not ui.auto_rotate.button_pressed and absf(ui.pivot.rotation.y - angle) > 0.3, "Dragging rotates the model and pauses automatic rotation")
	var wheel := InputEventMouseButton.new(); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; ui._surface_input(wheel); check(ui.zoom < 1.0, "Wheel input zooms the private camera")
	ui.reset_view(); check(ui.zoom == 1.0 and ui.pivot.rotation == Vector3.ZERO and ui.auto_rotate.button_pressed, "Reset view restores framing and automatic rotation")
	var old = ui.model
	ui.receive({"kind":"creation-preview-loading","previewId":2,"appearance":fixture.metadata.creationAppearance})
	for packet in fixture.packets: ui.receive(packet)
	check(not is_instance_valid(ui.model), "A newer appearance owner rejects delayed packets from its predecessor")
	for original in fixture.packets:
		var packet: Dictionary = original.duplicate(true); packet.previewId = 2; ui.receive(packet)
	await process_frame; await process_frame
	check(ui.installs == 2 and not is_instance_valid(old) and ui.snapshot().retiredAlive == 0, "Replacing a preview frees its old model, skeleton and animation subtree")
	var bad: Array = fixture.packets.duplicate(true)
	for packet in bad: packet.previewId = 3
	bad[1].sha256 = "0".repeat(64)
	for packet in bad: ui.receive(packet)
	check(not is_instance_valid(ui.model) and ui.message.text.contains("checksum"), "Corrupt appearance chunks cannot become a visible model")
	ui.set_active(false); for packet in fixture.packets: ui.receive(packet)
	check(not is_instance_valid(ui.model) and ui.snapshot().pendingParts == 0, "Hidden/closed preview discards late model data")
	var creator := Creator.new(); root.add_child(creator); creator.open()
	creator.receive({"kind":"creation-begin","viewId":1,"step":11,"steps":["Gender","Race","Portrait","Class","Alignment","Package","Abilities","Domains","Skills","Feats","Spells","Appearance","Voice","Name","Review"],"phase":"editing","canEdit":true,"canFinish":false,"canRecommend":false,"canCancel":true,"count":0})
	creator.receive({"kind":"creation-commit","viewId":1}); for packet in fixture.packets: creator.receive(packet)
	check(creator.appearance_preview.active and is_instance_valid(creator.appearance_preview.model), "Creator routes its appearance page to the isolated native viewport")
	creator.reset(); await process_frame; await process_frame
	check(not creator.appearance_preview.active and creator.appearance_preview.snapshot().retiredAlive == 0, "Creator close retires the native preview and all old model owners")
	creator.free(); finish(output, ui)
func finish(output: String, ui) -> void:
	ui.free()
	var file := FileAccess.open(output, FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
