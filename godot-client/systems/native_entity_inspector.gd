extends "res://systems/draggable_panel.gd"
const Snapshot=preload("res://systems/native_entity_snapshot.gd")
const VisibilityTrace=preload("res://tools/native_parity/visibility/entity_visibility_trace.gd")
const SceneryTrace=preload("res://tools/native_parity/visibility/terrain_pointer_trace.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
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
var selected_lifetime: Array=[]
var last_export:=""
var scenery_armed:=false
func setup(context: Callable,names: Callable,prefix: String,layout: String="user://native-menu-layout.cfg") -> void:
	context_provider=context; name_provider=names; export_prefix=prefix
	configure("Entity inspector","entity-inspector",Vector2(100,70),layout)
	custom_minimum_size=Vector2(720,440)
	var tools:=HBoxContainer.new(); content.add_child(tools)
	filter=LineEdit.new(); filter.placeholder_text="Search name or object ID"; filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tools.add_child(filter)
	creature_only=CheckBox.new(); creature_only.text="Creatures only"; creature_only.button_pressed=true; creature_only.focus_mode=Control.FOCUS_NONE; tools.add_child(creature_only)
	var refresh:=Button.new(); refresh.text="Refresh"; refresh.focus_mode=Control.FOCUS_NONE; tools.add_child(refresh); refresh.pressed.connect(refresh_entities)
	var scenery:=Button.new();scenery.text="Inspect scenery";scenery.tooltip_text="Click a surface to export its model and Part. Escape cancels. No movement command is sent.";scenery.focus_mode=Control.FOCUS_NONE;tools.add_child(scenery);scenery.pressed.connect(func():scenery_armed=true;hide())
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
func known_sources(scope: Dictionary,world: Node) -> Dictionary:
	if scope.get("known_objects") is Dictionary:return scope.known_objects
	# Legacy/offline callers retain their explicit renderer-only scope. These
	# borrowed references are enumerated only when the inspector is refreshed.
	var result: Dictionary={}
	for id in world.desired:result[id]=world.desired[id].get("object",{})
	return result
func entity_name(source: Dictionary) -> String:
	return str(name_provider.call(source)) if name_provider.is_valid() else str(source.get("id","Entity"))
func open() -> void:
	show(); move_to_front(); refresh_entities()
func reset() -> void:
	scenery_armed=false
	selected_id=-1; selected_world=0; selected_generation=-1; selected_lifetime=[];ids.clear()
	if entities!=null: entities.clear(); detail.text=""; export_button.disabled=true
	hide()
func refresh_entities() -> void:
	var scope:=context(); var world: Node=scope.get("world")
	var previous:=selected_id; var same_scope: bool=is_instance_valid(world) and world.get_instance_id()==selected_world and int(scope.get("generation",-1))==selected_generation
	ids.clear(); entities.clear(); selected_id=-1; export_button.disabled=true; detail.text=""
	if not is_instance_valid(world): status.text="No active world."; return
	selected_world=world.get_instance_id(); selected_generation=int(scope.get("generation",-1))
	var rows: Array=[]; var needle:=filter.text.to_lower();var known:=known_sources(scope,world)
	for id in known:
		var source: Dictionary=known[id]
		if source.has("areaId") and int(source.areaId)!=world.area_id:continue
		if source.get("replicationRemoved",false):continue
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
	var known:=known_sources(scope,world)
	if not known.has(selected_id): return {"error":"Entity left the world or client-known registry. Refresh the list."}
	var source: Dictionary=known[selected_id]
	if Lifetime.token(source)!=selected_lifetime:return {"error":"Entity lifetime changed. Refresh and select it again."}
	var value:=Snapshot.capture(world,selected_id,entity_name(source)) if world.desired.has(selected_id) else {"version":1,"kind":"native-entity-inspection","id":selected_id,"name":entity_name(source),"rendered":false,"admission":"not_in_render_desired","missing_received_fields_stay_unavailable":true}
	value.received_source=source.duplicate(true)
	value.visibility_trace=VisibilityTrace.capture(world,scope.get("registry"),scope.get("camera"),trace_request(world,scope,{"ids":[selected_id]}))
	return value
func trace_request(world: Node,scope: Dictionary,extra: Dictionary={}) -> Dictionary:
	var request:={"post_window":true,"measurement_active":false,"expected_world_instance_id":world.get_instance_id(),"expected_generation":scope.get("generation"),"expected_area_id":VisibilityTrace.property(world,"area_id"),"connection_scope":scope.get("connection")}
	if scope.get("known_objects") is Dictionary:request.known_objects=scope.known_objects
	request.merge(extra,true);return request
func _input(event: InputEvent) -> void:
	if not scenery_armed:return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		scenery_armed=false;show();get_viewport().set_input_as_handled();return
	if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
	scenery_armed=false;get_viewport().set_input_as_handled()
	var scope:=context();var world: Node=scope.get("world");var camera: Camera3D=scope.get("camera")
	show();move_to_front()
	if not is_instance_valid(world) or not is_instance_valid(camera):status.text="No active world/camera.";return
	var start:=camera.project_ray_origin(event.position);var end:=start+camera.project_ray_normal(event.position)*200.0
	var request:=trace_request(world,scope,{"start":[start.x,start.y,start.z],"end":[end.x,end.y,end.z]})
	var value:=SceneryTrace.capture(world,camera,request)
	value.kind="native-scenery-inspection";value.at_unix_ms=int(Time.get_unix_time_from_system()*1000)
	write_export(value,"scenery")
func select_entity(index: int) -> void:
	if index<0 or index>=ids.size(): return
	selected_id=ids[index]
	var scope:=context();var world: Node=scope.get("world")
	selected_lifetime=Lifetime.token(known_sources(scope,world).get(selected_id,{})) if is_instance_valid(world) else []
	var value:=selected_snapshot()
	detail.text=JSON.stringify(value,"  "); export_button.disabled=value.has("error")
func export_selected() -> void:
	var value:=selected_snapshot()
	if value.has("error"): status.text=str(value.error); export_button.disabled=true; return
	write_export(value,"entity-"+str(selected_id))
func write_export(value: Dictionary,suffix: String) -> void:
	if export_prefix.is_empty(): status.text="Export location is unavailable."; return
	var path:="%s.%s-%s.json"%[export_prefix,suffix,Time.get_ticks_usec()]
	if FileAccess.file_exists(path): status.text="Export filename already exists."; return
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: status.text="Could not open entity export: "+error_string(FileAccess.get_open_error()); return
	file.store_string(JSON.stringify(value,"  ")); var error:=file.get_error(); file.close()
	if error!=OK: status.text="Entity export failed: "+error_string(error); return
	last_export=path; detail.text=JSON.stringify(value,"  "); status.text="Exported: "+path.get_file()
	if DisplayServer.get_name()!="headless": DisplayServer.clipboard_set(ProjectSettings.globalize_path(path))
func blocks_pointer(point: Vector2) -> bool:
	return visible and get_global_rect().has_point(point)
