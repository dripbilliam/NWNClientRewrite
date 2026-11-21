extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Raw protocol UI messages in; native original TLK/2DA/texture readers and
# Godot controls out. No spans, PNG URLs or rendering-ready layouts from JS.
signal request(message: Dictionary)
signal options_requested
signal gui_sound_requested(resource: String)
const Desktop=preload("res://systems/native_game_desktop.gd")
const GameInput=preload("res://systems/native_data/game_input.gd")
var desktop
var gui_panel_access
var modal_order
var modal_surfaces
var modal_radials_bound:=false
var radial_preferences: Dictionary={}
func set_radial_preferences(value: Dictionary) -> void:
	if value==radial_preferences or not is_instance_valid(desktop): return
	radial_preferences=value.duplicate()
	desktop.ability_rules.always_subradial=bool(value.get("group_abilities",false)); desktop.spell_rules.always_subradial=bool(value.get("group_spells",false))
	for wheel in [desktop.radial,inventory.item_context.wheel]:
		wheel.submenu_previews=bool(value.get("submenu_previews",true)); wheel.submenu_preview_mode=clampi(int(value.get("submenu_mode",int(wheel.submenu_previews))),0,2); wheel.text_preview_mode=clampi(int(value.get("text_mode",1)),0,2)
		wheel.hide_icons=bool(value.get("hide_icons",false)); wheel.text_in_center=bool(value.get("text_in_center",false)); wheel.center_align_text=bool(value.get("center_align_text",false)); wheel.use_screen_center=bool(value.get("screen_center",false)); wheel.left_mirrors_right=bool(value.get("left_mirror",true)); wheel.reset()
	desktop.radial_stack.clear(); desktop.radial_entries.clear(); desktop.pending_shortcuts.clear()
var mouse_cursor
var creator
var nui
const Assets=preload("res://systems/native_data/asset_service.gd")
const TextOwner=preload("res://systems/native_data/talk_text.gd")
const SpeechHeader=preload("res://systems/native_data/ordinary_speech_header_receipt.gd")
const ActorNames=preload("res://systems/native_data/actor_name_state.gd")
var actor_names=ActorNames.new()
var actor_name_history_complete:=false
const Rich=preload("res://systems/native_data/rich_text.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Chat=preload("res://systems/server_chat.gd")
const Conversation=preload("res://systems/server_conversation.gd")
const Examine=preload("res://systems/server_examine.gd")
const ItemPropertyText=preload("res://systems/native_data/item_property_text.gd")
const Numbers=preload("res://systems/native_data/game_numbers.gd")
const SpeechText=preload("res://systems/native_data/ordinary_speech_text_receipt.gd")
const UiSkin=preload("res://systems/native_ui_skin.gd")
const InventoryOwner=preload("res://systems/native_inventory.gd")
var feedback=preload("res://systems/native_data/combat_feedback.gd").new()
func set_feedback_options(enabled: bool,total_only: bool)->void:
	feedback.floating_enabled=enabled
	feedback.total_damage_only=total_only
var floating_rows: Array=[]
var floating_font_reported: Dictionary={}
var overhead
var popup_fonts
var script_floating
var script_floating_anchor_query:=Callable()
var script_floating_object_delta_query:=Callable()
var overhead_popup_source
var overhead_popup_registry
var popup_options
var popup_preferences:={"mode":2,"largeFont":true}
var native_connection_query:=Callable()
var chat_focus_phase_query:=Callable()
var overhead_anchor_query:=Callable()
var world_camera: Camera3D
var world_camera_yaw: Callable
var world_registry
var text:=TextOwner.new()
var custom_token_connection: Variant=null
var pool:=Pool.new()
var assets
var catalog
var layer: CanvasLayer
var controls: Control
var window_layers
var key_bindings
var chat
var chat_skin
var conversation
var conversation_skin
var examine
var examine_skin
var skin_owner
var inventory
var inventory_windows
var timing_view
var barter
var generation:=-1
var area_id:=-1
var controlled_id:=-1
var closed:=false
var presentation_enabled:=true
var tables_ready:=false
var hud_ready:=false
var bindings_installed:=false
const HUD_TABLES=["stringtokens","portraits"]
const EARLY_TABLES=["stringtokens","portraits","keymap","damagelevels"]
var startup_at:=0
var startup_jobs: Dictionary={}
var startup_finished: Array=[]
var startup_marks: Dictionary={}
var table_jobs: Dictionary={}
var feedback_table_jobs: Dictionary={}
var feedback_table_errors: Dictionary={}
var tlk_jobs: Dictionary={}
var custom_tlk_requested:=false
var custom_tlk_female_absent:=false
var custom_tlk_primary_loaded:=false
var custom_tlk_female_loaded:=false
var custom_tlk_load_failed:=false
var portrait_jobs: Dictionary={}
var portrait_textures: Dictionary={}
var examine_portrait_waiting: Dictionary={}
var examine_jobs: Dictionary={}
var examine_pending: Dictionary={}
var examine_message: Dictionary={}
var queue: Array=[]
var pending_speech_logs: Array=[]
var pending_voice_captions: Array=[]
var speech_text_revision:=-1
var revision:=0
var stats:={"messages":0,"speech":0,"dialogs":0,"examines":0,"portraits":0,"stale_messages":0,"errors":[],"native_only":true,"full_ui_migration":false}
func configure(source,install: String,cache_path: String,layout: String="user://native-menu-layout.cfg",custom_tlk: Dictionary={}) -> void:
	modal_order=preload("res://systems/native_data/modal_order.gd").new()
	modal_surfaces=preload("res://systems/native_modal_surfaces.gd").new();add_child(modal_surfaces);modal_surfaces.configure(modal_order)
	startup_at=Time.get_ticks_msec()
	catalog=source; portrait_textures.clear(); feedback.text=text
	text.network_table_request=Callable(self,"request_network_text_table")
	var recorded: bool=catalog.has_method("talk_path")
	text.retire_native_family(false)
	var base_loaded: bool=text.base.open_file(catalog.talk_path("base") if recorded else install.path_join("lang/en/data/dialog.tlk"))
	if not base_loaded: stats.errors.append(text.base.failure)
	var female_path: String=catalog.talk_path("female") if recorded else install.path_join("lang/en/data/dialogf.tlk")
	var female_loaded:=false
	if FileAccess.file_exists(female_path):
		female_loaded=text.female.open_file(female_path)
		if not female_loaded:stats.errors.append(text.female.failure)
	var female_absent:=native_female_absent(recorded,"female",female_path)
	if base_loaded and (female_loaded or female_absent):text.publish_native_family(false,female_absent)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	key_bindings=preload("res://systems/native_key_bindings.gd").new(); add_child(key_bindings); key_bindings.configure(layout)
	# Portrait/name projection and movement bindings do not depend on every
	# class/feat/spell table. Dispatch these before optional/custom text work.
	for name in EARLY_TABLES: request_startup_table(name)
	if not custom_tlk.is_empty():
		text.retire_native_family(true);custom_tlk_requested=true;custom_tlk_primary_loaded=false;custom_tlk_female_loaded=false;custom_tlk_load_failed=false
		var name:=str(custom_tlk.get("name","")).get_file().trim_suffix(".tlk").to_lower()
		var path:=str(custom_tlk.get("path","")) if custom_tlk.get("path") is String else ""
		if recorded: path=catalog.talk_path("custom")
		var custom_female_path: String=catalog.talk_path("custom_female") if recorded else path.trim_suffix(".tlk")+"f.tlk" if not path.is_empty() else ""
		var female_resource: bool=catalog.has_resource(name+"f",2018)
		custom_tlk_female_absent=not female_resource and native_female_absent(recorded,"custom_female",custom_female_path)
		if catalog.has_resource(name,2018): tlk_jobs[assets.request(name,2018,"bytes")]=false
		elif not path.is_empty():
			custom_tlk_primary_loaded=text.custom.open_file(path)
			if not custom_tlk_primary_loaded:custom_tlk_load_failed=true;stats.errors.append(text.custom.failure)
		else:custom_tlk_load_failed=true
		if female_resource: tlk_jobs[assets.request(name+"f",2018,"bytes")]=true
		elif not custom_female_path.is_empty() and FileAccess.file_exists(custom_female_path):
			custom_tlk_female_loaded=text.custom_female.open_file(custom_female_path)
			if not custom_tlk_female_loaded:custom_tlk_load_failed=true;stats.errors.append(text.custom_female.failure)
		elif not custom_tlk_female_absent:custom_tlk_load_failed=true
		publish_custom_native_family()
	for name in ["racialtypes","classes","baseitems","armor","itempropdef","iprp_costtable","iprp_paramtable","damagetypes","damagetypegroups","effecticons","traps","encumbrance","capart","parts_robe","cloakmodel","iprp_spells","spells","feat","skills","exptable","domains","ranges","actions","ruleset","hen_familiar","hen_companion","spellschools","masterfeats"]: request_startup_table(name)
	layer=CanvasLayer.new(); layer.layer=10; add_child(layer); controls=Control.new(); controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); controls.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(controls)
	timing_view=preload("res://systems/native_timing_view.gd").new();add_child(timing_view);timing_view.configure(controls,text)
	chat=Chat.new(); controls.add_child(chat); chat.setup(); chat.request.connect(func(message):
		desktop.command(message))
	chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); chat.position=Vector2(10,maxf(0,get_viewport().get_visible_rect().size.y-280)); chat.size=Vector2(520,260)
	get_viewport().size_changed.connect(func(): chat.position.y=maxf(0,get_viewport().get_visible_rect().size.y-280))
	conversation=Conversation.new(); controls.add_child(conversation); conversation.setup(layout); conversation.request.connect(request.emit)
	conversation.visibility_changed.connect(func():
		if conversation.visible and is_instance_valid(desktop) and is_instance_valid(desktop.radial):desktop.radial.reset())
	var examine_surface: Control=modal_surfaces.create_root(controls,layer)
	examine=Examine.new(); examine_surface.add_child(examine); examine.setup(layout);examine.set_modal_order(modal_order,modal_surfaces,examine_surface.get_parent())
	inventory=InventoryOwner.new(); add_child(inventory); inventory.configure(controls,catalog,cache_path,text,layout); inventory.request.connect(request.emit)
	inventory.gold.set_modal_order(modal_order,modal_surfaces,layer);inventory.stack_dialog.set_modal_order(modal_order,modal_surfaces,layer)
	inventory.gold.world_pick=func(point): return world_registry.pick(world_camera,point) if is_instance_valid(world_registry) and is_instance_valid(world_camera) else {}
	inventory.gold.world_blocked=blocks_pointer
	inventory_windows=preload("res://systems/native_inventory_windows.gd").new(); add_child(inventory_windows); inventory_windows.configure(self,catalog,cache_path,layout)
	skin_owner=UiSkin.new(); add_child(skin_owner); skin_owner.fonts_ready.connect(func(): controls.theme=skin_owner.theme()); skin_owner.configure(catalog,cache_path)
	desktop=Desktop.new(); add_child(desktop); desktop.configure(self,catalog,cache_path,layout); desktop.request.connect(request.emit); desktop.options_requested.connect(options_requested.emit)
	inventory.ui.visibility_changed.connect(func():
		if inventory.ui.visible and is_instance_valid(desktop) and is_instance_valid(desktop.radial):desktop.radial.reset())
	# Speech and hover captions use the original shared popup resource family.
	# This owner outlives each area's HUD and cannot lose model-pending speech.
	popup_options=preload("res://systems/native_chat_options.gd").acquire(get_viewport(),layout)
	popup_preferences=popup_settings_from(popup_options.values)
	popup_options.settings_changed.connect(popup_preferences_changed)
	overhead_popup_source=preload("res://systems/native_nameplate_resources.gd").new();add_child(overhead_popup_source);overhead_popup_source.configure(catalog,cache_path)
	popup_fonts=preload("res://systems/native_popup_fonts.gd").new();add_child(popup_fonts);popup_fonts.configure(catalog,cache_path)
	var speech_overlay:=Control.new();controls.add_child(speech_overlay);controls.move_child(speech_overlay,0);speech_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overhead=preload("res://systems/native_overhead_speech.gd").new();add_child(overhead)
	overhead.configure(speech_overlay,text,popup_fonts,desktop.art,overhead_popup_source,overhead_context,overhead_source,overhead_anchor,popup_settings)
	overhead_popup_registry=preload("res://systems/native_overhead_popup_registry.gd").new();add_child(overhead_popup_registry);overhead_popup_registry.configure(overhead_context,overhead_source,popup_settings,popup_name_caption,popup_restoration);overhead.bind_popup_registry(overhead_popup_registry)
	# Script floaties are distinct native GUI widgets behind ordinary popups
	# (-5.1 versus -5.0). Neither passive overlay captures movement or clicks.
	var script_overlay:=Control.new();controls.add_child(script_overlay);controls.move_child(script_overlay,0);script_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);script_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	script_floating=preload("res://systems/native_script_floating.gd").new();add_child(script_floating)
	script_floating.configure(script_overlay,text,inventory.frame_skin.fonts,desktop.art,catalog,overhead_context,overhead_source,script_floating_anchor,cache_path)
	for font_name in ["fnt_floaty_smal","fnt_galahad14"]:inventory.frame_skin.fonts.request(font_name)
	script_floating.object_delta_ms_reader=script_floating_object_delta
	script_floating.log_message.connect(func(row):chat.append_message(row))
	desktop.shortcut_dialogs.information.set_modal_order(modal_order)
	desktop.shortcut_dialogs.edit.set_modal_owner(modal_order,"other")
	modal_surfaces.bind_layer(desktop.shortcut_dialogs.information,desktop.shortcut_dialogs);modal_surfaces.bind_layer(desktop.shortcut_dialogs.edit,desktop.shortcut_dialogs)
	gui_panel_access=preload("res://systems/native_gui_panel_access.gd").new(); add_child(gui_panel_access); gui_panel_access.configure(self)
	chat_skin=preload("res://systems/native_chat_hud.gd").new(); add_child(chat_skin); chat_skin.context_prepared.connect(bind_modal_radials); chat_skin.configure(self,catalog,cache_path,layout)
	bind_modal_radials()
	mouse_cursor=preload("res://systems/native_mouse_cursor.gd").new(); add_child(mouse_cursor); mouse_cursor.configure(self,catalog,cache_path)
	conversation_skin=preload("res://systems/native_conversation_frame.gd").new(); add_child(conversation_skin); conversation_skin.configure(self,catalog,cache_path)
	barter=preload("res://systems/native_barter.gd").new(); add_child(barter); barter.configure(self,catalog,cache_path,layout)
	examine_skin=preload("res://systems/native_examine_frame.gd").new(); add_child(examine_skin); examine_skin.configure(self,catalog,cache_path)
	nui=preload("res://systems/native_nui.gd").new(); add_child(nui); nui.configure(self); nui.request.connect(request.emit)
	creator=preload("res://systems/native_creation.gd").new(); add_child(creator); creator.configure(self); creator.request.connect(request.emit)
	window_layers=preload("res://systems/native_window_layers.gd").new(); add_child(window_layers); window_layers.configure(controls)
