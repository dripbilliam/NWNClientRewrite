extends Node
# Native menu ownership and rule projection. The protocol bridge sends raw
# received state/typed requests only; it never constructs these menu models.
signal request(message: Dictionary)
signal options_requested
signal target_changed(active: bool)
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const FeatRadial=preload("res://systems/native_data/feat_radial.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Draggable=preload("res://systems/draggable_panel.gd")
const Preparation=preload("res://systems/native_data/spell_preparation.gd")
const INVALID:=2130706432
const PARTY_COMMANDS=[[0,"Attack nearest","IR_ATTACKNEAREST"],[22,"Follow","IR_FOLLOW"],[10,"Stand ground","IR_STANDGROUND"],[9,"Guard","IR_GUARD"],[4,"Heal me","IR_HEALME"]]
var rules:=Rules.new()
var feat_rules:=FeatRadial.new()
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
var signatures: Dictionary={}
var party
var party_frame
var quickbar
var quickbar_frame
var sheet
var sheet_frame
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
var item_art: Dictionary={}
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
	owner_ui=ui; rules.text=ui.text; feat_rules.rules=rules; art=Art.new(); add_child(art); art.configure(catalog,cache_path); art.assets.completed.connect(map_prepared); art.loaded.connect(map_art_ready)
	party=preload("res://systems/server_party.gd").new(); ui.controls.add_child(party); party.setup(); party.panel_requested.connect(panel)
	party.portrait_selected.connect(func(index,_point):
		if index>=party.rows.size(): return
		if party.rows[index].self: panel("character")
		else: request.emit({"kind":"examine","targetId":party.rows[index].id}))
	party.portrait_menu.connect(func(index,point): if index<party.rows.size(): open_radial({"id":int(party.rows[index].id),"position":Vector3.ZERO},point))
	party.request.connect(func(_message): command({"kind":"native-rest"}))
	party_frame=preload("res://systems/native_party_frame.gd").new(); add_child(party_frame); party_frame.configure(party,catalog,cache_path,ui.text,ui.inventory.frame_skin)
	quickbar=preload("res://systems/server_quickbar.gd").new(); ui.controls.add_child(quickbar); quickbar.setup(); quickbar.request.connect(input_request)
	quickbar.set_key_bindings(ui.key_bindings)
	quickbar.inventory_requested.connect(func(): panel("inventory")); quickbar.character_requested.connect(func(): panel("character")); quickbar.spellbook_requested.connect(func(): panel("spells")); quickbar.map_requested.connect(func(): panel("map")); quickbar.journal_requested.connect(func(): panel("journal")); quickbar.options_requested.connect(func(): options_requested.emit()); quickbar.level_requested.connect(func(): panel("level-up"))
	quickbar.assignment_requested.connect(shortcut_menu); quickbar.rendered.connect(bind_quickbar_art)
	quickbar_frame=preload("res://systems/native_quickbar_frame.gd").new(); add_child(quickbar_frame); quickbar_frame.configure(quickbar,catalog,cache_path,ui.text,ui.inventory.frame_skin)
	for button in quickbar.pages[0].get_parent().get_children():
		if not button is Button or not quickbar.pages.has(button): button.hide()
	sheet=preload("res://systems/server_character_sheet.gd").new(); ui.controls.add_child(sheet); sheet.setup(layout); sheet.request.connect(input_request); sheet.level_requested.connect(func(): panel("level-up"))
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
	action_queue=preload("res://systems/server_action_queue.gd").new(); ui.controls.add_child(action_queue); action_queue.setup(self); action_queue.cancel_requested.connect(func(id,group): command({"kind":"native-cancel-action","actionId":id,"groupId":group}))
	radial=preload("res://systems/server_radial.gd").new(); add_child(radial); radial.request.connect(input_request)
	radial.key_bindings=ui.key_bindings
	radial.configure_art(art)
	quickbar.record_valid=sheet.can_drag; quickbar.inventory_valid=func(data): return int(data.get("viewId",-1))==owner_ui.inventory.ui.view_id and owner_ui.inventory.views.has(int(data.get("entryId",-1)))
	quickbar.radial_valid=func(data): return owner_ui.inventory.item_context.can_shortcut(data) if data.get("kind","")=="item-radial-entry" else radial.can_shortcut(data)
	owner_ui.inventory.ability_requested.connect(use_inventory_item); owner_ui.inventory.icons.completed.connect(item_icon_ready)
	owner_ui.inventory.item_context.opened.connect(radial.reset)
	owner_ui.inventory.item_context.ability_selected.connect(item_menu_ability)
	owner_ui.inventory.item_context.spell_entries=func():return spell_branches(8)
	target_prompt=Label.new(); target_prompt.add_theme_color_override("font_shadow_color",Color.BLACK); target_prompt.add_theme_constant_override("shadow_offset_x",2); target_prompt.add_theme_constant_override("shadow_offset_y",2); target_prompt.position=Vector2(20,65); target_prompt.hide(); ui.controls.add_child(target_prompt)
	startup_notice=Label.new(); startup_notice.text="Preparing spell and feat menus…"; startup_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; startup_notice.position=Vector2(12,40); startup_notice.hide(); ui.controls.add_child(startup_notice)
	ui.inventory.frame_skin.font_style(startup_notice,{"AurString_Font":"fnt_dialog16x16"}); startup_notice.add_theme_color_override("font_color",Color(1,0.85,0.5)); startup_notice.add_theme_color_override("font_shadow_color",Color.BLACK); startup_notice.add_theme_constant_override("shadow_offset_x",2); startup_notice.add_theme_constant_override("shadow_offset_y",2)
func command(value: Dictionary) -> void:
	if closed or not objects.has(actor_id): return
	var message:=value.duplicate(); message.actorId=actor_id; message.areaId=area_id; message.generation=generation; request.emit(message)
func set_world(epoch: int,area: int,controlled: int,raw_objects: Dictionary,header: Dictionary) -> void:
	var began:=Timing.begin()
	retain_replaced_raw_state(raw_objects)
	Timing.finish("snapshot_ui_desktop_retain_ms",began); began=Timing.begin()
	if epoch!=generation or controlled!=actor_id:
		for view in [party,quickbar,sheet,book,journal,area_map,players,buffs,radial,level_up,action_queue]: view.reset()
		Timing.finish("snapshot_ui_desktop_views_ms",began); began=Timing.begin()
		signatures.clear(); family_path.clear(); family_domain=false; radial_stack.clear(); map_jobs.clear(); map_queue.clear(); map_tile_queued.clear(); map_definition.clear(); map_set_job=-1; map_view=-1; cancel_target()
	Timing.finish("snapshot_ui_desktop_transient_ms",began); began=Timing.begin()
	objects=raw_objects; generation=epoch; area_id=area; actor_id=controlled
	if preparation.observe(actor(),[generation,area_id,actor_id],Time.get_ticks_msec()): signatures.erase("book")
	Timing.finish("snapshot_ui_desktop_objects_ms",began); began=Timing.begin()
	state=header; dirty=true
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
	if closed or not objects.has(actor_id) or not owner_ui.hud_ready: return
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
	if changed("action-queue",actions): action_queue.present(rules.queued_actions(actions))
	sync_party()
	var shortcut_items: Array=[]
	for binding in state.get("quickbar",[]):
		if int(binding.get("type",0))==1: shortcut_items.append(objects.get(int(binding.get("itemId",-1)),{}).get("item",{}))
	if changed("shortcuts",[state.get("quickbar",[]),current.get("playerState",{}).get("spellbooks",{}),current.get("playerState",{}).get("featUses",{}),current.get("playerState",{}).get("specialAbilities",[]),shortcut_items]): refresh_quickbar()
	var effects: Dictionary=current.get("playerState",{}).get("effectIcons",{})
	if changed("buffs",effects):
		serial+=1; var rows: Array=[]
		for id in effects: rows.append({"id":int(id),"state":effects[id]})
		buffs.receive({"kind":"buff-begin","viewId":serial,"actorId":actor_id,"count":rows.size()}); buffs.receive({"kind":"buff-rows","viewId":serial,"rows":rows}); buffs.receive({"kind":"buff-commit","viewId":serial})
		for id in buffs.buttons:
			buffs.rows[id].label=rules.title("effecticons",int(id)); art.bind(buffs.buttons[id].get_node("Icon"),rules.icon("effecticons",int(id))); buffs.buttons[id].text=""
	if sheet.wanted and changed("sheet",[current.get("inventoryStats",{}),current.get("replicated",{}).get("stats",{}),current.get("replicated",{}).get("hitPoints",{}),current.get("playerState",{})]): refresh_sheet()
	if book.wanted and changed("book",[current.get("playerState",{}).get("spellbooks",{}),current.get("replicated",{}).get("stats",{}).get("classes",[]),rules.feats(current)]): refresh_book()
	if journal.wanted and changed("journal",state.get("journal",{})): refresh_journal(journal.page)
	if players.wanted and changed("players",[players_frame.rows(),current.get("replicated",{}).get("party",{})]): refresh_players()
	if area_map.wanted: refresh_map()
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
func refresh_sheet() -> void:
	if not objects.has(actor_id): return
	serial+=1; sheet.receive({"kind":"sheet-view","viewId":serial,"page":sheet.page,"model":rules.record(actor(),str(generation)+":"+str(actor_id)),"canLevelUp":actor().get("playerState",{}).get("combat",{}).get("canLevelUp",false),"entries":rules.record_entries(actor(),sheet.page) if sheet.page>0 else []})
func bind_sheet_art() -> void:
	if closed or sheet.state.is_empty(): return
	if sheet.image_nodes.has("portrait"):
		var resource:=rules.portrait(actor())
		if resource.is_empty() and not party.rows.is_empty() and not str(party.rows[0].portraitKey).is_empty(): resource=str(party.rows[0].portraitKey).left(-1)+"l"
		art.bind_portrait(sheet.image_nodes.portrait,resource)
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
func refresh_quickbar() -> void:
	quick_bindings=state.get("quickbar",[]).duplicate(true); var rows: Array=[]
	for index in 36:
		var binding: Dictionary=quick_bindings[index] if index<quick_bindings.size() else {"type":0}
		rows.append(shortcut_row(binding))
	serial+=1; quickbar.receive({"kind":"quickbar-view","quickbarId":serial,"rows":rows})
func bind_quickbar_art() -> void:
	item_art.clear()
	for index in quickbar.buttons:
		var item: Dictionary=objects.get(int(quick_bindings[index].get("itemId",-1)),{}).get("item",{}) if index<quick_bindings.size() and int(quick_bindings[index].get("type",0))==1 else {}
		if not item.is_empty():
			var key: String=owner_ui.inventory.icons.request(item,owner_ui.text.tables,int(actor().get("appearance",{}).get("gender",0)))
			if not key.is_empty():
				if not item_art.has(key): item_art[key]=[]
				item_art[key].append({"index":index,"view":quickbar.quickbar_id})
				if owner_ui.inventory.icons.textures.has(key): item_icon_ready(key,owner_ui.inventory.icons.textures[key],"")
		var row: Dictionary=quickbar.rows[index]; art.bind(quickbar.buttons[index].image,str(row.get("icon","")))
func shortcut_row(binding: Dictionary) -> Dictionary:
	var type:=int(binding.get("type",0)); var id:=int(binding.get("intParam",0)); var table:="spells" if type in [2,44] else "feat" if type==4 else "skills" if type==3 else ""
	if type==4: id&=65535
	var action_icon:=""
	var uses: Variant=null
	if type==2: uses=rules.spell_uses(actor(),id,int(binding.get("classIndex",0)),int(binding.get("metamagic",0)),int(binding.get("domainLevel",0)))
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
		for row in PARTY_COMMANDS:
			if int(row[0])==id: label=str(row[1]); action_icon=str(row[2])
	elif type==38: label="Possess Familiar"; action_icon="IFE_POSSESS"
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

	return {"empty":type==0,"label":label,"enabled":type!=0 and (uses==null or uses is String and uses=="*" or int(uses)>0),"uses":uses,"icon":action_icon if type==4 and not action_icon.is_empty() else rules.icon(table,id) if not table.is_empty() else action_icon}
func assign(index: int,binding: Dictionary) -> void:
	if index<0 or index>=36: return
	var button: Dictionary=item_binding(binding) if int(binding.get("type",0))==1 else FeatRadial.binding(int(binding.intParam),int(binding.get("auxiliary",(int(binding.intParam)>>16)&65535))) if int(binding.get("type",0))==4 else binding
	command({"kind":"native-quickbar-assign","index":index,"button":button})
func activate(binding: Dictionary) -> void:
	match int(binding.get("type",0)):
		2,44,4,3: begin_target(binding)
		42: cancel_target(); command({"kind":"native-quickchat","quickChat":int(binding.intParam)&65535})
		38: cancel_target(); command({"kind":"native-possess"})
		39:
			cancel_target()
			var id:=int(binding.get("associateId",INVALID)) if int(binding.get("associateType",1))==1 else int(actor().get("companionId" if int(binding.get("associateType",1))==2 else "familiarId",INVALID))
			command({"kind":"native-associate","targetId":id,"command":(int(binding.intParam)&65535)-65536 if int(binding.intParam)&32768 else int(binding.intParam)&65535})
		1:
			var prepared:=item_binding(binding)
			if int(prepared.intParam)&65535!=255: begin_target(prepared)
			else: command({"kind":"native-quickbar-activate","index":quick_bindings.find(binding)})
		_: command({"kind":"native-quickbar-activate","index":quick_bindings.find(binding)})
func begin_target(binding: Dictionary) -> void:
	target=binding.duplicate(true); var type:=int(binding.get("type",0)); var id:=int(binding.get("intParam",0))
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
	if type==45:
		var kind:=int(objects.get(id,{}).get("objectType",2)); var bit: int=[5,6,7,10,11,12,9,14,13,2].find(kind)
		if bit<0 or (int(binding.objectMask)&(1<<bit))==0: target_prompt.text="Choose a valid target for the server action."; return
		cancel_target(); command({"kind":"native-script-target","version":int(binding.version),"targetId":INVALID if id<0 else id,"position":[point.x,-point.z,point.y]}); return
	if type==3 and (not objects.has(id) or int(objects[id].get("objectType",0)) not in ([9,10] if int(binding.intParam)==9 else [5])): target_prompt.text="Choose a valid target for this skill."; return
	cancel_target()
	var message:={"kind":"native-item-ability" if type==1 else "native-cast" if type==2 else "native-spell-like" if type==44 else "native-feat" if type==4 else "native-skill","targetId":INVALID if id<0 else id,"position":[point.x,-point.z,point.y]}
	if type==1: message.itemId=int(binding.itemId); message.propertyIndex=int(binding.intParam)&255; message.variant=(int(binding.intParam)>>16)&255
	elif type in [2,44]: message.spellId=int(binding.intParam); message.classIndex=int(binding.get("classIndex",0)); message.domainLevel=int(binding.get("domainLevel",0)); message.metamagic=int(binding.get("metamagic",0)); message.casterLevel=int(binding.get("domainLevel",0))
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
			sheet.page=int(message.get("page",0)); command({"kind":"native-panel","panel":"character","open":true,"page":sheet.page}); refresh_sheet()
		"sheet-close": command({"kind":"native-panel","panel":"character","open":false})
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
			if int(message.quickbarId)==quickbar.quickbar_id and index>=0 and index<quick_bindings.size(): activate(quick_bindings[index])
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
		"journal-open": command({"kind":"native-panel","panel":"journal","open":true}); refresh_journal(int(message.get("page",0)))
		"journal-page":
			if journal.wanted and int(message.get("viewId",-1))==journal.view_id: refresh_journal(int(message.get("page",0)))
		"journal-close": command({"kind":"native-panel","panel":"journal","open":false})
		"players-open": refresh_players()
		"players-attitude":
			if int(message.viewId)==players.view_id and int(message.entryId)<players.rows.size(): command({"kind":"native-player-attitude","playerId":players.rows[int(message.entryId)].playerId,"likes":message.likes})
		"map-open": refresh_map(true)
		"radial-select": radial_select(message)
		"radial-back":
			if radial_stack.size()>1: radial_stack.pop_back(); show_radial(radial_stack[-1])
		"radial-shortcut":
			if radial.can_shortcut(message) and radial_entries.has(int(message.slot)): assign(int(message.index),radial_entries[int(message.slot)].binding)
		"item-radial-shortcut":
			var source: Dictionary=message.duplicate(); source.kind="item-radial-entry"
			var binding: Dictionary=owner_ui.inventory.item_context.binding(source)
			if int(message.get("quickbarId",-1))==quickbar.quickbar_id and not binding.is_empty(): assign(int(message.index),binding)
		"radial-cancel": radial_stack.clear(); pending_shortcuts.clear()
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
	var value:={"slot":slot,"label":label,"action":action,"icon":icon,"submenu":extra.has("children"),"disabled":false,"canDrag":extra.has("binding"),"uses":null}; value.merge(extra,true); return value
func player_target(id: int) -> bool:
	for entry in state.get("players",[]):
		var player: Dictionary=entry[1] if entry is Array else entry
		if int(player.get("objectId",-1))==id or int(player.get("character",{}).get("id",-1))==id: return true
	return false
func open_radial(hit: Dictionary,point: Vector2) -> void:
	if not target.is_empty(): cancel_target(); return
	owner_ui.inventory.item_context.cancel()
	radial_target=int(hit.get("id",-1)); radial_position=hit.get("position",Vector3.ZERO); radial_stack.clear(); pending_shortcuts.clear(); radial.open_at(point,radial_target,radial_position,false)
	var object: Dictionary=objects.get(radial_target,{}); var kind:=int(object.get("objectType",0)); var entries: Array=[]
	var portrait:=rules.portrait(object) if kind==5 else ""
	if kind==5: entries.append(entry(3,"Special attacks","branch","ir_xattack",{"children":special_attacks()}))
	if radial_target==actor_id or radial_target<0:
		entries.append(entry(1,"Cast spell","branch","ir_cast",{"children":spell_branches()})); entries.append(entry(6,"Special abilities","branch","ir_xability",{"children":feat_entries()}))
		if radial_target==actor_id: entries.append(entry(5,"Issue command","branch","IR_COMMAND",{"children":party_commands()})); entries.append(entry(0,"Character record","panel","ir_charsheet",{"panel":"character"})); entries.append(entry(2,"Rest","rest","ir_rest")); entries.append(entry(4,"Inventory","panel","ir_inventory",{"panel":"inventory"}))
		else: entries.append(entry(2,"Move to","move","ir_moveto"))
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
		entries.append(entry(1,"Cast spell","branch","ir_cast",{"children":spell_branches()})); entries.append(entry(6,"Special abilities","branch","ir_xability",{"children":feat_entries()}))
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
	var result: Array=[]; var classes: Array=actor().get("replicated",{}).get("stats",{}).get("classes",[])
	for index in classes.size():
		var levels: Array=[]
		for level in 10:
			var spells: Array=[]; var model:=rules.spellbook(actor(),index,level,0)
			if int(model.classIndex)!=index: continue
			for row in model.known:
				if row.canCast or row.family:
					var entry:=spell_radial(row.binding,[],target_mask)
					if not entry.is_empty(): spells.append(entry)
			if not spells.is_empty(): levels.append(entry(level%8,"Level "+str(level),"branch","ir_cast",{"children":spells}))
		if not levels.is_empty(): result.append(entry(index%8,rules.title("classes",int(classes[index].id)),"branch","ir_cast",{"children":levels}))
	return result
func spell_radial(binding: Dictionary,path: Array,target_mask: int=0) -> Dictionary:
	var id:=int(binding.intParam); var children: Array=[]
	if path.size()<16:
		for child in rules.spell_children(id,path):
			var next:=binding.duplicate(); next.intParam=child; var value:=spell_radial(next,path+[id],target_mask)
			if not value.is_empty(): children.append(value)
	if target_mask and children.is_empty() and (Rules.number(Rules.cell(rules.row("spells",id),"TargetType"),0)&target_mask)==0: return {}
	return entry(0,rules.title("spells",id),"branch" if not children.is_empty() else "power",rules.icon("spells",id),{"children":children} if not children.is_empty() else {"binding":binding})
func feat_context() -> Dictionary:
	var ctx:=feat_rules.context(actor(),radial_target,pending_shortcuts.has("index"))
	var familiar_id:=int(actor().get("familiarId",INVALID))
	if objects.has(familiar_id) and not objects[familiar_id].get("replicationRemoved",false): ctx.familiar={"id":familiar_id}
	return ctx
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
	if closed or texture==null or not error.is_empty(): return
	for job in item_art.get(key,[]):
		if int(job.view)==quickbar.quickbar_id and quickbar.buttons.has(int(job.index)): quickbar.buttons[int(job.index)].image.texture=texture
func show_radial(menu: Dictionary,push: bool=false) -> void:
	if push: radial_stack.append(menu)
	radial_entries.clear(); radial_serial+=1; var entries: Array=[]; var source: Array=menu.entries
	var physical:=source.size()<=8; var slots: Dictionary={}
	for item in source:
		var slot:=int(item.get("slot",-1))
		if slot<0 or slot>7 or slots.has(slot): physical=false
		slots[slot]=true
	for index in mini(source.size(),8):
		var item: Dictionary=source[index].duplicate(true); item.slot=int(item.slot) if physical else index; radial_entries[int(item.slot)]=item; entries.append(item)
	if source.size()>8:
		entries.resize(7); radial_entries.erase(7); var more:=entry(7,"More…","branch","ir_more",{"children":source.slice(7)}); entries.append(more); radial_entries[7]=more
	radial.receive({"kind":"action-menu","requestId":radial.request_id,"menuId":radial_serial,"depth":maxi(0,radial_stack.size()-1),"title":menu.title,"entries":entries})
	radial.set_center(str(menu.get("center","ir_use")),bool(menu.get("portraitCenter",false)))
	for slot in radial_entries: art.bind(radial.icons[int(slot)],str(radial_entries[slot].icon))
func radial_select(message: Dictionary) -> void:
	if int(message.requestId)!=radial.request_id or int(message.menuId)!=radial.menu_id or not radial_entries.has(int(message.slot)): return
	var item: Dictionary=radial_entries[int(message.slot)]
	if item.has("children"): show_radial({"title":item.label,"entries":item.children,"center":item.icon},true); return
	if pending_shortcuts.has("index") and item.has("binding"): assign(int(pending_shortcuts.index),item.binding)
	else:
		match str(item.action):
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
	radial.reset(); radial_stack.clear(); pending_shortcuts.clear()
func barter_item_menu(id: int,point: Vector2,removable: bool) -> void:
	owner_ui.inventory.item_context.open_trade(owner_ui.barter,id,point)
func shortcut_menu(index: int,point: Vector2) -> void:
	if not owner_ui.tables_ready: return
	owner_ui.inventory.item_context.cancel()
	radial.open_at(point,actor_id,Vector3.ZERO,false); radial_stack.clear(); pending_shortcuts={"index":index}
	radial_target=actor_id; radial_position=Vector3.ZERO
	show_radial({"title":"Assign F"+str(index%12+1),"entries":[entry(0,"Clear slot","clear","ir_cancel"),entry(1,"Spell","branch","ir_cast",{"children":spell_branches()}),entry(2,"Feat","branch","ir_xability",{"children":feat_entries()}),entry(3,"Command","branch","IR_COMMAND",{"children":party_commands()}),entry(4,"Special attacks","branch","ir_xattack",{"children":special_attacks()})]},true)
func blocks_pointer(point: Vector2) -> bool:
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
		elif bindings.action_matches(62,event): open_radial({"id":actor_id},get_viewport().get_mouse_position()); get_viewport().set_input_as_handled()
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
	if not message.accepted:
		if message.action=="native-cancel-action": action_queue.rejected()
		target_prompt.text=str(message.get("text","The action was not accepted.")); target_prompt.show()
		if message.action=="native-level-up": level_owner.submitting=false; level_owner.status=target_prompt.text; level_owner.render(); level_up.status.text=target_prompt.text
		return
	if message.action=="native-level-up":
		match str(message.get("operation","")):
			"begin":
				if level_up.wanted: level_owner.begin(message.result)
			"submit":
				if message.result.get("accepted",false): level_up.reset()
				else: level_owner.submitting=false; level_owner.status="The server rejected these choices; reopen Level Up and check chat."; level_owner.render()
func snapshot() -> Dictionary:
	var menus: Dictionary={}
	for pair in [["character",sheet],["spells",book],["journal",journal],["map",area_map],["players",players],["level_up",level_up]]: menus[pair[0]]=is_instance_valid(pair[1]) and pair[1].visible
	return {"native_only":true,"menus":menus,"party_members":party.rows.size(),"party_skin":party_frame.snapshot(),"players_skin":players_frame.snapshot(),"quickbar_slots":quickbar.rows.size(),"quickbar_skin":quickbar_frame.snapshot(),"journal_skin":journal_frame.snapshot(),"buffs":buffs.buttons.size(),"queued_actions":action_queue.rows.size(),"cancel_pending":action_queue.pending.size(),"radial":radial.active,"targeting":not target.is_empty(),"map_art":area_map.board.art.size(),"map_skin":map_frame.snapshot(),"art":art.models.snapshot(),"missing_art":art.failed.keys(),"raw_data_retirement_enabled":raw_data_retirement_enabled,"raw_data_retirements":raw_data_retirements,"radial_skin":radial.skin_snapshot(),"stale_art_bindings":art.stale_bindings,"full_binary_parity":false}
func close() -> void:
	if closed: return
	closed=true; cancel_target(); objects.clear(); state.clear()
	preparation.reset()
	if is_instance_valid(sheet_frame): sheet_frame.close()
	if is_instance_valid(quickbar_frame): quickbar_frame.close()
	if is_instance_valid(party_frame): party_frame.close()
	if is_instance_valid(book_frame): book_frame.close()
	if is_instance_valid(journal_frame): journal_frame.close()
	if is_instance_valid(map_frame): map_frame.close()
	if is_instance_valid(players_frame): players_frame.close()
	if is_instance_valid(art): art.close()
	if is_instance_valid(radial): radial.reset()
func _exit_tree() -> void: close()
