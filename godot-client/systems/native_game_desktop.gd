extends Node
# Native menu ownership and rule projection. The protocol bridge sends raw
# received state/typed requests only; it never constructs these menu models.
signal request(message: Dictionary)
signal options_requested
signal target_changed(active: bool)
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
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
var quick_bindings: Array=[]
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
var quickbar_item_retry: Array=[]
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
	owner_ui=ui; rules.text=ui.text; feat_rules.rules=rules; ability_rules.rules=rules; ability_rules.feats=feat_rules; spell_rules.rules=rules; spell_rules.abilities=ability_rules; art=Art.new(); add_child(art); art.configure(catalog,cache_path); art.assets.completed.connect(map_prepared); art.loaded.connect(map_art_ready)
	party=preload("res://systems/server_party.gd").new(); ui.controls.add_child(party); party.setup(); party.panel_requested.connect(panel)
	party.portrait_selected.connect(func(index,_point):
		if index>=party.rows.size(): return
		if party.rows[index].self: panel("character")
		else: request.emit({"kind":"examine","targetId":party.rows[index].id}))
	party.portrait_menu.connect(func(index,point): if index<party.rows.size(): open_radial({"id":int(party.rows[index].id),"position":Vector3.ZERO,"origin":"portrait"},point))
	party.request.connect(func(_message): command({"kind":"native-rest"}))
	party_frame=preload("res://systems/native_party_frame.gd").new(); add_child(party_frame); party_frame.configure(party,catalog,cache_path,ui.text,ui.inventory.frame_skin)
	party_frame.locator_context=party_locator_context
	quickbar=preload("res://systems/server_quickbar.gd").new(); ui.controls.add_child(quickbar); quickbar.setup(); quickbar.request.connect(input_request)
	quickbar.set_key_bindings(ui.key_bindings)
	quickbar.inventory_requested.connect(func(): panel("inventory")); quickbar.character_requested.connect(func(): panel("character")); quickbar.spellbook_requested.connect(func(): panel("spells")); quickbar.map_requested.connect(func(): panel("map")); quickbar.journal_requested.connect(func(): panel("journal")); quickbar.options_requested.connect(func(): options_requested.emit()); quickbar.level_requested.connect(func(): panel("level-up"))
	quickbar.assignment_requested.connect(shortcut_menu); quickbar.rendered.connect(bind_quickbar_art)
	shortcut_rules.rules=rules
	shortcut_dialogs=preload("res://systems/native_quickbar_context.gd").new();add_child(shortcut_dialogs);shortcut_dialogs.configure(self,catalog,cache_path)
	quickbar_frame=preload("res://systems/native_quickbar_frame.gd").new(); add_child(quickbar_frame); quickbar_frame.configure(quickbar,catalog,cache_path,ui.text,ui.inventory.frame_skin)
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
	buffs.effect_selected.connect(func(id):command({"kind":"native-panel","panel":"effect","open":true,"effectId":id}))
	action_queue=preload("res://systems/server_action_queue.gd").new(); ui.controls.add_child(action_queue); action_queue.setup(self); action_queue.cancel_requested.connect(func(id,group): command({"kind":"native-cancel-action","actionId":id,"groupId":group}))
	radial=preload("res://systems/server_radial.gd").new(); add_child(radial); radial.request.connect(input_request)
	radial.key_bindings=ui.key_bindings
	radial.preview_provider=radial_preview
	radial.configure_art(art)
	radial.configure_text(ui.inventory.frame_skin.fonts)
	quickbar.record_valid=sheet.can_drag; quickbar.inventory_valid=func(data): return int(data.get("viewId",-1))==owner_ui.inventory.ui.view_id and owner_ui.inventory.views.has(int(data.get("entryId",-1)))
	quickbar.radial_valid=func(data): return owner_ui.inventory.item_context.can_shortcut(data) if data.get("kind","")=="item-radial-entry" else can_radial_shortcut(data)
	owner_ui.inventory.ability_requested.connect(use_inventory_item); owner_ui.inventory.icons.completed.connect(item_icon_ready)
	owner_ui.inventory.item_context.opened.connect(radial.reset)
	owner_ui.inventory.item_context.ability_selected.connect(item_menu_ability)
	owner_ui.inventory.item_context.spell_entries=func():return spell_branches(8)
	owner_ui.inventory.item_context.spell_menu=func(menu):return spell_entries(menu,8)
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
func set_world(epoch: int,area: int,controlled: int,raw_objects: Dictionary,header: Dictionary) -> void:
	var began:=Timing.begin()
	if epoch!=generation or controlled!=actor_id: rules.party_indicators.reset()
	retain_replaced_raw_state(raw_objects)
	Timing.finish("snapshot_ui_desktop_retain_ms",began); began=Timing.begin()
	if epoch!=generation or area!=area_id or controlled!=actor_id:
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
func sync() -> void:
	var current:=actor()
	var script_mode: Variant=state.get("scriptTargeting")
	if changed("script-target",script_mode):
		if script_mode is Dictionary and not script_mode.is_empty():
			target={"type":45,"version":int(script_mode.version),"objectMask":int(script_mode.objectMask),"cursor":int(script_mode.get("cursor",29)),"badCursor":int(script_mode.get("badCursor",31))}; target_prompt.text="Choose a server target · Esc or right-click to cancel"; target_prompt.show(); target_changed.emit(true)
		elif int(target.get("type",0))==45: cancel_target()
	var actions: Array=current.get("playerState",{}).get("actionQueue",[])
	if changed("action-queue",[actions,rules.text.revision]): action_queue.present(rules.queued_actions(actions))
	sync_party()
	var shortcut_items: Array=[]
	for binding in state.get("quickbar",[]):
		if int(binding.get("type",0))==1: shortcut_items.append(objects.get(int(binding.get("itemId",-1)),{}).get("item",{}))
	if changed("shortcuts",[state.get("quickbar",[]),current.get("playerState",{}).get("spellbooks",{}),current.get("playerState",{}).get("featUses",{}),current.get("playerState",{}).get("specialAbilities",[]),current.get("playerState",{}).get("playerFlags",0),current.get("playerState",{}).get("fields9E8",[]),shortcut_items]): refresh_quickbar()
	var effects: Dictionary=current.get("playerState",{})
	if changed("buffs",[effects.get("effectIcons",{}),effects.get("effectIconSerials",{}),rules.text.revision]):
		serial+=1; var rows: Array=rules.effect_icons(effects)
		buffs.receive({"kind":"buff-begin","viewId":serial,"actorId":actor_id,"count":rows.size()}); buffs.receive({"kind":"buff-rows","viewId":serial,"rows":rows}); buffs.receive({"kind":"buff-commit","viewId":serial})
	if sheet.wanted:
		var displayed:=sheet_character()
		if not displayed.is_empty() and changed("sheet",[displayed.get("id"),sheet_context,displayed.get("inventoryStats",{}),displayed.get("replicated",{}).get("stats",{}),displayed.get("replicated",{}).get("hitPoints",{}),displayed.get("playerState",{})]):refresh_sheet()
	if book.wanted and changed("book",[current.get("playerState",{}).get("spellbooks",{}),current.get("replicated",{}).get("stats",{}).get("classes",[]),rules.feats(current)]): refresh_book()
	if journal.wanted and changed("journal",state.get("journal",{})): refresh_journal(journal.page)
	if players.wanted and changed("players",[players_frame.rows(),current.get("replicated",{}).get("party",{})]): refresh_players()
	if area_map.wanted: refresh_map()
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
			var button: Button=party.cards[int(row.entryId)].get_node("Box/Portrait"); art.bind_portrait(button.get_node("Image"),str(row.portraitKey)); button.text=""
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
		"level-up": level_up.open()
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
func refresh_sheet() -> void:
	var displayed:=sheet_character()
	if displayed.is_empty():
		if not sheet_context.is_empty():retire_sheet_target()
		return
	var foreign:=not sheet_context.is_empty();var identity:=str(generation)+":"+str(displayed.id)
	if foreign:identity+=":"+str(sheet_context.actorLifetime)+":"+str(sheet_context.targetLifetime)
	var model:=rules.record(displayed,identity);var entries:Array=rules.record_entries(displayed,sheet.page) if sheet.page>0 else []
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
		else:art.bind_portrait(sheet.image_nodes.portrait,resource)
	for key in ["Str","Dex","Con","Int","Wis","Cha"]:
		if sheet.image_nodes.has("ability:"+key): art.bind(sheet.image_nodes["ability:"+key],"gui_chrsht_"+key.to_lower())
	for entry in sheet.state.get("entries",[]):
		if sheet.image_nodes.has("entry:"+str(entry.entryId)): art.bind(sheet.image_nodes["entry:"+str(entry.entryId)],str(entry.icon))
