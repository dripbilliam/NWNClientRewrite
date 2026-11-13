extends Node
# Sparse native selection presentation: existing skin/base passes receive the
# original colour channel; ordinary Parts use one retained authored-box batch.
const Bounds=preload("res://tools/native_parity/highlighting/native_highlight_bounds_kernel.gd")
const Source=preload("res://systems/native_render/selection_highlight_source.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var bounds
var texture_source
var entries: Dictionary={}
var tab_members: Dictionary={}
var hovered:=-1
var camera: WeakRef
var phase:=0.0
var revision:=0
var closed:=false
var stats:={"registrations":0,"unavailable":0,"channel_writes":0,"channel_failures":0,"frames":0}
func make_bounds():return Bounds.new()
func _init() -> void:
	bounds=make_bounds();add_child(bounds);set_process(false)
func configure(view: Camera3D) -> void:
	camera=weakref(view) if is_instance_valid(view) else null
	set_process(camera!=null)
func configure_assets(assets: Node,catalog,pool: RefCounted) -> bool:
	if closed or texture_source!=null:return false
	texture_source=preload("res://systems/native_render/selection_highlight_texture.gd").new();add_child(texture_source)
	texture_source.texture_prepared.connect(func(texture: Texture2D,sampler: Dictionary):
		if not closed:bounds.configure_texture(texture,sampler,bool(pool.native_surface_output)))
	return texture_source.configure(assets,catalog,pool)
func _owner(id: int) -> Node3D:
	if not entries.has(id):return null
	var entry: Dictionary=entries[id];var value: Variant=entry.owner.get_ref()
	if not value is Node3D or not is_instance_valid(value) or value.get_instance_id()!=entry.owner_id or value.is_queued_for_deletion() or not value.is_inside_tree():return null
	if entry.retired_supported and value.get("retired")==true:return null
	if value.has_meta("native_selection_scope") and value.get_meta("native_selection_scope")!=entry.lifetime:return null
	return value
func register_entity(id: int,row: Dictionary,owner: Node3D) -> bool:
	if closed:return false
	if entries.has(id) and _owner(id)==owner:
		var entry: Dictionary=entries[id]
		var color:=Color.from_string(str(row.get("color","#55ddff")),Color.CYAN)
		if color!=entry.color:
			entry.color=color;revision+=1
			var tint:=Vector3(color.r,color.g,color.b)
			# Reaction/selection colour can change without replacing the Gob.
			# Rewrite only channels this owner already holds; channel3 stays live.
			if entry.tab:_channel(id,2,tint)
			if not closed and entries.has(id) and is_same(entries[id],entry) and entry.hover:_channel(id,1,tint)
		return not closed and entries.has(id) and is_same(entries[id],entry)
	forget(id)
	if not is_instance_valid(owner) or not owner.has_method("set_renderer_vector") or not owner.has_method("renderer_alpha_model_indices"):return false
	var source:=Source.collect(owner)
	if not source.available:stats.unavailable+=1;return false
	var lifetime: Array=owner.get_meta("native_selection_scope") if owner.has_meta("native_selection_scope") else ["physical-owner",id,owner.get_instance_id()]
	var color:=Color.from_string(str(row.get("color","#55ddff")),Color.CYAN)
	entries[id]={"owner":weakref(owner),"owner_id":owner.get_instance_id(),"lifetime":lifetime.duplicate(true),"indices":owner.renderer_alpha_model_indices(),"color":color,"layer":null,"source_missing":source.missing.duplicate(),"retired_supported":source.retired_supported,"tab":false,"hover":false}
	if not bounds.register_entity(id,owner,lifetime,source.parts,color,model_alpha.bind(id),model_color.bind(id)):
		entries.erase(id);stats.unavailable+=1;return false
	if bounds.has_method("bind_draw_provider") and bounds.call("bind_draw_provider",id,model_draw_enabled.bind(id))!=true:
		bounds.forget(id);entries.erase(id);stats.unavailable+=1;return false
	revision+=1;stats.registrations+=1;return true
func _channel(id: int,slot: int,value: Variant) -> void:
	var owner:=_owner(id)
	if owner==null:return
	var entry: Dictionary=entries[id]
	var accepted: bool=owner.set_renderer_vector(slot,value,entry.indices)
	stats.channel_writes+=1
	if not accepted:stats.channel_failures+=1;return
	# Static clones enroll lazily on the first colour command. Retain a weak
	# endpoint afterwards; per-frame alpha reads never enumerate properties.
	if entries.has(id) and is_same(entries[id],entry):
		var layer: Variant=Source.layer(owner)
		entry.layer=weakref(layer) if layer is RefCounted else null
		entry["tab" if slot==2 else "hover"]=value!=null
func _state(id: int,model: int) -> Variant:
	if _owner(id)==null:return null
	var reference: Variant=entries[id].layer
	var layer: Variant=reference.get_ref() if reference is WeakRef else null
	if layer==null or layer.closed or not layer.models.has(model):return null
	return layer.models[model]
func model_alpha(model: int,id: int) -> Variant:
	var state: Variant=_state(id,model)
	return state.alpha if state!=null and not state.closed else null
func model_draw_enabled(model: int,id: int) -> Variant:
	var state: Variant=_state(id,model)
	return state.presentation_draw_enabled if state!=null and not state.closed else null
func model_color(model: int,id: int) -> Variant:
	var state: Variant=_state(id,model)
	return state.selected_vector if state!=null and not state.closed else null
func mark(ids: Array,hover: int=-1,tab_active: bool=true) -> void:
	if closed:return
	var epoch:=revision
	var desired: Dictionary={}
	if tab_active:
		for id in ids:
			if id is int and entries.has(id) and _owner(id)!=null:desired[id]=true
	for id in tab_members.keys():
		if not desired.has(id):_channel(int(id),2,null)
		if closed or revision!=epoch:return
	for id in desired:
		if entries.has(id) and not entries[id].tab:
			var color: Color=entries[id].color;_channel(int(id),2,Vector3(color.r,color.g,color.b))
		if closed or revision!=epoch:return
	tab_members=desired
	var next_hover: int=hover if entries.has(hover) and _owner(hover)!=null else -1
	if hovered!=next_hover:
		if hovered>=0:_channel(hovered,1,null)
		if closed or revision!=epoch:return
		hovered=next_hover
	if hovered>=0 and not entries[hovered].hover:
		var color: Color=entries[hovered].color;_channel(hovered,1,Vector3(color.r,color.g,color.b))
	if closed or revision!=epoch:return
	var selected: Array=tab_members.keys()
	if hovered>=0 and not selected.has(hovered):selected.append(hovered)
	bounds.mark(selected)
func forget(id: int) -> void:
	if not entries.has(id):return
	var entry: Dictionary=entries[id]
	if tab_members.has(id):_channel(id,2,null)
	if not entries.has(id) or not is_same(entries[id],entry):return
	if hovered==id:_channel(id,1,null);hovered=-1
	if not entries.has(id) or not is_same(entries[id],entry):return
	tab_members.erase(id);bounds.forget(id);entries.erase(id);revision+=1
func _process(delta: float) -> void:
	var began:=Timing.begin()
	if Timing.enabled:
		Timing.count("count_selection_entities",0 if closed else bounds.selected.size())
		Timing.count("count_selection_source_parts",0)
		Timing.count("count_selection_source_corners",0)
		Timing.count("count_selection_tick_complete",0)
	_selection_step(delta)
	Timing.finish("callback_selection",began)
func _selection_step(delta: float) -> void:
	if closed or bounds.selected.is_empty():return
	var view: Variant=camera.get_ref() if camera!=null else null
	if not view is Camera3D or not is_instance_valid(view):return
	# This is the existing SceneTree presentation delta, not a new timer or
	# network clock. Native Scene advances its pulse only with highlighted Gobs.
	var defaults: Dictionary=Bounds.AREA_PULSE_DEFAULTS
	var pulse:=Bounds.pulse_step(phase,delta,defaults.amplitude,defaults.frequency,defaults.size)
	if not pulse.available:return
	phase=float(pulse.phase)
	var complete: bool=bounds.tick(view,pulse.size,defaults.intensity);stats.frames+=1
	if Timing.enabled:
		Timing.count("count_selection_tick_complete",1 if complete else 0)
		# Reuse the helper's current completed-fit counters. Failed/idle ticks
		# retain zeros above rather than reporting a previous frame's numbers.
		if complete:
			Timing.count("count_selection_source_parts",int(bounds.stats.get("source_parts",0)))
			Timing.count("count_selection_source_corners",int(bounds.stats.get("source_corners",0)))
func snapshot() -> Dictionary:
	return {"closed":closed,"entries":entries.size(),"phase":phase,"stats":stats.duplicate(),"bounds":bounds.snapshot(),"texture_source":texture_source.snapshot() if texture_source!=null else {"status":"unconfigured"},"scope":"Native source-kind/bounds and private skin colour channels; no full-mesh overlay"}
func close() -> void:
	if closed:return
	# Channel publication can synchronously re-enter close via material signals.
	closed=true;set_process(false)
	for id in entries.keys():forget(int(id))
	if texture_source!=null:texture_source.close()
	bounds.close();camera=null
func _exit_tree() -> void:close()
