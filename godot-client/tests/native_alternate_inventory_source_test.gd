extends SceneTree
const Source=preload("res://tests/native_skill_description_source_test.gd")
const Owner=preload("res://systems/native_inventory.gd")
const Windows=preload("res://systems/native_inventory_windows.gd")
const Inventory=preload("res://systems/server_inventory.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Equipment=preload("res://systems/native_inventory_equipment.gd")
const Frame=preload("res://systems/native_inventory_frame.gd")
class Fonts extends Source.ControlledFonts:
	func snapshot() -> Dictionary:return {"controlled":true,"closed":closed}
class SourceEquipment extends Equipment:
	func configure(owner,catalog,cache_path: String) -> void:
		inventory=owner;assets=Assets.new();add_child(assets);assets.configure(catalog);assets.cache_directory=cache_path;assets.maximum_workers=2;assets.completed.connect(prepared)
		art=Source.ControlledArt.new();add_child(art)
		background=Control.new();background.set_meta("native_inventory_art",true);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;inventory.equipment.add_child(background)
		jobs[assets.request("inv_equip",2047,"gff") ]="@layout"
class SourceFrame extends Frame:
	func configure_fonts(_catalog,_cache_path: String) -> void:
		fonts=Fonts.new();add_child(fonts);art.loaded.connect(art_loaded)
class Unused extends Node:
	var closed:=false
	var layout_ready:=false
	func cancel() -> void:pass
	func close() -> void:closed=true
	func snapshot() -> Dictionary:return {"unused":true,"closed":closed}
	func blocks_pointer(_point: Vector2) -> bool:return false
class UnusedIcons extends Unused:
	var textures: Dictionary={}
	func request(_item: Dictionary,_tables: Dictionary,_gender: int) -> String:return ""
class Ui extends Node:
	signal request(message: Dictionary)
	var controlled_id:=1
	var area_id:=55
	var controls: Control
	var text
	var inventory
var checks:=0
var failures: Array=[]
var requests: Array=[]
var click_diagnostics: Array=[]
var surface: SubViewport
var ui
var windows
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
	return value
func frames(count: int=2) -> void:
	for index in count:await process_frame
func click(control: Control,interior: Vector2=Vector2(-1,-1)) -> void:
	var point:=control.get_global_transform_with_canvas()*(control.size*0.5 if interior.x<0 else interior)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await process_frame
	var hovered: Variant=surface.call("gui_get_hovered_control") if surface.has_method("gui_get_hovered_control") else null
	click_diagnostics.append({"control":str(control.get_path()),"point":str(point),"rect":str(control.get_global_rect()),"visible":control.is_visible_in_tree(),"disabled":control.disabled if control is BaseButton else false,"hovered":str(hovered.get_path()) if is_instance_valid(hovered) else "none","parent_rect":str(control.get_parent().get_global_rect()) if control.get_parent() is Control else "none"})
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.position=point;event.global_position=point;surface.push_input(event,true);await process_frame
func make_inventory(role: String,catalog,cache: String):
	var value:=Owner.new();ui.add_child(value);value.window_role=role;value.text_owner=ui.text
	value.ui=Inventory.new();ui.controls.add_child(value.ui);value.ui.item_commands_enabled=role=="primary";value.ui.setup("","inventory" if role=="primary" else "associate-inventory");value.ui.request.connect(value.input_request);value.request.connect(ui.request.emit)
	value.equipment_skin=SourceEquipment.new();value.add_child(value.equipment_skin);value.ui.native_equipment=value.equipment_skin;value.equipment_skin.configure(value.ui,catalog,cache)
	value.frame_skin=SourceFrame.new();value.add_child(value.frame_skin);value.ui.native_frame=value.frame_skin;value.frame_skin.configure(value.ui,catalog,cache,ui.text,value.equipment_skin)
	for field in ["gold","stack_dialog","item_context","item_tooltips","store_skin"]:
		var unused:=Unused.new();value.add_child(unused);value.set(field,unused)
	value.icons=UnusedIcons.new();value.add_child(value.icons);return value
func record(owner_id: int,opened: bool,serial: int,receipt: int) -> Dictionary:
	return {"role":"alternate","ownerId":owner_id,"rawOwnerId":owner_id,"actorId":1,"areaId":55,"open":opened,"receivedOpen":opened,"serial":serial,"receiptSerial":receipt,"source":"server13/1"}
func run() -> void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	if not options.has_all(["report","install"]) or FileAccess.file_exists(options.report):quit(2);return
	create_timer(30).timeout.connect(func():quit(3))
	var diagnostic:=await exercise(options)
	if is_instance_valid(windows):windows.close();windows.free()
	if is_instance_valid(ui):
		ui.inventory.close();ui.text.close();ui.free()
	if is_instance_valid(surface):surface.free()
	await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"scope":"Actual installed inv_panel/inv_equip/inv_container native geometry with controlled raster/fonts/icons and real pointer tabs/close; actual NativeInventory and window policy dispatch/retirement. Authored accepted raw13/1 fixtures only, no game-server/pixel/GPU acceptance; alternate item commands remain disabled."}
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();quit(0 if result.success else 1)
func exercise(options: Dictionary) -> Dictionary:
	var catalog:=Catalog.new()
	if not check(catalog.mount_install(options.install),"Installed original resource catalog mounts"):return {}
	root.size=Vector2i(1440,1000);surface=SubViewport.new();surface.size=root.size;surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.handle_input_locally=true;surface.gui_disable_input=false;root.add_child(surface);surface.notify_mouse_entered()
	ui=Ui.new();root.add_child(ui);ui.controls=Control.new();surface.add_child(ui.controls);ui.controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.controls.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.text=Talk.new();ui.text.base.open_file(str(options.install).path_join("lang/en/data/dialog.tlk"))
	for name in ["baseitems","encumbrance"]:ui.text.publish_table(name,Table.new().parse(catalog.read_resource(name,2017).get_string_from_ascii()))
	ui.inventory=make_inventory("primary",catalog,str(options.report).get_base_dir().path_join("models"));var alternate=make_inventory("alternate",catalog,str(options.report).get_base_dir().path_join("models"))
	windows=Windows.new();root.add_child(windows);windows.owner_ui=ui;windows.alternate=alternate;windows.states={"primary":windows.initial_state(),"alternate":windows.initial_state()};ui.inventory.ui.request.connect(windows.local_input.bind("primary"));alternate.ui.request.connect(windows.local_input.bind("alternate"));ui.request.connect(func(message):requests.append(message.duplicate(true)))
	windows.detailed_timings=true;alternate.detailed_timings=true
	var actor:={"id":1,"objectType":5,"replicated":{"name":{"text":"Primary fixture"}},"inventoryStats":{"field8c":11}}
	var associate:={"id":42,"objectType":5,"replicated":{"name":{"text":"Received associate"}},"inventoryStats":{"field8c":19}}
	var primary_item:={"id":501,"objectType":6,"item":{"baseItem":0,"name":{"text":"Primary sword"}},"inventoryLocation":{"channel":"R","ownerId":1,"x":0,"y":0}}
	var alternate_item:={"id":502,"objectType":6,"item":{"baseItem":0,"name":{"text":"Associate sword"}},"inventoryLocation":{"channel":"r","ownerId":42,"x":0,"y":0}}
	var raw:={"inventories":[["R",{"entries":[{"id":501,"x":0,"y":0}]}],["r",{"entries":[{"id":502,"x":0,"y":0}]}]],"windows":{"alternate":record(42,true,1,1)}}
	ui.inventory.set_world(1,55,1,[actor,associate,primary_item,alternate_item],raw);windows.synchronize(1,55,1,raw)
	check(not alternate.ui.wanted and requests.is_empty(),"Received open waits for source geometry without an echoed input or placeholder window")
	var deadline:=Time.get_ticks_msec()+20000
	while (not windows.ready_view(ui.inventory) or not windows.ready_view(alternate)) and Time.get_ticks_msec()<deadline:await process_frame
	if not check(windows.ready_view(ui.inventory) and windows.ready_view(alternate),"Both actual native source windows finish model layout"):return {"primaryFailure":ui.inventory.frame_skin.failure,"alternateFailure":alternate.frame_skin.failure}
	await frames(5)
	check(alternate.ui.wanted and alternate.displayed_owner()==42 and alternate.ui.heading.text=="Inventory: Received associate","Accepted13/1 presents the actual received NPC owner/title")
	check(alternate.objects==ui.inventory.objects and alternate.ui.items.has(502) and not alternate.ui.items.has(501),"Alternate native view shares canonical object identity but reads only lower r/i membership")
	check(alternate.ui.ac.text.contains("19") and not ui.inventory.ui.wanted and requests.is_empty(),"Alternate actor AC and silent opening leave primary visibility/input unchanged")
	check(windows.timing_rows.any(func(row):return row.phase=="native-window-visible" and row.visible and not row.pixels_measured),"Opt-in native timing records real control visibility separately from GPU presentation")
	check(not alternate.timing_rows.is_empty() and alternate.timing_rows.all(func(row):return row.data_received_us>0 and row.data_to_controls_us>=0 and row.refresh_us>=0 and not row.pixels_measured),"Opt-in native row timing retains accepted-data and synchronous-control commit boundaries")
	check(alternate.ui.size==Vector2(360,470) and alternate.ui.repository.cell_size==33 and alternate.frame_skin.definition.resource==ui.inventory.frame_skin.definition.resource,"Both views reuse original extent/grid/resource geometry")
	check(alternate.ui.buttons[502].disabled and alternate.ui.item_controls.examine.disabled and alternate.frame_skin.gold_button.disabled,"Untraced alternate item, examine and gold commands are explicitly disabled")
	var before:=requests.size();await click(alternate.ui.pages[1]);await frames()
	check(requests.size()==before+1 and requests.back().kind=="inventory-page" and int(requests.back().page)==1 and requests.back().inventoryRole=="alternate" and int(requests.back().ownerId)==42 and int(requests.back().windowSerial)==1 and int(requests.back().inventoryReceipt)==1,"Actual original page tab dispatches exact alternate owner/window lifetime")
	var page_request: Dictionary=requests.back().duplicate(true)
	check(alternate_item.inventoryLocation.channel=="r" and int(alternate_item.inventoryLocation.y)==0,"Native presentation does not invent primary membership or new repository coordinates")
	ui.inventory.ui.open();ui.inventory.refresh();await frames();check(ui.inventory.ui.wanted and alternate.ui.wanted,"Independent primary and alternate inventories coexist")
	ui.inventory.ui.position=Vector2(50,40);alternate.ui.position=Vector2(650,40);await frames();before=requests.size()
	# Authored raster has no per-pose bounds publication: the source all-pose
	# X rectangle overlaps the head slot at its center. Its top interior is a
	# genuine X hit; exact original raster/up-pose footprint is not claimed.
	await click(alternate.ui.close_button,Vector2(8,8))
	check(not alternate.ui.wanted and ui.inventory.ui.wanted and requests.size()==before+1 and requests.back().kind=="inventory-close" and requests.back().inventoryRole=="alternate" and int(requests.back().ownerId)==42,"Actual original alternate close retires only its view and sends the received owner")
	check(int(windows.owner_snapshot("alternate").displayedOwner)==42 and not windows.owner_snapshot("alternate").active,"Closed view retains original displayed owner while active state retires locally")
	before=requests.size();windows.observe({"alternate":record(42,true,2,2)});await frames();check(alternate.ui.wanted and requests.size()==before,"A later accepted original13/1 reopens without request echo")
	var previous_view: int=alternate.view_serial
	windows.receive({"kind":"inventory-command-result","inventoryRole":"alternate","ownerId":42,"windowSerial":1,"accepted":false,"reason":"Retired failure"});check(alternate.notice_text.is_empty(),"Retired command failure cannot contaminate a reopened view")
	alternate.input_request({"kind":"inventory-page","viewId":previous_view-1,"page":0});check(requests.size()==before,"Old private view ID cannot page the current associate")
	var saved: Dictionary=alternate_item.duplicate(true);before=requests.size();alternate.ui.operation(502,"drop");alternate.input_request({"kind":"inventory-action","viewId":alternate.view_serial,"entryId":502,"operation":"drop"});check(requests.size()==before and alternate_item==saved,"Unported alternate item path is blocked at both control and controller boundary")
	windows.observe({"alternate":record(42,false,3,3)});await frames();check(not alternate.ui.wanted and requests.size()==before,"Received close silently retires an actual alternate window")
	windows.observe({"alternate":record(42,true,4,4)});await frames();var count: int=alternate.objects.size();var source_models: Array=alternate.equipment_skin.models.keys();windows.close();check(ui.inventory.objects.size()==count and ui.inventory.objects.has(1),"Alternate close lifecycle detaches the shared map before clearing private owners")
	return {"requests":requests,"sourceModels":source_models,"window_state":windows.states,"page_request":page_request,"alternate_item_actions":false,"clicks":click_diagnostics,"up_pose_raster_footprint":false}