func refresh_book() -> void:
	serial+=1; var model: Dictionary=rules.spellbook_tree(actor(),book_class,book_level,book_meta,family_path,family_domain) if is_instance_valid(book_frame) and book_frame.layout_ready else rules.spellbook(actor(),book_class,book_level,book_meta,family_path,family_domain); preparation.decorate(model); model.kind="spellbook-view"; model.viewId=serial; book_class=int(model.classIndex); book.receive(model)
	if not preparation.notice.is_empty(): book.notice.text=preparation.notice
func bind_book_art() -> void:
	for id in book.widgets:
		if book.widgets[id].is_visible_in_tree(): art.bind(book.widgets[id].image,str(book.rows[id].icon))
func prewarm_quickbar_item_icons() -> void:
	quickbar_item_keys.clear(); quickbar_item_retry.clear(); quickbar_icon_errors.clear(); quickbar_item_tables_wait=false
	if not owner_ui.inventory.icon_tables_ready():
		for binding in quick_bindings:
			if int(binding.get("type",0))==1: quickbar_item_tables_wait=true; break
		return
	var icons=owner_ui.inventory.icons
	var gender:=int(actor().get("appearance",{}).get("gender",0))
	for index in mini(36,quick_bindings.size()):
		if int(quick_bindings[index].get("type",0))!=1: continue
		var item: Dictionary=objects.get(int(quick_bindings[index].get("itemId",-1)),{}).get("item",{})
		if item.is_empty(): continue
		var key: String=icons.request(item,owner_ui.text.tables,gender)
		if not key.is_empty(): quickbar_item_keys[index]=key
		elif icons.last_request_error=="Native asset queue is full": quickbar_item_retry.append(index)
		elif not icons.last_request_error.is_empty(): quickbar_icon_errors[index]=icons.last_request_error
func quickbar_item_icons_ready() -> bool:
	if quickbar_item_tables_wait:
		if not owner_ui.inventory.icon_tables_ready(): return false
		prewarm_quickbar_item_icons(); call_deferred("bind_quickbar_art"); return false
	if quickbar_binding_art or quickbar_art_view!=quickbar.quickbar_id: return false
	if not quickbar_item_retry.is_empty():
		var retry: Array=quickbar_item_retry.duplicate(); quickbar_item_retry.clear()
		var icons=owner_ui.inventory.icons
		var gender:=int(actor().get("appearance",{}).get("gender",0))
		for index in retry:
			if index>=quick_bindings.size(): continue
			var item: Dictionary=objects.get(int(quick_bindings[index].get("itemId",-1)),{}).get("item",{})
			if item.is_empty(): continue
			var key: String=icons.request(item,owner_ui.text.tables,gender)
			if not key.is_empty(): quickbar_item_keys[index]=key
			elif icons.last_request_error=="Native asset queue is full": quickbar_item_retry.append(index)
			elif not icons.last_request_error.is_empty(): quickbar_icon_errors[index]=icons.last_request_error
		if not quickbar_item_retry.is_empty(): return false
	for key in quickbar_item_keys.values():
		if not owner_ui.inventory.icons.textures.has(key) and not owner_ui.inventory.icons.failed.has(key): return false
	return true
