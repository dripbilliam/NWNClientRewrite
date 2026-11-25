extends Node
# World owner for shared particle presentation. CX requires a native owner
# for every emitter in its world.
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Effect=preload("res://systems/native_render/particle_stream_effect.gd")
const Fog=preload("res://systems/native_render/particle_stream_fog.gd")
const SceneBatches=preload("res://systems/native_render/particle_scene_batches.gd")
const CameraEffects=preload("res://systems/native_render/camera_effects.gd")
const DirectionalDepth=preload("res://systems/native_render/cx_directional_depth.gd")
var pooled_lighting:=OS.get_cmdline_user_args().has("--particle-lighting=pooled") or OS.get_environment("NWN_PARTICLE_LIGHTING")=="pooled"
var geometry_worker:=OS.get_cmdline_user_args().has("--particle-geometry-worker=on")
var animation_snapshot:=OS.get_cmdline_user_args().has("--particle-animation-snapshot=on")
var native_surface_output:=false
var cx_records:=false
var exclusive: bool:
	get: return cx_records or geometry_worker
var scene_batches: Node
var native: RefCounted
var renderer: RefCounted
var effect: CompositorEffect
var scope_root: Node3D
var camera: Camera3D
var compositor: Compositor
var particle_visibility: WeakRef
var weather_cover: Node
var shadows_enabled:=true
var sun_depth: Node
var sun_update_pending:=false
var sun_focus:=Vector3.ZERO
var sun_strength:=0.0
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
func suppressed_fallback_tick(_delta: float) -> void: pass
var visibility_dirty:=false
var visibility_publications:=0
func _enter_tree() -> void: process_priority=20
func configure(root_node: Node3D, use_cx_records: bool=false) -> bool:
	cx_records=use_cx_records
	if native!=null or closed or not ClassDB.class_exists("NwnParticleStreamRender") or RenderingServer.get_current_rendering_method()=="gl_compatibility":
		failure="Shared particles require the native renderer and RenderingDevice"; return false
	var metrics=root_node.get_meta("native_particle_metrics",null)
	if metrics==null or metrics.native_counters==null: failure="Shared particle world requires native diagnostic counters"; return false
	scope_root=root_node; native_surface_output=root_node.get_meta("native_surface_output",false); native=ClassDB.instantiate("NwnParticlePresentation"); renderer=ClassDB.instantiate("NwnParticleStreamRender")
	# The original draw samples the admitted light list after scene/camera
	# preparation. Retain the existing order for the ordinary renderer.
	if native_surface_output: process_priority=110
	var result: Dictionary=native.call("dispatch",8,{"counters":metrics.native_counters})
	if not result.has("error"): result=renderer.call("dispatch",0,{"presentation":native,"native_surface_output":native_surface_output,"cx_records":cx_records})
	if result.has("error"): failure=str(result.error); close(); return false
	var coarse_enabled: bool=OS.get_cmdline_user_args().has("--particle-coarse-timing")
	var sparse_enabled: bool=coarse_enabled or OS.get_cmdline_user_args().has("--particle-sparse-timing")
	# CX remembers static clocks at registration. Dynamic clocks still validate live.
	var setup_enabled: bool=cx_records or OS.get_cmdline_user_args().has("--particle-setup-boundary=bound")
	if sparse_enabled or setup_enabled:
		var sampled: Dictionary=native.call("dispatch",15,{"enabled":sparse_enabled,"stride":120,"min_members":1800,"coarse_phases":coarse_enabled,"setup_boundary":setup_enabled,"reset":true})
		if sampled.has("error"):failure=str(sampled.error);close();return false
	effect=Effect.new(); effect.configure(renderer,cx_records); root_node.set_meta("native_particle_stream_group",self)
	if cx_records:
		var ancestor: Node=root_node
		while ancestor!=null:
			if ancestor.has_meta("native_particle_visibility"):
				var visibility=ancestor.get_meta("native_particle_visibility")
				particle_visibility=weakref(visibility)
				visibility.shadows_changed.connect(set_shadows_enabled)
				set_shadows_enabled(visibility.shadows_enabled)
				break
			ancestor=ancestor.get_parent()
	if pooled_lighting and not native_surface_output: scene_batches=SceneBatches.new(); add_child(scene_batches)
	collision_provider=root_node.get_meta("native_particle_collision_indices",Callable())
	RenderingServer.frame_pre_draw.connect(refresh_visibility)
	if cx_records: RenderingServer.frame_pre_draw.connect(_flush_sun_update)
	return true
