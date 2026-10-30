extends "res://tests/native_quickbar_frame_test.gd"
const Menu=preload("res://systems/native_main_menu.gd")
const Settings=preload("res://systems/native_window_settings.gd")
const Policy=preload("res://systems/native_data/video_options_layout.gd")
func capture(output: String,suffix: String) -> void:
	for at in 3: await process_frame
	await RenderingServer.frame_post_draw; surface.get_texture().get_image().save_png(output.trim_suffix(".json")+suffix+".png")
func glyph_pixels(image: Image,control: Control) -> int:
	var point:=Vector2i(control.get_global_rect().position.round()); var count:=0
	for y in range(4,12):
		for x in range(4,12):
			var color:=image.get_pixelv(point+Vector2i(x,y))
			if color.r>0.25 and color.g>0.15 and color.b<color.r: count+=1
	return count
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1800,1100)
	var preferences:=output+".settings.cfg"; var service:=Settings.new(); root.add_child(service); service.configure(root,preferences)
	check(await wait_until(func():return service.query_ready),"Read-only native mode query finishes on its worker")
	check(service.error.is_empty() and not service.modes().is_empty() and service.worker==null,"Actual current monitor exposes native modes without changing it")
	surface=SubViewport.new(); surface.size=Vector2i(1200,850); surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=surface.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original video-page GUI/models mount read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg")
	check(await wait_until(func():return ui.tables_ready and ui.inventory.frame_skin.fonts!=null),"Active original UI resource/font owners prepare")
	var world:=WorldInput.new(); surface.add_child(world)
	var menu:=Menu.new(); surface.add_child(menu); menu.window_settings=service; menu.layout_path=output+".layout.cfg"; menu.playing_query=func():return true; menu.connection_query=func():return true
	menu.configure_native(ui.inventory.frame_skin,ui.text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"),[1,1,55,42]); menu.observe_lobby({"connected":true,"busy":false,"phase":"playing"}); menu.open(true)
	var video=menu.video_owner
	check(await wait_until(func():return video.art_ready() or not video.failure.is_empty()),"Original video panel, nested scale controls, fonts and animated scrollbar prepare")
	var diagnostic: Dictionary={"failure":video.failure}; var committed_scale:=Policy.f(1.2)
	if video.layout_ready and video.failure.is_empty():
		check(not menu.native_frame.buttons.videooptionsbutton.disabled,"Resolution menu control enables only with its actual native owner")
		await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center())
		check(video.visible and not menu.panel.visible and video.size==Vector2(372,384),"Actual Resolution click opens the source372x384 child and hides its parent")
		check(video.mode_list.get_child_count()==service.modes().size() and video.mode_list.get_children().all(func(child):return child is Label),"Native mode rows are read-only labels, preserving the original disabled selection")
		check(video.labels.intedit is Label and video.labels.intedit.text=="1.0" and video.labels.currres.text.ends_with("1800x1100"),"Runtime status text uses actual window data and the original read-only scale label")
		await capture(output,"-normal")
		var pixels:=surface.get_texture().get_image()
		check(glyph_pixels(pixels,video.buttons.intupbutton)>=4 and glyph_pixels(pixels,video.buttons.intdownbutton)>=4,"Original arrow glyph pixels remain visible above the shared scale-label background")
		var before: int=world.movement; await key(KEY_W); await key(KEY_W,false); check(world.movement==before+1,"WASD remains available while the native video page is open")
		before=world.middle; await click(Vector2(1110,80),MOUSE_BUTTON_MIDDLE); check(world.middle==before+1,"Outside middle mouse remains available to the world")
		before=world.clicks; await click(Vector2(1110,80)); check(world.clicks==before+1 and not menu.blocks_pointer(Vector2(1110,80)) and menu.blocks_pointer(video.get_global_rect().get_center()),"Only the actual video rectangle blocks click movement")
		var start: Vector2=video.position; var title_point: Vector2=video.labels.tguilabel.get_global_rect().get_center(); await motion(title_point); await mouse(title_point,true); await motion(title_point+Vector2(35,20),Vector2(35,20),true); await mouse(title_point+Vector2(35,20),false)
		var remembered: Vector2=video.position; var placement:=ConfigFile.new()
		check(remembered.distance_to(start+Vector2(35,20))<1 and placement.load(menu.layout_path)==OK and placement.get_value("positions","video-options",Vector2.ZERO)==remembered,"Dragging the original video title persists its native window position")
		await click(video.buttons.intupbutton.get_global_rect().get_center())
		check(video.pending_scale==Policy.f(1.1) and service.applied_scale==1.0 and not FileAccess.file_exists(preferences),"Scale arrows edit pending state without applying or persisting it")
		await click(video.buttons.cancelbutton.get_global_rect().get_center())
		check(not video.visible and menu.panel.visible and service.applied_scale==1.0 and not FileAccess.file_exists(preferences),"Cancel before Apply returns to Options and discards pending scale")
		await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center()); check(video.position==remembered,"Reopening the video child retains its last dragged position"); await click(video.buttons.intupbutton.get_global_rect().get_center()); await click(video.buttons.applybutton.get_global_rect().get_center())
		check(video.visible and not menu.panel.visible and video.applied and service.applied_scale==Policy.f(1.1) and not FileAccess.file_exists(preferences),"Apply changes the real window UI scale and keeps the child open with a pending config write")
		await capture(output,"-applied")
		var unrelated:=ConfigFile.new(); unrelated.set_value("interface","creature_slots",true); unrelated.set_value("rendering","particles_enabled",false); unrelated.save(preferences)
		await click(video.buttons.intupbutton.get_global_rect().get_center()); await click(video.buttons.cancelbutton.get_global_rect().get_center())
		var saved:=ConfigFile.new(); saved.load(preferences)
		check(menu.panel.visible and service.applied_scale==Policy.f(1.1) and Policy.f(float(saved.get_value("interface","ui_scale",0)))==Policy.f(1.1),"Cancel after Apply commits the applied value, discarding later unapplied edits")
		check(saved.get_value("interface","creature_slots",false)==true and saved.get_value("rendering","particles_enabled",true)==false,"Committing scale preserves independent creature-slot and particle preferences")
		await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center())
		check(video.pending_scale==Policy.f(1.1) and not video.applied,"Reopening starts from the actual current scale and a fresh transaction")
		await click(video.buttons.intupbutton.get_global_rect().get_center()); await click(video.buttons.okbutton.get_global_rect().get_center()); saved.load(preferences)
		check(menu.panel.visible and not video.visible and service.applied_scale==Policy.f(1.2) and Policy.f(float(saved.get_value("interface","ui_scale",0)))==Policy.f(1.2),"OK applies and persists the native scale before restoring Options")
		await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center()); await click(video.buttons.intupbutton.get_global_rect().get_center()); await click(video.buttons.xbutton.get_global_rect().get_center())
		check(menu.panel.visible and service.applied_scale==Policy.f(1.2),"Original X follows Cancel without applying a later pending edit")
		await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center()); await key(KEY_ESCAPE); await key(KEY_ESCAPE,false)
		check(not video.visible and menu.panel.visible,"Escape closes the video child and restores its parent first")
		await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center()); var point: Vector2=video.buttons.applybutton.get_global_rect().get_center(); var applies: int=service.applies; await motion(point); await mouse(point,true)
		menu.set_native_scope([2,2,77,99]); menu.open(true); await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center()); await mouse(point,false)
		check(service.applies==applies,"A held Apply cannot retarget a new connection/area scope")
		video.finish_page(); diagnostic=video.snapshot(); diagnostic.art_failures=ui.inventory.frame_skin.art.failed.keys(); diagnostic.physicalMouseWarped=false
		var overlay:=Control.new(); overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(overlay)
		var native_button:=Button.new(); overlay.add_child(native_button); ui.inventory.frame_skin.button(native_button,video.definition.entries.okbutton,overlay,video.models,false); ui.inventory.frame_skin.button_caption(native_button,ui.text.raw({"strRef":5197}))
		var pressed: Array=[0]; native_button.pressed.connect(func():pressed[0]+=1)
		var physical_point: Vector2=root.get_stretch_transform()*native_button.get_global_rect().get_center()
		for down in [true,false]:
			var event:=InputEventMouseButton.new(); event.position=physical_point; event.global_position=physical_point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; root.push_input(event,false); await process_frame
		check(pressed[0]==1,"Physical-window coordinates reach an original native button through the applied canvas scale")
		overlay.free()
		menu.open(true); await click(menu.native_frame.buttons.videooptionsbutton.get_global_rect().get_center()); await click(video.buttons.intupbutton.get_global_rect().get_center()); await click(video.buttons.applybutton.get_global_rect().get_center()); committed_scale=service.applied_scale
		menu.dismiss(); saved.load(preferences)
		check(not video.visible and not menu.panel.visible and is_equal_approx(float(saved.get_value("interface","ui_scale",0)),committed_scale),"Session/application dismissal commits an applied video transaction without restoring a retired parent")
	menu.detach_native(); var drained: bool=video.closed and video.assets.running.is_empty() and video.assets.pending.is_empty(); menu.free(); world.free(); ui.close(); ui.free(); display.hide(); await process_frame; await process_frame
	check(drained and not is_instance_valid(video),"Video retirement drains its original-resource workers before releasing the shared owner")
	# Actual Window canvas scaling: physical render target and a static3D image
	# must stay intact while a native2D marker changes size and logical extent.
	service.apply_scale(1.0)
	var stage:=Node3D.new(); root.add_child(stage); var camera:=Camera3D.new(); stage.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=3; camera.position=Vector3(0,0,5); camera.look_at(Vector3.ZERO); camera.current=true
	var mesh:=MeshInstance3D.new(); stage.add_child(mesh); mesh.mesh=BoxMesh.new(); var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color.CYAN; mesh.material_override=material
	var marker:=ColorRect.new(); root.add_child(marker); marker.position=Vector2(20,20); marker.size=Vector2(30,20); marker.color=Color.RED
	for at in 3: await process_frame
	await RenderingServer.frame_post_draw; var first:=root.get_texture().get_image(); var region:=Rect2i(550,200,700,700); var baseline:=first.get_region(region).get_data(); var physical:=root.size; var render_scale:=root.scaling_3d_scale
	check(service.apply_choice(1.5),"Real window accepts an original-policy-valid scale")
	for at in 3: await process_frame
	await RenderingServer.frame_post_draw; var second:=root.get_texture().get_image()
	check(root.size==physical and second.get_size()==first.get_size() and root.scaling_3d_scale==render_scale and root.content_scale_mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,"UI scale preserves physical target size and3D resolution scaling")
	check(second.get_region(region).get_data()==baseline,"Static world pixels remain identical when only UI scale changes")
	var projected:=camera.unproject_position(Vector3.ZERO); var mapped: Vector2=root.get_stretch_transform()*projected
	check(mapped.distance_to(Vector2(root.size)*0.5)<1.0 and camera.project_ray_normal(projected).dot(Vector3(0,0,-1))>0.99999,"World projection, nameplate placement and picking coordinates retain the same canvas-to-world contract")
	var controller:=preload("res://systems/camera_controller.gd").new(); root.add_child(controller); controller.configure(camera,Vector3.ZERO); controller.keyboard_pan=false
	controller.orbit(Vector2(12,6)); var expected_yaw: float=controller.yaw; var expected_pitch: float=controller.pitch; controller.reset(); controller.dragging=true
	var motion_event:=InputEventMouseMotion.new(); motion_event.relative=Vector2(8,4); motion_event.screen_relative=Vector2(12,6); controller._input(motion_event)
	check(is_equal_approx(controller.yaw,expected_yaw) and is_equal_approx(controller.pitch,expected_pitch),"Applied UI scale preserves the same physical camera orbit without capturing the real pointer")
	var follow:=preload("res://systems/game_camera_state.gd").new(); follow.reset(1,1.7,[0,0,0]); controller.follow_state=follow; controller._input(motion_event)
	var expected: Dictionary=follow.pointer(12,6,float(physical.x))
	check(is_equal_approx(float(follow.state.turnDelta),float(expected.yaw)),"Native Follow pointer normalization keeps the physical window width under UI scaling")
	controller.dragging=false; controller.free()
	check(first.get_pixel(25,25).r>0.9 and second.get_pixel(25,25).r<0.2 and second.get_pixel(60,40).r>0.9 and root.get_visible_rect().size.x<physical.x,"Canvas scaling changes actual2D marker pixels and logical layout extent")
	second.save_png(output.trim_suffix(".json")+"-canvas.png"); marker.free(); stage.free()
	service.close(); service.free(); var restored:=Settings.new(); root.add_child(restored); restored.configure(root,preferences)
	check(await wait_until(func():return restored.query_ready),"Reopened native settings complete their query")
	check(is_equal_approx(restored.applied_scale,committed_scale),"Committed scale persists across a fresh settings owner")
	var state: Dictionary=restored.snapshot(); restored.close(); restored.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"window_settings":state,"helperSha256":FileAccess.get_sha256("res://.cache/native-window/nwn-window-modes.exe"),"entryOwnerSha256":FileAccess.get_sha256("res://native_session_world.gd"),"publicConnections":0,"fullVideoParity":false,"scope":"Actual isolated native video input, read-only native monitor query, windowed scale Apply/Cancel/OK persistence, scoped return and physical-target/static3D-pixel preservation. Native display-mode changes/fullscreen, pregame integration and direct original-window comparison remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
