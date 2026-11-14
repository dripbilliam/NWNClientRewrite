extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const TextOwner=preload("res://systems/native_data/talk_text.gd")
const ItemPlan=preload("res://systems/native_data/item_icon.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Barter=preload("res://systems/native_barter.gd")
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
	var icon_key: String=str(barter.icon_targets.get(2,""));var resident: Dictionary=catalog.ui_asset_owner().lookup("item",icon_key)
	var success: bool=graphical and cold_hidden and barter.view.visible and barter.art_error.is_empty() and cold.ready and not resident.is_empty() and barter.view.item_buttons[2].image.texture==resident.texture
	var requests_before:=int(icons.stats.requested)
	var closed_header: Dictionary=header.duplicate(true);closed_header.open=false;closed_header.revision=2
	barter.set_world(1,1,1,objects,closed_header)
	var warm_header: Dictionary=header.duplicate(true);warm_header.serial=2;warm_header.revision=3
	barter.set_world(1,1,1,objects,warm_header)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and not barter.view.visible and barter.art_error.is_empty():await process_frame
	var warm_ready: bool=barter.view.visible and barter.art_snapshot().ready and int(icons.stats.requested)==requests_before
	success=success and warm_ready
	var invalid: Dictionary=item.duplicate(true);invalid.parts=[];objects[2].item=invalid
	var missing_header: Dictionary=warm_header.duplicate(true);missing_header.revision=4
	barter.set_world(1,1,1,objects,missing_header)
	deadline=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline and barter.art_error.is_empty():await process_frame
	barter.icon_ready(icon_key,resident.texture,"")
	var missing_explicit: bool=barter.view.visible and not barter.art_error.is_empty() and barter.view.art_notice.visible and barter.view.window_column.visible and not barter.view.stage.visible and barter.view.item_buttons[2].image.texture==null
	success=success and missing_explicit
	print(JSON.stringify({"success":success,"cold_hidden":cold_hidden,"cold":cold,"warm_ready":warm_ready,"missing_explicit":missing_explicit,"art_error":barter.art_error,"item_base":item.baseItem,"icon_requests":icons.stats.requested,"commands":desktop.commands.size()}))
	barter.close();barter.free();icons.close();ui.free();controls.free();painter.close();painter.free()
	quit(0 if success else 1)
