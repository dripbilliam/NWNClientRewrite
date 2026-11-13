extends SceneTree
const Fence = preload("res://tools/perf140/render/native_icon_draw_fence_retained_candidate.gd")
var checks := 0
var failures: Array[String] = []
var rows: Array = []
var report_path := ""
var font_path := "res://fixture-font.ttf"
var epoch := 0
var completed_epoch := 0
var gated := false
var gates: Array = []
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
		if argument.begins_with("--report="): report_path=argument.substr(9)
		if argument.begins_with("--font="): font_path=argument.substr(7)
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
		gate.released.post(); failures.append("bounded render gate failed to enter")
	return gate
func release_render(gate: RenderGate) -> void:
	if gate!=null: gate.released.post()
func completed_draw(fence: CompositorEffect) -> void:
	epoch+=1; var expected := epoch
	RenderingServer.call_on_render_thread(Callable(fence,"arm").bind(expected,fence))
	var count := 0
	while completed_epoch!=expected and count<240:
		await process_frame; count+=1
	check(completed_epoch==expected,"actual camera render epoch completes")
func snapshot(image: Image) -> Image:
	return Image.create_from_data(image.get_width(),image.get_height(),image.has_mipmaps(),image.get_format(),image.get_data())
func observe(rid: RID,expected: Image,label: String) -> void:
	var actual := RenderingServer.texture_2d_get(rid)
	check(actual!=null and not actual.is_empty(),label+": actual GPU image present")
	if actual==null or actual.is_empty(): return
	# Font atlases can use LA8 while RD readback exposes RGBA8. Compare exactly
	# after the documented Image conversion, never by tolerance or screenshots.
	var original_format := actual.get_format()
	actual.convert(Image.FORMAT_RGBA8); expected.convert(Image.FORMAT_RGBA8)
	var exact := actual.get_size()==expected.get_size() and actual.get_data()==expected.get_data()
	check(exact,label+": exact published atlas bytes")
	rows.append({"label":label,"exact":exact,"format":original_format,"bytes":actual.get_data().size(),"width":actual.get_width(),"height":actual.get_height()})
func run() -> void:
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	root.size=Vector2i(320,240); root.msaa_3d=Viewport.MSAA_DISABLED
	var host := Node3D.new(); root.add_child(host)
	var camera := Camera3D.new(); host.add_child(camera); camera.position=Vector3(0,0,3); camera.look_at(Vector3.ZERO); camera.current=true
	var geometry := MeshInstance3D.new(); geometry.mesh=QuadMesh.new()
	var material := StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; geometry.material_override=material; host.add_child(geometry)
	var fence := Fence.new(drawn); var compositor := Compositor.new(); compositor.compositor_effects=[fence]; camera.compositor=compositor
	gated=not RenderingServer.is_on_render_thread()
	var ts := TextServerManager.get_primary_interface(); check(ts.get_class()=="TextServerAdvanced","actual Advanced text server selected")
	var bytes := FileAccess.get_file_as_bytes(font_path); check(not bytes.is_empty(),"pinned actual TrueType font available")
	var font := ts.create_font(); ts.font_set_data(font,bytes)
	ts.font_set_allow_system_fallback(font,false); ts.font_set_generate_mipmaps(font,false); ts.font_set_multichannel_signed_distance_field(font,false)
	var size := Vector2i(24,0); var first := ts.font_get_glyph_index(font,24,65,0)
	ts.font_render_glyph(font,size,first)
	var rid := ts.font_get_glyph_texture_rid(font,size,first)
	var initial := snapshot(ts.font_get_texture_image(font,size,0))
	await completed_draw(fence); observe(rid,initial,"initial generated glyph creation")
	for code in range(66,78):
		var glyph := ts.font_get_glyph_index(font,24,code,0)
		ts.font_render_glyph(font,size,glyph)
		check(ts.font_get_glyph_texture_idx(font,size,glyph)==0,"fixture stays in first real atlas "+str(code))
		var gate := block_render()
		# This public getter is the actual dirty upload boundary; render_glyph
		# only rasterizes/marks dirty. Do not replace it with a mirrored helper.
		var next_rid := ts.font_get_glyph_texture_rid(font,size,glyph)
		var canonical := ts.font_get_texture_image(font,size,0)
		var expected := snapshot(canonical)
		canonical.fill(Color(1,0,1,1)) # authoritative edit AFTER publication, no new flush
		release_render(gate); await completed_draw(fence)
		observe(rid,expected,"queued dirty atlas "+str(code))
		check(next_rid==rid,"dirty glyph publication retains GPU RID "+str(code))
		# A clean query must not republish the now-edited canonical image.
		check(ts.font_get_glyph_texture_rid(font,size,glyph)==rid,"clean query retains RID "+str(code))
		await completed_draw(fence); observe(rid,expected,"clean query keeps prior publication "+str(code))
	# The caller-visible canonical Image remains mutable and owned by font until
	# free. The queued upload must own its independent Image, not this object.
	var last_glyph := ts.font_get_glyph_index(font,24,90,0); ts.font_render_glyph(font,size,last_glyph)
	var gate := block_render(); ts.font_get_glyph_texture_rid(font,size,last_glyph)
	var last_image := ts.font_get_texture_image(font,size,0); var weak := weakref(last_image); last_image=null
	ts.free_rid(font); bytes=PackedByteArray()
	check(weak.get_ref()==null,"freed font releases canonical Image while queued upload owns snapshot")
	release_render(gate); await completed_draw(fence)
	for value in gates: check(not value.timed_out(),"bounded render gate completed without timeout")
	camera.compositor=null; host.free(); camera=null; geometry=null; material=null; fence=null; compositor=null; gate=null; gates.clear(); initial=null
	await process_frame; await process_frame
	var result := {"success":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"text_server":ts.get_name(),"gated_separate_render_thread":gated,"main_on_render_thread":RenderingServer.is_on_render_thread(),"rendering_method":RenderingServer.get_current_rendering_method(),"rendering_driver":RenderingServer.get_current_rendering_driver_name(),"scope":"Actual Advanced dirty glyph atlas publication under bounded test-only render queue gates; exact pixels, clean query, same RID and release ownership. Functional only; no FPS or production error causation claim."}
	var file := FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close()
	print(JSON.stringify({"suite":"native_perf140_render_font_atlas_gpu_test","checks":checks,"failures":failures.size()}))
	quit(0 if failures.is_empty() else 1)
