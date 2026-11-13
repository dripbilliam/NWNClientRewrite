extends SceneTree
const Palette = preload("res://systems/native_render/native_light_palette.gd")
const Fence = preload("res://tools/perf140/render/native_icon_draw_fence_retained_candidate.gd")
var checks := 0
var failures: Array[String] = []
var report_path := ""
var completed_epoch := 0
var epoch := 0
var gated := false
var gates: Array = []
var rows: Array = []
class RenderGate extends RefCounted:
	var entered := Semaphore.new()
	var released := Semaphore.new()
	var lock := Mutex.new()
	var expired := false
	func block(_keep_alive: RefCounted) -> void:
		entered.post()
		var deadline := Time.get_ticks_msec()+3000
		while not released.try_wait():
			if Time.get_ticks_msec()>=deadline:
				lock.lock(); expired=true; lock.unlock(); return
			OS.delay_msec(1)
	func timed_out() -> bool:
		lock.lock(); var result := expired; lock.unlock(); return result
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func drawn(value: int) -> void: completed_epoch=value
func block_render() -> RenderGate:
	if not gated: return null
	var gate := RenderGate.new(); gates.append(gate)
	RenderingServer.call_on_render_thread(Callable(gate,"block").bind(gate))
	var entered := false; var deadline := Time.get_ticks_msec()+2000
	while not entered and Time.get_ticks_msec()<deadline:
		entered=gate.entered.try_wait()
		if not entered: OS.delay_msec(1)
	if not entered:
		gate.released.post(); failures.append("render gate did not enter within deadline")
	return gate
func release_render(gate: RenderGate) -> void:
	if gate!=null: gate.released.post()
func completed_draw(fence: CompositorEffect) -> bool:
	epoch+=1; var expected := epoch
	RenderingServer.call_on_render_thread(Callable(fence,"arm").bind(expected,fence))
	var count := 0
	while completed_epoch!=expected and count<240:
		await process_frame; count+=1
	check(completed_epoch==expected,"actual camera render epoch completes")
	return completed_epoch==expected
func expected_image(slot: int,position: Vector3,state: Dictionary,disabled: bool=false) -> Image:
	var result := Image.create(2,Palette.CAPACITY,false,Image.FORMAT_RGBAF); result.fill(Color(0,0,0,0))
	if not disabled:
		result.set_pixel(0,slot,Color(position.x,position.y,position.z,maxf(state.range,0.0001)))
		result.set_pixel(1,slot,Color(state.inverse,state.factor,1.0 if state.ambient else 0.0,1))
	return result
func observe(expected: Image,label: String) -> void:
	var actual: Image = Palette.texture.get_image()
	check(actual!=null and not actual.is_empty(),label+": GPU readback present")
	if actual==null or actual.is_empty(): return
	check(actual.get_width()==expected.get_width() and actual.get_height()==expected.get_height() and actual.get_format()==expected.get_format(),label+": exact dimensions and format")
	var exact := actual.get_data()==expected.get_data()
	check(exact,label+": exact published RGBAF bytes")
	rows.append({"label":label,"exact":exact,"format":actual.get_format(),"bytes":actual.get_data().size()})
func run() -> void:
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	root.size=Vector2i(320,240); root.msaa_3d=Viewport.MSAA_DISABLED
	var host := Node3D.new(); root.add_child(host)
	var camera := Camera3D.new(); host.add_child(camera); camera.position=Vector3(0,0,3); camera.look_at(Vector3.ZERO); camera.current=true
	var geometry := MeshInstance3D.new(); geometry.mesh=QuadMesh.new()
	var material := StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; geometry.material_override=material; host.add_child(geometry)
	var fence := Fence.new(drawn); var compositor := Compositor.new(); compositor.compositor_effects=[fence]; camera.compositor=compositor
	gated=not RenderingServer.is_on_render_thread()
	var gate := block_render()
	Palette.ensure()
	var texture_id := Palette.texture.get_instance_id(); var texture_rid := Palette.texture.get_rid()
	# No image-data alias is retained in the fixture: its expected image owns a
	# separate byte buffer, so the old implementation receives no accidental COW
	# protection from our assertions.
	Palette.image.set_pixel(0,0,Color(0.75,0.5,0.25,1))
	release_render(gate); await completed_draw(fence)
	observe(expected_image(0,Vector3.ZERO,{},true),"initial creation snapshot")
	var owner := Node.new(); host.add_child(owner); var slot := Palette.acquire(owner)
	var state := {"range":8.0,"inverse":2.0,"factor":0.2,"ambient":false}
	for turn in 12:
		gate=block_render()
		var published := Vector3(turn*0.25,turn*0.5,-turn*0.75)
		Palette.update(slot,published,state); Palette.flush()
		Palette.update(slot,Vector3(900+turn,800,700),state)
		release_render(gate); await completed_draw(fence)
		observe(expected_image(slot,published,state),"queued update snapshot "+str(turn))
		check(Palette.dirty,"new authoritative publication remains pending")
		check(Palette.texture.get_instance_id()==texture_id and Palette.texture.get_rid()==texture_rid,"no replacement GPU texture")
	# Explicit queue lifetime: a temporary CPU Image must remain alive while the
	# render command owns it, then retire after consumption.
	gate=block_render()
	var snapshot := Image.create_from_data(Palette.image.get_width(),Palette.image.get_height(),Palette.image.has_mipmaps(),Palette.image.get_format(),Palette.image.get_data())
	var weak: WeakRef=weakref(snapshot)
	Palette.texture.update(snapshot); snapshot=null
	if gated: check(weak.get_ref()!=null,"queued upload retains temporary Image")
	release_render(gate); await completed_draw(fence)
	check(weak.get_ref()==null,"temporary upload Image releases after command")
	gate=block_render(); Palette.release(slot); Palette.flush()
	Palette.image.set_pixel(1,slot,Color(1,1,1,1))
	release_render(gate); await completed_draw(fence)
	# Release only clears the enable row; the position row intentionally remains.
	var released := Image.create(2,Palette.CAPACITY,false,Image.FORMAT_RGBAF); released.fill(Color(0,0,0,0))
	released.set_pixel(0,slot,Color(911,800,700,8))
	observe(released,"release snapshot")
	for value in gates: check(not value.timed_out(),"bounded render gate never times out")
	check(Palette.texture.get_instance_id()==texture_id and Palette.texture.get_rid()==texture_rid,"all operations retain GPU texture identity")
	RenderingServer.global_shader_parameter_remove("nwn_native_lights"); RenderingServer.global_shader_parameter_remove("nwn_native_ambient"); RenderingServer.global_shader_parameter_remove("nwn_native_environment")
	Palette.image=null; Palette.texture=null; Palette.environment_texture=null; Palette.empty_environment=null; Palette.active.clear(); Palette.free_slots.clear()
	camera.compositor=null; host.free(); owner=null; camera=null; geometry=null; material=null; fence=null; compositor=null; gate=null; gates.clear()
	await process_frame; await process_frame
	var result := {"success":failures.is_empty(),"checks":checks,"failures":failures,"gated_separate_render_thread":gated,"main_on_render_thread":RenderingServer.is_on_render_thread(),"rows":rows,"scope":"Functional deterministic immutable Image upload controls with bounded test-only render gates, actual GPU bytes and one persistent texture; no FPS claim."}
	var file := FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print(JSON.stringify({"suite":"native_perf140_render_palette_upload_gpu_test","checks":checks,"failures":failures.size(),"gated":gated}))
	quit(0 if failures.is_empty() else 1)
