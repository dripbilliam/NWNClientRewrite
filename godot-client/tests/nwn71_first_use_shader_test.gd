extends SceneTree
const PipelinePreparation=preload("res://tests/nwn71_pipeline_preparation.gd")
# This diagnostic never measures FPS. --gpu-first-use requires a real RD
# graphical driver; default mode exercises only the controlled worker group.
var output:=""
var gpu:=false
var require_tracy:=false
var bridge: RefCounted
var material_variant:=0
var expected_separate:=false
var preparation_mode:="none"
var preparation_report: Dictionary={}
var checks:=0
var failures: Array=[]
var worker_mutex:=Mutex.new()
var completed: Array=[]
var phases: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg=="--gpu-first-use":gpu=true
		if arg=="--require-tracy":require_tracy=true
		if arg.begins_with("--material-variant="):material_variant=int(arg.trim_prefix("--material-variant="))
		if arg=="--expected-separate":expected_separate=true
		if arg.begins_with("--pipeline-preparation="):preparation_mode=arg.trim_prefix("--pipeline-preparation=")
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func sentinel(index: int) -> void:
	# POD work on worker threads, no scene/resource APIs. A known tiny delay
	# creates an identifiable wait while retaining normal group scheduling.
	OS.delay_msec(10)
	worker_mutex.lock();completed.append(index);worker_mutex.unlock()
func mark(phase: String,data: Dictionary={}) -> void:
	var row:={"phase":phase,"ticks_us":Time.get_ticks_usec(),"process_frame":Engine.get_process_frames()};row.merge(data);phases.append(row)
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	if require_tracy:
		check(ClassDB.class_exists("NwnParticlePresentation"),"private existing diagnostic bridge class is loaded")
		if failures.is_empty():
			bridge=ClassDB.instantiate("NwnParticlePresentation")
			var deadline:=Time.get_ticks_msec()+30000
			var info: Dictionary={}
			while Time.get_ticks_msec()<deadline:
				info=bridge.dispatch(65000,{})
				if info.get("bound",false) and info.get("connected",false):break
				await process_frame
			check(info.get("bound",false) and info.get("connected",false),"actual engine Tracy bridge connected before controlled work")
			mark("tracy_connected",info)
	else:await create_timer(1.0).timeout
	if not failures.is_empty():finish();return
	mark("sentinel_submit")
	var group:=WorkerThreadPool.add_group_task(sentinel,4,2,true,"NWN71_ControlledGroupSentinel")
	WorkerThreadPool.wait_for_group_task_completion(group)
	worker_mutex.lock();var done:=completed.duplicate();worker_mutex.unlock();done.sort()
	mark("sentinel_complete",{"group_id":group,"description":"NWN71_ControlledGroupSentinel","indices":done})
	check(done==[0,1,2,3],"controlled group completes every indexed task")
	if gpu:
		check(DisplayServer.get_name()!="headless","first-use reproduction requires a graphical RD driver")
		check(RenderingServer.get_current_rendering_method() in ["forward_plus","mobile"],"first-use reproduction uses ShaderRD rather than dummy/GLES3 rendering")
		check(material_variant>=0 and material_variant<1000000,"controlled shader code variant stays within explicit bounds")
		check(preparation_mode in ["none","rid","exact_draw"],"explicit bounded preparation mode")
		if expected_separate:check(not RenderingServer.is_on_render_thread(),"script runs outside the separate rendering thread")
		if failures.is_empty():await first_use()
	finish()
func finish() -> void:
	if bridge!=null:bridge.dispatch(5,{});bridge=null
	var screen:={"current_screen":root.current_screen,"primary_screen":DisplayServer.get_primary_screen(),"unfocusable":root.get_flag(Window.FLAG_NO_FOCUS)}
	if gpu:check(screen.current_screen!=screen.primary_screen and screen.unfocusable,"GPU diagnostic stays on actual nonprimary unfocusable window")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"gpu_first_use":gpu,"require_tracy":require_tracy,"material_variant":material_variant,"preparation_mode":preparation_mode,"preparation":preparation_report,"render_thread":{"expected_separate":expected_separate,"script_is_on_render_thread":RenderingServer.is_on_render_thread()},"window":screen,"phases":phases,"engine":{"version":Engine.get_version_info(),"display":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method()},"scope":"Controlled group ID/description sentinel and optional actual first-use spatial shader. Preparation prototype uses exact same authored geometry/material/viewport, with full ready andvisible latency accounted. No originalasset/animation/live/FPS acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
