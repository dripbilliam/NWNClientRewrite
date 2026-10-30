extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Radial=preload("res://systems/server_radial.gd")
const Layout=preload("res://systems/native_data/radial_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
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
	var sent: Array=[]; radial.request.connect(func(message):sent.append(message))
	var rows: Array=[]
	var names:=["Examine","Cast spell","Attack","Special attacks","Inventory","Issue command","Special abilities","Talk"]
	var resources:=["ir_examine","ir_cast","ir_attack","ir_xattack","ir_inventory","ir_command","ir_xability","ir_dialog"]
	for slot in 8: rows.append({"slot":slot,"label":names[slot],"uses":3 if slot==1 else null,"disabled":slot==2,"submenu":slot in [1,3,5,6],"canDrag":slot==7})
	radial.open_at(Vector2(700,420),7,Vector3.ZERO,false)
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":1,"title":"Original native radial artwork","depth":0,"entries":rows})
	for slot in 8: art.bind(radial.icons[slot],resources[slot])
	check(await wait_for(func():return radial.layout_ready and radial.center_frame.texture!=null and radial.selection.texture!=null and radial.icons.values().all(func(image):return image.texture!=null)),"Original model hooks, circle frames, selection ring and eight icons prepare natively")
	check(radial.skin_errors.is_empty() and art.failed.is_empty(),"Native radial artwork has no missing/failed resources")
	var expected:=[Vector2(0,-100),Vector2(71,-71),Vector2(100,0),Vector2(71,71),Vector2(0,100),Vector2(-71,71),Vector2(-100,0),Vector2(-71,-71)]
	for slot in 8:
		check((radial.buttons[slot].global_position+radial.buttons[slot].size*0.5-radial.origin).distance_to(expected[slot])<0.001,"Original GUI_RA_MENU attachment position "+str(slot))
		check(radial.buttons[slot].size==Vector2(56,56) and not radial.captions[slot].visible,"Native circular icon footprint replaces rectangular caption buttons "+str(slot))
	check(radial.stage is Control and not radial.stage is PanelContainer,"Wheel leaves the scene visible between separate icon discs")
	var source_shas: Dictionary={}
	for name in ["gui_ra_menu","gui_ra_circle56","gui_ra_clearring"]: source_shas[name]=Cache.digest(catalog.get_resource(name,2002))
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
	if args.has("screenshot"):
		await RenderingServer.frame_post_draw; var image:=root.get_texture().get_image(); check(image!=null and image.save_png(args.screenshot)==OK,"Native wheel screenshot saved")
	radial.back(); check(sent.size()==2 and sent[-1].kind=="radial-back" and int(sent[-1].menuId)==2,"Center/back returns through the current native menu identity")
	radial.reset(); radial.open_at(Vector2.ZERO,7,Vector3.ZERO,false)
	check(radial.origin==Vector2(155,155),"Original155px placement margin at the top-left edge")
	radial.reset(); radial.open_at(Vector2(10000,10000),7,Vector3.ZERO,false)
	check(radial.origin==Vector2(root.size)-Vector2(156,156),"Original far-edge placement margin keeps the wheel inside the viewport")
	check(not radial.blocks_pointer(radial.origin+Vector2(156,0)),"A world click outside the wheel remains available")
	var skin:=radial.skin_snapshot(); art.close(); radial.free(); art.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"source_shas":source_shas,"skin":skin,"scope":"Original installed GUI model/raster preparation, actual Godot circular controls and current menu requests; synthetic viewport input. Visual review and authoritative server actions are separate receipts."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
