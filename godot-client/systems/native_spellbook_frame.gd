extends Node
# Original main/memorization geometry over the received private spellbook owner.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/spellbook_layout.gd")
const Drag=preload("res://systems/draggable_panel.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
var panel
var frame
var text_owner
var assets
var refresh_owner: Callable
var jobs: Dictionary={}
var models: Dictionary={}
var definition: Dictionary={}
var help_gui: Dictionary={}
var help_models_requested:=false
var layout_ready:=false
var requested:=false
var closed:=false
var failure:=""
var stage: Control
var tab_root: Control
var known_scroll: ScrollContainer
var memory_scroll: ScrollContainer
var family_scroll: ScrollContainer
var memory_stage: Control
var family_stage: Control
var known_tree: Control
var memory_tree: Control
var family_tree: Control
var memory
var family
var help_window
var action_window
var help_bar
var help_icon: TextureRect
var memory_wanted:=true
var bars: Array=[]
var class_tabs: Dictionary={}
var level_tabs: Dictionary={}
var roots: Dictionary={}
var leaves: Dictionary={}
var extras: Dictionary={}
var expanded: Dictionary={}
var memory_expanded: Dictionary={}
var scroll_values: Dictionary={}
var last_level:=""
var last_family:=""
var repainting:=false
func configure(target,catalog,cache_path: String,text,painter,refresh: Callable) -> void:
	panel=target; panel.native_skin=self; frame=painter; text_owner=text; refresh_owner=refresh
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	panel.visibility_changed.connect(owner_visibility); frame.art.loaded.connect(art_loaded)
func _process(_delta: float) -> void:
	if closed or requested or not panel.wanted: return
	requested=true; set_process(false)
	for name in Plan.RESOURCES+["scrollbar_simple","pb_scrl_up","pb_scrl_down","ctl_chrsht_lvlup"]:
		var id: int=assets.request(name,2002,"actor-model" if name=="scrollbar_simple" else "mdl-original")
		if id<0: failure=str(assets.failure); return
		jobs[id]=name
	jobs[assets.request("cg_spellinfo",2047,"gff")]="@help-gui"
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name=="@help-gui":
		if result.value.get("type","")!="GUI ": failure="Invalid original spell-info GUI signature"; return
		help_gui=result.value.root
	else: models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	if not help_models_requested:
		help_models_requested=true
		var required: Dictionary={str(help_gui.get("Obj_ResRef","")).to_lower():true}
		for child in help_gui.get("Obj_ChildList",[]):
			if child.has("Obj_ResRef"): required[str(child.Obj_ResRef).to_lower()]=true
		for resource in required:
			if not models.has(resource): jobs[assets.request(resource,2002,"mdl-original")]=resource
		if not jobs.is_empty(): return
	definition=Plan.parse(models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	for extra in ["pb_scrl_up","pb_scrl_down","ctl_chrsht_lvlup"]:
		definition.models[extra]=Plan.Model.model(models[extra])
		if not str(definition.models[extra].error).is_empty(): failure=str(definition.models[extra].error); return
	var resource:=str(help_gui.Obj_ResRef).to_lower(); var geometry:=Plan.Model.model(models[resource])
	if not str(geometry.error).is_empty(): failure=str(geometry.error); return
	var controls:=Gui.elements(help_gui,models,-geometry.bounds.position)
	if not str(controls.error).is_empty(): failure=str(controls.error); return
	for tag in ["title","editbox","closebutton"]:
		if not controls.entries.has(tag): failure="Original spell-info control missing: "+tag; return
	if not geometry.hooks.has("icon"): failure="Original spell-info icon attachment missing"; return
	definition.help={"resource":resource,"size":geometry.bounds.size,"entries":controls.entries,"icon":-geometry.bounds.position+geometry.hooks.icon}
	activate()
func control(parent: Control,rect: Rect2=Rect2()) -> Control:
	var result:=Control.new(); parent.add_child(result); result.position=rect.position; result.size=rect.size; result.mouse_filter=Control.MOUSE_FILTER_IGNORE; return result
func image(resource: String,parent: Control) -> TextureRect:
	var result:=TextureRect.new(); parent.add_child(result); result.mouse_filter=Control.MOUSE_FILTER_IGNORE; result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; result.stretch_mode=TextureRect.STRETCH_SCALE
	var rect: Rect2=definition.models[resource].bounds; result.position=rect.position; result.size=rect.size; frame.art.bind(result,resource,"texture",true,""); return result
func heading(window,parent: Control,resource: String) -> void:
	var point: Vector2=definition.models[resource].hooks.title
	frame.label(window.heading,{"rect":Rect2(point-Vector2(0,9),Vector2(320,18)),"caption":{"AurString_Font":Plan.FONT,"AurString_AlignV":0.5}},parent); window.heading.mouse_filter=Control.MOUSE_FILTER_STOP
	frame.button(window.close_button,Plan.entry(definition.models,"ctl_btn_x",definition.models[resource].hooks.xbutton),parent,models,false)
func new_window(title: String,key: String,position: Vector2) -> Dictionary:
	var window:=Drag.new(); panel.get_parent().add_child(window); window.configure(title,key,position,panel.settings_path); window.window_column.hide(); window.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); window.custom_minimum_size=definition.memory_size; window.size=definition.memory_size
	var owner:=control(window,Rect2(Vector2.ZERO,definition.memory_size)); image("pnl_spellmemoriz",owner); heading(window,owner,"pnl_spellmemoriz"); window.hide(); return {"window":window,"stage":owner}
func scroll(parent: Control,rect: Rect2) -> ScrollContainer:
	var result:=ScrollContainer.new(); parent.add_child(result); result.position=rect.position; result.size=rect.size; result.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; result.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS; return result
func activate() -> void:
	layout_ready=true; panel.window_column.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=definition.main_size; panel.size=definition.main_size
	stage=control(panel,Rect2(Vector2.ZERO,definition.main_size)); image("pnl_spellbook",stage); heading(panel,stage,"pnl_spellbook"); tab_root=control(stage)
	known_scroll=scroll(stage,definition.known_view); known_tree=control(known_scroll)
	var item:=new_window(text_owner.raw({"strRef":0xd02a}),"spell-memorization",panel.position+Vector2(365,0)); memory=item.window
	memory_stage=item.stage; memory_scroll=scroll(memory_stage,definition.memory_view); memory_tree=control(memory_scroll); memory.close_requested.connect(func():memory_wanted=false)
	item=new_window("Spell variants","spell-family",panel.position+Vector2(30,30)); family=item.window; family_stage=item.stage; family_scroll=scroll(family_stage,definition.memory_view); family_tree=control(family_scroll)
	family.close_requested.connect(func():if panel.wanted: panel.request.emit({"kind":"book-family-close","viewId":panel.view_id}))
	var back: Button=frame.create_button(Plan.entry(definition.models,"pb_scrl_up",Vector2(318,18)),item.stage,models); back.tooltip_text="Back to parent spell"; back.pressed.connect(func():if panel.wanted: panel.request.emit({"kind":"book-family-back","viewId":panel.view_id}))
	help_window=Drag.new(); panel.get_parent().add_child(help_window); help_window.configure("Spell description","spell-description",panel.position+Vector2(40,40),panel.settings_path); help_window.window_column.hide(); help_window.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); help_window.custom_minimum_size=definition.help.size; help_window.size=definition.help.size
	var help_stage:=control(help_window,Rect2(Vector2.ZERO,definition.help.size)); frame.image(definition.help.resource,Rect2(Vector2.ZERO,definition.help.size),help_stage)
	help_icon=TextureRect.new(); help_stage.add_child(help_icon); help_icon.position=definition.help.icon-Vector2(16,16); help_icon.size=Vector2(32,32); help_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; help_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; help_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.label(help_window.heading,definition.help.entries.title,help_stage); help_window.heading.mouse_filter=Control.MOUSE_FILTER_STOP
	frame.button(help_window.close_button,definition.help.entries.closebutton,help_stage,models,false); frame.button_caption(help_window.close_button,text_owner.raw({"strRef":int(definition.help.entries.closebutton.caption.Obj_StrRef)}))
	var help_scroll:=scroll(help_stage,definition.help.entries.editbox.rect); panel.details.reparent(help_scroll,false); panel.details.custom_minimum_size=Vector2(help_scroll.size.x-18,0); panel.details.fit_content=true; panel.details.scroll_active=false; frame.font_style(panel.details,definition.help.entries.editbox.caption)
	help_bar=Bar.new(); help_stage.add_child(help_bar); help_bar.configure(frame,models,definition.help.entries.editbox,help_scroll,17); help_window.hide()
	# Preserve explicit commands in a separately styled utility window while
	# original pickup/cancel/world-drop gestures remain under audit.
	item=new_window("Spell actions","spell-actions",panel.position+Vector2(60,60)); action_window=item.window
	for index in 3:
		var button: Button=[panel.cast,panel.memorize,panel.clear][index]; var geometry: Rect2=definition.models.ctl_chrsht_lvlup.bounds; var offset:=Vector2((360-geometry.size.x)/2,70+index*(geometry.size.y+12))-geometry.position
		frame.button(button,Plan.entry(definition.models,"ctl_chrsht_lvlup",offset),item.stage,models,false); frame.button_caption(button,["Cast","Prepare","Clear"][index])
	panel.notice.reparent(item.stage,false); panel.notice.position=Vector2(8,350); panel.notice.size=Vector2(335,100); panel.notice.clip_text=false; panel.notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; frame.font_style(panel.notice,{"AurString_Font":Plan.FONT})
	if refresh_owner.is_valid() and panel.wanted: refresh_owner.call()
