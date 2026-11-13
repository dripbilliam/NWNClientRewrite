extends SceneTree
const Browser=preload("res://systems/server_browser.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);print("FAIL ",label)
func wait_until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+50000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await process_frame
	return predicate.call()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		if arg.begins_with("--install="):install=arg.substr(10)
	root.size=Vector2i(1280,900)
	var surface:=SubViewport.new();surface.size=root.size;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_disable_input=false;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var display:=TextureRect.new();root.add_child(display);display.texture=surface.get_texture();display.size=root.size;display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Original browser resources mount read-only")
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original localized text loads")
	var painter:=Painter.new();surface.add_child(painter);painter.configure_source(catalog,ProjectSettings.globalize_path("user://browser-assets"))
	var ui:=Browser.new();surface.add_child(ui);ui.request.connect(func(value):requests.append(value.duplicate(true)));ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://browser-assets"))
	var native=ui.native_browser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Native browser prepares: "+native.failure)
	if native.layout_ready:
		ui.open();ui.entry_context=true;ui.entry_stage="browser"
		var view:={"kind":"browser-view","connection":0,"viewId":1,"sourcePage":true,"tab":"Internet","gameType":null,"direct":{"host":"127.0.0.1","port":5125,"name":"NWN40"},"canJoin":true,"canDiscover":false,"hasSavedCdKey":true,"hasSessionProfile":true,"page":0,"pages":1,"rows":[],"busy":false}
		ui.receive(view);await process_frame
		var types: ItemList=native.pages.Internet.buttons["@gametypelist"]
		check(native.game_types.size()==13 and types.item_count==14,"All plus thirteen source game types are selectable")
		check(types.get_item_text(0)==text.raw({"strRef":67445}) and types.get_item_text(1)==text.raw({"strRef":10713}),"All and Action captions use original TLK text")
		check(types.get_selected_items()==PackedInt32Array([0]),"All is selected without a backend game-type constraint")
		var point:=types.get_global_rect().position+Vector2(12,types.get_item_rect(2).get_center().y)
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;surface.push_input(event,true);await process_frame
		check(requests.back().operation=="game-type" and requests.back().gameType==1 and requests.back().viewId==1,"Actual game-type pointer input sends the source ordinal, not discovery group363")
		view.viewId=2;view.gameType=1;ui.receive(view);await process_frame
		check(types.get_selected_items()==PackedInt32Array([2]),"Authoritative game-type selection is retained")
		var count:=requests.size();var old_scope: Array=native.scope.duplicate();var old_revision: int=native.revision
		view.viewId=3;view.busy=true;ui.receive(view);native.select_game_type(0,old_scope,old_revision)
		check(requests.size()==count,"Busy and retired game-type captures cannot submit")
		view.viewId=4;view.busy=false;ui.receive(view);native.select_game_type(0,native.scope.duplicate(),native.revision)
		check(requests.back().operation=="game-type" and requests.back().gameType==null,"All clears the game-type constraint")
		view.viewId=5;view.gameType=null;ui.receive(view)
		if DisplayServer.get_name()!="headless":
			check(root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus(),"The client stays unfocused on a secondary monitor")
			check(await wait_until(func():return painter.art.waiting.is_empty() and painter.art.models.pending.is_empty() and not painter.art.models.active and painter.fonts.pending.is_empty()),"Original browser artwork and fonts settle")
			await process_frame;await RenderingServer.frame_post_draw;check(surface.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Native browser screenshot saved")
	ui.close_native();ui.free();painter.close();painter.free();text.close();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":{"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"unfocusable":root.unfocusable,"focused":root.has_focus()}},"  "));file.close();quit(0 if failures.is_empty() else 1)
