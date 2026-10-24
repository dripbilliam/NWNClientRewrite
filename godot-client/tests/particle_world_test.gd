extends SceneTree
const World = preload("res://systems/particle_world.gd")
const Rigs = preload("res://systems/model_rigs.gd")
class Owner extends RefCounted:
	var camera
class Client extends Node:
	var particles
	var generation := 1
	var world_scope := {"admitted": true,"ticket":3}
	var pivots := {}
	var content_revisions := {}
	var removed_states := {}
	var owner_scene = Owner.new()
	var commands: Array = []
	func command(value: Dictionary) -> void:
		commands.append(value)
var failures: Array = []
var checks := 0
func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			output = arg.substr(9)
	var host := Node3D.new()
	root.add_child(host)
	var client := Client.new()
	host.add_child(client)
	var camera := Camera3D.new()
	host.add_child(camera)
	client.owner_scene.camera = camera
	var rigs := Rigs.new()
	host.add_child(rigs)
	var world := World.new()
	host.add_child(world)
	world.set_process(false)
	client.particles = world
	var registry := {"meshes_by_name": {}}
	world.configure(client, {"particles": {"epoch": 1, "emitters": []}}, registry, rigs)
	await process_frame
	check(not world.start_requested and client.commands.is_empty(), "Area without emitters does not start idle workers")
	var template := MeshInstance3D.new()
	template.mesh = QuadMesh.new()
	var material := StandardMaterial3D.new()
	template.material_override = material
	host.add_child(template)
	registry.meshes_by_name["authored"] = template
	var identity := [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
	var descriptor := {"id": 1, "objectId": 6, "textureMesh": "authored", "properties": {"update": "Explosion", "blend": "Normal", "twosidedtex": "false"}, "matrix": identity, "rootMatrix": identity, "nativeParent": null, "clock": {"clip": "default", "time": 0, "speed": 1, "loop": true, "playing": true}, "clips": {"default": {"length": 1, "events": [{"time": 0.05, "name": "Detonate"}]}}, "referenceTarget": null}
	world.adopt({"particles": {"emitters": [descriptor]}}, registry)
	await process_frame
	check(client.commands.size() == 1 and client.commands[0].kind == "particles-start", "First same-area emitter starts workers even when area admission had none")
	check(not template.visible and world.rows.size() == 1, "Original bitmap template stays hidden while a separate live surface owns draw data")
	check(not world.surfaces[1].two_sided, "String false does not enable two-sided rendering")
	world.receive({"kind": "particles-ready", "epoch": 0, "ids": [1]})
	check(not world.worker_ready, "Old readiness cannot enable the current epoch")
	world.receive({"kind": "particles-ready", "epoch": 1, "ids": [1]})
	world._process(0.1)
	check(client.commands[-1].kind == "particle-frame" and client.commands[-1].poses[0].detonate, "Original static-model detonation event reaches a worker frame")
	check(is_equal_approx(float(client.commands[-1].poses[0].animation.time), 0.1), "Static emitter controller sampling uses a native-owned clock")
	var count := client.commands.size()
	world._process(0.1)
	check(client.commands.size() == count, "Busy native frame cannot enqueue a second worker request")
	world.receive({"kind": "particle-complete", "epoch": 1, "sequence": 100})
	check(world.waiting == 0, "Unrelated completion cannot free another frame's admission")
	var positions := PackedByteArray()
	positions.resize(96 * 12)
	var attributes := positions.duplicate()
	world.receive({"kind": "particle-stream", "epoch": 1, "sequence": 0, "streams": [{"row": {"id": 1, "count": 6, "capacity": 96, "bounds": {"min": [0, 0, 0], "max": [1, 1, 1]}}, "positions": positions, "attributes": attributes}]})
	check(world.surfaces[1].vertex_count == 6 and world.stats.failures == 0, "Matching packed stream updates its native owner")
	world.receive({"kind": "particle-complete", "epoch": 1, "sequence": 0, "vertices": 6})
	check(world.waiting == -1 and world.stats.frames == 1, "Matching completion releases backpressure only after streams apply")
	var pivot := Node3D.new()
	host.add_child(pivot)
	client.pivots[6] = pivot
	pivot.hide()
	world._process(0.1)
	check(not world.surfaces[1].visible, "Removed/hidden entity cannot leave world-space particle ghosts")
	world.forget_entity(6)
	check(world.rows.is_empty() and world.surfaces.is_empty() and world.active_ids.is_empty(), "Entity replacement retires every emitter and its draw ownership")
	world.retire()
	check(not world.worker_ready and world.epoch == -1 and not rigs.model_event.is_connected(world._model_event), "Area retirement disables delivery and disconnects model event ownership")
	world.receive({"kind": "particles-ready", "epoch": 1, "ids": [1]})
	check(not world.worker_ready, "Late readiness cannot revive a retired world")
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Authored native runtime ownership, first-emitter startup, clocks/events, backpressure, stream admission and retirement"}
	host.free()
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t") + "\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
