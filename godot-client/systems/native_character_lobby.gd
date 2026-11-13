extends Control
signal prepared
signal artwork_ready
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/character_lobby_layout.gd")
const Sheet=preload("res://systems/native_data/character_sheet_layout.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
var owner_ui
var frame
var text_owner
var data_art
var data_catalog
var rule_assets
var rules:=Rules.new()
var assets
var jobs: Dictionary={}
var models: Dictionary={}
var source: Dictionary={}
var definition: Dictionary={}
var buttons: Dictionary={}
var mutation_notice: Label
var tabs: Array=[]
var record_tabs: Array=[]
var button_captions: Dictionary={}
var rows: Array=[]
var row_keys: Array=[]
var labels: Dictionary={}
var held: Dictionary={}
var list: ScrollContainer
var list_content: Control
var scrollbar
var page: Control
var record: Control
var record_view
var statistics: Control
var record_feats
var record_skills
var record_spells
var skill_projection: Dictionary={}
var skill_signature:=""
var spell_projection: Dictionary={}
var spell_signature:=""
var record_projection: Dictionary={}
var record_signature:=""
var rule_jobs: Dictionary={}
var record_index:=0
var record_labels: Dictionary={}
var record_portrait: TextureRect
var detail: RichTextLabel
var detail_scroll: ScrollContainer
var detail_bar
var notice: Label
var pregen: Button
var show_pregenerated:=false
var layout_ready:=false
var art_announced:=false
var row_art_keys: Array=[]
var closed:=false
var failure:=""
var revision:=0
var row_signature:=""
var catalog_signature:=""
var automatic_selection: Dictionary={}
var preview_signature:=""
var rule_signature:=""
var page_index:=0
var page_connection:=-1
var extra_pages
var interaction_epoch:=0
var projection_work
var data_epoch:=0
func configure(controller,painter,text,catalog,cache_path: String) -> void:
	owner_ui=controller; frame=painter; text_owner=text; rules.text=text; hide(); mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_ALL
	show_pregenerated=owner_ui.preferences.show_pregenerated
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.high_priority=true; assets.completed.connect(received)
	projection_work=preload("res://systems/native_data/character_picker_work.gd").new(); add_child(projection_work); projection_work.completed.connect(projections_received)
	bind_data(text,catalog,cache_path,frame.art)
	jobs[assets.request("pre_playmod",2047,"gff")]="@layout"
	for name in Plan.RESOURCES: request_model(name)
	# Roster rows do not exist until a server replies. Prepare their actual
	# checkbox poses now, so the first roster cannot trigger another UI build.
	for clip in ["uncheckedup","uncheckeddown","disabled","checkedup","checkeddown"]: row_art_keys.append(frame.art.request_model("ctl_pre_btn_char",clip))
	visibility_changed.connect(dismiss_pages)
func request_model(name: String) -> void:
	if name.is_empty() or models.has(name): return
	models[name]={}; jobs[assets.request(name,2002,"actor-model" if name=="scrollbar_simple" else "mdl-original")]=name
func bind_data(text,catalog,cache_path: String,images) -> void:
	if data_catalog==catalog and text_owner==text: return
	data_epoch+=1
	if is_instance_valid(projection_work): projection_work.retire()
	record_projection={}; skill_projection={}; spell_projection={}
	if is_instance_valid(rule_assets): rule_assets.close(); rule_assets.queue_free()
	if is_instance_valid(data_art) and is_instance_valid(record_portrait): data_art.unbind(record_portrait)
	data_catalog=catalog; text_owner=text; rules.text=text; data_art=images; rule_jobs.clear()
	if is_instance_valid(record_view): record_view.text_owner=text; record_view.refresh_captions()
	rule_assets=Assets.new(); add_child(rule_assets); rule_assets.configure(catalog); rule_assets.cache_directory=cache_path; rule_assets.maximum_workers=2; rule_assets.high_priority=true; rule_assets.completed.connect(rule_received)
	request_classes()
	row_signature=""; preview_signature=""; record_signature=""; skill_signature=""; spell_signature=""; rule_signature=""
	for owner in [record_feats,record_skills,record_spells]:
		if is_instance_valid(owner): owner.signature=""
	if is_instance_valid(extra_pages):
		extra_pages.text_owner=text; extra_pages.rules.text=text; extra_pages.data_art=images; extra_pages.info_signature=""; extra_pages.player_signature=""
	sync()
func request_classes() -> void:
	# Server-vault rows carry numeric class IDs too. Warm the installed labels at
	# Main Menu, then resolve again from the active server catalog after binding.
	if text_owner.tables.has("classes") or rule_jobs.values().has(["classes",owner_ui.connection]): return
	var id: int=rule_assets.request("classes",2017,"2da")
	if id>=0: rule_jobs[id]=["classes",owner_ui.connection]
func class_caption(id: int,short_names: bool=false) -> String:
	if rules.row("classes",id).is_empty():
		return "Loading class…" if not text_owner.tables.has("classes") or owner_ui.native_base_only else "Class unavailable"
	return rules.title("classes",id,"Short" if short_names else "Name")
func rule_received(id: int,result: Dictionary) -> void:
	if closed or not rule_jobs.has(id): return
	var work: Array=rule_jobs[id]; rule_jobs.erase(id)
	if work[1]!=owner_ui.connection: return
	text_owner.publish_table(work[0],result.value if str(result.get("error","")).is_empty() else {"orderedRows":[],"error":str(result.error)})
	sync()
func collect(node: Dictionary) -> void:
	request_model(str(node.get("Obj_ResRef","")).to_lower())
	for child in node.get("Obj_ChildList",[]): collect(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name=="@layout": source=result.value.root; collect(source)
	else: models[name]=result.value
	if jobs.is_empty() and not source.is_empty() and failure.is_empty(): build()
func control(parent: Control,rect: Rect2) -> Control:
	var target:=Control.new(); parent.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.position=rect.position; target.size=rect.size; return target
func label(parent: Control,key: String,rect: Rect2,value: String,caption: Dictionary=Plan.CAPTION) -> Label:
	var target: Label=frame.create_label({"rect":rect,"caption":caption},parent); target.text=value; labels[key]=target; return target
func picture(parent: Control,rect: Rect2) -> TextureRect:
	var target:=TextureRect.new(); parent.add_child(target); target.mouse_filter=Control.MOUSE_FILTER_IGNORE; target.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; target.stretch_mode=TextureRect.STRETCH_SCALE; target.position=rect.position; target.size=rect.size; return target
func build() -> void:
	definition=Plan.parse(source,models)
	if not str(definition.error).is_empty(): failure=definition.error; return
	size=definition.size; frame.image(definition.resource,definition.main,self)
	mutation_notice=Label.new(); add_child(mutation_notice); mutation_notice.position=Vector2(0,-28); mutation_notice.size=Vector2(size.x,26); mutation_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; frame.font_style(mutation_notice,Plan.CAPTION)
	var entry: Dictionary=definition.entries.buttonlist; frame.image(entry.resource,entry.rect,self)
	for tag in ["title","savelabel"]:
		entry=definition.entries[tag]; var target: Label=frame.create_label(entry,self); target.text=text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))}); labels[tag]=target
		if tag=="savelabel": target.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for tag in Plan.BUTTONS:
		entry=definition.entries[tag]; var button: Button=frame.create_button(entry,self,models); button_captions[tag]=frame.button_caption(button,text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))})); buttons[tag]=button
		button.button_down.connect(func():held[tag]=[owner_ui.connection,interaction_epoch,owner_ui.state.get("selected")]); button.pressed.connect(invoke.bind(tag))
	pregen=Button.new(); add_child(pregen); pregen.toggle_mode=true; frame.button(pregen,definition.entries.savegamebox,self,models,false,true)
	pregen.button_down.connect(func():held["pregen"]=[owner_ui.connection,interaction_epoch]); pregen.pressed.connect(toggle_pregen)
	list=ScrollContainer.new(); add_child(list); list.position=definition.list_rect.position; list.size=definition.list_rect.size; list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; list.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	list_content=control(list,Rect2(Vector2.ZERO,Vector2(list.size.x,1))); list_content.custom_minimum_size=list_content.size
	scrollbar=preload("res://systems/native_scrollbar.gd").new(); add_child(scrollbar); scrollbar.configure(frame,models,definition.entries.buttonlist,list,definition.row_next.y)
	if not scrollbar.failure.is_empty(): failure=scrollbar.failure; return
	var group:=ButtonGroup.new()
	for index in 3:
		var button: Button=frame.create_button(definition.tabs[index],self,models,true); button.toggle_mode=true; button.button_group=group
		frame.button_caption(button,text_owner.raw({"strRef":[95,94,96][index]})); tabs.append(button); button.button_down.connect(func():held["page:"+str(index)]=[owner_ui.connection,interaction_epoch]); button.pressed.connect(invoke_page.bind(index))
	# PRE_PLAYMOD's right-hand pages use the417-pixel source viewport. Their
	# tall record artwork must not cover the Play/Cancel controls below it.
	page=control(self,Rect2(definition.page_origin,definition.models.pmod_details800.bounds.size)); page.clip_contents=true; move_child(page,2)
	record_view=preload("res://systems/native_character_summary_view.gd").new(); page.add_child(record_view); record_view.configure(frame,text_owner,models,page.size)
	if not record_view.failure.is_empty(): failure=record_view.failure; return
	record=record_view; record_tabs=record_view.tabs; statistics=record_view.statistics; record_labels=record_view.labels; record_portrait=record_view.portrait; detail=record_view.detail; detail_scroll=record_view.detail_scroll; detail_bar=record_view.detail_bar
	record_view.page_down.connect(func(index):held["record:"+str(index)]=[owner_ui.connection,interaction_epoch,owner_ui.state.get("selected")]); record_view.page_pressed.connect(invoke_record)
	record_feats=preload("res://systems/native_lobby_record_feats.gd").new(); record_view.pages[2].add_child(record_feats); record_feats.configure(self,frame,definition.models,record_view.definition.page_size)
	if not record_feats.failure.is_empty(): failure=record_feats.failure; return
	record_skills=preload("res://systems/native_lobby_record_feats.gd").new(); record_view.pages[1].add_child(record_skills); record_skills.configure(self,frame,definition.models,record_view.definition.page_size,1)
	if not record_skills.failure.is_empty(): failure=record_skills.failure; return
	record_spells=preload("res://systems/native_lobby_record_feats.gd").new(); record_view.pages[3].add_child(record_spells); record_spells.configure(self,frame,definition.models,record_view.definition.page_size,3)
	if not record_spells.failure.is_empty(): failure=record_spells.failure; return
	extra_pages=preload("res://systems/native_lobby_pages.gd").new(); page.add_child(extra_pages); extra_pages.configure(frame,text_owner,definition,models)
	extra_pages.data_art=data_art
	if not extra_pages.failure.is_empty(): failure=extra_pages.failure; return
	notice=label(self,"notice",Rect2(0,size.y+4,size.x,45),""); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	layout_ready=true; sync(); prepared.emit()
