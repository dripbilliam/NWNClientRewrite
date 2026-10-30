extends "res://tests/native_quickbar_frame_test.gd"
const Layers=preload("res://systems/native_window_layers.gd")
const Draggable=preload("res://systems/draggable_panel.gd")
func pixels() -> Image:
	for at in 3: await process_frame
	await RenderingServer.frame_post_draw
	return surface.get_texture().get_image()
func mismatch(a: Image,b: Image,rect: Rect2i) -> int:
	var count:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if a.get_pixel(x,y)!=b.get_pixel(x,y): count+=1
	return count
func box(parent: Control,at: Vector2,extent: Vector2,color: Color) -> PanelContainer:
	var result:=PanelContainer.new(); parent.add_child(result); result.position=at; result.size=extent
	var style:=StyleBoxFlat.new(); style.bg_color=color; result.add_theme_stylebox_override("panel",style); return result
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(700,600); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var world:=ColorRect.new(); surface.add_child(world); world.size=surface.size; world.color=Color(0.15,0.35,0.65); world.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var host:=Control.new(); surface.add_child(host); host.size=surface.size; host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var lower:=box(host,Vector2(30,40),Vector2(330,340),Color(0.8,0.15,0.12))
	var label:=Label.new(); lower.add_child(label); label.text="Lower window text\nShould never bleed into front"; label.add_theme_font_size_override("font_size",23)
	var upper:=box(host,Vector2(150,100),Vector2(320,330),Color(0.08,0.06,0.03,0.6))
	var overlap:=Rect2i(151,101,208,278); var before:=await pixels(); lower.hide(); var reference:=await pixels(); lower.show()
	check(mismatch(before,reference,overlap)>10000,"The fixture detects lower UI bleeding through a translucent window before clipping")
	var layers:=Layers.new(); surface.add_child(layers); layers.configure(host)
	var covered:=await pixels(); check(mismatch(covered,reference,overlap)==0,"Front source transparency reveals only the world, with no lower-window pixels")
	check(mismatch(before,covered,Rect2i(31,41,100,300))==0,"Uncovered lower-window artwork and text remain unchanged")
	check(covered.get_pixel(400,200)!=Color.BLACK and covered.get_pixel(400,200)!=world.color,"World color remains visible through the translucent source panel")
	var late:=Label.new(); lower.add_child(late); late.text="Late published text"; late.position=Vector2(150,220); late.size=Vector2(160,30); var changed:=await pixels()
	check(mismatch(changed,reference,overlap)==0,"Dynamically published lower text inherits the same front-window coverage")
	upper.hide(); var hidden:=await pixels(); check(mismatch(hidden,reference,overlap)>10000,"Hiding the front window immediately reveals the lower UI")
	upper.show(); lower.move_to_front(); var reordered:=await pixels(); upper.hide(); var lower_reference:=await pixels(); upper.show()
	check(mismatch(reordered,lower_reference,Rect2i(151,101,208,278))==0,"Bringing the lower window forward updates coverage in actual canvas order")
	upper.move_to_front(); upper.position+=Vector2(70,20); var moved:=await pixels(); lower.hide(); var moved_reference:=await pixels(); lower.show()
	check(mismatch(moved,moved_reference,Rect2i(221,121,138,258))==0,"Moved window coverage follows its new screen rectangle")
	host.scale=Vector2.ONE*1.25; var scaled:=await pixels(); lower.hide(); var scaled_reference:=await pixels(); lower.show()
	check(mismatch(scaled,scaled_reference,Rect2i(277,152,169,320))==0,"Scaled desktop coverage uses canvas coordinates without stretching source windows")
	host.scale=Vector2.ONE; var stage:=Control.new(); upper.add_child(stage); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; var footer:=Button.new(); stage.add_child(footer); footer.position=Vector2(0,335); footer.size=Vector2(90,30); footer.text="Utility"; upper.set_meta("native_window_extras",[weakref(footer)])
	var footer_lower:=box(host,Vector2(200,440),Vector2(200,90),Color(0.7,0.3,0.1)); upper.move_to_front(); var with_footer:=await pixels(); footer_lower.hide(); var footer_reference:=await pixels(); footer_lower.show()
	check(mismatch(with_footer,footer_reference,Rect2i(221,456,88,28))==0,"Explicit source utility coverage clips lower UI outside the main panel")
	check(mismatch(with_footer,footer_reference,Rect2i(320,460,60,25))>100,"Empty area beside a utility retains visible lower UI")
	await pixels(); var updates: int=layers.updates; await process_frame; await process_frame; check(layers.updates==updates,"An unchanged desktop does not republish clipping uniforms every frame")
	var material: Material=lower.material; host.remove_child(lower); check(lower.material==null and not label.use_parent_material,"Removing a window restores its material and descendant inheritance")
	host.add_child(lower); var restored:=await pixels(); check(lower.material!=null and lower.material!=material and label.use_parent_material,"A reattached window gets fresh coverage ownership without duplicate watchers")
	var diagnostic: Dictionary=layers.snapshot(); check(diagnostic.overflow==0 and diagnostic.custom_root_materials==0,"This supported desktop has no overflow or custom-material exclusions")
	await shot(output,"-layered"); layers.close(); check(lower.material==null and upper.material==null and not late.use_parent_material,"Retiring the layer manager restores original per-control state")
	layers.free(); host.free(); world.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"publicConnections":0,"fullWindowParity":false,"scope":"Deterministic isolated native UI composition; no original-client visual claim or separate-canvas NUI coverage."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