func refresh_quickbar() -> void:
	quick_bindings=state.get("quickbar",[]).duplicate(true); var rows: Array=[]
	for index in 36:
		var binding: Dictionary=quick_bindings[index] if index<quick_bindings.size() else {"type":0}
		rows.append(shortcut_row(binding))
	prewarm_quickbar_item_icons()
	quickbar_art_view=-1
	serial+=1; quickbar.receive({"kind":"quickbar-view","quickbarId":serial,"rows":rows})
	if not shortcut_context.is_empty() and not shortcut_scope_valid(shortcut_context):retire_shortcut_context()
func bind_quickbar_art() -> void:
	quickbar_binding_art=true
	item_art.clear()
	for index in quickbar.buttons:
		var item: Dictionary=objects.get(int(quick_bindings[index].get("itemId",-1)),{}).get("item",{}) if owner_ui.inventory.icon_tables_ready() and index<quick_bindings.size() and int(quick_bindings[index].get("type",0))==1 else {}
		if not item.is_empty():
			var key: String=owner_ui.inventory.icons.request(item,owner_ui.text.tables,int(actor().get("appearance",{}).get("gender",0)))
			if not key.is_empty():
				if not item_art.has(key): item_art[key]=[]
				item_art[key].append({"index":index,"view":quickbar.quickbar_id})
				if owner_ui.inventory.icons.textures.has(key): item_icon_ready(key,owner_ui.inventory.icons.textures[key],"")
		var row: Dictionary=quickbar.rows[index]; art.bind(quickbar.buttons[index].image,str(row.get("icon","")))
	quickbar_binding_art=false; quickbar_art_view=quickbar.quickbar_id
	if is_instance_valid(quickbar_frame): quickbar_frame.try_admit()
func shortcut_row(binding: Dictionary) -> Dictionary:
	var type:=int(binding.get("type",0)); var id:=int(binding.get("intParam",0)); var table:="spells" if type in [2,44] else "feat" if type==4 else "skills" if type==3 else ""
	if type==4: id&=65535
	var action_icon:=""
	var uses: Variant=null
	var spell_shortcut: Dictionary={}
	if type==2: spell_shortcut=spell_rules.shortcut(actor(),binding); uses=spell_shortcut.uses
	elif type==4:
		uses=feat_rules.remaining(feat_rules.context(actor(),actor_id),id)
		if uses==100: uses=null
	elif type==44:
		uses=0; var source:=id; var visited: Dictionary={}
		while source>=0 and not visited.has(source):
			visited[source]=true
			for ability in actor().get("playerState",{}).get("specialAbilities",[]):
				if ability is Dictionary and int(ability.get("spell",-1))==source and int(ability.get("level",0))==int(binding.get("domainLevel",0)) and Rules.flag(ability.get("state",false)): uses=int(uses)+1
			if int(uses)>0: break
			source=Rules.number(Rules.cell(rules.row("spells",source),"Master"),-1)
	var label:="Empty" if type==0 else rules.title(table,id,"FEAT" if type==4 else "Name") if not table.is_empty() else str(binding.get("commandLabel","Action"))
	if type==4:
		var value:=feat_rules.leaf(feat_rules.context(actor(),actor_id,true),int(binding.intParam))
		if not value.is_empty() and not value.get("submenu",false): label=owner_ui.text.raw({"strRef":int(value.labelRef)}); action_icon=str(value.icon)
		else:
			var info:=feat_rules.feat(id); var spell:=feat_rules.target_spell(id,int(binding.get("auxiliary",(int(binding.intParam)>>16)&65535)))
			if not info.is_empty() and spell>=0 and spell!=int(info.spellId): label=rules.title("spells",spell); action_icon=rules.icon("spells",spell)
	if type==42:
		var value:=shortcut_rules.command(id)
		if not value.is_empty():label=owner_ui.text.raw({"strRef":int(value.labelRef)});action_icon=str(value.icon)
	elif type==39:
		var value:=shortcut_rules.associate(binding);label=""
		if not value.is_empty():
			label=owner_ui.text.raw({"strRef":int(value.labelRef)});action_icon=str(value.icon)
			var associate_id:=int(binding.get("associateId",INVALID));var associate_object: Dictionary=objects.get(associate_id,{})
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
		var item: Dictionary=objects.get(int(binding.get("itemId",-1)),{}).get("item",{}); label=owner_ui.text.name(item.get("name"),int(binding.get("itemId",-1)))
		var base:=rules.row("baseitems",int(item.get("baseItem",-1))); var resolved:=item_binding(binding); var index:=int(resolved.get("intParam",255))&65535
		if Rules.number(Rules.cell(base,"Stacking"),0)>1: uses=item.get("stackSize",item.get("field454"))
		if index<item.get("properties",[]).size():
			var property: Dictionary=item.properties[index]
			if int(property.type)==15:
				var cost:=int(property.get("costValue",0))
				if cost in [7,13]: uses="*"
				elif cost!=1: uses=item.get("propertyUses",item.get("field351",[])).get(str(index),0) if item.get("propertyUses",item.get("field351",[])) is Dictionary else item.get("propertyUses",item.get("field351",[]))[index] if index<item.get("propertyUses",item.get("field351",[])).size() else 0

	return {"empty":type==0,"label":label,"enabled":bool(spell_shortcut.enabled) if type==2 else type!=0 and (uses==null or uses is String and uses=="*" or int(uses)>0),"uses":uses,"icon":action_icon if type==4 and not action_icon.is_empty() else rules.icon(table,id) if not table.is_empty() else action_icon}
func assign(index: int,binding: Dictionary) -> void:
	if index<0 or index>=36: return
	var button: Dictionary=item_binding(binding) if int(binding.get("type",0))==1 else FeatRadial.binding(int(binding.intParam),int(binding.get("auxiliary",(int(binding.intParam)>>16)&65535))) if int(binding.get("type",0))==4 else binding
	command({"kind":"native-quickbar-assign","index":index,"button":button})