func visibility_changed() -> void: visibility_dirty=true
func scene_status(emitter: Node3D) -> int:
	if not emitter.is_inside_tree(): return 0
	return int(emitter.is_visible_in_tree()) | (int(emitter.can_process())<<1)
func update_scene_status(emitter: Node3D) -> void:
	if closed or not cx_records or native==null: return
	var id:=emitter.get_instance_id()
	if members.has(id): native.update_scene_status(id,scene_status(emitter))
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
		var fog_reason:=Fog.unsupported(get_viewport().get_camera_3d(),cx_records)
		if not fog_reason.is_empty(): return fog_reason
	if not cx_records and emitter.collision_indices_provider.is_valid() and emitter.collision_indices_provider!=collision_provider: return "custom collision service"
	if emitter.effective_flags()&4 and str(emitter.original_properties.get("update",""))!="Lightning" and (not is_instance_valid(emitter.native_wind_owner) or emitter.native_wind_owner.token==0):
		var wind: Variant=emitter.services.get("wind")
		if not cx_records or not wind is Callable or not wind.is_valid(): return "wind owner unavailable"
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
	if cx_records and not fast:
		emitter.reject_cx_presentation(fallback)
		return false
	var config:={"id":id,"enabled":emitter.particles_enabled}
	if fast:
		config.childless_chunk_admission=OS.get_cmdline_user_args().has("--particle-chunk-admission=childless")
		config.merge({"owner":emitter.native_owner,"providers":emitter.providers,"source_flags":emitter.source_model_flags,"culling":emitter.frustum_enabled,"draw_enabled":emitter.original_texture!=null,"clip":emitter.static_clip,"clip_length":float(emitter.channels.clips.get(emitter.static_clip,{}).get("length",0.0)),"clock":emitter.clock_provider,"elapsed":emitter.elapsed})
		if emitter.cx_target_motion: config.target=emitter.cx_target_id
		if cx_records:
			config.scene_status=scene_status(emitter)
			var wind: Variant=emitter.services.get("wind")
			config.wind_service=wind is Callable and wind.is_valid()
			config.use_world_collision=emitter.collision_indices_provider==collision_provider and emitter.services.get("collide")==scope_root.get_meta("native_particle_collision",Callable())
		if is_instance_valid(emitter.chunk_models) and not emitter.chunk_models.ready(): config.ready=Callable(emitter,"shared_chunk_ready")
		if emitter.original_texture!=null:
			var blend:=int(emitter._state.get("blendMode68",0))
			config.merge({"texture":emitter.original_texture,"additive":blend!=0 and (not cx_records or blend!=1),"punch_through":cx_records and blend==1,"two_sided":bool(emitter._state.get("twoSided",false)),"lighting":(emitter.effective_flags()&8)!=0})
		if is_instance_valid(emitter.native_wind_owner): config.wind_token=emitter.native_wind_owner.token
	else: config.fallback=Callable(self,"suppressed_fallback_tick") if geometry_worker else Callable(emitter,"grouped_fallback_tick")
	var result: Dictionary=native.call("dispatch",0,config)
	if result.has("error"):
		failure=str(result.error)
		if emitter.native_stream_group==self: emitter.native_stream_group=null; emitter.set_process(emitter.particles_enabled and not exclusive)
		if cx_records: emitter.reject_cx_presentation(failure)
		elif geometry_worker and is_instance_valid(emitter.surface): emitter.surface.retire()
		return false
	members[id]={"emitter":weakref(emitter),"fast":fast,"reason":fallback}; emitter.native_stream_group=self; emitter.set_process(false)
	if not emitter.visibility_changed.is_connected(visibility_changed): emitter.visibility_changed.connect(visibility_changed)
	if fast:
		fast_members+=1; emitter.native_compact_records=true; emitter.native_typed_frame=true; emitter.surface.retire()
	else:
		fallback_reasons[fallback]=int(fallback_reasons.get(fallback,0))+1
		if geometry_worker and is_instance_valid(emitter.surface): emitter.surface.retire()
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
		if emitter.native_stream_group==self: emitter.native_stream_group=null; emitter.set_process(emitter.particles_enabled and not exclusive and not emitter.retired and emitter.failure.is_empty())
		return
	var member: Dictionary=members[id]
	if member.fast:
		if not running and pending_controls.has(id): native.call("dispatch",4,pending_controls[id])
		emitter.sync_stream_diagnostics(); fast_members-=1
		if not exclusive: emitter.surface.configure(emitter.original_texture,1,int(emitter._state.get("blendMode68",0))!=0,bool(emitter._state.get("twoSided",false)),(emitter.effective_flags()&8)!=0)
		elif is_instance_valid(emitter.surface): emitter.surface.retire()
	else:
		fallback_reasons[member.reason]=int(fallback_reasons[member.reason])-1
		if int(fallback_reasons[member.reason])==0: fallback_reasons.erase(member.reason)
		if geometry_worker and is_instance_valid(emitter.surface): emitter.surface.retire()
	if running:
		if cx_records: native.update_scene_status(id,0)
		pending_removals[id]=true
	elif native!=null: native.call("dispatch",3,{"id":id})
	members.erase(id); pending_controls.erase(id)
	if emitter.native_stream_group==self: emitter.native_stream_group=null
	emitter.set_process(emitter.particles_enabled and not exclusive and not emitter.retired and emitter.failure.is_empty())
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
static func frame_fog(current: Camera3D,owner: Node,native_output: bool) -> Array:
	if not native_output:return Fog.sample(current,false,owner)
	var state=preload("res://systems/native_render/native_surface_state.gd")
	# An area-owned packet is already authoritative. The camera fallback sample
	# would be discarded by publish_camera, so leave that Environment unread.
	if not state.authoritative(owner):state.publish_camera(owner,Fog.sample(current,true))
	return Fog.sample(current,true,owner)
