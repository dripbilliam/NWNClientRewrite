extends Node
# Experimental world owner, selected only by --particle-presentation=shared
# or NWN_PARTICLE_PRESENTATION=shared. Unsupported owners keep their existing
# synchronous tick and surface; native owners publish counters without GD rows.
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Effect=preload("res://systems/native_render/particle_stream_effect.gd")
const Fog=preload("res://systems/native_render/particle_stream_fog.gd")
const SceneBatches=preload("res://systems/native_render/particle_scene_batches.gd")
const CameraEffects=preload("res://systems/native_render/camera_effects.gd")
var pooled_lighting:=OS.get_cmdline_user_args().has("--particle-lighting=pooled") or OS.get_environment("NWN_PARTICLE_LIGHTING")=="pooled"
var native_surface_output:=false
var scene_batches: Node
var native: RefCounted
var renderer: RefCounted
var effect: CompositorEffect
var scope_root: Node3D
var camera: Camera3D
var compositor: Compositor
var members: Dictionary={}
var pending_controls: Dictionary={}
var pending_removals: Dictionary={}
var pending_registrations: Dictionary={}
var collision_provider: Callable
var closed:=false
var running:=false
var close_requested:=false
var failure:=""
var last: Dictionary={}
var fast_members:=0
var fallback_reasons: Dictionary={}
var visibility_dirty:=false
var visibility_publications:=0
func _enter_tree() -> void: process_priority=20
func configure(root_node: Node3D) -> bool:
	if native!=null or closed or not ClassDB.class_exists("NwnParticleStreamRender") or RenderingServer.get_current_rendering_method()=="gl_compatibility": return false
	var metrics=root_node.get_meta("native_particle_metrics",null)
	if metrics==null or metrics.native_counters==null: failure="Shared particle world requires native diagnostic counters"; return false
	scope_root=root_node; native_surface_output=root_node.get_meta("native_surface_output",false); native=ClassDB.instantiate("NwnParticlePresentation"); renderer=ClassDB.instantiate("NwnParticleStreamRender")
	# The original draw samples the admitted light list after scene/camera
	# preparation. Retain the existing order for the ordinary renderer.
	if native_surface_output: process_priority=110
	var result: Dictionary=native.call("dispatch",8,{"counters":metrics.native_counters})
	if not result.has("error"): result=renderer.call("dispatch",0,{"presentation":native,"native_surface_output":native_surface_output})
	if result.has("error"): failure=str(result.error); close(); return false
	effect=Effect.new(); effect.configure(renderer); root_node.set_meta("native_particle_stream_group",self)
	if pooled_lighting and not native_surface_output: scene_batches=SceneBatches.new(); add_child(scene_batches)
	collision_provider=root_node.get_meta("native_particle_collision_indices",Callable())
	RenderingServer.frame_pre_draw.connect(refresh_visibility)
	return true
func visibility_changed() -> void: visibility_dirty=true
func refresh_visibility() -> void:
	if closed or running or native==null or not visibility_dirty: return
	assert(OS.get_thread_caller_id()==OS.get_main_thread_id())
	visibility_dirty=false
	var began:=Profile.begin()
	last=native.call("dispatch",11,{})
	if last.has("error"): failure=str(last.error); close(); return
	if scene_batches!=null and not scene_batches.consume(native.call("dispatch",9,{})): failure=scene_batches.failure; close(); return
	var submitted: Dictionary=renderer.call("dispatch",1,{})
	if submitted.has("error"): failure=str(submitted.error); close(); return
	visibility_publications+=1; Profile.finish("particle_visibility_publication",began)
func reason(emitter: Node3D) -> String:
	if emitter.native_owner==null or not emitter.native_pose_bound: return "reference/custom owner"
	if emitter.native_instance_streams: return "instance-stream rollback selected"
	# Chunks retain their private model/rig rendering and exactly-once destroy
	# services; their simulation and sorted pose publication use the shared owner.
	if not native_surface_output and not pooled_lighting and emitter.effective_flags()&8 and str(emitter._state.get("chunkName","")).is_empty(): return "scene lighting"
	if emitter.original_texture!=null:
		var fog_reason:=Fog.unsupported(get_viewport().get_camera_3d())
		if not fog_reason.is_empty(): return fog_reason
	if emitter.collision_indices_provider.is_valid() and emitter.collision_indices_provider!=collision_provider: return "custom collision service"
	if emitter.effective_flags()&4 and (not is_instance_valid(emitter.native_wind_owner) or emitter.native_wind_owner.token==0): return "wind owner unavailable"
	return ""