func owner_visibility() -> void:
	if not layout_ready or closed: return
	if not panel.visible:
		memory.hide(); family.hide(); help_window.hide(); action_window.hide(); memory_wanted=true
func clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()
func begin_render() -> void:
	if closed or not layout_ready: return
	scroll_values.known=known_scroll.scroll_vertical; scroll_values.memory=memory_scroll.scroll_vertical
	for bar in bars:
		if is_instance_valid(bar): bar.close(); bar.queue_free()
	bars.clear(); class_tabs.clear(); level_tabs.clear(); roots.clear(); leaves.clear(); extras.clear(); clear(tab_root); clear(known_tree); clear(memory_tree); clear(family_tree)
func make_bar(owner: ScrollContainer,resource: String,parent: Control,offset: Vector2) -> void:
	var bar:=Bar.new(); parent.add_child(bar); bar.configure(frame,models,{"offset":offset,"model":definition.models[resource],"caption":{}},owner,36); bars.append(bar)
func tab(entry: Dictionary,parent: Control,selected: bool,icon: String) -> Button:
	var button:=Button.new(); parent.add_child(button); var value:=entry.duplicate(true)
	if not icon.is_empty(): value.overrides={"gui_replace01":icon}
	frame.button(button,value,parent,models,false,true); button.toggle_mode=true; button.set_pressed_no_signal(selected); return button
