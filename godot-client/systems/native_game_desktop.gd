extends Node
# Native menu ownership and rule projection. The protocol bridge sends raw
# received state/typed requests only; it never constructs these menu models.
signal request(message: Dictionary)
signal options_requested
signal target_changed(active: bool)
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const GameInput=preload("res://systems/native_data/game_input.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
const Float32=preload("res://systems/native_render/particle_math.gd")
const MovementRate=preload("res://systems/native_data/native_movement_rate.gd")
const NetworkTargeting=preload("res://systems/native_data/native_network_targeting.gd")
const ActionMenu=preload("res://systems/native_data/native_network_action_menu.gd")
const FeatRadial=preload("res://systems/native_data/feat_radial.gd")
const AbilityRadial=preload("res://systems/native_data/ability_radial.gd")
const SpellRadial=preload("res://systems/native_data/spell_radial.gd")
const QuickbarRadial=preload("res://systems/native_data/quickbar_radial.gd")
const QuickbarAssociates=preload("res://systems/native_quickbar_associate_commands.gd")
const CreatureRadial=preload("res://systems/native_data/creature_radial.gd")
const OtherCreatureRadial=preload("res://systems/native_data/other_creature_radial.gd")
const AssociateCreatureRadial=preload("res://systems/native_data/associate_creature_radial.gd")
const RecordTarget=preload("res://systems/native_data/character_record_target.gd")
const PlayerIdentity=preload("res://systems/native_data/player_identity.gd")
const Art=preload("res://systems/native_ui_art.gd")
const RasterItemIcons=preload("res://systems/native_item_icons.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Draggable=preload("res://systems/draggable_panel.gd")
const Preparation=preload("res://systems/native_data/spell_preparation.gd")
const INVALID:=2130706432
const PARTY_COMMANDS=[[0,"Attack nearest","IR_ATTACKNEAREST"],[22,"Follow","IR_FOLLOW"],[10,"Stand ground","IR_STANDGROUND"],[9,"Guard","IR_GUARD"],[4,"Heal me","IR_HEALME"]]
var rules:=Rules.new()
var party_details=preload("res://systems/native_data/party_details.gd").new()
var feat_rules:=FeatRadial.new()
var ability_rules:=AbilityRadial.new()
var spell_rules:=SpellRadial.new()
var ability_tables_pending: Array=[]
var radial_history: Array=[]
var art
var owner_ui
var objects: Dictionary={}
var state: Dictionary={}
var raw_data_retirement_enabled:=not OS.get_cmdline_user_args().has("--ui-data-retirement=main")
var raw_data_retirements:=0
var actor_id:=-1
var area_id:=-1
var generation:=-1
var serial:=0
var dirty:=true
var text_revision:=-1
var signatures: Dictionary={}
var party
var party_frame
var quickbar
var quickbar_frame
var sheet
var sheet_frame
var sheet_context: Dictionary={}
var book
var book_frame
var preparation:=Preparation.new()
var preparation_check_at:=0
var journal
var journal_frame
var area_map
var map_frame
var players
var players_frame
var buffs
var buff_frame
var action_queue
var level_up
var level_owner
var level_rules_waiting:=false
var radial
var target: Dictionary={}
var target_prompt: Label
var startup_notice: Label
var book_class:=0
var book_level:=0
var book_meta:=0
var family_path: Array=[]
var family_domain:=false
var radial_stack: Array=[]
var radial_target:=INVALID
var radial_position:=Vector3.ZERO
var radial_serial:=0
var radial_entries: Dictionary={}
var radial_item_icons
var radial_item_jobs: Dictionary={}
var quick_bindings: Array=[]
var quickbar_request_serial:=0
var quickbar_pending_moves: Dictionary={}
var quickbar_pending_assigns: Dictionary={}
var panel_feedback_serial:=0
var panel_feedback_pending: Dictionary={}
var target_feedback_serial:=0
var target_feedback_pending: Dictionary={}
var pending_shortcuts: Dictionary={}
var shortcut_context: Dictionary={}
var shortcut_rules:=QuickbarRadial.new()
var creature_radial:=CreatureRadial.new()
var other_creature_radial:=OtherCreatureRadial.new()
var associate_creature_radial:=AssociateCreatureRadial.new()
# Scalar private disclosure scope; this is not an entity/player state store.
var world_context: Dictionary={}
var world_radial_coverage: Dictionary={}
var shortcut_dialogs
var shortcut_timings: Array=[]
var item_art: Dictionary={}
var quickbar_item_keys: Dictionary={}
var quickbar_secondary_keys: Dictionary={}
var quickbar_item_retry: Array=[]
var quickbar_retry_at:=0
var quickbar_item_tables_wait:=false
var quickbar_icon_errors: Dictionary={}
var quickbar_art_view:=-1
var quickbar_binding_art:=false
var theme_ready:=false
var map_cells: Array=[]
var map_jobs: Dictionary={}
var map_queue: Array=[]
var map_definition: Dictionary={}
var map_set_job:=-1
var map_view:=-1
var map_tile_queued: Dictionary={}
var closed:=false
func configure(ui,catalog,cache_path: String,layout: String="user://native-menu-layout.cfg") -> void:
	owner_ui=ui; rules.text=ui.text; feat_rules.rules=rules; ability_rules.rules=rules; ability_rules.feats=feat_rules; spell_rules.rules=rules; spell_rules.abilities=ability_rules; art=Art.new(); add_child(art); art.configure(catalog,cache_path); art.assets.completed.connect(map_prepared); art.loaded.connect(map_art_ready); art.image_failed.connect(party_hud_icon_failed)
	party=preload("res://systems/server_party.gd").new(); ui.controls.add_child(party); party.setup(); party.panel_requested.connect(panel)
	party.portrait_selected.connect(func(index,_point):
		if index>=party.rows.size(): return
		var id: int=int(party.rows[index].id)
		var object: Dictionary=objects.get(id,{})
		if object.is_empty():return
		if not target.is_empty():
			var position: Array=object.get("replicated",{}).get("position",[0,0,0])
			var point:=Vector3(float(position[0]),float(position[2]),-float(position[1])) if position.size()==3 else Vector3.ZERO
			if int(target.get("type",0))==45 and not server_target_current(target):
				cancel_target();quickbar_failure("Server target selection was replaced");return
			if target_cursor(id,true).get("valid",false):cast_target(id,point,false,"party")
			else:
				var reason: String="That target is not valid for this server action" if int(target.get("type",0))==45 else "That target is not valid for this item" if int(target.get("type",0))==1 else "That target is not valid for this action"
				quickbar_failure(reason)
			return
		if is_instance_valid(rules.text) and rules.text.diagnostics.size()<100:
			rules.text.diagnostics.append({"code":"network.party-click-unhandled","reason":"Native portrait chat/action composition is not connected","objectId":id}))
	party.portrait_menu.connect(func(index,point): if index<party.rows.size(): open_radial({"id":int(party.rows[index].id),"position":Vector3.ZERO,"origin":"portrait"},point))
	party.request.connect(func(_message): command({"kind":"native-rest"}))
	party_frame=preload("res://systems/native_party_frame.gd").new(); add_child(party_frame); party_frame.configure(party,catalog,cache_path,ui.text,ui.inventory.frame_skin)
	party_frame.locator_context=party_locator_context
	quickbar=preload("res://systems/server_quickbar.gd").new(); ui.controls.add_child(quickbar); quickbar.retained_item_icons=ui.inventory.retained_item_icons; quickbar.setup(); quickbar.request.connect(input_request)
	quickbar.set_key_bindings(ui.key_bindings)
	quickbar.inventory_requested.connect(func(): panel("inventory")); quickbar.character_requested.connect(func(): panel("character")); quickbar.spellbook_requested.connect(func(): panel("spells")); quickbar.map_requested.connect(func(): panel("map")); quickbar.journal_requested.connect(func(): panel("journal")); quickbar.options_requested.connect(func(): options_requested.emit()); quickbar.level_requested.connect(func(): panel("level-up"))
	quickbar.assignment_requested.connect(shortcut_menu); quickbar.rendered.connect(bind_quickbar_art)
	shortcut_rules.rules=rules
	shortcut_dialogs=preload("res://systems/native_quickbar_context.gd").new();add_child(shortcut_dialogs);shortcut_dialogs.configure(self,catalog,cache_path)
	quickbar_frame=preload("res://systems/native_quickbar_frame.gd").new(); add_child(quickbar_frame); quickbar_frame.configure(quickbar,catalog,cache_path,ui.text,ui.inventory.frame_skin,ui.inventory.icons.pool if ui.inventory.retained_item_icons else null)
	quickbar.admission_check=quickbar_item_icons_ready
	for button in quickbar.pages[0].get_parent().get_children():
		if not button is Button or not quickbar.pages.has(button): button.hide()
	sheet=preload("res://systems/server_character_sheet.gd").new(); ui.controls.add_child(sheet); sheet.setup(layout); sheet.request.connect(input_request); sheet.level_requested.connect(func(): if sheet_context.is_empty():panel("level-up"))
	sheet.rendered.connect(bind_sheet_art)
	sheet_frame=preload("res://systems/native_character_sheet_frame.gd").new(); add_child(sheet_frame); sheet_frame.configure(sheet,catalog,cache_path,ui.text,ui.inventory.frame_skin)
	book=preload("res://systems/server_spellbook.gd").new(); ui.controls.add_child(book); book.setup(layout); book.request.connect(input_request)
	book.rendered.connect(bind_book_art)
	book_frame=preload("res://systems/native_spellbook_frame.gd").new(); add_child(book_frame); book_frame.configure(book,catalog,cache_path,ui.text,ui.inventory.frame_skin,refresh_book)
	journal=preload("res://systems/server_journal.gd").new(); ui.controls.add_child(journal); journal.setup(layout); journal.request.connect(input_request)
	journal_frame=preload("res://systems/native_journal_frame.gd").new(); add_child(journal_frame); journal_frame.configure(self,catalog,cache_path)
	area_map=preload("res://systems/server_map.gd").new(); ui.controls.add_child(area_map); area_map.setup(layout); area_map.request.connect(input_request)
	map_frame=preload("res://systems/native_map_frame.gd").new(); add_child(map_frame); map_frame.configure(self,catalog,cache_path)
	players=preload("res://systems/server_players.gd").new(); ui.controls.add_child(players); players.setup(layout); players.request.connect(input_request)
	players_frame=preload("res://systems/native_players_frame.gd").new(); add_child(players_frame); players_frame.configure(self,catalog,cache_path)
	level_up=preload("res://systems/server_level_up.gd").new(); ui.controls.add_child(level_up); level_up.setup(layout)
	level_owner=preload("res://systems/native_level_up.gd").new(); level_owner.configure(self,level_up); level_up.request.connect(level_owner.input)
	buffs=preload("res://systems/server_buffs.gd").new(); ui.controls.add_child(buffs); buffs.setup()
	buff_frame=preload("res://systems/native_effect_bar.gd").new(); add_child(buff_frame); buff_frame.configure(buffs,art,catalog,cache_path,ui.inventory.item_tooltips)
	buff_frame.report=Callable(self,"buff_report");rules.effect_report=Callable(self,"buff_report")
	buffs.effect_selected.connect(func(id):command({"kind":"native-panel","panel":"effect","open":true,"effectId":id}))
	action_queue=preload("res://systems/server_action_queue.gd").new(); ui.controls.add_child(action_queue); action_queue.setup(self); action_queue.cancel_requested.connect(func(id,group): command({"kind":"native-cancel-action","actionId":id,"groupId":group}))
	radial=preload("res://systems/server_radial.gd").new(); add_child(radial); radial.request.connect(input_request)
	radial.key_bindings=ui.key_bindings
	radial.preview_provider=radial_preview
	radial.configure_art(art)
	radial.configure_text(ui.inventory.frame_skin.fonts)
	if ui.inventory.retained_item_icons:
		radial_item_icons=RasterItemIcons.new(); add_child(radial_item_icons); radial_item_icons.configure(catalog,cache_path)
		radial_item_icons.completed.connect(radial_item_icon_ready)
	else: ui.inventory.icons.completed.connect(radial_item_icon_ready)
	quickbar.record_valid=sheet.can_drag; quickbar.inventory_valid=func(data): return int(data.get("viewId",-1))==owner_ui.inventory.ui.view_id and owner_ui.inventory.views.has(int(data.get("entryId",-1)))
	quickbar.radial_valid=func(data): return owner_ui.inventory.item_context.can_shortcut(data) if data.get("kind","")=="item-radial-entry" else can_radial_shortcut(data)
	owner_ui.inventory.ability_requested.connect(use_inventory_item)
	if owner_ui.inventory.retained_item_icons:owner_ui.inventory.icons.prepared.connect(item_icon_prepared)
	else:owner_ui.inventory.icons.completed.connect(item_icon_ready)
	owner_ui.inventory.item_context.opened.connect(radial.reset)
	owner_ui.inventory.item_context.ability_selected.connect(item_menu_ability)
	owner_ui.inventory.target_selector=Callable(self,"select_inventory_target")
	owner_ui.inventory.item_context.spell_entries=func():return spell_branches(8)
	owner_ui.inventory.item_context.spell_menu=func(menu):return spell_entries(menu,8)
	owner_ui.inventory.item_context.spell_build_failed=func():return not spell_rules.uses_failure.is_empty()
	owner_ui.inventory.item_context.ability_menu=func():return {"title":"Special ability","entries":ability_entries({"kind":"abilities"})}
	target_prompt=Label.new(); target_prompt.add_theme_color_override("font_shadow_color",Color.BLACK); target_prompt.add_theme_constant_override("shadow_offset_x",2); target_prompt.add_theme_constant_override("shadow_offset_y",2); target_prompt.position=Vector2(20,65); target_prompt.hide(); ui.controls.add_child(target_prompt)
	startup_notice=Label.new(); startup_notice.text="Preparing spell and feat menus…"; startup_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; startup_notice.position=Vector2(12,40); startup_notice.hide(); ui.controls.add_child(startup_notice)
	ui.inventory.frame_skin.font_style(startup_notice,{"AurString_Font":"fnt_dialog16x16"}); startup_notice.add_theme_color_override("font_color",Color(1,0.85,0.5)); startup_notice.add_theme_color_override("font_shadow_color",Color.BLACK); startup_notice.add_theme_constant_override("shadow_offset_x",2); startup_notice.add_theme_constant_override("shadow_offset_y",2)
func command(value: Dictionary) -> void:
	if closed or not objects.has(actor_id): return
	# Original8055c0 handles Keen Senses locally: GUI message0xc3 resolves
	# TLK66728 in6cb2e0, rather than sending an impossible Search toggle.
	if value.get("kind","")=="native-activity" and int(value.get("activityId",-1))==0 and rules.feats(actor()).has(240):
		owner_ui.chat.append_message({"system":true,"text":owner_ui.text.raw({"strRef":66728})}); return
	var message:=value.duplicate(); message.actorId=actor_id; message.areaId=area_id; message.generation=generation; request.emit(message)
func submit_target(value: Dictionary,world_pointer: bool=false,failure_origin: String="") -> void:
	# src/main.js:2639 presents feedback only after the targeter's awaited send.
	if closed or not objects.has(actor_id):return
	var kind:=str(value.get("kind",""))
	var feedback:=target_feedback(kind)
	if feedback.is_empty():command(value);return
	target_feedback_serial+=1
	var request_id:=target_feedback_serial
	target_feedback_pending[request_id]={"action":kind,"generation":generation,"areaId":area_id,"actorId":actor_id,"feedback":feedback,"worldPointer":world_pointer,"failureOrigin":failure_origin}
	var tagged:=value.duplicate();tagged.targetFeedbackRequestId=request_id
	command(tagged)
func target_feedback(kind: String) -> String:
	match kind:
		"native-script-target":return "Target selected"
		"native-item-ability":return "Item use requested"
		"native-mode":return "Mode requested"
		"native-feat":return "Ability requested"
		"native-cast","native-spell-like":return "Spell cast requested"
	return ""
func item_target_report(code: String,message: String,data: Dictionary) -> void:
	# network_spell_targeting.js:itemProviders forwards these two source
	# diagnostics while the item targeter prepares the active property.
	if not is_instance_valid(owner_ui) or not is_instance_valid(owner_ui.text):return
	owner_ui.text.diagnostics.append({"code":code,"message":message,"data":data.duplicate(true)})
func buff_report(code: String,message: String,data: Dictionary) -> void:
	if closed or not is_instance_valid(owner_ui) or not is_instance_valid(owner_ui.text):return
	if owner_ui.text.diagnostics.size()<100:owner_ui.text.diagnostics.append({"code":code,"message":message,"data":data.duplicate(true)})
func party_hud_icon_failed(key: String,reason: String) -> void:
	# network_party_view.js:32 reports only its eight HUD icon skin requests.
	# Other party frame artwork has a separate admission failure path.
	for action in Rules.HUD_ACTIONS:
		var model: String=str(action[2])
		if key==RasterItemIcons.model_key(model,"up"):
			buff_report("network.hud-icon-unavailable",reason,{"model":model})
			return
func set_world(epoch: int,area: int,controlled: int,raw_objects: Dictionary,header: Dictionary) -> void:
	var began:=Timing.begin()
	if epoch!=generation or controlled!=actor_id: rules.party_indicators.reset()
	retain_replaced_raw_state(raw_objects)
	Timing.finish("snapshot_ui_desktop_retain_ms",began); began=Timing.begin()
	if epoch!=generation or area!=area_id or controlled!=actor_id:
		quickbar_pending_moves.clear()
		quickbar_pending_assigns.clear()
		panel_feedback_pending.clear()
		target_feedback_pending.clear()
		retire_shortcut_context()
		sheet_context.clear()
		for view in [party,quickbar,sheet,book,journal,area_map,players,buffs,radial,level_up,action_queue]: view.reset()
		Timing.finish("snapshot_ui_desktop_views_ms",began); began=Timing.begin()
		signatures.clear(); family_path.clear(); family_domain=false; radial_stack.clear(); radial_entries.clear(); pending_shortcuts.clear(); map_jobs.clear(); map_queue.clear(); map_tile_queued.clear(); map_definition.clear(); map_set_job=-1; map_view=-1; cancel_target()
	Timing.finish("snapshot_ui_desktop_transient_ms",began); began=Timing.begin()
	objects=raw_objects; generation=epoch; area_id=area; actor_id=controlled
	if preparation.observe(actor(),[generation,area_id,actor_id],Time.get_ticks_msec()): signatures.erase("book")
	Timing.finish("snapshot_ui_desktop_objects_ms",began); began=Timing.begin()
	state=header; dirty=true
	if is_instance_valid(level_owner):level_owner.observe_received()
	if not world_context.is_empty() and not world_scope_valid():retire_current_radial(radial.request_id)
	if not sheet_context.is_empty() and not sheet_scope_valid():retire_sheet_target()
	var roster: Array=[controlled]
	for member in header.get("party",[]):
		var id:=int(member.get("id",INVALID)) if member is Dictionary else int(member)
		if not roster.has(id): roster.append(id)
	party_details.observe(roster,objects,owner_ui.text)
	if is_instance_valid(journal_frame) and journal_frame.observe(): signatures.erase("journal")
	Timing.finish("snapshot_ui_desktop_header_ms",began)
func retain_replaced_raw_state(replacement: Dictionary) -> void:
	if not raw_data_retirement_enabled or objects.is_empty() or is_same(objects,replacement): return
	# Only raw JSON protocol maps enter this packet. UI controls, projected menu
	# state and GPU resources remain on main. A same-map incremental update is
	# still live and never schedules disposal. The session owner fences two
	# frames and bounds pending packets before dropping these extra references.
	var ancestor:=get_parent()
	while is_instance_valid(ancestor):
		var owner=ancestor.get_meta("native_data_retirement") if ancestor.has_meta("native_data_retirement") else null
		if is_instance_valid(owner) and not owner.closed:
			owner.defer_release({"ui_objects":objects,"ui_header":state})
			raw_data_retirements+=1; return
		ancestor=ancestor.get_parent()
func actor() -> Dictionary: return objects.get(actor_id,{})
func _process(_delta: float) -> void:
	if not shortcut_context.is_empty() and not shortcut_scope_valid(shortcut_context):retire_shortcut_context()
	if closed or not objects.has(actor_id) or not owner_ui.hud_ready: return
	if not quickbar_item_retry.is_empty() and not quickbar_binding_art and is_instance_valid(quickbar_frame) and Time.get_ticks_msec()>=quickbar_retry_at:
		quickbar_retry_at=Time.get_ticks_msec()+100;quickbar_frame.try_admit()
	if text_revision!=int(rules.text.revision): text_revision=int(rules.text.revision); dirty=true
	if dirty: ensure_ability_tables()
	if not owner_ui.tables_ready:
		startup_notice.show()
		if dirty:
			dirty=false; sync_party()
		if not quickbar.visible:
			# Prepare original slot geometry without inventing usable spells.
			var rows: Array=[]
			for index in 36: rows.append({"empty":true,"label":"Loading shortcut rules…","enabled":false,"uses":null,"icon":""})
			serial+=1; quickbar.receive({"kind":"quickbar-view","quickbarId":serial,"rows":rows})
		return
	startup_notice.hide()
	if level_rules_waiting and not level_owner.draft.is_empty() and class_tables_ready(int(level_owner.draft.classId)):
		level_rules_waiting=false; level_owner.render()
	if not theme_ready and owner_ui.skin_owner.announced:
		theme_ready=true; radial.stage.theme=owner_ui.skin_owner.theme()
	pump_map_art()
	if not preparation.pending.is_empty() and (dirty or Time.get_ticks_msec()>=preparation_check_at):
		preparation_check_at=Time.get_ticks_msec()+250
		if preparation.observe(actor(),[generation,area_id,actor_id],Time.get_ticks_msec()): signatures.erase("book"); dirty=true
	if not dirty: return
	var began:=Timing.begin(); dirty=false; sync(); Timing.finish("callback_ui",began)
func changed(key: String,value: Variant) -> bool:
	var digest:=Cache.digest(var_to_bytes(value))
	if signatures.get(key)==digest: return false
	signatures[key]=digest; return true
func receive_targeting_state(ui_state: Dictionary) -> void:
	for key in ["scriptTargeting","scriptTargetingData","spellTargetingOverrides"]:
		if not ui_state.has(key):continue
		var value: Variant=ui_state[key]
		state[key]=value.duplicate(true) if value is Dictionary or value is Array else value
	sync_script_target(ui_state.has("scriptTargeting"))
	dirty=true
func sync_script_target(force: bool=false) -> void:
	var script_mode: Variant=state.get("scriptTargeting")
	var updated:=changed("script-target",script_mode)
	if force or updated:
		if force:cancel_target()
		if script_mode is Dictionary and not script_mode.is_empty() and not actor().is_empty():
			target={"type":45,"version":int(script_mode.version),"objectMask":int(script_mode.objectMask),"cursor":int(script_mode.get("cursor",29)),"badCursor":int(script_mode.get("badCursor",31))}; target_prompt.text="Choose a server target · Esc or right-click to cancel"; target_prompt.show(); target_changed.emit(true)
		elif int(target.get("type",0))==45: cancel_target()
func sync() -> void:
	var current:=actor()
	sync_script_target()
	# The original coalesced UI pass publishes buffs, inventory, quickbar,
	# party, panels, then action queue. Inventory has its own received-state
	# owner; keep the remaining desktop views in that source order.
	var effects: Dictionary=current.get("playerState",{})
	if changed("buffs",[effects.get("effectIcons",{}),effects.get("effectIconSerials",{}),rules.text.revision]):
		serial+=1; var rows: Array=rules.effect_icons(effects,actor_id)
		buffs.receive({"kind":"buff-begin","viewId":serial,"actorId":actor_id,"count":rows.size()}); buffs.receive({"kind":"buff-rows","viewId":serial,"rows":rows}); buffs.receive({"kind":"buff-commit","viewId":serial})
	var shortcut_items: Array=[]
	for binding in state.get("quickbar",[]):
		if int(binding.get("type",0))==1: shortcut_items.append(objects.get(int(binding.get("itemId",-1)),{}).get("item",{}))
	if changed("shortcuts",[state.get("quickbar",[]),current.get("playerState",{}).get("spellbooks",{}),current.get("playerState",{}).get("featUses",{}),current.get("playerState",{}).get("specialAbilities",[]),current.get("playerState",{}).get("playerFlags",0),current.get("playerState",{}).get("fields9E8",[]),shortcut_items,rules.text.revision]): refresh_quickbar()
	sync_party()
	if sheet.wanted:
		var displayed:=sheet_character()
		if not displayed.is_empty() and changed("sheet",[displayed.get("id"),sheet_context,displayed.get("inventoryStats",{}),displayed.get("replicated",{}).get("stats",{}),displayed.get("replicated",{}).get("hitPoints",{}),displayed.get("playerState",{}),sheet_record_equipment(displayed,not sheet_context.is_empty()),rules.text.revision]):refresh_sheet()
	if book.wanted and changed("book",[current.get("playerState",{}).get("spellbooks",{}),current.get("replicated",{}).get("stats",{}).get("classes",[]),rules.feats(current),rules.text.revision]): refresh_book()
	if journal.wanted and changed("journal",[state.get("journal",{}),rules.text.revision]): refresh_journal(journal.page)
	if players.wanted and changed("players",[players_frame.rows(),current.get("replicated",{}).get("party",{}),rules.text.revision]): refresh_players()
	if area_map.wanted: refresh_map()
	var actions: Array=current.get("playerState",{}).get("actionQueue",[])
	if changed("action-queue",[actions,rules.text.revision]):
		var projected: Array=rules.queued_actions(actions,actor_id)
		if not actions.is_empty() and rules.text.tables.get("actions",{}).is_empty():
			# The old async queue sync rejects before replacing its existing rows.
			# requestNetworkUiRefresh catches that rejection after the earlier views.
			if rules.text.diagnostics.size()<100:rules.text.diagnostics.append({"code":"network.ui-refresh-failed","reason":"Native actions table is unavailable"})
		else:action_queue.present(projected)
func party_position(id: int) -> Variant:
	var object: Dictionary=objects.get(id,{})
	if int(object.get("objectType",0))!=5 or object.get("replicationRemoved",false) or object.get("destroyed",false): return null
	var data: Dictionary=object.get("replicated",{})
	if int(data.get("areaId",object.get("areaId",-1)))!=area_id: return null
	if is_instance_valid(owner_ui.world_registry):
		var instance=owner_ui.world_registry.native_owners.get(id)
		if is_instance_valid(instance):
			var rendered: Vector3=instance.global_position
			if rendered.is_finite(): return Vector2(rendered.x,-rendered.z)
	var received: Array=data.get("position",[])
	if received.size()!=3: return null
	var position:=Vector2(float(received[0]),float(received[1]))
	return position if position.is_finite() else null
func party_locator_context() -> Dictionary:
	if closed or owner_ui.closed or not owner_ui.presentation_enabled or not is_instance_valid(owner_ui.world_camera): return {}
	var yaw:=float(owner_ui.world_camera_yaw.call()) if owner_ui.world_camera_yaw.is_valid() else NAN
	if not is_finite(yaw):
		var q: Quaternion=Quaternion(Vector3.RIGHT,PI/2)*owner_ui.world_camera.global_basis.get_rotation_quaternion()
		yaw=preload("res://systems/game_camera_state.gd").quaternion_yaw([q.w,q.x,q.y,q.z])
	return {"yaw":yaw,"area":area_id,"actor":party_position(actor_id),"position":party_position}
func sync_party() -> void:
	var party_rows:=rules.party(objects,actor_id,state.get("party",[]),state.get("players",[]))
	if changed("party",party_rows):
		serial+=1; var hud_actions: Array=[]
		for index in Rules.HUD_ACTIONS.size():
			var source: Array=Rules.HUD_ACTIONS[index]; hud_actions.append({"index":index,"id":source[0],"label":source[1],"key":source[3]})
		party.receive({"kind":"party-view","viewId":serial,"actorId":actor_id,"rows":party_rows,"actions":hud_actions})
		for row in party_rows:
			var button: Button=party.cards[int(row.entryId)].get_node("Box/Portrait"); art.bind_portrait(button.get_node("Image"),str(row.portraitKey),false); button.text="♙" if str(row.portraitKey).is_empty() else ""
		for index in hud_actions.size():
			if party_frame.layout_ready: continue
			var button: Button=party.action_buttons[index]
			for definition in [["up","normal"],["hilite","hover"],["down","pressed"]]:
				var style:=StyleBoxTexture.new(); button.add_theme_stylebox_override(definition[1],style); art.bind(style,str(Rules.HUD_ACTIONS[index][2]),"texture",true,str(definition[0]))
			button.text=""
	for index in party.action_buttons:
		party.action_buttons[index].disabled=not owner_ui.panel_ready(str(Rules.HUD_ACTIONS[int(index)][0]))
	owner_ui.mark_hud_started()
func panel(id: String) -> void:
	if not owner_ui.panel_ready(id): return
	var access=owner_ui.get("gui_panel_access")
	if id=="character" and not sheet_context.is_empty():
		# Original6fc400 retargets a different displayed character to controlled;
		# its already-open close bypass applies only to the controlled record.
		if is_instance_valid(access) and not access.character_target(actor_id):return
		force_self_character_record();return
	if is_instance_valid(access) and not access.ordinary(id): return
	if id=="journal":party.encourage("journal",false)
	# src/main.js:2650 onVisibility receives the newly opened panel ID from
	# NetworkPanels.view; opening a panel retires the world radial and target.
	var opening: bool=match_panel_opening(id)
	if opening:
		if is_instance_valid(radial):radial.reset()
		if not target.is_empty():cancel_target()
	match id:
		"options": options_requested.emit()
		"inventory":
			if owner_ui.inventory.ui.wanted: owner_ui.inventory.ui.close_inventory()
			else: owner_ui.inventory.ui.open()
		"character":
			if sheet.wanted: sheet.close_sheet()
			else: sheet.open()
		"spells":
			if book.wanted: book.wanted=false; book.hide()
			else: book.open()
		"map":
			if area_map.wanted: area_map.close_map()
			else: area_map.open()
		"journal":
			if journal.wanted: journal.close_journal()
			else: journal.open()
		"pvp":
			if players.wanted: players.close_players()
			else: players.open()
		"rest": command({"kind":"native-rest"})
		"level-up":
			if level_owner.submitting: return
			if level_up.wanted and not level_up.source_active: level_up.close_level_up()
			else: level_up.open()
func match_panel_opening(id: String) -> bool:
	match id:
		"options":return true
		"character":return not sheet.wanted
		"spells":return not book.wanted
		"map":return not area_map.wanted
		"journal":return not journal.wanted
		"pvp":return not players.wanted
		"level-up":return not level_owner.submitting and (not level_up.wanted or level_up.source_active)
		_:return false
func sheet_scope_valid() -> bool:
	return not closed and RecordTarget.valid(sheet_context,get_instance_id(),generation,area_id,actor_id,objects) and RecordTarget.admission(actor_id,int(sheet_context.target),objects,state).available
func sheet_character() -> Dictionary:
	if sheet_context.is_empty():return actor()
	return objects.get(int(sheet_context.target),{}) if sheet_scope_valid() else {}
func current_sheet_target() -> Variant:
	if closed or not is_instance_valid(sheet) or not sheet.wanted:return null
	if not sheet_context.is_empty():return int(sheet_context.target) if sheet_scope_valid() else null
	var current:=actor()
	return actor_id if not current.is_empty() and current.get("id")==actor_id and current.get("objectType")==5 and current.get("replicationRemoved")!=true and current.get("destroyed")!=true else null
func sheet_request_scope() -> Dictionary:
	# close_sheet emits after wanted=false; retain its exact foreign lease until
	# this synchronous request has captured both disclosure tokens.
	if sheet_context.is_empty():return {"targetId":actor_id} if not actor().is_empty() else {}
	return RecordTarget.request_scope(sheet_context) if sheet_scope_valid() else {}
func retire_sheet_target() -> void:
	if sheet_context.is_empty():return
	sheet_context.clear();signatures.erase("sheet")
	if is_instance_valid(sheet):sheet.reset()
func force_self_character_record() -> bool:
	if closed or not is_instance_valid(sheet) or actor().is_empty():return false
	if sheet.wanted and sheet_context.is_empty() and current_sheet_target()==actor_id:return true
	if not owner_ui.panel_ready("character"):return false
	var retarget:=not sheet_context.is_empty();sheet_context.clear();signatures.erase("sheet")
	if retarget:sheet.page=0
	if sheet.wanted:input_request({"kind":"sheet-page","page":sheet.page})
	else:sheet.open()
	return true
func open_character_record(target_id: int) -> bool:
	if closed or target_id==actor_id or not is_instance_valid(sheet):return false
	var admission:=RecordTarget.admission(actor_id,target_id,objects,state)
	var scope:=RecordTarget.capture(get_instance_id(),generation,area_id,actor_id,target_id,objects)
	if not admission.available or scope.is_empty():return false
	var access=owner_ui.get("gui_panel_access")
	if not is_instance_valid(access) or not access.character_target(target_id):return false
	if not RecordTarget.valid(scope,get_instance_id(),generation,area_id,actor_id,objects) or not RecordTarget.admission(actor_id,target_id,objects,state).available:return false
	var same:bool=sheet.wanted and current_sheet_target()==target_id
	if same:return true
	if not owner_ui.panel_ready("character"):return false
	sheet_context=scope
	sheet.page=0;signatures.erase("sheet")
	if sheet.wanted:input_request({"kind":"sheet-page","page":0})
	else:sheet.open()
	return true
func sheet_record_equipment(displayed: Dictionary,foreign: bool) -> Dictionary:
	var equipment: Dictionary={}
	if not foreign and is_instance_valid(owner_ui.inventory):
		var inventory: Variant=owner_ui.inventory.inventories.get("I")
		if inventory is Dictionary and inventory.get("entries") is Array:
			for location in inventory.entries:
				var slot:=int(location.get("slot",-1))
				if slot not in [16,32]:continue
				var item: Variant=objects.get(int(location.get("id",-1)),{}).get("item")
				if item is Dictionary:equipment[slot]=item
			return equipment
	for equipped in displayed.get("appearance",{}).get("equipment",[]):
		var slot:=int(equipped.get("slot",-1))
		if slot in [16,32] and equipped.get("item") is Dictionary:equipment[slot]=equipped.item
	return equipment
func refresh_sheet() -> void:
	var displayed:=sheet_character()
	if displayed.is_empty():
		if not sheet_context.is_empty():retire_sheet_target()
		return
	var foreign:=not sheet_context.is_empty();var identity:=str(generation)+":"+str(displayed.id)
	if foreign:identity+=":"+str(sheet_context.actorLifetime)+":"+str(sheet_context.targetLifetime)
	var model:=rules.record(displayed,identity,sheet_record_equipment(displayed,foreign));var entries:Array=rules.record_entries(displayed,sheet.page) if sheet.page>0 else []
	if foreign:
		# Original nonself record hides progression. The controlled armor/mode
		# buffer is not the NPC's current armor result; leave unproved data null.
		model.experience=null;model.nextExperience=null;model.armorClass=null
		for value in entries:value.canDrag=false
	serial+=1; sheet.receive({"kind":"sheet-view","viewId":serial,"page":sheet.page,"model":model,"canLevelUp":not foreign and displayed.get("playerState",{}).get("combat",{}).get("canLevelUp",false),"entries":entries})
func inspect_sheet_entry(message: Dictionary) -> void:
	if not sheet.wanted or int(message.get("viewId",-1))!=sheet.view_id or int(message.get("page",-1))!=sheet.page or sheet.page not in [1,2]: return
	var scope:=sheet_request_scope()
	if scope.is_empty():
		if not sheet_context.is_empty():retire_sheet_target()
		return
	var id:=int(message.get("entryId",-1))
	if not sheet.entry_data.has(id): return
	var row: Dictionary=sheet.entry_data[id]
	# CCharPageFeats9c04b0 returns without GUI4 when GetFeat is unavailable.
	if sheet.page==2 and rules.record_feat_definition(int(row.id)).is_empty(): return
	# Active server TLK overrides/custom tokens can arrive after the previous
	# click. Resolve this row again without rebuilding the whole record/list.
	sheet.receive({"kind":"sheet-description","viewId":sheet.view_id,"page":sheet.page,"entryId":id,"description":rules.description("skills" if sheet.page==1 else "feat",int(row.id))})
	if sheet.page==1: command({"kind":"native-panel","panel":"skill","open":true,"skillId":int(row.id)}.merged(scope))
	else: command({"kind":"native-panel","panel":"feat","open":true,"featId":int(row.id)}.merged(scope))
func bind_sheet_art() -> void:
	if closed or sheet.state.is_empty(): return
	if sheet.image_nodes.has("portrait"):
		var displayed:=sheet_character();var resource:=rules.portrait(displayed) if not displayed.is_empty() else ""
		if sheet_context.is_empty() and resource.is_empty() and not party.rows.is_empty() and not str(party.rows[0].portraitKey).is_empty(): resource=str(party.rows[0].portraitKey).left(-1)+"l"
		if not sheet_context.is_empty() and resource.is_empty():sheet.image_nodes.portrait.texture=null
		else:art.bind_portrait(sheet.image_nodes.portrait,resource,false)
	for key in ["Str","Dex","Con","Int","Wis","Cha"]:
		if sheet.image_nodes.has("ability:"+key): art.bind(sheet.image_nodes["ability:"+key],"gui_chrsht_"+key.to_lower())
	for entry in sheet.state.get("entries",[]):
		if sheet.image_nodes.has("entry:"+str(entry.entryId)): art.bind(sheet.image_nodes["entry:"+str(entry.entryId)],str(entry.icon))
func refresh_book() -> void:
	var model: Dictionary=rules.spellbook_tree(actor(),book_class,book_level,book_meta,family_path,family_domain) if is_instance_valid(book_frame) and book_frame.layout_ready else rules.spellbook(actor(),book_class,book_level,book_meta,family_path,family_domain)
	if not str(model.get("error","")).is_empty():
		signatures.erase("book")
		book.receive({"kind":"book-notice","text":str(model.error)})
		return
	serial+=1; preparation.decorate(model); model.kind="spellbook-view"; model.viewId=serial; book_class=int(model.classIndex); book.receive(model)
	if not preparation.notice.is_empty(): book.notice.text=preparation.notice
func bind_book_art() -> void:
	for id in book.widgets:
		if book.widgets[id].is_visible_in_tree(): art.bind(book.widgets[id].image,str(book.rows[id].icon))
func prewarm_quickbar_item_icons() -> void:
	quickbar_item_keys.clear(); quickbar_secondary_keys.clear(); quickbar_item_retry.clear(); quickbar_icon_errors.clear(); quickbar_item_tables_wait=false
	if not owner_ui.inventory.icon_tables_ready():
		for binding in quick_bindings:
			if int(binding.get("type",0))==1: quickbar_item_tables_wait=true; break
		return
	var gender:=int(actor().get("appearance",{}).get("gender",0))
	for index in mini(36,quick_bindings.size()):
		if int(quick_bindings[index].get("type",0))!=1: continue
		request_quickbar_item(index,false,gender)
		if owner_ui.inventory.retained_item_icons:request_quickbar_item(index,true,gender)
func quickbar_item(index: int,secondary: bool=false) -> Dictionary:
	if index<0 or index>=quick_bindings.size() or int(quick_bindings[index].get("type",0))!=1:return {}
	var id:=int(quick_bindings[index].get("secondaryItemId",INVALID)) if secondary else int(quick_bindings[index].get("itemId",INVALID))
	return objects.get(id,{}).get("item",{})
func request_quickbar_item(index: int,secondary: bool,gender: int) -> void:
	var item: Dictionary=quickbar_item(index,secondary)
	if item.is_empty():return
	var icons=owner_ui.inventory.icons
	var key: String=icons.request(item,owner_ui.text.tables,gender,"small") if owner_ui.inventory.retained_item_icons else icons.request(item,owner_ui.text.tables,gender)
	if not key.is_empty():
		if secondary:quickbar_secondary_keys[index]=key
		else:quickbar_item_keys[index]=key
	elif icons.last_request_error=="Native asset queue is full":quickbar_item_retry.append({"index":index,"secondary":secondary})
	elif not icons.last_request_error.is_empty():quickbar_icon_errors[str(index)+(":secondary" if secondary else "")]=icons.last_request_error
func quickbar_item_icons_ready() -> bool:
	if quickbar_item_tables_wait:
		if not owner_ui.inventory.icon_tables_ready(): return false
		prewarm_quickbar_item_icons(); call_deferred("bind_quickbar_art"); return false
	if quickbar_binding_art or quickbar_art_view!=quickbar.quickbar_id: return false
	if not quickbar_item_retry.is_empty():
		var retry: Array=quickbar_item_retry.duplicate(); quickbar_item_retry.clear()
		var gender:=int(actor().get("appearance",{}).get("gender",0))
		for job in retry:request_quickbar_item(int(job.index),bool(job.secondary),gender)
		if not quickbar_item_retry.is_empty(): return false
	for key in quickbar_item_keys.values()+quickbar_secondary_keys.values():
		if owner_ui.inventory.retained_item_icons:
			if not owner_ui.inventory.icons.bundles.has(key) and not owner_ui.inventory.icons.failed.has(key):return false
		else:
			if not owner_ui.inventory.icons.textures.has(key) and not owner_ui.inventory.icons.failed.has(key): return false
	if owner_ui.inventory.retained_item_icons:
		for index in quickbar.buttons:
			if quickbar_item_keys.has(index) and not quickbar_frame.item_icon_presented(int(index)):return false
			if quickbar_secondary_keys.has(index) and not quickbar_frame.item_icon_presented(int(index),true):return false
	return true
func refresh_quickbar() -> void:
	var next_bindings: Array=state.get("quickbar",[]).duplicate(true); var rows: Array=[]
	for index in 36:
		var binding: Dictionary=next_bindings[index] if index<next_bindings.size() else {"type":0}
		rules.spellbook_failure=""
		var row: Dictionary=shortcut_row(binding)
		if not rules.spellbook_failure.is_empty():
			signatures.erase("shortcuts")
			quickbar_failure(rules.spellbook_failure,"network.ui-refresh-failed")
			return
		rows.append(row)
	quick_bindings=next_bindings
	prewarm_quickbar_item_icons()
	quickbar_art_view=-1
	serial+=1; quickbar.receive({"kind":"quickbar-view","quickbarId":serial,"rows":rows})
	if not shortcut_context.is_empty() and not shortcut_scope_valid(shortcut_context):retire_shortcut_context()
func reset_quickbar_for_graphics_failure() -> void:
	# src/main.js:2724 resets the bound quickbar when graphics fails.
	if closed:return
	retire_shortcut_context()
	quickbar_pending_moves.clear();quickbar_pending_assigns.clear();quick_bindings.clear();pending_shortcuts.clear()
	item_art.clear();quickbar_item_keys.clear();quickbar_secondary_keys.clear();quickbar_item_retry.clear();quickbar_icon_errors.clear()
	quickbar_item_tables_wait=false;quickbar_art_view=-1;quickbar_binding_art=false
	if is_instance_valid(quickbar):quickbar.reset()
	if is_instance_valid(quickbar_frame):quickbar_frame.current_icons.clear()
func bind_quickbar_art() -> void:
	quickbar_binding_art=true
	item_art.clear()
	for index in quickbar.buttons:
		if owner_ui.inventory.icon_tables_ready():
			for secondary in ([true,false] if owner_ui.inventory.retained_item_icons else [false]):
				var item: Dictionary=quickbar_item(int(index),secondary)
				if item.is_empty():continue
				var key: String=owner_ui.inventory.icons.request(item,owner_ui.text.tables,int(actor().get("appearance",{}).get("gender",0)),"small") if owner_ui.inventory.retained_item_icons else owner_ui.inventory.icons.request(item,owner_ui.text.tables,int(actor().get("appearance",{}).get("gender",0)))
				if key.is_empty():continue
				if not item_art.has(key):item_art[key]=[]
				item_art[key].append({"index":index,"view":quickbar.quickbar_id,"secondary":secondary})
				if not owner_ui.inventory.retained_item_icons and owner_ui.inventory.icons.textures.has(key):item_icon_ready(key,owner_ui.inventory.icons.textures[key],"")
		var row: Dictionary=quickbar.rows[index]
		if not owner_ui.inventory.retained_item_icons or not bool(row.get("itemIcon",false)):art.bind(quickbar.buttons[index].image,str(row.get("icon","")))
	quickbar_binding_art=false; quickbar_art_view=quickbar.quickbar_id
	if owner_ui.inventory.retained_item_icons:call_deferred("bind_retained_quickbar_art")
	if is_instance_valid(quickbar_frame): quickbar_frame.try_admit()
func bind_retained_quickbar_art() -> void:
	if closed or not owner_ui.inventory.retained_item_icons or not is_instance_valid(quickbar_frame):return
	for secondary in [true,false]:
		for key in item_art:
			if not owner_ui.inventory.icons.bundles.has(key):continue
			for job in item_art[key]:
				if bool(job.secondary)!=secondary or int(job.view)!=quickbar.quickbar_id or not quickbar.buttons.has(int(job.index)):continue
				var button: Button=quickbar.buttons[int(job.index)]
				quickbar_frame.bind_item_icon(int(job.index),str(key),owner_ui.inventory.icons.bundles[key],button.modulate.a,secondary)
	quickbar_frame.try_admit()
func item_icon_prepared(key: String,_bundle: Dictionary,error: String) -> void:
	if closed:return
	if not error.is_empty() and (quickbar_item_keys.values().has(key) or quickbar_secondary_keys.values().has(key)):quickbar_failure("Shortcut icon unavailable: "+error,"network.quickbar-icon-unavailable")
	if item_art.has(key):call_deferred("bind_retained_quickbar_art")
func shortcut_row(binding: Dictionary) -> Dictionary:
	var type:=int(binding.get("type",0)); var id:=int(binding.get("intParam",0)); var table:="spells" if type in [2,44] else "feat" if type==4 else "skills" if type==3 else ""
	if type==4: id&=65535
	var action_icon:=""
	var uses: Variant=null
	var item_enabled:=true
	var spell_shortcut: Dictionary={}
	if type==2:
		var spell_binding: Dictionary=binding.duplicate(); spell_binding.classIndex=int(binding.get("classIndex",0))&7; spell_binding.domainLevel=int(binding.get("domainLevel",0))&15; spell_binding.metamagic=int(binding.get("metamagic",0))&63
		uses=rules.spell_uses(actor(),id,int(spell_binding.classIndex),int(spell_binding.metamagic),int(spell_binding.domainLevel))
		spell_shortcut={"enabled":int(uses)>0}
	elif type==4:
		uses=preload("res://systems/native_data/native_network_feat_input.gd").network_feat_uses(actor(),feat_rules,id)
		if uses==100: uses=null
	elif type==44:
		uses=rules.spell_like_shortcut_uses(actor(),id,int(binding.get("domainLevel",0))&15)
	var label:="Empty" if type==0 else rules.title(table,id,"FEAT" if type==4 else "Name") if not table.is_empty() else str(binding.get("commandLabel","Action"))
	if type==4:
		var value:=feat_rules.leaf(feat_rules.context(actor(),actor_id,true),int(binding.intParam))
		if not value.is_empty() and not value.get("submenu",false): label=owner_ui.text.raw({"strRef":int(value.labelRef)}); action_icon=str(value.icon)
		else:
			var info:=feat_rules.feat(id); var spell:=feat_rules.target_spell(id,int(binding.get("auxiliary",(int(binding.intParam)>>16)&65535)))
			if not info.is_empty() and spell>=0 and spell!=int(info.spellId): label=rules.title("spells",spell); action_icon=rules.icon("spells",spell)
	if type==42:
		var value:=shortcut_rules.command(id&65535)
		if not value.is_empty():label=owner_ui.text.raw({"strRef":int(value.labelRef)});action_icon=str(value.icon)
		else:label="Quick chat "+str(id&65535)
	elif type==39:
		var value:=shortcut_rules.associate(binding);label=""
		if not value.is_empty():
			label=owner_ui.text.raw({"strRef":int(value.labelRef)});action_icon=str(value.icon)
			var resolved: Variant=QuickbarAssociates.shortcut(binding,actor())
			var associate_id:=int(resolved.targetId) if resolved is Dictionary else INVALID
			var associate_object: Dictionary=objects.get(associate_id,{})
			if not associate_object.is_empty() and not associate_object.get("replicationRemoved",false):
				var associate_name: String=owner_ui.text.name(associate_object.get("replicated",{}).get("name",associate_object.get("appearance",{}).get("name",{})),associate_id)
				if not associate_name.is_empty():label+=" : "+associate_name
	elif type==38: label="Possess Familiar"; action_icon="IFE_POSSESS"
	elif type==10:
		var activity: Dictionary=ability_rules.activity(actor(),id)
		label=owner_ui.text.raw({"strRef":int(activity.get("labelRef",0))}); action_icon=str(activity.get("icon",""))
	elif type==8:
		var value:=shortcut_rules.emote(id)
		if not value.is_empty():label=owner_ui.text.raw({"strRef":int(value.labelRef)});action_icon=str(value.icon)
	elif type in [6,7,18,40,41,43]:
		var value: Array={6:[1072,"IR_DIALOG"],7:[1056,"IR_ATTACK"],18:[0,"IR_TEXTMACRO"],40:[549,"IR_EXAMINE"],41:[263,"IR_BARTER"],43:[8272,"IR_SKILLSELF"]}[type]
		label=str(binding.get("commandLabel","")) if type==18 else owner_ui.text.raw({"strRef":int(value[0])});action_icon=str(value[1])
	if type==1:
		var item: Dictionary=objects.get(int(binding.get("itemId",-1)),{}).get("item",{})
		label="Unavailable item" if item.is_empty() else owner_ui.text.name(item.get("name"),int(binding.get("itemId",-1)))
		var item_provider:=preload("res://systems/native_data/native_item_quickbar.gd").new()
		item_provider.configure({"registry":objects,"local_object_id":actor_id},owner_ui.text.tables)
		var presentation: Dictionary=item_provider.update_count(binding)
		uses=presentation.get("uses",null);item_enabled=bool(presentation.get("enabled",true))

	return {"empty":type==0,"label":label,"enabled":bool(spell_shortcut.enabled) if type==2 else item_enabled if type==1 else type!=0 and (uses==null or uses is String and uses=="*" or int(uses)>0),"uses":uses,"itemIcon":type==1,"icon":action_icon if type==4 and not action_icon.is_empty() else rules.icon(table,id) if not table.is_empty() else action_icon}
func quickbar_failure(reason: String,code: String="network.quickbar-ui-failed") -> void:
	if is_instance_valid(owner_ui) and is_instance_valid(owner_ui.text) and owner_ui.text.diagnostics.size()<100:
		owner_ui.text.diagnostics.append({"code":code,"message":reason})
	if is_instance_valid(target_prompt):target_prompt.text=reason;target_prompt.show()
func assign(index: int,binding: Dictionary,configure_item: bool=true,quickbar_request_id: int=-1) -> bool:
	if index<0 or index>=36 or quickbar_pending_assigns.has(index): return false
	var button: Dictionary=binding
	if int(binding.get("type",0))==1 and configure_item:
		var provider=preload("res://systems/native_data/native_item_quickbar.gd").new()
		provider.configure({"registry":objects,"local_object_id":actor_id},owner_ui.text.tables)
		var previous: Dictionary=quick_bindings[index] if index<quick_bindings.size() else {}
		var configured: Dictionary=provider.configure_shortcut(previous,binding)
		if not bool(configured.get("ok",false)):
			quickbar_failure(str(configured.get("error","That item cannot be assigned")))
			return false
		button=configured.button
	elif int(binding.get("type",0))==4:
		button=FeatRadial.binding(int(binding.intParam),int(binding.get("auxiliary",(int(binding.intParam)>>16)&65535)))
	if quickbar_request_id<0:
		quickbar_request_serial+=1
		quickbar_request_id=quickbar_request_serial
	quickbar_pending_assigns[index]=quickbar_request_id
	quickbar.set_pending(index,true)
	var request_value:={"kind":"native-quickbar-assign","index":index,"button":button,"quickbarRequestId":quickbar_request_id}
	command(request_value)
	return true
func activate(binding: Dictionary,source_index: int=-1) -> void:
	if source_index>=0 and (source_index>=quick_bindings.size() or quick_bindings[source_index]!=binding):return
	if source_index>=0 and quickbar_pending_assigns.has(source_index):return
	var shortcut_index:=source_index if source_index>=0 else quick_bindings.find(binding)
	if source_index>=0:
		var kind:=int(binding.get("type",0)); var spell_id:=int(binding.get("intParam",0))
		if kind==2:
			rules.spellbook_failure=""
			var spell_uses:=rules.spell_uses(actor(),spell_id,int(binding.get("classIndex",0))&7,int(binding.get("metamagic",0))&63,int(binding.get("domainLevel",0))&15)
			if not rules.spellbook_failure.is_empty():
				quickbar_failure(rules.spellbook_failure,"network.quickbar-activation-failed")
				return
			if spell_uses==0:return
		if kind==44 and rules.spell_like_shortcut_uses(actor(),spell_id,int(binding.get("domainLevel",0))&15)==0:return
	match int(binding.get("type",0)):
		2: begin_target(binding,source_index>=0)
		44,4,3: begin_target(binding,source_index>=0)
		6,7,40,41:begin_target(binding)
		8:play_emote(int(binding.get("intParam",-1)))
		18:execute_macro(str(binding.get("commandLine","")))
		10:
			if int(binding.get("intParam",0))==5 and (ability_rules.player_flags(actor())&512)==0: begin_target(binding)
			else:
				cancel_target(); command({"kind":"native-activity","activityId":int(binding.get("intParam",0))})
				if int(binding.get("intParam",0))==5:
					# Native AQ31 maps to server ActionCounterSpell50. Cancel the
					# received group too: its queued action can otherwise restore
					# mode4 after the native mode toggle, even with no new target.
					var groups: Dictionary={}
					for queued in actor().get("playerState",{}).get("actionQueue",[]):
						if int(queued.get("type",-1))==31 and not groups.has(int(queued.group)):
							groups[int(queued.group)]=true; command({"kind":"native-cancel-action","actionId":31,"groupId":int(queued.group)})
		42: cancel_target(); command({"kind":"native-quickchat","quickChat":int(binding.intParam)&65535})
		38: cancel_target(); command({"kind":"native-possess"})
		43: cancel_target(); command({"kind":"native-quickbar-activate","index":shortcut_index})
		39:
			cancel_target()
			var associate_request: Variant=QuickbarAssociates.shortcut(binding,actor())
			if not associate_request is Dictionary:return
			if shortcut_index>=0:command({"kind":"native-quickbar-activate","index":shortcut_index})
			else:
				command({"kind":"native-associate","targetId":associate_request.targetId,"command":associate_request.command})
		1:
			var prepared:=item_binding(binding)
			if int(prepared.intParam)&65535!=255: begin_target(prepared,source_index>=0)
			else: command({"kind":"native-quickbar-activate","index":shortcut_index})
		_: command({"kind":"native-quickbar-activate","index":shortcut_index})
func execute_macro(line: String) -> void:
	# Original85c8f0 invokes87b590 with mode0, independently of the open chat
	# prompt. Reuse that native dispatcher without clearing the user's edit.
	var message:=preload("res://systems/native_data/chat_prompt.gd").dispatch(line,0,state.get("players",[]),owner_ui.text)
	if message.has("error") or message.has("error_ref"):
		owner_ui.chat.append_message({"system":true,"text":owner_ui.text.raw({"strRef":int(message.error_ref)}) if message.has("error_ref") else str(message.error)})
	elif not message.is_empty():command(message)
func play_emote(id: int) -> void:
	var value:=shortcut_rules.emote(id)
	if value.is_empty():return
	var duration:=10.0 if id in [18,20] else 0.0
	if id not in [18,20] and preload("res://systems/native_data/character_record_values.gd").cfg(owner_ui.text.tables,"MOTE_ANIMATIONS_USE_MDL_TIMINGS",0)!=0:
		var registry=owner_ui.world_registry
		if is_instance_valid(registry):
			var body=registry.native_owners.get(actor_id)
			if is_instance_valid(body) and is_instance_valid(body.rigs):duration=maxf(0,body.rigs.clip_length(actor_id,int(value.animation)))
	var position: Array=actor().get("replicated",{}).get("position",[])
	if position.size()==3:command({"kind":"native-emote","animation":int(value.animation),"position":position.duplicate(),"duration":duration,"voice":int(value.voice)})
func begin_target(binding: Dictionary,quickbar_origin: bool=false) -> void:
	target=binding.duplicate(true); var type:=int(binding.get("type",0)); var id:=int(binding.get("intParam",0))
	if quickbar_origin and type in [1,2,4,44]:target.failureOrigin="quickbar"
	if quickbar_origin and type in [1,2,4,44] and actor().is_empty():
		cancel_target();quickbar_failure("Controlled item user is unavailable" if type==1 else "Controlled creature is unavailable" if type==4 else "Controlled caster is unavailable");return
	if type in [6,7,40,41]:
		target_prompt.text="Choose a target for "+str(shortcut_row(binding).label)+" · Esc or right-click to cancel";target_prompt.show();target_changed.emit(true);return
	if type==10:
		target_prompt.text="Choose a creature to counterspell · Esc or right-click to cancel"; target_prompt.show(); target_changed.emit(true); return
	if type==1:
		var providers:=preload("res://systems/native_data/native_item_quickbar.gd").new()
		providers.configure({"registry":objects,"local_object_id":actor_id},owner_ui.text.tables)
		var policy:=preload("res://systems/native_data/native_network_item_input.gd")
		var plan: Dictionary=policy.prepare_item_target(int(binding.get("itemId",INVALID)),id,providers,int(owner_ui.inventory.wanted),0,1,Callable(self,"item_target_report"))
		if str(plan.get("mode",""))=="unavailable":
			cancel_target()
			if quickbar_origin:quickbar_failure("Item targeting metadata is unavailable")
			return
		target.itemPlan=plan
		if str(plan.mode)=="self":cast_target(actor_id,Vector3.ZERO);return
		target_prompt.text="Choose a target for "+str(shortcut_row(binding).label)+" · Esc or right-click to cancel";target_prompt.show();target_changed.emit(true);return
	if type in [2,44]:
		if rules.spell_family(id):
			cancel_target()
			var family: Dictionary=quickbar_shortcut_choice(binding)
			var children: Array=family.get("children",[])
			if children.is_empty():
				if quickbar_origin:quickbar_failure("No valid variants are available for this spell")
				return
			radial_target=-1;radial_position=Vector3.ZERO;radial_stack.clear();pending_shortcuts.clear()
			radial.open_at(get_viewport().get_mouse_position(),-1,Vector3.ZERO,false)
			show_radial({"title":str(family.label),"entries":quickbar_choice_menu(str(family.label),children),"center":str(family.icon)},true)
			return
		if type==2:
			var shortcut: Dictionary=spell_rules.shortcut(actor(),binding)
			if not spell_rules.uses_failure.is_empty():
				cancel_target()
				quickbar_failure(spell_rules.uses_failure,"network.quickbar-activation-failed" if quickbar_origin else "network.spellbook-ui-failed")
				return
			target=shortcut.binding
			if quickbar_origin:target.failureOrigin="quickbar"
		var request: Dictionary={"spellId":id,"classIndex":int(target.get("classIndex",0))&7,"domainLevel":int(target.get("domainLevel",0))&15,"metamagic":int(target.get("metamagic",0))&63,"spontaneous":int(target.get("spontaneous",0))}
		if type==44:request={"kind":"innate","spellId":id,"casterLevel":int(target.get("domainLevel",0))&15}
		var spell_policy:=preload("res://systems/native_data/native_network_spell_input.gd")
		var spell_plan: Dictionary=spell_policy.prepare_spell_target(actor(),request,rules,1,int(owner_ui.inventory.wanted))
		if str(spell_plan.get("mode",""))=="unavailable":
			cancel_target()
			if quickbar_origin:quickbar_failure("Spell targeting metadata is unavailable")
			return
		target.spellPlan=spell_plan;target.spellId=int(spell_plan.definition.id)
		if str(spell_plan.mode)=="self":
			var location: Array=actor().get("replicated",{}).get("position",[])
			cast_target(actor_id,Vector3(location[0],location[2],-location[1]) if location.size()==3 else Vector3.ZERO)
			return
		target_prompt.text="Choose a target for "+str(shortcut_row(binding).label)+" · Esc or right-click to cancel";target_prompt.show();target_changed.emit(true);return
	if type==3 and id==10: cancel_target(); command({"kind":"native-mode","modeId":2}); return
	if type==3 and id==22: cast_target(actor_id,Vector3.ZERO); return
	if type==4:
		var policy:=preload("res://systems/native_data/native_network_feat_input.gd")
		var feat_plan: Dictionary=policy.prepare_feat_target({"featId":id,"auxiliary":int(binding.get("auxiliary",(id>>16)&65535))},feat_rules)
		if str(feat_plan.get("mode",""))=="unavailable":
			cancel_target()
			if quickbar_origin:quickbar_failure("Feat targeting metadata is unavailable")
			return
		if str(feat_plan.mode)=="mode":cancel_target();submit_target({"kind":"native-mode","modeId":int(feat_plan.modeId)},false,"quickbar" if quickbar_origin else "");return
		target.featPlan=feat_plan;target.spellId=int(feat_plan.get("definition",{}).get("id",-1))
		if str(feat_plan.mode)=="self":cast_target(actor_id,Vector3.ZERO);return
	else:
		var data:=rules.row("spells" if type in [1,2,44] else "skills",int(binding.get("spellId",id)))
		if Rules.number(Rules.cell(data,"TargetType"),-1)==1: cast_target(actor_id,Vector3.ZERO); return
	target_prompt.text="Choose a target for "+str(shortcut_row(binding).label)+" · Esc or right-click to cancel"; target_prompt.show(); target_changed.emit(true)
func cancel_target() -> void:
	target.clear()
	if is_instance_valid(target_prompt): target_prompt.hide()
	target_changed.emit(false)
func server_target_current(binding: Dictionary) -> bool:
	if int(binding.get("type",0))!=45: return false
	# A newer packet can replace the mode before the next UI sync. The original
	# client never sends a selection for a superseded server version.
	if state.has("scriptTargeting"):
		var mode: Variant=state.scriptTargeting
		if not mode is Dictionary or mode.is_empty() or int(mode.get("version",-1))!=int(binding.get("version",-2)): return false
		if int(mode.get("areaId",area_id))!=area_id or int(mode.get("actorId",actor_id))!=actor_id: return false
	return true
func target_preview_descriptor() -> Dictionary:
	# Original NetworkSpellTargeting.presentation: 57/2 supplies the active
	# server-script shape, while 57/1 overrides a spell's shape fields only.
	# The visible ground shader is a separate render owner.
	if target.is_empty(): return {}
	var type:=int(target.get("type",0))
	if type==45:
		var script_data: Variant=state.get("scriptTargetingData")
		return script_data.duplicate(true) if server_target_current(target) and script_data is Dictionary else {}
	var item_plan: Variant=target.get("itemPlan")
	var spell_id:=int(item_plan.get("definition",{}).get("id",-1)) if type==1 and item_plan is Dictionary else int(target.get("spellId",target.get("intParam",-1)))
	if spell_id<0 or type not in [1,2,4,44]: return {}
	var spell: Dictionary=rules.row("spells",spell_id)
	if spell.is_empty(): return {}
	var overrides: Variant=state.get("spellTargetingOverrides",{})
	var override: Dictionary={}
	if overrides is Dictionary:
		var selected: Variant=overrides.get(spell_id,overrides.get(str(spell_id),{}))
		if selected is Dictionary: override=selected
	var shape_name:=str(Rules.cell(spell,"TargetShape","")).to_lower()
	var shape:=int({"sphere":1,"rectangle":2,"cone":3,"hsphere":4}.get(shape_name,0))
	var range_class:=str(Rules.cell(spell,"Range",""))
	var range_index:=int({"P":1,"T":1,"S":2,"M":3,"L":4}.get(range_class,-1))
	var range_value:=0.0
	if range_index>=0:
		var ranges: Variant=rules.tables.get("ranges")
		if ranges is Dictionary: range_value=float(MovementRate.native_float_entry(ranges,range_index,"PrimaryRange").get("value",0.0))
	var x_value: Variant=Rules.cell(spell,"TargetSizeX",0)
	var y_value: Variant=Rules.cell(spell,"TargetSizeY",0)
	var size_x:=float(x_value) if x_value is int or x_value is float or str(x_value).is_valid_float() else 0.0
	var size_y:=float(y_value) if y_value is int or y_value is float or str(y_value).is_valid_float() else 0.0
	return {"shape":int(override.get("shape",shape)),"sizeX":float(override.get("sizeX",size_x)),"sizeY":float(override.get("sizeY",size_y)),"flags":int(override.get("flags",Rules.number(Rules.cell(spell,"TargetFlags"),0))),"range":range_value,"spellId":spell_id,"featId":-1}
func target_cursor(id: int,has_ground: bool=false) -> Dictionary:
	if int(target.get("type",0)) in [6,7,40,41]:
		var kind:=int(objects.get(id,{}).get("objectType",0));var type:=int(target.type)
		var valid: bool=kind in [5,6,7,9,10] if type==40 else kind in [5,9,10] and id!=actor_id if type==7 else kind==5 and id!=actor_id
		var good: int={6:11,7:7,40:17,41:37}[type]
		return {"valid":valid,"id":good if valid else good+2,"centered":false,"allow_pressed":true}
	if int(target.get("type",0))==10:
		var valid: bool=id!=actor_id and int(objects.get(id,{}).get("objectType",0))==5
		return {"valid":valid,"id":29 if valid else 31,"centered":false,"allow_pressed":true}
	if target.is_empty(): return {}
	var type:=int(target.get("type",0)); var object: Dictionary=objects.get(id,{})
	var kind:=int(object.get("objectType",2 if has_ground else 0)); var spell_id:=int(target.get("spellId",target.get("intParam",-1)))
	if type==45:
		var result: Dictionary=preload("res://systems/native_data/mouse_cursor.gd").target(target,kind,false)
		if not server_target_current(target): result.valid=false; result.id=int(target.get("badCursor",31))
		return result
	if type==1:
		var plan: Dictionary=target.get("itemPlan",{})
		if plan.is_empty():return {"valid":false,"id":31,"centered":false,"allow_pressed":true}
		var valid:=str(plan.get("mode",""))=="self" and id==actor_id
		var cursor:=int(plan.get("flags",31))
		for pair in plan.get("targetTypes",[]):
			if int(pair[0])==kind:valid=true;cursor=int(pair[1]);break
		if valid and bool(plan.get("creatureVeto",false)):
			var providers:=preload("res://systems/native_data/native_item_quickbar.gd").new()
			providers.configure({"registry":objects,"local_object_id":actor_id},owner_ui.text.tables)
			valid=not preload("res://systems/native_data/native_network_item_input.gd").item_creature_target_veto(int(plan.itemId),int(plan.packed),id,providers)
		return {"valid":valid,"id":cursor if valid else int(plan.get("flags",31)),"centered":false,"allow_pressed":true}
	if type==4:
		var feat_plan: Dictionary=target.get("featPlan",{})
		if feat_plan.is_empty():feat_plan=preload("res://systems/native_data/native_network_feat_input.gd").prepare_feat_target({"featId":int(target.get("intParam",0)),"auxiliary":int(target.get("auxiliary",(int(target.get("intParam",0))>>16)&65535))},feat_rules)
		var allowed:=str(feat_plan.get("mode",""))=="self" and id==actor_id or preload("res://systems/native_data/native_network_feat_input.gd").feat_target_allowed(feat_plan.get("definition",{}),object)
		return {"valid":allowed,"id":29 if allowed else 31,"centered":false,"allow_pressed":true}
	var spell_plan: Variant=target.get("spellPlan")
	var mask:=int(spell_plan.get("definition",{}).get("targetType",0)) if type in [2,44] and spell_plan is Dictionary else Rules.number(Rules.cell(rules.row("spells",spell_id),"TargetType"),0)&65535
	var result: Dictionary=preload("res://systems/native_data/mouse_cursor.gd").target(target,kind,id==actor_id,mask)
	if result.get("valid",false) and type in [2,44] and spell_plan is Dictionary:
		var veto:=preload("res://systems/native_data/native_network_spell_input.gd").spell_creature_target_veto(int(target.get("intParam",-1)),actor(),object,rules)
		if veto:result.valid=false;result.id=31
	return result
func cast_target(id: int,point: Vector3,world_pointer: bool=false,failure_origin: String="") -> void:
	if target.is_empty(): return
	var binding:=target.duplicate(); var type:=int(binding.get("type",0))
	var source_failure: String=""
	if not world_pointer:source_failure=failure_origin if not failure_origin.is_empty() else str(binding.get("failureOrigin",""))
	# network_spell_targeting.js:radial/radialInnate reject a family root.
	# Its children must be chosen by the family menu before dispatch.
	if type in [2,44] and rules.spell_family(int(binding.get("intParam",-1))):
		cancel_target(); target_prompt.text="Choose a spell variant before casting"; target_prompt.show(); return
	if type in [6,7,40,41]:
		if not target_cursor(id).get("valid",false):return
		cancel_target()
		if type==40:command({"kind":"examine","targetId":id})
		elif type==41:command({"kind":"native-barter","operation":"start","targetId":id})
		else:command({"kind":"interact","targetId":id,"action":"conversation.start" if type==6 else "combat.attack"})
		return
	if type==10:
		if not target_cursor(id).get("valid",false): return
		cancel_target(); command({"kind":"native-activity","activityId":int(binding.intParam),"targetId":id}); return
	if type==45:
		if not server_target_current(binding):
			cancel_target()
			if source_failure in ["quickbar","party"]:quickbar_failure("Server target selection was replaced")
			return
		var kind:=int(objects.get(id,{}).get("objectType",2))
		if not NetworkTargeting.allowed(binding,kind): target_prompt.text="Choose a valid target for the server action."; return
		cancel_target(); submit_target({"kind":"native-script-target","version":int(binding.version),"targetId":INVALID if id<0 else id,"position":[point.x,-point.z,point.y]},world_pointer,source_failure); return
	if type==1:
		var plan: Dictionary=binding.get("itemPlan",{})
		if plan.is_empty() or not target_cursor(id,true).get("valid",false):return
		var providers:=preload("res://systems/native_data/native_item_quickbar.gd").new()
		providers.configure({"registry":objects,"local_object_id":actor_id},owner_ui.text.tables)
		var request: Dictionary=preload("res://systems/native_data/native_network_item_input.gd").confirm_item_target(plan,INVALID if id<0 else id,[point.x,-point.z,point.y],providers)
		cancel_target();submit_target(request,world_pointer,source_failure);return
	if type in [2,44] and not target_cursor(id,true).get("valid",false):return
	if type==4:
		var feat_plan: Dictionary=binding.get("featPlan",{})
		if str(feat_plan.get("mode",""))!="self" and not target_cursor(id,true).get("valid",false):return
	if type==3 and (not objects.has(id) or int(objects[id].get("objectType",0)) not in ([9,10] if int(binding.intParam)==9 else [5])): target_prompt.text="Choose a valid target for this skill."; return
	cancel_target()
	var message:={"kind":"native-cast" if type==2 else "native-spell-like" if type==44 else "native-feat" if type==4 else "native-skill","targetId":INVALID if id<0 else id,"position":[point.x,-point.z,point.y]}
	if type in [2,44]: message.spellId=int(binding.intParam); message.classIndex=int(binding.get("classIndex",0)); message.domainLevel=int(binding.get("domainLevel",0)); message.metamagic=int(binding.get("metamagic",0)); message.casterLevel=int(binding.get("domainLevel",0)); message.spontaneous=int(binding.get("spontaneous",0))
	elif type==4: message.featId=int(binding.intParam)&65535; message.auxiliary=int(binding.get("auxiliary",(int(binding.intParam)>>16)&65535))
	else: message.packedSkill=int(binding.intParam); message.position=[0,0,0]
	if type in [2,44,4]:submit_target(message,world_pointer,source_failure)
	else:command(message)
func world_pointer_miss() -> void:
	if is_instance_valid(target_prompt):target_prompt.text="Select walkable ground";target_prompt.show()
func world_click(hit: Dictionary) -> bool:
	if target.is_empty(): return false
	if int(target.get("type",0))==45 and not server_target_current(target):
		cancel_target();world_target_failure("Server target selection was replaced");return true
	var cursor:=target_cursor(int(hit.get("id",-1)),not hit.is_empty())
	if not cursor.get("valid",false):
		var reason:="That target is not valid for this server action" if int(target.get("type",0))==45 else "That target is not valid for this item" if int(target.get("type",0))==1 else "That target is not valid for this action"
		world_target_failure(reason)
		return true
	cast_target(int(hit.get("id",-1)),hit.get("position",Vector3.ZERO),true); return true
func world_target_failure(reason: String) -> void:
	if is_instance_valid(owner_ui) and is_instance_valid(owner_ui.text) and owner_ui.text.diagnostics.size()<100:owner_ui.text.diagnostics.append({"code":"network.spell-target-failed","message":reason})
	if is_instance_valid(target_prompt):target_prompt.text=reason;target_prompt.show()
func input_request(message: Dictionary) -> void:
	var kind:=str(message.kind)
	if kind.begins_with("quickbar-") and not owner_ui.tables_ready: return
	match kind:
		"sheet-open","sheet-page":
			if kind=="sheet-page" and (not sheet.wanted or message.has("viewId") and int(message.viewId)!=sheet.view_id):return
			var scope:=sheet_request_scope()
			if scope.is_empty():
				if not sheet_context.is_empty():retire_sheet_target()
				return
			sheet.page=int(message.get("page",0))
			var panel_request: Dictionary={"kind":"native-panel","panel":"character","open":true,"page":sheet.page}.merged(scope)
			if kind=="sheet-page":
				panel_feedback_serial+=1
				panel_request.requestId=panel_feedback_serial
				panel_feedback_pending[panel_feedback_serial]={"generation":generation,"areaId":area_id,"actorId":actor_id,"page":sheet.page}
			command(panel_request); refresh_sheet()
		"sheet-close":
			var scope:=sheet_request_scope()
			if not scope.is_empty():command({"kind":"native-panel","panel":"character","open":false}.merged(scope))
			sheet_context.clear();signatures.erase("sheet")
		"sheet-select": inspect_sheet_entry(message)
		"spellbook-open","spellbook-query":
			if message.kind=="spellbook-query" and (int(message.get("classIndex",book_class))!=book_class or int(message.get("level",book_level))!=book_level or int(message.get("metamagic",book_meta))!=book_meta):
				book.selected_id=-1
				family_path.clear();family_domain=false
				if (int(message.get("classIndex",book_class))!=book_class or int(message.get("level",book_level))!=book_level) and is_instance_valid(book_frame) and is_instance_valid(book_frame.help_window):book_frame.help_window.hide()
			book_class=int(message.get("classIndex",book_class)); book_level=int(message.get("level",book_level)); book_meta=int(message.get("metamagic",book_meta)); family_path.clear(); family_domain=false; refresh_book()
		"book-family":
			if int(message.viewId)==book.view_id and book.rows.has(int(message.entryId)):
				var entry: Dictionary=book.rows[int(message.entryId)]; book_class=int(entry.classIndex); book_level=int(entry.level); book_meta=int(entry.metamagic); family_domain=bool(entry.get("domain",false)); family_path.append(int(entry.spellId)); refresh_book()
		"book-family-back":
			if int(message.get("viewId",-1))==book.view_id and not family_path.is_empty():
				family_path.pop_back()
				if family_path.is_empty(): family_domain=false
				refresh_book()
		"book-family-close":
			if int(message.get("viewId",-1))==book.view_id: family_path.clear(); family_domain=false; refresh_book()
		"book-inspect":
			if int(message.viewId)==book.view_id and book.rows.has(int(message.entryId)):
				if not family_path.is_empty() and book.state.get("known",[]).any(func(row):return int(row.entryId)==int(message.entryId)):
					family_path.clear(); family_domain=false; refresh_book(); return
				book.receive({"kind":"book-description","viewId":book.view_id,"entryId":message.entryId,"rich":rules.description("spells",int(book.rows[int(message.entryId)].spellId))})
		"book-activate":
			if int(message.viewId)==book.view_id and book.rows.has(int(message.entryId)) and book.rows[int(message.entryId)].canCast: activate(book.rows[int(message.entryId)].binding)
		"book-prepare","book-clear": prepare_spell(message)
		"quickbar-activate":
			var index:=int(message.index)
			if owner_ui.presentation_enabled and not owner_ui.blocks_quickbar_activation() and int(message.quickbarId)==quickbar.quickbar_id and index>=0 and index<quick_bindings.size(): activate(quick_bindings[index],index)
		"quickbar-clear":
			if int(message.quickbarId)==quickbar.quickbar_id: assign(int(message.index),{"type":0})
		"quickbar-move":
			var source_index:=int(message.sourceIndex);var destination_index:=int(message.index)
			if int(message.quickbarId)!=quickbar.quickbar_id or source_index<0 or source_index>=quick_bindings.size() or destination_index<0 or destination_index>=36 or source_index==destination_index or quickbar_pending_assigns.has(destination_index):return
			quickbar_request_serial+=1
			var request_id:=quickbar_request_serial
			quickbar_pending_moves[request_id]={"sourceIndex":source_index,"destinationIndex":destination_index,"binding":quick_bindings[source_index].duplicate(true),"generation":generation,"areaId":area_id,"actorId":actor_id}
			if not assign(destination_index,quick_bindings[source_index],false,request_id):quickbar_pending_moves.erase(request_id)
		"quickbar-assign":
			if int(message.viewId)==book.view_id and book.rows.has(int(message.entryId)) and book.rows[int(message.entryId)].canDrag: assign(int(message.index),book.rows[int(message.entryId)].binding)
		"sheet-assign":
			if int(message.viewId)==sheet.view_id:
				for entry in sheet.state.entries:
					if int(entry.entryId)==int(message.entryId) and entry.canDrag: assign(int(message.index),entry.binding)
		"inventory-shortcut":
			if int(message.viewId)==owner_ui.inventory.ui.view_id and owner_ui.inventory.views.has(int(message.entryId)): assign(int(message.index),{"type":1,"itemId":owner_ui.inventory.views[int(message.entryId)].row.itemId,"intParam":16711935})
		"journal-open":
			var opening_lifetime: Variant=message.get("journalLifetime")
			if not closed and objects.has(actor_id) and opening_lifetime is int and opening_lifetime>0 and journal.wanted and opening_lifetime==journal.journal_lifetime:
				command({"kind":"native-panel","panel":"journal","open":true,"journalLifetime":journal.journal_lifetime}); refresh_journal(int(message.get("page",0)))
		"journal-page":
			if journal.wanted and int(message.get("viewId",-1))==journal.view_id: refresh_journal(int(message.get("page",0)))
		"journal-close":
			var closing_lifetime: Variant=message.get("journalLifetime")
			if not closed and objects.has(actor_id) and closing_lifetime is int and closing_lifetime>0 and not journal.wanted and closing_lifetime==journal.journal_lifetime:
				command({"kind":"native-panel","panel":"journal","open":false,"journalLifetime":journal.journal_lifetime})
		"players-open": refresh_players()
		"players-attitude":
			if int(message.viewId)==players.view_id and int(message.entryId)<players.rows.size(): command({"kind":"native-player-attitude","playerId":players.rows[int(message.entryId)].playerId,"likes":message.likes})
		"map-open": refresh_map(true)
		"radial-select": radial_select(message)
		"radial-back":
			if int(message.get("requestId",-1))==radial.request_id and int(message.get("menuId",-1))==radial.menu_id and radial_stack.size()>1: radial_stack.pop_back(); show_radial(radial_stack[-1])
		"radial-shortcut":
			if can_radial_shortcut(message) and radial_entries.has(int(message.slot)): assign(int(message.index),radial_entries[int(message.slot)].binding,false)
		"item-radial-shortcut":
			var source: Dictionary=message.duplicate(); source.kind="item-radial-entry"
			var binding: Dictionary=owner_ui.inventory.item_context.binding(source)
			if int(message.get("quickbarId",-1))==quickbar.quickbar_id and not binding.is_empty(): assign(int(message.index),binding,false)
		"radial-cancel": radial_stack.clear(); pending_shortcuts.clear(); world_context.clear()
func prepare_spell(message: Dictionary) -> void:
	if int(message.get("viewId",-1))!=book.view_id or not book.rows.has(int(message.entryId)): return
	var entry: Dictionary=book.rows[int(message.entryId)]
	if not book.wanted or not bool(book.state.get("prepared",false)) or int(entry.spellId)<0 or bool(entry.get("pending",false)): return
	if message.kind=="book-clear" and not book.state.memory.any(func(row):return int(row.entryId)==int(entry.entryId)): return
	var destination: Dictionary=book.rows.get(int(message.get("destinationId",-1)),{})
	for row in [entry,destination]:
		if not row.is_empty() and int(row.get("slot",-1))>=0:
			var actual:=Preparation.slot(actor(),row)
			var expected: Array=[-1,0,false] if int(row.spellId)<0 else [int(row.spellId),int(row.metamagic),bool(row.domain)]
			if actual.is_empty() or actual.slice(0,3)!=expected:
				refresh_book(); book.notice.text="Spell preparations changed on the server. Select the current slot and try again."; return
	if message.has("destinationId") and (destination.is_empty() or int(destination.get("slot",-1))<0): return
	if not destination.is_empty() and (int(destination.classIndex)!=int(entry.classIndex) or int(destination.level)!=int(entry.level)): return
	var slot:=int(destination.get("slot",entry.get("slot",-1)))
	if slot<0 and message.kind!="book-clear":
		for candidate in book.state.memory:
			if int(candidate.spellId)<0 and not candidate.get("pending",false) and int(candidate.level)==int(entry.level) and int(candidate.classIndex)==int(entry.classIndex): slot=int(candidate.slot); destination=candidate; break
	if slot<0: book.notice.text="No available preparation slot at this spell level."; return
	if destination.is_empty() and message.kind!="book-clear": destination=entry
	var plan:=Preparation.plan(entry,destination,message.kind=="book-clear",rules.meta_cost)
	if not str(plan.error).is_empty(): book.notice.text=plan.error; return
	var result:=preparation.submit(actor(),[generation,area_id,actor_id],plan.writes,Time.get_ticks_msec())
	if not str(result.error).is_empty(): book.notice.text=result.error; return
	for value in result.requests: command(value)
	if not result.requests.is_empty(): refresh_book()
func refresh_journal(page: int=0) -> void:
	serial+=1; var entries: Array=[]; var data: Dictionary=state.get("journal",{})
	journal_frame.observe()
	if page<2: entries=journal_frame.model.rows(page,owner_ui.text,actor_id,(journal_frame.minutes_per_hour*1440000)&0xffffffff)
	elif page==2:
		# network_panels.js:74:458 selects the server's nonquest records
		# for Notes. Preserve their received order beside the editable notebook.
		for entry in data.get("entries",[]):
			var source: Dictionary=entry[1] if entry is Array else entry
			if bool(source.get("isQuest",false)):continue
			var row:=source.duplicate(true)
			row.title=owner_ui.text.rich(source.get("title",{"text":str(source.get("tag","Journal entry"))}),actor_id)
			row.description=owner_ui.text.rich(source.get("description",{"strRef":source.get("strRef",-1)}),actor_id)
			entries.append(row)
	elif page==3:
		for entry in data.get("worldEntries",[]):
			var source: Dictionary=entry[1] if entry is Array else entry; var row:=source.duplicate(true)
			row.key="world:"+str(entry[0] if entry is Array else source.get("id",0)); row.title=owner_ui.text.rich(source.get("title",{"text":str(source.get("tag","Journal entry"))}),actor_id); row.description=owner_ui.text.rich(source.get("description",{"strRef":source.get("strRef",-1)}),actor_id); entries.append(row)
	journal.receive({"kind":"journal-view","viewId":serial,"page":page,"entries":entries,"loaded":data.get("loaded",false)})
func refresh_players() -> void:
	serial+=1; var rows: Array=[]
	rows=players_frame.rows()
	players.receive({"kind":"players-view","viewId":serial,"rows":rows})
func refresh_map(force: bool=false) -> void:
	var area: Dictionary=state.get("area",{}); var exploration: Array=actor().get("playerState",{}).get("mapExploration",{}).get(str(area_id),[])
	var area_changed:=changed("map-area",[area_id,area.get("width",0),area.get("height",0),area.get("tileset",""),area.get("tiles",[])])
	if force or area_changed:
		map_jobs.clear(); map_queue.clear(); map_tile_queued.clear(); map_set_job=-1; map_definition.clear()
		var placements: Variant=area.get("tiles",null)
		if not placements is Array or placements.size()!=int(area.get("width",0))*int(area.get("height",0)):
			map_frame.report_failure("Native map tile placements are unavailable")
			return
		serial+=1; map_view=serial; map_cells=[]
		for tile in area.get("tiles",[]): map_cells.append(map_cells.size())
		var controls:={"pin":map_cells.size(),"hilite":map_cells.size()+1,"down":map_cells.size()+2,"player":map_cells.size()+3}
		area_map.receive({"kind":"map-view","viewId":map_view,"width":int(area.get("width",0)),"height":int(area.get("height",0)),"cells":map_cells,"controls":controls})
		for definition in [["pin","CTL_MAP_PIN","up"],["hilite","CTL_MAP_PIN","hilite"],["down","CTL_MAP_PIN","down"],["player","CTL_MAP_XMARKER","up"]]:
			map_queue.append({"index":controls[definition[0]],"model":definition[1],"clip":definition[2],"overrides":{},"turn":0})
		map_set_job=art.assets.request(str(area.get("tileset","")),2013,"bytes")
		signatures.erase("map-exploration")
	var pin_projection: Dictionary=map_pins(area,exploration)
	if not str(pin_projection.get("error","")).is_empty():
		signatures.erase("map-exploration")
		quickbar_failure(str(pin_projection.error),"network.hud-action-failed")
		return
	if bool(pin_projection.get("pending",false)):
		signatures.erase("map-exploration")
		return
	var pins: Array=pin_projection.rows
	if changed("map-exploration",[exploration,pins]):
		area_map.receive({"kind":"map-state","viewId":map_view,"explored":exploration,"pins":pins}); prepare_map_level(map_frame.level)
	var pose: Array=actor().get("replicated",{}).get("position",[])
	if pose.size()==3:
		var board=area_map.board; board.point=map_point(pose,area)
		var orientation: Variant=actor().get("replicated",{}).get("orientation",[0,1,0])
		var direction: Vector3
		if orientation is Dictionary and not orientation.has("vector"):
			var radians: float=Float32.f(float(orientation.get("yaw",0))*PI/180.0)
			direction=Vector3(-NativeMath.native_sinf(radians),NativeMath.native_cosf(radians),0)
		else: direction=preload("res://systems/network_motion.gd").facing(orientation)
		var x: float=Float32.f(direction.x); var y: float=Float32.f(direction.y)
		board.heading=0.0 if x==0 and y==0 else Float32.f(NativeMath.native_atan2f(Float32.f(-x),y)*57.2957763671875)
		board.queue_redraw()
func map_cvtt(value: float) -> int:
	return int(value) if is_finite(value) and value>=-2147483648.0 and value<2147483648.0 else -2147483648
func map_axis(value: float,size: int,scale: float,pin: bool) -> float:
	var tenth:float=Float32.f(0.1); var pixel:float=Float32.f(0.01); var half:float=Float32.f(0.5)
	var projected:float=Float32.f(Float32.f(Float32.f(Float32.f(value)*tenth)*scale)-Float32.f(Float32.f(Float32.f(float(size))*scale)*half))
	if pin:
		projected=Float32.f(Float32.f(projected/pixel)+half)
		projected=Float32.f(Float32.f(float(map_cvtt(projected)))*pixel)
	return projected
func map_point(position: Array,area: Dictionary,pin: bool=false) -> Array:
	if position.size()<3:return []
	var zoom:int=int(area_map.board.zoom) if is_instance_valid(area_map) and is_instance_valid(area_map.board) else 16
	var scale:float=Float32.f(Float32.f(float(zoom))*Float32.f(0.01))
	# MapBoard centers canonical zoom-16 coordinates and scales them by zoom/16.
	var board_scale:float=float(zoom)/16.0
	var x:float=map_axis(float(position[0]),int(area.get("width",0)),scale,pin)/board_scale
	var y:float=map_axis(float(position[1]),int(area.get("height",0)),scale,pin)/board_scale
	var z:float=Float32.f(Float32.f(Float32.f(float(position[2]))*Float32.f(0.1))*scale)
	if not pin and z<Float32.f(-0.09):z=Float32.f(-0.09)
	return [x,y,z]
func map_pins(area: Dictionary,explored: Array) -> Dictionary:
	var entries: Dictionary={}; var result: Array=[]; var width:=int(area.get("width",0))
	for pin in area.get("mapPins",[]): entries["0:"+str(pin.get("id",entries.size()))]={"type":0,"reference":int(pin.get("id",0))&0xffffffff,"value":pin}
	for entry in state.get("mapPins",[]):
		var pin: Dictionary=entry[1] if entry is Array else entry
		if int(pin.get("areaId",area_id))==area_id:
			var reference:=int(pin.get("id",entry[0] if entry is Array else entries.size()))&0xffffffff; entries["0:"+str(reference)]={"type":0,"reference":reference,"value":pin}
	for pin in area.get("playerMapPins",[]):
		var reference:=int(pin.get("index",entries.size()))&0xffffffff; entries["1:"+str(reference)]={"type":1,"reference":reference,"value":pin}
	for key in entries:
		var entry: Dictionary=entries[key]; var pin: Dictionary=entry.value
		var position: Array=pin.get("position",[])
		if position.size()<2: continue
		var tenth:float=Float32.f(0.1)
		var x:=map_cvtt(Float32.f(Float32.f(float(position[0]))*tenth)); var y:=map_cvtt(Float32.f(Float32.f(float(position[1]))*tenth)); var index:=y*width+x
		var visible: bool=Rules.flag(pin.get("enabled",true)) and x>=0 and x<width and y>=0 and y<int(area.get("height",0)) and index<explored.size() and int(explored[index])==1
		var source: Variant=pin.get("name",pin.get("text",{}))
		var resolved: Dictionary=owner_ui.text.network_resolve(source,actor_id)
		if bool(resolved.get("pending",false)):return {"pending":true}
		if not bool(resolved.get("ready",false)):return {"error":str(resolved.get("error",resolved.get("reason","Native map pin text is unavailable")))}
		var label: String=str(resolved.body)
		var encoded: Dictionary=preload("res://systems/native_data/native_gff_text.gd").encode(label)
		if encoded.has("error"):return {"error":str(encoded.error)}
		result.append({"key":key,"type":entry.type,"reference":entry.reference,"viewId":map_view,"scope":[generation,area_id,actor_id],"position":position.duplicate(),"text":label,"visible":visible,"point":map_point(position,area,true),"rich":preload("res://systems/native_data/rich_text.gd").parse(label)})
	return {"rows":map_frame.apply_overlays(result) if is_instance_valid(map_frame) else result}
func map_prepared(id: int,result: Dictionary) -> void:
	if closed or id!=map_set_job or not area_map.wanted or area_map.view_id!=map_view: return
	map_set_job=-1
	if not str(result.error).is_empty(): area_map.note.text="Map artwork unavailable: "+str(result.error); return
	map_definition=preload("res://systems/native_data/area_definition.gd").new().parse_set(result.bytes.get_string_from_utf8())
	prepare_map_level(map_frame.level)
func prepare_map_level(level: int) -> void:
	if map_definition.is_empty() or not area_map.wanted or level<0 or level>2: return
	var area: Dictionary=state.get("area",{}); var tiles: Array=map_definition.get("tiles",[])
	for index in area.get("tiles",[]).size():
		var key:=str(level)+":"+str(index)
		if map_tile_queued.has(key): continue
		var tile: Dictionary=area.tiles[index]; var fields: Dictionary=tile.get("fields",{}); var tile_id:=int(fields.get("14",tile.get("id",0))); var turn:=int(fields.get("24",tile.get("orientation",0)))
		if tile_id<0 or tile_id>=tiles.size():
			map_frame.report_failure("Map tile definition "+str(tile_id)+" is unavailable"); return
		if turn<0 or turn>3:
			map_frame.report_failure("Native map tile orientation is unavailable"); return
		var raster:=str(tiles[tile_id].get("mapImage",""))
		if raster.is_empty():map_frame.report_failure("Native tile map image is unavailable");return
		map_tile_queued[key]=true
		map_queue.append({"index":index,"bank":level,"model":preload("res://systems/native_data/area_map_layout.gd").ICONS[level],"clip":"","overrides":{"gui_replace01":raster},"turn":turn})
func pump_map_art() -> void:
	if map_queue.is_empty() or closed or not area_map.wanted or area_map.view_id!=map_view or art.models.pending.size()>=80: return
	for count in mini(2,map_queue.size()):
		var job: Dictionary=map_queue.pop_front(); var key: String=art.request_model(str(job.model),str(job.clip),job.overrides,int(job.turn))
		if key.is_empty(): map_frame.report_failure("Some installed map artwork could not be loaded."); continue
		if not map_jobs.has(key): map_jobs[key]=[]
		map_jobs[key].append({"view":map_view,"index":job.index,"bank":int(job.get("bank",-1))})
		if art.textures.has(key): map_art_ready(key,art.textures[key],art.bounds.get(key,{}))
func map_art_ready(key: String,texture: Texture2D,bounds: Dictionary) -> void:
	if closed or not map_jobs.has(key): return
	if bounds.is_empty(): map_frame.report_failure("Original map tile artwork has no bounds: "+key); return
	for job in map_jobs[key]:
		if area_map.wanted and int(job.view)==area_map.view_id:
			var image: Dictionary={"texture":texture,"min":bounds.min,"max":bounds.max}; var bank:=int(job.get("bank",-1))
			if bank>=0:
				var pixels: int=preload("res://systems/native_data/area_map_layout.gd").PIXELS[bank]
				if not area_map.board.tile_banks.has(pixels): area_map.board.tile_banks[pixels]={}
				area_map.board.tile_banks[pixels][int(job.index)]=image
			if bank in [-1,1]: area_map.board.art[int(job.index)]=image
	map_jobs.erase(key); area_map.board.queue_redraw()
func entry(slot: int,label: String,action: String,icon: String="",extra: Dictionary={}) -> Dictionary:
	var value:={"slot":slot,"label":label,"action":action,"icon":icon,"submenu":extra.has("children") or extra.has("menu"),"disabled":false,"canDrag":extra.has("binding"),"uses":null}; value.merge(extra,true); return value
func player_target(id: int) -> bool:
	for entry in state.get("players",[]):
		var player: Dictionary=entry[1] if entry is Array else entry
		if int(player.get("objectId",-1))==id or int(player.get("character",{}).get("id",-1))==id: return true
	return false
func world_member_lifetime(id: int) -> Variant:
	var source: Variant=objects.get(id)
	if not source is Dictionary or source.get("id")!=id or source.get("objectType")!=5 or source.get("areaId")!=area_id or source.get("replicationRemoved")==true or source.get("destroyed")==true:return null
	var lifetime: Variant=source.get("clientKnownLifetime")
	return int(lifetime) if CreatureRadial.integer(lifetime,9007199254740991) and lifetime>0 else null
func capture_world_scope(id: int) -> Dictionary:
	var actor_lifetime: Variant=world_member_lifetime(actor_id);var target_lifetime: Variant=world_member_lifetime(id)
	if closed or actor_lifetime==null or target_lifetime==null:return {}
	return {"owner":get_instance_id(),"generation":generation,"area":area_id,"actor":actor_id,"target":id,"actorLifetime":actor_lifetime,"targetLifetime":target_lifetime}
func world_scope_valid() -> bool:
	if world_context.is_empty():return true
	return not closed and world_context.get("owner")==get_instance_id() and world_context.get("generation")==generation and world_context.get("area")==area_id and world_context.get("actor")==actor_id and world_context.get("target")==radial_target and world_member_lifetime(actor_id)==world_context.get("actorLifetime") and world_member_lifetime(radial_target)==world_context.get("targetLifetime")
func can_radial_shortcut(data: Dictionary) -> bool:
	if not world_context.is_empty() and not world_scope_valid():retire_current_radial(radial.request_id);return false
	var value: Variant=radial_entries.get(int(data.get("slot",-1)))
	if value is Dictionary and not QuickbarAssociates.entry_valid(self,value):retire_current_radial(radial.request_id);return false
	return radial.can_shortcut(data)
func owned_associate_creature(object:Dictionary,portrait:String,origin:String) -> bool:
	var permission:=PlayerIdentity.permission(state.get("gameMasterPermission"))
	if permission.available and permission.permission:return false # DM contexts remain separate.
	var master:Variant=object.get("replicated",{}).get("master")
	if CreatureRadial.integer(master,4294967295) and int(master)!=actor_id:return false
	var missing:Array=[]
	if not permission.available:missing.append("connection.permission")
	if not CreatureRadial.integer(master,4294967295):missing.append("clicked.replicated.master")
	var scope:=capture_world_scope(radial_target)
	if scope.is_empty():missing.append("current-creature-disclosure-lifetime")
	associate_creature_radial.rules=rules
	var model:=associate_creature_radial.project(actor(),object,{"dmPermission":permission.permission if permission.available else null})
	for key in model.missing:
		if not missing.has(key):missing.append(key)
	if not missing.is_empty() or not model.available:
		world_radial_coverage={"coverage":"owned-associate-context-unavailable","origin":origin,"missing":missing,"pending":model.pending};retire_current_radial(radial.request_id);return true
	world_context=scope
	world_radial_coverage={"coverage":model.coverage,"origin":origin,"missing":[],"pending":[],"permissionSource":permission.source}
	show_radial({"title":owner_ui.text.name(null,radial_target),"entries":model.entries,"center":portrait,"portraitCenter":true},true)
	return true
func normal_other_creature(object: Dictionary,portrait: String) -> bool:
	# Only the proved world-origin normal993790 path is specialized here.
	# Portraits, owned associates and DM roots retain separate source owners.
	var permission: Dictionary=PlayerIdentity.permission(state.get("gameMasterPermission"))
	if permission.available and permission.permission:
		world_radial_coverage={"coverage":"legacy-dm-context-unaccepted","missing":[],"pending":["dm-root"]};return false
	var missing: Array=[]
	if not permission.available:missing.append("connection.permission")
	var master: Variant=object.get("replicated",{}).get("master")
	if not CreatureRadial.integer(master,4294967295):missing.append("clicked.replicated.master")
	elif permission.available and int(master)==actor_id:
		world_radial_coverage={"coverage":"legacy-owned-associate-unaccepted","missing":[],"pending":["owned-associate-root"]};return false
	var context: Dictionary=PlayerIdentity.normal_context(state,radial_target)
	for key in context.missing:
		if not missing.has(key):missing.append(key)
	var scope: Dictionary=capture_world_scope(radial_target)
	if scope.is_empty():missing.append("current-creature-disclosure-lifetime")
	if not missing.is_empty():
		world_radial_coverage={"coverage":"normal-other-context-unavailable","missing":missing,"pending":[]};retire_current_radial(radial.request_id);return true
	context.skills={"0":rules.skill_admission(actor(),0),"13":rules.skill_admission(actor(),13)}
	other_creature_radial.rules=rules
	var model: Dictionary=other_creature_radial.project(actor(),object,context)
	world_context=scope
	world_radial_coverage={"coverage":model.coverage,"missing":model.missing.duplicate(),"pending":model.pending.duplicate(),"permissionSource":permission.source,"playerSource":context.playerLookup.source}
	var center: String=portrait if model.portrait and not portrait.is_empty() else "ir_examine"
	show_radial({"title":owner_ui.text.name(null,radial_target),"entries":model.entries,"center":center,"portraitCenter":model.portrait and not portrait.is_empty()},true)
	return true
func open_radial(hit: Dictionary,point: Vector2) -> void:
	if not target.is_empty(): cancel_target(); target_prompt.text="Spell targeting cancelled"; target_prompt.show(); return
	if actor().is_empty():return
	var invalid_innate: String=AbilityRadial.replicated_innate_error(actor())
	if not invalid_innate.is_empty():
		buff_report("network.radial-menu-failed",invalid_innate,{})
		return
	var origin:=str(hit.get("origin","world"))
	if origin not in ["world","portrait","keyboard"]:return
	if origin=="world":
		var clicked_id:=int(hit.get("id",-1));var clicked: Dictionary=objects.get(clicked_id,{})
		var source_kind: String="ground" if clicked_id<0 else {7:"trigger",5:"creature",6:"item",9:"placeable",10:"door"}.get(int(clicked.get("objectType",-1)),"")
		var world_point: Variant=hit.get("position",Vector3.ZERO)
		if source_kind.is_empty() or not world_point is Vector3 or not world_point.is_finite():return
		var access=owner_ui.get("gui_panel_access")
		if not is_instance_valid(access) or not access.context_attempt(source_kind,INVALID if clicked_id<0 else clicked_id,Vector3(world_point.x,-world_point.z,world_point.y)):return
	# Portrait851020 has a separate source owner and no world GUI26/access gate.
	# Keyboard action62's original caller is not yet verified; retain its UI open.
	retire_shortcut_context(false)
	world_radial_coverage.clear()
	owner_ui.inventory.item_context.cancel()
	radial_target=int(hit.get("id",-1)); radial_position=hit.get("position",Vector3.ZERO); radial_stack.clear(); pending_shortcuts.clear(); radial.open_at(point,radial_target,radial_position,false)
	var object: Dictionary=objects.get(radial_target,{})
	var options: Dictionary={"castMenu":func():return radial_cast_menu(),"abilityMenu":func():return {"title":"Special ability","entries":ability_entries({"kind":"abilities"})},"commandMenu":func():return network_party_command_menu()}
	var menu: Dictionary=ActionMenu.network_radial_actions(object if not object.is_empty() else null,actor(),options)
	show_radial(menu,true)
func radial_cast_menu() -> Dictionary:
	var entries:=spell_branches()
	return {"title":"Spell","entries":entries,"spellBuildFailed":not spell_rules.uses_failure.is_empty()}
func network_party_command_menu() -> Dictionary:
	var entries: Array=[]
	for index in PARTY_COMMANDS.size():
		var source: Array=PARTY_COMMANDS[index]
		entries.append({"slot":index+2,"label":str(source[1]),"icon":str(source[2]),"quickChat":int(source[0]),"labelRef":[0x14e1,0x2aa,0x5c5,0x5c2,0x5cb][index],"action":"associate.quickChat"})
	return {"title":"Issue command","entries":entries}
func party_commands(id: int=-1) -> Array:
	var result: Array=[]
	for row in PARTY_COMMANDS: result.append(entry(result.size(),str(row[1]),"power",str(row[2]),{"binding":{"type":42,"intParam":int(row[0])}}))
	if id>=0:
		var type:=int(objects.get(id,{}).get("replicated",{}).get("field908",0))
		for command_id in [-9] if type==2 else [-8] if type==3 else [-18,-19,-20] if type==1 else []:
			var description: Array={-8:["Unsummon","IFE_NOFAMILIAR"],-9:["Unsummon","IFE_NOFAMILIAR"],-18:["Unlock","IR_UNLOCK"],-19:["Inventory","IR_INVENTORY"],-20:["Disarm trap","IR_HAND_TRAP"]}[command_id]
			result.append(entry(result.size(),str(description[0]),"power",str(description[1]),{"binding":{"type":39,"intParam":command_id,"associateType":1,"associateId":id}}))
		if type==3: result.append(entry(result.size(),"Possess familiar","power","IFE_POSSESS",{"binding":{"type":38}}))
	return result
func spell_branches(target_mask: int=0) -> Array:
	return spell_entries({"kind":"spell-root"},target_mask)
func spell_entries(menu: Dictionary,target_mask: int=0) -> Array:
	var ctx:=feat_context(); ctx.filter=target_mask if target_mask else 65535
	var object: Dictionary=objects.get(radial_target,{})
	ctx.targetBit=4 if radial_target<0 or radial_target==INVALID else (1 if radial_target==actor_id else 2) if int(object.get("objectType",0))==5 else {6:8,10:16,9:32,7:64}.get(int(object.get("objectType",0)),0)
	var result:=spell_rules.menu(ctx,menu)
	if not spell_rules.uses_failure.is_empty():
		if target_mask==8:owner_ui.inventory.item_target_failure(spell_rules.uses_failure)
		else:quickbar_failure(spell_rules.uses_failure,"network.quickbar-ui-failed" if pending_shortcuts.has("index") else "network.radial-menu-failed")
		return []
	# The old class conversion helper throws on a missing active class cell;
	# discard this whole page rather than offering a nonconverted spell action.
	if not spell_rules.conversion_failure.is_empty():return []
	for at in result.size():
		if result[at].has("epicFeat"): result[at]=decorate_feat(feat_rules.leaf(ctx,int(result[at].epicFeat)),int(result[at].slot),ctx)
	return result.filter(func(value):return not value.is_empty())
func spell_radial(binding: Dictionary,path: Array,target_mask: int=0,uses: Variant=null,innate_mode: bool=false) -> Dictionary:
	var id:=int(binding.intParam); var children: Array=[]
	if innate_mode or path.size()<16:
		for child in rules.spell_children(id,path):
			var next:=binding.duplicate(); next.intParam=child; var value:=spell_radial(next,path+[id],target_mask,uses,innate_mode)
			if not value.is_empty():
				value.slot=children.size()
				children.append(value)
	var family:=rules.spell_family(id) if innate_mode else not children.is_empty()
	if target_mask and not family and (Rules.number(Rules.cell(rules.row("spells",id),"TargetType"),0)&target_mask)==0: return {}
	var disabled: bool=not pending_shortcuts.has("index") and ((not innate_mode or not family) and not radial_spell_allowed(id) or uses!=null and int(uses)<1)
	var extra: Dictionary={"children":children} if family else {"binding":binding}
	extra.disabled=disabled; extra.uses=uses
	var icon:=rules.icon("spells",id)
	if innate_mode and icon.is_empty():icon="IR_XABILITY"
	return entry(0,rules.title("spells",id),"branch" if family else "power",icon,extra)
func radial_spell_allowed(id: int) -> bool:
	var mask:=Rules.number(Rules.cell(rules.row("spells",id),"TargetType"),0)&65535
	if radial_target<0: return (mask&4)!=0
	var object: Dictionary=objects.get(radial_target,{})
	var bit: int=(1 if radial_target==actor_id else 2) if int(object.get("objectType",0))==5 else {6:8,10:16,9:32,7:64}.get(int(object.get("objectType",0)),0)
	return (mask&bit)!=0
func feat_context() -> Dictionary:
	var ctx:=feat_rules.context(actor(),radial_target,pending_shortcuts.has("index"))
	var familiar: Variant=preload("res://systems/native_data/native_network_associates.gd").network_familiar(objects,actor())
	if familiar is Dictionary:ctx.familiar=familiar
	return ctx
func ensure_ability_tables() -> bool:
	ability_tables_pending.clear()
	if not rules.text.tables.has("classes"): return false
	for name in spell_rules.dependencies(actor()):
		if name.is_empty() or owner_ui.text.tables.has(name): continue
		ability_tables_pending.append(name)
		if owner_ui.table_jobs.values().has(name): continue
		if not owner_ui.catalog.has_resource(name,2017): owner_ui.text.publish_table(name,{}); continue
		var request_id: int=owner_ui.assets.request(name,2017,"2da",{"immutable_source":true})
		if request_id>=0: owner_ui.table_jobs[request_id]=name
	return ability_tables_pending.is_empty()
func ability_table_ready() -> void:
	dirty=true
	if is_instance_valid(level_owner):
		level_owner.warm()
		if level_up.wanted and not level_owner.draft.is_empty():level_owner.render()
	if radial.active and not radial_stack.is_empty() and (str(radial_stack[-1].get("kind","")).begins_with("spell-") or str(radial_stack[-1].get("kind","")) in ["abilities","class-abilities","ability-classes"]):
		show_radial(radial_stack[-1])
func quickbar_choice_source(kind: String) -> Array:
	# Old NetworkQuickbarView.choices includes every owned item, feat and
	# trained skill, not only the native radial's fixed action sectors.
	var choices: Array=[]
	var controlled: Dictionary=actor()
	if kind=="quickbar-items":
		for raw_id in objects:
			var object: Dictionary=objects[raw_id]
			if int(object.get("objectType",0))!=6 or bool(object.get("replicationRemoved",false)):continue
			var item_id: int=int(raw_id)
			var assigned:=false
			for button in quick_bindings:
				if int(button.get("type",0))==1 and (int(button.get("itemId",INVALID))==item_id or int(button.get("secondaryItemId",INVALID))==item_id):assigned=true;break
			if int(object.get("inventoryLocation",{}).get("ownerId",INVALID))!=actor_id and not assigned:continue
			var item: Dictionary=object.get("item",{})
			choices.append({"label":owner_ui.text.name(item.get("name"),item_id),"binding":{"type":1,"itemId":item_id,"intParam":0xff00ff}})
	elif kind=="quickbar-feats":
		var ids: Array=[]
		var player: Dictionary=controlled.get("playerState",{})
		for id in player.get("feats",[])+player.get("bonusFeats",[]):
			if not ids.has(int(id)):ids.append(int(id))
		for feat in controlled.get("inventoryStats",{}).get("feats",[]):
			if feat is Dictionary and not ids.has(int(feat.get("id",-1))):ids.append(int(feat.get("id",-1)))
		for id in ids:
			choices.append({"label":rules.title("feat",int(id),"FEAT"),"binding":{"type":4,"intParam":int(id)}})
	elif kind=="quickbar-skills":
		for skill in controlled.get("inventoryStats",{}).get("skills",[]):
			if not skill is Dictionary or float(skill.get("value",0))<=0.0:continue
			var id: int=int(skill.get("index",-1))
			choices.append({"label":rules.title("skills",id),"binding":{"type":3,"intParam":id}})
	return choices
func quickbar_choice_entries(menu: Dictionary) -> Array:
	var choices: Array=quickbar_choice_source(str(menu.get("kind","")))
	var start: int=maxi(0,int(menu.get("start",0)))
	var result: Array=[]
	for index in range(start,mini(choices.size(),start+7)):
		var choice: Dictionary=choices[index]
		result.append(entry(index-start,str(choice.label),"power",str(choice.get("icon","IR_XABILITY")),{"binding":choice.binding}))
	if start+7<choices.size():
		var next: Dictionary=menu.duplicate();next.start=start+7
		result.append(entry(7,"More…","branch","IR_XABILITY",{"menu":next}))
	return result
func class_ability_entry(descriptor: Dictionary,slot: int) -> Dictionary:
	var index:=int(descriptor.classIndex); var cls: Dictionary=ability_rules.class_row(actor(),index)
	var label:=rules.title("classes",int(ability_rules.classes(actor())[index].id)); var icon:=str(Rules.cell(cls,"Icon","ir_xability"))
	if descriptor.group: return entry(slot,label,"branch",icon,{"menu":{"kind":"class-abilities","classIndex":index,"start":0,"title":label,"center":icon}})
	var value:=feat_radial(int(descriptor.firstFeat))
	if value.is_empty(): return {}
	value.slot=slot; value.label=str(value.label)+" ("+label+")"; return value
func ability_entries(menu: Dictionary) -> Array:
	if str(menu.get("kind","")).begins_with("spell-"): return spell_entries(menu)
	var quick_kind:=str(menu.get("kind",""))
	if quick_kind=="associate-actions":
		# Original98f8e0 takes the type captured by its root creator. Its
		# canonical entity lifetime is still checked at selection/drop boundaries.
		if int(menu.get("targetId",-1))!=radial_target or not CreatureRadial.integer(menu.get("associateType"),65535):return []
		associate_creature_radial.rules=rules
		return associate_creature_radial.action_rows(int(menu.associateType),radial_target)
	if quick_kind=="world-attacks":return special_attacks()
	if quick_kind=="world-commands":creature_radial.rules=rules;return creature_radial.commands()
	if quick_kind in ["world-emotes","world-emotes-more","world-emotes-last"]:
		creature_radial.rules=rules
		var world_classes: Array=ability_rules.classes(actor());var world_first: int=int(world_classes[0].get("id",255)) if not world_classes.is_empty() else 255
		return creature_radial.emotes(["world-emotes","world-emotes-more","world-emotes-last"].find(quick_kind),world_first,actor())
	if quick_kind=="quickbar-actions":
		var actions: Array=shortcut_rules.actions(actor())
		for definition in [[1,"Items","IR_USE","quickbar-items"],[3,"Feats","IR_XABILITY","quickbar-feats"],[4,"Skills","IR_STEALTH","quickbar-skills"]]:
			actions.append(entry(int(definition[0]),str(definition[1]),"branch",str(definition[2]),{"menu":{"kind":str(definition[3]),"title":str(definition[1]),"center":str(definition[2]),"start":0}}))
		return actions
	if quick_kind in ["quickbar-items","quickbar-feats","quickbar-skills"]:return quickbar_choice_entries(menu)
	if quick_kind=="quickbar-attacks":return special_attacks()
	if quick_kind=="quickbar-commands":return shortcut_rules.commands()+QuickbarAssociates.entries(self,menu)
	if quick_kind in ["quickbar-associates-more","quickbar-associate-member","quickbar-associate-choices-page"]:return QuickbarAssociates.entries(self,menu)
	if quick_kind in ["quickbar-emotes","quickbar-emotes-more","quickbar-emotes-last"]:
		var classes: Array=ability_rules.classes(actor());var first: int=int(classes[0].get("id",255)) if not classes.is_empty() else 255
		return shortcut_rules.emotes(["quickbar-emotes","quickbar-emotes-more","quickbar-emotes-last"].find(quick_kind),first)
	var ctx:=feat_context(); var result: Array=[]; var kind:=str(menu.get("kind",""))
	if kind in ["abilities","ability-classes"]:
		if kind=="abilities":
			if is_instance_valid(rules.text) and rules.text.diagnostics.size()<100:
				rules.text.diagnostics.append({"code":"network.feat-menu-state-incomplete","reason":"Replicated combat mode is not yet projected into the ability menu","actorId":actor_id})
			result=[entry(0,owner_ui.text.raw({"strRef":84543}),"power","ir_craft",{"binding":{"type":3,"intParam":22}}),entry(1,owner_ui.text.raw({"strRef":342}),"power","isk_taunt",{"binding":{"type":3,"intParam":18},"disabled":not ctx.assignment and ctx.self})]
			for activity_id in [0,1]:
				var activity: Dictionary=ability_rules.activity(actor(),activity_id)
				result.append(entry(2 if activity_id==0 else 6,owner_ui.text.raw({"strRef":int(activity.labelRef)}),"activity",str(activity.icon),{"activityId":activity_id,"binding":{"type":10,"intParam":activity_id},"disabled":not ctx.assignment and not ctx.self}))
		if not ensure_ability_tables(): result.append(entry(4,"Preparing class abilities…","none","IR_MORE_SP_AB",{"disabled":true})); return result
		var descriptors:=ability_rules.descriptors(ctx)
		if kind=="ability-classes":
			for descriptor in descriptors: result.append(class_ability_entry(descriptor,int(descriptor.classIndex)))
		elif descriptors.size()<=3 and not ability_rules.grouped(actor()):
			for descriptor in descriptors: result.append(class_ability_entry(descriptor,5-int(descriptor.classIndex)))
		else:
			result.append(entry(4,"Class abilities","branch","IR_MORE_SP_AB",{"menu":{"kind":"ability-classes","title":"Class abilities","center":"IR_MORE_SP_AB"}}))
			if ctx.owned.has(1089): var value:=feat_radial(1089); value.slot=3; result.append(value)
		if kind=="abilities" and not actor().get("playerState",{}).get("specialAbilities",[]).is_empty(): result.append(entry(7,"Innate abilities","branch","IR_MORE_SP_AB",{"menu":{"kind":"innate","start":0,"title":"Innate abilities","center":"IR_MORE_SP_AB"}}))
	elif kind=="class-abilities":
		for source in ability_rules.class_page(ctx,int(menu.classIndex),int(menu.get("start",0))):
			if source.has("next"):
				var next:=menu.duplicate(); next.start=int(source.next); result.append(entry(7,"More special abilities","branch","IR_MORE_SP_AB",{"menu":next}))
			elif source.get("domain",false):
				var id:=int(source.featId); result.append(entry(int(source.slot),rules.title("feat",id,"FEAT"),"power",rules.icon("feat",id),{"binding":FeatRadial.binding(id),"uses":source.uses,"disabled":source.disabled}))
			else: result.append(decorate_feat(feat_rules.leaf(ctx,int(source.featId)),int(source.slot),ctx))
	elif kind=="innate":
		for source in ability_rules.innate_page(actor(),int(menu.get("start",0))):
			if source.has("next"):
				var next:=menu.duplicate(); next.start=int(source.next); result.append(entry(7,"More innate abilities","branch","IR_MORE_SP_AB",{"menu":next}))
			else:
				var value:=spell_radial({"type":44,"intParam":int(source.spellId),"domainLevel":int(source.domainLevel)},[],0,int(source.uses),true)
				value.slot=int(source.slot); result.append(value)
	return result.filter(func(value):return not value.is_empty())
func feat_entries() -> Array:
	var result: Array=[]; var seen: Dictionary={}; var ctx:=feat_context()
	for id in rules.feats(actor()):
		var value:=feat_rules.leaf(ctx,int(id))
		if value.is_empty() or seen.has(int(value.featId)): continue
		seen[int(value.featId)]=true
		var data:=rules.row("feat",int(value.featId))
		if Rules.number(Rules.cell(data,"SpellId"),-1)>=0 or Rules.number(Rules.cell(data,"UsesPerDay"),0)!=0: result.append(decorate_feat(value,0,ctx))
	return result
func feat_radial(id: int) -> Dictionary:
	var ctx:=feat_context(); return decorate_feat(feat_rules.leaf(ctx,id),0,ctx)
func decorate_feat(value: Dictionary,slot: int,ctx: Dictionary) -> Dictionary:
	if value.is_empty(): return {}
	var id:=int(value.featId); var label:=rules.title("feat",id,"FEAT"); var icon:=str(value.get("icon",rules.icon("feat",id)))
	if value.has("labelRef"):
		var resolved: String=owner_ui.text.raw({"strRef":int(value.labelRef)})
		if not resolved.is_empty(): label=resolved
	if value.get("submenu",false):
		return entry(slot,label,"branch",icon,{"binding":FeatRadial.binding(id,int(value.auxiliary)),"children":func():return feat_variant_menu(id,ctx)})
	return entry(slot,label,"power",icon,{"binding":{"type":38} if value.action=="associate.possessFamiliar" else FeatRadial.binding(id,int(value.auxiliary)),"uses":value.uses,"disabled":bool(value.disabled)})
func feat_variant_menu(id: int,ctx: Dictionary) -> Dictionary:
	var children: Array=[]
	for child in feat_rules.variants(ctx,id):
		var value: Dictionary=decorate_feat(child,int(child.slot),ctx)
		if not value.is_empty(): children.append(value)
	return {"title":rules.title("feat",id,"FEAT"),"entries":children}
func special_attacks() -> Array:
	var ctx:=feat_context(); var result: Array=[]
	for value in feat_rules.special(ctx): result.append(decorate_special(value,ctx))
	return result
func decorate_special(value: Dictionary,ctx: Dictionary) -> Dictionary:
	if value.get("kind","")=="group":
		var children: Array=[]
		for child in value.children: children.append(decorate_special(child,ctx))
		return entry(int(value.slot),owner_ui.text.raw({"strRef":int(value.labelRef)}),"branch",str(value.icon),{"children":children})
	if value.get("kind","")=="parry": return entry(int(value.slot),rules.title("skills",10),"mode",str(value.icon),{"binding":{"type":3,"intParam":10},"modeId":2,"disabled":value.disabled})
	return decorate_feat(value,int(value.slot),ctx)
func use_radial_feat(binding: Dictionary) -> void:
	var selection:=feat_rules.select(feat_context(),int(binding.intParam))
	match str(selection.mode):
		"mode": cancel_target(); submit_target({"kind":"native-mode","modeId":int(selection.modeId)})
		"target": begin_target(FeatRadial.binding(int(selection.featId),int(selection.auxiliary)))
		"use": target=FeatRadial.binding(int(selection.featId),int(selection.auxiliary)); cast_target(radial_target,radial_position)
func item_binding(binding: Dictionary) -> Dictionary:
	var result:=binding.duplicate(true); var item: Dictionary=objects.get(int(binding.get("itemId",-1)),{}).get("item",{}); var packed:=int(result.get("intParam",16711935)); var base:=rules.row("baseitems",int(item.get("baseItem",-1)))
	if packed&255==255 and Rules.number(Rules.cell(base,"QBBehaviour"),0) in [1,2]:
		for index in item.get("properties",[]).size():
			var property: Dictionary=item.properties[index]
			if int(property.type)!=15: continue
			var spell:=Rules.number(Rules.cell(rules.row("iprp_spells",int(property.subtype)),"SpellIndex"))
			if spell<0: continue
			packed=index|16711680; result.intParam=packed; break
	var index:=packed&65535
	if index<item.get("properties",[]).size():
		var property: Dictionary=item.properties[index]
		if int(property.type)==15: result.spellId=Rules.number(Rules.cell(rules.row("iprp_spells",int(property.subtype)),"SpellIndex"))
	return result
func use_inventory_item(id: int) -> void:
	# src/main.js::activateNetworkItem: the ordinary inventory double-click
	# action uses the same translated shortcut configurator as the old client.
	var object: Dictionary=objects.get(id,{})
	if object.is_empty() or not object.get("item") is Dictionary:
		owner_ui.inventory.ui.notice.text="Native inventory item is unavailable"
		return
	if not target.is_empty():
		if target_cursor(id).get("valid",false):cast_target(id,Vector3.ZERO)
		return
	if str(object.get("inventoryLocation",{}).get("channel",""))=="C":
		owner_ui.inventory.ui.operation(id,"move",{"destination":"backpack"})
		return
	var base: Dictionary=rules.row("baseitems",int(object.item.get("baseItem",-1)))
	if Rules.number(Rules.cell(base,"Container"),0)!=0:
		owner_ui.inventory.ui.operation(id,"open")
		return
	var provider=preload("res://systems/native_data/native_item_quickbar.gd").new()
	provider.configure({"registry":objects,"local_object_id":actor_id},owner_ui.text.tables)
	var configured: Dictionary=provider.configure_shortcut({}, {"itemId":id,"intParam":0xff00ff})
	if not bool(configured.get("ok",false)):
		owner_ui.inventory.ui.notice.text="That item cannot be activated"
		return
	if (int(configured.button.get("intParam",0))&65535)!=255:
		begin_target(configured.button)
		return
	if Rules.number(Rules.cell(base,"EquipableSlots"),0)!=0:
		owner_ui.inventory.ui.operation(id,"toggle")
		return
	owner_ui.inventory.ui.notice.text="This item action is not connected yet"
	owner_ui.text.diagnostics.append({"code":"network.item-default-action-unhandled","reason":"Native container or other non-property item activation is not connected","itemId":id})
func item_menu_ability(binding: Dictionary) -> void:
	if binding.has("itemTarget"):
		begin_target(binding)
		if target.is_empty():return
		var id:=int(binding.itemTarget)
		if target_cursor(id).get("valid",false): cast_target(id,Vector3.ZERO)
		else: cancel_target()
	else: begin_target(item_binding(binding))
func select_inventory_target(id: int) -> bool:
	if target.is_empty():return false
	var item: Dictionary=objects.get(id,{})
	if item.is_empty():return true
	if int(target.get("type",0))==45 and not server_target_current(target):
		cancel_target();owner_ui.inventory.item_target_failure("Server target selection was replaced");return true
	if not target_cursor(id,true).get("valid",false):
		var reason: String="That target is not valid for this server action" if int(target.get("type",0))==45 else "That target is not valid for this item" if int(target.get("type",0))==1 else "That target is not valid for this action"
		owner_ui.inventory.item_target_failure(reason)
		return true
	cast_target(id,Vector3.ZERO,false,"inventory")
	return true
func item_icon_ready(key: String,texture: Texture2D,error: String) -> void:
	if closed: return
	if not error.is_empty() and quickbar_item_keys.values().has(key):quickbar_failure("Shortcut icon unavailable: "+error,"network.quickbar-icon-unavailable")
	if texture!=null and error.is_empty():
		for job in item_art.get(key,[]):
			if int(job.view)==quickbar.quickbar_id and quickbar.buttons.has(int(job.index)): quickbar.buttons[int(job.index)].image.texture=texture
	if not quickbar_binding_art and is_instance_valid(quickbar_frame): quickbar_frame.try_admit()
func radial_item_icon_ready(key: String,texture: Texture2D,error: String) -> void:
	if closed or not radial_item_jobs.has(key):return
	var jobs: Array=radial_item_jobs[key]; radial_item_jobs.erase(key)
	for job in jobs:
		var slot: int=int(job.slot)
		if not radial.active or radial.request_id!=int(job.requestId) or radial.menu_id!=int(job.menuId) or not radial_entries.has(slot) or int(radial_entries[slot].get("itemIconId",-1))!=int(job.itemId):continue
		if texture!=null and error.is_empty():radial.icons[slot].texture=texture
		else:
			art.bind(radial.icons[slot],"IR_USE")
			target_prompt.text="Shortcut icon unavailable: "+error; target_prompt.show()
func show_radial(menu: Dictionary,push: bool=false) -> void:
	var source: Array=ability_entries(menu) if menu.has("kind") else menu.entries
	if bool(menu.get("spellBuildFailed",false)) or str(menu.get("kind","")).begins_with("spell-") and not spell_rules.uses_failure.is_empty():return
	if push: radial_stack.append(menu)
	radial_entries.clear();radial_item_jobs.clear(); radial_serial+=1; var entries: Array=[]
	var physical:=source.size()<=8; var slots: Dictionary={}
	for item in source:
		var slot:=int(item.get("slot",-1))
		if slot<0 or slot>7 or slots.has(slot): physical=false
		slots[slot]=true
	for index in mini(source.size(),8):
		var item: Dictionary=source[index].duplicate(true); item.slot=int(item.slot) if physical else index
		if item.has("children"):item.submenu=true
		if not item.has("disabled"):item.disabled=false
		if not item.has("uses"):item.uses=null
		if not item.has("canDrag"):item.canDrag=false
		radial_entries[int(item.slot)]=item; entries.append(item)
	if source.size()>8:
		entries.resize(7); radial_entries.erase(7); var more:=entry(7,"More…","branch","IR_MORE_SP_AB",{"children":source.slice(7)}); entries.append(more); radial_entries[7]=more
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":radial_serial,"depth":maxi(0,radial_stack.size()-1),"title":menu.get("title","Special abilities"),"entries":entries})
	var record:={"actor_id":actor_id,"area_id":area_id,"generation":generation,"menu_id":radial_serial,"depth":maxi(0,radial_stack.size()-1),"title":menu.get("title","Special abilities"),"entries":[]}
	for value in entries: record.entries.append({"slot":int(value.slot),"label":str(value.label),"submenu":bool(value.get("submenu",false)),"disabled":bool(value.get("disabled",false)),"binding":value.get("binding",{}).duplicate()})
	radial_history.append(record)
	if radial_history.size()>64: radial_history.pop_front()
	radial.set_center(str(menu.get("center","ir_use")),bool(menu.get("portraitCenter",false)))
	for slot in radial_entries:
		var value: Dictionary=radial_entries[slot]
		var image: TextureRect=radial.icons[int(slot)]
		if not value.has("itemIconId"):
			art.bind(image,str(value.icon));continue
		art.bind(image,"")
		var item_id: int=int(value.itemIconId)
		var item: Dictionary=objects.get(item_id,{}).get("item",{})
		var icons=radial_item_icons if is_instance_valid(radial_item_icons) else owner_ui.inventory.icons
		var key: String=icons.request(item,owner_ui.text.tables,int(actor().get("appearance",{}).get("gender",0))) if not item.is_empty() else ""
		if key.is_empty():art.bind(image,"IR_USE");continue
		var texture: Texture2D=icons.textures.get(key)
		if texture!=null:image.texture=texture
		else:
			if not radial_item_jobs.has(key):radial_item_jobs[key]=[]
			radial_item_jobs[key].append({"requestId":radial.request_id,"menuId":radial.menu_id,"slot":int(slot),"itemId":item_id})
func radial_child_menu(item: Dictionary) -> Dictionary:
	var child: Variant=item.get("children")
	if child is Callable:child=child.call()
	return child if child is Dictionary else {"title":str(item.get("label","")),"entries":child if child is Array else [],"center":str(item.get("icon",""))}
func radial_preview(slot: int,request_id: int,menu_id: int) -> Array:
	if not radial.active or request_id!=radial.request_id or menu_id!=radial.menu_id or not radial_entries.has(slot): return []
	var parent: Dictionary=radial_entries[slot]; var values: Array=[]
	if parent.has("menu"):values=parent.menu.entries if parent.menu.has("entries") else ability_entries(parent.menu)
	elif parent.has("children"):values=radial_child_menu(parent).entries
	var result: Array=[]; var slots: Dictionary={}; var physical:=values.size()<=8
	for value in values:
		var at:=int(value.get("slot",-1))
		if at<0 or at>7 or slots.has(at): physical=false
		slots[at]=true
	for index in mini(values.size(),8 if values.size()<=8 else 7):
		var value: Dictionary=values[index].duplicate(); value.slot=int(value.slot) if physical else index
		if value.has("children"):value.submenu=true
		result.append(value)
	if values.size()>8: result.append(entry(7,"More…","branch","IR_MORE_SP_AB",{"children":values.slice(7)}))
	return result
func radial_select(message: Dictionary) -> void:
	if not radial.active or int(message.requestId)!=radial.request_id or int(message.menuId)!=radial.menu_id or not radial_entries.has(int(message.slot)): return
	if not world_context.is_empty() and not world_scope_valid():retire_current_radial(radial.request_id);return
	if not shortcut_context.is_empty() and not shortcut_scope_valid(shortcut_context):retire_shortcut_context();return
	var item: Dictionary=radial_entries[int(message.slot)]
	if not QuickbarAssociates.entry_valid(self,item):retire_current_radial(radial.request_id);return
	if item.get("disabled",false): return
	if item.has("menu"): show_radial(item.menu,true); return
	if item.has("children"): show_radial(radial_child_menu(item),true); return
	if pending_shortcuts.has("index") and item.has("binding"): assign(int(pending_shortcuts.index),item.binding)
	else:
		match str(item.action):
			"associate-record":open_character_record(int(item.targetId))
			"world-attack":
				if radial_target==actor_id:begin_target({"type":7})
				else:command({"kind":"interact","targetId":radial_target,"action":"combat.attack"})
			"world-skill":command({"kind":"native-skill","targetId":radial_target,"packedSkill":int(item.binding.intParam),"position":[0,0,0]})
			"world-disengage":cancel_target();command({"kind":"native-disengage"})
			"world-cancel-polymorph":cancel_target();command({"kind":"native-cancel-polymorph"})
			"world-party":
				var party_message:={"kind":"native-party","operation":str(item.operation)}
				if item.has("targetId"):party_message.targetId=int(item.targetId)
				command(party_message)
			"world-associate":command({"kind":"native-associate","targetId":int(item.targetId),"command":int(item.command)})
			"world-emote":
				var emote_flags: Variant=actor().get("replicated",{}).get("field8E0")
				if CreatureRadial.integer(emote_flags,65535) and (int(emote_flags)&16)==0:activate(item.binding)
			"quickbar-clear":assign(int(shortcut_context.index),{"type":0})
			"quickbar-use":activate(shortcut_context.binding,int(shortcut_context.index))
			"quickbar-examine":
				if is_instance_valid(shortcut_dialogs):shortcut_dialogs.examine(shortcut_context,shortcut_rules.information(shortcut_context.binding))
			"quickbar-macro","quickbar-macro-line","quickbar-macro-label":
				if is_instance_valid(shortcut_dialogs):shortcut_dialogs.edit_macro(shortcut_context,"new" if item.action=="quickbar-macro" else "line" if item.action=="quickbar-macro-line" else "label")
			"activity": command({"kind":"native-activity","activityId":int(item.activityId),"targetId":radial_target if int(item.activityId)==5 else INVALID})
			"barter": command({"kind":"native-barter","operation":"start","targetId":radial_target})
			"barter-remove": owner_ui.barter.remove_item(radial_target)
			"mode": cancel_target(); command({"kind":"native-mode","modeId":int(item.modeId)})
			"power":
				if int(item.binding.get("type",0))==4: use_radial_feat(item.binding)
				elif int(item.binding.get("type",0)) in [38,39,42]: activate(item.binding)
				elif radial_target<0: begin_target(item.binding)
				else: target=item.binding.duplicate(); cast_target(radial_target,radial_position)
			"panel": panel(str(item.panel))
			"rest": command({"kind":"native-rest"})
			"examine": command({"kind":"examine","targetId":radial_target})
			"interact": command({"kind":"interact","targetId":radial_target,"action":item.interaction})
			"pickup": command({"kind":"pickup","targetId":radial_target})
			"clear":
				if pending_shortcuts.has("index"): assign(int(pending_shortcuts.index),{"type":0})
			"move": command({"kind":"walk","position":[radial_position.x,-radial_position.z,radial_position.y]})
			_: network_radial_action(item)
	radial.reset(); radial_stack.clear(); pending_shortcuts.clear();shortcut_context.clear();world_context.clear()
func network_radial_action(item: Dictionary) -> void:
	var action: String=str(item.get("action",""))
	match action:
		"character.sheet":panel("character");return
		"object.examine":command({"kind":"examine","targetId":radial_target});return
		"associate.command":command({"kind":"native-associate","targetId":radial_target,"command":int(item.get("command",0))});return
		"associate.quickChat":command({"kind":"native-quickchat","quickChat":int(item.get("quickChat",0))});return
		"associate.possess","associate.possessFamiliar":command({"kind":"native-possess"});return
		"rest":command({"kind":"native-rest"});return
		"item.pickup":command({"kind":"pickup","targetId":radial_target});return
		"movement.moveTo":
			if radial_target<0:command({"kind":"walk","position":[radial_position.x,-radial_position.z,radial_position.y],"run":true});return
		"spell.cast","spellLike.use","feat.use":
			if item.get("binding") is Dictionary:
				target=item.binding.duplicate(true);cast_target(radial_target,radial_position);return
	var interaction: String={"placeable.use":"object.use","combat.bash":"combat.attack"}.get(action,action)
	if interaction in ["door.open","door.close","door.transition","trigger.transition","conversation.start","object.use","combat.attack"]:
		command({"kind":"interact","targetId":radial_target,"action":interaction});return
	if is_instance_valid(rules.text) and rules.text.diagnostics.size()<100:
		rules.text.diagnostics.append({"code":"network.interaction-unimplemented","reason":"Native interaction handler is not connected","action":action,"objectId":radial_target})
	if is_instance_valid(target_prompt):target_prompt.text=str(item.get("label","Action"))+" is not connected yet";target_prompt.show()
func barter_item_menu(id: int,point: Vector2,removable: bool) -> void:
	owner_ui.inventory.item_context.open_trade(owner_ui.barter,id,point)
func quickbar_shortcut_choice(binding: Dictionary,path: Array=[],budget: Variant=null) -> Dictionary:
	var id:=int(binding.get("intParam",-1))
	if path.has(id) or path.size()>=32:return {}
	var remaining: Dictionary=budget if budget is Dictionary else {"remaining":2048}
	remaining.remaining=int(remaining.remaining)-1
	if int(remaining.remaining)<0 or rules.casting_spell(id)==null:return {}
	var result: Dictionary={"label":rules.title("spells",id),"icon":rules.icon("spells",id)}
	var definition: Variant=rules.talent_spell(id)
	if definition!=null and not definition.children.is_empty():
		var children: Array=[]
		for child in rules.spell_children(id,path):
			if rules.casting_spell(int(child))==null:continue
			var next: Dictionary=binding.duplicate();next.intParam=int(child)
			var choice:=quickbar_shortcut_choice(next,path+[id],remaining)
			if not choice.is_empty():children.append(choice)
		result.children=children
	else:result.binding=binding.duplicate()
	return result
func quickbar_append_spell_choice(result: Array,seen: Dictionary,class_index: int,id: int,meta: int,domain: int) -> void:
	var key: String="%d:%d:%d"%[id,meta,domain]
	if seen.has(key):return
	seen[key]=true
	var choice:=quickbar_shortcut_choice({"type":2,"intParam":id,"classIndex":class_index,"metamagic":meta,"domainLevel":domain})
	if not choice.is_empty():result.append(choice)
func quickbar_spell_choices() -> Array:
	var controlled: Dictionary=actor();var player: Dictionary=controlled.get("playerState",{});var result: Array=[]
	var spellbooks: Dictionary=player.get("spellbooks",{})
	var owned: Array=player.get("feats",[])+player.get("bonusFeats",[])
	var masks: Array=[0]
	for option in [[1,11],[2,12],[4,25],[8,29],[16,33],[32,37]]:
		if owned.has(option[1]):masks.append(option[0])
	for raw_index in spellbooks:
		var class_index:=int(raw_index);var book: Dictionary=spellbooks[raw_index];var seen: Dictionary={}
		for meta in masks:
			for level in 10:
				if level+rules.meta_cost(int(meta))>=10:break
				for spell in rules.preparation_entries(controlled,class_index,level,int(meta)):
					quickbar_append_spell_choice(result,seen,class_index,int(spell.id),int(meta),level if bool(spell.domain) else 0)
		for raw_level in book.get("memorized",{}):
			for spell in book.memorized[raw_level]:
				if not spell is Dictionary:continue
				var meta:=int(spell.get("metamagic",0));var domain:=(int(raw_level)-rules.meta_cost(meta))&255 if bool(spell.get("domain",false)) else 0
				quickbar_append_spell_choice(result,seen,class_index,int(spell.get("spell",-1)),meta,domain)
	return result
func quickbar_choice_branch(title: String,choices: Array) -> Dictionary:
	return {"title":title,"entries":quickbar_choice_menu(title,choices)}
func quickbar_choice_menu(title: String,choices: Array) -> Array:
	var result: Array=[]
	for index in mini(choices.size(),7):
		var choice: Dictionary=choices[index];var icon_value: Variant=choice.get("icon");var icon: String="IR_XABILITY" if icon_value==null else str(icon_value)
		if choice.has("children"):
			var children: Array=choice.children
			result.append(entry(index,str(choice.label),"branch",icon,{"children":Callable(self,"quickbar_choice_branch").bind(str(choice.label),children),"disabled":children.is_empty()}))
		else:result.append(entry(index,str(choice.label),"power",icon,{"binding":choice.binding}))
	if choices.size()>7:result.append(entry(7,"More…","branch","IR_XABILITY",{"children":Callable(self,"quickbar_choice_branch").bind(title,choices.slice(7))}))
	return result
func quickbar_assignment_entries() -> Array:
	var ability_choices: Array=[]
	for ability in actor().get("playerState",{}).get("specialAbilities",[]):
		if not ability is Dictionary:continue
		var choice:=quickbar_shortcut_choice({"type":44,"intParam":int(ability.get("spell",-1)),"domainLevel":int(ability.get("level",0))})
		if not choice.is_empty():ability_choices.append(choice)
	var command_choices: Array=[]
	for definition in [["Attack nearest","IR_ATTACKNEAREST",0],["Follow","IR_FOLLOW",22],["Stand ground","IR_STANDGROUND",10],["Guard","IR_GUARD",9],["Heal me","IR_HEALME",4]]:
		command_choices.append({"label":definition[0],"icon":definition[1],"binding":{"type":42,"intParam":definition[2]}})
	for choice in QuickbarAssociates.source_choices(self):command_choices.append(choice)
	var groups: Array=[
		{"slot":2,"label":"Items","icon":"IR_USE","entries":quickbar_choice_source("quickbar-items")},
		{"slot":1,"label":"Spells","icon":"IR_CAST","entries":quickbar_spell_choices()},
		{"slot":3,"label":"Feats","icon":"IR_XABILITY","entries":quickbar_choice_source("quickbar-feats")},
		{"slot":4,"label":"Skills","icon":"IR_STEALTH","entries":quickbar_choice_source("quickbar-skills")},
		{"slot":5,"label":"Abilities","icon":"IR_XABILITY","entries":ability_choices},
		{"slot":0,"label":"Commands","icon":"IR_COMMAND","entries":command_choices}]
	var result: Array=[]
	for group in groups:
		if group.entries.is_empty():continue
		result.append(entry(int(group.slot),str(group.label),"branch",str(group.icon),{"children":Callable(self,"quickbar_choice_branch").bind(str(group.label),group.entries)}))
	result.append(entry(6,"Clear slot","clear","",{"binding":{"type":0}}))
	return result
func shortcut_menu(index: int,point: Vector2) -> void:
	if not owner_ui.tables_ready or index<0 or index>=mini(36,quick_bindings.size()): return
	var began:=Time.get_ticks_usec();retire_shortcut_context()
	owner_ui.inventory.item_context.cancel()
	shortcut_context={"generation":generation,"area":area_id,"actor":actor_id,"index":index,"binding":quick_bindings[index].duplicate(true)}
	var binding: Dictionary=shortcut_context.binding;var type:=int(binding.get("type",0));shortcut_rules.rules=rules
	radial.open_at(point,actor_id,Vector3.ZERO,false); radial_stack.clear(); pending_shortcuts={"index":index}
	radial_target=actor_id; radial_position=Vector3.ZERO
	show_radial({"title":"Assign F"+str(index%12+1),"entries":quickbar_assignment_entries(),"center":""},true)
	finish_shortcut_timing(index,type,began,radial_entries.size())
func finish_shortcut_timing(index: int,type: int,began: int,count: int) -> void:
	var elapsed:=Time.get_ticks_usec()-began;shortcut_timings.append({"index":index,"type":type,"build_usec":elapsed,"entries":count});if shortcut_timings.size()>64:shortcut_timings.pop_front()
	Timing.finish("ui_shortcut_root_ms",began)
func shortcut_scope_valid(value: Dictionary) -> bool:
	var index:=int(value.get("index",-1))
	return not closed and value.get("generation") == generation and value.get("area")==area_id and value.get("actor")==actor_id and objects.has(actor_id) and index>=0 and index<mini(36,quick_bindings.size()) and quick_bindings[index]==value.get("binding")
func retire_current_radial(expected_request_id: int) -> bool:
	if closed or not is_instance_valid(radial) or not radial.active or radial.request_id!=expected_request_id: return false
	radial_stack.clear(); radial_entries.clear(); pending_shortcuts.clear(); shortcut_context.clear(); world_context.clear()
	radial.reset(); return true
func retire_shortcut_context(reset_wheel: bool=true) -> void:
	shortcut_context.clear();pending_shortcuts.clear();world_context.clear()
	if reset_wheel and is_instance_valid(radial):radial.reset();radial_stack.clear();radial_entries.clear()
	if is_instance_valid(shortcut_dialogs):shortcut_dialogs.clear()
func blocks_pointer(point: Vector2) -> bool:
	if is_instance_valid(shortcut_dialogs) and shortcut_dialogs.blocks_pointer(point):return true
	if is_instance_valid(players_frame) and players_frame.popup.blocks_pointer(point): return true
	if is_instance_valid(map_frame) and map_frame.blocks_pointer(point): return true
	if is_instance_valid(book_frame) and book_frame.layout_ready and book_frame.blocks_pointer(point): return true
	if is_instance_valid(journal_frame) and journal_frame.blocks_pointer(point): return true
	if action_queue.blocks_pointer(point) or party.blocks_pointer(point) or buffs.blocks_pointer(point) or radial.blocks_pointer(point): return true
	for view in [quickbar,sheet,book,journal,area_map,players,level_up]:
		if view.visible and view.get_global_rect().has_point(point): return true
	return false
func _input(event: InputEvent) -> void:
	# src/main.js:2745:35 captures active target Escape before ordinary shortcut
	# guards. Inventory's earlier front-window handler retains its priority.
	if closed or target.is_empty() or actor_id<0 or not objects.has(actor_id) or not event is InputEventKey or not event.pressed or event.keycode!=KEY_ESCAPE:return
	if GameInput.is_text_entry(get_viewport().gui_get_focus_owner()):return
	if is_instance_valid(owner_ui.inventory) and is_instance_valid(owner_ui.inventory.ui) and owner_ui.inventory.ui.wanted and owner_ui.inventory.ui.is_front_game_window():return
	cancel_target();target_prompt.text="Spell targeting cancelled";target_prompt.show();get_viewport().set_input_as_handled()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var bindings=owner_ui.key_bindings
	if is_instance_valid(bindings) and bindings.blocked(): return
	var focus:=get_viewport().gui_get_focus_owner()
	if GameInput.is_text_entry(focus): return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return
	# src/network_inventory_view.js:31 captures Escape only while its own
	# inventory window is the front visible game window.
	if event.keycode==KEY_ESCAPE and actor_id>=0 and objects.has(actor_id) and is_instance_valid(owner_ui.inventory) and is_instance_valid(owner_ui.inventory.ui) and owner_ui.inventory.ui.wanted and owner_ui.inventory.ui.is_front_game_window():
		owner_ui.inventory.ui.close_inventory(); get_viewport().set_input_as_handled(); return
	if event.keycode==KEY_ESCAPE:
		var view: Control=Draggable.front_game_window(owner_ui.controls)
		if view is Draggable:
			view.close_requested.emit()
			if view.close_hides:view.hide()
			get_viewport().set_input_as_handled(); return
		options_requested.emit()
		get_viewport().set_input_as_handled(); return
	if is_instance_valid(bindings):
		var actions:={66:"character",67:"spells",68:"map",65:"journal",70:"options",107:"rest",69:"pvp"}
		var selected: int=bindings.action(event,actions.keys())
		if actions.has(selected): panel(str(actions[selected])); get_viewport().set_input_as_handled()
		elif bindings.action_matches(62,event): open_radial({"id":actor_id,"origin":"keyboard"},get_viewport().get_mouse_position()); get_viewport().set_input_as_handled()
	else:
		var panels:={KEY_C:"character",KEY_B:"spells",KEY_M:"map",KEY_J:"journal",KEY_O:"options",KEY_R:"rest"}
		if panels.has(event.keycode): panel(str(panels[event.keycode])); get_viewport().set_input_as_handled()
func class_tables_ready(class_id: int) -> bool:
	var ready:=true; var cls:=rules.row("classes",class_id)
	for field in ["StatGainTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable","SkillsTable","FeatsTable","BonusFeatsTable"]:
		var name:=str(Rules.cell(cls,field,"")).to_lower()
		if name.is_empty() or name=="****" or owner_ui.text.tables.has(name): continue
		ready=false
		if not owner_ui.table_jobs.values().has(name) and owner_ui.catalog.has_resource(name,2017):
			var id: int=owner_ui.assets.request(name,2017,"2da")
			if id>=0: owner_ui.table_jobs[id]=name
		elif not owner_ui.catalog.has_resource(name,2017): owner_ui.text.tables[name]={}
	if not ready: level_rules_waiting=true
	return ready
func receive(message: Dictionary) -> void:
	if message.kind!="native-action-result": return
	if str(message.get("action",""))=="walk" and message.get("walkPointerRequestId")!=null:
		if int(message.get("generation",-1))!=generation or int(message.get("areaId",-1))!=area_id or int(message.get("actorId",-1))!=actor_id:return
		if bool(message.get("accepted",false)):
			target_prompt.text="Move requested";target_prompt.show()
			if is_instance_valid(owner_ui) and is_instance_valid(owner_ui.text) and owner_ui.text.diagnostics.size()<100:owner_ui.text.diagnostics.append({"code":"network.walk-requested","message":"Native waypoint request sent","data":{"sequence":int(message.get("sequence",-1)),"position":message.get("position",[]).duplicate(),"run":bool(message.get("run",true))},"severity":"info"})
		else:
			var reason:=str(message.get("text","Movement request failed"))
			target_prompt.text=reason;target_prompt.show()
			if is_instance_valid(owner_ui) and is_instance_valid(owner_ui.text) and owner_ui.text.diagnostics.size()<100:owner_ui.text.diagnostics.append({"code":"network.walk-request-failed","message":reason})
		return
	if message.get("targetFeedbackRequestId")!=null:
		var feedback_id:=int(message.targetFeedbackRequestId)
		var pending_feedback: Dictionary=target_feedback_pending.get(feedback_id,{})
		target_feedback_pending.erase(feedback_id)
		if pending_feedback.is_empty() or str(message.get("action",""))!=str(pending_feedback.action) or int(message.get("generation",-1))!=int(pending_feedback.generation) or int(message.get("areaId",-1))!=int(pending_feedback.areaId) or int(message.get("actorId",-1))!=int(pending_feedback.actorId) or generation!=int(pending_feedback.generation) or area_id!=int(pending_feedback.areaId) or actor_id!=int(pending_feedback.actorId):return
		if bool(message.get("accepted",false)):
			target_prompt.text=str(pending_feedback.feedback);target_prompt.show()
			return
		if bool(pending_feedback.get("worldPointer",false)):
			var reason:=str(message.get("text","The action was not accepted."))
			world_target_failure(reason)
			return
		if str(pending_feedback.get("failureOrigin",""))=="inventory":
			owner_ui.inventory.item_target_failure(str(message.get("text","The action was not accepted.")))
			return
		if str(pending_feedback.get("failureOrigin","")) in ["quickbar","party"]:
			quickbar_failure(str(message.get("text","The action was not accepted.")))
			return
	if message.action=="native-panel" and message.get("requestId")!=null:
		var request_id:=int(message.requestId)
		var pending: Dictionary=panel_feedback_pending.get(request_id,{})
		panel_feedback_pending.erase(request_id)
		if pending.is_empty():return
		if str(message.get("panel",""))!="character" or message.get("open")!=true or int(message.get("generation",-1))!=int(pending.generation) or int(message.get("areaId",-1))!=int(pending.areaId) or int(message.get("actorId",-1))!=int(pending.actorId) or generation!=int(pending.generation) or area_id!=int(pending.areaId) or actor_id!=int(pending.actorId) or not sheet.wanted or sheet.page!=int(pending.page):return
		if not bool(message.get("accepted",false)):
			var reason:=str(message.get("text","Character record page request failed"))
			if is_instance_valid(owner_ui.text) and owner_ui.text.diagnostics.size()<100:owner_ui.text.diagnostics.append({"code":"network.hud-action-failed","message":reason,"data":{"panel":"character","page":int(pending.page)}})
			target_prompt.text=reason;target_prompt.show()
		return
	if message.action=="native-quickbar-assign" and message.get("quickbarRequestId")!=null:
		var request_id:=int(message.quickbarRequestId)
		var destination_index:=int(message.get("index",-1))
		if int(quickbar_pending_assigns.get(destination_index,-1))!=request_id:return
		quickbar_pending_assigns.erase(destination_index)
		quickbar.set_pending(destination_index,false)
		var move: Dictionary=quickbar_pending_moves.get(request_id,{})
		quickbar_pending_moves.erase(request_id)
		if move.is_empty():
			if not bool(message.get("accepted",false)):quickbar_failure(str(message.get("text","That shortcut could not be assigned")))
			return
		if int(message.get("index",-1))!=int(move.destinationIndex) or int(message.get("generation",-1))!=int(move.generation) or int(message.get("areaId",-1))!=int(move.areaId) or int(message.get("actorId",-1))!=int(move.actorId) or generation!=int(move.generation) or area_id!=int(move.areaId) or actor_id!=int(move.actorId):return
		if bool(message.get("accepted",false)):
			var source_index:=int(move.sourceIndex)
			if source_index>=0 and source_index<quick_bindings.size() and JSON.stringify(quick_bindings[source_index])==JSON.stringify(move.binding):assign(source_index,{"type":0},false)
		else:
			quickbar_failure(str(message.get("text","That shortcut could not be assigned")))
		return
	if message.action in ["native-players","native-party","native-player-attitude"]: players_frame.receive(message); return
	if message.action=="native-map": map_frame.receive(message); return
	if message.action=="native-prepare":
		if not message.accepted and preparation.reject(int(message.get("requestId",-1)),[int(message.get("generation",-1)),int(message.get("areaId",-1)),int(message.get("actorId",-1))],str(message.get("text","Spell preparation could not be sent."))):
			if book.wanted: refresh_book()
		return # Transport acceptance is not a server preparation confirmation.
	if message.action=="native-quickbar-activate" and not bool(message.get("accepted",false)):
		quickbar_failure(str(message.get("text","Shortcut could not be activated")))
		return
	# Level-up owns its request/view/lifetime correlation and current error
	# presentation. An old refusal must not show a global prompt over a new UI.
	if message.action=="native-level-up":level_owner.receive_result(message);return
	if not message.accepted:
		if message.action=="native-cancel-action":
			if is_instance_valid(rules.text) and rules.text.diagnostics.size()<100:
				rules.text.diagnostics.append({"code":"network.action-cancel-failed","reason":str(message.get("text","The action was not accepted."))})
			return
		target_prompt.text=str(message.get("text","The action was not accepted.")); target_prompt.show()
		return
func radial_diagnostic() -> Dictionary:
	var current:=actor(); var tables: Array=[]
	for index in ability_rules.classes(current).size():
		var name:=ability_rules.class_table(current,index)
		tables.append({"class_index":index,"resource":name,"loaded":owner_ui.text.tables.has(name),"rows":owner_ui.text.tables.get(name,{}).get("orderedRows",[]).size()})
	return {"actor_id":actor_id,"area_id":area_id,"generation":generation,"classes":ability_rules.classes(current).duplicate(true),"feats":rules.feats(current).slice(0,512),"innate":current.get("playerState",{}).get("specialAbilities",[]).slice(0,512),"class_tables":tables,"pending_class_tables":ability_tables_pending.duplicate(),"errors":ability_rules.errors+spell_rules.errors,"active":radial.active,"path":radial_stack.map(func(menu):return str(menu.get("title",menu.get("kind","Menu")))),"history":radial_history.duplicate(true),"worldContext":world_radial_coverage.duplicate(true)}
func snapshot() -> Dictionary:
	var menus: Dictionary={}
	for pair in [["character",sheet],["spells",book],["journal",journal],["map",area_map],["players",players],["level_up",level_up]]: menus[pair[0]]=is_instance_valid(pair[1]) and pair[1].visible
	return {"native_only":true,"menus":menus,"radial_diagnostics":radial_diagnostic(),"party_members":party.rows.size(),"party_skin":party_frame.snapshot(),"players_skin":players_frame.snapshot(),"quickbar_slots":quickbar.rows.size(),"quickbar_skin":quickbar_frame.snapshot(),"journal_skin":journal_frame.snapshot(),"buffs":buffs.buttons.size(),"queued_actions":action_queue.rows.size(),"cancel_pending":action_queue.pending.size(),"radial":radial.active,"targeting":not target.is_empty(),"map_art":area_map.board.art.size(),"map_skin":map_frame.snapshot(),"art":art.models.snapshot(),"missing_art":art.failed.keys(),"raw_data_retirement_enabled":raw_data_retirement_enabled,"raw_data_retirements":raw_data_retirements,"radial_skin":radial.skin_snapshot(),"stale_art_bindings":art.stale_bindings,"full_binary_parity":false}
func close() -> void:
	if closed: return
	if level_owner!=null:level_owner.close()
	closed=true; cancel_target(); quickbar_pending_moves.clear(); quickbar_pending_assigns.clear(); panel_feedback_pending.clear(); target_feedback_pending.clear(); objects.clear(); state.clear(); world_context.clear(); sheet_context.clear()
	rules.party_indicators.reset()
	party_details.reset()
	preparation.reset()
	if is_instance_valid(sheet_frame): sheet_frame.close()
	if is_instance_valid(quickbar_frame): quickbar_frame.close()
	if is_instance_valid(party_frame): party_frame.close()
	if is_instance_valid(book_frame): book_frame.close()
	if is_instance_valid(journal_frame): journal_frame.close()
	if is_instance_valid(map_frame): map_frame.close()
	if is_instance_valid(players_frame): players_frame.close()
	if is_instance_valid(action_queue): action_queue.close()
	if is_instance_valid(buff_frame): buff_frame.close()
	if is_instance_valid(art): art.close()
	if is_instance_valid(radial_item_icons):radial_item_icons.close()
	if is_instance_valid(shortcut_dialogs):shortcut_dialogs.close()
	if is_instance_valid(radial): radial.reset()
func _exit_tree() -> void: close()
