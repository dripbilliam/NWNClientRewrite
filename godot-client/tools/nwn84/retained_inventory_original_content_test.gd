extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Owner=preload("res://systems/native_inventory.gd")
const Slot=preload("res://systems/inventory_slot.gd")
const Plan=preload("res://systems/native_data/item_icon.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func hook_error(owner,entry: int) -> float:
	var slot=owner.ui.buttons.get(entry)
	if slot==null or slot.native_icon_center==null or not owner.ui.scene_host.slots.has(str(entry)): return INF
	var host=owner.ui.scene_host
	var model: Node3D=host.slots[str(entry)].model
	var expected: Vector2=slot.get_global_transform()*slot.native_icon_center
	var drawn: Vector2=host.get_global_transform()*Vector2(model.position.x*100.0,-model.position.z*100.0)
	return expected.distance_to(drawn)
func projected_bounds_error(owner,entry: int) -> float:
	var slot=owner.ui.buttons.get(entry)
	if slot==null or slot.native_icon_center==null or not owner.ui.scene_host.slots.has(str(entry)): return INF
	var host=owner.ui.scene_host
	var model=host.slots[str(entry)].model
	var bounds:=AABB(); var found:=false
	for mesh in model.meshes:
		var box: AABB=mesh.global_transform*mesh.get_aabb()
		bounds=bounds.merge(box) if found else box; found=true
	if not found: return INF
	var rendered:=Vector2(bounds.get_center().x*100.0,-bounds.get_center().z*100.0)
	var hook: Vector2=host.get_global_transform().affine_inverse()*(slot.get_global_transform()*slot.native_icon_center)
	return rendered.distance_to(hook)
func lower_pixel_bounds(image: Image) -> Dictionary:
	var magenta:=Rect2i(); var green:=Rect2i(); var magenta_found:=false; var green_found:=false
	for y in range(650,mini(image.get_height(),1200)):
		for x in range(0,mini(image.get_width(),900)):
			var color: Color=image.get_pixel(x,y)
			if color.r>0.9 and color.g<0.1 and color.b>0.9:
				magenta=magenta.expand(Vector2i(x,y)) if magenta_found else Rect2i(x,y,1,1); magenta_found=true
			elif color.g>0.03 and color.g<0.5 and color.g>color.r*1.2 and color.g>color.b*1.1:
				green=green.expand(Vector2i(x,y)) if green_found else Rect2i(x,y,1,1); green_found=true
	var green_near:=Rect2i();var green_near_found:=false
	if magenta_found:
		var marker_center: Vector2i=magenta.get_center()
		for y in range(maxi(0,marker_center.y-100),mini(image.get_height(),marker_center.y+100)):
			for x in range(maxi(0,marker_center.x-100),mini(image.get_width(),marker_center.x+100)):
				var color: Color=image.get_pixel(x,y)
				if color.g>0.03 and color.g<0.5 and color.g>color.r*1.2 and color.g>color.b*1.1:
					green_near=green_near.expand(Vector2i(x,y)) if green_near_found else Rect2i(x,y,1,1);green_near_found=true
	return {"magenta":str(magenta),"green":str(green),"magenta_found":magenta_found,"green_found":green_found,"center_gap":magenta.get_center().distance_to(green.get_center()) if magenta_found and green_found else INF,"near_green":str(green_near),"near_green_found":green_near_found,"near_gap":magenta.get_center().distance_to(green_near.get_center()) if green_near_found else INF}
func host_green_bounds(image: Image) -> Dictionary:
	var bounds:=Rect2i(); var found:=false
	for y in range(int(image.get_height()/2),image.get_height()):
		for x in image.get_width():
			var color: Color=image.get_pixel(x,y)
			if color.g>0.03 and color.g<0.5 and color.g>color.r*1.2 and color.g>color.b*1.1:
				bounds=bounds.expand(Vector2i(x,y)) if found else Rect2i(x,y,1,1); found=true
	return {"bounds":str(bounds),"found":found,"center":str(bounds.get_center())}
func run() -> void:
	var options: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	if not options.has_all(["install","report"]) or FileAccess.file_exists(options.report): quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var primary:=DisplayServer.get_primary_screen()
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:
			root.current_screen=screen; root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80); break
	root.size=Vector2i(1100,850)
	var catalog:=Catalog.new()
	check(catalog.mount_install(str(options.install)),"Installed original catalog")
	check(catalog.mount_erf(str(options.install).path_join("data/nwm/Prelude.nwm"),100000000),"Original Prelude icon templates")
	check(OS.get_cmdline_user_args().has("--item-icon-backend=retained") or OS.get_environment("NWN_ITEM_ICON_BACKEND")=="retained","Whole-system retained icon backend selected")
	var tables: Dictionary={}
	for name in ["baseitems","capart","parts_robe","cloakmodel","iprp_spells","encumbrance"]:
		var parser:=Table.new(); tables[name]=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii())
		check(parser.failure.is_empty(),"Original item table "+name)
	var original_item: Dictionary={}
	for index in tables.baseitems.orderedRows.size():
		var candidate:={"baseItem":index,"parts":[1],"name":{"text":"Original item"}}
		var decoder:=Plan.new(); var planned: Dictionary=decoder.plan(candidate,tables)
		if planned.is_empty() or decoder.select(planned,catalog).is_empty(): continue
		original_item=candidate; break
	check(not original_item.is_empty(),"Installed original item with a valid GUI_ICON model")
	if original_item.is_empty(): quit(1); return
	var text:=Text.new(); text.tables=tables
	var surface:=Control.new(); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(surface)
	var owner:=Owner.new(); root.add_child(owner); owner.configure(surface,catalog,"",text)
	check(owner.retained_item_icons and owner.icons.bundles is Dictionary,"NativeInventory uses retained scene service")
	var actor:={"id":1,"objectType":5,"replicated":{"name":{"text":"Original icon test"}},"inventoryStats":{"field70":12,"field28c":149},"playerState":{"combat":{"field898":27,"armorClass":13}},"appearance":{"gender":0}}
	var equipped:={"id":11,"objectType":6,"item":original_item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"I","slot":2}}
	var later:={"id":12,"objectType":6,"item":original_item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"R","x":0,"y":6}}
	var raw:={"inventories":[["I",{"entries":[{"id":11,"slot":2}]}],["R",{"entries":[{"id":12,"x":0,"y":6}]}]],"containers":[]}
	owner.set_world(1,3,1,[actor,equipped,later],raw)
	check(owner.icons.bundles.is_empty() and owner.icons.pending.is_empty(),"Retained backend does not prewarm closed inventory icons")
	owner.ui.open(); owner.refresh()
	var armor_key: String=owner.icons.request(equipped.item,tables,0)
	var deadline:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and not owner.icons.bundles.has(armor_key): await process_frame
	check(owner.icons.bundles.has(armor_key),"Original item model bundle prepared on demand")
	var drag_preview: Control=Slot.scene_drag_preview(owner.icons,armor_key,owner.icons.bundles.get(armor_key,{}))
	if drag_preview!=null: root.add_child(drag_preview); await process_frame
	check(drag_preview!=null and drag_preview.get_child_count()==1 and drag_preview.get_child(0).slots.has("preview"),"Drag preview owns a transient retained 3D model")
	if drag_preview!=null:
		var drag_deadline:=Time.get_ticks_msec()+3000
		while Time.get_ticks_msec()<drag_deadline and not drag_preview.get_child(0).binding_ready("preview"):await process_frame
		check(drag_preview.get_child(0).binding_ready("preview") and drag_preview.get_child(0).viewport.get_texture().get_image().get_used_rect().has_area(),"Drag preview presents original model pixels before use")
	if drag_preview!=null: root.remove_child(drag_preview); drag_preview.free()
	owner.refresh()
	check(not owner.ui.visible and owner.ui.items.has(11) and owner.ui.scene_host.slots.has("11"),"Inventory stays hidden until retained model draw receipt")
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not owner.ui.visible: await process_frame
	var first_state:={"visible":owner.ui.visible,"binding_ready":owner.ui.scene_host.binding_ready("11"),"image_texture":owner.ui.buttons[11].image.texture!=null,"host_revision":owner.ui.scene_host.revision,"presented_revision":owner.ui.scene_host.presented_revision,"failure":owner.ui.scene_icon_failure}
	check(owner.ui.visible and owner.ui.scene_host.binding_ready("11") and owner.ui.buttons[11].image.texture==null,"First visible inventory frame contains original item model without an item bitmap")
	var icon_pixels: Image=owner.ui.scene_host.viewport.get_texture().get_image()
	check(icon_pixels!=null and icon_pixels.get_used_rect().has_area(),"Retained inventory scene draws nontransparent original item pixels")
	owner.page=1; owner.signature=""; owner.refresh()
	var flat_key: String=owner.icons.request(later.item,tables,0)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not owner.ui.scene_host.binding_ready("12"):
		await process_frame; owner.refresh()
	check(owner.ui.scene_host.binding_ready("12") and owner.ui.buttons[12].image.texture==null,"Later-page original item model admitted with no bitmap")
	deadline=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and not owner.frame_skin.layout_ready: await process_frame
	check(owner.frame_skin.layout_ready,"Original inventory frame hooks are ready for placement comparison")
	deadline=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline and (hook_error(owner,12)>=0.5 or not owner.ui.scene_host.binding_ready("12")): await process_frame
	var automatic_hook_error: float=hook_error(owner,12)
	check(automatic_hook_error<0.5,"Later-page 3D model automatically follows original repository slot hook")
	check(not owner.ui.buttons[12].caption.visible,"Rebuilt inventory slot does not overlay placeholder caption on retained model")
	var scale_rows: Array=[]
	root.size=Vector2i(3440,1369)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=root.size
	for scale_value in [1.0,1.3,1.9]:
		root.content_scale_factor=scale_value
		await process_frame; await process_frame
		var error: float=hook_error(owner,12)
		var slot=owner.ui.buttons[12]; var model: Node3D=owner.ui.scene_host.slots["12"].model
		var anchor: Vector2=owner.ui.scene_icon_bindings[12].get("anchor",Vector2.ZERO)
		var projected: Vector2=owner.ui.scene_host.camera.unproject_position(model.global_position)
		var composed:=Vector2(projected.x,float(owner.ui.scene_host.viewport.size.y)-projected.y)
		var camera_error: float=composed.distance_to(anchor)
		scale_rows.append({"scale":scale_value,"window_width":root.size.x,"hook_error":error,"camera_error":camera_error,"projected_bounds_error":projected_bounds_error(owner,12),"host_ready":owner.ui.scene_host.binding_ready("12"),"native_center":str(slot.native_icon_center),"expected_global":str(slot.get_global_transform()*slot.native_icon_center) if slot.native_icon_center!=null else "pending","model_position":str(model.position),"host_global":str(owner.ui.scene_host.get_global_transform()),"host_size":str(owner.ui.scene_host.size),"viewport_size":str(owner.ui.scene_host.viewport.size),"presentation_size":str(owner.ui.scene_host.presentation.size),"presentation_position":str(owner.ui.scene_host.presentation.position),"stored_anchor":str(anchor)})
		check(error<0.5 and camera_error<0.5 and owner.ui.scene_host.binding_ready("12"),"Original repository hook and camera projection at 3440 wide and UI scale "+str(scale_value))
	var cover:=ColorRect.new(); cover.color=Color(1,0,1,1); cover.size=Vector2(20,20); cover.z_index=2
	var cover_local: Vector2=owner.ui.buttons[12].native_icon_center if owner.ui.buttons[12].native_icon_center!=null else owner.ui.buttons[12].size*0.5
	cover.position=cover_local-cover.size*0.5; owner.ui.buttons[12].add_child(cover); await process_frame
	var overlap_capture: String=str(options.report).trim_suffix(".json")+"-overlap.png"
	var overlap_image: Image=root.get_texture().get_image()
	check(overlap_image!=null and overlap_image.save_png(overlap_capture)==OK,"Overlapping control screenshot captured above retained icon panel")
	var pixel_bounds: Dictionary=lower_pixel_bounds(overlap_image) if overlap_image!=null else {}
	check(bool(pixel_bounds.get("near_green_found",false)) and float(pixel_bounds.get("near_gap",INF))<12.0,"Rendered item pixels center on original hook under overlapping control")
	var host_bounds: Dictionary=host_green_bounds(owner.ui.scene_host.viewport.get_texture().get_image())
	var host=owner.ui.scene_host
	var slot_model: Node3D=host.slots["12"].model
	var mesh_bounds: Array=[]
	for mesh in slot_model.meshes:
		mesh_bounds.append({"local_aabb":str(mesh.get_aabb()),"world_aabb":str(mesh.global_transform*mesh.get_aabb()),"global_transform":str(mesh.global_transform)})
	var projection_debug:={"camera_position":str(host.camera.position),"camera_transform":str(host.camera.global_transform),"projected_model_origin":str(host.camera.unproject_position(slot_model.global_position)),"mesh_bounds":mesh_bounds}
	cover.free()
	var prepared_before: int=owner.icons.bundles.size()
	owner.ui.close_inventory()
	check(owner.ui.scene_host.slots.is_empty() and owner.ui.scene_host.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Closing inventory retires all retained icon models and panel viewport work")
	owner.ui.open(); owner.refresh()
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not owner.ui.visible: await process_frame
	check(owner.ui.visible and owner.icons.bundles.size()==prepared_before,"Reopening inventory reuses prepared original model bundles")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"first_state":first_state,"automatic_hook_error":automatic_hook_error,"scale_rows":scale_rows,"overlap_capture":overlap_capture,"pixel_bounds":pixel_bounds,"host_bounds":host_bounds,"projection_debug":projection_debug,"icons":owner.snapshot().icons,"owner":owner.snapshot(),"scope":"Installed original retained 3D item models, UI scales 1.0/1.3/1.9, 3440-wide resize, hook placement, overlap, drag model, close and reopen. No live Arelith or FPS measurement."}
	owner.close(); owner.free(); surface.free(); text.close(); await process_frame
	var file:=FileAccess.open(options.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"success":report.success,"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
