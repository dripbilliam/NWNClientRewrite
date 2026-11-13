extends SceneTree
const Focus=preload("res://systems/native_render/focus_lighting.gd")
const Point=preload("res://systems/native_render/model_point_light.gd")
const Report=preload("res://systems/native_render/native_feature_report.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var checks: Array=[]
var output:=""
var expectation_path:=""
func check(ok: bool,label: String)->void:checks.append({"ok":ok,"label":label})
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		if arg.begins_with("--expectation="):expectation_path=arg.substr(14)
	call_deferred("run")
func run()->void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expectation_path))
	var arguments:=OS.get_cmdline_user_args()
	check(arguments.has("--profile=false"),"Actual native argv selects profiling OFF")
	var features:=Report.new();check(features.configure(arguments,expected.requested),"Actual current native feature report configures")
	var private_settings:=output+".options.cfg";var config:=ConfigFile.new()
	config.set_value("rendering","profiling_enabled",true);config.set_value("rendering","gamma",1.2);config.set_value("rendering","fov_degrees",45.0);config.set_value("rendering","particles_enabled",true);config.set_value("rendering","particle_collision_enabled",true);config.set_value("rendering","compact_scenery",true)
	check(config.save(private_settings)==OK,"Private saved preference fixture created")
	var before:=FileAccess.get_sha256(private_settings)
	var settings:=Settings.new();root.add_child(settings);settings.setup(private_settings,"",false,"","false");settings.hide()
	check(not settings.profiling_enabled and not Timing.enabled,"Actual settings override and profiler remain OFF")
	check(settings.gamma_value==1.2 and settings.fov_degrees==45 and settings.particles_enabled and settings.particle_collision_enabled and settings.compact_scenery_enabled,"Gamma/FOV/particle/collision/scenery preferences carried forward")
	check(FileAccess.get_sha256(private_settings)==before,"Runtime profiling override does not overwrite saved preference bytes")
	var quality:={"gamma":settings.gamma_value,"fov":settings.fov_degrees,"particles":settings.particles_enabled,"particle_collision":settings.particle_collision_enabled,"compact_scenery":settings.compact_scenery_enabled,"profiling":settings.profiling_enabled,"msaa_3d":ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")}
	settings.free()
	var world:=Node3D.new();world.name="PrivateNormalOwnerFixture";root.add_child(world)
	var lights: Array=[]
	for index in 32:
		var light:=Point.new();light.name="Light"+str(index);light.set_meta("native_enhanced_light",false)
		light.configure({"radius":8.0,"color":[.8,.4,.2],"multiplier":1.0});world.add_child(light)
		light.set_meta("native_enhanced_light",true);light.native_state={"range":8.0};light.position=Vector3(float(index),0,0);lights.append(light)
	var focus:=Focus.new();focus.configure(world)
	check(focus.members.size()==32,"Actual Focus owner binds all32 current canonical lamps")
	var owner: RefCounted=focus.get("_input_registry")
	check(owner.effective==expected.lightInput,"Actual Focus input owner matches resolved normal/fallback selection")
	var first: Dictionary={};var second: Dictionary={}
	if expected.lightInput=="builtin":
		first=owner.poll([],true);second=owner.poll([],false)
		check(not first.has("error") and first.rows.size()==32,"Real builtin registry publishes all32 lamps")
		check(second.rows.is_empty() and int(second.reused)==32,"Real builtin quiet poll reuses32 current rows")
		lights[7].native_properties.radius=1000.0;var removed: Dictionary=owner.poll([],false)
		check(removed.removed.has(lights[7].get_instance_id()),"Live authored radius change removes only current ineligible lamp")
	else:
		check(owner.native==null and owner.snapshot().owner=="focus-script-polling","Explicit fallback uses script owner without hidden native instance")
	var lighting: Dictionary=focus.input_registry_snapshot()
	if expected.typed:
		check(int(lighting.typed_reader.plain_claims)==1 and int(lighting.typed_reader.plain_rows)>=64 and int(lighting.typed_reader.plain_field_reads)>=192,"Actual engine typed cold enrollment and live field reads execute")
		check(lighting.render_core_counters.has("available"),"Cold actual-use counter API exists without enabling profiler")
	else:check(not lighting.has("typed_reader"),"Conservative fallback has no hidden typed mode")
	var observed: Dictionary=features.snapshot();observed.presentation={"detailed_profiling":bool(quality.profiling)}
	check(observed.valid,"Actual native feature report remains valid")
	check(observed.rendering.render_thread_requirement=="headless-not-a-gpu-thread-proof" if expected.thread!="default" else observed.rendering.render_thread_requirement=="not-requested","Headless thread evidence retains its explicit limitation")
	focus.close();focus.free();world.free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);var success:=checks.all(func(row):return row.ok)
	file.store_string(JSON.stringify({"success":success,"checks":checks,"actual":observed,"lighting":lighting,"quality":quality,"world_scope":{"connection":1,"generation":1,"areaId":1},"scope":"Private actual native report/32-lamp Focus input/settings/argv fixture; no broker, game assets, server, GPU, visual, frame timing or FPS proof."}));file.close()
	print(JSON.stringify({"success":success,"checks":checks.size(),"owner":expected.lightInput}));quit(0 if success else 1)
