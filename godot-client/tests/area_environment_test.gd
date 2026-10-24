extends SceneTree
const Main = preload("res://main.gd")
var checks: Array = []
var output := ""
func check(value: bool,label: String) -> void:
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
	var host := Main.new(); root.add_child(host); host.load_room(input.scene)
	var owner = host.environment_owner
	check(is_instance_valid(owner) and host.camera != null,"Actual native loader creates the area atmosphere owner")
	if host.camera == null: host.free(); quit(1); return
	var original_sun: Node = owner.sunlight
	check(original_sun != null,"Original exported area sunlight is identified and reused")
	var fields := {"98":0x332211,"9c":0x664422,"a0":0x554433,"a4":25,"a8":false,"ac":0,"b0":0,"b4":1,"b8":0xbbccdd,"bc":0x99aabb,"c0":0x8899aa,"c4":5,"c8":true,"cc":0,"d0":0,"d4":1,"d8":true,"dc":false,"e0":0,"104":60,"108":45}
	var state := {"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}
	check(owner.receive({"revision":1,"state":state}),"Native raw area RGB, fog and module period are admitted")
	check(owner.sunlight == original_sun,"Applying received area state does not add a duplicate sun")
	check(owner.environment.fog_enabled and owner.environment.fog_mode == Environment.FOG_MODE_DEPTH and owner.environment.fog_density == 1,"Depth fog is enabled at full coverage rather than exponential engine defaults")
	check(owner.environment.background_color == owner.environment.fog_light_color and owner.environment.background_color.is_equal_approx(Color(170.0/255,153.0/255,136.0/255)),"Original fog color also fills the background in the active daytime period")
	check(owner.sunlight.shadow_enabled and is_equal_approx(owner.sunlight.shadow_opacity,.6),"Day shadow gate and opacity come from native area fields")
	check((-owner.sunlight.global_basis.z).distance_to(Vector3.DOWN) < .00001,"Z-up area light direction becomes downward Godot illumination")
	var before: int = owner.phase_updates
	owner.advance(.1);owner.advance(.2)
	check(owner.phase_updates == before,"Fixed-period colors are cached instead of rewritten each native frame")
	var old_begin: float = owner.environment.fog_depth_begin
	host.camera_controller.distance += 5;owner.advance(0)
	check(is_equal_approx(owner.environment.fog_depth_begin,old_begin+5),"Zoom distance updates the native fog interval without a bridge request")
	var snapshots := {"day":owner.snapshot()}
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.get_basename()+"-day.png") == OK,"Day lighting and fog native screenshot saved")
	state.time.timeOfDay = 2
	check(owner.receive({"revision":2,"state":state}),"Received night period replaces daytime lighting")
	check(not owner.sunlight.shadow_enabled and owner.environment.background_color.is_equal_approx(Color(51.0/255,68.0/255,85.0/255)),"Night uses moon fog, ambient and shadow gate even when sun colors are nonzero")
	snapshots.night = owner.snapshot()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.get_basename()+"-night.png") == OK,"Night lighting and fog native screenshot saved")
	state.time.timeOfDay = 3;state.elapsed = 30
	check(owner.receive({"revision":3,"state":state}),"Dawn starts at server-provided elapsed time")
	check(owner.sample.diffuse == [0.0,0.0,0.0] and not owner.sample.isNight and owner.sample.amount == 15,"Halfway dawn matches original diffuse midpoint, fog amount and day-side switch")
	owner.advance(30)
	check(owner.sample.complete and owner.sample.amount == 5 and owner.environment.background_color.is_equal_approx(Color(170.0/255,153.0/255,136.0/255)),"Native frame clock completes dawn without server polling")
	state.time.timeOfDay = 4;state.elapsed = 30
	owner.receive({"revision":4,"state":state})
	check(owner.sample.isNight and owner.sample.amount == 15,"Dusk midpoint switches to the moon side")
	fields.d8 = false;fields.dc = true;state.time.timeOfDay = 1;state.elapsed = 0
	owner.receive({"revision":5,"state":state})
	check(owner.sample.isNight and owner.sample.amount == 25,"A fixed-night area ignores the module day period")
	check(not owner.receive({"revision":4,"state":state}),"A delayed atmosphere revision cannot rewind state")
	var bad: Dictionary = state.duplicate(true);bad.fields.erase("108")
	check(not owner.receive({"revision":6,"state":bad}),"Incomplete area state is rejected before changing environment")
	fields["108"] = .05;fields.a4 = 0;fields.e0 = 1
	owner.receive({"revision":7,"state":state})
	check(owner.range_state.start < 0 and owner.environment.fog_depth_begin == owner.range_state.start and is_equal_approx(host.camera.far,135),"Native degenerate clip guard, negative fog start and sky far range survive Godot setters")
	snapshots.final = owner.snapshot()
	var refs: Array = [weakref(owner),weakref(original_sun)]
	host.free();await process_frame;await process_frame
	check(refs.all(func(ref):return ref.get_ref() == null),"Environment, original light and native room owners release together")
	var passed := checks.all(func(row):return row.passed)
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"checks":checks,"snapshots":snapshots,"scope":"Authored local native atmosphere integration; not GPU equality, sky/weather, dynamic area commands or public server acceptance"},"\t"));file.close()
	print(JSON.stringify({"passed":passed,"checks":checks.size()}));quit(0 if passed else 1)