func activate(binding: Dictionary,source_index: int=-1) -> void:
	if source_index>=0 and (source_index>=quick_bindings.size() or quick_bindings[source_index]!=binding):return
	var shortcut_index:=source_index if source_index>=0 else quick_bindings.find(binding)
	match int(binding.get("type",0)):
		2: begin_target(spell_rules.shortcut(actor(),binding).binding)
		44,4,3: begin_target(binding)
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
			if int(binding.get("associateType",0)) not in [1,2,3]:return
			if shortcut_index>=0:command({"kind":"native-quickbar-activate","index":shortcut_index})
			else:
				var id:=int(binding.get("associateId",INVALID)) if int(binding.associateType)==1 else int(actor().get("companionId" if int(binding.associateType)==2 else "familiarId",INVALID))
				command({"kind":"native-associate","targetId":id,"command":(int(binding.intParam)&65535)-65536 if int(binding.intParam)&32768 else int(binding.intParam)&65535})
		1:
			var prepared:=item_binding(binding)
			if int(prepared.intParam)&65535!=255: begin_target(prepared)
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
func begin_target(binding: Dictionary) -> void:
	target=binding.duplicate(true); var type:=int(binding.get("type",0)); var id:=int(binding.get("intParam",0))
	if type in [6,7,40,41]:
		target_prompt.text="Choose a target for "+str(shortcut_row(binding).label)+" · Esc or right-click to cancel";target_prompt.show();target_changed.emit(true);return
	if type==10:
		target_prompt.text="Choose a creature to counterspell · Esc or right-click to cancel"; target_prompt.show(); target_changed.emit(true); return
	if type==3 and id==10: cancel_target(); command({"kind":"native-mode","modeId":2}); return
	if type==3 and id==22: cast_target(actor_id,Vector3.ZERO); return
	if type==4:
		var auxiliary:=int(binding.get("auxiliary",(id>>16)&65535))&65535; id&=65535
		var info:=feat_rules.feat(id)
		if info.is_empty(): cancel_target(); return
		if auxiliary==0 and FeatRadial.MODES.has(id): cancel_target(); command({"kind":"native-mode","modeId":FeatRadial.MODES[id]}); return
		target.spellId=feat_rules.target_spell(id,auxiliary)
		if int(info.targetSelf)!=0: cast_target(actor_id,Vector3.ZERO); return
	else:
		var data:=rules.row("spells" if type in [1,2,44] else "skills",int(binding.get("spellId",id)))
		if Rules.number(Rules.cell(data,"TargetType"),-1)==1: cast_target(actor_id,Vector3.ZERO); return
	target_prompt.text="Choose a target for "+str(shortcut_row(binding).label)+" · Esc or right-click to cancel"; target_prompt.show(); target_changed.emit(true)
func cancel_target() -> void:
	target.clear()
	if is_instance_valid(target_prompt): target_prompt.hide()
	target_changed.emit(false)
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
	var kind:=int(object.get("objectType",2 if has_ground else 0)); var spell_id:=int(target.get("spellId",target.get("intParam",-1))); var property_type:=-1
	if type==1:
		var properties: Array=objects.get(int(target.get("itemId",-1)),{}).get("item",{}).get("properties",[]); var index:=int(target.get("intParam",0))&65535
		if index<properties.size(): property_type=int(properties[index].get("type",-1))
		var variant:=(int(target.get("intParam",0))>>16)&255
		var children:=preload("res://systems/native_data/item_radial.gd").new(); children.rules=rules
		var variants: Array=children.children(spell_id)
		if variant!=255 and variant<variants.size(): spell_id=int(variants[variant])
	var mask:=Rules.number(Rules.cell(rules.row("spells",spell_id),"TargetType"),0)&65535
	return preload("res://systems/native_data/mouse_cursor.gd").target(target,kind,id==actor_id,mask,property_type)
func cast_target(id: int,point: Vector3) -> void:
	if target.is_empty(): return
	var binding:=target.duplicate(); var type:=int(binding.get("type",0))
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
		var kind:=int(objects.get(id,{}).get("objectType",2)); var bit: int=[5,6,7,10,11,12,9,14,13,2].find(kind)
		if bit<0 or (int(binding.objectMask)&(1<<bit))==0: target_prompt.text="Choose a valid target for the server action."; return
		cancel_target(); command({"kind":"native-script-target","version":int(binding.version),"targetId":INVALID if id<0 else id,"position":[point.x,-point.z,point.y]}); return
	if type==3 and (not objects.has(id) or int(objects[id].get("objectType",0)) not in ([9,10] if int(binding.intParam)==9 else [5])): target_prompt.text="Choose a valid target for this skill."; return
	cancel_target()
	var message:={"kind":"native-item-ability" if type==1 else "native-cast" if type==2 else "native-spell-like" if type==44 else "native-feat" if type==4 else "native-skill","targetId":INVALID if id<0 else id,"position":[point.x,-point.z,point.y]}
	if type==1: message.itemId=int(binding.itemId); message.propertyIndex=int(binding.intParam)&255; message.variant=(int(binding.intParam)>>16)&255
	elif type in [2,44]: message.spellId=int(binding.intParam); message.classIndex=int(binding.get("classIndex",0)); message.domainLevel=int(binding.get("domainLevel",0)); message.metamagic=int(binding.get("metamagic",0)); message.casterLevel=int(binding.get("domainLevel",0)); message.spontaneous=int(binding.get("spontaneous",0))
	elif type==4: message.featId=int(binding.intParam)&65535; message.auxiliary=int(binding.get("auxiliary",(int(binding.intParam)>>16)&65535))
	else: message.packedSkill=int(binding.intParam); message.position=[0,0,0]
	command(message)
