extends Node
const Draggable=preload("res://systems/draggable_panel.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const Bar=preload("res://systems/native_scrollbar.gd")
var owner_frame
var panel
var edit: TextEdit
var scroll: ScrollContainer
var bar
var buttons: Dictionary={}
var notice: Label
var serial:=0
var state: Dictionary={}
var definition: Dictionary={}
var failure:=""
var layout_ready:=false
var pending:=false
var caret_pending:=0
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
func configure(owner,layout: Dictionary,models: Dictionary) -> void:
	owner_frame=owner; set_process(false)
	var main_name:=str(layout.get("Obj_ResRef","")).to_lower(); var main:=Geometry.model(models[main_name]); var origin: Vector2=-main.bounds.position
	definition=Gui.elements(layout,models,origin)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	var entries: Dictionary=definition.entries
	for child in layout.get("Obj_ChildList",[]):
		if str(child.get("Obj_Tag","")).to_lower()=="pintextedit":
			var nested:=Gui.elements(child,models,entries.pintextedit.offset)
			if str(nested.error).is_empty() and nested.entries.has("title"): entries.title=nested.entries.title
	for tag in ["pintextedit","title","okbutton","cancelbutton","deletebutton"]:
		if not entries.has(tag): failure="Missing original map-note control: "+tag; return
	var ui=owner.desktop.owner_ui;var order=modal_lease.property(ui,"modal_order");var surfaces=modal_lease.property(ui,"modal_surfaces");var source_canvas=modal_lease.property(ui,"layer");var parent: Node=ui.controls
	if is_instance_valid(surfaces) and source_canvas is CanvasLayer:parent=surfaces.create_root(ui.controls,source_canvas)
	panel=Draggable.new(); parent.add_child(panel); panel.configure("Map Note","map-note",Vector2(250,160),owner.panel.settings_path); panel.window_column.hide(); panel.close_requested.connect(cancel); panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); panel.custom_minimum_size=main.bounds.size; panel.size=main.bounds.size
	modal_lease.configure(panel,order,surfaces,parent.get_parent() if parent.get_parent() is CanvasLayer else null);modal_lease.bind_input(panel)
	modal_lease.admission_changed.connect(func(admitted):
		if not admitted:panel.dragging=false)
	var stage:=Control.new(); panel.add_child(stage); stage.mouse_filter=Control.MOUSE_FILTER_IGNORE; stage.size=main.bounds.size
	owner.image(owner.picture(stage),main_name,Rect2(Vector2.ZERO,main.bounds.size))
	var title: Label=owner.frame.create_label(entries.title,stage,owner.desktop.owner_ui.text.raw({"strRef":int(entries.title.caption.get("Obj_StrRef",6379))})); title.mouse_filter=Control.MOUSE_FILTER_STOP; title.gui_input.connect(panel._title_input)
	var entry: Dictionary=entries.pintextedit
	if entry.model.drawn: owner.image(owner.picture(stage),entry.resource,entry.rect)
	var text_rect:=Rect2(entry.offset+entry.model.hooks.text0,entry.model.hooks.text1-entry.model.hooks.text0).abs()
	scroll=ScrollContainer.new(); stage.add_child(scroll); scroll.position=text_rect.position; scroll.size=text_rect.size; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
	edit=TextEdit.new(); scroll.add_child(edit); edit.custom_minimum_size=text_rect.size; edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL; edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY; edit.scroll_fit_content_height=true
	for kind in ["normal","focus","read_only"]: edit.add_theme_stylebox_override(kind,StyleBoxEmpty.new())
	owner.frame.font_style(edit,entry.caption); edit.add_theme_color_override("font_color",Color.WHITE); edit.add_theme_color_override("caret_color",Color.WHITE)
	edit.caret_changed.connect(queue_caret); edit.text_changed.connect(queue_caret); edit.resized.connect(queue_caret)
	bar=Bar.new(); stage.add_child(bar); bar.configure(owner.frame,models,entry,scroll,14)
	for tag in ["okbutton","cancelbutton","deletebutton"]:
		var button: Button=owner.frame.create_button(entries[tag],stage,models); owner.frame.button_caption(button,owner.desktop.owner_ui.text.raw({"strRef":int(entries[tag].caption.get("Obj_StrRef",-1))})); buttons[tag]=button
	buttons.okbutton.pressed.connect(func():submit("add" if int(state.get("type",-1))<0 else "change")); buttons.deletebutton.pressed.connect(func():submit("delete")); buttons.cancelbutton.pressed.connect(cancel)
	notice=Label.new(); stage.add_child(notice); notice.position=Vector2(4,main.bounds.size.y+4); notice.size=Vector2(main.bounds.size.x,40); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; owner.frame.font_style(notice,{"AurString_Font":"fnt_galahad14"}); notice.add_theme_color_override("font_color",Color(1,0.6,0.5)); notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layout_ready=true; cancel()
func open(value: Dictionary) -> void:
	if not layout_ready: return
	serial+=1; state=value.duplicate(true); pending=false; edit.text=str(state.get("text","")); notice.text=""; panel.show(); panel.move_to_front(); panel._clamp(); edit.editable=true; edit.grab_focus(); scroll.scroll_vertical=0
	buttons.okbutton.disabled=false; buttons.deletebutton.visible=int(state.get("type",-1))==1; buttons.deletebutton.disabled=false
	queue_caret()
	modal_lease.activate([serial])
func submit(operation: String) -> void:
	if pending or state.is_empty() or not modal_lease.admits(): return
	var value:=state.duplicate(true); value.operation=operation; value.text=edit.text; value.editorSerial=serial
	if not owner_frame.submit_note(value): return
	pending=true; edit.editable=false; buttons.okbutton.disabled=true; buttons.deletebutton.disabled=true; notice.text=""
func caret_changed() -> void:
	if not is_instance_valid(edit) or not is_instance_valid(scroll): return
	var caret: Vector2=edit.get_caret_draw_pos(); var current: float=scroll.scroll_vertical
	if caret.y<current: scroll.scroll_vertical=maxi(0,int(caret.y))
	elif caret.y+edit.get_line_height()>current+scroll.size.y: scroll.scroll_vertical=int(caret.y+edit.get_line_height()-scroll.size.y)
func queue_caret() -> void:
	caret_pending=3; set_process(true); caret_changed()
func _process(_delta: float) -> void:
	if not is_instance_valid(panel) or not panel.visible: set_process(false); return
	caret_changed(); caret_pending-=1
	if caret_pending<=0: set_process(false)
func _input(event: InputEvent) -> void:
	if not is_instance_valid(panel) or not panel.visible or not modal_lease.admits() or not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_ESCAPE: return
	if is_instance_valid(modal_lease.order):cancel();get_viewport().set_input_as_handled();return
	var windows: Array=panel.get_parent().get_children(); windows.reverse()
	for window in windows:
		if window is Draggable and window.visible:
			if window==panel: cancel(); get_viewport().set_input_as_handled()
			return
func reject(message: String) -> void:
	if not layout_ready: return
	pending=false; edit.editable=true; buttons.okbutton.disabled=false; buttons.deletebutton.disabled=false; notice.text=message
func uncertain(message: String) -> void:
	if layout_ready: notice.text=message
func cancel() -> void:
	modal_lease.retire()
	serial+=1; state.clear(); pending=false; caret_pending=0; set_process(false)
	if is_instance_valid(panel): panel.hide()
func close() -> void:
	cancel();modal_lease.close()
	if is_instance_valid(bar): bar.close()
	if is_instance_valid(panel): panel.queue_free()