func step(delta: float) -> void:
	if closed or native==null: return
	var phase:=Profile.begin()
	visibility_dirty=false
	for id in pending_removals: native.call("dispatch",3,{"id":int(id)})
	pending_removals.clear()
	# Nested emitters arrive here on the following frame. Most frames have no
	# registrations, so avoid copying an empty Dictionary and its values Array.
	if not pending_registrations.is_empty():
		var registering: Dictionary=pending_registrations.duplicate(); pending_registrations.clear()
		for reference: WeakRef in registering.values():
			var emitter: Object=reference.get_ref()
			if is_instance_valid(emitter): register(emitter)
	if not pending_controls.is_empty():
		for command in pending_controls.values(): native.call("dispatch",4,command)
		pending_controls.clear()
	Profile.finish("particle_frame_queues_ms",phase)
	phase=Profile.begin()
	var current:=get_viewport().get_camera_3d()
	if current==null: Profile.finish("particle_frame_inputs_ms",phase); return
	var fog_reason:=Fog.unsupported(current,cx_records)
	if fast_members>0 and not fog_reason.is_empty():
		Profile.finish("particle_frame_inputs_ms",phase)
		failure=("CX particle raster cannot composite " if cx_records else "Shared raster unsupported ")+fog_reason
		close()
		return
	attach_camera(current)
	var input:={"delta":delta,"view":Bounds.native_view(current,false),"profile":Profile.enabled,"fog":frame_fog(current,scope_root,native_surface_output),"scene_instances":pooled_lighting,"native_surface_output":native_surface_output}
	if geometry_worker: input.geometry_worker=true
	# This dictionary is local to this synchronous dispatch; callbacks cannot
	# obtain it through the group while the native frame is running.
	if cx_records or animation_snapshot: input.animation_snapshot=true
	Profile.finish("particle_frame_inputs_ms",phase)
	var sun: DirectionalLight3D
	if native_surface_output:
		phase=Profile.begin()
		var reference: WeakRef=scope_root.get_meta("native_focus_light_owner") if scope_root.has_meta("native_focus_light_owner") else null
		var owner=reference.get_ref() if reference!=null else null
		if cx_records:
			if is_instance_valid(owner):
				input.cx_lighting=owner.cx_particle_lighting()
				if shadows_enabled: sun=owner.cx_particle_sun()
			var cx_fog: Array=preload("res://systems/native_render/native_surface_state.gd").cx_packet(scope_root)
			if not cx_fog.is_empty(): input.cx_fog=cx_fog
		else:
			input.lighting=owner.particle_lighting() if is_instance_valid(owner) else {}
		Profile.finish("particle_frame_lighting_dto_ms",phase)
	if collision_provider.is_valid():
		phase=Profile.begin()
		var indices: Array=collision_provider.call()
		if indices.size()==2: input.scene_indices=indices
		Profile.finish("particle_frame_collision_indices_ms",phase)
	phase=Profile.begin()
	running=true; last=native.call("dispatch",1,input); running=false
	# Native presentation includes controls/pose, simulation, geometry and packet
	# construction. This span does not claim an exclusive simulation CPU cost.
	Profile.finish("particle_frame_native_presentation_ms",phase)
	if last.has("error"): failure=str(last.error); close(); return
	if cx_records and shadows_enabled:
		phase=Profile.begin()
		_update_sun(current,sun)
		Profile.finish("particle_cx_shadow_ms",phase)
	if Profile.enabled:
		for name in last.get("phases",{}): Profile.record(str(name),float(last.phases[name]))
		Profile.count("count_particle_early_culled",int(last.get("early_culled",0)))
	if scene_batches!=null:
		phase=Profile.begin()
		var consumed: bool=scene_batches.consume(native.call("dispatch",9,{}))
		Profile.finish("particle_frame_scene_publication_ms",phase)
		if not consumed: failure=scene_batches.failure; close(); return
	phase=Profile.begin()
	var submitted: Dictionary=renderer.call("dispatch",1,{})
	Profile.finish("particle_frame_renderer_submit_ms",phase)
	if submitted.has("error"): failure=str(submitted.error); close(); return
	phase=Profile.begin()
	var state: Dictionary=renderer.call("dispatch",2,{})
	Profile.finish("particle_frame_renderer_status_ms",phase)
	if int(state.error)!=0: failure=str(state.failure); close(); return
	if close_requested: close()