func world_click(hit: Dictionary) -> bool:
	if target.is_empty(): return false
	var cursor:=target_cursor(int(hit.get("id",-1)),not hit.is_empty())
	if not cursor.get("valid",false): target_prompt.text="Choose a valid target for this action."; return true
	cast_target(int(hit.get("id",-1)),hit.get("position",Vector3.ZERO)); return true
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
			sheet.page=int(message.get("page",0)); command({"kind":"native-panel","panel":"character","open":true,"page":sheet.page}.merged(scope)); refresh_sheet()
		"sheet-close":
			var scope:=sheet_request_scope()
			if not scope.is_empty():command({"kind":"native-panel","panel":"character","open":false}.merged(scope))
			sheet_context.clear();signatures.erase("sheet")
		"sheet-select": inspect_sheet_entry(message)
		"spellbook-open","spellbook-query":
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
			if int(message.viewId)==book.view_id and book.rows.has(int(message.entryId)): book.receive({"kind":"book-description","viewId":book.view_id,"entryId":message.entryId,"rich":rules.description("spells",int(book.rows[int(message.entryId)].spellId))})
		"book-activate":
			if int(message.viewId)==book.view_id and book.rows.has(int(message.entryId)) and book.rows[int(message.entryId)].canCast: activate(book.rows[int(message.entryId)].binding)
		"book-prepare","book-clear": prepare_spell(message)
		"quickbar-activate":
			var index:=int(message.index)
			if int(message.quickbarId)==quickbar.quickbar_id and index>=0 and index<quick_bindings.size(): activate(quick_bindings[index],index)
		"quickbar-clear":
			if int(message.quickbarId)==quickbar.quickbar_id: assign(int(message.index),{"type":0})
		"quickbar-move":
			if int(message.quickbarId)==quickbar.quickbar_id and int(message.sourceIndex)>=0 and int(message.sourceIndex)<quick_bindings.size() and int(message.sourceIndex)!=int(message.index): assign(int(message.index),quick_bindings[int(message.sourceIndex)]); assign(int(message.sourceIndex),{"type":0})
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
			if can_radial_shortcut(message) and radial_entries.has(int(message.slot)): assign(int(message.index),radial_entries[int(message.slot)].binding)
		"item-radial-shortcut":
			var source: Dictionary=message.duplicate(); source.kind="item-radial-entry"
			var binding: Dictionary=owner_ui.inventory.item_context.binding(source)
			if int(message.get("quickbarId",-1))==quickbar.quickbar_id and not binding.is_empty(): assign(int(message.index),binding)
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
		serial+=1; map_view=serial; map_cells=[]
		for tile in area.get("tiles",[]): map_cells.append(map_cells.size())
		var controls:={"pin":map_cells.size(),"hilite":map_cells.size()+1,"down":map_cells.size()+2,"player":map_cells.size()+3}
		area_map.receive({"kind":"map-view","viewId":map_view,"width":int(area.get("width",0)),"height":int(area.get("height",0)),"cells":map_cells,"controls":controls})
		for definition in [["pin","CTL_MAP_PIN","up"],["hilite","CTL_MAP_PIN","hilite"],["down","CTL_MAP_PIN","down"],["player","CTL_MAP_XMARKER","up"]]:
			map_queue.append({"index":controls[definition[0]],"model":definition[1],"clip":definition[2],"overrides":{},"turn":0})
		map_set_job=art.assets.request(str(area.get("tileset","")),2013,"bytes")
		signatures.erase("map-exploration")
	var pins:=map_pins(area,exploration)
	if changed("map-exploration",[exploration,pins]):
		area_map.receive({"kind":"map-state","viewId":map_view,"explored":exploration,"pins":pins}); prepare_map_level(map_frame.level)
	var pose: Array=actor().get("replicated",{}).get("position",[])
	if pose.size()==3:
		var board=area_map.board; board.point=map_point(pose,area)
		var direction: Vector3=preload("res://systems/network_motion.gd").facing(actor().get("replicated",{}).get("orientation",[0,1,0]))
		board.heading=rad_to_deg(atan2(-direction.x,direction.y))
		board.queue_redraw()
func map_point(position: Array,area: Dictionary) -> Array:
	return [(float(position[0])/10.0-float(area.get("width",0))/2.0)*0.16,(float(position[1])/10.0-float(area.get("height",0))/2.0)*0.16] if position.size()>=2 else []
func map_pins(area: Dictionary,explored: Array) -> Array:
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
		var x:=floori(float(position[0])/10.0); var y:=floori(float(position[1])/10.0); var index:=y*width+x
		var visible: bool=Rules.flag(pin.get("enabled",true)) and x>=0 and x<width and y>=0 and y<int(area.get("height",0)) and index<explored.size() and int(explored[index])==1
		var source: Variant=pin.get("name",pin.get("text",{}))
		result.append({"key":key,"type":entry.type,"reference":entry.reference,"viewId":map_view,"scope":[generation,area_id,actor_id],"position":position.duplicate(),"text":owner_ui.text.raw(source),"visible":visible,"point":map_point(position,area),"rich":owner_ui.text.rich(source,actor_id)})
	return map_frame.apply_overlays(result) if is_instance_valid(map_frame) else result
func map_prepared(id: int,result: Dictionary) -> void:
	if closed or id!=map_set_job or not area_map.wanted or area_map.view_id!=map_view: return
	map_set_job=-1
	if not str(result.error).is_empty(): area_map.note.text="Map artwork unavailable: "+str(result.error); return
	map_definition=preload("res://systems/native_data/area_definition.gd").new().parse_set(result.bytes.get_string_from_utf8())
	prepare_map_level(map_frame.level)
