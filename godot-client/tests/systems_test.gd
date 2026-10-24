extends SceneTree

const Registry = preload("res://systems/entity_registry.gd")
const CameraController = preload("res://systems/camera_controller.gd")
const Hud = preload("res://systems/native_hud.gd")
const WorldInput = preload("res://systems/world_input.gd")
var failures: Array[String] = []
var checks := 0

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Authored native systems check timed out"); quit(1))
	var host := Node3D.new()
	root.add_child(host)
	var room := Node3D.new()
	host.add_child(room)
	var source_material := StandardMaterial3D.new()
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.4, 0.5, 0.7))
	var texture := ImageTexture.create_from_image(image)
	source_material.albedo_texture = texture
	var rows: Array = []
	var nodes: Array[MeshInstance3D] = []
	for i in 4:
		var mesh := MeshInstance3D.new()
		mesh.name = "fixture_%s" % i
		mesh.mesh = BoxMesh.new()
		mesh.mesh.material = source_material
		room.add_child(mesh)
		mesh.position = [Vector3(0, 0.5, 0), Vector3(0, 1.3, 0), Vector3(0, 1, 3), Vector3(3, 1, 0)][i]
		mesh.scale = Vector3(2, 2, 0.5) if i == 2 else Vector3.ONE
		nodes.append(mesh)
		rows.append({"name": str(mesh.name), "objectId": 1 if i < 2 else 2, "particle": i == 3, "blend": "additive", "depthTest": true})
	var old_overlay := StandardMaterial3D.new()
	nodes[0].material_overlay = old_overlay
	var registry := Registry.new()
	host.add_child(registry)
	registry.configure(room, {"entities": [{"id": 1, "eligible": true, "name": "Authored creature", "type": 5, "resources": ["fixture"]}, {"id": 2, "eligible": false, "name": "Scenery"}], "meshes": rows})
	expect(registry.stats.entities == 2 and registry.stats.bound_meshes == 3, "Logical IDs retain every equipment/body part")
	expect(registry.stats.colliders == 3, "Particles do not become physical picking occluders")
	expect(registry.eligible_ids() == [1], "Non-usable scenery is not invented as an interactable")
	var particle: BaseMaterial3D = nodes[3].get_active_material(0)
	expect(particle.blend_mode == BaseMaterial3D.BLEND_MODE_ADD and particle.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED, "Particle additive blending and depth-write semantics survive import")
	expect(particle.albedo_texture == texture and nodes[0].get_active_material(0) == source_material, "Particle adaptation preserves texture identity and other materials")
	registry.mark([1, 2])
	expect(nodes[0].material_overlay == nodes[1].material_overlay and nodes[0].material_overlay != old_overlay and nodes[2].material_overlay == null, "All eligible body parts highlight together; scenery does not")
	registry.mark([])
	expect(nodes[0].material_overlay == old_overlay and nodes[1].material_overlay == null, "Unhighlighting restores previous overlays")
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.global_position = Vector3(0, 3, 8)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true
	await physics_frame
	await physics_frame
	var screen := camera.unproject_position(Vector3(0, 0.5, 0))
	var hit: Dictionary = registry.pick(camera, screen)
	expect(hit.get("id") == 2, "A wall/scenery hit occludes a creature behind it")
	for body in registry.get_children():
		if body.get_meta("entity_id", -1) == 2:
			body.collision_layer = 0
	await physics_frame
	hit = registry.pick(camera, screen)
	expect(hit.get("id") == 1, "Precise triangle ray hits resolve to the original logical object")
	var controller := CameraController.new()
	host.add_child(controller)
	controller.configure(camera, Vector3(0, 0.5, 0))
	var start := camera.global_transform
	var distance: float = controller.distance
	controller.orbit(Vector2(40, 20))
	expect(is_equal_approx(camera.global_position.distance_to(controller.target), distance), "Orbit retains focus distance")
	controller.reset()
	expect(camera.global_transform.is_equal_approx(start), "Reset restores the exact captured view")
	controller.pan(Vector2(1, 1), 0.5)
	expect(is_equal_approx(camera.global_position.distance_to(start.origin), 3.5), "Diagonal pan speed is normalized")
	controller.zoom(0.001)
	expect(controller.distance == 2.0, "Zoom respects the near limit")
	controller.reset()
	var hud := Hud.new()
	host.add_child(hud)
	hud.configure(registry, camera, "")
	await process_frame
	hud.toggle_panel("objects")
	hud.inspect_entity(1)
	expect(hud.panels.objects.visible and hud.panels.details.visible, "Multiple native menus can remain open")
	expect(hud.blocks_pointer(hud.panels.details.global_position + Vector2(10, 10)) and not hud.blocks_pointer(Vector2(1400, 900)), "Only menu rectangles consume world pointer input")
	expect(hud.details.text.contains("Authored creature") and hud.details.text.contains("fixture"), "Object inspector uses captured identity and model resources")
	var before := camera.global_position
	controller.pan(Vector2(0, 1), 0.1)
	expect(camera.global_position != before and hud.panels.details.visible, "Open menus do not lock camera movement")
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	controller._input(middle)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(15, 5)
	before = camera.global_position
	controller._input(motion)
	expect(controller.dragging and camera.global_position != before and hud.panels.details.visible, "Middle-button orbit remains active with a native menu open")
	controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(not controller.dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss releases captured middle-button input")
	var world := WorldInput.new()
	host.add_child(world)
	world.configure(registry, camera, hud)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	world._unhandled_input(tab)
	expect(world.tab, "Tab enables group highlighting")
	world._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(not world.tab and world.pending_button == 0, "Focus loss releases held world input")
	var imported := ImporterMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([2, 0, 1])
	imported.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var source_mesh := GLTFMesh.new()
	source_mesh.mesh = imported
	var state := GLTFState.new()
	state.set_meshes([source_mesh])
	state.json = {"nodes": [{"name": "cpu_fixture", "mesh": 0}]}
	var cpu_room := Node3D.new()
	host.add_child(cpu_room)
	var cpu_mesh := MeshInstance3D.new()
	cpu_mesh.name = "cpu_fixture"
	cpu_mesh.mesh = imported.get_mesh()
	cpu_room.add_child(cpu_mesh)
	cpu_mesh.position.x = 50
	cpu_mesh.scale = Vector3(-1, 2, 1)
	var cpu_registry := Registry.new()
	host.add_child(cpu_registry)
	cpu_registry.configure(cpu_room, {"entities": [], "meshes": [{"name": "cpu_fixture", "objectId": null}]}, state)
	expect(cpu_registry.stats.importer_geometries == 1 and cpu_registry.stats.runtime_geometry_reads == 0, "Imported CPU arrays prepare picking without renderer readbacks")
	var physics_faces: PackedVector3Array = cpu_registry.get_child(0).get_child(0).shape.get_faces()
	expect(physics_faces == PackedVector3Array([Vector3(50, 2, 0), Vector3(50, 0, 0), Vector3(49, 0, 0)]), "Picking retains source index order and mirrored/nonuniform world transforms")
	host.free()
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Authored native identity/material/physics/camera/menu input; not live-server or performance acceptance"}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file := FileAccess.open(arg.substr(9), FileAccess.WRITE)
			if file == null:
				push_error("Native check report path could not be opened")
				quit(1)
				return
			file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