func register(emitter: Node3D) -> bool:
	if closed or native==null or emitter.retired or not emitter.failure.is_empty() or not scope_root.is_ancestor_of(emitter) or emitter.get_viewport()!=get_viewport(): return false
	var id:=emitter.get_instance_id()
	if members.has(id): return true
	if is_instance_valid(emitter.native_frame_group) or is_instance_valid(emitter.native_stream_group) and emitter.native_stream_group!=self: return false
	if running:
		# Private chunk model publication can add nested emitters while native
		# iteration is in progress. Admit them at the next frame boundary.
		pending_registrations[id]=weakref(emitter); emitter.native_stream_group=self; emitter.set_process(false); return true
	var fallback:=reason(emitter); var fast:=fallback.is_empty()
	var config:={"id":id,"enabled":emitter.particles_enabled}
	if fast:
		config.merge({"owner":emitter.native_owner,"providers":emitter.providers,"source_flags":emitter.source_model_flags,"culling":emitter.frustum_enabled,"draw_enabled":emitter.original_texture!=null,"clip":emitter.static_clip,"clip_length":float(emitter.channels.clips.get(emitter.static_clip,{}).get("length",0.0)),"clock":emitter.clock_provider,"elapsed":emitter.elapsed})
		if is_instance_valid(emitter.chunk_models) and not emitter.chunk_models.ready(): config.ready=Callable(emitter,"shared_chunk_ready")
		if emitter.original_texture!=null: config.merge({"texture":emitter.original_texture,"additive":int(emitter._state.get("blendMode68",0))!=0,"two_sided":bool(emitter._state.get("twoSided",false)),"lighting":(emitter.effective_flags()&8)!=0})
		if is_instance_valid(emitter.native_wind_owner): config.wind_token=emitter.native_wind_owner.token
	else: config.fallback=Callable(emitter,"grouped_fallback_tick")
	var result: Dictionary=native.call("dispatch",0,config)
	if result.has("error"):
		failure=str(result.error)
		if emitter.native_stream_group==self: emitter.native_stream_group=null; emitter.set_process(emitter.particles_enabled)
		return false
	members[id]={"emitter":weakref(emitter),"fast":fast,"reason":fallback}; emitter.native_stream_group=self; emitter.set_process(false)
	if not emitter.visibility_changed.is_connected(visibility_changed): emitter.visibility_changed.connect(visibility_changed)
	if fast:
		fast_members+=1; emitter.native_compact_records=true; emitter.native_typed_frame=true; emitter.surface.retire()
	else: fallback_reasons[fallback]=int(fallback_reasons.get(fallback,0))+1
	if emitter.queued_detonate: control(emitter,{"detonate":true})
	if emitter.collision_flags_pending: control(emitter,{"flags":emitter.effective_flags()})
	return true
func info(id: int) -> Dictionary: return native.call("dispatch",10,{"id":id}) if native!=null and members.has(id) and members[id].fast else {}
func unregister(emitter: Node3D) -> void:
	var id:=emitter.get_instance_id()
	if emitter.visibility_changed.is_connected(visibility_changed): emitter.visibility_changed.disconnect(visibility_changed)
	visibility_dirty=true
	pending_registrations.erase(id)
	if not members.has(id):
		if emitter.native_stream_group==self: emitter.native_stream_group=null; emitter.set_process(emitter.particles_enabled and not emitter.retired and emitter.failure.is_empty())
		return
	var member: Dictionary=members[id]
	if member.fast:
		if not running and pending_controls.has(id): native.call("dispatch",4,pending_controls[id])
		emitter.sync_stream_diagnostics(); fast_members-=1
		emitter.surface.configure(emitter.original_texture,1,int(emitter._state.get("blendMode68",0))!=0,bool(emitter._state.get("twoSided",false)),(emitter.effective_flags()&8)!=0)
	else:
		fallback_reasons[member.reason]=int(fallback_reasons[member.reason])-1
		if int(fallback_reasons[member.reason])==0: fallback_reasons.erase(member.reason)
	if running: pending_removals[id]=true
	elif native!=null: native.call("dispatch",3,{"id":id})
	members.erase(id); pending_controls.erase(id)
	if emitter.native_stream_group==self: emitter.native_stream_group=null
	emitter.set_process(emitter.particles_enabled and not emitter.retired and emitter.failure.is_empty())