func prepare_map_level(level: int) -> void:
	if map_definition.is_empty() or not area_map.wanted or level<0 or level>2: return
	var area: Dictionary=state.get("area",{}); var tiles: Array=map_definition.get("tiles",[])
	var exploration: Array=actor().get("playerState",{}).get("mapExploration",{}).get(str(area_id),[])
	for index in area.get("tiles",[]).size():
		var key:=str(level)+":"+str(index)
		if map_tile_queued.has(key) or index>=exploration.size() or int(exploration[index])!=1: continue
		var tile: Dictionary=area.tiles[index]; var fields: Dictionary=tile.get("fields",{}); var tile_id:=int(fields.get("14",tile.get("id",0))); var turn:=int(fields.get("24",tile.get("orientation",0)))
		if tile_id<0 or tile_id>=tiles.size(): continue
		var raster:=str(tiles[tile_id].get("fields",{}).get("ImageMap2D","")).left(16)
		if raster.is_empty() or raster=="****": continue
		map_tile_queued[key]=true
		map_queue.append({"index":index,"bank":level,"model":preload("res://systems/native_data/area_map_layout.gd").ICONS[level],"clip":"","overrides":{"gui_replace01":raster},"turn":turn})
func pump_map_art() -> void:
	if map_queue.is_empty() or closed or not area_map.wanted or area_map.view_id!=map_view or art.models.pending.size()>=80: return
	for count in mini(2,map_queue.size()):
		var job: Dictionary=map_queue.pop_front(); var key: String=art.request_model(str(job.model),str(job.clip),job.overrides,int(job.turn))
		if key.is_empty(): area_map.note.text="Some installed map artwork could not be loaded."; continue
		if not map_jobs.has(key): map_jobs[key]=[]
		map_jobs[key].append({"view":map_view,"index":job.index,"bank":int(job.get("bank",-1))})
		if art.textures.has(key): map_art_ready(key,art.textures[key],art.bounds.get(key,{}))
func map_art_ready(key: String,texture: Texture2D,bounds: Dictionary) -> void:
	if closed or not map_jobs.has(key) or bounds.is_empty(): return
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
	if not target.is_empty(): cancel_target(); return
	if actor().is_empty():return
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
	var object: Dictionary=objects.get(radial_target,{}); var kind:=int(object.get("objectType",0)); var entries: Array=[]
	var portrait:=rules.portrait(object) if kind==5 else ""
	if origin=="portrait" and kind!=5:
		var permission:=PlayerIdentity.permission(state.get("gameMasterPermission"))
		if not permission.available or not permission.permission:
			world_radial_coverage={"coverage":"portrait-canonical-creature-unavailable","missing":["clicked.canonical-creature"],"pending":[]};retire_current_radial(radial.request_id);return
	if origin in ["world","portrait"] and kind==5 and radial_target!=actor_id and owned_associate_creature(object,portrait,origin):return
	if origin=="world" and kind==5 and radial_target!=actor_id and normal_other_creature(object,portrait):return
	if radial_target==actor_id:
		creature_radial.rules=rules
		var model:=creature_radial.normal_self(actor(),{"partyOwnerPresent":is_instance_valid(party)})
		world_radial_coverage={"coverage":model.coverage,"origin":origin,"missing":model.missing,"pending":model.pending}
		show_radial({"title":owner_ui.text.name(null,radial_target),"entries":model.entries,"center":portrait if not portrait.is_empty() else "ir_examine","portraitCenter":not portrait.is_empty()},true)
		return
	if kind==5: entries.append(entry(3,"Special attacks","branch","ir_xattack",{"children":special_attacks()}))
	if radial_target<0:
		entries.append(entry(1,"Cast spell","branch","ir_cast",{"children":spell_branches()})); entries.append(entry(6,"Special abilities","branch","ir_xability",{"menu":{"kind":"abilities"}}))
		entries.append(entry(2,"Move to","move","ir_moveto"))
	else:
		entries.append(entry(0,"Examine","examine","ir_examine"))
		if kind==5:
			entries.append(entry(7,owner_ui.text.raw({"strRef":0x107}),"barter","ir_barter") if player_target(radial_target) else entry(7,"Talk","interact","ir_dialog",{"interaction":"conversation.start"})); entries.append(entry(2,"Attack","interact","ir_attack",{"interaction":"combat.attack"}))
			if int(object.get("replicated",{}).get("master",-1))==actor_id: entries.append(entry(5,"Companion commands","branch","IR_COMMAND",{"children":party_commands(radial_target)}))
		elif kind==10:
			var door: Dictionary=object.get("replicated",{})
			var open: bool=int(door.get("doorOpenState",{22:0,50:1,51:2,72:3}.get(int(door.get("animation",22)),0)))!=0
			entries.append(entry(2,"Close" if open else "Open","interact","ir_use",{"interaction":"door.close" if open else "door.open"}))
		elif kind==9: entries.append(entry(2,"Use","interact","ir_use",{"interaction":"object.use"}))
		elif kind==6: entries.append(entry(2,"Pick up","pickup","ir_pickup"))
		entries.append(entry(1,"Cast spell","branch","ir_cast",{"children":spell_branches()})); entries.append(entry(6,"Special abilities","branch","ir_xability",{"menu":{"kind":"abilities"}}))
	show_radial({"title":owner_ui.text.name(null,radial_target) if radial_target>=0 else "Ground","entries":entries,"center":portrait if not portrait.is_empty() else "ir_examine","portraitCenter":not portrait.is_empty()},true)
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
	ctx.targetBit=8 if target_mask==8 else 4 if radial_target<0 or radial_target==INVALID else (1 if radial_target==actor_id else 2) if int(object.get("objectType",0))==5 else {6:8,10:16,9:32,7:64}.get(int(object.get("objectType",0)),0)
	var result:=spell_rules.menu(ctx,menu)
	for at in result.size():
		if result[at].has("epicFeat"): result[at]=decorate_feat(feat_rules.leaf(ctx,int(result[at].epicFeat)),int(result[at].slot),ctx)
	return result.filter(func(value):return not value.is_empty())
