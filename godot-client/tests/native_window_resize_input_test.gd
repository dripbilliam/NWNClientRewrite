extends SceneTree
const Settings=preload("res://systems/native_window_settings.gd")
const Menu=preload("res://systems/native_render_settings.gd")
var checks:=0
var failures: Array=[]
var clicks:=0
var observations: Array=[]
var resize_dispatch:=false
var reentrant_updates:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func settle() -> void:
	for index in 12: await process_frame
func physical_click(point: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.pressed=down; event.button_index=MOUSE_BUTTON_LEFT; event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0; root.push_input(event,false); await process_frame
func observe(label: String,owner,button: Button) -> void:
	await settle()
	var logical:=root.get_visible_rect().size; var transform:=root.get_stretch_transform(); var extent: Vector2=Vector2(root.size)/owner.applied_scale
	var point: Vector2=transform*button.get_global_rect().get_center(); var before:=clicks; await physical_click(point)
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var sample: Vector2i=Vector2i(transform*(button.get_global_rect().position+Vector2(8,8)))
	check(image.get_size()==root.size and image.get_pixelv(sample).r>0.9 and image.get_pixelv(sample).g<0.1,"Button pixels occupy their expected physical target position after resize: "+label)
	var native_size:=DisplayServer.window_get_size(root.get_window_id())
	observations.append({"phase":label,"mode":root.mode,"window":[root.size.x,root.size.y],"native_window":[native_size.x,native_size.y],"base":[root.content_scale_size.x,root.content_scale_size.y],"logical":[logical.x,logical.y],"scale":owner.applied_scale,"stretch":[transform.x.x,transform.x.y,transform.y.x,transform.y.y,transform.origin.x,transform.origin.y],"clicks":clicks-before,"applies":owner.applies,"screen":root.current_screen})
	check(root.size==native_size,"Godot Window size follows the operating-system client rectangle: "+label)
	check(logical.distance_to(extent)<2,"Logical UI follows physical client size and selected scale: "+label)
	check(transform.x.distance_to(Vector2(owner.applied_scale,0))<0.01 and transform.y.distance_to(Vector2(0,owner.applied_scale))<0.01 and transform.origin.length()<1,"Canvas uses uniform explicit scaling without an old-aspect letterbox: "+label)
	check(clicks==before+1,"Rendered button center accepts physical-window input: "+label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	# Exercise a monitor migration as well as same-monitor resizing. Production
	# starts on a secondary screen; the reported failure followed maximizing an
	# ultrawide window after startup.
	for screen in DisplayServer.get_screen_count():
		if screen!=DisplayServer.get_primary_screen() and DisplayServer.screen_get_size(screen).x>3000:
			root.current_screen=screen; break
	root.size=Vector2i(1280,800); var original_screen:=root.current_screen
	root.size_changed.connect(func():resize_dispatch=true)
	var settings:=Settings.new(); root.add_child(settings); settings.configure(root,output+".preferences.cfg")
	settings.changed.connect(func():
		if resize_dispatch: reentrant_updates+=1)
	root.size_changed.connect(func():resize_dispatch=false)
	var menu:=Menu.new(); root.add_child(menu); menu.setup(output+".menu.cfg",output+".layout.cfg"); menu.show()
	var button:=Button.new(); root.add_child(button); button.position=Vector2(850,100); button.size=Vector2(150,60); button.text="Resize hit target"; button.focus_mode=Control.FOCUS_NONE; button.pressed.connect(func():clicks+=1)
	var style:=StyleBoxFlat.new(); style.bg_color=Color.RED
	for state in ["normal","hover","pressed"]: button.add_theme_stylebox_override(state,style)
	await observe("initial-window",settings,button)
	root.size=Vector2i(1500,820); await observe("wide-window",settings,button)
	root.mode=Window.MODE_MAXIMIZED; await observe("maximized",settings,button)
	root.mode=Window.MODE_FULLSCREEN; await observe("fullscreen",settings,button)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,800); await observe("restored-window",settings,button)
	DisplayServer.window_set_size(Vector2i(1520,850),root.get_window_id()); await observe("os-size-notification",settings,button)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED,root.get_window_id()); await observe("os-maximize-notification",settings,button)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN,root.get_window_id()); await observe("os-fullscreen-notification",settings,button)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED,root.get_window_id()); root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,800); await observe("os-restored-window",settings,button)
	settings.unconstrained=true; settings.apply_scale(1.5); button.position=Vector2(500,100); await observe("scaled-window",settings,button)
	root.mode=Window.MODE_MAXIMIZED; await observe("scaled-maximized",settings,button)
	root.mode=Window.MODE_FULLSCREEN; await observe("scaled-fullscreen",settings,button)
	root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,800); await observe("scaled-restored",settings,button)
	settings.apply_scale(1.0)
	# Multiple native notifications may be delivered before one rendered frame.
	for extent in [Vector2i(1400,850),Vector2i(2200,1000),Vector2i(3440,1369)]:
		DisplayServer.window_set_size(extent,root.get_window_id())
	await observe("ultrawide-burst-resize",settings,button)
	check(root.current_screen==original_screen and root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable,"Resize test stays nonactivating on the secondary monitor")
	check(reentrant_updates==0,"Canvas updates never reenter Godot's unfinished viewport resize/screen attachment")
	await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")
	var state:=settings.snapshot(); settings.close(); settings.free(); button.free(); menu.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"window_settings":state,"physicalOSInputInjected":false,"publicConnections":0,"scope":"Actual native Window resize/maximize/fullscreen and restore, scale and physical-event-to-button contract. No physical mouse movement, window activation or public server."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
