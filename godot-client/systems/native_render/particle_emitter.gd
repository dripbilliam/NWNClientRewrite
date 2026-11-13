extends Node3D
# Packed templates retain immutable original data/resources only. Each cloned
# node creates private lists, clocks and a GPU surface in _ready. The world can
# supply its shared visual RNG; standalone fixtures retain an instance stream.
const M=preload("res://systems/native_render/particle_math.gd")
const Schedule=preload("res://systems/native_render/particle_schedule.gd")
const Initialization=preload("res://systems/native_render/particle_initialization.gd")
const Movement=preload("res://systems/native_render/particle_movement.gd")
const Vertices=preload("res://systems/native_render/particle_vertices.gd")
const Random=preload("res://systems/native_render/particle_random.gd")
const Channels=preload("res://systems/native_render/particle_channels.gd")
const Surface=preload("res://systems/particle_surface.gd")
const InstanceSurface=preload("res://systems/particle_instance_surface.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Lightning=preload("res://systems/native_render/particle_lightning.gd")
const Target=preload("res://systems/native_render/particle_target.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
const Chunks=preload("res://systems/native_render/particle_chunks.gd")
const ChunkModels=preload("res://systems/native_render/chunk_models.gd")
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
const FIELDS={"birthrate":"birthRate","lifeexp":"lifeExp","particlerot":"particleRot","blurlength":"blurLength","velocity":"velocity","randvel":"randomVelocity","framestart":"frameStart","frameend":"frameEnd","xsize":"xSize","ysize":"ySize","spread":"spread","mass":"mass","bounce_co":"bounceCoefficient","sizestart":"sizeStart","sizeend":"sizeEnd","sizestart_y":"sizeStartY","sizeend_y":"sizeEndY","alphastart":"alphaStart","alphaend":"alphaEnd","fps":"fps","deadspace":"deadspace","blastradius":"blastRadius","blastlength":"blastLength","lightningdelay":"lightningDelay","lightningradius":"lightningRadius","lightningscale":"lightningScale"}
const MODES={"Normal":0,"Billboard_to_Local_Z":1,"Billboard_to_World_Z":2,"Linked":3,"Aligned_to_World_Z":4,"Aligned_to_Particle_Dir":5,"Motion_Blur":6}
@export var original_properties: Dictionary={}
@export var channel_asset: Dictionary={}
@export var physical_part: int=-1
@export var source_path: NodePath
@export var original_texture: Texture2D
@export var origin_resource: String=""
@export var source_model_flags: int=-1
@export var reference_paths: Array[NodePath]=[]
var clock_provider: Callable
var services: Dictionary={}
var _state: Dictionary={}
# Compatibility/debug view only. The native tick never exports particle state.
# Commands use detonate(); mutating this snapshot is not a native command.
var state: Dictionary:
	get:
		return native_owner.call("dispatch",2,{},{}) if native_owner!=null else _state
	set(value): _state=value
var native_owner: RefCounted
var native_frame_group: Node
var native_stream_group: Node
var native_stream_vertices:=0
var native_group_identity: Dictionary={}
var native_pose_bound:=false
var native_active:=0
var native_free:=0
var native_compact_records:=false
var native_typed_frame:=false
var batched_phase_collection:=false
var native_instance_streams:=false
var queued_detonate:=false
var force_reference:=false
var parameters: Dictionary={}
var providers: Dictionary={}
var channels:=Channels.new()
var rng:=Random.new()
var source: Node3D
var surface
var retired:=false
var failure:=""
var limitations: Array=[]
var frames:=0
var sequence:=0
var allocated:=0
var elapsed:=0.0
var static_clip:=""
var peak_active:=0
var rng_scope:="instance"
var target_signature: Array=[null]
var target_status:=""
var target_listener_active:=false
var compiled_kernel:=false
var fused_dispatch:=false
var native_parameter_transfer:=false
var missing_chunk_models:=0
var chunk_models
var bounds:=Bounds.new()
var frustum_enabled:=not OS.get_cmdline_user_args().has("--particle-culling=none"):
	set(value):
		frustum_enabled=value
		if is_instance_valid(native_stream_group): native_stream_group.control(self,{"culling":value})
var culled_frames:=0
var culling_checks:=0
var culling_fallbacks:=0
var last_culled:=false
var last_radius:=0.0
var metrics_owner
var visibility_owner
var particles_enabled:=true
var collision_enabled:=true
var collision_flags_pending:=false
var collision_indices_provider: Callable
var native_wind_owner
var direct_scene_queries:=0
var direct_scene_hits:=0
var native_surface_output:=false
var native_surface_world: WeakRef
var native_light_reference: WeakRef
func _ready() -> void:
	process_priority=20; add_to_group("native_original_particle_emitters")
	var lighting_ancestor:=get_parent()
	while lighting_ancestor!=null:
		if lighting_ancestor.has_meta("native_surface_output"):
			native_surface_output=lighting_ancestor.get_meta("native_surface_output",false)
			native_surface_world=weakref(lighting_ancestor)
			if lighting_ancestor.has_meta("native_focus_light_owner"): native_light_reference=lighting_ancestor.get_meta("native_focus_light_owner")
			break
		lighting_ancestor=lighting_ancestor.get_parent()
	if native_surface_output: process_priority=110
	var visibility_ancestor:=get_parent()
	while visibility_ancestor!=null:
		if visibility_ancestor.has_meta("native_particle_visibility"):
			visibility_owner=visibility_ancestor.get_meta("native_particle_visibility"); visibility_owner.register(self); break
		visibility_ancestor=visibility_ancestor.get_parent()
	var metrics_ancestor:=get_parent()
	while metrics_ancestor!=null:
		if metrics_ancestor.has_meta("native_particle_metrics"):
			metrics_owner=metrics_ancestor.get_meta("native_particle_metrics"); metrics_owner.register(self); break
		metrics_ancestor=metrics_ancestor.get_parent()
	compiled_kernel=Kernel.enabled()
	batched_phase_collection=not OS.get_cmdline_user_args().has("--particle-phase-collection=individual") and (OS.get_cmdline_user_args().has("--particle-phase-collection=batch") or OS.get_environment("NWN_PARTICLE_PHASE_COLLECTION")!="individual")
	# The isolated C++ transfer is diagnostic-only: it did not improve the
	# measured room while both sides still marshal per-field Dictionaries.
	native_parameter_transfer=compiled_kernel and OS.get_cmdline_user_args().has("--particle-parameters=cpp")
	fused_dispatch=compiled_kernel and Kernel.fused_enabled() and str(original_properties.get("update","")) in ["Fountain","Explosion","Single"] and not services.has("moveParticles") and not services.has("updateEmitter")
	if compiled_kernel and not Kernel.available(): fail("Compiled native particle kernel is unavailable"); return
	var ancestor:=get_parent()
	while ancestor!=null:
		if ancestor.has_meta("native_particle_random"):
			rng=ancestor.get_meta("native_particle_random"); rng_scope="world"; break
		ancestor=ancestor.get_parent()
	if not services.has("addPointSourceWind") or not services.has("wind"):
		ancestor=get_parent()
		while ancestor!=null:
			if ancestor.has_meta("native_point_wind_owner"):
				var owner=ancestor.get_meta("native_point_wind_owner")
				if is_instance_valid(owner):
					if not services.has("addPointSourceWind"):
						services.addPointSourceWind=func(position,radius,duration,strength):
							if not owner.add_source(position,radius,duration,strength): fail(owner.failure)
					if not services.has("wind") and owner.native_owner!=null:
						services.wind=owner.wind_vector; native_wind_owner=owner
				break
			ancestor=ancestor.get_parent()
	source=get_node_or_null(source_path) as Node3D
	if source==null or not get_parent() is Node3D: fail("Native particle transform/source owner is absent"); return
	parameters=original_properties.duplicate(true); channels.configure(channel_asset,physical_part)
	if not channels.failure.is_empty(): fail(channels.failure); return
	var mode:=str(parameters.get("render","")); var update:=str(parameters.get("update","")); var flags:=int(parameters.get("flags",0)); var texture_name:=str(parameters.get("texture","")).to_lower()
	# PartEmitter60420 creates CHitInfo(mode1, maskFFFFFFFFBFFFFFFF, box0).
	# Only collision emitters acquire this boundary; other streams retain their
	# fused native owner. Native membership/BSP completeness is a separate gap.
	if flags&16 and update!="Lightning" and not services.has("collide"):
		ancestor=get_parent()
		while ancestor!=null:
			if ancestor.has_meta("native_particle_collision"):
				services.collide=ancestor.get_meta("native_particle_collision")
				collision_indices_provider=ancestor.get_meta("native_particle_collision_indices",Callable()); break
			ancestor=ancestor.get_parent()
	var chunk_name:=str(parameters.get("chunkname",""))
	if chunk_name.is_empty() and texture_name not in ["","null"] and original_texture==null: fail("Original particle bitmap unavailable: "+texture_name); return
	if not MODES.has(mode) or update not in ["Fountain","Explosion","Single","Lightning"]: fail("Native particle update/render owner pending: "+update+"/"+mode); return
	if flags&1 and update!="Lightning": fail("Native point-to-point particle movement is pending"); return
	if str(parameters.get("blend",""))=="Punch-Through": fail("Native particle punch-through material is pending"); return
	if flags&4 and update!="Lightning" and not services.has("wind"): fail("Native scene wind sampling is pending"); return
	if flags&16 and update!="Lightning" and not services.has("collide"): fail("Native particle scene intersection is pending"); return
	if not chunk_name.is_empty() and not Chunks.REQUIRED.all(func(name):return services.has(name) and services[name] is Callable and services[name].is_valid()):
		if Chunks.REQUIRED.any(func(name):return services.has(name)): fail("Native chunk model service set is incomplete"); return
		chunk_models=ChunkModels.new(); chunk_models.resource=chunk_name; chunk_models.origin_resource=origin_resource; add_child(chunk_models)
		if not chunk_models.failure.is_empty(): fail(chunk_models.failure); return
		services.merge(chunk_models.services(),true)
	state={"flags":flags,"chunkName":"","renderMode1a8":MODES[mode],"blendMode68":0 if str(parameters.get("blend",""))=="Normal" else 2,"spawnType":int(parameters.get("spawntype",0)),"loop":int(parameters.get("loop",0)),"xGrid":int(parameters.get("xgrid",0)),"yGrid":int(parameters.get("ygrid",0)),"ageMode1cc":1,"accumulator198":0.0,"remaining164":[0.0,0.0,0.0],"detonate108":0,"blastLatch1c8":0.0,"elevationThreshold":5.0,"hit1f0":{"normal":[0.0,0.0,0.0]},"twoSided":bool(parameters.get("twosidedtex",false)),"position1e0":[0.0,0.0,0.0],"quaternion1d0":[1.0,0.0,0.0,0.0],"previous19c":[0.0,0.0,0.0],"previousQuaternion178":[1.0,0.0,0.0,0.0],"reference10c":[0.0,0.0,0.0],"referenceQuaternion118":[1.0,0.0,0.0,0.0],"basis140":[1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0],"active188":{"records":[],"capacity":0},"free130":{"records":[],"capacity":0},"initialized208":0,"source50":{"position":[0.0,0.0,0.0],"quaternion":[1.0,0.0,0.0,0.0],"adjustedScale":1.0,"opacity108":1.0,"instance":null},"instance100":null}
	providers={"random":rng.next,"cameraPosition":camera_position,"cosineDouble":func(value):return cos(value),"globalTransform":func(_e):return pose(get_parent()),"sourceFactor":func(value):return value.adjustedScale,"cameraQuaternion":camera_quaternion,"updateEmitter":update_emitter,"reserveActive":func(_capacity):pass,"reserveFree":func(_capacity):pass,"createParticle":create_particle,"initializeParticle":initialize_particle,"randomizeParticle":randomize_particle,"moveParticles":move_particles,"clearHit":func(hit):hit.normal=[0.0,0.0,0.0],"destroyParticle":func(_part,_flag):pass,"lightColor":light_color}
	# Keep authored flags/services intact so the preference is reversible.
	_state.flags=effective_flags()
	providers.merge(services,true)
	providers.baseCreate=base_create; providers.baseInitialize=base_initialize
	if not chunk_name.is_empty():
		state.chunkName=chunk_name
		providers.detachChunk=func(child,_scene): Schedule.invoke(providers,"chunkScene",[child,false])
	providers.targetPosition=func(target):return pose(target).position
	providers.randomPosition=random_position
	if update=="Lightning":
		state.merge({"target1c0":null,"targetDistance20c":0.0,"targetListener128":0,"lightningElapsed":0.0,"lightningPreviousDirection":[0.0,0.0,0.0],"lightningPreviousPosition":[0.0,0.0,0.0],"partScale":1.0})
		Target.initialize_lightning(state,{"baseInitialize":func(_e):pass,"listen":func(_source,_callback,_event,_owner):target_listener_active=true; return 1})
		parameters.lifeexp=state.lifeExp
		limitations.append("Reference target notification is projected after bounded native model publication; complete Gob event order/reattachment remain incomplete")
	if flags&8 and not native_surface_output: limitations.append("Particle tint uses Godot scene lighting; original point-sampled tint/fog/soft depth remain incomplete")
	limitations.append("Local visual RNG seed/draw ordering and instance opacity/fade bindings remain incomplete")
	for candidate in ["pause","default"]:
		if channels.clips.has(candidate): static_clip=candidate; break
	if not static_clip.is_empty(): limitations.append("Static pause/default channel clock lacks full authoritative object-animation/event binding")
	surface=Surface.new(); surface.name="NativeParticleSurface"; surface.configure(original_texture,1,int(state.blendMode68)!=0,bool(state.twoSided),(flags&8)!=0,native_surface_output); add_child(surface)
	if fused_dispatch and Kernel.streams_enabled() and (flags&1)==0 and not force_reference and not OS.get_cmdline_user_args().has("--particle-owner=reference") and services.keys().all(func(name):return name in ["addPointSourceWind","collide","wind"] or name in Chunks.REQUIRED) and (not services.has("wind") or is_instance_valid(native_wind_owner)):
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var instance_streams: bool=(OS.get_cmdline_user_args().has("--particle-streams=instances") or OS.get_environment("NWN_PARTICLE_STREAMS")=="instances") and RenderingServer.get_current_rendering_method()!="gl_compatibility"
		if instance_streams:
			surface.queue_free(); surface=InstanceSurface.new(); surface.name="NativeParticleInstances"; surface.configure(original_texture,1,int(state.blendMode68)!=0,bool(state.twoSided),(flags&8)!=0,native_surface_output); add_child(surface)
		var configuration:={"state":_state,"parameters":parameters,"clips":channels.clips,"update":update.to_lower(),"cacheConstants":channels.cache_constants,"compactRecords":not OS.get_cmdline_user_args().has("--particle-records=legacy") and (OS.get_cmdline_user_args().has("--particle-records=compact") or OS.get_environment("NWN_PARTICLE_RECORDS")!="legacy")}
		native_pose_bound=not OS.get_cmdline_user_args().has("--particle-poses=gd")
		configuration.instanceStreams=instance_streams
		configuration.typedEmitter=configuration.compactRecords and not OS.get_cmdline_user_args().has("--particle-emitter=mirrored") and (OS.get_cmdline_user_args().has("--particle-emitter=typed") or OS.get_environment("NWN_PARTICLE_EMITTER")!="mirrored")
		if native_pose_bound: configuration.poseId=get_parent().get_instance_id(); configuration.sourceId=source.get_instance_id()
		var result: Dictionary=owner.call("dispatch",0,configuration,{})
		if result.has("error"): fail(result.error); return
		native_owner=owner; native_parameter_transfer=true
	set_particles_enabled(particles_enabled)
	var group_ancestor:=get_parent()
	while group_ancestor!=null:
		if not native_surface_output and group_ancestor.has_meta("native_particle_frame_group"):
			var group=group_ancestor.get_meta("native_particle_frame_group")
			if is_instance_valid(group): group.register(self)
			break
		group_ancestor=group_ancestor.get_parent()
	var stream_ancestor:=get_parent()
	while stream_ancestor!=null:
		if stream_ancestor.has_meta("native_particle_stream_group"):
			var stream=stream_ancestor.get_meta("native_particle_stream_group")
			if is_instance_valid(stream): stream.register(self)
			break
		stream_ancestor=stream_ancestor.get_parent()
static func pose(node: Node3D) -> Dictionary:
	var transform:=node.global_transform; var q:=transform.basis.orthonormalized().get_rotation_quaternion()
	# Conjugation by the MDL Z-up -> Godot Y-up basis.
	return {"position":[transform.origin.x,-transform.origin.z,transform.origin.y],"quaternion":[q.w,q.x,-q.z,q.y]}
func light_color(point: Array) -> Array:
	if not native_surface_output: return [1.0,1.0,1.0]
	var owner=native_light_reference.get_ref() if native_light_reference!=null else null
	var input: Dictionary=owner.particle_lighting() if is_instance_valid(owner) else {}
	input.point=point
	var value: Vector3=preload("res://systems/native_render/focus_light_sample.gd").sample(input)
	return [value.x,value.y,value.z]
func camera_position() -> Array:
	return pose(get_viewport().get_camera_3d()).position
func camera_quaternion() -> Array:
	var camera:=get_viewport().get_camera_3d(); var q:=camera.global_basis.orthonormalized().get_rotation_quaternion(); var convert:=Quaternion(Vector3.RIGHT,PI/2)*q
	return [convert.w,convert.x,convert.y,convert.z]
func create_particle(chunk: bool,delta: float) -> Dictionary:
	allocated+=1
	if chunk:
		var part:=Chunks.construct(state,delta,providers)
		if part.chunk78==null and not (is_instance_valid(chunk_models) and chunk_models.no_model): missing_chunk_models+=1
		return part
	return base_create(delta)
func base_create(delta: float) -> Dictionary:
	if compiled_kernel:
		var out:=Kernel.simulate("create",state,delta,providers)
		if out.has("error"): fail(out.error); return {}
		return out.value
	return Initialization.create(state,delta,providers)
func initialize_particle(part: Dictionary,delta: float,factor: float) -> void:
	if part.get("nativeChunky",false): Chunks.initialize(part,delta,factor,providers)
	else: base_initialize(part,delta,factor)
func base_initialize(part: Dictionary,delta: float,factor: float) -> void:
	if compiled_kernel: apply_kernel("initialize",delta,part,factor)
	else: Initialization.initialize(part,state,delta,factor,providers)
func randomize_particle(e: Dictionary,part: Dictionary) -> void:
	if compiled_kernel: apply_kernel("randomize_frame",0,part)
	else: Initialization.randomize_frame(e,part,providers)
func move_particles(e: Dictionary,delta: float) -> void:
	if compiled_kernel: apply_kernel("standard",delta)
	else: Movement.standard(e,delta,providers)
func random_position(part: Dictionary,x: int,y: int) -> void:
	if compiled_kernel: apply_kernel("random_position",x,part,y)
	else: Initialization.random_position(part,state,x,y,providers)
func apply_kernel(operation: String,delta: float,part: Dictionary={},factor: float=1.0) -> void:
	var out:=Kernel.simulate(operation,state,delta,providers,part,factor)
	if out.has("error"): fail(out.error)
func update_emitter(e: Dictionary,delta: float) -> void:
	var update:=str(original_properties.get("update",""))
	if compiled_kernel and update in ["Fountain","Explosion","Single"]:
		apply_kernel(update.to_lower(),delta); return
	match update:
		"Fountain": Schedule.fountain(e,delta,providers)
		"Explosion": Schedule.explosion(e,delta,providers)
		"Single": Schedule.single(e,delta,providers)
		"Lightning":
			var error:=Lightning.update(e,delta,providers)
			if not error.is_empty(): fail(error)
func refresh_target() -> void:
	if str(original_properties.get("update",""))!="Lightning": return
	var children: Array=[]; var signature: Array=[]
	for path in reference_paths:
		var reference=get_node_or_null(path)
		children.append(reference)
		if reference==null: signature.append([str(path),-1]); continue
		var target=reference.model68
		signature.append([reference.get_instance_id(),reference.revision,target.get_instance_id() if is_instance_valid(target) else 0])
	if not children.is_empty() and (children[0]==null or not str(children[0].failure).is_empty() or not is_instance_valid(children[0].model68) or children[0].model68.is_queued_for_deletion()):
		state.target1c0=null; target_signature=signature; target_status="Waiting for first direct referenced model"
		if children[0]!=null and not str(children[0].failure).is_empty(): target_status=children[0].failure
		return
	if signature==target_signature and (signature.is_empty() or is_instance_valid(state.target1c0)): return
	target_signature=signature
	if int(state.initialized208)==0:
		var initial:=pose(get_parent()); state.position1e0=M.values(initial.position); state.quaternion1d0=M.values(initial.quaternion)
	Target.set_target(state,{"children":func(_e):return children,"referenceView":func(child):return child,"globalPosition":func(_e):return pose(get_parent()).position,"targetPosition":providers.targetPosition,"lightningView":func(_e):return state,"removeListener":func(_source,_listener):target_listener_active=false})
	target_status="Bound first direct referenced model" if is_instance_valid(state.target1c0) else "No direct reference endpoint"
func detonate() -> void:
	if not retired and not _state.is_empty():
		if native_owner!=null: queued_detonate=true
		else: _state.detonate108=1
		if is_instance_valid(native_frame_group): native_frame_group.control(self,{"detonate":true})
		if is_instance_valid(native_stream_group): native_stream_group.control(self,{"detonate":true})
func fail(reason: String) -> void:
	failure=reason; set_process(false)
	if is_instance_valid(native_frame_group): native_frame_group.control(self,{"enabled":false})
	if is_instance_valid(native_stream_group): native_stream_group.control(self,{"enabled":false})
	if is_instance_valid(surface): surface.visible=false
	update_metrics()
	push_warning(reason)
func outside_view(camera: Camera3D) -> bool:
	# Unknown classification, point impulses/custom movement, target beams and
	# chunk models keep the prior path until their complete bounds are bound.
	if not frustum_enabled: return false
	if source_model_flags<0 or not str(state.chunkName).is_empty() or str(original_properties.get("update",""))=="Lightning" or services.has("moveParticles") or services.has("updateEmitter") or services.has("globalTransform"):
		culling_fallbacks+=1; return false
	var wind: Array=[0.0,0.0,0.0]
	if int(state.flags)&4:
		if not is_instance_valid(native_wind_owner) or native_wind_owner.closed or native_wind_owner.point_count>0:
			culling_fallbacks+=1; return false
		wind=native_wind_owner.parameters.get("wind",wind)
	var transform: Transform3D=get_parent().global_transform
	culling_checks+=1
	# An inside center cannot be rejected by a nonnegative sphere radius.
	# Use the engine's single native frustum query before constructing bounds.
	if camera.is_position_in_frustum(transform.origin): last_radius=0.0; return false
	var radius:=bounds.radius_for(parameters,source_model_flags,wind)
	if not is_finite(radius) or radius<0 or float(parameters.get("lifeexp",0))<0: culling_fallbacks+=1; return false
	var scale_value:=maxf(1.0,maxf(transform.basis.x.length(),maxf(transform.basis.y.length(),transform.basis.z.length())))
	radius*=scale_value; last_radius=radius
	# Most effect models use the original 1000-unit sphere. Only expand the
	# conservative envelope if the basic original sphere would be rejected.
	if not Bounds.outside(camera,transform.origin,radius): return false
	# Original admission uses its computed source sphere. Enlarge it to also
	# cover actual retained native particles, full quads and emission extents;
	# this adapter deliberately admits more rather than clipping effects.
	var size_value:=maxf(maxf(absf(float(parameters.get("sizestart",0))),absf(float(parameters.get("sizeend",0)))),absf(float(parameters.get("sizemid",0))))
	size_value=maxf(size_value,maxf(maxf(absf(float(parameters.get("sizestart_y",0))),absf(float(parameters.get("sizeend_y",0)))),absf(float(parameters.get("sizemid_y",0)))))
	var padding:=size_value*scale_value*2.0
	radius+=padding+maxf(absf(float(state.xSize)),absf(float(state.ySize)))*0.02
	for part in state.active188.records:
		var position: Array=part.position10
		var center:=Vector3(float(position[0]),float(position[2]),-float(position[1]))
		radius=maxf(radius,transform.origin.distance_to(center)+padding)
		if int(state.renderMode1a8)==6:
			var trail: Array=part.trail64
			radius=maxf(radius,transform.origin.distance_to(Vector3(float(trail[0]),float(trail[2]),-float(trail[1])))+padding)
	last_radius=radius
	return Bounds.outside(camera,transform.origin,radius)
func shared_chunk_ready() -> bool:
	if retired or not failure.is_empty(): return false
	if not is_instance_valid(chunk_models): return true
	if not chunk_models.failure.is_empty(): fail(chunk_models.failure); return false
	return chunk_models.ready()
func tick(delta: float,shared_frame: bool=false) -> void:
	if not particles_enabled or retired or not failure.is_empty() or _state.is_empty() or not is_instance_valid(source) or not is_visible_in_tree() or get_viewport().get_camera_3d()==null: return
	if native_surface_output and native_surface_world!=null:
		var owner=native_surface_world.get_ref()
		if is_instance_valid(owner): preload("res://systems/native_render/native_surface_state.gd").publish_camera(owner,preload("res://systems/native_render/particle_stream_fog.gd").sample(get_viewport().get_camera_3d(),true))
	if is_instance_valid(chunk_models):
		if not chunk_models.failure.is_empty(): fail(chunk_models.failure); return
		if not chunk_models.ready(): return
	if native_owner!=null: tick_native(delta,shared_frame); return
	var began:=Profile.begin(); elapsed+=delta; var clock: Dictionary=clock_provider.call() if clock_provider.is_valid() else {"clip":static_clip,"time":elapsed}
	var phase:=Profile.begin()
	var clip:=str(clock.get("clip","")); var time:=float(clock.get("time",0.0))
	if not clock_provider.is_valid() and channels.clips.has(clip) and float(channels.clips[clip].length)>0: time=fposmod(time,float(channels.clips[clip].length))
	if not channels.sample(clip,time,parameters): fail(channels.failure); return
	if native_parameter_transfer:
		apply_kernel("parameters",0.0,parameters)
		if not failure.is_empty(): return
	else:
		for name in FIELDS: state[FIELDS[name]]=M.f(parameters.get(name,1.0 if name=="blurlength" else 0.0))
		state.colorStart=M.values(parameters.get("colorstart",[0.0,0.0,0.0])); state.colorEnd=M.values(parameters.get("colorend",[0.0,0.0,0.0]))
	# Do not hide a resource overflow by silently dropping births/draws.
	if absf(state.birthRate)>32768 or allocated>32768: fail("Native particle instance exceeds explicit allocation limit"); return
	if state.renderMode1a8==6 and state.blurLength==0: fail("Original particle blur length is zero"); return
	if str(original_properties.get("update",""))=="Explosion" and state.blastRadius!=0 and not providers.has("addPointSourceWind"): fail("Native explosion point-wind registration is pending"); return
	if int(parameters.get("detonate",0))!=0: state.detonate108=int(parameters.detonate); parameters.detonate=0
	var source_pose:=pose(source); state.source50.position=source_pose.position; state.source50.quaternion=source_pose.quaternion; state.source50.adjustedScale=M.f(source.global_basis.get_scale().x)
	if str(original_properties.get("update",""))=="Lightning": state.partScale=M.f(get_parent().scale.x); refresh_target()
	Profile.finish("native_particle_channels_pose",phase); phase=Profile.begin()
	last_culled=outside_view(get_viewport().get_camera_3d())
	Profile.finish("native_particle_admission",phase)
	if is_instance_valid(surface): surface.visible=not last_culled
	if last_culled:
		culled_frames+=1
		update_metrics()
		Profile.finish("native_particles",began); return
	phase=Profile.begin()
	if compiled_kernel: apply_kernel("animate_"+str(original_properties.update).to_lower() if fused_dispatch else "animate",delta)
	else: Schedule.animate(state,delta,providers)
	Profile.finish("native_particle_simulation",phase)
	if not failure.is_empty(): return
	if not str(state.chunkName).is_empty():
		phase=Profile.begin(); Chunks.render(state,providers); Profile.finish("native_particle_chunk_poses",phase)
	elif not original_texture==null:
		phase=Profile.begin()
		var output:=Kernel.build_streams(state,providers,surface.capacity) if compiled_kernel and Kernel.streams_enabled() else Kernel.build(state,providers) if compiled_kernel else Vertices.build(state,providers)
		Profile.finish("native_particle_vertices",phase)
		if output.has("error"): fail(output.error); return
		phase=Profile.begin()
		if not upload(output): fail("Native particle surface publication rejected"); return
		Profile.finish("native_particle_upload",phase)
	frames+=1; peak_active=maxi(peak_active,state.active188.records.size()); Profile.finish("native_particles",began)
	update_metrics()
func tick_native(delta: float,shared_frame: bool) -> void:
	if not particles_enabled or retired or not failure.is_empty(): return
	var began:=Profile.begin(); var phase:=Profile.begin(); elapsed+=delta
	var clock: Dictionary=clock_provider.call() if clock_provider.is_valid() else {"clip":static_clip,"time":elapsed}
	var clip:=str(clock.get("clip","")); var time:=float(clock.get("time",0.0))
	if not clock_provider.is_valid() and channels.clips.has(clip) and float(channels.clips[clip].length)>0: time=fposmod(time,float(channels.clips[clip].length))
	var input:={"delta":delta,"clip":clip,"time":time,"view":Bounds.native_view(get_viewport().get_camera_3d(),not shared_frame),"capacity":surface.capacity,"source_flags":source_model_flags,"culling":frustum_enabled,"detonate":queued_detonate,"profile":Profile.enabled,"draw_enabled":original_texture!=null}
	if native_surface_output and effective_flags()&8: input.tint=M.values(Schedule.invoke(providers,"lightColor",[pose(get_parent()).position]))
	if int(original_properties.get("flags",0))&4:
		if not is_instance_valid(native_wind_owner) or native_wind_owner.token==0: fail("Native scene wind token is retired"); return
		input.wind_token=native_wind_owner.token
	if collision_flags_pending: input.patch={"flags":effective_flags()}
	if collision_enabled and collision_indices_provider.is_valid():
		var indices: Array=collision_indices_provider.call()
		if indices.size()==2: input.scene_indices=indices
	if not native_pose_bound:
		var source_pose:=pose(source); source_pose.adjustedScale=source.global_basis.get_scale().x; source_pose.opacity108=1.0; source_pose.instance=null
		var transform: Transform3D=get_parent().global_transform
		input.source=source_pose; input.pose=pose(get_parent()); input.scale=maxf(transform.basis.x.length(),maxf(transform.basis.y.length(),transform.basis.z.length()))
	Profile.finish("native_particle_pose_collection",phase); Profile.finish("native_particle_channels_pose",phase)
	phase=Profile.begin()
	var output: Dictionary=native_owner.call("dispatch",1,input,providers); queued_detonate=false
	complete_native_frame(output,began,phase)
func complete_native_frame(output: Dictionary,began: int,phase: int) -> void:
	Profile.finish("native_particle_dispatch",phase); phase=Profile.begin()
	if output.has("error"): fail(output.error); return
	native_compact_records=bool(output.get("compact_records",false))
	native_typed_frame=bool(output.get("typed_emitter",false))
	native_instance_streams=bool(output.get("instance_streams",false))
	collision_flags_pending=false
	direct_scene_queries+=int(output.get("direct_scene_queries",0)); direct_scene_hits+=int(output.get("direct_scene_hits",0))
	if batched_phase_collection: Profile.record_batch(output.get("phases",{}))
	else:
		for name in output.get("phases",{}): Profile.record(str(name),float(output.phases[name]))
	Profile.finish("native_particle_phase_collection",phase); phase=Profile.begin()
	allocated=int(output.allocated); native_active=int(output.active); native_free=int(output.free); channels.constant_hits=int(output.constant_hits); channels.sampled_channels=int(output.sampled_channels)
	missing_chunk_models=int(output.get("missing_chunk_models",0))
	if not failure.is_empty():
		update_metrics()
		return
	last_culled=bool(output.culled); last_radius=float(output.radius)
	if bool(output.culling_checked): culling_checks+=1
	elif frustum_enabled: culling_fallbacks+=1
	if last_culled: culled_frames+=1; surface.visible=false
	else:
		phase=Profile.begin()
		if not upload(output): fail("Native particle surface publication rejected"); return
		Profile.finish("native_particle_upload",phase); frames+=1; peak_active=maxi(peak_active,native_active)
	Profile.finish("native_particles",began)
	update_metrics()
func receive_group_frame(output: Dictionary,group_elapsed: float,prepare_ms: float,dispatch_ms: float) -> bool:
	var began:=Profile.begin(); elapsed=group_elapsed; queued_detonate=false
	if Profile.enabled:
		Profile.record("native_particle_pose_collection",prepare_ms); Profile.record("native_particle_channels_pose",prepare_ms); Profile.record("native_particle_dispatch",dispatch_ms)
	complete_native_frame(output,0,0)
	if Profile.enabled: Profile.record("native_particles",prepare_ms+dispatch_ms+(Time.get_ticks_usec()-began)/1000.0)
	return failure.is_empty() and not retired
func grouped_fallback_tick(delta: float) -> void: tick(delta,true)
func update_metrics() -> void:
	if metrics_owner==null: return
	var began:=Profile.begin(); metrics_owner.update(self); Profile.finish("native_particle_metrics",began)
func active_count() -> int:
	if is_instance_valid(native_stream_group):
		var value: Dictionary=native_stream_group.info(get_instance_id())
		if not value.is_empty(): return int(value.active)
	return native_active if native_owner!=null else _state.get("active188",{}).get("records",[]).size()
func upload(output: Dictionary) -> bool:
	if output.has("instances"):
		var box: Array=output.bounds; sequence+=1
		return surface.apply_instances(1,sequence,int(output.count),int(output.capacity),output.instances,AABB(Vector3(box[0],box[1],box[2]),Vector3(box[3],box[4],box[5])))
	if output.has("positions"):
		var box: Array=output.bounds
		sequence+=1
		return surface.apply_frame(1,sequence,int(output.count),int(output.capacity),output.positions,output.attributes,AABB(Vector3(box[0],box[1],box[2]),Vector3(box[3],box[4],box[5])))
	var count:=int(output.get("count",0)); var capacity: int=surface.capacity
	if count>capacity: capacity=mini(Vertices.MAX_VERTICES,maxi(96,maxi(capacity*2,count)))
	var positions:=PackedByteArray(); var attributes:=PackedByteArray(); positions.resize(capacity*12); attributes.resize(capacity*12); var bounds:=AABB(); var first:=true
	var bytes: PackedByteArray=output.get("buffer",PackedByteArray())
	for index in count:
		var at:=index*24; var point:=Vector3(bytes.decode_float(at+4),bytes.decode_float(at+12),-bytes.decode_float(at+8)); var u:=bytes.decode_float(at+16); var v:=bytes.decode_float(at+20)
		if not point.is_finite() or not is_finite(u) or not is_finite(v): return false
		positions.encode_float(index*12,point.x); positions.encode_float(index*12+4,point.y); positions.encode_float(index*12+8,point.z); attributes.encode_u32(index*12,bytes.decode_u32(at)); attributes.encode_float(index*12+4,u); attributes.encode_float(index*12+8,v)
		if first: bounds=AABB(point,Vector3.ZERO); first=false
		else: bounds=bounds.expand(point)
	sequence+=1
	return surface.apply_frame(1,sequence,count,capacity,positions,attributes,bounds)
func _process(delta: float) -> void:
	var began:=Profile.begin()
	if is_instance_valid(native_frame_group) and native_frame_group.engine_ordered:
		var result: Dictionary=native_frame_group.native.call("dispatch",8,native_group_identity)
		if result.has("error"): fail(str(result.error))
	else: tick(delta,true)
	Profile.finish("callback_particles",began)
func effective_flags() -> int:
	var authored:=int(original_properties.get("flags",0))
	return authored if collision_enabled else authored & ~16
func set_collision_enabled(value: bool) -> void:
	if collision_enabled==value: return
	collision_enabled=value
	if not _state.is_empty(): _state.flags=effective_flags()
	# Resident simulation owns private state. Patch it once on the next tick,
	# including when particles were paused while the preference changed.
	if native_owner!=null: collision_flags_pending=true
	if is_instance_valid(native_frame_group): native_frame_group.control(self,{"flags":effective_flags()})
	if is_instance_valid(native_stream_group): native_stream_group.control(self,{"flags":effective_flags()})
func set_particles_enabled(value: bool) -> void:
	particles_enabled=value; visible=value
	process_mode=Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	set_process(value and not retired and failure.is_empty() and (not is_instance_valid(native_frame_group) or native_frame_group.engine_ordered))
	if is_instance_valid(native_frame_group): native_frame_group.control(self,{"enabled":value})
	if is_instance_valid(native_stream_group):
		native_stream_group.control(self,{"enabled":value}); set_process(false)
	if is_instance_valid(surface): surface.visible=value and not last_culled
	if is_instance_valid(native_stream_group) and native_stream_group.members.get(get_instance_id(),{}).get("fast",false) and is_instance_valid(surface): surface.hide()
func sync_stream_diagnostics() -> void:
	if not is_instance_valid(native_stream_group): return
	var value: Dictionary=native_stream_group.info(get_instance_id())
	if value.is_empty(): return
	elapsed=float(value.elapsed); frames=int(value.frames); native_active=int(value.active); native_free=int(value.free); allocated=int(value.allocated); peak_active=int(value.peak_active)
	native_stream_vertices=int(value.vertices); queued_detonate=bool(value.pending_detonate); collision_flags_pending=bool(value.pending_patch)
	channels.constant_hits=int(value.constant_hits); channels.sampled_channels=int(value.sampled_channels); culling_checks=int(value.culling_checks); culled_frames=int(value.culled_frames); culling_fallbacks=int(value.culling_fallbacks); last_culled=bool(value.culled); last_radius=float(value.radius); direct_scene_queries=int(value.direct_scene_queries); direct_scene_hits=int(value.direct_scene_hits)
func snapshot() -> Dictionary:
	# Native state exports only when explicitly requested, never in HUD totals.
	sync_stream_diagnostics()
	var shared: bool=is_instance_valid(native_stream_group) and native_stream_group.members.get(get_instance_id(),{}).get("fast",false)
	return {"direct_scene_queries":direct_scene_queries,"direct_scene_hits":direct_scene_hits,"backend":"resident" if native_owner!=null else "compiled" if compiled_kernel else "gd","compact_records":native_compact_records,"instance_streams":native_instance_streams,"fused_dispatch":fused_dispatch,"native_parameter_transfer":native_parameter_transfer,"channel_cache":channels.snapshot(),"frustum_enabled":frustum_enabled,"source_model_flags":source_model_flags,"culling_checks":culling_checks,"culling_fallbacks":culling_fallbacks,"culled_frames":culled_frames,"culled":last_culled,"admission_radius":last_radius,"failure":failure,"frames":frames,"active":active_count(),"free":native_free if native_owner!=null else _state.get("free130",{}).get("records",[]).size(),"allocated":allocated,"peak_active":peak_active,"vertices":native_stream_vertices if shared else surface.vertex_count if is_instance_valid(surface) else 0,"missing_chunk_models":missing_chunk_models,"chunks":chunk_models.snapshot() if is_instance_valid(chunk_models) else {},"rng_draws":rng.draws,"rng_scope":rng_scope,"static_clip":static_clip,"available_clips":channels.clips.keys(),"target_status":target_status,"limitations":limitations.duplicate()}
func retire() -> void:
	if retired: return
	if is_instance_valid(native_stream_group): native_stream_group.unregister(self)
	if is_instance_valid(native_frame_group): native_frame_group.unregister(self)
	if is_instance_valid(visibility_owner): visibility_owner.unregister(self); visibility_owner=null
	if metrics_owner!=null: metrics_owner.unregister(self); metrics_owner=null
	if native_owner!=null:
		# Export once at retirement so private active/pooled chunk models follow
		# the same exactly-once destroy path as the retained reference owner.
		var final_state: Dictionary=native_owner.call("dispatch",2,{},{}) if not str(_state.get("chunkName","")).is_empty() else {}
		native_owner=null; _state=final_state
	collision_indices_provider=Callable()
	native_wind_owner=null
	if not state.is_empty() and not str(state.chunkName).is_empty():
		for part in state.active188.records+state.free130.records: Chunks.destroy(part,providers)
	if is_instance_valid(chunk_models): chunk_models.retire()
	retired=true; set_process(false); providers.clear(); services.clear(); clock_provider=Callable(); state.clear(); parameters.clear(); channels.clips.clear(); target_signature.clear(); target_listener_active=false
	if is_instance_valid(surface): surface.retire()
func _exit_tree() -> void: retire()