func root_button(parent: Control,origin: Vector2,key: String,caption: String,icon: String,opened: bool,callback: Callable) -> Button:
	var button:=tab(Plan.entry(definition.models,"ctl_treebtn_root",origin),parent,opened,icon); roots[key]=button
	var label: Label=frame.create_label({"rect":Rect2(Vector2(74,6)-definition.models.ctl_treebtn_root.bounds.position,Vector2(250,34)),"caption":{"AurString_Font":Plan.FONT,"AurString_AlignV":0.5}},button); label.text=caption
	button.pressed.connect(func():if panel.wanted and roots.get(key)==button: callback.call(button.button_pressed)); return button
func refresh_local() -> void:
	if repainting or closed or not panel.wanted: return
	repainting=true; panel.present(panel.state); repainting=false
func render() -> void:
	if closed or not layout_ready or panel.state.is_empty(): return
	var state: Dictionary=panel.state; var view: int=panel.view_id; var selected_class: String=""
	for index in 8:
		var cls: Dictionary=state.classes[index] if index<state.classes.size() else {}; var button:=tab(definition.class_tabs[index],tab_root,not cls.is_empty() and int(cls.index)==int(state.classIndex),str(cls.get("icon",""))); class_tabs[index]=button; button.disabled=cls.is_empty(); button.tooltip_text=str(cls.get("label",""))
		if not cls.is_empty():
			if int(cls.index)==int(state.classIndex): selected_class=str(cls.label)
			button.pressed.connect(func():if panel.wanted and panel.view_id==view and class_tabs.get(index)==button: panel.query({"classIndex":int(cls.index),"metamagic":0}))
	panel.set_caption(selected_class+" "+text_owner.raw({"strRef":0x145f}))
	for index in 10:
		var button:=tab(definition.level_tabs[index],tab_root,index==int(state.level),Plan.LEVEL_ICONS[index]); level_tabs[index]=button; button.tooltip_text=text_owner.raw({"strRef":Plan.LEVEL_REFS[index]}); button.pressed.connect(func():if panel.wanted and panel.view_id==view and level_tabs.get(index)==button: panel.query({"level":index}))
	var scope:=str(state.classIndex)+":"+str(state.level); var origin: Vector2=definition.known_tree-definition.known_view.position
	for group in state.get("groups",[]):
		var mask:=int(group.metamagic); var key:=scope+":"+str(mask); var open: bool=expanded.get(key,mask==0); var option: Dictionary={}
		for row in Plan.META:
			if int(row.mask)==mask: option=row; break
		root_button(known_tree,origin,"known:"+key,text_owner.raw({"strRef":int(option.get("label",0x104b8))}),Plan.LEVEL_ICONS[int(state.level)] if mask==0 else str(option.get("icon","")),open,func(value):expanded[key]=value; refresh_local())
		var planned:=Plan.known_rows(definition.models,group.entries.size() if open else 0,origin)
		if open:
			for index in group.entries.size(): leaf(group.entries[index],planned.rows[index],known_tree)
		origin=planned.next_origin
	known_tree.custom_minimum_size=Vector2(331,maxf(1,origin.y)); make_bar(known_scroll,"ctl_wizardpage",stage,definition.page_origin)
	var level_key:=str(state.classIndex)+":"+str(state.level)
	if last_level!=level_key: memory_expanded[level_key]=true; last_level=level_key
	origin=definition.memory_tree-definition.memory_view.position
	for group in state.get("memoryGroups",[]):
		var level:=int(group.level); var key:=str(state.classIndex)+":"+str(level); var open: bool=memory_expanded.get(key,false)
		root_button(memory_tree,origin,"memory:"+key,text_owner.raw({"strRef":Plan.LEVEL_REFS[level]}),Plan.LEVEL_ICONS[level],open,func(value):memory_expanded[key]=value; refresh_local())
		var planned:=Plan.memory_slots(definition.models,group.entries.size() if open else 0,origin)
		if open:
			for index in group.entries.size(): memory_slot(group.entries[index],planned.slots[index])
		origin=planned.next_origin
	memory_tree.custom_minimum_size=Vector2(331,maxf(1,origin.y)); make_bar(memory_scroll,"pnl_spellmemoriz",memory_stage,Vector2.ZERO)
	memory.visible=panel.wanted and bool(state.prepared) and memory_wanted
	var family_title:=str(state.get("familyTitle","")); family.visible=panel.wanted and not family_title.is_empty(); family.set_caption(family_title)
	if not family_title.is_empty():
		var plan:=Plan.known_rows(definition.models,state.family.size(),Vector2(-20,-32))
		for index in state.family.size(): leaf(state.family[index],plan.rows[index],family_tree)
		family_tree.custom_minimum_size=Vector2(331,maxf(1,plan.next_origin.y))
		make_bar(family_scroll,"pnl_spellmemoriz",family_stage,Vector2.ZERO)
		if last_family!=family_title: family.move_to_front()
	last_family=family_title
	known_scroll.set_deferred("scroll_vertical",int(scroll_values.get("known",0))); memory_scroll.set_deferred("scroll_vertical",int(scroll_values.get("memory",0))); select_entry()