func invoke_record(index: int) -> void:
	var key:="record:"+str(index); var capture: Array=held.get(key,[]); held.erase(key)
	if closed or not is_visible_in_tree() or not record.is_visible_in_tree() or index not in [0,1,2,3] or record_tabs[index].disabled: return
	if capture!=[owner_ui.connection,interaction_epoch,owner_ui.state.get("selected")] or not owner_ui.native_selection.is_empty():
		for at in record_tabs.size(): record_tabs[at].set_pressed_no_signal(at==record_index)
		return
	record_index=index; sync_record_page()
func detail_font_loaded(name: String) -> void:
	if not closed and is_instance_valid(record_view): record_view.detail_font_loaded(name)
func sync_record_page() -> void:
	record_view.set_page(record_index); record_view.refresh_captions()
	statistics.visible=record_index==0; record_feats.visible=record_index==2; record_skills.visible=record_index==1; record_spells.visible=record_index==3
	for index in record_tabs.size(): record_tabs[index].set_pressed_no_signal(index==record_index)
	if record_index==2: record_feats.present(owner_ui.record_preview())
	if record_index==1: record_skills.present(owner_ui.record_preview())
	if record_index==3: record_spells.present(owner_ui.record_preview())
func prepare_skills(value: Variant) -> void:
	prepare_record(value)