func first_use() -> void:
	if preparation_mode!="none":await prepared_first_use();return
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,3);camera.current=true
	var mesh:=MeshInstance3D.new();mesh.mesh=SphereMesh.new();world.add_child(mesh)
	# New custom code instantiates only one justified material family; no broad
	# variant warmup and no production shader/cache mutation.
	var shader:=Shader.new()
	mark("material_code_start")
	# This numeric literal changes actual fragment output and survives shader
	# compilation. A comment-only tag could be stripped before shader caching.
	var red:=0.25+float(material_variant)/1048576.0
	shader.code="shader_type spatial; render_mode unshaded; void fragment(){ ALBEDO=vec3("+String.num(red,9)+",0.65,0.9); }"
	var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
	mark("material_submitted",{"shader_code_sha256":shader.code.sha256_text(),"material_variant":material_variant,"red_constant":red})
	await RenderingServer.frame_post_draw
	mark("first_draw_complete")
	for index in 3:await RenderingServer.frame_post_draw
	mark("settled_draws_complete")
	check(mesh.is_visible_in_tree() and camera.is_current(),"first-use fixture retains intended mesh/material/camera")
	world.free();await RenderingServer.frame_post_draw
	mark("fixture_freed")
func pipeline_counts() -> Dictionary:
	return {"canvas":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),"mesh":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),"surface":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),"draw":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),"specialization":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)}
func prepared_first_use() -> void:
	var began:=Time.get_ticks_usec();mark("preparation_case_begin",{"mode":preparation_mode})
	var job:=PipelinePreparation.new();check(job.open(root,preparation_mode,material_variant),"private sameviewport case opens")
	# An identical loading cover is established in both cases before geometry.
	RenderingServer.force_draw(true,0.0);RenderingServer.force_sync();mark("loading_cover_drawn")
	var before:=pipeline_counts();mark("material_code_start")
	check(job.request_material(),"same actual mesh/material requested once")
	var requested:=Time.get_ticks_usec();mark("material_submitted",{"shader_code_sha256":job.shader.code.sha256_text(),"material_variant":material_variant,"mode":preparation_mode})
	var identity: Dictionary=job.identity();var prepared: Dictionary={}
	if preparation_mode=="exact_draw":
		mark("pipeline_preparation_draw_start")
		check(job.draw_preparation(),"covered draw and render sync finish before handoff")
		mark("pipeline_preparation_draw_complete");prepared=pipeline_counts()
	check(job.identity()==identity,"preparation retains exact resources/layout")
	check(job.handoff(),"readiness andloading cover release at the specified fence")
	var ready:=Time.get_ticks_usec();mark("ready_handoff",{"mode":preparation_mode})
	var before_visible:=pipeline_counts();var visible_began:=Time.get_ticks_usec();mark("first_visible_draw_start")
	check(job.draw_visible(),"first visible draw completes using same actualresources")
	var visible:=Time.get_ticks_usec();mark("first_visible_draw_complete");mark("first_draw_complete")
	var after_visible:=pipeline_counts();check(job.identity()==identity,"first visible draw never recreates or substitutes resources")
	check(job.mesh.is_visible_in_tree() and job.camera.is_current() and not job.cover.visible,"handoff exposes the intended scene")
	preparation_report={"mode":preparation_mode,"case_to_ready_ms":(ready-began)/1000.0,"case_to_first_visible_ms":(visible-began)/1000.0,"request_to_ready_ms":(ready-requested)/1000.0,"request_to_first_visible_ms":(visible-requested)/1000.0,"ready_to_first_visible_ms":(visible-ready)/1000.0,"first_visible_draw_ms":(visible-visible_began)/1000.0,"before":before,"after_preparation":prepared,"before_visible":before_visible,"after_visible":after_visible,"scene":job.snapshot(),"scope":"Same mainviewport/renderlayout/exact authoredArrayMesh+ShaderMaterial resources; baseline onlyget_rid, candidate extra covered draw+sync. Total latency includes preparation, no cost hidden from ready."}
	for index in 3:await RenderingServer.frame_post_draw
	mark("settled_draws_complete");job.close();await RenderingServer.frame_post_draw;mark("fixture_freed")
