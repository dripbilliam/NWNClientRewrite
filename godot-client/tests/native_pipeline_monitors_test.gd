extends SceneTree
const Profile=preload("res://systems/native_render/frame_profile.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""; var expected_thread:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--expected-render-thread="): expected_thread=arg.substr(25)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var providers: Dictionary={}
	for name in ["Performance","RenderingServer"]:
		var constants: Dictionary={}
		for item in ClassDB.class_get_integer_constant_list(name):
			if "PIPELINE" in str(item): constants[str(item)]=ClassDB.class_get_integer_constant(name,item)
		var methods: Array=[]
		for method in ClassDB.class_get_method_list(name):
			if "rendering_info" in str(method.name) or "monitor" in str(method.name): methods.append(method.name)
		providers[name]={"constants":constants,"methods":methods}
	var profile:=Profile.new(); root.add_child(profile); profile.configure(root); profile.set_process(false)
	var deadline:=Time.get_ticks_msec()+5000
	while not profile.render_thread_info.snapshot().get("observed",false) and Time.get_ticks_msec()<deadline: await process_frame
	var thread_info: Dictionary=profile.render_thread_info.snapshot()
	check(thread_info.get("observed",false) and int(thread_info.get("thread_id",0))>0 and int(thread_info.get("main_thread_id",0))==OS.get_main_thread_id(),"Supported callback observes actual render execution thread without main-thread blocking")
	check(expected_thread.is_empty() or bool(thread_info.get("separate",false))==(expected_thread=="separate"),"Actual render thread matches the requested engine mode")
	check(profile.pipeline_monitors.size()==5 and providers.Performance.constants.size()==5,"All five actual installed-engine pipeline compilation counters are registered")
	var expected: Array=[]
	for name in providers.Performance.constants: expected.append(str(name).to_lower())
	check(profile.pipeline_monitors.keys().all(func(name):return expected.has(name)),"Production monitor names refer to real Performance constants, not the obsolete prefix")
	var first: Dictionary=profile.collect(Time.get_ticks_usec()); var baseline:=true
	for name in profile.pipeline_monitors: baseline=baseline and first.has(name) and first[name]>=0 and first[name+"_delta"]==0
	check(baseline,"First actual sample records cumulative counters with zero baseline deltas")
	check(first.has("render_setup_cpu_ms") and is_finite(float(first.render_setup_cpu_ms)) and float(first.render_setup_cpu_ms)>=0,"Installed render-setup API is readable in native milliseconds without synchronizing the GPU")
	if DisplayServer.get_name()!="headless":
		var initial_boundaries: int=profile.render_boundary_count
		deadline=Time.get_ticks_msec()+5000
		while profile.render_boundary_count==initial_boundaries and Time.get_ticks_msec()<deadline: await process_frame
		var rendered: Dictionary=profile.collect(Time.get_ticks_usec())
		var render_wall: float=float(rendered.get("postdraw_render_frame_wall_ms",rendered.get("render_frame_wall_ms",-1)))
		var boundaries: int=int(rendered.get("postdraw_count_render_boundaries",rendered.get("count_render_boundaries",0)))
		check(profile.render_boundary_count>initial_boundaries and render_wall>=0 and boundaries==1,"Real engine pre/post draw signals contribute one separately identified render wall interval")
	else:
		await process_frame; await process_frame
		check(profile.render_boundary_count==0 and profile.render_started==0,"Headless mode does not invent draw boundaries or render wall measurements")
	for name in profile.pipeline_monitors: profile.previous_pipeline_counts[name]=1e15
	var second: Dictionary=profile.collect(Time.get_ticks_usec()); var nonnegative:=true
	for name in profile.pipeline_monitors: nonnegative=nonnegative and second[name]>=0 and second[name+"_delta"]==0
	check(nonnegative,"Counter reset cannot fabricate negative compilation activity")
	profile.set_enabled(false); check(profile.previous_pipeline_counts.is_empty(),"Disabling profiling drops stale pipeline baselines")
	await process_frame; await process_frame
	check(profile.render_started==0 and profile.render_boundary_count==0 and profile.phases.is_empty() and profile.postdraw_phases.is_empty(),"Disabled profiling records no render-boundary samples or stale start timestamps")
	profile.set_enabled(true); var restarted: Dictionary=profile.collect(Time.get_ticks_usec())
	check(profile.pipeline_monitors.keys().all(func(name):return restarted[name+"_delta"]==0),"Reenabled profiling starts fresh rather than charging the previous interval")
	profile.free(); await process_frame
	var value:={"success":failures.is_empty(),"checks":checks,"failures":failures,"providers":providers,"render_thread":thread_info,"expected_render_thread":expected_thread,"thread_model":ProjectSettings.get_setting("rendering/driver/threads/thread_model",0),"engine":Engine.get_version_info(),"public_connections":0,"scope":"Actual installed-engine API registration, observed render thread IDs and cumulative/delta baseline/reset behavior. No performance or compilation-cause acceptance."}
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify(value,"\t")); output.close(); quit(0 if failures.is_empty() else 1)