func prepare_spells(value: Variant) -> void:
	prepare_record(value)
func prepare_record(value: Variant) -> void:
	if owner_ui.native_frontend and owner_ui.native_base_only: return
	var scope: Array=[owner_ui.connection,data_epoch,owner_ui.state.get("selected")]
	if not projection_work.observe(scope,value,text_owner.tables,text_owner.revision): return
	record_projection={}; skill_projection={}; spell_projection={}; preview_signature=""
func projections_received() -> void:
	if closed or not is_instance_valid(owner_ui): return
	# A hidden/cancelled owner may not have called sync since its state changed.
	# Validate the live owner again before publishing even an accepted worker.
	if projection_work.wanted.is_empty() or projection_work.wanted[0]!=[owner_ui.connection,data_epoch,owner_ui.state.get("selected")] or str(owner_ui.state.get("phase","")) not in ["character-selection","character-rejected"]:
		projection_work.retire(); return
	var projected: Dictionary=projection_work.result
	record_projection=projected.get("record",{}); skill_projection=projected.get("skills",{}); spell_projection=projected.get("spells",{}); preview_signature=""
	for name in projected.get("dependencies",[]):
		if rule_jobs.values().has([name,owner_ui.connection]): continue
		var id: int=rule_assets.request(name,2017,"2da")
		if id>=0: rule_jobs[id]=[name,owner_ui.connection]
	sync()
