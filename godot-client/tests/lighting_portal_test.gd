extends SceneTree
const Main = preload("res://main.gd")
var checks: Array = []
var output := ""
func check(value: bool, label: String) -> void:
	checks.append({"passed":value,"name":label})
	if not value: push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var fixture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): fixture = arg.substr(10)
		if arg.begins_with("--report="): output = arg.substr(9)
	if fixture.is_empty() or output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var host := Main.new(); root.add_child(host)
	host.load_room(input.scene)
	check(host.camera != null and host.registry != null,"Authored exported room imports into the actual native loader")
	if host.camera == null: host.free(); quit(1); return
	var settings: Environment = host.environment_owner.environment
	var actual := settings.ambient_light_color.srgb_to_linear()
	check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(.18,.12,.06)) < .00001,"Native ambient input roundtrips to original linear irradiance without double darkening")
	actual = settings.background_color.srgb_to_linear()
	check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(.08,.12,.16)) < .00001,"Source background survives one sRGB conversion")
	var sun: DirectionalLight3D = host.room_owner.find_child("nwn_light_0",true,false)
	check(sun != null and (-sun.global_basis.z).distance_to(Vector3(-3,-8,-4).normalized()) < .00001,"Native sunlight follows source world target instead of default horizontal axis")
	check(host.registry.entities[7].eligible and host.registry.entities[7].type == 7,"Replicated transition is an eligible logical portal")
	await physics_frame; await physics_frame
	var point := host.camera.unproject_position(Vector3(-1,.05,1))
	var hit: Dictionary = host.registry.pick(host.camera,point)
	check(hit.get("id",-1) == 7,"Invisible authoritative portal polygon is picked above the floor")
	hit = host.registry.pick(host.camera,host.camera.unproject_position(Vector3(2,1,0)))
	check(hit.get("id",-1) == 9,"Usable placeable retains actual render-zero hit faces through glTF")
	check(host.registry.parts[9][0].get_active_material(0).albedo_color.a == 0,"Retained hidden placeable geometry stays transparent")
	host.registry.mark([7])
	check(host.registry.marked.has(7),"Portal can be selected for native highlighting")
	host.registry.mark([])
	await RenderingServer.frame_post_draw
	var screenshot := output.get_basename()+".png"
	check(get_root().get_texture().get_image().save_png(screenshot) == OK,"Authored native lighting and portal screenshot saved")
	var weak: WeakRef = weakref(host.registry)
	host.free(); await process_frame; await process_frame
	check(weak.get_ref() == null,"Native scene and portal physics owners release after test")
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Authored native glTF lighting and transition polygon; no online connection or full fog/sky parity"},"\t")); file.close()
	print(JSON.stringify({"passed":passed,"checks":checks.size()})); quit(0 if passed else 1)
