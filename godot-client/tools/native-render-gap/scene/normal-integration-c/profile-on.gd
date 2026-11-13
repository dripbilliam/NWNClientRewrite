extends SceneTree
const Features=preload("res://systems/native_render/native_feature_report.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var output:=""
var expected_path:=""
var checks: Array=[]
func check(ok: bool,label: String)->void:checks.append({"ok":ok,"label":label})
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		if arg.begins_with("--expectation="):expected_path=arg.substr(14)
	call_deferred("run")
func run()->void:
	var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	var features:=Features.new()
	check(OS.get_cmdline_user_args().has("--profile=true"),"Explicit profile ON reaches actual native argv")
	check(features.configure(OS.get_cmdline_user_args(),expected.requested),"Actual full-bundle feature report accepts explicit profile ON")
	var settings_file:=output+".cfg";var cfg:=ConfigFile.new()
	cfg.set_value("rendering","profiling_enabled",false);cfg.set_value("rendering","gamma",1.2);cfg.set_value("rendering","fov_degrees",45.0)
	check(cfg.save(settings_file)==OK,"Private saved profile OFF fixture created")
	var before:=FileAccess.get_sha256(settings_file)
	var settings:=Settings.new();root.add_child(settings);settings.setup(settings_file,"",false,"","true");settings.hide()
	var profiler:=Timing.new();profiler.set_enabled(settings.profiling_enabled)
	check(settings.profiling_enabled and Timing.enabled and Timing.begin()>0,"Actual settings and FrameProfile enable explicit diagnostic timers")
	check(FileAccess.get_sha256(settings_file)==before,"Explicit runtime profiling leaves saved preference bytes unchanged")
	var actual: Dictionary=features.snapshot();actual.presentation={"detailed_profiling":Timing.enabled}
	check(actual.valid and actual.render_core.flags.size()==12,"Profiling ON retains all12 normal functional selections")
	check(actual.render_core.flags==expected.renderCore.flags,"Actual selected functional flags remain unchanged by profiling")
	profiler.set_enabled(false);profiler.free();settings.free();await process_frame
	var success:=checks.all(func(row):return row.ok)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":success,"checks":checks,"actual":actual,"scope":"Actual profile-ON settings/profiler/feature-contract only; no full-world feature-use, graphics or FPS claim"}));file.close()
	quit(0 if success else 1)