func select_page(index: int) -> void:
	if closed or not visible or index<0 or index>=tabs.size() or tabs[index].disabled: return
	if page_index==index: return
	page_index=index; held.clear(); owner_ui._send({"kind":"lobby-page","page":index}); sync()
func invoke_page(index: int) -> void:
	var key:="page:"+str(index); var capture: Array=held.get(key,[]); held.erase(key)
	if capture==[owner_ui.connection,interaction_epoch]: select_page(index)
func toggle_pregen() -> void:
	var capture: Array=held.get("pregen",[]); held.erase("pregen")
	if capture!=[owner_ui.connection,interaction_epoch]: pregen.set_pressed_no_signal(show_pregenerated); return
	show_pregenerated=pregen.button_pressed; row_signature=""; sync()
func service_automatic_selection() -> void:
	if owner_ui.post_delete_index>=0: return
	if closed or not layout_ready or not is_visible_in_tree() or automatic_selection.is_empty() or not owner_ui.can_select(): return
	var pending: Dictionary=automatic_selection; automatic_selection={}
	if pending.connection!=owner_ui.connection or pending.catalog!=catalog_signature or not row_keys.has(pending.key): return
	owner_ui.native_selection.clear()
	if page_index!=0: select_page(0)
	list.scroll_vertical=0
	owner_ui.choose_native(str(pending.key))
func dismiss_pages() -> void:
	if closed: return
	if is_visible_in_tree():
		if layout_ready: grab_focus(); service_automatic_selection()
		return
	release_focus()
	interaction_epoch+=1; held.clear()
	if page_index==0: return
	page_index=0; held.clear()
	if is_instance_valid(owner_ui) and owner_ui.connection==page_connection and owner_ui.state.get("connected",false) and str(owner_ui.state.get("phase","")) in ["character-selection","character-rejected"]: owner_ui._send({"kind":"lobby-page","page":0})
