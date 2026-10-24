extends SceneTree
const Surface = preload("res://systems/particle_surface.gd")
var checks: Array = []
func check(value: bool,label: String) -> void: checks.append({"passed":value,"name":label})
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2);return
	root.size = Vector2i(128,128)
	var world := Node3D.new();root.add_child(world)
	var camera := Camera3D.new();world.add_child(camera);camera.position = Vector3(0,0,4);camera.projection = Camera3D.PROJECTION_ORTHOGONAL;camera.size = 4;camera.make_current()
	var environment := WorldEnvironment.new();environment.environment = Environment.new();environment.environment.background_mode = Environment.BG_COLOR;environment.environment.background_color = Color.BLACK;environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color = Color.BLACK;world.add_child(environment)
	var light := DirectionalLight3D.new();light.light_color = Color.RED;light.light_energy = 1;world.add_child(light)
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE);var texture := ImageTexture.create_from_image(image)
	var surface := Surface.new();world.add_child(surface);surface.configure(texture,1,false,false,true)
	var positions := PackedByteArray();positions.resize(72)
	var attributes := PackedByteArray();attributes.resize(72)
	var points := [Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(1,1,0),Vector3(-1,-1,0),Vector3(1,1,0),Vector3(-1,1,0)]
	for i in 6:
		positions.encode_float(i*12,points[i].x);positions.encode_float(i*12+4,points[i].y);positions.encode_float(i*12+8,0)
		attributes.encode_u32(i*12,0xffffffff);attributes.encode_float(i*12+4,(points[i].x+1)/2);attributes.encode_float(i*12+8,(points[i].y+1)/2)
	check(surface.apply_frame(1,0,6,6,positions,attributes,AABB(Vector3(-1,-1,-.01),Vector3(2,2,.02))),"Lit particle uses the original uncompressed vertex/attribute layout")
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var red := root.get_texture().get_image().get_pixel(64,64)
	check(red.r > .3 and red.g < .02 and red.b < .02,"Original bitmap/vertex color receives actual red engine light")
	light.light_color = Color.GREEN
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var green := root.get_texture().get_image().get_pixel(64,64)
	check(green.g > .3 and green.r < .02 and green.b < .02,"Changing only the scene light changes the particle tint")
	light.light_energy = 0;environment.environment.ambient_light_color = Color(0,0,.2)
	await RenderingServer.frame_post_draw;await RenderingServer.frame_post_draw
	var ambient := root.get_texture().get_image().get_pixel(64,64)
	check(ambient.b > .05 and ambient.r < .02 and ambient.g < .02,"Lit particle also receives the native area's engine ambient color")
	var refs: Array = [weakref(surface),weakref(world)]
	surface.retire();world.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	check(refs.all(func(v):return v.get_ref() == null),"Lit surface and world retire before native renderer teardown")
	var passed := checks.all(func(v):return v.passed)
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"checks":checks,"colors":{"red":[red.r,red.g,red.b],"green":[green.r,green.g,green.b],"ambient":[ambient.r,ambient.g,ambient.b]},"scope":"Authored native Vulkan lighting adapter; no claim of original per-point CPU lighting equivalence"},"\t"));file.close();print("PARTICLE_LIGHTING_TEST passed=",passed);quit(0 if passed else 1)