func spell_radial(binding: Dictionary,path: Array,target_mask: int=0,uses: Variant=null) -> Dictionary:
	var id:=int(binding.intParam); var children: Array=[]
	if path.size()<16:
		for child in rules.spell_children(id,path):
			var next:=binding.duplicate(); next.intParam=child; var value:=spell_radial(next,path+[id],target_mask,uses)
			if not value.is_empty(): children.append(value)
	if target_mask and children.is_empty() and (Rules.number(Rules.cell(rules.row("spells",id),"TargetType"),0)&target_mask)==0: return {}
	var disabled: bool=not pending_shortcuts.has("index") and (not radial_spell_allowed(id) or uses!=null and int(uses)<1)
	var extra: Dictionary={"children":children} if not children.is_empty() else {"binding":binding}
	extra.disabled=disabled; extra.uses=uses
	return entry(0,rules.title("spells",id),"branch" if not children.is_empty() else "power",rules.icon("spells",id),extra)
func radial_spell_allowed(id: int) -> bool:
	var mask:=Rules.number(Rules.cell(rules.row("spells",id),"TargetType"),0)&65535
	if radial_target<0: return (mask&4)!=0
	var object: Dictionary=objects.get(radial_target,{})
	var bit: int=(1 if radial_target==actor_id else 2) if int(object.get("objectType",0))==5 else {6:8,10:16,9:32,7:64}.get(int(object.get("objectType",0)),0)
	return (mask&bit)!=0
func feat_context() -> Dictionary:
	var ctx:=feat_rules.context(actor(),radial_target,pending_shortcuts.has("index"))
	var familiar_id:=int(actor().get("familiarId",INVALID))
	if objects.has(familiar_id) and not objects[familiar_id].get("replicationRemoved",false): ctx.familiar={"id":familiar_id}
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
	if radial.active and not radial_stack.is_empty() and (str(radial_stack[-1].get("kind","")).begins_with("spell-") or str(radial_stack[-1].get("kind","")) in ["abilities","class-abilities","ability-classes"]):
		show_radial(radial_stack[-1])
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
	if quick_kind=="quickbar-actions":return shortcut_rules.actions(actor())
	if quick_kind=="quickbar-attacks":return special_attacks()
	if quick_kind=="quickbar-commands":return shortcut_rules.commands()+QuickbarAssociates.entries(self,menu)
	if quick_kind in ["quickbar-associates-more","quickbar-associate-member"]:return QuickbarAssociates.entries(self,menu)
	if quick_kind in ["quickbar-emotes","quickbar-emotes-more","quickbar-emotes-last"]:
		var classes: Array=ability_rules.classes(actor());var first: int=int(classes[0].get("id",255)) if not classes.is_empty() else 255
		return shortcut_rules.emotes(["quickbar-emotes","quickbar-emotes-more","quickbar-emotes-last"].find(quick_kind),first)
	var ctx:=feat_context(); var result: Array=[]; var kind:=str(menu.get("kind",""))
	if kind in ["abilities","ability-classes"]:
		if kind=="abilities":
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
				var value:=spell_radial({"type":44,"intParam":int(source.spellId),"domainLevel":int(source.domainLevel)},[],0,int(source.uses))
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
		var children: Array=[]
		for child in feat_rules.variants(ctx,id): children.append(decorate_feat(child,int(child.slot),ctx))
		return entry(slot,label,"branch",icon,{"children":children})
	return entry(slot,label,"power",icon,{"binding":{"type":38} if value.action=="associate.possessFamiliar" else FeatRadial.binding(id,int(value.auxiliary)),"uses":value.uses,"disabled":bool(value.disabled)})
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
		"mode": cancel_target(); command({"kind":"native-mode","modeId":int(selection.modeId)})
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
	var context=owner_ui.inventory.item_context
	var choices: Array=context.policy.powers(objects.get(id,{}).get("item",{}))
	if choices.size()==1 and choices[0].action=="use" and not choices[0].disabled:
		begin_target(item_binding({"type":1,"itemId":id,"intParam":int(choices[0].payload),"spellId":int(choices[0].get("spellId",-1))})); return
	owner_ui.inventory.item_context.open_inventory(id,get_viewport().get_mouse_position(),true)
func item_menu_ability(binding: Dictionary) -> void:
	if binding.has("itemTarget"):
		target=binding.duplicate(true)
		var id:=int(binding.itemTarget)
		if target_cursor(id).get("valid",false): cast_target(id,Vector3.ZERO)
		else: cancel_target()
	else: begin_target(item_binding(binding))
func item_icon_ready(key: String,texture: Texture2D,error: String) -> void:
	if closed: return
	if not error.is_empty() and quickbar_item_keys.values().has(key) and is_instance_valid(target_prompt): target_prompt.text="Shortcut icon unavailable: "+error; target_prompt.show()
	if texture!=null and error.is_empty():
		for job in item_art.get(key,[]):
			if int(job.view)==quickbar.quickbar_id and quickbar.buttons.has(int(job.index)): quickbar.buttons[int(job.index)].image.texture=texture
	if not quickbar_binding_art and is_instance_valid(quickbar_frame): quickbar_frame.try_admit()
func show_radial(menu: Dictionary,push: bool=false) -> void:
	if push: radial_stack.append(menu)
	radial_entries.clear(); radial_serial+=1; var entries: Array=[]; var source: Array=ability_entries(menu) if menu.has("kind") else menu.entries
	var physical:=source.size()<=8; var slots: Dictionary={}
	for item in source:
		var slot:=int(item.get("slot",-1))
		if slot<0 or slot>7 or slots.has(slot): physical=false
		slots[slot]=true
	for index in mini(source.size(),8):
		var item: Dictionary=source[index].duplicate(true); item.slot=int(item.slot) if physical else index; radial_entries[int(item.slot)]=item; entries.append(item)
	if source.size()>8:
		entries.resize(7); radial_entries.erase(7); var more:=entry(7,"More…","branch","IR_MORE_SP_AB",{"children":source.slice(7)}); entries.append(more); radial_entries[7]=more
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":radial_serial,"depth":maxi(0,radial_stack.size()-1),"title":menu.get("title","Special abilities"),"entries":entries})
	var record:={"actor_id":actor_id,"area_id":area_id,"generation":generation,"menu_id":radial_serial,"depth":maxi(0,radial_stack.size()-1),"title":menu.get("title","Special abilities"),"entries":[]}
	for value in entries: record.entries.append({"slot":int(value.slot),"label":str(value.label),"submenu":bool(value.get("submenu",false)),"disabled":bool(value.get("disabled",false)),"binding":value.get("binding",{}).duplicate()})
	radial_history.append(record)
	if radial_history.size()>64: radial_history.pop_front()
	radial.set_center(str(menu.get("center","ir_use")),bool(menu.get("portraitCenter",false)))
	for slot in radial_entries: art.bind(radial.icons[int(slot)],str(radial_entries[slot].icon))