func _process(_delta: float) -> void:
	if not closed and layout_ready and not art_announced and art_ready(): art_announced=true; artwork_ready.emit()
	if closed or not layout_ready or not is_visible_in_tree(): return
	if get_viewport().gui_get_focus_owner()==null: grab_focus()
	var signature:=str([text_owner.tables.keys(),text_owner.revision])
	if signature!=rule_signature: rule_signature=signature; sync()
	else: service_automatic_selection()
func sync() -> void:
	if closed or not layout_ready: return
	var state: Dictionary=owner_ui.state; revision+=1
	request_classes()
	if owner_ui.needs_local_metadata() and not (owner_ui.native_frontend and owner_ui.native_base_only):
		for name in ["pregen","classes","portraits"]:
			if text_owner.tables.has(name) or rule_jobs.values().has([name,owner_ui.connection]): continue
			var id: int=rule_assets.request(name,2017,"2da")
			if id>=0: rule_jobs[id]=[name,owner_ui.connection]
	if page_connection!=owner_ui.connection: page_connection=owner_ui.connection; page_index=0; record_index=0; interaction_epoch+=1; held.clear(); catalog_signature=""; automatic_selection={}
	buttons.newcharbutton.disabled=not state.get("canCreate",false); buttons.playbutton.disabled=not state.get("canSelect",false) or state.get("selected")==null or not owner_ui.native_selection.is_empty()
	buttons.cancelbutton.disabled=not state.get("connected",false)
	buttons.deletecharbutton.disabled=not owner_ui.delete_reason().is_empty(); buttons.deletecharbutton.tooltip_text=owner_ui.delete_reason()
	buttons.customcharbutton.disabled=true; buttons.customcharbutton.tooltip_text="Local character customization is not migrated yet."
	mutation_notice.text=owner_ui.local_notice
	for tag in buttons: button_captions[tag].modulate=Color(0.5,0.5,0.5) if buttons[tag].disabled else Color.WHITE
	for index in tabs.size(): tabs[index].set_pressed_no_signal(index==page_index); tabs[index].disabled=index!=0 and not state.get("canLobbyPages",state.get("canSelect",false))
	record.visible=page_index==0; extra_pages.present(page_index,state,owner_ui.connection)
	var choices: Array=owner_ui.catalog_choices(text_owner); pregen.disabled=not owner_ui.local_catalog.ready() or owner_ui.needs_local_metadata() and not owner_ui.can_select() or choices.any(func(row):return row.get("source","")!="server" and not row.has("pregenerated")); pregen.tooltip_text="Local pregenerated metadata is not available yet." if pregen.disabled else ""; pregen.set_pressed_no_signal(show_pregenerated)
	var next_signature:=JSON.stringify([owner_ui.connection,choices,show_pregenerated,text_owner.tables.get("classes",{}).size(),text_owner.revision])
	if row_signature!=next_signature: rebuild_rows(choices); row_signature=next_signature
	var next_catalog:=JSON.stringify([owner_ui.connection,state.get("choices",[]),owner_ui.local_catalog.accepted,choices.map(func(row):return [row.key,row.get("pregenerated",false)]),show_pregenerated])
	if next_catalog!=catalog_signature:
		var initial:=catalog_signature.is_empty(); catalog_signature=next_catalog; automatic_selection={}; interaction_epoch+=1; held.clear()
		if not row_keys.is_empty() and (not initial or state.get("selected")!=row_keys[0]): automatic_selection={"connection":owner_ui.connection,"catalog":catalog_signature,"key":row_keys[0]}
	buttons.playbutton.disabled=not owner_ui.can_select() or not row_keys.has(state.get("selected")) or not owner_ui.native_selection.is_empty() or not automatic_selection.is_empty()
	button_captions.playbutton.modulate=Color(0.5,0.5,0.5) if buttons.playbutton.disabled else Color.WHITE
	for row in rows: row.set_pressed_no_signal(row.get_meta("key")==state.get("selected")); row.disabled=not owner_ui.can_select()
	var value: Variant=owner_ui.record_preview(); var next_preview:=JSON.stringify([value,text_owner.tables.size(),text_owner.revision])
	prepare_record(value)
	if next_preview!=preview_signature: render_record(value); preview_signature=next_preview
	for index in record_tabs.size():
		record_tabs[index].disabled=index==3 and not spell_projection.get("ready",false) or index==1 and not skill_projection.get("ready",false) or not owner_ui.can_select() or not owner_ui.native_selection.is_empty()
		record_tabs[index].tooltip_text=text_owner.raw({"strRef":[0x2940,0x147,0x146,0x145f][index]})
	sync_record_page()
	notice.text=str(state.get("error",""))
	if notice.text.is_empty() and owner_ui.native_frontend and owner_ui.native_base_only: notice.text="Preparing character details…"
	if notice.text.is_empty() and is_instance_valid(owner_ui.native_preview): notice.text=owner_ui.native_preview.error
	if notice.text.is_empty(): notice.text=owner_ui.preferences.failure
	if notice.text.is_empty() and not record_projection.get("errors",[]).is_empty(): notice.text=str(record_projection.errors[0])
	if notice.text.is_empty(): notice.text=str(state.get("pageError",""))
	if notice.text.is_empty() and not owner_ui.local_catalog.ready(): notice.text="Reading local character records…"
	if notice.text.is_empty() and not owner_ui.local_catalog.errors.is_empty(): notice.text=str(owner_ui.local_catalog.errors.values()[0])
	if notice.text.is_empty() and owner_ui.needs_local_metadata() and not str(text_owner.tables.get("pregen",{}).get("error","")).is_empty(): notice.text="Pregenerated table unavailable; no local characters are classified as pregenerated."
	if notice.text.is_empty() and not owner_ui.delete_lease.is_empty():
		if owner_ui.delete_lease.get("refreshing",false): notice.text="Refreshing local characters…"
	elif notice.text.is_empty() and owner_ui.needs_local_metadata() and not owner_ui.can_select() and state.get("canSelect",false): notice.text="Reading active character-list tables…"
	if notice.text.is_empty() and not state.get("canSelect",false): notice.text="Waiting for the server…"
	service_automatic_selection()
