extends "res://systems/draggable_panel.gd"
const Snapshot=preload("res://systems/native_entity_snapshot.gd")
var context_provider: Callable
var name_provider: Callable
var export_prefix:=""
var filter: LineEdit
var creature_only: CheckBox
var entities: ItemList
var detail: TextEdit
var status: Label
var export_button: Button
var ids: Array[int]=[]
var selected_id:=-1
var selected_world:=0
var selected_generation:=-1
var last_export:=""
func setup(context: Callable,names: Callable,prefix: String,layout: String="user://native-menu-layout.cfg") -> void:
	context_provider=context; name_provider=names; export_prefix=prefix
	configure("Entity inspector","entity-inspector",Vector2(100,70),layout)
	custom_minimum_size=Vector2(720,440)
	var tools:=HBoxContainer.new(); content.add_child(tools)
	filter=LineEdit.new(); filter.placeholder_text="Search name or object ID"; filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tools.add_child(filter)
	creature_only=CheckBox.new(); creature_only.text="Creatures only"; creature_only.button_pressed=true; creature_only.focus_mode=Control.FOCUS_NONE; tools.add_child(creature_only)
	var refresh:=Button.new(); refresh.text="Refresh"; refresh.focus_mode=Control.FOCUS_NONE; tools.add_child(refresh); refresh.pressed.connect(refresh_entities)
	var split:=HSplitContainer.new(); split.custom_minimum_size=Vector2(700,330); split.size_flags_vertical=Control.SIZE_EXPAND_FILL; content.add_child(split)
	entities=ItemList.new(); entities.custom_minimum_size=Vector2(235,300); entities.size_flags_vertical=Control.SIZE_EXPAND_FILL; entities.focus_mode=Control.FOCUS_NONE; split.add_child(entities)
	detail=TextEdit.new(); detail.editable=false; detail.custom_minimum_size=Vector2(450,300); detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL; split.add_child(detail)
	var footer:=HBoxContainer.new(); content.add_child(footer)
	status=Label.new(); status.text="Open a world, then refresh."; status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size.x=510; status.size_flags_horizontal=Control.SIZE_EXPAND_FILL; footer.add_child(status)
	export_button=Button.new(); export_button.text="Export entity JSON"; export_button.focus_mode=Control.FOCUS_NONE; export_button.disabled=true; footer.add_child(export_button); export_button.pressed.connect(export_selected)
	filter.text_changed.connect(func(_value):refresh_entities()); creature_only.toggled.connect(func(_value):refresh_entities()); entities.item_selected.connect(select_entity)
	hide()
func context() -> Dictionary:
	return context_provider.call() if context_provider.is_valid() else {}
func entity_name(source: Dictionary) -> String:
	return str(name_provider.call(source)) if name_provider.is_valid() else str(source.get("id","Entity"))
func open() -> void:
	show(); move_to_front(); refresh_entities()
func reset() -> void:
	selected_id=-1; selected_world=0; selected_generation=-1; ids.clear()
	if entities!=null: entities.clear(); detail.text=""; export_button.disabled=true
	hide()
func refresh_entities() -> void:
	var scope:=context(); var world: Node=scope.get("world")
	var previous:=selected_id; var same_scope: bool=is_instance_valid(world) and world.get_instance_id()==selected_world and int(scope.get("generation",-1))==selected_generation
	ids.clear(); entities.clear(); selected_id=-1; export_button.disabled=true; detail.text=""
	if not is_instance_valid(world): status.text="No active world."; return
	selected_world=world.get_instance_id(); selected_generation=int(scope.get("generation",-1))
	var rows: Array=[]; var needle:=filter.text.to_lower()
	for id in world.desired:
		var source: Dictionary=world.desired[id].get("object",{})
		if creature_only.button_pressed and int(source.get("objectType",-1))!=5: continue
		var label:=entity_name(source)
		if not needle.is_empty() and not label.to_lower().contains(needle) and not str(id).contains(needle): continue
		rows.append({"id":int(id),"name":label})
	rows.sort_custom(func(a,b): return str(a.name).naturalnocasecmp_to(str(b.name))<0 if a.name!=b.name else a.id<b.id)
	for row in rows: ids.append(int(row.id)); entities.add_item("%s  [%s]"%[row.name,row.id])
	status.text="%d matching entities. Select one; refresh captures current playback."%ids.size()
	if same_scope and ids.has(previous): var index:=ids.find(previous); entities.select(index); select_entity(index)
func selected_snapshot() -> Dictionary:
	var scope:=context(); var world: Node=scope.get("world")
	if not is_instance_valid(world) or world.get_instance_id()!=selected_world or int(scope.get("generation",-1))!=selected_generation: return {"error":"World changed. Refresh and select the entity again."}
	if not world.desired.has(selected_id): return {"error":"Entity left the world. Refresh the list."}
	return Snapshot.capture(world,selected_id,entity_name(world.desired[selected_id].get("object",{})))
func select_entity(index: int) -> void:
	if index<0 or index>=ids.size(): return
	selected_id=ids[index]; var value:=selected_snapshot()
	detail.text=JSON.stringify(value,"  "); export_button.disabled=value.has("error")
func export_selected() -> void:
	var value:=selected_snapshot()
	if value.has("error"): status.text=str(value.error); export_button.disabled=true; return
	if export_prefix.is_empty(): status.text="Export location is unavailable."; return
	var path:="%s.entity-%s-%s.json"%[export_prefix,selected_id,Time.get_ticks_usec()]
	if FileAccess.file_exists(path): status.text="Export filename already exists."; return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: status.text="Could not open entity export: "+error_string(FileAccess.get_open_error()); return
	file.store_string(JSON.stringify(value,"  ")); var error:=file.get_error(); file.close()
	if error!=OK: status.text="Entity export failed: "+error_string(error); return
	last_export=path; detail.text=JSON.stringify(value,"  "); status.text="Exported: "+path.get_file()
	if DisplayServer.get_name()!="headless": DisplayServer.clipboard_set(ProjectSettings.globalize_path(path))
func blocks_pointer(point: Vector2) -> bool:
	return visible and get_global_rect().has_point(point)