func _process(delta: float) -> void:
	var began:=Profile.begin(); step(delta); Profile.finish("callback_particles",began)
func set_shadows_enabled(value: bool) -> void:
	if closed or value==shadows_enabled: return
	shadows_enabled=value
	effect.set_shadows_enabled(value)
	if value: return
	sun_update_pending=false
	if is_instance_valid(sun_depth):
		for viewport in sun_depth.viewports:
			viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		for viewport in sun_depth.moving_views:
			viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		sun_depth.queue_free()
		sun_depth=null
func _flush_sun_update() -> void:
	if not sun_update_pending or closed or not is_instance_valid(sun_depth): return
	sun_update_pending=false
	# SceneTree has flushed world transforms by frame_pre_draw. Drain their
	# notifications without moving fit selection or initial publication.
	var phase:=Profile.begin()
	if sun_depth.flush_observed_movers():
		effect.set_sun_shadow(sun_depth.static_fits(),sun_depth.moving_fits(),sun_focus,sun_depth.radii,sun_strength)
	Profile.finish("particle_cx_shadow_late_ms",phase)
func _update_sun(view: Camera3D,sun: DirectionalLight3D) -> void:
	sun_update_pending=false
	var fits: Array[CompositorEffect]=[]
	if last.get("cx_lit_draw",false) and is_instance_valid(sun) and sun.shadow_enabled and sun.shadow_opacity>0.0 and sun.light_energy>0.0:
		if sun_depth==null:
			sun_depth=DirectionalDepth.new()
			add_child(sun_depth)
			sun_depth.configure(scope_root,PackedFloat32Array([24.0,96.0]),PackedFloat32Array([1.2,4.8]),true)
		var focus: Dictionary=scope_root.shadow_focus()
		var position: Vector3=focus.get("position",view.global_position)
		fits=sun_depth.update(position,-sun.global_basis.z.normalized())
		sun_focus=position
		sun_strength=sun.shadow_opacity
		sun_update_pending=true
		var moving: Array[CompositorEffect]=sun_depth.moving_fits()
		if not fits.is_empty() or not moving.is_empty():
			effect.set_sun_shadow(fits,moving,position,sun_depth.radii,sun.shadow_opacity)
			return
	effect.set_sun_shadow(fits)
