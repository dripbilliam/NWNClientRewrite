extends Node
# Original TGA bytes -> native worker decoder -> Godot hardware cursor. This
# owner never moves/captures the pointer. Tests inject publication instead.
const Policy=preload("res://systems/native_data/mouse_cursor.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Slot=preload("res://systems/inventory_slot.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var publisher: Callable
var ui
var assets
var jobs: Dictionary={}
var images: Dictionary={}
var textures: Dictionary={}
var texture_order: Array=[]
var missing: Dictionary={}
var cursors: Dictionary={}
var desired:=Policy.selection()
var pressed:=false
var focused:=false
var installed:=false
var closed:=false
var stamp:=""
var failures: Array=[]
var publications:=0
func configure(owner,catalog,cache_path: String) -> void:
	ui=owner; assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	jobs[assets.request("cursors",2017,"2da",{"immutable_source":true})]=-1
	# Tiny stock cursor images are prepared independently of the rule-table gate.
	# Custom00..99 remain demand loaded from the active catalog.
	for id in range(1,93): ensure(id)
func ensure(id: int) -> void:
	if closed or images.has(id) or missing.has(id) or jobs.values().has(id): return
	var name:=Policy.resource(id)
	if name.is_empty(): return
	if not assets.catalog.has_resource(name,3): missing[id]=true; return
	var job: int=assets.request(name,3,"raster")
	if job>=0: jobs[job]=id
func prepared(job: int,result: Dictionary) -> void:
	if closed or not jobs.has(job): return
	var id:=int(jobs[job]); jobs.erase(job)
	if not str(result.get("error","")).is_empty():
		failures.append({"id":id,"error":result.error}); missing[id]=true; return
	if id==-1: cursors=result.value; return
	var raster: Dictionary=result.get("value",{})
	var bytes: PackedByteArray=result.get("bytes",PackedByteArray())
	if bytes.size()<18 or bytes[16]!=32 or raster.get("format","")!="rgba8" or raster.get("mips",[]).is_empty() or int(raster.get("width",0))>256 or int(raster.get("height",0))>256:
		missing[id]=true; failures.append({"id":id,"error":"Cursor raster requires bounded RGBA data"}); return
	var image:=Image.create_from_data(int(raster.width),int(raster.height),false,Image.FORMAT_RGBA8,raster.mips[0].data)
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
	if not is_instance_valid(desktop): select(Policy.selection(),pressed); return
	if blocked:
		var fallback: Dictionary=desktop.target_cursor(-1)
		select(fallback if not fallback.is_empty() else Policy.selection(),pressed); return
	var targeting: Dictionary=desktop.target_cursor(int(hit.get("id",-1)),not hit.is_empty())
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
func _input(event: InputEvent) -> void:
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
	var began:=Timing.begin(); cursor_step(); Timing.finish("callback_mouse_cursor",began)
func cursor_step() -> void:
	if closed: return
	var window:=get_window(); var point:=get_viewport().get_mouse_position()
	var allowed:=window.has_focus() and not window.unfocusable and get_viewport().get_visible_rect().has_point(point)
	if not allowed:
		if installed: release()
		focused=false; pressed=false; return
	focused=true
	var hover:=get_viewport().gui_get_hovered_control()
	var value: Dictionary=hovered_selection(hover,get_viewport().gui_is_dragging()) if hover!=null else desired
	var drag: Variant=get_viewport().gui_get_drag_data()
	if drag is Dictionary and str(drag.get("kind", "")) in ["native-inventory-item","native-barter-item"]: value=Policy.selection(92,true)
	# Physical camera capture owns its cursor visibility; never force it visible.
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE: return
	publish(value,pressed,float(window.content_scale_factor))
func publish(value: Dictionary,down: bool,scale: float) -> void:
	if closed: return
	var id:=Policy.variant(int(value.id),bool(value.allow_pressed),down); ensure(id)
	var key:="%s:%s:%s"%[id,scale,value.centered]
	if key==stamp: return
	var present:=id if images.has(id) else 1
	if not images.has(present): return
	var publication_key:=key if present==id else "fallback:"+key
	if stamp==publication_key: return
	var geometry:=Policy.geometry(scale,bool(value.centered) if present==id else false)
	var texture_key:="%s:%s"%[present,geometry.size]
	if not textures.has(texture_key):
		while textures.size()>=128: textures.erase(texture_order.pop_front())
		var image: Image=images[present].duplicate()
		image.resize(geometry.size,geometry.size,Image.INTERPOLATE_NEAREST)
		textures[texture_key]=ImageTexture.create_from_image(image)
	texture_order.erase(texture_key); texture_order.append(texture_key)
	# Missing/in-flight images use the native arrow without caching that fallback
	# as a successful desired publication. Worker completion can then replace it.
	var packet:={"id":present,"requested_id":id,"name":Policy.resource(present),"hotspot":Vector2(geometry.hotspot),"size":geometry.size,"texture":textures[texture_key]}
	if publisher.is_valid(): publisher.call(packet)
	elif DisplayServer.get_name()!="headless":
		for shape in [Input.CURSOR_ARROW,Input.CURSOR_POINTING_HAND,Input.CURSOR_HELP]: Input.set_custom_mouse_cursor(packet.texture,shape,packet.hotspot)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	installed=true; publications+=1; stamp=publication_key
func release() -> void:
	if installed:
		if publisher.is_valid(): publisher.call({"reset":true})
		elif DisplayServer.get_name()!="headless":
			for shape in [Input.CURSOR_ARROW,Input.CURSOR_POINTING_HAND,Input.CURSOR_HELP]: Input.set_custom_mouse_cursor(null,shape)
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	installed=false; stamp=""
func snapshot() -> Dictionary:
	return {"native_only":true,"prepared":images.size(),"pending":jobs.size(),"missing":missing.keys(),"failures":failures.duplicate(),"publications":publications,"desired":desired.duplicate(),"focused":focused,"full_cursor_parity":false}
func close() -> void:
	if closed: return
	closed=true; release()
	if is_instance_valid(assets): assets.close()
	jobs.clear(); images.clear(); textures.clear(); texture_order.clear(); ui=null
func _exit_tree() -> void: close()