func rebuild_rows(choices: Array) -> void:
	# Active-resource publication can invalidate row captions during the row's
	# own gui_input signal. Detach immediately, then destroy after dispatch ends.
	for row in rows:
		row.hide(); row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		list_content.remove_child(row); row.queue_free()
	rows.clear(); row_keys.clear()
	var sorted: Array=choices.filter(func(row):return show_pregenerated or not row.get("pregenerated",false))
	sorted.sort_custom(func(a,b):return str(a.label).nocasecmp_to(str(b.label))<0)
	var model: Dictionary=definition.models.ctl_pre_btn_char
	for data in sorted:
		var offset: Vector2=definition.first+definition.row_next*rows.size(); var entry:=Sheet.entry(definition.models,"ctl_pre_btn_char",offset)
		var row: Button=frame.create_button(entry,list_content,models,true); row.set_meta("key",str(data.key))
		var local_offset: Vector2=offset-entry.rect.position
		var title: String=str(data.label); label(row,"row:name:"+str(data.key),Sheet.box(model,"text0","text1",local_offset),title)
		var classes: Array=[]
		for item in data.get("classes",[]): classes.append(class_caption(int(item.id),data.classes.size()>=4))
		var caption: String="("+"/".join(classes)+")" if not classes.is_empty() else ""
		var code:=int(data.get("serverSource",-1)); var ref:=0xcf7d if code in [2,17] else 0xcf7c if code==14 else 0xcf7b
		caption+=(" " if not caption.is_empty() else "")+text_owner.raw({"strRef":ref})
		label(row,"row:classes:"+str(data.key),Sheet.box(model,"label0","label1",local_offset),caption)
		var portrait_rect: Rect2=definition.portrait; portrait_rect.position+=local_offset; var portrait:=picture(row,portrait_rect)
		var resource:=rules.portrait({"replicated":data},1); data_art.bind_portrait(portrait,resource)
		row.gui_input.connect(row_input.bind(str(data.key),owner_ui.connection)); rows.append(row); row_keys.append(str(data.key))
	list_content.custom_minimum_size=Vector2(list.size.x,maxf(1,definition.row_next.y*rows.size())); list_content.size=list_content.custom_minimum_size
