extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const TextOwner=preload("res://systems/native_data/talk_text.gd")
const ItemPlan=preload("res://systems/native_data/item_icon.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Examine=preload("res://systems/server_examine.gd")
const Frame=preload("res://systems/native_examine_frame.gd")
class GoldStub:
	extends RefCounted
	func balance() -> int:return 1000
class InventoryUiStub:
	extends RefCounted
	var wanted:=true
class InventoryStub:
	extends Node
	var frame_skin
	var icons
	var examine_owner
	var objects: Dictionary={}
	var store: Dictionary={}
	var gold=GoldStub.new()
	var ui=InventoryUiStub.new()
	var pending: Dictionary={}
	var views: Dictionary={}
	var view_serial:=0
	func store_command(_message: Dictionary) -> void:pass
class UiStub:
	extends Node
	var inventory
	var examine
	var text=TextOwner.new()
	var generation:=1
	var area_id:=1
	var controlled_id:=1
	var table_requests:=0
	func request_examine_tables() -> void:table_requests+=1
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var install:="";var graphical:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
		elif arg=="--graphical":graphical=true
	if install.is_empty():quit(2);return
	if graphical:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
		root.size=Vector2i(1000,800)
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):quit(3);return
	catalog.build_resource_index()
	var parser:=Table.new();var baseitems: Dictionary=parser.parse(catalog.get_resource("baseitems",2017).get_string_from_ascii())
	if not parser.failure.is_empty():quit(4);return
	var item: Dictionary={}
	for index in baseitems.orderedRows.size():
		var candidate:={"baseItem":index,"parts":[1],"identified":true}
		var plan:=ItemPlan.new();var selected: Dictionary=plan.plan(candidate,{"baseitems":baseitems})
		if selected.is_empty() or plan.select(selected,catalog).is_empty():continue
		item=candidate;break
	if item.is_empty():quit(5);return
	var painter:=Painter.new();root.add_child(painter);painter.configure_source(catalog,"")
	var ui:=UiStub.new();root.add_child(ui);ui.text.base.open_file(install.path_join("lang/en/data/dialog.tlk"));ui.text.tables={"baseitems":baseitems}
	var inventory:=InventoryStub.new();ui.add_child(inventory);inventory.frame_skin=painter;ui.inventory=inventory
	var icons:=Icons.new();inventory.add_child(icons);icons.configure(catalog,"");inventory.icons=icons
	var host:=Control.new();root.add_child(host);host.size=root.size
	var examine:=Examine.new();host.add_child(examine);examine.setup("");ui.examine=examine
	ui.text.objects={1:{"appearance":{"gender":0}},2:{"item":item}}
	inventory.objects={2:{"item":item}}
	var frame:=Frame.new();ui.add_child(frame);frame.configure(ui,catalog,"")
	var message:={"type":"item","targetId":2,"revision":1,"name":{"text":"Original item"},"nativeBody":{"text":"Original item examination"},"identified":true}
	examine.present(message)
	var cold_hidden: bool=not examine.visible and examine.admission_pending
	var deadline:=Time.get_ticks_msec()+90000
	while Time.get_ticks_msec()<deadline and not examine.visible and examine.admission_failure.is_empty():await process_frame
	var cold: Dictionary=frame.art_snapshot()
	var resident: Dictionary=catalog.ui_asset_owner().lookup("item",frame.icon_key)
	var success: bool=graphical and cold_hidden and examine.visible and examine.admission_failure.is_empty() and cold.ready and not resident.is_empty() and examine.portrait.texture==resident.texture and ui.table_requests==1
	var requests_before:=int(icons.stats.requested)
	examine.present(message)
	var warm_hidden: bool=not examine.visible and examine.admission_pending
	var stale_icon_rejected: bool=not examine.set_native_portrait(resident.texture,2,2) and not examine.set_native_portrait(resident.texture,3,1)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not examine.visible and examine.admission_failure.is_empty():await process_frame
	var warm_ready: bool=warm_hidden and examine.visible and frame.art_snapshot().ready and int(icons.stats.requested)==requests_before and ui.table_requests==2
	success=success and warm_ready and stale_icon_rejected
	ui.text.objects[2].item={"baseItem":-1,"parts":[]}
	examine.present(message)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not examine.visible and examine.admission_failure.is_empty():await process_frame
	var missing_explicit: bool=examine.visible and not examine.admission_failure.is_empty() and examine.admission_notice.visible and examine.window_column.visible and frame.stages.item.visible==false
	success=success and missing_explicit
	var basic:={"type":"creature","targetId":3,"revision":4,"name":{"text":"Original creature"},"nativeBody":{"text":"Original creature examination"}}
	examine.present(basic)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not examine.visible and examine.admission_failure.is_empty():await process_frame
	var portrait_on_demand: bool=examine.visible and frame.art_snapshot().ready and examine.set_native_portrait(resident.texture,3,4)
	success=success and portrait_on_demand
	print(JSON.stringify({"success":success,"cold_hidden":cold_hidden,"cold":cold,"warm_ready":warm_ready,"stale_icon_rejected":stale_icon_rejected,"missing_explicit":missing_explicit,"portrait_on_demand":portrait_on_demand,"admission_failure":examine.admission_failure,"item_base":item.baseItem,"icon_requests":icons.stats.requested,"table_requests":ui.table_requests}))
	frame.close();frame.free();examine.free();host.free();icons.close();ui.free();painter.close();painter.free()
	quit(0 if success else 1)