func set_gameplay_visible(value: bool) -> void:
	if closed or value==presentation_enabled: return
	presentation_enabled=value
	if is_instance_valid(modal_surfaces):modal_surfaces.set_created_visible(value)
	# Catalog/font/art owners remain live for the independent pregame chooser,
	# creator and loading screen. Hide only the gameplay canvases; CanvasLayer
	# children (including NUI windows) do not inherit a Control's visibility.
	var canvases: Array=[layer,desktop.radial,inventory.item_context.wheel]
	if is_instance_valid(chat_skin) and is_instance_valid(chat_skin.context):
		canvases.append(chat_skin.context)
		if not value: chat_skin.context.reset()
	if not value:
		var focus:=get_viewport().gui_get_focus_owner()
		for canvas in canvases:
			if is_instance_valid(focus) and canvas.is_ancestor_of(focus): focus.release_focus(); break
	for canvas in canvases:
		canvas.visible=value
		canvas.process_mode=Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	# These input owners are siblings of the hidden canvas. Their preparation
	# and received-state callbacks continue, but hidden menus cannot take keys.
	set_process_unhandled_key_input(value)
	desktop.set_process_unhandled_key_input(value)
	inventory.gold.set_process_input(value)
	mouse_cursor.set_process_input(value)
	if not value:
		mouse_cursor.select(preload("res://systems/native_data/mouse_cursor.gd").selection())
func bind_modal_radials() -> void:
	if closed or not is_instance_valid(modal_order): return
	# Bookkeeping only: coverage remains unavailable until verified non-radial
	# modal owners opt in. No53/2 close or input gate is enabled by these leases.
	# Chat creates its wheel only after its asynchronous source models prepare.
	# Repeated completion/bind calls must not retire or promote an existing lease.
	var count:=0
	if is_instance_valid(desktop) and bind_modal_radial(desktop.radial,desktop.retire_current_radial): count+=1
	if is_instance_valid(inventory) and is_instance_valid(inventory.item_context) and bind_modal_radial(inventory.item_context.wheel,retire_item_radial): count+=1
	if is_instance_valid(chat_skin) and bind_modal_radial(chat_skin.context,retire_chat_radial): count+=1
	modal_radials_bound=count==3
func bind_modal_radial(wheel,retire: Callable) -> bool:
	if not is_instance_valid(wheel): return false
	if is_instance_valid(modal_surfaces):modal_surfaces.bind_layer(wheel,wheel)
	if wheel.modal_owner_order!=modal_order or wheel.modal_owner_retire!=retire:
		wheel.set_modal_owner(modal_order,retire)
	return wheel.modal_owner_order==modal_order and wheel.modal_owner_retire==retire
func retire_item_radial(expected_request_id: int) -> bool:
	if closed or not is_instance_valid(inventory) or not is_instance_valid(inventory.item_context): return false
	var wheel=inventory.item_context.wheel
	if not is_instance_valid(wheel) or not wheel.active or wheel.request_id!=expected_request_id: return false
	inventory.item_context.cancel(); return true
func retire_chat_radial(expected_request_id: int) -> bool:
	if closed or not is_instance_valid(chat_skin) or not is_instance_valid(chat_skin.context): return false
	var wheel=chat_skin.context
	if not wheel.active or wheel.request_id!=expected_request_id: return false
	wheel.reset(); return true
func request_startup_table(name: String) -> void:
	# UI rule projection only reads these graphs. Borrow the decoder's immutable
	# source instead of deep-copying aliased physical/keyed/ordered row views at
	# both cache levels. Mutable consumers retain Assets' existing copy default.
	var id: int=assets.request(name,2017,"2da",{"immutable_source":true})
	table_jobs[id]=name; startup_jobs[id]={"name":name,"queued_ms":Time.get_ticks_msec()-startup_at}
func request_network_text_table(name: String) -> void:
	if closed or table_jobs.values().has(name):return
	var id: int=assets.request(name,2017,"2da",{"immutable_source":true})
	if id<0:text.publish_table_error(name,"Native network table request could not be queued: "+name);return
	table_jobs[id]=name
func request_feedback_table(name: String) -> void:
	var id: int=assets.request(name,2017,"2da",{"immutable_source":true})
	if id<0:feedback_table_errors[name]="Native feedback rule request could not be queued: "+name;return
	table_jobs[id]=name;feedback_table_jobs[id]=name
func ensure_feedback_tables(message: Dictionary) -> Dictionary:
	var failure:="";var waiting:=false
	for name in feedback.required_tables(message):
		var source: Variant=text.tables.get(name)
		if source is Dictionary and source.get("orderedRows") is Array:continue
		if feedback_table_errors.has(name):
			if failure.is_empty():failure=str(feedback_table_errors[name])
			continue
		if table_jobs.values().has(name):waiting=true;continue
		request_feedback_table(name);waiting=true
	if not failure.is_empty():return {"ready":false,"failure":failure}
	return {"ready":not waiting}
func mark_hud_started() -> void:
	if not startup_marks.has("hud_presented_ms"): startup_marks.hud_presented_ms=Time.get_ticks_msec()-startup_at
func panel_ready(id: String) -> bool:
	if tables_ready or id in ["options","rest"]: return true
	if id=="map": return hud_ready
	if id=="journal": return hud_ready and tlk_jobs.is_empty()
	if id=="pvp": return hud_ready and tlk_jobs.is_empty() and text.tables.has("classes")
	return false
