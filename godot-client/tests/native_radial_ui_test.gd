extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Radial=preload("res://systems/server_radial.gd")
const Layout=preload("res://systems/native_data/radial_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func wait_for(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func click(point: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; root.push_input(event,true); await process_frame
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1424,921)
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original native resource catalog mounts without a bridge")
	var art:=Art.new(); root.add_child(art); art.configure(catalog,ProjectSettings.globalize_path("res://.cache/native-radial-ui"))
	var radial:=Radial.new(); root.add_child(radial); radial.configure_art(art)
	var fonts:=Fonts.new(); root.add_child(fonts); fonts.configure(catalog,ProjectSettings.globalize_path("res://.cache/native-radial-ui")); radial.configure_text(fonts)
	var sent: Array=[]; radial.request.connect(func(message):sent.append(message))
	var rows: Array=[]
	var names:=["Examine","Cast spell","Attack","Special attacks","Inventory","Issue command","Special abilities","Talk"]
	var resources:=["ir_examine","ir_cast","ir_attack","ir_xattack","ir_inventory","ir_command","ir_xability","ir_dialog"]
	for slot in 8: rows.append({"slot":slot,"label":names[slot],"uses":3 if slot==1 else null,"disabled":slot==2,"submenu":slot in [1,3,5,6],"canDrag":slot==7})
	radial.open_at(Vector2(700,420),7,Vector3.ZERO,false)
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":1,"title":"Original native radial artwork","depth":0,"entries":rows})
	for slot in 8: art.bind(radial.icons[slot],resources[slot])
	check(await wait_for(func():return radial.layout_ready and radial.center_frame.texture!=null and radial.selection.texture!=null and radial.icons.values().all(func(image):return image.texture!=null) and radial.arrows.values().all(func(image):return image.texture!=null)),"Original model hooks, circle frames, arrows, selection ring and eight icons prepare natively")
	check(radial.skin_errors.is_empty() and art.failed.is_empty(),"Native radial artwork has no missing/failed resources")
	radial.highlight(0)
	var bubble: TextureRect=radial.text_backgrounds[radial.hint.get_instance_id()]
	check(await wait_for(func():return bubble.texture!=null and bubble.size.x>radial.hint.size.x),"Original bubble raster keeps its border outside the text rectangle")
	check(bubble.position.is_equal_approx(Vector2(-15,-5)) and bubble.size.is_equal_approx(radial.hint.size+Vector2(30,10)),"Original bubble background retains native pixel size and root offset without stretching")
	check(await wait_for(func():return radial.hint.get_meta("native_font_applied","")=="ttf fnt_default 14" and radial.captions.values().all(func(label):return label.get_meta("native_font_applied","")=="ttf fnt_default 14")),"Radial action labels receive the current binary's original default dialog font")
	var expected:=[Vector2(0,-100),Vector2(71,-71),Vector2(100,0),Vector2(71,71),Vector2(0,100),Vector2(-71,71),Vector2(-100,0),Vector2(-71,-71)]
	for slot in 8:
		check((radial.buttons[slot].global_position+radial.buttons[slot].size*0.5-radial.origin).distance_to(expected[slot])<0.001,"Original GUI_RA_MENU attachment position "+str(slot))
		check(radial.buttons[slot].size==Vector2(56,56) and not radial.captions[slot].visible,"Native circular icon footprint replaces rectangular caption buttons "+str(slot))
	check(radial.stage is Control and not radial.stage is PanelContainer,"Wheel leaves the scene visible between separate icon discs")
	check(radial.arrows.keys().all(func(slot):return radial.arrows[slot].visible==(slot in [1,3,5,6])),"Only physical submenu slots show native GUI_RA_MORE arrows")
	for slot in 8:
		check(is_equal_approx(radial.arrows[slot].rotation,slot*PI/4.0),"Submenu arrow follows its original physical slot rotation "+str(slot))
	var source_shas: Dictionary={}
	for name in ["gui_ra_menu","gui_ra_circle56","gui_ra_clearring","gui_ra_more","gui_icon_1x1mrng"]: source_shas[name]=Cache.digest(catalog.get_resource(name,2002))
	if radial.frames[0].texture!=null:
		var image: Image=radial.frames[0].texture.get_image()
		check(image.get_width() in [56,57] and image.get_height() in [56,57],"Original frame model retains its56px size")
		check(image.get_pixel(0,0).a<0.05 and image.get_pixel(image.get_width()/2,image.get_height()/2).a>0.1,"Original circular frame has transparent corners and an opaque center")
	var invalid:={"nodes":[{"name":"center","position":[0,0,0],"orientation":[0,0,0,1],"scale":1,"parent":4}]}
	check(not Layout.parse(invalid).error.is_empty(),"Invalid original hook hierarchy is rejected")
	var layout_size:=radial.stage.size
	for slot in 8: radial.icons[slot].texture=ImageTexture.create_from_image(Image.create(32,512,false,Image.FORMAT_RGBA8))
	for frame in 8: await process_frame
	check(radial.stage.size==layout_size and radial.buttons.values().all(func(button):return button.size==Vector2(56,56)),"Late/tall textures cannot expand the native wheel or click areas")
	for slot in 8: art.bind(radial.icons[slot],resources[slot])
	await click(radial.buttons[2].get_global_rect().get_center())
	check(sent.is_empty() and not radial.pending,"Disabled native icon does not send an action")
	await click(radial.buttons[1].get_global_rect().get_center())
	check(sent.size()==1 and sent[0].kind=="radial-select" and int(sent[0].slot)==1,"Actual Godot circular button click emits exactly one current submenu request")
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":2,"title":"Spell submenu","depth":1,"entries":rows}); radial.highlight(7)
	for slot in 8: art.bind(radial.icons[slot],resources[slot])
	check(radial.selection.visible and radial.selection.position==radial.buttons[7].position and radial.hint.visible and radial.hint.text.contains("Talk"),"Original selection ring follows the hovered icon and shows its action")
	check(radial.can_shortcut(radial.buttons[7].payload) and not radial.can_shortcut({"requestId":radial.request_id,"menuId":1,"slot":7}),"Original-looking wheel preserves current leaf drag identity across submenu changes")
	var preview_calls: Array=[]
	radial.preview_provider=func(slot,request,menu):
		preview_calls.append([slot,request,menu]); return [{"slot":0,"icon":"ir_cast","uses":2},{"slot":3,"icon":"ir_inventory","disabled":true},{"slot":7,"icon":"IR_MORE_SP_AB","submenu":true}]
	radial.highlight(1)
	check(await wait_for(func():return radial.preview_icons[0].texture!=null and radial.preview_icons[3].texture!=null and radial.preview_icons[7].texture!=null),"Hover prepares original ringed micro preview models with child icon replacements")
	check(radial.preview_layer.visible and radial.preview_icons[0].visible and not radial.preview_icons[1].visible and radial.preview_icons[3].modulate.a<0.5,"Preview preserves physical holes and exhausted-child opacity")
	check(radial.preview_counts[0].text=="2" and preview_calls.size()==1 and int(preview_calls[0][2])==2,"Preview uses the current menu identity and received child count")
	check(radial.preview_icons[0].position+Vector2(11,11)==radial.buttons[1].position+Vector2(28,-2),"Native micro ring uses a30px integer component radius")
	if args.has("screenshot"):
		await RenderingServer.frame_post_draw; var image:=root.get_texture().get_image(); check(image!=null and image.save_png(args.screenshot)==OK,"Native wheel screenshot saved")
	radial.submenu_previews=false; radial.show_preview(rows[1]); check(not radial.preview_layer.visible,"Disabling submenu previews clears the old layer without dispatching an action")
	radial.submenu_previews=true
	radial.submenu_preview_mode=2; radial.text_preview_mode=2
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":2,"title":"All native previews","depth":1,"entries":rows})
	for slot in 8: art.bind(radial.icons[slot],resources[slot])
	check(await wait_for(func():return radial.icons.values().all(func(icon):return icon.texture!=null)),"All-mode fixture binds the actual original parent icons after the new page")
	check(radial.preview_groups.values().filter(func(group):return group.layer.visible).size()==4 and preview_calls.size()==5,"Original All mode prepares each physical branch once on page activation")
	check(await wait_for(func():return radial.preview_groups.values().filter(func(group):return group.layer.visible).all(func(group):return group.icons[0].texture!=null and group.icons[3].texture!=null and group.icons[7].texture!=null)),"All native branch previews resolve their own ringed artwork")
	check(radial.captions.values().all(func(label):return label.visible) and not radial.hint.visible,"Original All text mode attaches every current action without a second hover label")
	radial.highlight(1); check(not radial.selection.visible and radial.preview_groups[3].layer.visible,"A hovered submenu retains the other All previews and suppresses its leaf selection ring")
	await process_frame
	check(radial.captions.values().all(func(label):return label.size.is_equal_approx(label.get_meta("native_bubble_dimensions",Vector2.ZERO))),"Every shaped caption rectangle matches the original selected bubble dimensions")
	check(await wait_for(func():return radial.captions.values().all(func(label):return radial.text_backgrounds[label.get_instance_id()].texture!=null)),"All action captions resolve their original bubble backgrounds")
	if args.has("screenshot"):
		await RenderingServer.frame_post_draw; check(root.get_texture().get_image().save_png(str(args.screenshot).trim_suffix(".png")+"-all.png")==OK,"All preview/text screenshot saved")
	radial.hide_icons=true
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":2,"title":"Native text-only wheel","depth":1,"entries":rows})
	check(not radial.preview_layer.visible and radial.icons.values().all(func(icon):return not icon.visible) and radial.frames.values().all(func(frame):return not frame.visible) and radial.arrows.values().all(func(arrow):return not arrow.visible),"Original Hide Icons suppresses ordinary, arrow and micro art")
	check(radial.buttons.values().all(func(button):return button.visible) and radial.captions.values().all(func(label):return label.visible),"Hidden art retains native physical selection and action text")
	if args.has("screenshot"):
		await RenderingServer.frame_post_draw; check(root.get_texture().get_image().save_png(str(args.screenshot).trim_suffix(".png")+"-text.png")==OK,"Text-only screenshot saved")
	radial.text_preview_mode=0; radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":2,"title":"No action text","depth":1,"entries":rows}); radial.highlight(7)
	check(not radial.hint.visible and radial.captions.values().all(func(label):return not label.visible),"Original Off text mode does not reappear on hover")
	radial.hide_icons=false; radial.text_preview_mode=1; radial.text_in_center=true; radial.center_align_text=true; radial.submenu_preview_mode=0
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":2,"title":"Centered action text","depth":1,"entries":rows}); radial.highlight(1)
	check(radial.hint.visible and radial.hint.position+radial.hint.size*0.5==Vector2(155,155)+radial.hooks.text and radial.selection.visible and not radial.preview_layer.visible,"Original center text hook and preview-Off leaf ring remain independent")
	radial.text_in_center=false; radial.center_align_text=false; radial.submenu_preview_mode=1
	radial.back(); check(sent.size()==2 and sent[-1].kind=="radial-back" and int(sent[-1].menuId)==2,"Center/back returns through the current native menu identity")
	radial.reset(); radial.open_at(Vector2.ZERO,7,Vector3.ZERO,false)
	check(rows.size()==8,"Closing a wheel cannot clear its caller's retained menu entries")
	check(radial.origin==Vector2(155,155),"Original155px placement margin at the top-left edge")
	radial.reset(); radial.open_at(Vector2(10000,10000),7,Vector3.ZERO,false)
	check(radial.origin==Vector2(root.size)-Vector2(156,156),"Original far-edge placement margin keeps the wheel inside the viewport")
	check(not radial.blocks_pointer(radial.origin+Vector2(156,0)),"A world click outside the wheel remains available")
	radial.use_screen_center=true; radial.reset(); radial.open_at(Vector2.ZERO,7,Vector3.ZERO,false)
	check(radial.origin==Vector2(root.size)*0.5,"Screen-center preference places the wheel without warping or capturing the physical mouse")
	radial.use_screen_center=false
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":3,"title":"Held submenu","depth":0,"entries":rows})
	check(not radial.preview_layer.visible,"Changing menu identity clears the previous preview")
	var before:=sent.size(); var right:=InputEventMouseButton.new(); right.button_index=MOUSE_BUTTON_RIGHT; right.pressed=true; right.position=radial.origin; right.global_position=right.position; root.push_input(right,true); await process_frame
	var motion:=InputEventMouseMotion.new(); motion.position=radial.origin+Vector2(135,-135); motion.global_position=motion.position; motion.button_mask=MOUSE_BUTTON_MASK_RIGHT; root.push_input(motion,true); await process_frame
	var hover_trace:={"active":radial.active,"pending":radial.pending,"selected":radial.selected,"hover_slot":radial.hover_slot,"hover_menu":radial.hover_menu,"menu_id":radial.menu_id,"click_mode":radial.click_mode,"processing":radial.is_processing(),"sector":radial.hit(motion.position-radial.origin),"last_motion":radial.last_motion.duplicate(true),"entry_count":radial.entries.size()}
	check(await wait_for(func():return sent.size()>before),"Held right-button movement into the outer submenu sector enters after dwell")
	check(sent.size()==before+1 and sent[-1].kind=="radial-select" and int(sent[-1].slot)==1,"Held navigation emits one current physical submenu selection")
	check(radial.submenu_delay_usec==150000,"Held submenu timeout uses the original initializer")
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":4,"title":"Deeper menu","depth":1,"entries":rows})
	var until:=Time.get_ticks_msec()+350
	while Time.get_ticks_msec()<until: await process_frame
	check(sent.size()==before+1,"An old dwell cannot enter another layer after its menu is replaced")
	radial.text_preview_mode=2; radial.submenu_preview_mode=0; radial.hide_icons=false; radial.text_in_center=false; radial.center_align_text=false
	var corners:=[Vector2.ZERO,Vector2(root.size.x,0),Vector2(root.size),Vector2(0,root.size.y)]
	var edge_layouts: Array=[]
	for n in corners.size():
		radial.reset(); radial.open_at(corners[n],7,Vector3.ZERO,false); radial.click_mode=true; radial.initial_gesture=false
		radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":9+n,"title":"Original edge alignment","depth":0,"entries":rows})
		for slot in 8: art.bind(radial.icons[slot],resources[slot])
		await process_frame
		check(await wait_for(func():return radial.captions.values().all(func(label):return radial.text_backgrounds[label.get_instance_id()].texture!=null)),"Edge bubble artwork is ready "+str(n))
		var bounds:=Rect2(Vector2.ZERO,Vector2(root.size)).grow(1.1)
		check(radial.captions.values().all(func(label):return bounds.encloses(label.get_global_rect())),"Original edge placement keeps normal action glyph rectangles in the viewport "+str(n))
		var labels: Array=[]
		for slot in 8:
			var label: Label=radial.captions[slot]; labels.append({"slot":slot,"rect":[label.global_position.x,label.global_position.y,label.size.x,label.size.y]})
		edge_layouts.append({"origin":[radial.origin.x,radial.origin.y],"labels":labels})
		if args.has("screenshot"):
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(str(args.screenshot).trim_suffix(".png")+"-edge-"+str(n)+".png")==OK,"Original edge screenshot saved "+str(n))
	radial.reset()
	var skin:=radial.skin_snapshot()
	skin.text_bubble_bounds={}
	skin.edge_layouts=edge_layouts
	for key in art.bounds:
		if str(key).contains("pnl_bubble"): skin.text_bubble_bounds[key]=art.bounds[key]
	art.close(); fonts.close(); radial.free(); art.free(); fonts.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"source_shas":source_shas,"skin":skin,"hover_trace":hover_trace,"scope":"Original installed GUI model/raster preparation, actual Godot circular controls and current menu requests; synthetic viewport input. Visual review and authoritative server actions are separate receipts."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