func leaf(row: Dictionary,entry: Dictionary,parent: Control) -> void:
	var id:=int(row.entryId); var button: Button=panel.widgets[id]; frame.button(button,entry,parent,models,false,true); button.toggle_mode=true; button.caption.show(); button.counter.hide(); button.secondary_image.hide(); leaves[id]={"button":button,"entry":entry}
	frame.font_style(button.caption,{"AurString_Font":Plan.FONT}); button.caption.autowrap_mode=TextServer.AUTOWRAP_OFF; button.caption.clip_text=true
	button.caption.text=str(row.label)
	var view: int=panel.view_id; var help: Button=frame.create_button(entry.help,parent,models); help.tooltip_text="Spell description"; help.pressed.connect(func():if panel.wanted and panel.view_id==view and panel.widgets.get(id)==button: show_description(id))
	var prepare: Button=frame.create_button(entry.arrow,parent,models); prepare.tooltip_text="Prepare spell"; prepare.pressed.connect(func():if panel.wanted and panel.view_id==view and panel.widgets.get(id)==button: panel.selected_id=id; panel.operation("book-prepare"))
	button.context_requested.connect(func(_point):if panel.wanted and panel.view_id==view and panel.widgets.get(id)==button: show_actions(id))
	extras[id]={"help":help,"prepare":prepare}; layout_leaf(id)
