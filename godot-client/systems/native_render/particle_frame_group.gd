extends Node
# Experimental main-thread driver; not enabled by default. The native owner
# calls each consumer synchronously, including reference/custom fallbacks.
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
var native: RefCounted
var scope_root: Node3D
var scope_group: StringName
var members: Dictionary={}
var collision_provider: Callable
var order_dirty:=true
var closed:=false
var failure:=""
var last: Dictionary={}
var engine_ordered:=false
func _enter_tree() -> void: process_priority=20
func configure(value: Node3D,ordered_callbacks: bool=false) -> bool:
	if native!=null or closed or not ClassDB.class_exists("NwnParticleFrameGroup"): return false
	if value.has_meta("native_particle_frame_group"): return false
	scope_root=value; scope_group=StringName("native_particle_frame_"+str(get_instance_id())); engine_ordered=ordered_callbacks
	# Node's cached process order can differ from freshly sorted tree groups
	# after move_child(). This mode retains the exact original engine callbacks
	# and only shares frame inputs / native retained emitter preparation.
	if engine_ordered: process_priority=19
	native=ClassDB.instantiate("NwnParticleFrameGroup"); scope_root.set_meta("native_particle_frame_group",self)
	collision_provider=scope_root.get_meta("native_particle_collision_indices",Callable())
	get_tree().tree_changed.connect(mark_order_dirty)
	return true
func mark_order_dirty() -> void: order_dirty=true
func register(emitter: Node3D) -> bool:
	if closed or native==null or not emitter.failure.is_empty() or emitter.retired or not scope_root.is_ancestor_of(emitter): return false
	# Different viewports/priorities need their own frame owner to preserve
	# camera selection and the engine's processing order.
	if emitter.get_viewport()!=get_viewport() or emitter.process_priority!=20: return false
	var id:=emitter.get_instance_id()
	if members.has(id): return true
	if is_instance_valid(emitter.native_frame_group): return false
	var config:={"id":id,"fallback":Callable(emitter,"grouped_fallback_tick"),"enabled":emitter.particles_enabled}
	# Chunk readiness/custom/reference/native-pose rollback stays in the same
	# ordered frame as a synchronous fallback instead of being omitted.
	var fast: bool=emitter.native_owner!=null and emitter.native_pose_bound and str(emitter._state.get("chunkName","")).is_empty() and (not emitter.collision_indices_provider.is_valid() or emitter.collision_indices_provider==collision_provider)
	if fast:
		var input:={"clip":emitter.static_clip,"capacity":emitter.surface.capacity,"source_flags":emitter.source_model_flags,"culling":emitter.frustum_enabled,"draw_enabled":emitter.original_texture!=null}
		if is_instance_valid(emitter.native_wind_owner): input.wind_token=emitter.native_wind_owner.token
		config.merge({"owner":emitter.native_owner,"input":input,"providers":emitter.providers,"receiver":Callable(emitter,"receive_group_frame"),"clock":emitter.clock_provider,"elapsed":emitter.elapsed,"clip_length":float(emitter.channels.clips.get(emitter.static_clip,{}).get("length",0.0))})
	var result: Dictionary=native.call("dispatch",0,config)
	if result.has("error") and fast:
		config={"id":id,"fallback":Callable(emitter,"grouped_fallback_tick"),"enabled":emitter.particles_enabled}; result=native.call("dispatch",0,config); fast=false
	if result.has("error"): failure=str(result.error); return false
	members[id]={"emitter":weakref(emitter),"fast":fast}; emitter.native_frame_group=self; emitter.native_group_identity={"id":id}; emitter.add_to_group(scope_group)
	if not engine_ordered: emitter.set_process(false)
	order_dirty=true
	if emitter.queued_detonate: control(emitter,{"detonate":true})
	if emitter.collision_flags_pending: control(emitter,{"flags":emitter.effective_flags()})
	return true
func unregister(emitter: Node3D) -> void:
	var id:=emitter.get_instance_id()
	if native!=null: native.call("dispatch",1,{"id":id})
	members.erase(id)
	if emitter.is_in_group(scope_group): emitter.remove_from_group(scope_group)
	if emitter.native_frame_group==self: emitter.native_frame_group=null
	emitter.set_process(emitter.particles_enabled and not emitter.retired and emitter.failure.is_empty()); order_dirty=true
func control(emitter: Node3D,patch: Dictionary) -> void:
	if native==null or closed or not members.has(emitter.get_instance_id()): return
	var command: Dictionary=patch.duplicate(); command.id=emitter.get_instance_id(); native.call("dispatch",4,command)
func update_order() -> void:
	if not order_dirty: return
	for id in members.keys():
		var emitter: Object=members[id].emitter.get_ref()
		if not is_instance_valid(emitter): native.call("dispatch",1,{"id":id}); members.erase(id)
	var ids: Array[int]=[]
	for emitter in get_tree().get_nodes_in_group(scope_group):
		if members.has(emitter.get_instance_id()): ids.append(emitter.get_instance_id())
	var result: Dictionary=native.call("dispatch",3,{"ids":ids})
	if result.has("error"): failure=str(result.error)
	order_dirty=false
func step(delta: float) -> void:
	if closed or native==null or not failure.is_empty(): return
	if get_viewport().get_camera_3d()==null:
		if engine_ordered: native.call("dispatch",7,{})
		return
	if not engine_ordered: update_order()
	if not failure.is_empty(): return
	var input:={"delta":delta,"view":Bounds.native_view(get_viewport().get_camera_3d()),"profile":Profile.enabled}
	if collision_provider.is_valid():
		var indices: Array=collision_provider.call()
		if indices.size()==2: input.scene_indices=indices
	last=native.call("dispatch",7 if engine_ordered else 2,input)
	if last.has("error"): failure=str(last.error)
func _process(delta: float) -> void:
	var began:=Profile.begin(); step(delta); Profile.finish("callback_particles",began)
func snapshot() -> Dictionary:
	return {"failure":failure,"members":members.size(),"last":last.duplicate(true),"native":native.call("dispatch",6,{}) if native!=null else {}}
func close() -> void:
	if closed: return
	if is_inside_tree() and get_tree().tree_changed.is_connected(mark_order_dirty): get_tree().tree_changed.disconnect(mark_order_dirty)
	for id in members.keys():
		var emitter: Object=members[id].emitter.get_ref()
		if is_instance_valid(emitter): unregister(emitter)
	if native!=null: native.call("dispatch",5,{})
	if is_instance_valid(scope_root) and scope_root.get_meta("native_particle_frame_group",null)==self: scope_root.remove_meta("native_particle_frame_group")
	closed=true; members.clear(); collision_provider=Callable(); set_process(false)
func _exit_tree() -> void: close()
