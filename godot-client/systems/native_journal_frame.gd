extends Node
# Native journal presentation; replicated records remain authoritative.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Plan=preload("res://systems/native_data/journal_layout.gd")
const Data=preload("res://systems/native_data/journal_state.gd")
const Notes=preload("res://systems/native_data/journal_notes.gd")
const Date=preload("res://systems/native_data/journal_date.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
const Text=preload("res://systems/server_text.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var desktop
var panel
var frame
var text_owner
var assets
var model:=Data.new()
var notes:=Notes.new()
var models: Dictionary={}
var layouts: Dictionary={}
var jobs: Dictionary={}
var definition: Dictionary={}
var requested:=false
var layout_ready:=false
var closed:=false
var failure:=""
var source_signature:=""
var stage: Control
var title: Label
var page_image: TextureRect
var notes_image: TextureRect
var quest_scroll: ScrollContainer
var tree: Control
var notes_scroll: ScrollContainer
var edit: TextEdit
var note_notice: Label
var sort_controls: Array=[]
var quest_bar
var notes_bar
var quest_bar_host: Control
var notes_bar_host: Control
var row_controls: Array=[]
var image_requests: Dictionary={}
var last_page:=-1
var writing_notes:=false
var note_deadline:=0
var remeasure:=false
var minutes_per_hour:=5
var message_expanded: Dictionary={}
func configure(owner,catalog,cache_path: String) -> void:
	desktop=owner; panel=owner.journal; panel.native_skin=self; frame=owner.owner_ui.inventory.frame_skin; text_owner=owner.owner_ui.text
	var storage: String=panel.settings_path if not panel.settings_path.is_empty() else "user://native-menu-layout.cfg"
	notes.configure(ProjectSettings.globalize_path(storage+".journal-notes"))
	assets=Assets.new(); add_child(assets); assets.configure(catalog); assets.cache_directory=cache_path; assets.maximum_workers=2; assets.completed.connect(prepared)
	frame.art.loaded.connect(art_loaded); frame.fonts.loaded.connect(font_loaded); panel.visibility_changed.connect(owner_visibility)
	# Installed journal resources are independent of the server's journal rows.
	for name in Plan.RESOURCES+["scrollbar_simple","pb_scrl_up","pb_scrl_down","ctl_btn_pre_116"]: jobs[assets.request(name,2002,"actor-model" if name in ["ctl_jnl_entrytxt","scrollbar_simple"] else "mdl-original")]=name
	for name in ["jnl_panel","jnl_page_quest","jnl_page_notes"]: jobs[assets.request(name,2047,"gff")]="@"+name
	if frame.fonts.has_method("request"): frame.fonts.request(Plan.FONT)
func observe() -> bool:
	var name: String=text_owner.name(null,desktop.actor_id)
	if name.is_empty(): return false
	var dm:=false
	for pair in desktop.state.get("players",[]):
		var player: Dictionary=pair[1] if pair is Array else pair
		if int(player.get("objectId",-1))==desktop.actor_id: dm=bool(player.get("dm",false)); break
	var identity:=JSON.stringify([name,dm]); var changed:=model.context!=identity
	if changed: capture_notes()
	model.reset(identity)
	if notes.select(identity) and is_instance_valid(edit): assign_notes()
	if changed: source_signature=""; message_expanded.clear()
	var source: Dictionary=desktop.state.get("journal",{}); var signature:=Cache.digest(var_to_bytes(source.get("entries",[])))
	if signature!=source_signature: source_signature=signature; changed=model.observe(source) or changed
	minutes_per_hour=int(desktop.state.get("module",{}).get("minutesPerHour",5))&255
	return changed
func _process(_delta: float) -> void:
	if closed: return
	if not requested and panel.wanted: requested=true
	if note_deadline>0 and Time.get_ticks_msec()>=note_deadline: note_deadline=0; notes.flush(); update_notice()
	if layout_ready and panel.wanted and remeasure:
		remeasure=false; layout_rows(); panel.present_if_ready()
	if panel.wanted and not panel.visible:
		if failure.is_empty(): failure=art_failure()
		panel.present_if_ready()
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=name+": "+str(result.error); return
	if name.begins_with("@"): layouts[name.substr(1)]=result.value.root
	else: models[name]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	definition=Plan.parse(layouts,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	activate()
func control(parent: Control) -> Control:
	var value:=Control.new(); parent.add_child(value); value.mouse_filter=Control.MOUSE_FILTER_IGNORE; return value
func scroller(parent: Control,rect: Rect2) -> ScrollContainer:
	var value:=ScrollContainer.new(); parent.add_child(value); value.position=rect.position; value.size=rect.size; value.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; value.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER; return value
func picture(parent: Control) -> TextureRect:
	var value:=TextureRect.new(); parent.add_child(value); value.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; value.mouse_filter=Control.MOUSE_FILTER_IGNORE; value.stretch_mode=TextureRect.STRETCH_SCALE
	var id:=value.get_instance_id(); value.tree_exiting.connect(func():image_requests.erase(id),CONNECT_ONE_SHOT); return value
func image(value: TextureRect,resource: String,rect: Rect2,poses: Array=[]) -> void:
	value.position=rect.position; value.size=rect.size
	var key: String=frame.art.request_model(resource,"",{},0,"",poses); image_requests[value.get_instance_id()]={"target":weakref(value),"key":key}
	value.visible=frame.art.textures.has(key)
	if value.visible: value.texture=frame.art.textures[key]
func art_loaded(key: String,texture: Texture2D,_bounds: Dictionary) -> void:
	if closed: return
	for data in image_requests.values():
		if data.key!=key: continue
		var target: Object=data.target.get_ref()
		if is_instance_valid(target) and not target.is_queued_for_deletion(): target.texture=texture; target.show()
func font_loaded(name: String) -> void:
	if layout_ready and name==Plan.FONT: remeasure=true
func art_failure() -> String:
	var font_failures: Variant=frame.fonts.get("failed")
	if font_failures is Dictionary and font_failures.has(Plan.FONT): return "Original journal font could not be prepared: "+Plan.FONT
	for data in image_requests.values():
		var target: Object=data.target.get_ref()
		if is_instance_valid(target) and not target.is_queued_for_deletion() and frame.art.failed.has(data.key): return "Original journal artwork could not be prepared: "+str(data.key)
	for control in journal_buttons():
		if not is_instance_valid(control) or control.is_queued_for_deletion(): continue
		var geometry: Dictionary=frame.button_geometry.get(control.get_instance_id(),{})
		for style in geometry.get("styles",{}).values():
			var key: String=frame.art.models.model_key(str(geometry.resource),str(style[1]),geometry.overrides)
			if frame.art.failed.has(key): return "Original journal control could not be prepared: "+key
	for bar in [quest_bar,notes_bar]:
		if is_instance_valid(bar) and not bar.failure.is_empty(): return "Original journal scrollbar could not be prepared: "+bar.failure
	return ""
func journal_buttons() -> Array:
	var result: Array=[panel.close_button]+panel.tabs+sort_controls.filter(func(control):return control is Button)
	for row in row_controls: result.append(row.button)
	for bar in [quest_bar,notes_bar]:
		if is_instance_valid(bar): result.append_array([bar.up,bar.down])
	return result
func display_ready() -> bool:
	if closed or not failure.is_empty() or not layout_ready: return false
	if frame.fonts.has_method("request") and not frame.fonts.fonts.has(Plan.FONT): return false
	for data in image_requests.values():
		var target: Object=data.target.get_ref()
		if is_instance_valid(target) and not target.is_queued_for_deletion() and not frame.art.textures.has(data.key): return false
	for control in journal_buttons():
		if not is_instance_valid(control) or control.is_queued_for_deletion(): continue
		var geometry: Dictionary=frame.button_geometry.get(control.get_instance_id(),{})
		if geometry.is_empty(): return false
		for style in geometry.styles.values():
			if not frame.art.textures.has(frame.art.models.model_key(str(geometry.resource),str(style[1]),geometry.overrides)): return false
	for bar in [quest_bar,notes_bar]:
		if not is_instance_valid(bar) or not bar.art_ready: return false
	return true
func activate() -> void:
	var utility_model:=Plan.Model.model(models.ctl_btn_pre_116); var utility_bounds: Rect2=utility_model.bounds
	layout_ready=true; panel.window_column.hide(); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=definition.size; panel.size=definition.size; panel.visual_extent=Vector2(definition.size.x,definition.size.y+4+utility_bounds.size.y)
	stage=control(panel); stage.size=panel.size
	image(picture(stage),"pnl_jnl_panel",definition.main.rect)
	page_image=picture(stage); image(page_image,"pnl_jnl_page1",definition.page.rect)
	notes_image=picture(stage); image(notes_image,"edit_jnl_348x408",definition.notes.rect)
	title=frame.create_label(definition.title,stage); title.text=text_owner.raw({"strRef":int(definition.title.caption.get("Obj_StrRef",10562))}); title.mouse_filter=Control.MOUSE_FILTER_STOP; title.gui_input.connect(panel._title_input)
	frame.button(panel.close_button,definition.close,stage,models,false)
	var group:=ButtonGroup.new()
	for at in 3:
		var button: Button=panel.tabs[at]; frame.button(button,definition.tabs[at],stage,models,false,true); button.toggle_mode=true; button.button_group=group; button.tooltip_text=text_owner.raw({"strRef":Plan.TAB_REFS[at]})
	# A separate replacement-only entry preserves received world messages.
	# It is not represented as a fourth original page tab.
	var parsed: Dictionary={"ctl_btn_pre_116":utility_model}; var utility:=Plan.entry(parsed,"ctl_btn_pre_116",Vector2(0,definition.size.y+4)-utility_bounds.position)
	frame.button(panel.tabs[3],utility,stage,models,false); frame.button_caption(panel.tabs[3],"Messages"); panel.tabs[3].tooltip_text="Received server messages"
	panel.set_meta("native_window_extras",[weakref(panel.tabs[3])])
	quest_scroll=scroller(stage,definition.quest_view); tree=control(quest_scroll); tree.custom_minimum_size.x=definition.quest_view.size.x
	quest_bar_host=control(stage); quest_bar=Bar.new(); quest_bar_host.add_child(quest_bar); quest_bar.configure(frame,models,definition.quest_bar,quest_scroll,36)
	for at in 3:
		var button:=Button.new(); stage.add_child(button); var entry: Dictionary=definition.sort[["dateradio","nameradio","priorityradio"][at]]; frame.button(button,entry,stage,models,false,true); button.toggle_mode=true; button.pressed.connect(func():sort_by(at)); sort_controls.append(button)
	for entry in definition.sort_labels:
		var label: Label=frame.create_label(entry,stage); label.text=text_owner.raw({"strRef":int(entry.caption.get("Obj_StrRef",-1))}); sort_controls.append(label)
	notes_scroll=scroller(stage,definition.notes_view); edit=TextEdit.new(); notes_scroll.add_child(edit); edit.custom_minimum_size=Vector2(definition.notes_view.size.x,definition.notes_view.size.y); edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL; edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY; edit.scroll_fit_content_height=true; edit.scroll_past_end_of_file=false
	for state in ["normal","focus","read_only"]: edit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	edit.add_theme_color_override("font_color",Color.WHITE); edit.add_theme_color_override("caret_color",Color.WHITE); frame.font_style(edit,{"AurString_Font":Plan.FONT}); assign_notes()
	edit.text_changed.connect(func():if not writing_notes: notes.edit(edit.text); note_deadline=Time.get_ticks_msec()+250)
	edit.caret_changed.connect(caret_changed)
	notes_bar_host=control(stage); notes_bar=Bar.new(); notes_bar_host.add_child(notes_bar); notes_bar.configure(frame,models,definition.notes,notes_scroll,14)
	note_notice=Label.new(); stage.add_child(note_notice); note_notice.position=Vector2(120,definition.size.y+5); note_notice.size=Vector2(240,26); frame.font_style(note_notice,{"AurString_Font":Plan.FONT}); update_notice(); render()
func assign_notes() -> void:
	if not is_instance_valid(edit): return
	writing_notes=true; edit.text=notes.value; writing_notes=false
func blocks_pointer(point: Vector2) -> bool:
	return panel.visible and (panel.get_global_rect().has_point(point) or (layout_ready and panel.tabs[3].get_global_rect().has_point(point)))
func capture_notes() -> void:
	if is_instance_valid(edit) and not writing_notes: notes.edit(edit.text)
func caret_changed() -> void:
	if not is_instance_valid(edit) or writing_notes: return
	var caret: Vector2=edit.get_caret_draw_pos(); var current: float=notes_scroll.scroll_vertical
	if caret.y<current: notes_scroll.scroll_vertical=maxi(0,int(caret.y))
	elif caret.y+edit.get_line_height()>current+notes_scroll.size.y: notes_scroll.scroll_vertical=int(caret.y+edit.get_line_height()-notes_scroll.size.y)
func update_notice() -> void:
	if is_instance_valid(note_notice): note_notice.text=notes.failure; note_notice.visible=not notes.failure.is_empty()
func owner_visibility() -> void:
	if not panel.wanted: capture_notes(); notes.flush(); update_notice(); last_page=-1
func clear_rows() -> void:
	row_controls.clear()
	for child in tree.get_children(): tree.remove_child(child); child.queue_free()
func render() -> void:
	if closed or not layout_ready or not panel.wanted: return
	var page: int=panel.page
	if last_page==2 and page!=2: capture_notes(); notes.flush(); update_notice()
	page_image.visible=page!=2; notes_image.visible=page==2; quest_scroll.visible=page!=2; quest_bar_host.visible=page!=2; notes_scroll.visible=page==2; notes_bar_host.visible=page==2
	for control in sort_controls: control.visible=page<2
	for at in 4:
		panel.tabs[at].disabled=false
		if at<3: panel.tabs[at].set_pressed_no_signal(at==page)
	for at in 3: sort_controls[at].set_pressed_no_signal(page<2 and at==model.modes[page])
	title.text=text_owner.raw({"strRef":10562}) if page!=3 else "Messages"
	clear_rows()
	if page==2:
		if last_page!=2: edit.grab_focus()
	else:
		var bound: int=panel.view_id
		for row in panel.state.get("entries",[]):
			var root:=control(tree); var button:=Button.new(); root.add_child(button); button.toggle_mode=true
			var expanded: bool=bool(row.get("expanded",message_expanded.get(str(row.get("key","")),true)))
			frame.button(button,Plan.entry(definition.models,"ctl_jnl_questbtn",Vector2.ZERO),root,models,false,true); button.set_pressed_no_signal(expanded)
			if bool(row.get("unread",false)):
				var geometry: Dictionary=frame.button_geometry[button.get_instance_id()]
				for state in ["normal","normal_checked"]:
					geometry.styles[state][1]="encouraged"; frame.art.bind(geometry.styles[state][0],"ctl_jnl_questbtn","texture",true,"encouraged")
			var label:=Text.label(row.title,289); root.add_child(label); label.custom_minimum_size=Vector2.ZERO; label.fit_content=false; label.position=Vector2(41,8); label.size=Vector2(289,26); frame.font_style(label,{"AurString_Font":Plan.FONT}); Text.set_text(label,row.title)
			var key:=str(row.key); button.pressed.connect(func():expand(key,bound))
			var detail: RichTextLabel; var background: TextureRect
			if expanded:
				background=picture(root); root.move_child(background,0); detail=Text.label({},284); root.add_child(detail); frame.font_style(detail,{"AurString_Font":Plan.FONT})
				var stamp:=Date.format(int(row.get("date",0)),int(row.get("time",0)),minutes_per_hour,text_owner.raw({"strRef":0x10c40}),text_owner.raw({"strRef":0x10c3f}))
				var spans: Array=[{"text":stamp+"\n\n"}]+row.description.get("spans",[{"text":row.description.get("text","")}]); Text.set_text(detail,{"spans":spans})
			row_controls.append({"root":root,"button":button,"label":label,"detail":detail,"background":background,"expanded":expanded})
		layout_rows(); remeasure=true
		quest_scroll.set_deferred("scroll_vertical",int(panel.positions.get(page,0)))
	last_page=page; panel._clamp(); panel.present_if_ready()
func layout_rows() -> void:
	if not layout_ready or panel.page==2: return
	var point: Vector2=definition.quest_tree-definition.quest_view.position
	for row in row_controls:
		row.root.position=point; point+=definition.models.ctl_jnl_questbtn.hooks.nextlink
		if row.expanded:
			var pixels: float=row.detail.get_content_height(); var plan:=Plan.description(models.ctl_jnl_entrytxt,pixels,definition.models.ctl_jnl_questbtn.hooks.nextlink)
			if not str(plan.error).is_empty(): failure=str(plan.error); return
			row.detail.position=plan.text.position; row.detail.custom_minimum_size=Vector2(284,0); row.detail.size=plan.text.size; image(row.background,"ctl_jnl_entrytxt",plan.rect,plan.poses); point=row.root.position+plan.next
	tree.custom_minimum_size.y=maxf(1,point.y); tree.size=tree.custom_minimum_size
func sort_by(mode: int) -> void:
	if closed or not panel.wanted or panel.view_id<0 or panel.page>1: return
	if model.sort_by(panel.page,mode): desktop.refresh_journal(panel.page)
func expand(key: String,bound: int) -> void:
	if closed or not panel.wanted or panel.view_id!=bound: return
	if panel.page==3: message_expanded[key]=not bool(message_expanded.get(key,true))
	elif not model.expand(key): return
	panel.positions[panel.page]=quest_scroll.scroll_vertical; desktop.refresh_journal(panel.page)
func reset_view() -> void:
	capture_notes(); notes.flush(); note_deadline=0; last_page=-1
	if layout_ready: clear_rows()
func snapshot() -> Dictionary:
	return {"ready":layout_ready,"failure":failure,"pending":jobs.size(),"records":model.records.size(),"rows":row_controls.size(),"notes_pending":notes.drafts.size(),"notes_writes":notes.writes,"notes_failure":notes.failure,"native_only":true,"full_journal_parity":false}
func close() -> void:
	if closed: return
	closed=true; capture_notes(); notes.flush(); jobs.clear(); image_requests.clear(); models.clear(); layouts.clear()
	for bar in [quest_bar,notes_bar]:
		if is_instance_valid(bar): bar.close()
	if is_instance_valid(frame) and is_instance_valid(frame.art) and frame.art.loaded.is_connected(art_loaded): frame.art.loaded.disconnect(art_loaded)
	if is_instance_valid(frame) and is_instance_valid(frame.fonts) and frame.fonts.loaded.is_connected(font_loaded): frame.fonts.loaded.disconnect(font_loaded)
	if is_instance_valid(assets): assets.close()
func _exit_tree() -> void: close()
