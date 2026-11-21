extends Node
signal target_preview_changed(snapshot: Dictionary)
# Original TGA bytes -> native worker decoder -> Godot hardware cursor. This
# owner never moves/captures the pointer. Tests inject publication instead.
const Policy=preload("res://systems/native_data/mouse_cursor.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const S3TC=preload("res://systems/native_data/s3tc_decode.gd")
const Slot=preload("res://systems/inventory_slot.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const TargetPreview=preload("res://systems/native_render/native_target_preview_shader.gd")
var publisher: Callable
# Isolated test seam. Production leaves this empty and uses Input directly.
var hardware_publisher: Callable
var cursor_images: Dictionary={}
var ui
var assets
var jobs: Dictionary={}
var images: Dictionary={}
var textures: Dictionary={}
var texture_order: Array=[]
var missing: Dictionary={}
var cursors: Dictionary={}
var names: Dictionary={}
var table_ready:=false
var desired:=Policy.selection()
var pressed:=false
var focused:=false
var world_visible:=false
var installed:=false
var closed:=false
var stamp:=""
var failures: Array=[]
var publications:=0
var target_preview_state: Dictionary={"enabled":false}
func _ready() -> void:
	target_preview_changed.connect(TargetPreview.publish)
	TargetPreview.publish(target_preview_snapshot())
func target_preview_snapshot() -> Dictionary: return target_preview_state.duplicate(true)
func set_target_preview_state(value: Dictionary) -> void:
	if target_preview_state==value:return
	target_preview_state=value.duplicate(true); target_preview_changed.emit(target_preview_snapshot())
func clear_target_preview() -> void: set_target_preview_state({"enabled":false})
func target_preview_scope_valid() -> bool:
	if not is_instance_valid(ui) or not is_instance_valid(ui.desktop): return false
	var desktop=ui.desktop
	return not desktop.target.is_empty() and desktop.generation==int(target_preview_state.get("generation",-1)) and desktop.area_id==int(target_preview_state.get("areaId",-1)) and desktop.actor_id==int(target_preview_state.get("actorId",-1)) and int(desktop.target.get("version",-1))==int(target_preview_state.get("targetVersion",-2)) and desktop.target_preview_descriptor()==target_preview_state.get("preview",{})
func observe_target_preview(hit: Dictionary,blocked: bool,cursor: Dictionary) -> void:
	if blocked or hit.is_empty() or not cursor.get("valid",false) or not is_instance_valid(ui) or not is_instance_valid(ui.desktop): clear_target_preview(); return
	var desktop=ui.desktop
	var preview: Dictionary=desktop.target_preview_descriptor()
	var actor: Dictionary=desktop.objects.get(desktop.actor_id,{})
	var player: Variant=actor.get("replicated",{}).get("position")
	var point: Variant=hit.get("position")
	if preview.is_empty() or not player is Array or player.size()!=3 or not point is Vector3 or not point.is_finite(): clear_target_preview(); return
	for coordinate in player:
		if not coordinate is int and not coordinate is float or not is_finite(float(coordinate)): clear_target_preview(); return
	var id:=int(hit.get("id",-1))
	var type:=int(desktop.objects.get(id,{}).get("objectType",2))
	set_target_preview_state({"enabled":true,"preview":preview.duplicate(true),"point":[point.x,-point.z,point.y],"player":player.duplicate(),"type":type,"generation":desktop.generation,"areaId":desktop.area_id,"actorId":desktop.actor_id,"targetVersion":int(desktop.target.get("version",-1))})
func configure(owner,catalog,cache_path: String) -> void:
	ui=owner; assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	var table_job: int=assets.request("cursors",2017,"2da",{"immutable_source":true})
	if table_job>=0:jobs[table_job]=-1
	else:table_ready=true;ensure(int(desired.id))
func valid_resref(value: String) -> bool:
	if value.length()<1 or value.length()>32:return false
	for index in value.length():
		var c:=value.unicode_at(index)
		if not (c>=48 and c<=57 or c>=65 and c<=90 or c>=97 and c<=122 or c==95):return false
	return true
func resource_name(id: int) -> String:
	return str(names.get(id,Policy.resource(id)))
func cursor_failure(id: int,reason: String) -> void:
	failures.append({"id":id,"error":reason})
	if is_instance_valid(ui) and is_instance_valid(ui.text):
		ui.text.diagnostics.append({"code":"cursor.asset-failed","reason":reason,"id":id})
func ensure(id: int) -> void:
	if closed or not table_ready or images.has(id) or missing.has(id) or jobs.values().has(id): return
	var name:=resource_name(id)
	if name.is_empty(): return
	var selected: Dictionary=assets.catalog.raster_location(name)
	var kind:=int(selected.get("type",-1))
	if kind not in [3,2033,2073]:
		missing[id]=true
		var reason:=str(selected.get("error",""))
		cursor_failure(id,reason if not reason.is_empty() else "Native cursor image is unavailable")
		return
	var job: int=assets.request(name,kind,"raster")
	if job>=0: jobs[job]=id
func prepared(job: int,result: Dictionary) -> void:
	if closed or not jobs.has(job): return
	var id:=int(jobs[job]); jobs.erase(job)
	if id==-1:
		if str(result.get("error","")).is_empty():
			cursors=result.value
			for row in cursors.get("orderedRows",[]):
				var raw:=str(row.get("CursorID",""));var name:=str(row.get("ResRef",""))
				if raw.is_valid_float() and valid_resref(name):
					var cursor_id:=float(raw)
					if is_finite(cursor_id) and cursor_id==floorf(cursor_id):names[int(cursor_id)]=name.to_lower()
		table_ready=true;ensure(int(desired.id));return
	if not str(result.get("error","")).is_empty():
		cursor_failure(id,str(result.error)); missing[id]=true; return
	var raster: Dictionary=result.get("value",{})
	var width:=int(raster.get("width",0));var height:=int(raster.get("height",0));var mips: Array=raster.get("mips",[])
	if width<1 or height<1 or width>128 or height>128 or mips.is_empty():
		missing[id]=true;cursor_failure(id,"Native cursor image exceeds cursor limits");return
	var pixels: PackedByteArray=mips[0].get("data",PackedByteArray())
	var format:=str(raster.get("format",""))
	if format in ["dxt1_rgb","dxt1_rgba","dxt3","dxt5"]:pixels=S3TC.decode(pixels,width,height,format)
	elif format!="rgba8":pixels=PackedByteArray()
	if pixels.size()!=width*height*4:
		missing[id]=true;cursor_failure(id,"Cursor raster requires RGBA pixels");return
	var image:=Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,pixels)
	# Original hardware cursor14083b3e0 reverses CResTGA rows before SDL upload.
	image.flip_y(); images[id]=image
	if id==Policy.variant(int(desired.id),bool(desired.allow_pressed),pressed): stamp=""
func select(value: Dictionary,down: bool=false) -> void:
	desired=value; pressed=down
	ensure(Policy.variant(int(desired.id),bool(desired.allow_pressed),pressed))
func world_pointer(hit: Dictionary,blocked: bool) -> void:
	if closed: return
	var desktop=ui.desktop
	# GUI hover is resolved separately so slots win over the generic menu arrow.
	if not is_instance_valid(desktop): world_visible=false;clear_target_preview(); return
	if blocked:
		world_visible=false
		clear_target_preview()
		return
	world_visible=true
	var targeting: Dictionary=desktop.target_cursor(int(hit.get("id",-1)),not hit.is_empty())
	observe_target_preview(hit,false,targeting)
	if not targeting.is_empty(): select(targeting,pressed); return
	var player_ids: Array=[]
	for entry in desktop.state.get("players",[]):
		var player: Variant=entry[1] if entry is Array and entry.size()>1 else entry
		if player is Dictionary: player_ids.append(int(player.get("objectId",player.get("character",{}).get("id",-1))))
	select(Policy.world(hit,desktop.objects,desktop.actor_id,cursors,player_ids),pressed)
func hovered_selection(control: Control,dragging: bool) -> Dictionary:
	while is_instance_valid(control):
		if control is Slot and control.current() and control.row.has("entryId"):
			if is_instance_valid(ui) and is_instance_valid(ui.desktop):
				var targeting: Dictionary=ui.desktop.target_cursor(int(control.row.get("itemId",control.row.entryId)))
				if not targeting.is_empty(): return targeting
			return Policy.selection(92 if dragging else 91,true)
		control=control.get_parent() as Control
	if is_instance_valid(ui) and is_instance_valid(ui.desktop):
		var fallback: Dictionary=ui.desktop.target_cursor(-1)
		if not fallback.is_empty(): return fallback
	return Policy.selection()
func hovered_slot(control: Control) -> bool:
	while is_instance_valid(control):
		if control is Slot and control.current() and control.row.has("entryId"):return true
		control=control.get_parent() as Control
	return false
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var down: bool=(event.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0
		if down!=pressed:pressed=down;stamp=""
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: pressed=event.pressed; stamp=""
	if closed or not event is InputEventMouseButton or not event.pressed or not is_instance_valid(ui) or not is_instance_valid(ui.desktop): return
	if event.button_index==MOUSE_BUTTON_RIGHT and not ui.desktop.target.is_empty():
		ui.desktop.cancel_target(); get_viewport().set_input_as_handled()
	elif event.button_index==MOUSE_BUTTON_LEFT and target_slot(get_viewport().gui_get_hovered_control()): get_viewport().set_input_as_handled()
func target_slot(control: Control) -> bool:
	if not is_instance_valid(ui) or not is_instance_valid(ui.desktop) or ui.desktop.target.is_empty(): return false
	while is_instance_valid(control):
		if control is Slot and control.current() and control.row.has("entryId"):
			var id:=int(control.row.get("itemId",control.row.entryId)); var targeting: Dictionary=ui.desktop.target_cursor(id)
			if targeting.get("valid",false): ui.desktop.cast_target(id,Vector3.ZERO)
			return true
		control=control.get_parent() as Control
	return false
func _process(_delta: float) -> void:
	var began:=Timing.begin(); cursor_step(); TargetPreview.tick(Time.get_ticks_msec()); Timing.finish("callback_mouse_cursor",began)
func cursor_step() -> void:
	if closed: return
	if target_preview_state.get("enabled",false) and not target_preview_scope_valid(): clear_target_preview()
	var window:=get_window(); var point:=get_viewport().get_mouse_position()
	var allowed:=window.has_focus() and not window.unfocusable and get_viewport().get_visible_rect().has_point(point)
	if not allowed:
		clear_target_preview()
		if installed: release()
		focused=false; pressed=false; return
	focused=true
	var hover:=get_viewport().gui_get_hovered_control()
	var drag: Variant=get_viewport().gui_get_drag_data()
	var item_drag:=drag is Dictionary and str(drag.get("kind", "")) in ["native-inventory-item","native-barter-item"]
	if not world_visible and not hovered_slot(hover) and not item_drag:
		if installed:release()
		return
	var value: Dictionary=hovered_selection(hover,get_viewport().gui_is_dragging()) if hover!=null else desired
	if item_drag: value=Policy.selection(92,true)
	# Physical camera capture owns its cursor visibility; never force it visible.
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE: clear_target_preview(); return
	publish(value,pressed,float(window.content_scale_factor))
func publish(value: Dictionary,down: bool,scale: float) -> void:
	if closed: return
	var id:=Policy.variant(int(value.id),bool(value.allow_pressed),down); ensure(id)
	var key:="%s:%s:%s"%[id,scale,value.centered]
	if key==stamp or "fallback:"+key==stamp and not images.has(id): return
	if not images.has(id):
		publish_fallback(id)
		stamp="fallback:"+key
		return
	var texture_key:=str(id)
	if not cursor_images.has(texture_key):
		while cursor_images.size()>=128:
			var retired_key: Variant=texture_order.pop_front();cursor_images.erase(retired_key);textures.erase(retired_key)
		cursor_images[texture_key]=images[id].duplicate()
	texture_order.erase(texture_key); texture_order.append(texture_key)
	# Physical cursor publication keeps CPU pixels on CPU. The legacy injected
	# publisher owns the only TextureRect consumer and receives its texture lazily.
	var packet:={"id":id,"requested_id":id,"name":resource_name(id),"hotspot":Vector2.ZERO,"size":maxi(cursor_images[texture_key].get_width(),cursor_images[texture_key].get_height()),"width":cursor_images[texture_key].get_width(),"height":cursor_images[texture_key].get_height(),"image":cursor_images[texture_key]}
	if publisher.is_valid():
		if not textures.has(texture_key):textures[texture_key]=ImageTexture.create_from_image(cursor_images[texture_key])
		packet.texture=textures[texture_key];publisher.call(packet)
	else:publish_hardware(packet.image,packet.hotspot)
	installed=true; publications+=1; stamp=key
func publish_fallback(id: int) -> void:
	var shape:=Input.CURSOR_CROSS if id in [29,31] else (Input.CURSOR_ARROW if id==1 else Input.CURSOR_POINTING_HAND)
	if publisher.is_valid():publisher.call({"reset":true,"fallback":shape,"requested_id":id})
	elif DisplayServer.get_name()!="headless":
		publish_hardware(null,Vector2.ZERO)
		Input.set_default_cursor_shape(shape)
	installed=false
func publish_hardware(image: Image,hotspot: Vector2) -> void:
	for shape in [Input.CURSOR_ARROW,Input.CURSOR_POINTING_HAND,Input.CURSOR_HELP]:
		if hardware_publisher.is_valid():hardware_publisher.call(image,shape,hotspot)
		elif DisplayServer.get_name()!="headless":Input.set_custom_mouse_cursor(image,shape,hotspot)
	if not hardware_publisher.is_valid() and DisplayServer.get_name()!="headless":Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func release() -> void:
	clear_target_preview()
	TargetPreview.reset()
	if installed:
		if publisher.is_valid(): publisher.call({"reset":true})
		else:publish_hardware(null,Vector2.ZERO)
	installed=false; stamp=""
func snapshot() -> Dictionary:
	var id:=Policy.variant(int(desired.id),bool(desired.allow_pressed),pressed)
	return {"native_only":true,"prepared":images.size(),"pending":jobs.size(),"missing":missing.keys(),"failures":failures.duplicate(),"publications":publications,"desired":desired.duplicate(),"focused":focused,"cursor":{"id":id,"resource":resource_name(id) if images.has(id) else null,"loaded":images.has(id)},"targetPreview":target_preview_snapshot(),"full_cursor_parity":false}
func close() -> void:
	if closed: return
	closed=true; release()
	if is_instance_valid(assets): assets.close()
	jobs.clear(); images.clear(); textures.clear(); cursor_images.clear(); texture_order.clear(); ui=null; hardware_publisher=Callable()
func _exit_tree() -> void: close()