func radial_preview(slot: int,request_id: int,menu_id: int) -> Array:
	if not radial.active or request_id!=radial.request_id or menu_id!=radial.menu_id or not radial_entries.has(slot): return []
	var parent: Dictionary=radial_entries[slot]; var values: Array=ability_entries(parent.menu) if parent.has("menu") else parent.get("children",[])
	var result: Array=[]; var slots: Dictionary={}; var physical:=values.size()<=8
	for value in values:
		var at:=int(value.get("slot",-1))
		if at<0 or at>7 or slots.has(at): physical=false
		slots[at]=true
	for index in mini(values.size(),8 if values.size()<=8 else 7):
		var value: Dictionary=values[index].duplicate(); value.slot=int(value.slot) if physical else index; result.append(value)
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
	if item.has("children"): show_radial({"title":item.label,"entries":item.children,"center":item.icon},true); return
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
	radial.reset(); radial_stack.clear(); pending_shortcuts.clear();shortcut_context.clear();world_context.clear()
func barter_item_menu(id: int,point: Vector2,removable: bool) -> void:
	owner_ui.inventory.item_context.open_trade(owner_ui.barter,id,point)
func shortcut_menu(index: int,point: Vector2) -> void:
	if not owner_ui.tables_ready or index<0 or index>=mini(36,quick_bindings.size()): return
	var began:=Time.get_ticks_usec();retire_shortcut_context()
	owner_ui.inventory.item_context.cancel()
	shortcut_context={"generation":generation,"area":area_id,"actor":actor_id,"index":index,"binding":quick_bindings[index].duplicate(true)}
	var binding: Dictionary=shortcut_context.binding;var type:=int(binding.get("type",0));shortcut_rules.rules=rules
	if type==1:
		var identity:=shortcut_context.duplicate(true)
		var texture: Texture2D=quickbar.buttons[index].image.texture if is_instance_valid(quickbar) and quickbar.buttons.has(index) else null
		owner_ui.inventory.item_context.open_quickbar(int(binding.get("itemId",INVALID)),point,func():return shortcut_scope_valid(identity),func():if shortcut_scope_valid(identity):assign(index,{"type":0}),binding,texture)
		finish_shortcut_timing(index,type,began,owner_ui.inventory.item_context.entries.size())
		return
	radial.open_at(point,actor_id,Vector3.ZERO,false); radial_stack.clear(); pending_shortcuts={"index":index} if type==0 else {}
	radial_target=actor_id; radial_position=Vector3.ZERO
	var row:=shortcut_row(binding);show_radial({"title":str(row.label),"entries":shortcut_rules.empty() if type==0 else shortcut_rules.bound(binding,bool(row.enabled),str(row.icon),str(row.label)),"center":"" if type==0 else str(row.icon)},true)
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
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var bindings=owner_ui.key_bindings
	if is_instance_valid(bindings) and bindings.blocked(): return
	var focus:=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return
	if event.keycode==KEY_ESCAPE and not target.is_empty(): cancel_target(); get_viewport().set_input_as_handled(); return
	if event.keycode==KEY_ESCAPE:
		var candidates: Array=owner_ui.controls.get_children(); candidates.reverse()
		for view in candidates:
			if view is Draggable and view.visible:
				view.close_requested.emit()
				if view.close_hides: view.hide()
				get_viewport().set_input_as_handled(); return
	if is_instance_valid(bindings):
		var actions:={66:"character",68:"map",65:"journal",70:"options",107:"rest",69:"pvp"}
		var selected: int=bindings.action(event,actions.keys())
		if actions.has(selected): panel(str(actions[selected])); get_viewport().set_input_as_handled()
		elif bindings.action_matches(62,event): open_radial({"id":actor_id,"origin":"keyboard"},get_viewport().get_mouse_position()); get_viewport().set_input_as_handled()
	else:
		var panels:={KEY_C:"character",KEY_M:"map",KEY_J:"journal",KEY_O:"options",KEY_R:"rest"}
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
	if message.action in ["native-players","native-party","native-player-attitude"]: players_frame.receive(message); return
	if message.action=="native-map": map_frame.receive(message); return
	if message.action=="native-prepare":
		if not message.accepted and preparation.reject(int(message.get("requestId",-1)),[int(message.get("generation",-1)),int(message.get("areaId",-1)),int(message.get("actorId",-1))],str(message.get("text","Spell preparation could not be sent."))):
			if book.wanted: refresh_book()
		return # Transport acceptance is not a server preparation confirmation.
	# Level-up owns its request/view/lifetime correlation and current error
	# presentation. An old refusal must not show a global prompt over a new UI.
	if message.action=="native-level-up":level_owner.receive_result(message);return
	if not message.accepted:
		if message.action=="native-cancel-action": action_queue.rejected()
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
	closed=true; cancel_target(); objects.clear(); state.clear(); world_context.clear(); sheet_context.clear()
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
	if is_instance_valid(shortcut_dialogs):shortcut_dialogs.close()
	if is_instance_valid(radial): radial.reset()
func _exit_tree() -> void: close()
