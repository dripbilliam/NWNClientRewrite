extends SceneTree
const Effect=preload("res://systems/native_render/native_gamma_effect.gd")
const Post=preload("res://systems/native_render/native_postprocess.gd")
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	var png:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--png="): png=arg.substr(6)
	if report.is_empty() or png.is_empty() or FileAccess.file_exists(report): quit(2);return
	root.size=Vector2i(256,256)
	var effect:=Effect.new()
	effect.set_surface_output(true)
	var opted:=OS.get_environment("NWN71_GAMMA_PREWARM")=="1"
	if opted:
		for n in 240:
			if bool(effect.snapshot().get("prewarm",{}).get("tone_completed",false)):break
			await process_frame
		check(bool(effect.snapshot().get("prewarm",{}).get("tone_completed",false)),"Tonal pipeline prepared before camera/compositor installation")
		check(effect.tone_pipeline.is_valid() and effect.midpoint_pipeline.is_valid(),"Both tonal pipelines are valid before first callback")
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();world.add_child(environment)
	environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.1,.2,.3);environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var camera:=Camera3D.new();world.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.position=Vector3(0,0,5);camera.make_current()
	var compositor:=Compositor.new();compositor.compositor_effects=[effect];camera.compositor=compositor
	var quad:=MeshInstance3D.new();world.add_child(quad);quad.mesh=QuadMesh.new();quad.mesh.size=Vector2(2,2)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.4,.25,.1);quad.material_override=material
	var ui:=CanvasLayer.new();world.add_child(ui);var tile:=ColorRect.new();ui.add_child(tile);tile.position=Vector2(5,5);tile.size=Vector2(20,20);tile.color=Color(.2,.4,.8)
	check(effect.set_postprocess({"mask":8,"intensity":.15,"midpoint":.4,"vibrance":.7}),"Tonal postprocess admitted")
	var frame:=Post.empty_frame();var state: Dictionary=effect.postprocess_state()
	check(effect.publish_postprocess_frame(frame,int(state.revision)),"Tonal frame published")
	effect.set_gamma(1.2)
	for n in 16: await process_frame
	await RenderingServer.frame_post_draw
	var after: Dictionary=effect.snapshot()
	check(after.failure.is_empty() and after.passes>0 and after.midpoint_passes>0,"Tonal and midpoint GPU passes completed")
	if opted:check(after.prewarm.tone_completed and after.prewarm.tone_requested,"First callback reused prepared tonal pipeline")
	var image:=root.get_texture().get_image()
	check(image.get_width()==256 and image.get_height()==256,"Expected 256 pixel render target")
	if failures.is_empty():check(image.save_png(png)==OK,"Diagnostic PNG saved")
	var sample:=image.get_pixel(128,128);var ui_sample:=image.get_pixel(10,10)
	var result:={"success":failures.is_empty(),"failures":failures,"opted":opted,"snapshot":after,"center":[sample.r,sample.g,sample.b],"ui":[ui_sample.r,ui_sample.g,ui_sample.b],"png":png,"scope":"Small authored GPU correctness fixture; no FPS or original-area acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"\t"));file.close()
	effect.close();world.free()
	await process_frame
	quit(0 if result.success else 1)