func startup_snapshot() -> Dictionary:
	var slow:=startup_finished.duplicate(); slow.sort_custom(func(a,b):return float(a.worker_ms)>float(b.worker_ms)); slow=slow.slice(0,6)
	var result:=startup_marks.duplicate()
	result.merge({"gameplay_visible":presentation_enabled,"gameplay_canvas_visible":layer.visible if is_instance_valid(layer) else false,"chat_visible_in_tree":chat.is_visible_in_tree() if is_instance_valid(chat) else false})
	result.merge({"configured_ticks_ms":startup_at,"elapsed_ms":Time.get_ticks_msec()-startup_at,"hud_ready":hud_ready,"tables_ready":tables_ready,"pending_tables":table_jobs.values(),"pending_custom_text":tlk_jobs.size(),"completed_tables":startup_finished.size(),"slowest_tables":slow})
	if is_instance_valid(desktop): result.merge({"party_visible":desktop.party.visible,"quickbar_visible":desktop.quickbar.visible,"party_layout_ready":desktop.party_frame.layout_ready,"quickbar_layout_ready":desktop.quickbar_frame.layout_ready})
	if is_instance_valid(desktop) and desktop.radial.active: result.radial=desktop.radial_diagnostic()
	return result
func set_world(epoch: int,area: int,controlled: int,objects: Array,raw_inventory: Dictionary={},header: Dictionary={}) -> void:
	var began:=Timing.begin()
	if native_connection_query.is_valid():sync_custom_token_connection(native_connection_query.call())
	if generation!=epoch:
		conversation.reset(); examine.reset(); examine_message.clear(); clear_floating();pending_speech_logs.clear();pending_voice_captions.clear()
		if is_instance_valid(timing_view):timing_view.reset()
		if is_instance_valid(chat.native_skin):chat.native_skin.retire_pending_chat()
		feedback_table_errors.clear()
	elif area_id!=area and is_instance_valid(timing_view):timing_view.reset_display()
	Timing.finish("snapshot_ui_reset_ms",began); began=Timing.begin()
	generation=epoch; area_id=area; controlled_id=controlled; text.objects={}
	for object in objects: text.objects[int(object.id)]=object
	text.players.clear()
	for entry in header.get("ui",{}).get("players",[]):
		if entry is Array and entry.size()>=2 and entry[1] is Dictionary:text.players[int(entry[0])]=entry[1]
	sync_tlk_override_header(header)
	if is_instance_valid(timing_view):timing_view.observe(header.get("ui",{}).get("timing"))
	observe_actor_names(header,objects)
	if is_instance_valid(overhead):overhead.observe_sources()
	if is_instance_valid(script_floating):script_floating.observe_sources()
	if is_instance_valid(overhead_popup_registry):overhead_popup_registry.observe(text.objects.keys())
	drain_speech_logs()
	drain_voice_captions()
	Timing.finish("snapshot_ui_object_map_ms",began); began=Timing.begin()
	inventory.set_world(epoch,area,controlled,objects,raw_inventory)
	if is_instance_valid(inventory_windows): inventory_windows.synchronize(epoch,area,controlled,raw_inventory)
	Timing.finish("snapshot_ui_inventory_ms",began); began=Timing.begin()
	desktop.set_world(epoch,area,controlled,text.objects,{"area":header.get("area",{}),"module":header.get("module",{}),"scriptTargeting":header.get("ui",{}).get("scriptTargeting"),"scriptTargetingData":header.get("ui",{}).get("scriptTargetingData"),"spellTargetingOverrides":header.get("ui",{}).get("spellTargetingOverrides",{}),"playerAttitudes":header.get("ui",{}).get("playerAttitudes",[]),"partyInviteNotice":header.get("ui",{}).get("partyInviteNotice"),"partyListRevision":header.get("ui",{}).get("partyListRevision",0),"party":header.get("ui",{}).get("party",[]),"quickbar":header.get("ui",{}).get("quickbar",[]),"players":header.get("ui",{}).get("players",[]),"playerRosterKnown":header.get("ui",{}).get("playerRosterKnown"),"gameMasterPermission":header.get("ui",{}).get("gameMasterPermission"),"journal":header.get("ui",{}).get("journal",{}),"mapPins":header.get("ui",{}).get("mapPins",[])})
	Timing.finish("snapshot_ui_desktop_ms",began)
	if is_instance_valid(gui_panel_access): gui_panel_access.observe_header(header.get("ui",{}).get("guiPanelAccess"))
	barter.set_world(epoch,area,controlled,text.objects,header.get("ui",{}).get("barter",{}))
	examine_skin.sync()
func update_world(epoch: int,area: int,controlled: int,objects: Array,removed: Array,raw_inventory: Dictionary={},header: Dictionary={}) -> void:
	if epoch!=generation or area!=area_id: return
	controlled_id=controlled
	for id in removed: text.objects.erase(int(id))
	for object in objects: text.objects[int(object.id)]=object
	text.players.clear()
	for entry in header.get("ui",{}).get("players",[]):
		if entry is Array and entry.size()>=2 and entry[1] is Dictionary:text.players[int(entry[0])]=entry[1]
	sync_tlk_override_header(header)
	if is_instance_valid(timing_view):timing_view.observe(header.get("ui",{}).get("timing"))
	observe_actor_names(header,objects,removed)
	if is_instance_valid(overhead):overhead.observe_sources(objects.map(func(object):return int(object.id)),removed)
	if is_instance_valid(script_floating):script_floating.observe_sources(objects.map(func(object):return int(object.id)),removed)
	if is_instance_valid(overhead_popup_registry):overhead_popup_registry.observe(objects.map(func(object):return int(object.id)),removed)
	drain_speech_logs()
	drain_voice_captions()
	inventory.update_world(epoch,area,controlled,objects,removed,raw_inventory)
	if is_instance_valid(inventory_windows): inventory_windows.synchronize(epoch,area,controlled,raw_inventory)
	desktop.set_world(epoch,area,controlled,text.objects,{"area":header.get("area",{}),"module":header.get("module",{}),"scriptTargeting":header.get("ui",{}).get("scriptTargeting"),"scriptTargetingData":header.get("ui",{}).get("scriptTargetingData"),"spellTargetingOverrides":header.get("ui",{}).get("spellTargetingOverrides",{}),"playerAttitudes":header.get("ui",{}).get("playerAttitudes",[]),"partyInviteNotice":header.get("ui",{}).get("partyInviteNotice"),"partyListRevision":header.get("ui",{}).get("partyListRevision",0),"party":header.get("ui",{}).get("party",[]),"quickbar":header.get("ui",{}).get("quickbar",[]),"players":header.get("ui",{}).get("players",[]),"playerRosterKnown":header.get("ui",{}).get("playerRosterKnown"),"gameMasterPermission":header.get("ui",{}).get("gameMasterPermission"),"journal":header.get("ui",{}).get("journal",{}),"mapPins":header.get("ui",{}).get("mapPins",[])})
	if is_instance_valid(gui_panel_access): gui_panel_access.observe_header(header.get("ui",{}).get("guiPanelAccess"))
	barter.set_world(epoch,area,controlled,text.objects,header.get("ui",{}).get("barter",{}))
	examine_skin.sync()
func receive_immediate_targeting(epoch: int,area: int,controlled: int,ui_state: Dictionary) -> void:
	if closed or epoch!=generation or area!=area_id or controlled!=controlled_id or not is_instance_valid(desktop):return
	desktop.receive_targeting_state(ui_state)
