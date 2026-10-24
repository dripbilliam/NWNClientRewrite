extends SceneTree
const World = preload("res://systems/particle_world.gd")
const Rigs = preload("res://systems/model_rigs.gd")
const Frames = preload("res://systems/bridge_frames.gd")
class Owner extends RefCounted:
	var camera
class Client extends Node:
	var particles
	var generation := 1
	var world_scope := {"admitted": true}
	var content_revisions := {1: 10, 2: 20}
	var removed_states := {}
	var pivots := {}
	var owner_scene = Owner.new()
	var send: Callable
	func command(value: Dictionary) -> void:
		send.call(value)
var peer := StreamPeerTCP.new()
var decoder := Frames.new()
var hello := false
var token := ""
var world
var client
var rigs
var host: Node3D
var frames: Array = []
var index := 0
var stage := "waiting"
var screenshot := ""
var checks := 0
var failures: Array = []
var changed_pixels := 0
var maximum_endpoint_error := 0.0
var capturing := false

func _initialize() -> void:
	var ticket := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticket="):
			ticket = arg.substr(9)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ticket))
	token = data.token
	peer.connect_to_host("127.0.0.1", int(data.port))

func check(value: bool, name: String) -> void:
	checks += 1
	if not value:
		failures.append(name)

func send(value: Dictionary) -> void:
	var message := value.duplicate()
	message.merge({"connection": 1, "areaId": 2, "generation": 1, "transferId": 1})
	peer.put_data((JSON.stringify(message) + "\n").to_utf8_buffer())

func setup(message: Dictionary) -> void:
	host = Node3D.new()
	root.add_child(host)
	client = Client.new()
	host.add_child(client)
	client.send = send
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = Vector3(11, 7, 22)
	camera.look_at(Vector3(11, 1, -2), Vector3.UP)
	camera.current = true
	client.owner_scene.camera = camera
	rigs = Rigs.new()
	host.add_child(rigs)
	rigs.set_process(false)
	for id in [1, 2]:
		var nodes: Array = []
		for part in 2:
			var node := Node3D.new()
			host.add_child(node)
			nodes.append(node)
		rigs.entities[id] = {"nodes": nodes, "models": []}
		client.pivots[id] = nodes[0]
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var template := MeshInstance3D.new()
	template.mesh = QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	template.material_override = material
	host.add_child(template)
	world = World.new()
	host.add_child(world)
	world.set_process(false)
	client.particles = world
	world.configure(client, {"particles": message.data}, {"meshes_by_name": {"authored": template}}, rigs)
	frames = message.frames
	screenshot = message.screenshot
	stage = "frames"

func _process(_delta: float) -> bool:
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	if not hello:
		hello = true
		send({"kind": "hello", "token": token})
		token = ""
	var count := peer.get_available_bytes()
	if count > 0:
		for message in decoder.feed(peer.get_data(mini(count, 262144))[1]):
			if message.kind == "quit":
				quit(0)
				return false
			if message.kind == "reference-scene":
				setup(message)
			else:
				world.receive(message)
	if world == null or not world.worker_ready or world.waiting >= 0 or capturing:
		return false
	if stage == "frames" and index < frames.size():
		var frame: Dictionary = frames[index]
		rigs.entities[1].nodes[0].global_transform = world._transform(frame.root)
		rigs.entities[1].nodes[1].global_transform = world._transform(frame.emitter)
		rigs.entities[2].nodes[0].global_transform = world._transform(frame.pivot)
		rigs.entities[2].nodes[1].global_transform = world._transform(frame.anchor)
		var endpoint: Array = world._reference_pose(world.rows.values()[0].referenceTarget)
		var error := 0.0
		for i in 16:
			error = maxf(error, absf(float(endpoint[i]) - float(frame.expected[i])))
		maximum_endpoint_error = maxf(maximum_endpoint_error, error)
		check(error < 0.00002, "Live native endpoint agrees with original physical attachment frame%s" % index)
		world._process(0.05)
		index += 1
	elif stage == "frames":
		capturing = true
		capture()
	elif stage == "retire":
		check(world.stats.vertices == 0, "Replaced target revision drains actual worker-produced reference quads")
		stage = "recycled"
		client.content_revisions[2] = 20
		world._process(0.05)
	elif stage == "recycled":
		check(world.stats.vertices == 0, "Recycled target identity cannot revive the retired endpoint")
		check(world.stats.failures == 0, "No native stream or material failures")
		world.retire()
		stage = "done"
		send({"kind": "tested", "result": {"passed": failures.is_empty(), "checks": checks, "failures": failures, "frames": index, "changedPixels": changed_pixels, "maximum_endpoint_error": maximum_endpoint_error}})
	return false

func capture() -> void:
	await RenderingServer.frame_post_draw
	check(world.stats.vertices > 0 and world.stats.visible > 0, "Actual reference-linked workers produce native visible quads")
	var active := root.get_texture().get_image()
	active.save_png(ProjectSettings.globalize_path("res://reports/" + screenshot))
	for surface in world.surfaces.values():
		surface.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var hidden := root.get_texture().get_image()
	for y in active.get_height():
		for x in active.get_width():
			var a := active.get_pixel(x, y)
			var b := hidden.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.025:
				changed_pixels += 1
	check(changed_pixels >= 8, "Reference-linked streams contribute actual Vulkan pixels")
	client.content_revisions[2] = 21
	stage = "retire"
	capturing = false
	world._process(0.05)