func memory_slot(row: Dictionary,entry: Dictionary) -> void:
	var id:=int(row.entryId); var button: Button=panel.widgets[id]; frame.button(button,entry,memory_tree,models,false); button.caption.hide(); button.counter.hide(); button.secondary_image.hide(); leaves[id]={"button":button,"entry":entry}; layout_leaf(id)
	button.image.modulate.a=1.0 if bool(row.ready) else 0.4
	# The existing explicit action strip is available through the description.
	var view: int=panel.view_id
	button.context_requested.connect(func(_point):if panel.wanted and panel.view_id==view and panel.widgets.get(id)==button: show_actions(id))
func layout_leaf(id: int) -> void:
	if not leaves.has(id): return
	var item: Dictionary=leaves[id]; var button: Button=item.button; var entry: Dictionary=item.entry; var local: Vector2=entry.offset-button.position
	button.image.position=local+entry.model.hooks.icon-Vector2(16,16); button.image.size=Vector2(32,32)
	if entry.has("caption"): button.caption.position=entry.caption.position-button.position; button.caption.size=entry.caption.size
func art_loaded(_key: String,_texture: Texture2D,_bounds: Dictionary) -> void:
	if closed or not layout_ready: return
	for id in leaves: layout_leaf(int(id))
func select_entry() -> void:
	if closed or not layout_ready: return
	for id in leaves:
		var button: Button=leaves[id].button
		if button.toggle_mode: button.set_pressed_no_signal(int(id)==panel.selected_id)
	for id in extras:
		var row: Dictionary=panel.rows.get(int(id),{}); extras[id].help.visible=int(id)==panel.selected_id and int(row.get("spellId",-1))>=0; extras[id].prepare.visible=extras[id].help.visible and bool(panel.state.get("prepared",false)) and not bool(row.get("pending",false))
func show_description(id: int) -> void:
	if not panel.rows.has(id): return
	panel.select_entry(id,true); frame.art.bind(help_icon,str(panel.rows[id].icon)); help_window.set_caption(str(panel.rows[id].label)); help_window.show(); help_window.move_to_front()
func show_actions(id: int) -> void:
	if not panel.rows.has(id): return
	panel.select_entry(id,true); action_window.set_caption(str(panel.rows[id].label)); action_window.show(); action_window.move_to_front()
func blocks_pointer(point: Vector2) -> bool:
	for window in [memory,family,help_window,action_window]:
		if is_instance_valid(window) and window.visible and window.get_global_rect().has_point(point): return true
	return false
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"pending":jobs.size(),"class_tabs":class_tabs.size(),"level_tabs":level_tabs.size(),"roots":roots.size(),"visible_entries":leaves.size(),"memory_visible":is_instance_valid(memory) and memory.visible,"native_only":true,"full_spellbook_parity":false}
func close() -> void:
	if closed: return
	closed=true; jobs.clear(); models.clear()
	for bar in bars:
		if is_instance_valid(bar): bar.close()
	if is_instance_valid(help_bar): help_bar.close()
	if is_instance_valid(frame) and is_instance_valid(frame.art) and frame.art.loaded.is_connected(art_loaded): frame.art.loaded.disconnect(art_loaded)
	for window in [memory,family,help_window,action_window]:
		if is_instance_valid(window): window.queue_free()
	if is_instance_valid(assets): assets.close()
func _exit_tree() -> void: close()
