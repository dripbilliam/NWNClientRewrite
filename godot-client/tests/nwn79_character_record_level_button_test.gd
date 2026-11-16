extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
var checks:=0
var failures: Array=[]
var surface: SubViewport

func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func wait_until(predicate: Callable,limit_ms: int=20000)->bool:
	var deadline:=Time.get_ticks_msec()+limit_ms
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func key(surface_owner: SubViewport,chord: Dictionary)->void:
	for pressed in [true,false]:
		var event:=InputEventKey.new()
		event.keycode=int(chord.key);event.physical_keycode=int(chord.key);event.pressed=pressed
		event.shift_pressed=(int(chord.modifiers)&1)!=0;event.ctrl_pressed=(int(chord.modifiers)&2)!=0
		surface_owner.push_input(event,true)
		await process_frame

func run()->void:
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.trim_prefix("--install=")
	if install.is_empty():printerr("NWN79 Character Record test needs --install");quit(2);return
	if DisplayServer.get_screen_count()>1:DisplayServer.window_set_current_screen(1)
	root.size=Vector2i(1200,800)
	surface=SubViewport.new();surface.size=root.size;surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS;surface.gui_disable_input=false;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var display:=TextureRect.new();root.add_child(display);display.texture=surface.get_texture();display.size=root.size;display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new();check(catalog.mount_install(install),"installed-assets-mount")
	var ui:=Gameplay.new();surface.add_child(ui)
	ui.configure(catalog,install,ProjectSettings.globalize_path("res://.cache/nwn79-record-test-cache"),ProjectSettings.globalize_path("res://.cache/nwn79-record-layout.cfg"))
	var actor:={"id":4294967295,"objectType":5,"areaId":55,"nativeLifetime":1,"clientKnownLifetime":1,"replicated":{"name":{"text":"Detached level 15"},"position":[0,0,0],"hitPoints":{"current":50,"maximum":50},"stats":{"racialType":6,"classes":[{"id":4,"level":15}]}},"inventoryStats":{"field94":50000},"playerState":{"abilities":{"base":[12,12,12,12,12,12],"current":[12,12,12,12,12,12]},"combat":{"armorClass":15,"canLevelUp":true},"feats":[]}}
	ui.set_world(1,55,4294967295,[actor],{}, {"area":{"id":55},"ui":{}})
	var desktop=ui.desktop;var sheet=desktop.sheet;var skin=desktop.sheet_frame;var bindings=ui.key_bindings
	check(await wait_until(func():return bindings.bindings_ready),"native-character-keymap-ready")
	var binding: int=int(bindings.active.normal.values.get(66,0));var chord: Dictionary=bindings.native_chord(binding)
	check(binding>0 and int(chord.get("key",0))>0,"configured-character-record-key")
	var original_ready: bool=ui.tables_ready
	ui.tables_ready=false
	await key(surface,chord)
	check(not sheet.wanted,"physical-record-key-gated-before-rule-tables")
	ui.tables_ready=original_ready or await wait_until(func():return ui.table_jobs.is_empty())
	check(await wait_until(func():return ui.tables_ready),"active-rule-tables-ready")
	await key(surface,chord)
	check(await wait_until(func():return sheet.wanted and not sheet.state.is_empty(),3000),"physical-record-key-opens-self-sheet")
	check(bool(sheet.state.get("canLevelUp",false)) and sheet.page==0,"authoritative-level-flag-reaches-sheet-view")
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty(),20000),"original-character-frame-layout-prepares")
	check(skin.failure.is_empty(),"original-character-frame-no-model-failure")
	var physical:=await wait_until(func():return sheet.is_visible_in_tree() and sheet.level_button.is_visible_in_tree(),20000)
	check(physical,"physical-level-up-button-visible")
	check(sheet.level_button.visible and not sheet.level_button.disabled,"level-up-button-enabled")
	var diagnostic:={"tablesReady":ui.tables_ready,"actorId":desktop.actor_id,"recordWanted":sheet.wanted,"sheetVisible":sheet.is_visible_in_tree(),"viewId":sheet.view_id,"page":sheet.page,"canLevelUp":sheet.state.get("canLevelUp"),"buttonVisible":sheet.level_button.visible,"buttonInTree":sheet.level_button.is_visible_in_tree(),"buttonDisabled":sheet.level_button.disabled,"skinReady":skin.layout_ready,"skinDisplayReady":skin.display_ready(),"skinFailure":skin.failure,"skinPending":skin.jobs.size(),"artPending":ui.inventory.frame_skin.art.models.pending.size(),"artActive":ui.inventory.frame_skin.art.models.active,"panelPolicyComplete":ui.gui_panel_access.policy.complete,"panelPolicy":ui.gui_panel_access.policy.snapshot(),"keyBlocked":bindings.blocked()}
	sheet.close_sheet();check(not sheet.wanted and not sheet.level_button.is_visible_in_tree(),"close-hides-record-button")
	await key(surface,chord)
	check(sheet.wanted,"warm-key-reopens-record")
	var moved: Dictionary=actor.duplicate(true);moved.areaId=56
	ui.set_world(2,56,4294967295,[moved],{}, {"area":{"id":56},"ui":{}})
	check(not sheet.wanted and not sheet.level_button.visible and not sheet.is_visible_in_tree(),"area-generation-reset-retires-record-button")
	ui.close();ui.free();await process_frame
	print(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"scope":"Detached level-15 synthetic actor, installed native UI assets and configured physical Character Record key; no server or live character mutation."}))
	quit(0 if failures.is_empty() else 1)