func row_input(event: InputEvent,key: String,connection: int) -> void:
	if closed or not visible or owner_ui.connection!=connection: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		grab_focus(); automatic_selection={}
		if page_index!=0: select_page(0)
		owner_ui.choose_native(key,event.double_click); accept_event()
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not has_focus() or closed or not layout_ready or not is_visible_in_tree(): return
	# Original focused CGuiEdit consumes key presses. Its submit/cancel callbacks
	# and next/previous Tab links are unassigned in this chooser; do not let Godot
	# turn those keys into unrelated menu actions or default focus traversal.
	accept_event()
	if not owner_ui.can_select() or row_keys.is_empty() or event.keycode not in [KEY_LEFT,KEY_UP,KEY_RIGHT,KEY_DOWN]: return
	automatic_selection={}
	var selected: Variant=owner_ui.state.get("selected")
	if not owner_ui.native_selection.is_empty() and owner_ui.native_selection.connection==owner_ui.connection: selected=owner_ui.native_selection.key
	var policy:=preload("res://systems/native_data/character_lobby_keys.gd")
	var next:=policy.move(row_keys.find(selected),row_keys.size(),-1 if event.keycode in [KEY_LEFT,KEY_UP] else 1,list.scroll_vertical,roundi(definition.row_next.y),roundi(list.size.y))
	if next.scroll!=null: list.scroll_vertical=int(next.scroll)
	if page_index!=0: select_page(0)
	owner_ui.choose_native(str(row_keys[int(next.index)]))
