extends SceneTree
# Diagnostic only: a two-sided occluder is intentionally paired with the same
# one-sided rendered wall. Controls establish pixels; a mismatch is reported,
# not hidden or treated as an accepted renderer optimization.
const Fence = preload("res://tools/perf140/render/native_icon_draw_fence_retained_candidate.gd")
var report_path := ""
var completed_epoch := 0
var epoch := 0
var failures: Array[String] = []
var host: Node3D
var camera: Camera3D
var wall: MeshInstance3D
var target: MeshInstance3D
var occluder: OccluderInstance3D
var fence: CompositorEffect
var compositor: Compositor
var rows: Array = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_path = argument.substr(9)
	call_deferred("run")
func drawn(value: int) -> void: completed_epoch = value
func material(color: Color, cull: int) -> StandardMaterial3D:
	var result := StandardMaterial3D.new(); result.albedo_color = color
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; result.cull_mode = cull
	return result
func run() -> void:
	if report_path.is_empty():
		push_error("An explicit private --report path is required"); quit(1); return
	root.size = Vector2i(320,240); root.msaa_3d = Viewport.MSAA_DISABLED
	host = Node3D.new(); root.add_child(host)
	var environment_owner := WorldEnvironment.new(); var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR; environment.background_color = Color.BLACK
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR; environment_owner.environment = environment; host.add_child(environment_owner)
	camera = Camera3D.new(); camera.near = 0.1; camera.far = 100.0; host.add_child(camera); camera.current = true
	fence = Fence.new(drawn); compositor = Compositor.new(); compositor.compositor_effects = [fence]; camera.compositor = compositor
	var wall_mesh := QuadMesh.new(); wall_mesh.size = Vector2(20,20)
	wall = MeshInstance3D.new(); wall.mesh = wall_mesh; wall.material_override = material(Color.RED,BaseMaterial3D.CULL_BACK); host.add_child(wall)
	var target_mesh := QuadMesh.new(); target_mesh.size = Vector2(1,1)
	target = MeshInstance3D.new(); target.mesh = target_mesh; target.material_override = material(Color.GREEN,BaseMaterial3D.CULL_DISABLED); host.add_child(target)
	var arrays := wall_mesh.surface_get_arrays(0)
	var shape := ArrayOccluder3D.new(); shape.set_arrays(arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_INDEX])
	occluder = OccluderInstance3D.new(); occluder.occluder = shape; host.add_child(occluder)
	for back in [false,true]:
		for enabled in [false,true]: await sample(back,enabled,false)
	# A material that really draws both sides is the conservative control.
	for enabled in [false,true]: await sample(true,enabled,true)
	var front_off: Dictionary = rows[0]; var front_on: Dictionary = rows[1]
	var back_off: Dictionary = rows[2]; var back_on: Dictionary = rows[3]
	var two_sided_off: Dictionary = rows[4]; var two_sided_on: Dictionary = rows[5]
	if front_off.color != "red": failures.append("front control did not see opaque wall")
	if back_off.color != "green": failures.append("back control did not see target through culled wall")
	if front_on.color != "red": failures.append("front occlusion changed opaque wall")
	if two_sided_off.color != "red" or two_sided_on.color != "red": failures.append("two-sided material controls failed")
	var result := {"success":failures.is_empty(),"diagnostic_only":true,"accepted_occlusion_change":false,"failures":failures,"rows":rows,"one_sided_backface_mismatch":back_off.color != back_on.color,"main_on_render_thread":RenderingServer.is_on_render_thread(),"rendering_method":RenderingServer.get_current_rendering_method(),"rendering_driver":RenderingServer.get_current_rendering_driver_name(),"note":"A clean diagnostic can expose an intentionally unsafe one-sided wall/occluder mismatch; it does not approve all-tile occlusion."}
	root.use_occlusion_culling = false; camera.compositor = null
	host.free(); host = null; camera = null; wall = null; target = null; occluder = null; compositor = null; fence = null
	await process_frame; await process_frame
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	if file == null: push_error("Cannot write private occlusion report"); quit(1); return
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print(JSON.stringify({"suite":"native_perf140_render_occlusion_faces_gpu_test","success":result.success,"rows":rows.size(),"one_sided_backface_mismatch":result.one_sided_backface_mismatch}))
	quit(0 if result.success else 1)
func sample(back: bool, enabled: bool, two_sided: bool) -> void:
	camera.position = Vector3(0,0,-5 if back else 5); camera.look_at(Vector3.ZERO)
	target.position.z = 1.0 if back else -1.0
	(wall.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_BACK
	root.use_occlusion_culling = enabled
	# Let asynchronous occluder BVH publication and HZ timeout settle. This is
	# functional evidence, not a throughput benchmark.
	for frame in 90: await process_frame
	epoch += 1; var expected := epoch
	RenderingServer.call_on_render_thread(Callable(fence,"arm").bind(expected,fence))
	var waits := 0
	while completed_epoch != expected and waits < 180:
		await process_frame; waits += 1
	if completed_epoch != expected:
		failures.append("camera render fence timeout"); rows.append({"color":"timeout"}); return
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures.append("viewport readback missing"); rows.append({"color":"missing"}); return
	var pixel := image.get_pixel(image.get_width()/2,image.get_height()/2)
	var color := "red" if pixel.r > 0.5 and pixel.r > pixel.g*2 else "green" if pixel.g > 0.5 and pixel.g > pixel.r*2 else "black" if maxf(pixel.r,maxf(pixel.g,pixel.b)) < 0.1 else "other"
	var name := ("back" if back else "front")+("-on" if enabled else "-off")+("-two-sided" if two_sided else "-one-sided")
	var png := report_path.trim_suffix(".json")+"."+name+".png"; var saved := image.save_png(png)
	if saved != OK: failures.append("PNG save failed: "+str(saved))
	rows.append({"name":name,"color":color,"pixel":[pixel.r,pixel.g,pixel.b,pixel.a],"occlusion_enabled":root.use_occlusion_culling,"objects":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_OBJECTS_IN_FRAME),"draws":root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"png":png,"waits":waits})
