extends Control
const Numbers=preload("res://systems/native_data/browser_numbers.gd")
var rendered_revision:=-1
var row_nodes_created:=0
var row_updates:=0
var view_updates:=0
var duplicate_views_skipped:=0
var presentation_usec:=0
# Source pages only. The existing browser controller owns admission and scoped
# capabilities; this owner never fabricates query results or connection success.
signal prepared
signal action_requested(operation: String,fields: Dictionary,capture: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/server_browser_layout.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
var frame
var text_owner
var assets
var sources: Dictionary={}
var models: Dictionary={}
var requested: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var tabs: Dictionary={}
var pages: Dictionary={}
var state: Dictionary={}
var scope: Array=[]
var held: Dictionary={}
var revision:=0
var failure:=""
var layout_ready:=false
var closed:=false
var active_tab:="Internet"
var notice: Label
var previous: Button
var next: Button
var refresh_servers: Button
var login_profiles_button: Button
var refresh_timer: Timer
var refresh_available_at:=0
var game_types: Array=[]
var type_table_failure:=""
var reveal_selection:=false
var list_keyboard:=false
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter; text_owner=text; mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_CLICK; hide()
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(received)
	for name in ["serverlist_panel"]+Plan.PAGES.values(): jobs[assets.request(name,2047,"gff")]="@"+name
	jobs[assets.request("gamespyrooms",2017,"2da")]="@types"
	for name in Plan.EXTRA: request_model(name)
	get_viewport().size_changed.connect(place)
func request_model(name: String) -> void:
	if name.is_empty() or requested.has(name): return
	requested[name]=true; jobs[assets.request(name,2002,"actor-model")]=name
func collect(node: Dictionary) -> void:
	request_model(str(node.get("Obj_ResRef","")).to_lower())
	for child in node.get("Obj_ChildList",[]): collect(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if name=="@types":
		type_table_failure=str(result.get("error",""))
		if type_table_failure.is_empty():
			for cells in result.value.get("orderedCells",[]):
				if cells.size()>2 and str(cells[1]).is_valid_int() and str(cells[2]).is_valid_int(): game_types.append({"ref":int(cells[1]),"group":int(cells[2])})
	elif not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	elif name.begins_with("@"):
		sources[name.substr(1)]=result.value.root; collect(result.value.root)
	else: models[name]=result.value
	if sources.size()!=4 or not jobs.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(sources,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	build()
func original_button(tag: String,entry: Dictionary,parent: Control,check: bool=false) -> Button:
	var button: Button=frame.create_button(entry,parent,models,check); button.toggle_mode=check
	var ref:=int(entry.get("caption",{}).get("Obj_StrRef",-1))
	if ref>=0 and ref!=4294967295: frame.button_caption(button,text_owner.raw({"strRef":ref}))
	button.button_down.connect(func():held[tag]={"scope":scope.duplicate(),"revision":revision})
	button.pressed.connect(invoke.bind(tag)); return button
func build() -> void:
	size=definition.size; custom_minimum_size=size; frame.image(definition.resource,definition.main,self)
	#8d4870 removes tab1; tab4 requires platform authentication not owned by
	# this client. Retain source metadata, without painting invented live tabs.
	for tag in Plan.TABS: tabs[tag]=original_button(tag,definition.entries[tag],self,true)
	for tab in Plan.PAGES:
		var plan: Dictionary=definition.pages[tab]; var stage:=Control.new(); add_child(stage); stage.size=size; stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
		frame.image(plan.resource,plan.rect,stage); var buttons: Dictionary={}; var guards: Array=[]
		for tag in Plan.ACTIONS+Plan.SORTS+[plan.favorite]: buttons[tag]=original_button(tab+"/"+tag,plan.entries[tag],stage,tag in Plan.SORTS)
		var art_clip:=Control.new(); stage.add_child(art_clip); art_clip.position=plan.clip.position; art_clip.size=plan.clip.size; art_clip.clip_contents=true; art_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var entry: Dictionary=plan.entries.ctl_serverlist; var art_rect: Rect2=entry.rect; art_rect.position-=plan.clip.position; frame.image(entry.resource,art_rect,art_clip)
		var scroll:=ScrollContainer.new(); stage.add_child(scroll); scroll.position=plan.clip.position; scroll.size=plan.clip.size; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
		var body:=Control.new(); scroll.add_child(body); body.mouse_filter=Control.MOUSE_FILTER_IGNORE; body.custom_minimum_size=Vector2(plan.clip.size.x,0)
		var bar:=Bar.new(); stage.add_child(bar); var bar_entry: Dictionary=entry.duplicate(true); bar_entry.caption.erase("AurString_Font"); bar.configure(frame,models,bar_entry,scroll,Plan.ROW_STEP)
		if not bar.failure.is_empty(): failure=bar.failure; return
		var highlights: Array=[]
		if tab=="Internet":
			for tag in ["hidelocal","hideserver","hidepasswords"]:
				buttons[tag]=original_button(tab+"/"+tag,plan.entries[tag],stage,true)
				var guard:=Control.new(); stage.add_child(guard); guard.position=plan.entries[tag].rect.position; guard.size=plan.entries[tag].rect.size; guard.mouse_filter=Control.MOUSE_FILTER_STOP; guards.append(guard)
			buttons.filtersbutton=original_button(tab+"/filtersbutton",plan.entries.filtersbutton,stage)
			for tag in ["tguilabel","tguilabel1","locallabel","serverlabel","passwordlabel"]:
				var label: Label=frame.create_label(plan.entries[tag],stage); label.text=text_owner.raw({"strRef":int(plan.entries[tag].caption.get("Obj_StrRef",-1))})
				if tag in ["locallabel","serverlabel","passwordlabel"]: label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				label.tooltip_text=label.text
			var side: Dictionary={}
			side.filterlist=side_list(stage,plan.entries.filterlist); buttons["@filterlist"]=side.filterlist.body
			var types:=ItemList.new(); stage.add_child(types); types.position=plan.entries.gametypelist.rect.position; types.size=plan.entries.gametypelist.rect.size
			types.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
			frame.font_style(types,plan.entries.gametypelist.caption); types.add_theme_constant_override("v_separation",0); types.add_theme_constant_override("h_separation",0)
			types.add_item(text_owner.raw({"strRef":67445}))
			for type in game_types: types.add_item(text_owner.raw({"strRef":type.ref}))
			types.item_selected.connect(func(index):select_game_type(index,scope.duplicate(),revision)); buttons["@gametypelist"]=types
			types.tooltip_text=type_table_failure
			pages[tab]={"stage":stage,"buttons":buttons,"guards":guards,"scroll":scroll,"body":body,"bar":bar,"side":side,"rows":[],"highlights":highlights,"revision":-1}
		else: pages[tab]={"stage":stage,"buttons":buttons,"guards":guards,"scroll":scroll,"body":body,"bar":bar,"side":{},"rows":[],"highlights":highlights,"revision":-1}
	# Replacement-only paging/status uses the original font and native button
	# artwork. Transport pages are not mislabeled as original GUI controls.
	notice=Label.new(); add_child(notice); frame.font_style(notice,{"AurString_Font":"fnt_galahad14"}); notice.position=Vector2(0,size.y+5); notice.size=Vector2(size.x,35); notice.clip_text=true; notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	previous=Button.new(); next=Button.new()
	for index in 2:
		var button: Button=[previous,next][index]; add_child(button); var entry: Dictionary=definition.pages.Internet.entries.dirconnectbutton.duplicate(true); entry.rect.position=Vector2(0 if index==0 else size.x-entry.rect.size.x,size.y+40); entry.offset=entry.rect.position-entry.model.bounds.position
		frame.button(button,entry,self,models,false); frame.button_caption(button,["Previous page","Next page"][index])
		var page_tag: String=["@previous","@next"][index]; button.button_down.connect(func():held[page_tag]={"scope":scope.duplicate(),"revision":revision}); button.pressed.connect(invoke.bind(page_tag))
	refresh_servers=preload("res://systems/native_refresh_button.gd").new(); add_child(refresh_servers); refresh_servers.position=Vector2(size.x-38,5)
	refresh_servers.button_down.connect(func():held["@refresh"]={"scope":scope.duplicate(),"revision":revision}); refresh_servers.pressed.connect(invoke.bind("@refresh"))
	refresh_timer=Timer.new(); add_child(refresh_timer); refresh_timer.one_shot=true; refresh_timer.timeout.connect(update_refresh)
	login_profiles_button=Button.new(); add_child(login_profiles_button); login_profiles_button.position=Vector2(size.x-240,5); login_profiles_button.size=Vector2(194,30); login_profiles_button.focus_mode=Control.FOCUS_NONE
	login_profiles_button.theme=preload("res://systems/native_client_menu_style.gd").for_tree(get_tree()); frame.font_style(login_profiles_button,{"AurString_Font":"fnt_galahad14"})
	login_profiles_button.button_down.connect(func():held["@profiles"]={"scope":scope.duplicate(),"revision":revision}); login_profiles_button.pressed.connect(invoke.bind("@profiles"))
	layout_ready=true; place(); prepared.emit()
func side_list(stage: Control,entry: Dictionary) -> Dictionary:
	var scroll:=ScrollContainer.new(); stage.add_child(scroll); scroll.position=entry.rect.position; scroll.size=entry.rect.size; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var body:=Label.new(); scroll.add_child(body); body.custom_minimum_size=Vector2(entry.rect.size.x,0); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.mouse_filter=Control.MOUSE_FILTER_IGNORE; frame.font_style(body,entry.caption)
	var bar:=Bar.new(); stage.add_child(bar); var data: Dictionary=entry.duplicate(true); data.caption.erase("AurString_Font"); bar.configure(frame,models,data,scroll,17)
	if not bar.failure.is_empty(): failure=bar.failure
	return {"scroll":scroll,"body":body,"bar":bar}
func place() -> void:
	if layout_ready: position=((get_viewport_rect().size-size)*0.5).max(Vector2.ZERO)
func emit_action(operation: String,fields: Dictionary={}) -> void:
	if not closed and visible and layout_ready: action_requested.emit(operation,fields,scope.duplicate())
func select_game_type(index: int,capture: Array,version: int) -> void:
	if closed or not visible or not layout_ready or capture!=scope or version!=revision or state.get("busy",false) or active_tab!="Internet" or index<0 or index>game_types.size(): return
	emit_action("game-type",{"gameType":null if index==0 else index-1})
func _gui_input(event: InputEvent) -> void:
	#1e9790: all four cursor keys move one row; boundaries do not wrap.
	# Keyboard ownership begins with a list click, not merely opening a page.
	if not event is InputEventKey or not event.pressed or not list_keyboard or not has_focus() or closed or not visible or not layout_ready: return
	if event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		if not event.echo: accept_event(); emit_action("activate-current")
		return
	if state.get("busy",false): return
	if event.keycode not in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]: return
	accept_event(); reveal_selection=true
	emit_action("selection-step",{"direction":-1 if event.keycode in [KEY_UP,KEY_LEFT] else 1})
func reveal_current_selection(capture: Array) -> void:
	if closed or not visible or scope!=capture or not pages.has(active_tab): return
	var page: Dictionary=pages[active_tab]
	for index in state.get("rows",[]).size():
		if state.rows[index].get("selected",false) and index<page.rows.size(): page.scroll.ensure_control_visible(page.rows[index]); break
func row_input(event: InputEvent,id: int,capture: Array,version: int) -> void:
	if closed or not visible or not layout_ready or scope!=capture or version!=revision or not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT or not event.pressed: return
	# Original1ea090 selects on down;8d1b30 routes a double-click to Connect.
	# A second down during the selection acknowledgment may queue activation,
	# but the controller requires an exact canonical selection acknowledgment.
	if state.get("busy",false) and not event.double_click: return
	list_keyboard=true; grab_focus(); accept_event()
	emit_action("select",{"entryId":id,"activate":event.double_click})
func invoke(tag: String) -> void:
	if closed or not visible or not layout_ready: return
	var capture: Dictionary=held.get(tag,{"scope":scope,"revision":revision}); held.erase(tag)
	if capture.scope!=scope or int(capture.revision)!=revision: return
	if tag=="@profiles":
		if not login_profiles_button.disabled: emit_action("profiles")
		return
	if tag=="@refresh":
		if refresh_servers.visible and not refresh_servers.disabled:
			refresh_available_at=Time.get_ticks_msec()+2000; update_refresh(); emit_action("refresh")
		return
	if tag in ["@previous","@next"]:
		var button: Button=previous if tag=="@previous" else next
		if not button.disabled: emit_action("page",{"page":int(state.get("page",0))+(-1 if tag=="@previous" else 1)})
		return
	if tag in Plan.TABS:
		if not tabs[tag].disabled: emit_action("tab",{"tab":Plan.TABS[tag]})
		return
	var parts:=tag.split("/"); if parts.size()!=2 or parts[0]!=active_tab: return
	var name: String=parts[1]; var page: Dictionary=pages[active_tab]
	if not page.buttons.has(name) or page.buttons[name].disabled: return
	if name=="cancelbutton": emit_action("back"); return
	if state.get("busy",false): return
	if name in Plan.SORTS: emit_action("sort-column",{"column":Plan.SORTS.find(name)})
	elif name=="dirconnectbutton": emit_action("direct")
	elif name=="filtersbutton": emit_action("filters")
	elif name in ["hidelocal","hideserver","hidepasswords"]:
		var values: Dictionary=state.get("filters",{"local":true,"server":true,"password":true}).duplicate(); var key: String={"hidelocal":"local","hideserver":"server","hidepasswords":"password"}[name]; values[key]=not page.buttons[name].button_pressed
		if name=="hidelocal" and not values.local: values.server=true
		if name=="hideserver" and not values.server: values.local=true
		emit_action("visibility",{"filters":values})
	else: emit_action("inspect" if name=="srvdetailsbutton" else "join" if name=="connectbutton" else "favorite",{"on":active_tab!="Favorites"})
func set_view(value: Dictionary) -> void:
	if closed or not layout_ready or not Plan.PAGES.has(str(value.get("tab",""))): return
	if rendered_revision==revision and value==state: duplicate_views_skipped+=1; return
	var began:=Time.get_ticks_usec(); view_updates+=1
	var next_scope: Array=[int(value.connection),int(value.viewId)]
	if scope!=next_scope: revision+=1
	scope=next_scope; state=value.duplicate(true); active_tab=str(value.tab)
	var login: Variant=state.get("activeLoginProfile")
	login_profiles_button.text=str(login.label).left(20) if login is Dictionary else "Login profiles…"; login_profiles_button.tooltip_text="Login profiles · "+str(login.playerName) if login is Dictionary else "Manage player-name and CD-key profiles"; login_profiles_button.disabled=state.get("busy",false)
	for tag in tabs: tabs[tag].disabled=state.get("busy",false); tabs[tag].set_pressed_no_signal(Plan.TABS[tag]==active_tab)
	for tab in pages: pages[tab].stage.visible=tab==active_tab
	var page: Dictionary=pages[active_tab]; var selected: Dictionary={}
	for row in state.get("rows",[]):
		if row.get("selected",false): selected=row; break
	for tag in page.buttons:
		if tag.begins_with("@"): continue
		var button: Button=page.buttons[tag]; var can: bool=not state.get("busy",false)
		if tag=="cancelbutton": can=true
		elif tag=="connectbutton" or tag=="srvdetailsbutton": can=can and not selected.is_empty() and selected.get("allowed",false) and (tag!="connectbutton" or state.get("canJoin",false))
		elif tag=="dirconnectbutton": can=can and state.get("canJoin",false)
		elif tag in ["favoritesbutton","rmfavoritebutton"]: can=can and not selected.is_empty()
		elif tag in Plan.SORTS: can=can and active_tab!="History"
		# Source disabled checkbox artwork can draw an X even when unchecked.
		if tag not in ["hidelocal","hideserver","hidepasswords"]: button.disabled=not can
		if tag in Plan.SORTS: button.set_pressed_no_signal(Plan.SORTS.find(tag)==int(state.get("sourceSort",{}).get("header",2)))
	for guard in page.guards: guard.visible=state.get("busy",false)
	if active_tab=="Internet":
		var types: ItemList=page.buttons["@gametypelist"]; var selected_type: Variant=state.get("gameType")
		types.mouse_filter=Control.MOUSE_FILTER_IGNORE if state.get("busy",false) else Control.MOUSE_FILTER_STOP; types.focus_mode=Control.FOCUS_NONE if state.get("busy",false) else Control.FOCUS_ALL
		types.deselect_all()
		var selected_index:=0 if selected_type==null else int(selected_type)+1
		if selected_index>=0 and selected_index<types.item_count: types.select(selected_index)
		for pair in [["hidelocal","local"],["hideserver","server"],["hidepasswords","password"]]: page.buttons[pair[0]].set_pressed_no_signal(not state.get("filters",{}).get(pair[1],true))
		var lines: Array=[]
		for pair in [["password",0x10ba5],["server",0x10ba4],["local",0x10ba3]]:
			if not state.get("filters",{}).get(pair[0],true): lines.append(text_owner.raw({"strRef":pair[1]}))
		var advanced: Dictionary=state.get("advancedFilters",{})
		if advanced.get("hideEmpty",false): lines.append(text_owner.raw({"strRef":0xab7}))
		if advanced.get("hideFull",false): lines.append(text_owner.raw({"strRef":0xab8}))
		if not str(advanced.get("module","")).is_empty(): lines.append(str(advanced.module))
		page.buttons["@filterlist"].text="\n".join(lines)
	render_rows(page)
	if reveal_selection and not state.get("busy",false):
		reveal_selection=false; reveal_current_selection.call_deferred(scope.duplicate())
	previous.visible=int(state.get("pages",1))>1; next.visible=previous.visible; previous.disabled=state.get("busy",false) or int(state.get("page",0))==0; next.disabled=state.get("busy",false) or int(state.get("page",0))+1>=int(state.get("pages",1))
	refresh_available_at=maxi(refresh_available_at,Time.get_ticks_msec()+maxi(0,int(state.get("refreshCooldownMs",0)))); update_refresh()
	notice.text=str(state.get("status",""))
	rendered_revision=revision; presentation_usec+=Time.get_ticks_usec()-began
func update_refresh() -> void:
	if closed or not is_instance_valid(refresh_servers): return
	var remaining:=maxi(0,refresh_available_at-Time.get_ticks_msec())
	refresh_servers.visible=active_tab=="Internet"
	refresh_servers.disabled=state.get("busy",false) or not state.get("canDiscover",false) or remaining>0
	refresh_servers.tooltip_text="Internet discovery is disabled for this session." if not state.get("canDiscover",false) else "Please wait before refreshing again" if remaining>0 else "Refresh servers"
	if remaining>0: refresh_timer.start(remaining/1000.0)
	else: refresh_timer.stop()
func retained_row_input(event: InputEvent,button: Button) -> void:
	var page_name: String=button.get_meta("browser_page","")
	if page_name!=active_tab or not pages.has(page_name): return
	var context: Dictionary=pages[page_name].row_context
	row_input(event,int(button.get_meta("browser_entry",-1)),context.scope,int(context.revision))
func render_rows(page: Dictionary) -> void:
	var plan: Dictionary=definition.pages[active_tab]; var rows: Array=state.get("rows",[]); page.body.custom_minimum_size=Vector2(plan.clip.size.x,rows.size()*Plan.ROW_STEP)
	page.row_context={"scope":scope.duplicate(),"revision":revision}
	while page.rows.size()>rows.size():
		var retired: Button=page.rows.pop_back(); page.body.remove_child(retired); retired.queue_free()
	for index in rows.size():
		var row: Dictionary=rows[index]; var button: Button
		if index<page.rows.size(): button=page.rows[index]
		else:
			button=Button.new(); page.body.add_child(button); button.position=Vector2(0,index*Plan.ROW_STEP); button.size=Vector2(plan.clip.size.x-18,Plan.ROW_STEP); button.custom_minimum_size=Vector2.ZERO; button.focus_mode=Control.FOCUS_NONE
			for name in ["normal","hover","pressed","focus","disabled"]: button.add_theme_stylebox_override(name,StyleBoxEmpty.new())
			var labels: Array=[]
			for column in 6:
				var label:=Label.new(); button.add_child(label); frame.font_style(label,plan.entries[Plan.COLUMNS[column]].caption); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.clip_text=true; label.position=Vector2(plan.columns[column].position.x-plan.clip.position.x,plan.columns[column].position.y-plan.clip.position.y); label.size=Vector2(plan.columns[column].size.x,Plan.ROW_STEP); labels.append(label)
			button.set_meta("browser_labels",labels); button.set_meta("browser_page",active_tab); button.gui_input.connect(retained_row_input.bind(button)); page.rows.append(button); row_nodes_created+=1
		if button.get_meta("browser_row",{})==row: continue
		button.set_meta("browser_row",row); button.set_meta("browser_entry",int(row.entryId)); row_updates+=1
		var texts: Array=[str(row.get("serverName","")) if not str(row.get("serverName","")).is_empty() else Numbers.endpoint(row),str(row.get("moduleName","")),"%s/%s"%[Numbers.integer(row.get("playerCount")),Numbers.integer(row.get("maximumPlayers"))],"%s-%s"%[Numbers.integer(row.get("minimumLevel")),Numbers.integer(row.get("maximumLevel"))],Numbers.integer(row.get("pvpSetting")),"?"]
		var color:=Color(0.7,0.7,0.7,0.7) if not row.get("allowed",false) else Color(1,0.25,0.25,1) if row.get("passwordRequired",false) else Color(0.6,0.85,1,1)
		for column in 6:
			var label: Label=button.get_meta("browser_labels")[column]
			if label.text!=texts[column]: label.text=texts[column]
			if label.get_theme_color("font_color")!=color: label.add_theme_color_override("font_color",color)
		if row.get("selected",false):
			if not button.has_meta("browser_highlight"):
				var highlight: TextureRect=frame.image(plan.highlight,Rect2(Vector2.ZERO,plan.highlight_size),button); button.move_child(highlight,0); button.set_meta("browser_highlight",highlight)
			button.get_meta("browser_highlight").show()
		elif button.has_meta("browser_highlight"): button.get_meta("browser_highlight").hide()
		button.tooltip_text=Numbers.endpoint(row)
func dismiss() -> void:
	if is_instance_valid(refresh_timer): refresh_timer.stop()
	revision+=1; reveal_selection=false; list_keyboard=false; release_focus(); hide()
	for button in tabs.values(): var disabled: bool=button.disabled; button.disabled=true; button.disabled=disabled
	for page in pages.values():
		page.bar.cancel_drag(); page.bar.stop_repeat()
		for side in page.side.values(): side.bar.cancel_drag(); side.bar.stop_repeat()
		for button in page.buttons.values():
			if button is Button: var disabled: bool=button.disabled; button.disabled=true; button.disabled=disabled
	for button in [previous,next,refresh_servers,login_profiles_button]:
		if is_instance_valid(button): var disabled: bool=button.disabled; button.disabled=true; button.disabled=disabled
func close() -> void:
	if closed: return
	dismiss(); closed=true
	if is_instance_valid(assets): assets.close()
	for page in pages.values():
		page.bar.close()
		for side in page.side.values(): side.bar.close()
	jobs.clear(); models.clear(); frame=null; text_owner=null
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"visible":visible,"tab":active_tab,"source_pages":pages.keys(),"game_types":game_types.size(),"type_table_failure":type_table_failure,"jobs":jobs.size(),"row_nodes_created":row_nodes_created,"row_updates":row_updates,"view_updates":view_updates,"duplicate_views_skipped":duplicate_views_skipped,"presentation_usec":presentation_usec,"native_only":true,"full_browser_parity":false,"game_type_filtering":true,"unported":["platform-authenticated buddy list","original-client pixel/audio comparison"]}
func _exit_tree() -> void: close()