func render_record(value: Variant) -> void:
	for target in record_labels.values(): target.text=""
	detail.text=""; record_portrait.texture=null
	if not value is Dictionary: return
	record_labels.title.text=text_owner.raw({"strRef":0xf182})+", "+text_owner.name({"firstName":value.get("firstName",{}),"lastName":value.get("lastName",{})},-1)
	if value.has("recordSource"):
		var resource:=rules.portrait({"replicated":value},4); data_art.bind_portrait(record_portrait,resource)
		if not record_projection.get("ready",false): return
		var model: Dictionary=record_projection; var lines: Array=[]
		var race: String=model.subrace if not str(model.subrace).is_empty() else rules.title("racialtypes",int(model.race))
		var heading: String=race+", "+text_owner.raw({"strRef":model.alignmentRef})
		for item in model.classes:
			var short_names: bool=model.classes.size()>3
			var caption: String=class_caption(int(item.id),short_names)
			lines.append(caption+" "+str(item.level) if short_names else caption+" ("+str(item.level)+")")
		record_labels.classes.text=heading+"\n"+("\n" if model.classes.size()<4 else ", ").join(lines)+"\n"
		for ability in model.abilities:
			var prefix:=str(ability.key).to_lower(); record_labels[prefix+"stat"].text=Values.integer_text(ability.score); record_labels[prefix+"mod"].text=Values.integer_text(ability.modifier)
		for pair in [["lac",321],["lhp",320]]: record_labels[pair[0]].text=text_owner.raw({"strRef":pair[1]})
		record_labels.hitpoints.text=str(model.currentHP)+"/"+str(model.maximumHP); record_labels.armorclass.text=str(model.armorClass)
		record_labels.experience.text=text_owner.raw({"strRef":314})+": "+str(model.experience)
		record_labels.nextlevel.text=text_owner.raw({"strRef":315})+": "+(text_owner.raw({"strRef":model.nextMaximumRef}) if model.nextMaximumRef>=0 else str(model.nextExperience))
		var detail_lines: Array=preload("res://systems/native_data/pregame_record_details.gd").markup(model.details,func(ref):return text_owner.raw({"strRef":ref}))
		preload("res://systems/server_text.gd").set_text(detail,text_owner.rich({"text":"\n".join(detail_lines)},-1))
		return
	var lines: Array=[]
	for item in value.get("classes",[]): lines.append(class_caption(int(item.id))+" ("+Values.integer_text(item.get("level"))+")")
	record_labels.classes.text="\n".join(lines)
	var abilities: Dictionary=value.get("abilities",{}); var stats: Dictionary=value
	for key in ["Str","Dex","Con","Int","Wis","Cha"]:
		if abilities.has(key):
			record_labels[key.to_lower()+"stat"].text=Values.integer_text(abilities[key]); var modifier: Variant=Values.modifier(int(abilities[key]),text_owner.tables)
			record_labels[key.to_lower()+"mod"].text=str(modifier) if modifier!=null else ""
	record_labels.lac.text=text_owner.raw({"strRef":321}); record_labels.lhp.text=text_owner.raw({"strRef":320})
	if value.has("currentHitPoints") and value.has("hitPoints"): record_labels.hitpoints.text=Values.integer_text(value.currentHitPoints)+"/"+Values.integer_text(value.hitPoints)
	if stats.has("armorClass"): record_labels.armorclass.text=Values.integer_text(stats.armorClass)
	if value.has("experience"): record_labels.experience.text="XP: "+Values.integer_text(value.experience)
	var resource:=rules.portrait({"replicated":value},4); data_art.bind_portrait(record_portrait,resource)
	preload("res://systems/server_text.gd").set_text(detail,text_owner.rich(value.get("description",{}),-1))
func invoke(tag: String) -> void:
	if closed or not visible or buttons[tag].disabled: return
	var capture: Array=held.get(tag,[]); held.erase(tag)
	if capture.size()!=3 or capture.slice(0,2)!=[owner_ui.connection,interaction_epoch]: return
	if tag in ["playbutton","deletecharbutton"] and capture[2]!=owner_ui.state.get("selected"): return
	if tag=="playbutton": owner_ui._play()
	elif tag=="deletecharbutton": owner_ui.begin_delete()
	elif tag=="newcharbutton":
		if page_index!=0: select_page(0)
		owner_ui.create_button.pressed.emit()
	elif tag=="cancelbutton": owner_ui._send({"kind":"lobby-disconnect","saveCharacter":false})
func art_ready() -> bool:
	return layout_ready and not closed and failure.is_empty() and row_art_keys.all(func(key):return frame.art.textures.has(key)) and preload("res://systems/native_menu_builder.gd").source_ready(self,frame)
func close() -> void:
	if closed: return
	if is_instance_valid(owner_ui) and not owner_ui.preferences.save(show_pregenerated): push_warning(owner_ui.preferences.failure)
	closed=true; automatic_selection={}; hide()
	if is_instance_valid(record_feats): record_feats.close()
	if is_instance_valid(record_skills): record_skills.close()
	if is_instance_valid(record_spells): record_spells.close()
	if is_instance_valid(extra_pages): extra_pages.close()
	if is_instance_valid(scrollbar): scrollbar.close()
	if is_instance_valid(detail_bar): detail_bar.close()
	if is_instance_valid(record_view): record_view.close()
	if is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(detail_font_loaded): frame.fonts.loaded.disconnect(detail_font_loaded)
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(rule_assets): rule_assets.close()
	if is_instance_valid(projection_work): projection_work.close()
	jobs.clear(); rule_jobs.clear(); models.clear(); frame=null; data_art=null; data_catalog=null; text_owner=null; owner_ui=null
func _exit_tree() -> void: close()