func receive(message: Dictionary,epoch: int,transport_connection: Variant=null) -> void:
	if closed: return
	if transport_connection!=null and message.get("kind")=="combat-feedback" and preload("res://systems/native_data/overhead_speech_scope.gd").integer(message.get("type"),93,94) and is_instance_valid(script_floating):
		# The native common log tail belongs to the admitted connection, even
		# while its widget's area/creature is unavailable. Never recover an
		# explicit malformed envelope through the weaker legacy queue.
		var received_script: Dictionary=script_floating.receive(message,transport_connection,epoch)
		if not received_script.get("ready",false):stats.stale_messages+=1
		return
	if message.get("kind")=="combat-feedback" and preload("res://systems/native_data/overhead_speech_scope.gd").integer(message.get("type"),93,94) and message.has("nativeTextEvent") and is_instance_valid(script_floating):
		# Native script prompts and their optional log echo do not wait on
		# unrelated menus/tables or enter the legacy combat-floaty renderer.
		var provenance: Variant=message.nativeTextEvent
		if not preload("res://systems/native_data/overhead_speech_scope.gd").valid_header(provenance) or int(provenance.generation)!=epoch:
			stats.stale_messages+=1;return
		if provenance.has("areaId") and provenance.areaId==null:
			# A captured-but-unknown area cannot anchor a widget. Its log still
			# belongs to the already accepted connection and generation.
			var accepted: Variant=native_connection_query.call() if native_connection_query.is_valid() else null
			if not preload("res://systems/native_data/overhead_speech_scope.gd").integer(accepted,0,9007199254740991) or provenance.get("connection")!=accepted:stats.stale_messages+=1;return
		else:script_floating.receive(message);return
	# If provenance capture failed, the Host still forwards the original
	# packet. Preserve its existing log queue; present() suppresses the old
	# widget path for93/94 rather than inventing a source reference.
	# Ordinary overhead speech is independent of inventory/class/feat tables.
	# Keep the unchanged chat-log queue, but publish speech at receipt so cold
	# optional menus cannot postpone it or restart its native GUI-delta timer.
	var speech_receipt: Dictionary={}
	if message.get("kind")=="server-speech":
		speech_receipt=capture_speech_text(message)
		if is_instance_valid(overhead):overhead.receive(message,speech_receipt)
		if not str(message.get("sound","")).is_empty() or bool(message.get("soundFlag",false)):
			text.diagnostics.append({"code":"network.speech-audio-unhandled","reason":"Native server speech audio is not connected","objectId":message.get("objectId"),"soundObjectId":message.get("soundObjectId"),"sound":message.get("sound"),"flag":message.get("soundFlag")})
	if message.get("kind")=="gui-panel-access-event":
		if is_instance_valid(gui_panel_access): gui_panel_access.receive_event(message.get("event"))
		return # Connection-scoped; outer session admission rejects old connections.
	if message.get("kind")=="inventory-window-status":
		if epoch==generation and is_instance_valid(inventory_windows): inventory_windows.observe(message.get("windows",{}))
		return
	if message.get("kind")=="container-status":
		if epoch!=generation:return
		if not bool(message.get("primary",false)):
			text.diagnostics.append({"code":"network.alternate-container-ui-unhandled","reason":"Native alternate container view is not connected","targetId":message.get("targetId")})
			return
		inventory.container_page=0; inventory.signature=""
		if int(message.get("targetId",2130706432))!=2130706432 and not inventory.ui.wanted:inventory.ui.open()
		return
	if message.get("kind")=="store-open":
		if epoch==generation and not inventory.ui.wanted:inventory.ui.open()
		return
	if str(message.kind).begins_with("barter-"):
		if epoch==generation: barter.receive(message)
		if message.kind!="barter-reject": return
	if str(message.kind).begins_with("nui-"): nui.receive(message); return
	if message.kind=="native-action-result":
		if message.get("action","") in ["native-chat","native-chat-party"]:
			if epoch==generation and int(message.get("areaId",-1))==area_id and int(message.get("actorId",-1))==controlled_id:
				if message.get("action","")=="native-chat" and is_instance_valid(chat.native_skin) and chat.native_skin.chat_result(message):return
				if not message.get("accepted",false):chat.append_message({"system":true,"category":"client-notice","text":str(message.get("text","Chat request could not be sent."))})
			return
		if epoch==generation:
			barter.receive(message)
			desktop.receive(message); inventory.receive(message)
			examine_skin.receive(message)
		return
	if message.kind in ["inventory-result","inventory-ack","inventory-command-result","store-transaction","store-close"]:
		if epoch==generation:
			if message.get("inventoryRole","")=="alternate" or bool(message.get("alternate",false)):
				if is_instance_valid(inventory_windows): inventory_windows.receive(message)
			else: inventory.receive(message)
		if epoch==generation: examine_skin.receive(message)
		return
	if message.kind=="custom-token":
		if transport_connection!=null and not sync_custom_token_connection(transport_connection):stats.stale_messages+=1;return
		var value: Variant=message.get("id")
		if not (value is int or value is float) or not is_finite(float(value)) or floor(float(value))!=float(value) or value<-2147483648 or value>2147483647:return
		var bytes: Variant=message.get("textBytes")
		if not bytes is PackedByteArray:
			# Local authored UI callers predate native packet ingress. Their String
			# text enters the same byte owner; admitted wire traffic must carry bytes.
			if transport_connection!=null or not message.get("text") is String:return
			var encoded: Dictionary=preload("res://systems/native_data/native_talk_parser.gd").encode(message.text,text.base.language)
			if not encoded.get("ready",false):return
			bytes=encoded.bytes
		var result: Dictionary=text.apply_server_token(int(value),bytes)
		if result.get("applied",false):floating_text_data_changed()
		return
	if message.kind=="tlk-overrides":
		if transport_connection!=null and not sync_custom_token_connection(transport_connection):stats.stale_messages+=1;return
		if not message.get("entries") is Array:return
		if message.entries.is_empty():return
		for row in message.entries:
			if not row is Dictionary or not row.get("strRef") is int or not row.get("text") is String:return
		for row in message.entries:
			text.set_native_override(int(row.strRef),str(row.text))
		text.mark_changed()
		floating_text_data_changed()
		return
	if queue.size()>=512: stats.errors.append("Native UI protocol queue exceeds bound"); return
	if message.kind=="dialog-entry" and epoch==generation and is_instance_valid(conversation):
		# The old dialog becomes visible with an ellipsis before ParseStr waits.
		conversation.present({"kind":"dialog-entry","speakerId":message.get("speakerId",-1),"rich":{"text":"…"}})
	queue.append({"generation":epoch,"message":message.duplicate(true),"speechText":speech_receipt})
func capture_speech_text(message: Dictionary) -> Dictionary:
	var receipt:=SpeechText.capture(message,text,overhead_context())
	receipt.header=SpeechHeader.capture(message,text,overhead_context())
	if SpeechHeader.native_actor_mode(receipt.header)=="native":
		# Copies a ready stored value, or seals the exact event's pending P
		# publication before the menu queue or a newer raw snapshot can change it.
		SpeechHeader.prepare_name(receipt.header,text,overhead_context(),{},actor_names)
	return receipt
func actor_name_context() -> Dictionary:
	var current:=overhead_context();current.actorNameHistoryComplete=actor_name_history_complete;return current
func observe_actor_names(header: Dictionary,objects: Array,removed: Array=[]) -> void:
	var history: Variant=header.get("actorNameHistory")
	actor_name_history_complete=history is Dictionary and preload("res://systems/native_data/overhead_speech_scope.gd").integer(history.get("version"),1,1) and history.get("complete") is bool and history.complete
	var current:=actor_name_context()
	for id in removed:actor_names.retire(int(id))
	for object in objects:
		if object.get("objectType")==5:actor_names.observe(object,object.get("nativeActorNameState"),text,current)
func overhead_context() -> Dictionary:
	return {"connection":native_connection_query.call() if native_connection_query.is_valid() else null,"generation":generation if generation>=0 else null,"areaId":area_id if area_id>=0 else null,"enabled":not closed and presentation_enabled}
func sync_custom_token_connection(connection: Variant) -> bool:
	if not (connection is int or connection is float) or not is_finite(float(connection)) or floor(float(connection))!=float(connection) or connection<0:return false
	if native_connection_query.is_valid() and native_connection_query.call()!=connection:return false
	if custom_token_connection!=connection:
		text.reset_server_tokens()
		text.reset_native_overrides()
		custom_token_connection=connection
		floating_text_data_changed()
	return true
func sync_tlk_override_header(header: Dictionary) -> void:
	var ui_header: Variant=header.get("ui",{})
	if not ui_header is Dictionary or not ui_header.has("tlkOverrides") or not ui_header.tlkOverrides is Dictionary:return
	var desired: Dictionary=ui_header.tlkOverrides
	if desired==text.overrides:return
	text.reset_native_overrides()
	for ref in desired:
		if desired[ref] is String:text.set_native_override(int(ref),desired[ref])
	if not desired.is_empty():text.mark_changed()
	floating_text_data_changed()
func custom_token_snapshot() -> Dictionary:
	return {"connection":custom_token_connection,"revision":text.server_tokens.revision,"records":text.server_token_snapshot()}
func overhead_source(id: int) -> Dictionary:return text.objects.get(id,{})
func receive_voice_caption(event: Dictionary) -> Dictionary:
	# Quick-chat22/0 has an SSF StrRef but no nativeTextEvent serial. Publish its
	# caption to the existing chat/TLK service; do not fabricate an ordinary
	# overhead speech serial that could suppress later real server speech.
	if closed or not is_instance_valid(chat) or not native_connection_query.is_valid():return {"ready":false,"reason":"Voice caption UI is unavailable."}
	if event.get("connection")!=native_connection_query.call() or int(event.get("generation",-1))!=generation or int(event.get("areaId",-1))!=area_id:return {"ready":false,"retired":true}
	var id: int=int(event.get("actorId",-1));var object: Dictionary=text.objects.get(id,{})
	if object.is_empty() or int(object.get("objectType",0))!=5 or int(object.get("nativeLifetime",-1))!=int(event.get("lifetime",-2)) or bool(object.get("replicationRemoved",false)):return {"ready":false,"retired":true}
	var str_ref: int=int(event.get("strRef",4294967295))
	if str_ref<0 or str_ref==4294967295:return {"ready":false,"reason":"Voice caption string reference is unavailable."}
	if not tlk_jobs.is_empty():
		# A creature voice waits for its caption result before probing and
		# replacing its sound. The voice owner retries this scoped request after
		# TLK completion; do not enqueue a second, unordered UI copy.
		if bool(event.get("waitForCompletion",false)):return {"ready":false,"pending":true}
		if pending_voice_captions.size()<128:pending_voice_captions.append(event.duplicate(true));return {"ready":false,"pending":true}
		return {"ready":false,"reason":"Voice caption queue is full."}
	var body:=text.raw({"strRef":str_ref})
	if body.is_empty():return {"ready":false,"reason":"Voice caption text is unavailable."}
	var name:=text.name(null,id)
	if name.is_empty():name=text.raw({"strRef":5189})
	chat.append_message({"kind":"chat","channel":1,"system":false,"objectId":id,"name":Rich.parse(name),"rich":Rich.parse(body),"text":body,"nativeNameResolved":false})
	return {"ready":true,"actorId":id,"text":body}
func drain_voice_captions() -> void:
	if closed or not tlk_jobs.is_empty() or pending_voice_captions.is_empty():return
	var waiting: Array=pending_voice_captions;pending_voice_captions=[]
	for event in waiting:receive_voice_caption(event)
static func popup_settings_from(value: Dictionary)->Dictionary:
	var cleaned:=preload("res://systems/native_data/chat_preferences.gd").clean(value)
	return {"mode":cleaned["ui.text-bubble-mode"],"largeFont":cleaned["ui.large-font"]}
func popup_settings()->Dictionary:return popup_preferences.duplicate()
func popup_visual_ready(id: int,visual_source: Dictionary,visual_scope: Array)->void:
	if closed or not is_instance_valid(overhead):return
	var current:=overhead_context()
	if visual_scope!=[current.connection,current.generation,current.areaId]:return
	overhead.popup_visual_ready(id,visual_source,visual_scope)
func popup_preferences_changed(value: Dictionary)->void:
	if closed:return
	var next:=popup_settings_from(value)
	if next==popup_preferences:return
	popup_preferences=next
	if is_instance_valid(overhead_popup_registry):overhead_popup_registry.apply_preferences(next)
func popup_name_caption(id: int)->Dictionary:
	return preload("res://systems/native_data/popup_name_cache.gd").capture(text.objects.get(id,{}),text)
func popup_restoration(_id: int,record: Dictionary)->Dictionary:
	# Exact known bypasses of6e9900's CR/relative-level decoration branch.
	# Target stats+90 has no certified received owner; never substitute missing
	# CR with0, appearance data or an Examine-only disclosure.
	if record.cachedRaw.is_empty() or record.cacheOwnerId==0x7f000000 or record.cacheOwnerId==controlled_id:return {"ready":true,"rawBytes":record.cachedRaw,"rich":record.cachedRich}
	return {"ready":false,"reason":"Native CR-relative popup restoration provider is unavailable."}
func overhead_anchor(id: int,witness: Array,scope: Array) -> Dictionary:
	return overhead_anchor_query.call(id,witness,scope) if overhead_anchor_query.is_valid() else {"ready":false}
func script_floating_anchor(id: int,witness: Array,scope: Array,height: float) -> Dictionary:
	return script_floating_anchor_query.call(id,witness,scope,height) if script_floating_anchor_query.is_valid() else {"ready":false}
