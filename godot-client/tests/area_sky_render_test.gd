extends SceneTree
const EnvironmentOwner = preload("res://systems/area_environment.gd")
var checks: Array = []
var output := ""
func check(value: bool, label: String) -> void:
	checks.append({"passed":value,"name":label})
	if not value: push_error(label)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
func difference(a: Image,b: Image) -> float:
	var total := 0.0
	for y in range(10,a.get_height(),20):
		for x in range(10,a.get_width(),20):
			var p := a.get_pixel(x,y);var q := b.get_pixel(x,y)
			total += absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
	return total / (ceilf(float(a.get_height()-10)/20)*ceilf(float(a.get_width()-10)/20)*3)
func run() -> void:
	var fixture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): fixture = arg.substr(10)
		if arg.begins_with("--report="): output = arg.substr(9)
	if fixture.is_empty() or output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var bundle: Dictionary = input.skyResources[0]
	var has_horizon := bundle.get("horizon") is String
	var expected_imports := 5 if has_horizon else 4
	var host := Node3D.new();root.add_child(host)
	var camera := Camera3D.new();host.add_child(camera);camera.position = Vector3(0,2,0);camera.current = true;camera.far = 135
	var owner := EnvironmentOwner.new();owner.configure({},host);host.add_child(owner);owner.camera = camera
	var fields := {"98":0,"9c":0,"a0":0,"a4":0,"a8":false,"b8":0,"bc":0,"c0":0,"c4":0,"c8":false,"d8":false,"dc":false,"e0":1,"104":0,"108":45}
	var state := {"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}
	check(owner.receive({"revision":1,"state":state}),"Area atmosphere uses actual native admission state")
	check(owner.receive_sky(bundle),"Four installed original sky phases pass external GLB and metadata hashes")
	if not is_instance_valid(owner.sky): host.free();quit(1);return
	owner.set_process(false)
	var sky = owner.sky
	check(sky.resources.stats.imports == expected_imports and sky.instances.size() == expected_imports,"Original resources import once into one admitted-world owner")
	var programs := {}
	for rows in sky.materials.values():
		for row in rows:
			programs[row.base.shader.get_instance_id()] = true;programs[row.overlay.shader.get_instance_id()] = true
	check(programs.size() == 1,"Every original sky phase and horizon surface shares one native shader program")
	var invalid := bundle.duplicate(true);invalid.resources[invalid.phases[1]].sha256 = "0".repeat(64)
	check(not owner.receive_sky(invalid) and owner.sky == sky,"Corrupt external sky hashes are rejected without replacing the working sky")
	invalid = bundle.duplicate(true);invalid.phases[1] = "absent_phase"
	check(not owner.receive_sky(invalid) and owner.sky == sky,"Incomplete phase sets cannot replace the admitted original sky")
	if has_horizon:
		invalid = bundle.duplicate(true);invalid.resources[invalid.horizon].sha256 = "0".repeat(64)
		check(not owner.receive_sky(invalid) and owner.sky == sky,"Corrupt original horizon art cannot replace the working sky owner")
	check(sky.phases.all(func(key):return sky.instances[key].metadata.counts.meshes == 2 and sky.instances[key].metadata.counts.triangles == 160),"Original sky geometry remains two meshes and 160 triangles per phase")
	if has_horizon:
		check(sky.horizon == "skyfade1" and sky.instances[sky.horizon].metadata.counts.meshes == 1 and sky.instances[sky.horizon].metadata.counts.triangles == 112,"Original horizon model retains its 112 triangles and resolved bitmap UVs")
	var before := []
	for model in sky.instances.values():
		before.append(weakref(model))
		check(model.meshes.meshes_by_name.values().all(func(mesh):return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Sky does not enter world shadow passes")
	owner.environment.background_color = Color.MAGENTA;owner.environment.fog_enabled = false
	await frame()
	var day := root.get_texture().get_image()
	var center := day.get_pixel(day.get_width()/2,day.get_height()/2)
	check(Vector3(center.r-1,center.g,center.b-1).length() > .15,"Original textured sky renders rather than the diagnostic clear color")
	check(day.save_png(output.get_basename()+"-day.png") == OK,"Original daytime sky screenshot saved")
	# A second independent material path guards UV/color mistakes in our sky
	# shader. The original imported Godot material renders the same art/mesh with
	# a long clip range, unlit and fog disabled, without our depth projection.
	camera.far = 10000
	for row in sky.materials[sky.phases[1]]:
		var original: BaseMaterial3D = row.mesh.mesh.surface_get_material(int(row.surface)).duplicate()
		original.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		original.disable_fog = true
		original.cull_mode = BaseMaterial3D.CULL_DISABLED
		original.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		original.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		original.render_priority = -128
		original.albedo_color = Color(1,1,1,original.albedo_color.a)
		row.mesh.set_surface_override_material(int(row.surface),original)
	await frame()
	var original_material := root.get_texture().get_image()
	var material_delta := difference(day,original_material)
	check(material_delta < .003,"Sky pass preserves original texture UVs with the native unlit white phase color")
	camera.far = 135;sky.last_draw.clear();sky.advance(state,0)
	camera.position += Vector3(150,90,-250);sky.advance(state,0)
	await frame()
	var moved := root.get_texture().get_image()
	var translation_delta := difference(day,moved)
	check(translation_delta < .001,"Camera translation preserves the centered original sky projection")
	check(sky.global_position.is_equal_approx(camera.global_position),"Sky anchor follows the native camera without moving gameplay entities")
	camera.far = 2
	owner.environment.fog_enabled = true;owner.environment.fog_light_color = Color.GREEN;owner.environment.fog_depth_begin = 0;owner.environment.fog_depth_end = 1;owner.environment.fog_density = 1
	await frame()
	var fogged := root.get_texture().get_image()
	var fog_delta := difference(moved,fogged)
	check(fog_delta < .001,"Short world clip and full green world fog leave the sky pass unchanged")
	fields.dc = true;sky.advance(state,0)
	await frame()
	var night := root.get_texture().get_image()
	var period_delta := difference(day,night)
	check(period_delta > .02 and sky.state.current == 3,"Fixed-night areas select and display the original night model")
	check(night.save_png(output.get_basename()+"-night.png") == OK,"Original night sky screenshot saved")
	fields.d8 = true;state.time.timeOfDay = 3;sky.advance(state,15)
	check(sky.state.current == 3 and sky.state.target == 0 and is_equal_approx(sky.state.alpha,.625),"Native dawn blends original night and dawn model surfaces")
	await frame()
	var dawn := root.get_texture().get_image()
	check(difference(dawn,day) > .005 and difference(dawn,night) > .005,"Both original sky layers contribute actual visible dawn pixels")
	check(dawn.save_png(output.get_basename()+"-dawn.png") == OK,"Original dawn blend screenshot saved")
	# An independent standard-material path checks the actual two-pass alpha
	# equation, including the clear color under the partially transparent base.
	# It also checks the original fog-tinted horizon bitmap after both phases.
	var old_horizon: Color = sky.horizon_color
	if has_horizon: sky.advance(state,15,Color(.25,.5,.75))
	await frame()
	var blended := root.get_texture().get_image()
	camera.far = 10000
	for index in [sky.state.current,sky.state.target]:
		var weight: float = 1.0-sky.state.alpha if index == sky.state.current else sky.state.alpha
		for row in sky.materials[sky.phases[index]]:
			var original: BaseMaterial3D = row.mesh.mesh.surface_get_material(int(row.surface)).duplicate()
			original.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;original.disable_fog = true;original.cull_mode = BaseMaterial3D.CULL_DISABLED
			original.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;original.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			original.albedo_color = Color(1,1,1,original.albedo_color.a)
			original.albedo_color.a *= weight;original.render_priority = -128 if index == sky.state.current else -127
			row.mesh.set_surface_override_material(int(row.surface),original)
	if has_horizon:
		for row in sky.materials[sky.horizon]:
			var original: BaseMaterial3D = row.mesh.mesh.surface_get_material(int(row.surface)).duplicate()
			original.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;original.disable_fog = true;original.cull_mode = BaseMaterial3D.CULL_DISABLED
			original.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;original.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			original.albedo_color = sky.horizon_color;original.albedo_color.a = 1.0;original.render_priority = -126
			row.mesh.set_surface_override_material(int(row.surface),original)
	await frame()
	var blend_delta := difference(blended,root.get_texture().get_image())
	check(blend_delta < .003,"Both phase weights and fog-tinted horizon match independent original standard materials with native normal-alpha blending")
	camera.far = 2;sky.last_draw.clear();sky.advance(state,15,old_horizon)
	if has_horizon:
		await frame()
		var original_horizon := root.get_texture().get_image()
		for row in sky.materials[sky.horizon]: row.base.set_shader_parameter("original_color",Color(.1,.8,.2,.1))
		await frame()
		check(difference(original_horizon,root.get_texture().get_image()) < .001,"Native horizon flag ignores mesh diffuse tint and part alpha while preserving bitmap alpha")
		sky.advance(state,15,Color(.85,.25,.1));await frame()
		check(difference(original_horizon,root.get_texture().get_image()) > .005,"Received fog tint changes actual original horizon pixels")
		check(root.get_texture().get_image().save_png(output.get_basename()+"-horizon.png") == OK,"Original fog-tinted horizon screenshot saved")
		sky.advance(state,15,old_horizon)
	owner.environment.fog_enabled = false
	var box := MeshInstance3D.new();box.mesh = BoxMesh.new();box.mesh.size = Vector3(.4,.4,.2)
	var material := StandardMaterial3D.new();material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color = Color.GREEN;box.material_override = material
	host.add_child(box);box.global_position = camera.global_position + Vector3(0,0,-1)
	await frame()
	var foreground := root.get_texture().get_image().get_pixel(day.get_width()/2,day.get_height()/2)
	check(foreground.g > .95 and foreground.r < .01 and foreground.b < .01,"World geometry occludes both sky layers at far depth")
	check(sky.resources.stats.imports == expected_imports,"Camera and phase updates perform no repeated asset import")
	var changes: int = sky.material_updates
	for index in 1000: sky.advance(state,15)
	check(sky.material_updates == changes,"Unchanged sky phase performs no repeated material rebinding or uniform upload")
	var old_sky: WeakRef = weakref(sky)
	var absent := bundle.duplicate(true);absent.skyId = 0;absent.phases = [];absent.resources = {};absent.horizon = null
	check(owner.receive_sky(absent),"An indoor/no-sky area replaces the old sky set")
	await process_frame;await process_frame
	check(old_sky.get_ref() == null and before.all(func(ref):return ref.get_ref() == null),"Retired sky, original model nodes and rig owners are released")
	check(owner.sky.instances.is_empty(),"No-sky state retains no geometry or texture instances")
	host.free();await process_frame;await process_frame
	var passed := checks.all(func(row):return row.passed)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"horizon":has_horizon,"blendPixelDelta":blend_delta,"importedMaterialPixelDelta":material_delta,"cameraTranslationPixelDelta":translation_delta,"worldFogPixelDelta":fog_delta,"dayNightPixelDelta":period_delta,"scope":"Installed original sky/bitmap-horizon native Vulkan functional checks; weather/complete GPU parity and performance unaccepted"},"\t"));file.close()
	print("SKY_RENDER_TEST ",checks.size()," checks; ",passed)
	quit(0 if passed else 1)
