extends SceneTree
const Host=preload("res://systems/native_item_icon_panel_host.gd")
var checks:=0
var failures: Array=[]

class FakePool:
	extends RefCounted
	var compact_static_parts:=false
	var native_lighting:=false
	var failure:=""
	var shared_mesh: Mesh=BoxMesh.new()
	func geometry(_digest: String,_index: int,_data: Dictionary) -> Mesh:
		shared_mesh.set_meta("native_pick_geometry",{})
		return shared_mesh
	func material(_row: Dictionary,_raster: Dictionary) -> Material:
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color.WHITE
		return material

func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)

func wait_host(host,frames: int=120) -> bool:
	for _frame in frames:
		if host.presentation_ready():return true
		await process_frame
	return host.presentation_ready()

func bundle() -> Dictionary:
	var mesh:={"indices":[0,1,2,0,2,3],"render":true,"textures":[],"shadow":false}
	var row:={"name":"icon","parent":-1,"position":[0.25,0.5,0.75],"orientation":[0.0,0.0,0.0,1.0],"scale":1.0,"flags":0,"alpha":1.0,"features":[],"mesh":mesh}
	return {"sha256":"fixture-mdl","value":{"name":"GUI_ICON_1X1L","nodes":[row],"animations":[]},"textures":{},"dependencies":[]}