func script_floating_object_delta(id: int,witness: Array,scope: Array) -> Variant:
	return script_floating_object_delta_query.call(id,witness,scope) if script_floating_object_delta_query.is_valid() else null
func floating_text_data_changed() -> void:
	if is_instance_valid(script_floating):script_floating.data_changed()
	actor_names.data_changed(text,actor_name_context())
	drain_speech_logs()
func overhead_claims_nameplate(id: int,row: Dictionary,caption: Dictionary={}) -> bool:
	if not is_instance_valid(overhead):return false
	if not caption.is_empty():overhead.update_owner_caption(id,preload("res://systems/native_data/overhead_speech_anchor.gd").witness(row),caption)
	if is_instance_valid(overhead_popup_registry) and overhead_popup_registry.has_method("hover_blocked"):return overhead_popup_registry.hover_blocked(id,row)
	return overhead.has_popup(id,row)
func native_female_absent(recorded: bool,key: String,path: String)->bool:
	if not path.is_empty():return not FileAccess.file_exists(path)
	if not recorded:return true # Explicitly no file path and no resource candidate.
	# Recorded path lookup can also fail hash validation. A present manifest
	# entry with an unreadable body is not proof of absence and must not alias.
	var manifest: Variant=catalog.get("manifest")
	if not manifest is Dictionary or not manifest.get("talk") is Dictionary:return false
	var primary: String="custom" if key=="custom_female" else "base"
	return manifest.talk.has(primary) and not manifest.talk.has(key)
func publish_custom_native_family()->void:
	if custom_tlk_requested and tlk_jobs.is_empty() and not custom_tlk_load_failed and custom_tlk_primary_loaded and (custom_tlk_female_absent or custom_tlk_female_loaded):text.publish_native_family(true,custom_tlk_female_absent)
func prepared(id: int,result: Dictionary) -> void:
	if closed: return
	if examine_jobs.has(id):
		var name:=str(examine_jobs[id]); examine_jobs.erase(id); examine_pending.erase(name)
		if not str(result.error).is_empty(): stats.errors.append({"resource":name,"reason":result.error}); text.publish_table_error(name,str(result.error))
		else: text.publish_table(name,result.value)
		refresh_examine_properties(); return
	if tlk_jobs.has(id):
		var female: bool=tlk_jobs[id]; tlk_jobs.erase(id)
		var target=text.custom_female if female else text.custom
		if not str(result.error).is_empty():custom_tlk_load_failed=true;stats.errors.append(result.error)
		elif not target.open_bytes(result.bytes):custom_tlk_load_failed=true;stats.errors.append(target.failure)
		elif female:custom_tlk_female_loaded=true
		else:custom_tlk_primary_loaded=true
		publish_custom_native_family()
		text.mark_changed()
		floating_text_data_changed()
		if is_instance_valid(desktop): desktop.signatures.erase("party"); desktop.dirty=true
		if is_instance_valid(gui_panel_access): gui_panel_access.drain()
		return
	if table_jobs.has(id):
		var name:=str(table_jobs[id]); table_jobs.erase(id)
		if feedback_table_jobs.has(id):
			feedback_table_jobs.erase(id)
			if not str(result.error).is_empty():feedback_table_errors[name]=str(result.error)
			else:feedback_table_errors.erase(name)
		if startup_jobs.has(id):
			var row: Dictionary=startup_jobs[id]; startup_jobs.erase(id)
			row.merge({"completed_ms":Time.get_ticks_msec()-startup_at,"worker_ms":float(result.get("worker_ms",0)),"read_ms":float(result.get("read_ms",0)),"queue_ms":float(result.get("phases",{}).get("service_queue_ms",0)),"decode_ms":float(result.get("timings",{}).get("decode_ms",0)),"memory_decode_hit":bool(result.get("memory_decode_hit",false)),"bytes":result.get("bytes",PackedByteArray()).size(),"error":str(result.get("error",""))}); startup_finished.append(row)
		if not str(result.error).is_empty():
			stats.errors.append({"resource":name,"reason":result.error})
			if name=="effecticons":text.diagnostics.append({"code":"network.effect-icons-table-unavailable","reason":str(result.error)})
			text.publish_table_error(name,str(result.error))
		else: text.publish_table(name,result.value)
		if name=="portraits" and not examine_portrait_waiting.is_empty():
			var waiting: Dictionary=examine_portrait_waiting.duplicate(true)
			examine_portrait_waiting.clear()
			start_examine_portrait(waiting.message,int(waiting.revision))
		floating_text_data_changed()
		if is_instance_valid(desktop): desktop.ability_table_ready()
		if is_instance_valid(gui_panel_access): gui_panel_access.drain()
		return
	if not portrait_jobs.has(id): return
	var job: Dictionary=portrait_jobs[id]; portrait_jobs.erase(id)
	if int(job.generation)!=generation or not examine.visible and not examine.admission_pending or int(examine.state.get("revision",-1))!=int(job.revision): return
	if not str(result.error).is_empty(): request_examine_portrait(job.remaining,int(job.target),int(job.revision),str(job.base),str(result.error)); return
	var texture=pool.texture(result)
	if texture==null: request_examine_portrait(job.remaining,int(job.target),int(job.revision),str(job.base),pool.failure); return
	portrait_textures[str(job.name)]=texture
	if examine.set_native_portrait(preload("res://systems/native_ui_art.gd").portrait_texture(texture),int(job.target),int(job.revision)):
		examine.portrait.flip_v=true; stats.portraits+=1
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_ui",began)
func _profile_process(delta: float) -> void:
	if closed: return
	update_floating(delta)
	if not bindings_installed and not table_jobs.values().has("keymap"):
		key_bindings.install(text.tables.get("keymap",{}),text.base.language); bindings_installed=true; startup_marks.bindings_ready_ms=Time.get_ticks_msec()-startup_at
	if not hud_ready and not HUD_TABLES.any(func(name):return table_jobs.values().has(name)):
		text.import_tokens(); hud_ready=true; startup_marks.hud_rules_ready_ms=Time.get_ticks_msec()-startup_at
		floating_text_data_changed()
		if is_instance_valid(desktop): desktop.dirty=true
		if is_instance_valid(gui_panel_access): gui_panel_access.drain()
	if not table_jobs.is_empty() or not tlk_jobs.is_empty(): return
	drain_voice_captions()
	if not tables_ready:
		tables_ready=true; startup_marks.all_rules_ready_ms=Time.get_ticks_msec()-startup_at; barter.refresh()
		if is_instance_valid(desktop): desktop.signatures.erase("party"); desktop.dirty=true
		if is_instance_valid(gui_panel_access): gui_panel_access.drain()
	if speech_text_revision!=text.revision:
		speech_text_revision=text.revision;actor_names.data_changed(text,actor_name_context());drain_speech_logs()
	if queue.is_empty() or int(queue[0].generation)>generation: return
	var pending: Dictionary=queue[0]
	var text_preflight: Dictionary=preflight_network_text(pending.message)
	if text_preflight.get("pending",false):return
	if text_preflight.has("error"):
		queue.pop_front();stats.errors.append({"code":"network.text-presentation-failed","reason":text_preflight.error,"kind":pending.message.get("kind")});return
	if str(pending.message.get("kind","")) in ["combat-feedback","spell-feedback","attack-feedback","damage-feedback","initiative-feedback"]:
		var feedback_rules:=ensure_feedback_tables(pending.message)
		if feedback_rules.has("failure"):
			queue.pop_front()
			feedback.report_failure(pending.message,str(feedback_rules.failure))
			stats.errors.append({"code":"network.feedback-presentation-failed","reason":feedback_rules.failure})
			return
		if not feedback_rules.ready:return
	var next: Dictionary=queue.pop_front()
	if int(next.generation)!=generation: stats.stale_messages+=1; return
	present(next.message,next.get("speechText",{})); stats.messages+=1
func preflight_network_text(message: Dictionary) -> Dictionary:
	# NetworkText.resolve waited for StringTokens/rule promises before an old
	# frontend callback could complete. Keep the received UI message queued
	# while the corresponding Godot resource request is outstanding.
	var kind: String=str(message.get("kind",""))
	if kind=="system-notice":
		var notice_options: Dictionary={"playerId":message.get("playerId",0),"nativeB8":0}
		if message.has("playerName"):notice_options.playerName=message.playerName
		var prefix: Dictionary=text.network_resolve({"strRef":int(message.get("strRef",4294967295))},2130706432,notice_options)
		if not prefix.get("ready",false):return prefix
		if str(message.get("category",""))=="journal":
			var title: Dictionary=text.network_resolve(message.get("title"),2130706432)
			if not title.get("ready",false):return title
		return {"ready":true}
	var values: Array=[];var context:=int(message.get("tokenObjectId",controlled_id))
	match kind:
		"dialog-entry":values.append(message.get("text"))
		"dialog-replies":
			for row in message.get("replies",[]):
				if row is Dictionary:values.append(row.get("text"))
		"barter-reject":
			if int(message.get("operation",0))==1:
				var ref: int={1:0x1a8a,2:0x1a8b,3:0x1a8c,4:0x1a8d,5:0x2848,6:0x107cb}.get(int(message.get("reason",0)),1)
				values.append({"strRef":ref});context=int(message.get("targetId",context))
		"examine":
			context=int(message.get("targetId",context))
			var examine_name_value: Variant=message.get("name")
			if examine_name_value==null:
				var examined: Dictionary=text.objects.get(context,{})
				for source in ["item","replicated","appearance","staticState"]:
					var component: Dictionary=examined.get(source,{})
					if component.has("name"):
						examine_name_value=component.name
						break
			if examine_name_value is Dictionary and examine_name_value.has("firstName"):
				values.append(examine_name_value.get("firstName"))
				values.append(examine_name_value.get("lastName"))
			elif examine_name_value!=null:values.append(examine_name_value)
			if message.has("description"):values.append(message.description)
		"combat-feedback","spell-feedback","attack-feedback","damage-feedback","initiative-feedback":
			# Feedback generates the final TLK reference during formatting; its
			# table must be available before the queued format callback runs.
			if not text.tables.has("stringtokens"):
				var token_table: Dictionary=text.network_table("stringtokens")
				if not token_table.get("ready",false):return token_table
		_:
			if message.has("text") and kind!="server-speech":values.append(message.text)
	for value in values:
		var source: String=text.raw(value)
		if not source.contains("<"):continue
		var resolved: Dictionary=text.network_resolve(value,context,{"nativeB8":0} if kind in ["dialog-entry","dialog-replies"] else {})
		if not resolved.get("ready",false):return resolved
	return {"ready":true}