func control(emitter: Node3D,patch: Dictionary) -> void:
	var id:=emitter.get_instance_id()
	if closed or native==null or not members.has(id): return
	if patch.has("enabled"): visibility_dirty=true
	var command: Dictionary=patch.duplicate(); command.id=id
	if command.has("flags"): command.patch={"flags":command.flags}; command.erase("flags")
	if running:
		if not pending_controls.has(id): pending_controls[id]={}
		pending_controls[id].merge(command,true)
	else: native.call("dispatch",4,command)
func detach_camera() -> void:
	CameraEffects.remove(camera,effect)
	camera=null
func attach_camera(next: Camera3D) -> void:
	if camera==next: return
	detach_camera(); camera=next
	CameraEffects.install(camera,effect)
func step(delta: float) -> void:
	if closed or native==null: return
	visibility_dirty=false
	for id in pending_removals: native.call("dispatch",3,{"id":int(id)})
	pending_removals.clear()
	var registering: Dictionary=pending_registrations.duplicate(); pending_registrations.clear()
	for reference: WeakRef in registering.values():
		var emitter: Object=reference.get_ref()
		if is_instance_valid(emitter): register(emitter)
	for command in pending_controls.values(): native.call("dispatch",4,command)
	pending_controls.clear()
	var current:=get_viewport().get_camera_3d()
	if current==null: return
	var fog_reason:=Fog.unsupported(current)
	if fast_members>0 and not fog_reason.is_empty(): failure="Shared raster unsupported "+fog_reason+"; established particles restored"; close(); return
	attach_camera(current)
	if native_surface_output: preload("res://systems/native_render/native_surface_state.gd").publish_camera(scope_root,Fog.sample(current,true))
	var input:={"delta":delta,"view":Bounds.native_view(current,false),"profile":Profile.enabled,"fog":Fog.sample(current,native_surface_output,scope_root),"scene_instances":pooled_lighting,"native_surface_output":native_surface_output}
	if native_surface_output:
		var reference: WeakRef=scope_root.get_meta("native_focus_light_owner") if scope_root.has_meta("native_focus_light_owner") else null
		var owner=reference.get_ref() if reference!=null else null
		input.lighting=owner.particle_lighting() if is_instance_valid(owner) else {}
	if collision_provider.is_valid():
		var indices: Array=collision_provider.call()
		if indices.size()==2: input.scene_indices=indices
	running=true; last=native.call("dispatch",1,input); running=false
	if last.has("error"): failure=str(last.error); close(); return
	if scene_batches!=null and not scene_batches.consume(native.call("dispatch",9,{})): failure=scene_batches.failure; close(); return
	var submitted: Dictionary=renderer.call("dispatch",1,{})
	if submitted.has("error"): failure=str(submitted.error); close(); return
	var state: Dictionary=renderer.call("dispatch",2,{})
	if int(state.error)!=0: failure=str(state.failure); close(); return
	if close_requested: close()
func _process(delta: float) -> void:
	var began:=Profile.begin(); step(delta); Profile.finish("callback_particles",began)
func snapshot() -> Dictionary:
	return {"closed":closed,"failure":failure,"members":members.size(),"fast_members":fast_members,"pending_registrations":pending_registrations.size(),"fallback_reasons":fallback_reasons.duplicate(),"native":native.call("dispatch",7,{}) if native!=null else {},"renderer":renderer.call("dispatch",2,{}) if renderer!=null else {},"scene_batches":scene_batches.snapshot() if scene_batches!=null else {}}
func close() -> void:
	if closed: return
	if running: close_requested=true; return
	if RenderingServer.frame_pre_draw.is_connected(refresh_visibility): RenderingServer.frame_pre_draw.disconnect(refresh_visibility)
	for member in members.values().duplicate():
		var emitter: Object=member.emitter.get_ref()
		if is_instance_valid(emitter): unregister(emitter)
	for reference: WeakRef in pending_registrations.values().duplicate():
		var emitter: Object=reference.get_ref()
		if is_instance_valid(emitter): unregister(emitter)
	if native!=null: native.call("dispatch",5,{})
	if scene_batches!=null: scene_batches.close()
	if is_instance_valid(scope_root) and scope_root.get_meta("native_particle_stream_group",null)==self: scope_root.remove_meta("native_particle_stream_group")
	detach_camera()
	if effect!=null: effect.enabled=false; effect.close()
	closed=true; members.clear(); pending_controls.clear(); pending_removals.clear(); pending_registrations.clear(); collision_provider=Callable(); set_process(false)
func _exit_tree() -> void: close()