func run() -> void:
	var gpu:=OS.get_cmdline_user_args().has("--gpu")
	if gpu:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		root.size=Vector2i(450,240)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:
				root.current_screen=screen
				root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80)
				break
	var panel:=Control.new()
	panel.position=Vector2(20,20)
	panel.size=Vector2(132,99)
	root.add_child(panel)
	var background:=ColorRect.new()
	background.color=Color(0.02,0.07,0.11)
	background.size=panel.size
	panel.add_child(background)
	var host=Host.new()
	panel.add_child(host)
	host.size=panel.size
	var pool:=FakePool.new()
	check(host.configure(pool),"Configured one panel host")
	check(host.viewport!=null and host.camera!=null and host.presentation!=null,"One viewport, camera and live presentation")
	check(host.presentation.texture==host.viewport.get_texture(),"Presentation reuses the live ViewportTexture")
	check(host.viewport.transparent_bg and host.viewport.own_world_3d,"Transparent isolated 3D panel scene")
	check(host.viewport.size==Vector2i(132,99) and is_equal_approx(host.camera.size,0.99),"Panel pixels map to 0.01 model units")
	var icon_bundle:=bundle()
	check(host.bind_slot("first","same-key",icon_bundle,Vector2(33,66)),"First item model installed")
	check(host.bind_slot("second","same-key",icon_bundle,Vector2(99,33),0.4),"Second item model installed")
	var unchanged_revision: int=host.revision
	check(host.bind_slot("first","same-key",icon_bundle,Vector2(33,66)) and host.revision==unchanged_revision,"Unchanged binding does not invalidate draw readiness")
	check(not host.binding_ready("first") and not host.binding_ready("second"),"Installation does not claim viewport presentation")
	if gpu:
		await wait_host(host)
		check(host.binding_ready("first") and host.binding_ready("second"),"Panel camera reports the current binding cohort rendered")
		for _frame in 2:await process_frame
		check(host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and host.presentation.visible,"Settled live texture has no continuing 3D viewport updates")
		var settled_revision: int=host.revision
		check(host.bind_slot("first","same-key",icon_bundle,Vector2(33,66)) and host.revision==settled_revision and host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Unchanged settled binding adds no GPU work")
		var panel_image: Image=host.viewport.get_texture().get_image()
		var root_image: Image=root.get_texture().get_image()
		var panel_pixels:=0
		var composed_pixels:=0
		if panel_image!=null and not panel_image.is_empty():
			for y in panel_image.get_height():
				for x in panel_image.get_width():
					if panel_image.get_pixel(x,y).a>0.2:panel_pixels+=1
		if root_image!=null and not root_image.is_empty():
			for y in range(20,mini(119,root_image.get_height())):
				for x in range(20,mini(152,root_image.get_width())):
					var pixel:=root_image.get_pixel(x,y)
					if pixel.r>0.5 and pixel.g>0.5 and pixel.b>0.5:composed_pixels+=1
		check(panel_pixels>0,"Panel SubViewport contains actual model pixels")
		check(composed_pixels>0,"Parent UI composites the live panel texture")
		print(JSON.stringify({"gpu_panel_pixels":panel_pixels,"gpu_composed_pixels":composed_pixels,"rendering_method":RenderingServer.get_current_rendering_method()}))
	else:
		for _frame in 3:await process_frame
		check(not host.binding_ready("first") and not host.binding_ready("second"),"Headless mode cannot falsely claim a rendered frame")
	var first=host.slots.first.model
	var second=host.slots.second.model
	check(first!=second and first.meshes[0].mesh==second.meshes[0].mesh,"Each binding owns a model while sharing immutable geometry")
	check(first.position.is_equal_approx(Vector3(0.33,0,-0.66)) and second.position.is_equal_approx(Vector3(0.99,0,-0.33)),"Panel-local top-left anchors map to 3D")
	var first_projected: Vector2=host.camera.unproject_position(first.global_position)
	var second_projected: Vector2=host.camera.unproject_position(second.global_position)
	check(host.presentation.flip_v and Vector2(first_projected.x,host.viewport.size.y-first_projected.y).distance_to(Vector2(33,66))<0.1 and Vector2(second_projected.x,host.viewport.size.y-second_projected.y).distance_to(Vector2(99,33))<0.1,"Composited model origins land at their top-left panel anchors")
	check(is_equal_approx(second.meshes[0].transparency,0.6),"Disabled alpha is per binding")
	var first_part=first.parts[0]
	check(first_part.position.is_equal_approx(Vector3(0.25,0.75,-0.5)),"Authored part transform is retained")
	check(host.bind_slot("first","same-key",icon_bundle,Vector2(66,66)) and host.slots.first.model==first,"Matching binding repositions without reconstructing")
	check(host.reposition_slot("second",Vector2(100,50),1.0) and is_equal_approx(second.meshes[0].transparency,0.0),"Reposition updates transform and alpha")
	if gpu:
		check(not host.presentation_ready() and host.viewport.render_target_update_mode==SubViewport.UPDATE_ONCE and not host.presentation.visible,"Changed position and alpha request only one new panel draw")
		check(await wait_host(host) and host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Reposition draw settles and turns the viewport off again")
	host.resize_panel(Vector2(200,100))
	check(host.viewport.size==Vector2i(200,100) and is_equal_approx(host.camera.size,1.0),"Resize updates panel camera and viewport")
	var resized_projection: Vector2=host.camera.unproject_position(first.global_position)
	check(Vector2(resized_projection.x,host.viewport.size.y-resized_projection.y).distance_to(Vector2(66,66))<0.1,"Resized panel preserves the composited item anchor")
	if gpu:
		check(not host.presentation_ready() and host.viewport.render_target_update_mode==SubViewport.UPDATE_ONCE,"Resize invalidates the static icon image")
		check(await wait_host(host) and host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Resized panel redraws exactly to a settled state")
		panel.hide()
		check(host.bind_slot("first","replacement-key",icon_bundle,Vector2(44,66)),"Hidden panel accepts a replacement item model")
		check(not host.binding_ready("first") and not host.presentation.visible,"Hidden rebind cannot present stale icon pixels")
		panel.show()
		check(await wait_host(host) and host.binding_ready("first") and host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Reopened panel obtains replacement draw receipt without continuous updates")
	host.unbind_slot("first")
	check(not host.slots.has("first") and host.slots.has("second"),"Unbind retires one model")
	host.clear()
	check(host.slots.is_empty() and host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not host.presentation.visible,"Clear retires all models and hides stale pixels")
	if gpu:
		check(host.bind_slot("reopen","same-key",icon_bundle,Vector2(66,50)),"Cleared panel can reopen with a new binding")
		check(not host.binding_ready("reopen") and not host.presentation.visible,"Reopened binding waits for a fresh draw")
		check(await wait_host(host) and host.binding_ready("reopen") and host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Reopened panel settles with viewport disabled")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Panel host ownership, transforms, alpha, resize and live ViewportTexture; optional graphical pixel/draw receipt, no FPS.","gpu":gpu}
	print(JSON.stringify(report))
	panel.free()
	quit(0 if failures.is_empty() else 1)