func speech(message: Dictionary,receipt: Dictionary={}) -> Dictionary:
	var channel:=int(message.channel)
	if channel==7: return {}
	var system:=channel in [5,15]; var object: Dictionary=text.objects.get(int(message.get("objectId",-1)),{})
	var remote:=channel>=0 and channel<31 and ((0x401e4054>>channel)&1)!=0
	if receipt.is_empty():receipt=capture_speech_text(message)
	if not receipt.has("header"):receipt.header=SpeechHeader.capture(message,text,overhead_context())
	if object.is_empty() and not system and channel not in [11,12] and not remote and SpeechHeader.native_actor_mode(receipt.header)=="legacy":return {}
	var context:=int(message.get("contextId",controlled_id));var raw: String
	if channel in SpeechText.CHANNELS:
		if receipt.is_empty():receipt=SpeechText.capture(message,text,overhead_context())
		var resolved:=SpeechText.prepare(receipt,text,overhead_context(),true)
		if not resolved.get("ready",false):return {"pending":true} if resolved.get("pending",false) else {}
		raw=str(resolved.body)
	elif channel in [1,2,3,4,5,6,14,17,18,19,20,22,30]:raw=text.raw(message.text,0) # Native literal body; font markup is parsed below, not ParseStr.
	else:raw=text.resolve(message.text,context)
	if raw.is_empty(): return {}
	# Callers of the older body-only receipt API have no captured header yet.
	# Actual receive() captures both at the same boundary before any queue.
	var header_state: Dictionary={}
	if channel in SpeechText.LOCALIZED:
		header_state={"nativeB8":0,"nativeBC":0}
		if receipt.has("context"):header_state.context=receipt.context
	var name:=""
	var native_name_resolved:=false
	if not system and (remote and message.has("speakerName") or SpeechHeader.native_actor_mode(receipt.header)!="legacy"):
		var named:=SpeechHeader.prepare_name(receipt.header,text,overhead_context(),header_state,actor_names)
		if not named.get("ready",false):return {"pending":true} if named.get("pending",false) else {}
		name=str(named.name);native_name_resolved=true
	elif not system:
		# Canonical actor stored-name provenance is a separate remaining port:
		# U/party labels are not proof of stats+40 or P/actor cached bytes.
		name=text.name(null,int(message.get("objectId",-1)))
	if not system and name.is_empty():name=text.raw({"strRef":5189})
	# Receiver name selection precedes the channel-label fetch. Base labels
	# use gender0/parseFlag0; only runtime overrides invoke native ParseStr.
	var prepared_prefix:=SpeechHeader.prepare_prefix(receipt.header,text,overhead_context(),header_state)
	if not prepared_prefix.get("ready",false):return {"pending":true} if prepared_prefix.get("pending",false) else {}
	var prefix:=str(prepared_prefix.prefix)
	if channel in [14,30] and not prefix.is_empty(): prefix="["+prefix+"] "
	var result:={"kind":"chat","channel":channel,"system":system,"objectId":message.get("objectId",-1),"contextId":message.get("contextId"),"position":message.get("position"),"name":Rich.parse(name),"rich":Rich.parse(prefix+raw),"text":Rich.parse(raw).text,"nativeNameResolved":native_name_resolved}
	if not system and not name.is_empty():
		var reply: Dictionary=preload("res://systems/native_data/chat_reply.gd").presentation(int(message.get("objectId",-1)),text.objects,desktop.state.get("players",[]) if is_instance_valid(desktop) else [],text)
		if not reply.is_empty():result.reply=reply
	return result
func drain_speech_logs() -> void:
	if closed or pending_speech_logs.is_empty() or not table_jobs.is_empty() or not tlk_jobs.is_empty():return
	var waiting: Array=pending_speech_logs;pending_speech_logs=[]
	for entry in waiting:
		if int(entry.generation)!=generation or entry.connection!=overhead_context().connection:continue
		var row:=speech(entry.message,entry.receipt)
		if row.get("pending",false):pending_speech_logs.append(entry)
		elif not row.is_empty():chat.append_message(row);stats.speech+=1
func floating_f(value: float) -> float:
	return Vector2(value,0.0).x
func clear_floating() -> void:
	for row in floating_rows:
		if is_instance_valid(row.get("node")): row.node.queue_free()
		if is_instance_valid(row.get("shadow_node")): row.shadow_node.queue_free()
	floating_rows.clear();floating_font_reported.clear()
func report_floating_font_failure(name: String) -> void:
	var font_owner=inventory.frame_skin.fonts if is_instance_valid(inventory.frame_skin) else null
	if font_owner==null or not font_owner.failed.has(name) or floating_font_reported.has(name):return
	floating_font_reported[name]=true
	stats.errors.append({"code":"network.floating-font-failed","reason":str(font_owner.failed[name]),"font":name})
func add_floating(row: Dictionary) -> void:
	var font_name: String=str(row.get("font",""))
	if font_name.is_empty():font_name="fnt_galahad14"
	if is_instance_valid(inventory.frame_skin):inventory.frame_skin.fonts.request(font_name)
	var rgb: Array=row.get("rgb",[1,1,1])
	floating_rows.append({"id":int(row.objectId),"areaId":area_id,"node":null,"shadow_node":null,"font_failed":false,"font":font_name,"duration":floating_f(1.5),"remaining":floating_f(1.5),"rgb":rgb.duplicate(),"shadow":int(row.get("flags",0))!=0,"visible":false,"opacity":1.0,"raw":str(row.get("raw",""))})
func floating_rgb(rgb: Array) -> String:
	var color:="#"
	for index in 3:
		var value:=float(rgb[index]) if index<rgb.size() else 1.0
		color+="%02x"%int(floorf(clampf(value,0.0,1.0)*255.0+0.5))
	return color
func make_floating_bitmap(row: Dictionary) -> void:
	var owner=inventory.frame_skin.fonts
	if not owner.fonts.has(str(row.font)) or not owner.atlases.has(str(row.font)):return
	var spans: Array=Rich.parse(str(row.raw)).spans
	var default_color:=floating_rgb(row.rgb)
	var layout: Dictionary=owner.render_bitmap(str(row.font),spans,default_color)
	if layout.has("error"):
		stats.errors.append({"code":"network.floating-font-failed","reason":str(layout.error),"font":str(row.font)})
		row.font_failed=true
		return
	var node:=preload("res://systems/native_floating_bitmap_glyphs.gd").new()
	node.configure(owner,str(row.font),layout)
	if not node.failure.is_empty():
		stats.errors.append({"code":"network.floating-font-failed","reason":node.failure,"font":str(row.font)})
		row.font_failed=true
		node.queue_free();return
	node.hide();controls.add_child(node);row.node=node;row.baseline=float(layout.baseline)
	if int(layout.missing)>0:stats.errors.append({"code":"network.floating-glyph-unavailable","reason":"Native bitmap font has no glyph for some text bytes","font":str(row.font),"count":int(layout.missing)})
	if bool(row.shadow):
		var black_spans: Array=[]
		for span in spans:black_spans.append({"text":span.text,"color":"#000000"})
		var shadow_layout: Dictionary=owner.render_bitmap(str(row.font),black_spans,"#000000")
		if shadow_layout.has("error"):
			stats.errors.append({"code":"network.floating-font-failed","reason":str(shadow_layout.error),"font":str(row.font)})
			return
		var shadow:=preload("res://systems/native_floating_bitmap_glyphs.gd").new()
		shadow.configure(owner,str(row.font),shadow_layout)
		if not shadow.failure.is_empty():
			stats.errors.append({"code":"network.floating-font-failed","reason":shadow.failure,"font":str(row.font)})
			shadow.queue_free();return
		shadow.hide();controls.add_child(shadow);controls.move_child(shadow,node.get_index());row.shadow_node=shadow
func update_floating(delta: float) -> void:
	if not is_instance_valid(world_camera):return
	var step: float=floating_f(delta)
	if not is_finite(step) or step<0.0:
		for row in floating_rows:
			if is_instance_valid(row.get("node")):row.node.queue_free()
			if is_instance_valid(row.get("shadow_node")):row.shadow_node.queue_free()
			stats.errors.append({"code":"network.floating-presentation-failed","reason":"Native floating-text frame delta is invalid","objectId":int(row.id)})
		floating_rows.clear()
		return
	for font_name in ["fnt_floaty_smal","fnt_galahad14"]:report_floating_font_failure(font_name)
	for index in range(floating_rows.size()-1,-1,-1):
		var row: Dictionary=floating_rows[index]; var remaining: float=float(row.remaining)
		if int(row.get("areaId",-1))!=area_id:
			if is_instance_valid(row.get("node")):row.node.queue_free()
			if is_instance_valid(row.get("shadow_node")):row.shadow_node.queue_free()
			floating_rows.remove_at(index);continue
		report_floating_font_failure(str(row.font))
		if step>=remaining:
			if is_instance_valid(row.get("node")):row.node.queue_free()
			if is_instance_valid(row.get("shadow_node")):row.shadow_node.queue_free()
			floating_rows.remove_at(index);continue
		if not is_instance_valid(row.get("node")) and not bool(row.get("font_failed",false)):make_floating_bitmap(row)
		var height: float=floating_f(floating_f(floating_f(float(row.duration)-remaining)*floating_f(0.5))+floating_f(2.0))
		var actor: Dictionary=text.objects.get(int(row.id),{})
		var model: Node3D=world_registry.native_owners.get(int(row.id)) if is_instance_valid(world_registry) else null
		if is_instance_valid(model) and not actor.get("replicationRemoved",false) and int(actor.get("areaId",-1))==area_id:
			var model_position: Vector3=model.global_position
			var point:=Vector3(model_position.x,floating_f(height+model_position.y),model_position.z)
			row.visible=not world_camera.is_position_behind(point)
			var screen:=world_camera.unproject_position(point)
			if is_instance_valid(row.get("node")):
				row.node.position=Vector2(int(floating_f(screen.x+floating_f(0.5)))-row.node.size.x*0.5,int(floating_f(screen.y+floating_f(0.5)))-float(row.baseline))
			row.opacity=1.0 if remaining>=0.5 else floating_f(remaining+remaining)
		if is_instance_valid(row.get("node")):
			row.node.visible=bool(row.visible)
			row.node.modulate.a=float(row.opacity)
		if is_instance_valid(row.get("shadow_node")):
			row.shadow_node.visible=bool(row.visible)
			row.shadow_node.position=row.node.position-Vector2.ONE
			row.shadow_node.modulate.a=float(row.opacity)
		row.remaining=floating_f(remaining-step)