func set_weather(value: Dictionary) -> void:
	if not cx_records or closed or effect==null: return
	var visibility=particle_visibility.get_ref() if particle_visibility!=null else null
	if value.is_empty() or bool(value.get("interior",false)) or is_instance_valid(visibility) and not visibility.enabled:
		effect.set_weather({})
		return
	var view:=get_viewport().get_camera_3d()
	var cover: CompositorEffect
	if view!=null:
		if weather_cover==null:
			weather_cover=DirectionalDepth.new()
			add_child(weather_cover)
			weather_cover.configure(scope_root,PackedFloat32Array([60.0]),PackedFloat32Array([15.0]))
		var focus: Dictionary=scope_root.shadow_focus()
		var fall: Vector3=value.fall
		if value.kind==2:
			var horizontal:=Vector3(fall.x,0.0,fall.z).normalized()
			if horizontal==Vector3.ZERO: horizontal=Vector3.RIGHT
			fall=horizontal*sin(deg_to_rad(3.0))+Vector3.DOWN*cos(deg_to_rad(3.0))
		var fits: Array[CompositorEffect]=weather_cover.update(focus.get("position",view.global_position),fall)
		if not fits.is_empty(): cover=fits[0]
	if cover==null and value.density==0.0:
		effect.set_weather({})
		return
	effect.set_weather(value,cover)
func snapshot() -> Dictionary:
	return {"closed":closed,"failure":failure,"members":members.size(),"fast_members":fast_members,"pending_registrations":pending_registrations.size(),"fallback_reasons":fallback_reasons.duplicate(),"geometry_worker":geometry_worker,"animation_snapshot":animation_snapshot,"suppressed_fallbacks":members.size()-fast_members if geometry_worker else 0,"native":native.call("dispatch",7,{}) if native!=null else {},"renderer":renderer.call("dispatch",2,{}) if renderer!=null else {},"scene_batches":scene_batches.snapshot() if scene_batches!=null else {}}
func close() -> void:
	if closed: return
	if running: close_requested=true; return
	if cx_records and not failure.is_empty(): push_error("CX particle presentation failed: "+failure)
	if RenderingServer.frame_pre_draw.is_connected(refresh_visibility): RenderingServer.frame_pre_draw.disconnect(refresh_visibility)
	if RenderingServer.frame_pre_draw.is_connected(_flush_sun_update): RenderingServer.frame_pre_draw.disconnect(_flush_sun_update)
	sun_update_pending=false
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
	if is_instance_valid(weather_cover): weather_cover.queue_free(); weather_cover=null
	if is_instance_valid(sun_depth): sun_depth.queue_free(); sun_depth=null
	closed=true; members.clear(); pending_controls.clear(); pending_removals.clear(); pending_registrations.clear(); collision_provider=Callable(); set_process(false)
func _exit_tree() -> void: close()
