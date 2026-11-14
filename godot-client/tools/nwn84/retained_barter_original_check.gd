extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const TextOwner=preload("res://systems/native_data/talk_text.gd")
const ItemPlan=preload("res://systems/native_data/item_icon.gd")
const Icons=preload("res://systems/native_item_icon_scene_service.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Barter=preload("res://systems/native_barter.gd")
const Slot=preload("res://systems/inventory_slot.gd")
class GoldStub:
	extends Node
	var barter_context: Callable
	func balance() -> int:return 1000
class InventoryUiStub:
	extends RefCounted
	var barter_owner
class InventoryStub:
	extends Node
	const IconPlan=ItemPlan
	var ui=InventoryUiStub.new()
	var frame_skin
	var item_tooltips
	var gold
	var icons
	var retained_item_icons:=true
	var inventories: Dictionary={}
class RulesStub:
	extends RefCounted
	func presentation_object(_source: Dictionary,id: int,_players: Array) -> Dictionary:return {"replicated":{"name":{"text":"Partner "+str(id)},"portraitRef":0}}
	func portrait(_identity: Dictionary,_size: int) -> String:return ""
class DesktopStub:
	extends Node
	var rules=RulesStub.new()
	var state: Dictionary={"players":[]}
	var commands: Array=[]
	func command(message: Dictionary) -> void:commands.append(message)
	func barter_item_menu(_id: int,_point: Vector2,_owned: bool) -> void:pass
class UiStub:
	extends Node
	var controls
	var inventory
	var desktop
	var text=TextOwner.new()
	var tables_ready:=true
func _initialize() -> void:call_deferred("run")
func hook_error(barter,id: int) -> float:
	if not barter.view.item_buttons.has(id) or not barter.scene_host.slots.has(str(id)):return INF
	var button=barter.view.item_buttons[id]
	var local: Vector2=button.native_icon_center if button.native_icon_center!=null else button.size*0.5
	var expected: Vector2=button.get_global_transform()*local
	var model: Node3D=barter.scene_host.slots[str(id)].model
	var drawn: Vector2=barter.scene_host.get_global_transform()*Vector2(model.position.x*100.0,-model.position.z*100.0)
	return expected.distance_to(drawn)
func projection_error(barter,id: int) -> float:
	if not barter.scene_host.slots.has(str(id)):return INF
	var model: Node3D=barter.scene_host.slots[str(id)].model
	var projected: Vector2=barter.scene_host.camera.unproject_position(model.global_position)
	var composed:=Vector2(projected.x,float(barter.scene_host.viewport.size.y)-projected.y)
	return composed.distance_to(Vector2(model.position.x*100.0,-model.position.z*100.0))
func overlap_error(image: Image) -> float:
	var marker:=Rect2i();var found:=false
	for y in image.get_height():
		for x in image.get_width():
			var color: Color=image.get_pixel(x,y)
			if color.r>0.9 and color.g<0.1 and color.b>0.9:
				marker=marker.expand(Vector2i(x,y)) if found else Rect2i(x,y,1,1);found=true
	if not found:return INF
	var green:=Rect2i();var green_found:=false;var center:=marker.get_center()
	for y in range(maxi(0,center.y-100),mini(image.get_height(),center.y+100)):
		for x in range(maxi(0,center.x-100),mini(image.get_width(),center.x+100)):
			var color: Color=image.get_pixel(x,y)
			if color.g>0.03 and color.g<0.5 and color.g>color.r*1.2 and color.g>color.b*1.1:
				green=green.expand(Vector2i(x,y)) if green_found else Rect2i(x,y,1,1);green_found=true
	return center.distance_to(green.get_center()) if green_found else INF
func run() -> void:
	var install:="";var graphical:=false;var report_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
		elif arg=="--graphical":graphical=true
		elif arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	if install.is_empty():quit(2);return
	if graphical:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
		root.size=Vector2i(1100,850)
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):quit(3);return
	catalog.build_resource_index()
	var parser:=Table.new();var baseitems: Dictionary=parser.parse(catalog.get_resource("baseitems",2017).get_string_from_ascii())
	if not parser.failure.is_empty():quit(4);return
	var item: Dictionary={}
	for index in baseitems.orderedRows.size():
		var candidate:={"baseItem":index,"parts":[1],"name":{"text":"Original item"}}
		var plan:=ItemPlan.new();var selected: Dictionary=plan.plan(candidate,{"baseitems":baseitems})
		if selected.is_empty() or plan.select(selected,catalog).is_empty():continue
		item=candidate;break
	if item.is_empty():quit(5);return
	var painter:=Painter.new();root.add_child(painter);painter.configure_source(catalog,"")
	var ui:=UiStub.new();root.add_child(ui);ui.text.base.open_file(install.path_join("lang/en/data/dialog.tlk"));ui.text.tables={"baseitems":baseitems}
	var desktop:=DesktopStub.new();ui.add_child(desktop);ui.desktop=desktop
	var controls:=Control.new();root.add_child(controls);controls.size=root.size;ui.controls=controls
	var inventory:=InventoryStub.new();ui.add_child(inventory);inventory.frame_skin=painter;ui.inventory=inventory
	var gold:=GoldStub.new();inventory.add_child(gold);inventory.gold=gold
	var icons:=Icons.new();inventory.add_child(icons);icons.configure(catalog,"");inventory.icons=icons
	inventory.inventories={"B":{"entries":[{"id":2,"x":0,"y":0}]},"A":{"entries":[]}}
	var barter:=Barter.new();ui.add_child(barter);barter.configure(ui,catalog,"","")
	var objects:={1:{"appearance":{"gender":0}},2:{"item":item,"inventoryLocation":{"ownerId":1,"channel":"B","x":0,"y":0}},3:{"replicated":{"name":{"text":"Partner"}}}}
	var header:={"open":true,"actorId":1,"areaId":1,"partnerId":3,"serial":1,"revision":1,"ownLocked":false,"otherLocked":false,"ownAccepted":false,"otherAccepted":false,"initiator":true}
	barter.set_world(1,1,1,objects,header)
	var cold_hidden: bool=not barter.view.visible
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and not barter.view.visible and barter.art_error.is_empty():await process_frame
	var cold: Dictionary=barter.art_snapshot()
	var icon_key: String=str(barter.icon_targets.get(2,""))
	var success: bool=graphical and cold_hidden and barter.view.visible and barter.art_error.is_empty() and cold.ready and icons.bundles.has(icon_key) and barter.scene_host.binding_ready("2") and barter.view.item_buttons[2].image.texture==null
	var prepared_before:=icons.bundles.size()
	var scale_rows: Array=[]
	var overlap_capture:=""
	var marker_gap:=INF
	if graphical:
		root.size=Vector2i(3440,1369)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size=root.size
		for scale_value in [1.0,1.3,1.9]:
			root.content_scale_factor=scale_value
			await process_frame;await process_frame
			var row:={"scale":scale_value,"width":root.size.x,"hook_error":hook_error(barter,2),"projection_error":projection_error(barter,2),"ready":barter.scene_host.binding_ready("2"),"stage_size":str(barter.view.stage.size),"host_size":str(barter.scene_host.size)}
			scale_rows.append(row)
			success=success and row.hook_error<0.5 and row.projection_error<0.5 and row.ready
		var button=barter.view.item_buttons[2]
		var marker:=ColorRect.new();marker.color=Color(1,0,1,1);marker.size=Vector2(20,20);marker.z_index=2
		marker.position=button.native_icon_center-marker.size*0.5;button.add_child(marker)
		await process_frame
		if not report_path.is_empty():
			overlap_capture=report_path.trim_suffix(".json")+"-overlap.png"
			var capture: Image=root.get_texture().get_image()
			marker_gap=overlap_error(capture)
			success=success and marker_gap<12.0 and capture.save_png(overlap_capture)==OK
		marker.free()
	var drag_preview: Control=Slot.scene_drag_preview(icons,icon_key,icons.bundles.get(icon_key,{}))
	if drag_preview!=null:
		root.add_child(drag_preview)
		deadline=Time.get_ticks_msec()+3000
		while Time.get_ticks_msec()<deadline and not drag_preview.get_child(0).binding_ready("preview"):await process_frame
	var drag_ready: bool=drag_preview!=null and drag_preview.get_child(0).binding_ready("preview") and drag_preview.get_child(0).viewport.get_texture().get_image().get_used_rect().has_area()
	success=success and drag_ready
	if drag_preview!=null:drag_preview.free()
	var closed_header: Dictionary=header.duplicate(true);closed_header.open=false;closed_header.revision=2
	barter.set_world(1,1,1,objects,closed_header)
	var warm_header: Dictionary=header.duplicate(true);warm_header.serial=2;warm_header.revision=3
	barter.set_world(1,1,1,objects,warm_header)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not barter.view.visible and barter.art_error.is_empty():await process_frame
	var warm_ready: bool=barter.view.visible and barter.art_snapshot().ready and icons.bundles.size()==prepared_before
	success=success and warm_ready
	var invalid: Dictionary=item.duplicate(true);invalid.parts=[];objects[2].item=invalid
	var missing_header: Dictionary=warm_header.duplicate(true);missing_header.revision=4
	barter.set_world(1,1,1,objects,missing_header)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and barter.art_error.is_empty():await process_frame
	barter.scene_icon_ready(icon_key,icons.bundles.get(icon_key,{}),"")
	var missing_explicit: bool=barter.view.visible and not barter.art_error.is_empty() and barter.view.art_notice.visible and barter.view.window_column.visible and not barter.view.stage.visible and barter.view.item_buttons[2].image.texture==null
	success=success and missing_explicit
	var report:={"success":success,"cold_hidden":cold_hidden,"cold":cold,"scale_rows":scale_rows,"overlap_capture":overlap_capture,"marker_gap":marker_gap,"drag_ready":drag_ready,"warm_ready":warm_ready,"missing_explicit":missing_explicit,"art_error":barter.art_error,"item_base":item.baseItem,"prepared":icons.bundles.size(),"host_slots":barter.scene_host.slots.size(),"commands":desktop.commands.size()}
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report))
	barter.close();barter.free();icons.close();ui.free();controls.free();painter.close();painter.free()
	quit(0 if success else 1)