func present(message: Dictionary,speech_receipt: Dictionary={}) -> void:
	match str(message.kind):
		"system-notice":present_system_notice(message)
		"barter-reject":
			if int(message.operation)==1:
				var ref: int={1:0x1a8a,2:0x1a8b,3:0x1a8c,4:0x1a8d,5:0x2848,6:0x107cb}.get(int(message.reason),1)
				var rich:=Rich.parse(text.resolve({"strRef":ref},int(message.targetId),{"nativeB8":1}))
				chat.append_message({"category":"barter-reject","system":true,"color":"#ffff00","rich":rich,"text":rich.text,"targetId":int(message.targetId),"operation":int(message.operation),"reason":int(message.reason)})
		"combat-feedback","spell-feedback","attack-feedback","damage-feedback","initiative-feedback":
			feedback.controlled=controlled_id
			for row in feedback.format(message): chat.append_message(row)
			if message.kind=="combat-feedback" and int(message.get("type",-1)) in [93,94]:feedback.floating.clear()
			else:
				for row in feedback.floating: add_floating(row)
			for resource in feedback.sounds: gui_sound_requested.emit(str(resource))
		"server-speech":
			var row:=speech(message,speech_receipt)
			if row.get("pending",false):
				if pending_speech_logs.size()<512:pending_speech_logs.append({"generation":generation,"connection":overhead_context().connection,"message":message.duplicate(true),"receipt":speech_receipt if not speech_receipt.is_empty() else capture_speech_text(message)})
			elif not row.is_empty(): chat.append_message(row); stats.speech+=1
		"dialog-close": conversation.reset()
		"dialog-entry":
			var row:=message.duplicate(true); row.rich=Rich.parse(text.resolve(message.text,int(message.tokenObjectId),{"nativeB8":0})); conversation.present(row); stats.dialogs+=1
		"dialog-replies":
			var choices: Array=message.replies if not message.replies.is_empty() else [{"id":4294967295,"text":{"text":""}}]; var replies: Array=[]
			for index in choices.size():
				var row: Dictionary=choices[index]
				var label:=text.resolve(row.text,int(message.tokenObjectId),{"nativeB8":0})
				if label.is_empty(): label=text.resolve({"strRef":0x6ce if bool(message.end) or message.replies.is_empty() else 0x6cd,"gender":0},int(message.tokenObjectId))
				replies.append({"id":row.id,"rich":Rich.parse(label),"available":true})
			conversation.present({"kind":"dialog-replies","entryId":message.entryId,"end":message.end,"replies":replies}); stats.dialogs+=1
		"dialog-selected": text.diagnostics.append({"code":"network.dialog-selected-unhandled","reason":"Selected multiplayer reply transcript presentation is not connected"})
		"examine": present_examine(message)
		"dialog-error": conversation.present(message)
func present_system_notice(message: Dictionary) -> void:
	var options: Dictionary={"playerId":message.get("playerId",0),"nativeB8":0}
	if message.has("playerName"):options.playerName=message.playerName
	var prefix: String=text.resolve({"strRef":int(message.get("strRef",4294967295))},2130706432,options)
	var content: String=prefix
	if str(message.get("category",""))=="journal":content+=" "+text.resolve(message.get("title"),2130706432)
	else:content+=str(message.get("suffix",""))
	var rich: Dictionary=Rich.parse(content)
	chat.append_message({"system":true,"category":str(message.get("category","")),"text":str(rich.text),"rich":rich,"color":str(message.get("color","")),"playerId":message.get("playerId")})
	if str(message.get("category",""))=="journal":
		if is_instance_valid(desktop) and is_instance_valid(desktop.party):desktop.party.encourage("journal")
		if not str(message.get("sound","")).is_empty():gui_sound_requested.emit(str(message.sound))
func examine_name(message: Dictionary,id: int) -> String:
	var supplied: Variant=message.get("name")
	if supplied is Dictionary and supplied.has("text"):
		return text.resolve(supplied,id,{"nativeB8":0})
	if supplied is Dictionary and not str(supplied.get("firstName","")).is_empty():
		return (text.resolve(supplied.firstName,id,{"nativeB8":0})+" "+text.resolve(supplied.get("lastName"),id,{"nativeB8":0})).strip_edges()
	var object: Dictionary=text.objects.get(id,{})
	var name: Variant=null
	for key in ["item","replicated","appearance","staticState"]:
		var source: Dictionary=object.get(key,{})
		if source.has("name"):
			name=source.name
			break
	if name is Dictionary and not str(name.get("firstName","")).is_empty():
		return (text.resolve(name.firstName,id,{"nativeB8":0})+" "+text.resolve(name.get("lastName"),id,{"nativeB8":0})).strip_edges()
	if name==null or name is String and name.is_empty(): return "Examine"
	return text.resolve(name,id,{"nativeB8":0})
func present_examine(message: Dictionary) -> void:
	revision+=1
	examine_portrait_waiting.clear()
	examine_message=message.duplicate(true)
	inventory.receive(message)
	var id:=int(message.targetId); var output:={"kind":"examine","type":message.type,"identified":bool(message.get("identified",true)),"targetId":id,"revision":revision,"name":Rich.parse(examine_name(message,id)),"warnings":[],"facts":[],"properties":[],"effects":[],"effectCount":message.get("effects",[]).size()}
	output.close=bool(message.get("close",false)) or (message.type=="trap" and not message.get("success",false))
	if output.close:
		examine.present(output); stats.examines+=1; return
	if message.has("description"): output.description=Rich.parse(text.resolve(message.description,id,{"nativeB8":0}))
	if message.type=="item":
		output.propertyHeading=Rich.parse("Item properties"); output.propertyCount=message.get("properties",[]).size()
		var item: Dictionary=text.objects.get(id,{}).get("item",{})
		if item.has("baseItem"): output.facts.append({"name":"Item type","rich":Rich.parse(text.label("baseitems",int(item.baseItem)))})
		if bool(message.get("identified",false)) and int(message.get("charges",0))>0: output.facts.append({"name":"Charges","rich":Rich.parse(Numbers.text(message.charges))})
		output.facts.append({"name":"Weight","rich":Rich.parse(Numbers.tenths(message.weight) if message.has("weight") else "NaN")})
		if message.has("value"): output.facts.append({"name":"Value","rich":Rich.parse(Numbers.text(message.value))})
		if not bool(message.get("identified",false)): output.facts.append({"name":"Identification","rich":Rich.parse("Unidentified")})
		if message.has("canUse") and not message.canUse: output.facts.append({"name":"Use","rich":Rich.parse("Cannot use")})
		if message.has("minimumLevel"): output.facts.append({"name":"Required level","rich":Rich.parse(Numbers.text(message.minimumLevel))})
	if message.type=="creature" and message.get("hasDetails",false):
		output.condition=Rich.parse(text.label("damagelevels",int(message.damageLevel),"STRING_REF"))
		if int(message.reaction)>=0 and int(message.reaction)<=2: output.reaction=text.rich({"strRef":[0x1918,0x1919,0x1917][int(message.reaction)]},id)
		if message.has("challengeRating"): output.facts.append({"name":"Challenge Rating","rich":Rich.parse(Numbers.text(message.challengeRating))})
		if message.has("playerLevel"): output.facts.append({"name":"Level","rich":Rich.parse(Numbers.text(message.playerLevel))})
	var properties: Variant=message.get("properties",[])
	if properties is Array and not properties.is_empty():
		var details:=ItemPropertyText.project(properties,text,int(message.get("actorId",controlled_id)))
		for name in details.missing:
			if not text.network_table_errors.has(name):continue
			details.warnings.erase("Loading item properties…")
			if not details.warnings.has("Some examination details could not be loaded."):details.warnings.append("Some examination details could not be loaded.")
			break
		output.properties=details.properties; output.warnings=details.warnings
		if details.failed:stats.errors.append({"code":"network.examine-detail-unavailable","targetId":id,"reason":"Native item property GameStrRef is unavailable"})
	if output.warnings.is_empty() or str(output.warnings.back())!="Some examination details could not be loaded.":
		for effect in message.get("effects",[]):
			var label:=text.label("effecticons",int(effect),"StrRef")
			if not label.is_empty(): output.effects.append(Rich.parse(label))
		if message.type=="trap":
			output.facts.append({"name":"Trap","rich":Rich.parse(text.label("traps",int(message.get("trapType",-1)),"TrapName"))})
			if int(message.get("assessment",5))<=4:
				output.facts.append({"name":"Assessment","rich":Rich.parse(text.resolve({"strRef":0xcf98-int(message.assessment)},id))})
	else:output.effectCount=0
	examine.present(output); stats.examines+=1
	if not output.close: request_examine_tables()
	var portrait_value: Variant=message.get("portraitId")
	if message.type!="creature" or not message.get("hasDetails",false) or not (portrait_value is int or portrait_value is float and is_finite(portrait_value) and floorf(portrait_value)==portrait_value): return
	start_examine_portrait(message,revision)
func start_examine_portrait(message: Dictionary,request_revision: int) -> void:
	if request_revision!=revision or examine_message.get("targetId")!=message.get("targetId") or not examine.visible and not examine.admission_pending:return
	var portrait_id:=int(message.get("portraitId",65534));var base: String=""
	if portrait_id<65534:
		var table: Dictionary=text.network_table("portraits")
		if table.get("pending",false):examine_portrait_waiting={"message":message.duplicate(true),"revision":request_revision};return
		if not table.get("ready",false):
			stats.errors.append({"code":"network.examine-portrait-unavailable","targetId":int(message.targetId),"reason":str(table.get("error","Native portraits table is unavailable"))})
			return
		var rows: Array=text.tables.get("portraits",{}).get("orderedRows",[])
		if portrait_id<0 or portrait_id>=rows.size() or not rows[portrait_id] is Dictionary:return
		base="po_"+str(rows[portrait_id].get("BaseResRef",""))
	else:base=str(message.get("portrait",""))
	if base.is_empty() or base.ends_with("****"):return
	request_examine_portrait(preload("res://systems/native_data/portrait_resources.gd").candidates(base,3),int(message.targetId),request_revision,base)
func request_examine_portrait(names: Array,target_id: int,request_revision: int,base: String,failure: String="") -> void:
	if not examine.visible and not examine.admission_pending or int(examine.state.get("revision",-1))!=request_revision: return
	for index in names.size():
		var name: String=str(names[index])
		if portrait_textures.has(name):
			if examine.set_native_portrait(preload("res://systems/native_ui_art.gd").portrait_texture(portrait_textures[name]),target_id,request_revision):
				examine.portrait.flip_v=true; stats.portraits+=1
			return
		var location: Dictionary=catalog.raster_location(name)
		if location.is_empty(): continue
		var job: int=assets.request(name,int(location.type),"raster")
		if job<0: continue
		portrait_jobs[job]={"name":name,"base":base,"remaining":names.slice(index+1),"target":target_id,"revision":request_revision,"generation":generation}
		return
	stats.errors.append({"code":"network.portrait-unavailable","objectId":target_id,"resource":base,"size":3,"reason":failure if not failure.is_empty() else "Native portrait is unavailable"})
func request_examine_tables() -> void:
	if examine_message.get("properties",[]) is not Array or examine_message.get("properties",[]).is_empty() or not examine.visible: return
	var requested:=0
	for name in ItemPropertyText.dependencies(examine_message.get("properties",[]),text.tables):
		if text.network_table_errors.has(name): continue
		if examine_pending.has(name): continue
		if requested>=8: break
		var job: int=assets.request(name,2017,"2da")
		if job<0: stats.errors.append({"resource":name,"reason":assets.failure}); text.publish_table_error(name,assets.failure); continue
		examine_jobs[job]=name; examine_pending[name]=true; requested+=1
func refresh_examine_properties() -> void:
	if examine_message.get("properties",[]) is not Array or examine_message.get("properties",[]).is_empty() or not examine.visible: return
	var details:=ItemPropertyText.project(examine_message.get("properties",[]),text,int(examine_message.get("actorId",controlled_id)))
	for name in details.missing:
		if not text.network_table_errors.has(name):continue
		details.warnings.erase("Loading item properties…")
		if not details.warnings.has("Some examination details could not be loaded."):details.warnings.append("Some examination details could not be loaded.")
		break
	if (details.failed or details.warnings.has("Some examination details could not be loaded.")) and not examine.state.is_empty():
		examine.state.effects=[]
		examine.state.effectCount=0
	if examine.refresh_properties(details.properties,details.warnings,int(examine_message.targetId),revision): request_examine_tables()
func blocks_pointer(point: Vector2) -> bool:
	if closed or not presentation_enabled: return false
	if is_instance_valid(barter) and barter.blocks_pointer(point): return true
	if is_instance_valid(nui) and nui.blocks_pointer(point): return true
	if is_instance_valid(desktop) and desktop.blocks_pointer(point): return true
	if is_instance_valid(inventory) and inventory.blocks_pointer(point): return true
	if is_instance_valid(inventory_windows) and inventory_windows.blocks_pointer(point): return true
	if is_instance_valid(chat) and chat.blocks_pointer(point): return true
	for control in [conversation,examine]:
		if is_instance_valid(control) and control.visible and control.get_global_rect().has_point(point): return true
	return false
func active_network_radial() -> bool:
	if is_instance_valid(desktop) and is_instance_valid(desktop.radial) and desktop.radial.active:return true
	if is_instance_valid(inventory) and is_instance_valid(inventory.item_context) and is_instance_valid(inventory.item_context.wheel) and inventory.item_context.wheel.active:return true
	return is_instance_valid(chat_skin) and is_instance_valid(chat_skin.context) and chat_skin.context.active
func blocks_world_pointer_globally() -> bool:
	# In normal network play GameUi.detach has no local panel; its remaining
	# blocksWorldInput source is the creator's externalCapture. RadialMenu.active
	# blocks both highlight and pointer picks regardless of cursor position.
	return is_instance_valid(creator) and creator.phase!="closed" or active_network_radial()
func can_focus_network_chat() -> bool:
	# src/main.js:2643:570 supplies this exact NetworkSpeechView gate.
	if closed or not chat_focus_phase_query.is_valid() or not bool(chat_focus_phase_query.call()):return false
	if is_instance_valid(conversation) and conversation.opened:return false
	if is_instance_valid(inventory) and is_instance_valid(inventory.ui) and inventory.ui.wanted:return false
	if active_network_radial():return false
	if is_instance_valid(desktop):
		for panel in [desktop.sheet,desktop.book,desktop.journal,desktop.area_map,desktop.players,desktop.level_up]:
			if is_instance_valid(panel) and (panel.wanted or panel.visible):return false
	return true
func blocks_quickbar_activation() -> bool:
	# src/main.js:2633 canUse excludes these multiplayer windows. The
	# onVisibility OrbitControls flag is disconnected during network play.
	if closed or not presentation_enabled:return false
	if is_instance_valid(creator) and creator.phase!="closed":return true
	if is_instance_valid(conversation) and conversation.visible:return true
	if is_instance_valid(inventory) and is_instance_valid(inventory.ui) and inventory.ui.wanted:return true
	if not is_instance_valid(desktop):return false
	if is_instance_valid(desktop.radial) and desktop.radial.active:return true
	for panel in [desktop.sheet,desktop.book,desktop.journal,desktop.area_map,desktop.players,desktop.level_up]:
		if is_instance_valid(panel) and panel.visible:return true
	return false
func _unhandled_key_input(event: InputEvent) -> void:
	if not presentation_enabled: return
	if is_instance_valid(creator) and creator.phase!="closed": return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(key_bindings) and key_bindings.blocked(): return
	var focus:=get_viewport().gui_get_focus_owner()
	# src/network_inventory_view.js:31 used an unmodified I key while a
	# replicated world was present and no text control owned the keystroke.
	if controlled_id>=0 and is_instance_valid(inventory) and inventory.objects.has(controlled_id) and event.keycode==KEY_I and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not GameInput.is_text_entry(focus):
		if inventory.ui.wanted: inventory.ui.close_inventory()
		else: inventory.ui.open()
		get_viewport().set_input_as_handled(); return
	if event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed and not GameInput.is_text_entry(focus) and not focus is Button and can_focus_network_chat() and is_instance_valid(desktop) and desktop.objects.has(controlled_id) and (not is_instance_valid(chat.native_skin) or chat.native_skin.pending_chat.is_empty()):
		chat.entry.grab_focus(); get_viewport().set_input_as_handled()
func snapshot() -> Dictionary:
	if is_instance_valid(mouse_cursor): stats.mouse_cursor=mouse_cursor.snapshot()
	if is_instance_valid(inventory_windows): stats.inventory_windows=inventory_windows.snapshot()
	var state:=stats.duplicate(true); state.merge({"startup":startup_snapshot(),"queued":queue.size(),"pending_tables":table_jobs.size(),"pending_portraits":portrait_jobs.size(),"tables_ready":tables_ready,"tlk_reads":text.base.reads+text.female.reads+text.custom.reads+text.custom_female.reads,"token_diagnostics":text.diagnostics.duplicate(),"feedback_diagnostics":feedback.diagnostics.duplicate(),"floating":floating_rows.size(),"nui":nui.snapshot(),"skin":skin_owner.snapshot() if is_instance_valid(skin_owner) else {},"inventory":inventory.snapshot() if is_instance_valid(inventory) else {},"barter":barter.snapshot() if is_instance_valid(barter) else {},"examine":examine_skin.snapshot() if is_instance_valid(examine_skin) else {},"desktop":desktop.snapshot() if is_instance_valid(desktop) else {},"creation":{"phase":creator.phase,"native_only":true},"scope":"Native gameplay desktop, character creation and original-data UI projection. Full binary visual parity and public-server transfers remain incomplete; native NUI is locally verified."}); state.window_layers=window_layers.snapshot() if is_instance_valid(window_layers) else {}; return state
func reset_quickbar_for_graphics_failure() -> void:
	if closed or not is_instance_valid(desktop):return
	desktop.reset_quickbar_for_graphics_failure()
func close() -> void:
	if closed: return
	closed=true; world_camera_yaw=Callable(); clear_floating()
	if is_instance_valid(popup_options) and popup_options.settings_changed.is_connected(popup_preferences_changed):popup_options.settings_changed.disconnect(popup_preferences_changed)
	popup_options=null
	native_connection_query=Callable();chat_focus_phase_query=Callable();overhead_anchor_query=Callable()
	script_floating_anchor_query=Callable();script_floating_object_delta_query=Callable()
	if is_instance_valid(script_floating):script_floating.close()
	if is_instance_valid(overhead):overhead.close()
	if is_instance_valid(overhead_popup_registry):overhead_popup_registry.close()
	if is_instance_valid(overhead_popup_source):overhead_popup_source.close()
	if is_instance_valid(popup_fonts):popup_fonts.close()
	modal_radials_bound=false
	if is_instance_valid(modal_order): modal_order.close()
	if is_instance_valid(mouse_cursor): mouse_cursor.close()
	if is_instance_valid(key_bindings): key_bindings.close()
	if is_instance_valid(window_layers): window_layers.close()
	if is_instance_valid(timing_view): timing_view.close()
	if is_instance_valid(creator): creator.close()
	if is_instance_valid(nui): nui.close()
	if is_instance_valid(barter): barter.close()
	if is_instance_valid(examine_skin): examine_skin.close()
	if is_instance_valid(conversation_skin): conversation_skin.close()
	if is_instance_valid(chat_skin): chat_skin.close()
	if is_instance_valid(gui_panel_access): gui_panel_access.close()
	if is_instance_valid(desktop): desktop.close()
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(skin_owner): skin_owner.close()
	if is_instance_valid(inventory_windows): inventory_windows.close()
	if is_instance_valid(inventory): inventory.close()
	if is_instance_valid(examine):examine.close_modal_owner()
	if is_instance_valid(modal_surfaces):modal_surfaces.close()
	actor_names.close();actor_name_history_complete=false
	text.close(); table_jobs.clear(); feedback_table_jobs.clear(); feedback_table_errors.clear(); portrait_jobs.clear(); portrait_textures.clear(); examine_portrait_waiting.clear(); examine_jobs.clear(); examine_pending.clear(); examine_message.clear(); queue.clear();pending_speech_logs.clear();pending_voice_captions.clear(); pool.clear(); catalog=null
func _exit_tree() -> void: close()
