extends RefCounted
# Native GPU resources shared by content identity, not scene instances.
const Cache = preload("res://systems/native_data/prepared_cache.gd")
const Template = preload("res://systems/native_render/model_template.gd")
const PickGeometry=preload("res://systems/native_render/pick_geometry.gd")
const RendererGeometryToken=preload("res://systems/native_render/renderer_geometry_token.gd")
const SceneGeometry=preload("res://systems/native_render/scene_geometry.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const MeshPreparation=preload("res://systems/native_data/mesh_preparation.gd")
const RasterUpload=preload("res://systems/native_data/raster_upload_preparation.gd")
const NativeDrawCache=preload("res://systems/native_render/native_draw_cache_runtime.gd")
const NativeDrawCodec=preload("res://systems/native_render/native_mesh_resource_cache.gd")
const TargetPreview=preload("res://systems/native_render/native_target_preview_shader.gd")
var native_draw_captures: Array=[]
var use_prepared_geometry:=MeshPreparation.configured_enabled()
var use_raster_upload_preparation:=RasterUpload.configured_enabled()
var use_worker_texture_creation:=RasterUpload.configured_worker_texture_creation() and RenderingServer.get_rendering_device()!=null
var ready_raster_uploads: Dictionary={}
var ready_worker_textures: Dictionary={}
var ready_raster_order: Array[String]=[]
var ready_raster_bytes:=0
var raster_upload_counts:={"worker_jobs":0,"worker_rows":0,"worker_declined":0,"accepted":0,"consumed":0,"fallbacks":0,"cached_skips":0,"evictions":0,"invalid_sidecars":0,"invalid_packets":0,"peak_ready_bytes":0}
var raster_upload_threads: Array[int]=[]
const MAX_READY_RASTER_BYTES:=16*1024*1024
var publication_budget_us:=3000
static func configured_scenery_publication_budget() -> int:
	# Private loading-only experiment. The normal shared budget stays at 3 ms.
	var value: Variant=ProjectSettings.get_setting("nwn/private/publication_scenery_budget_us",0)
	return clampi(int(value),3000,8000) if value is int and int(value)>3000 else 0
var scenery_publication_budget_us:=configured_scenery_publication_budget()
static func configured_entry_publication_budget() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--publication-entry-budget-us="):
			var value:=argument.trim_prefix("--publication-entry-budget-us=")
			return clampi(int(value),3000,12000) if value.is_valid_int() else 0
	return 0
var entry_publication_budget_us:=configured_entry_publication_budget()
var publication_world: WeakRef
var _scenery_budget_active:=false
var _scenery_budget_activations:=0
var _scenery_budget_clears:=0
func _observe_scenery_budget(active: bool) -> void:
	if active==_scenery_budget_active:return
	_scenery_budget_active=active
	if active:_scenery_budget_activations+=1
	else:_scenery_budget_clears+=1
func bind_publication_world(world: Node) -> void:
	publication_world=weakref(world) if is_instance_valid(world) else null
	if JoinDiagnostics.enabled and is_instance_valid(world):JoinDiagnostics.bind_area(world,self)
	if is_instance_valid(world) and world.has_meta("native_area_graphics_owner"):
		var owner: Variant=world.get_meta("native_area_graphics_owner")
		if owner!=null and owner.has_method("bind_area_resource_pool"):owner.bind_area_resource_pool(world,self)
func _area_binding_prefix() -> String:
	var world: Node=publication_world.get_ref() if publication_world!=null else null
	return str(world.get_instance_id())+":" if is_instance_valid(world) and world.has_meta("native_area_graphics_owner") else ""
func _area_binding_key(identity: String) -> String:
	return _area_binding_prefix()+identity
func template_binding_key(identity: String) -> String:
	# The source identity is unchanged; only the authoritative pool binding is
	# scoped to the publishing area when one owns this pool.
	return _area_binding_key(identity)
func release_area_bindings(area_id: int) -> void:
	if area_id<=0:return
	var prefix:=str(area_id)+":"
	for key in ready_raster_order.duplicate():
		if key.begins_with(prefix):_take_ready_raster(key)
	for key in templates.keys():
		if str(key).begins_with(prefix):templates.erase(key);template_order.erase(key)
	for key in materials.keys():
		if str(key).begins_with(prefix):materials.erase(key);resource_order.material.erase(key)
	for key in textures.keys():
		if str(key).begins_with(prefix):textures.erase(key);resource_order.texture.erase(key)
	var current: Node=publication_world.get_ref() if publication_world!=null else null
	if is_instance_valid(current) and current.get_instance_id()==area_id:publication_world=null
func publication_budget_limit_us() -> int:
	# The ordinary policy has no world-dependent allowance to resolve.
	if entry_publication_budget_us<=publication_budget_us and scenery_publication_budget_us<=publication_budget_us:return publication_budget_us
	if publication_world==null:
		if scenery_publication_budget_us>publication_budget_us:_observe_scenery_budget(false)
		return publication_budget_us
	var world: Node=publication_world.get_ref()
	if not is_instance_valid(world) or world.is_queued_for_deletion() or world.get("closed")==true or world.get("retiring")==true:
		if scenery_publication_budget_us>publication_budget_us:_observe_scenery_budget(false)
		return publication_budget_us
	var effective:=publication_budget_us
	if entry_publication_budget_us>effective and world.get_meta("native_entry_loading",false):effective=entry_publication_budget_us
	if scenery_publication_budget_us>publication_budget_us:
		var scenery_active: bool=world.get_meta("native_publication_loading",false)
		_observe_scenery_budget(scenery_active)
		if scenery_active:effective=maxi(effective,scenery_publication_budget_us)
	return effective
func publication_callback_budget_us(ordinary_limit: int=3000) -> int:
	var effective:=publication_budget_limit_us()
	return maxi(ordinary_limit,effective) if effective>publication_budget_us else ordinary_limit
var maximum_publications_per_frame:=16
var publication_frame:=-1
var publication_us:=0
var publications:=0
var construction_steps:=0
var priority_publications:=0
var completion_units:=0
var maximum_completion_units_per_frame:=64
var completion_us:=0
var _completion_depth:=0
var _completion_began:=0
var _completion_priority:=false
var cooperative_templates:=false
const JoinDiagnostics=preload("res://systems/native_render/join_publication_diagnostics.gd")
var _foreground_model_frame:=-1
var foreground_model_delivery: Dictionary={}
func _publication_frame() -> void:
	var frame:=int(Engine.get_process_frames())
	if publication_frame!=frame:
		if JoinDiagnostics.enabled and publication_frame>=0 and JoinDiagnostics.owns_pool(self):
			JoinDiagnostics.pool_frame(publication_us,completion_us,publications,construction_steps,completion_units)
		publication_frame=frame;publication_us=0;publications=0;construction_steps=0;priority_publications=0;completion_units=0;completion_us=0
func cooperative_publication() -> bool:return cooperative_templates
func remaining_publication_us() -> int:
	_publication_frame()
	return maxi(1,publication_budget_limit_us()-publication_us-(Time.get_ticks_usec()-_completion_began if _completion_depth>0 else 0))
func can_consume_completion(priority: bool=false) -> bool:
	_publication_frame()
	var elapsed:=publication_us+(Time.get_ticks_usec()-_completion_began if _completion_depth>0 else 0)
	if completion_units+_completion_depth>=maximum_completion_units_per_frame:
		if JoinDiagnostics.enabled and JoinDiagnostics.owns_pool(self):JoinDiagnostics.pool_denied("completion-units")
		return false
	if (priority and priority_publications==0 and not _completion_priority) or _completion_depth==0 and completion_units==0 and publications==0 and construction_steps==0:return true
	var available:=elapsed<publication_budget_limit_us()
	if not available and JoinDiagnostics.enabled and JoinDiagnostics.owns_pool(self):JoinDiagnostics.pool_denied("completion-time")
	return available
func reserve_foreground_model_completion()->bool:
	var frame:=int(Engine.get_process_frames())
	if _foreground_model_frame==frame or not JoinDiagnostics.enabled or not JoinDiagnostics.owns_pool(self):return false
	var world: Node=publication_world.get_ref() if publication_world!=null else null
	if not is_instance_valid(world) or world.closed or world.retiring or not world.ready_for_control():return false
	if not can_consume_completion():return false
	_foreground_model_frame=frame
	return true
func record_foreground_model_delivery(decoder: String,prepared_us: int,early: bool)->void:
	if prepared_us<=0 or not JoinDiagnostics.enabled or not JoinDiagnostics.owns_pool(self):return
	var delay:=(Time.get_ticks_usec()-prepared_us)/1000.0
	var stats: Dictionary=foreground_model_delivery.get_or_add(decoder,{"samples":0,"early":0,"totalMs":0.0,"maxMs":0.0,"over100ms":0})
	stats.samples+=1
	stats.early+=int(early)
	stats.totalMs+=delay
	stats.maxMs=maxf(float(stats.maxMs),delay)
	stats.over100ms+=int(delay>100.0)
func begin_completion_scope() -> void:
	_publication_frame()
	if _completion_depth==0:_completion_began=Time.get_ticks_usec();_completion_priority=false
	_completion_depth+=1
func begin_prioritized_completion_scope(priority: bool) -> void:
	begin_completion_scope();_completion_priority=_completion_priority or priority
func end_completion_scope() -> void:
	if _completion_depth<1:return
	_completion_depth-=1
	if _completion_depth==0:
		var elapsed:=Time.get_ticks_usec()-_completion_began;publication_us+=elapsed;completion_us+=elapsed;_completion_began=0
		if _completion_priority:priority_publications+=1
		_completion_priority=false
	completion_units+=1
func can_publish(priority: bool=false) -> bool:
	_publication_frame()
	var elapsed:=publication_us+(Time.get_ticks_usec()-_completion_began if _completion_depth>0 else 0)
	if (priority and priority_publications==0) or publications==0 and construction_steps==0 and completion_units==0:return true
	var time_available:=elapsed<publication_budget_limit_us()
	var unit_available:=publications<maximum_publications_per_frame
	if JoinDiagnostics.enabled and (not time_available or not unit_available) and JoinDiagnostics.owns_pool(self):
		if not time_available:JoinDiagnostics.pool_denied("publication-time")
		if not unit_available:JoinDiagnostics.pool_denied("publication-units")
	return time_available and unit_available
func construction_finished(began: int) -> void:
	_publication_frame()
	if _completion_depth==0:publication_us+=Time.get_ticks_usec()-began
	construction_steps+=1
func publication_finished(began: int,priority: bool=false) -> void:
	_publication_frame()
	# A nested scene operation is included in its completion callback's outer
	# wall-clock scope. Count the unit once without charging that CPU time twice.
	if _completion_depth==0:publication_us+=Time.get_ticks_usec()-began
	publications+=1
	if priority: priority_publications+=1
var failure := ""
var meshes: Dictionary = {}
var textures: Dictionary = {}
var materials: Dictionary = {}
var unshaded := false
var native_lighting:=false
var native_legacy_lighting:=false
var native_standard:=false # Only after the active native shader profile matches.
var native_surface_output:=false # Research carrier, never selected implicitly.
var texture_filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
var picking := false
var compact_static_parts:=OS.get_cmdline_user_args().has("--static-parts=compact")
var pick_shapes: Dictionary = {}
var hidden_hit_geometry: Dictionary={}
var hidden_hit_order: Array=[]
var templates: Dictionary = {}
var template_preparation_peaks: Array=[]
var template_diagnostic_peaks: Variant=null
var completion_diagnose:=OS.get_cmdline_user_args().has("--publication-completion-diagnose")
var completion_template_peaks: Array=[]
var completion_template_max_us:=0
var completion_template_logged:=0
var template_order: Array=[]
var maximum_templates:=512
var maximum_meshes:=4096
var maximum_textures:=512
var maximum_materials:=2048
class Recency:
	extends RefCounted
	# Cache hits used Array.erase(), which scanned and shifted every retained
	# binding. Material hits are frequent while publishing repeated models.
	var links: Dictionary={}
	var first: Variant=null
	var last: Variant=null
	func is_empty() -> bool:return links.is_empty()
	func size() -> int:return links.size()
	func clear() -> void:links.clear();first=null;last=null
	func erase(key: String) -> void:
		if not links.has(key):return
		var row: Dictionary=links[key]
		var previous: Variant=row.prev;var following: Variant=row.next
		links.erase(key)
		if previous==null:first=following
		else:
			var prior: Dictionary=links[previous];prior.next=following
		if following==null:last=previous
		else:
			var next_row: Dictionary=links[following];next_row.prev=previous
	func touch(key: String) -> void:
		if links.has(key):
			var old: Dictionary=links[key]
			var previous: Variant=old.prev;var following: Variant=old.next
			if previous==null:first=following
			else:
				var prior: Dictionary=links[previous];prior.next=following
			if following==null:last=previous
			else:
				var next_row: Dictionary=links[following];next_row.prev=previous
		var row: Dictionary={"prev":last,"next":null}
		links[key]=row
		if last==null:first=key
		else:
			var previous_last: Dictionary=links[last];previous_last.next=key
		last=key
	func pop_front() -> String:
		if first==null:return ""
		var key: String=first
		var following: Variant=links[key].next
		links.erase(key);first=following
		if following==null:last=null
		else:
			var row: Dictionary=links[following];row.prev=null
		return key
var resource_order:={"mesh":Recency.new(),"texture":Recency.new(),"material":Recency.new()}
var stats := {"meshes_created":0,"textures_created":0,"materials_created":0,"mesh_hits":0,"texture_hits":0,"material_hits":0,"native_decompressions":0,"templates_created":0,"template_hits":0,"template_evictions":0,"mesh_evictions":0,"texture_evictions":0,"material_evictions":0,"prepared_mesh_uses":0,"main_mesh_preparations":0,"prepared_hidden_uses":0}
var model_geometry_records: Dictionary={}
var model_geometry_leases: Dictionary={}
var model_geometry_stats: Dictionary={"created":0,"reused":0,"retired":0,"active":0,"owners":0}
var model_geometry_sources: Array=[]
func renderer_geometry_token(source: Dictionary,source_sha: String,index: int,data: Dictionary) -> Resource:
	for row in model_geometry_sources:
		if is_same(row.source,source):return row.token
	var token:=RendererGeometryToken.new()
	token.source_sha=source_sha;token.node_index=index;token.mesh_data=data
	model_geometry_sources.append({"source":source,"token":token})
	return token
func acquire_model_geometry(object: MeshInstance3D) -> bool:
	if not is_instance_valid(object):return false
	var token: Variant=object.get_meta("native_renderer_geometry_token",null)
	if token==null:return false
	var owner_id:=object.get_instance_id()
	if model_geometry_leases.has(owner_id):return true
	failure=""
	var id: int=int(token.get_instance_id())
	if not model_geometry_records.has(id):
		var resource: ArrayMesh=prepare_geometry(token.source_sha,token.node_index,token.mesh_data,false,false) if token.current==null else token.current
		if resource==null:return false
		token.current=resource
		model_geometry_records[id]={"resource":resource,"token":token,"owners":0}
		model_geometry_stats.created+=1;model_geometry_stats.active+=1
	else:model_geometry_stats.reused+=1
	object.mesh=model_geometry_records[id].resource
	model_geometry_records[id].owners+=1;model_geometry_stats.owners+=1
	model_geometry_leases[owner_id]={"object":weakref(object),"record":id}
	return true
func release_model_geometry(object: MeshInstance3D) -> bool:
	if not is_instance_valid(object):return false
	return release_model_geometry_id(object.get_instance_id())
func release_model_geometry_id(owner_id: int) -> bool:
	if not model_geometry_leases.has(owner_id):return false
	var lease: Dictionary=model_geometry_leases[owner_id]
	model_geometry_leases.erase(owner_id)
	var id:=int(lease.record)
	if not model_geometry_records.has(id):return false
	var record: Dictionary=model_geometry_records[id]
	var original: Mesh=record.resource
	var object: MeshInstance3D=lease.object.get_ref()
	var unchanged: bool=is_instance_valid(object) and object.mesh==original
	if unchanged:object.mesh=null
	record.owners-=1;model_geometry_stats.owners-=1
	if int(record.owners)==0:
		record.token.current=null
		model_geometry_records.erase(id)
		model_geometry_stats.retired+=1;model_geometry_stats.active-=1
	return unchanged
func touch(kind: String,key: String) -> void:
	resource_order[kind].touch(key)
func retain(kind: String,entries: Dictionary,key: String,value: Resource,limit: int) -> void:
	# These bounds cover cache bindings, not resources still referenced by live
	# models/templates. Dropping a binding never changes an admitted instance.
	if limit<=0: return
	while not resource_order[kind].is_empty() and entries.size()>=limit:
		var oldest: String=resource_order[kind].pop_front()
		entries.erase(oldest); stats[kind+"_evictions"]+=1
		if kind=="mesh": pick_shapes.erase(oldest)
	entries[key]=value; touch(kind,key)
func main_thread() -> bool:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): failure = "Native render resources must be published on the main thread"; return false
	return true
func begin_native_model(bundle: Dictionary) -> Dictionary:
	var context:=NativeDrawCache.begin_model(bundle)
	if bool(bundle.get("tile_initial_skin",false)):
		context.tile_initial_skin=true
		context.tile_source_sha=str(bundle.get("sha256",""))
		context.tile_model=bundle.value
		context.tile_skins={}
	if not context.is_empty():native_draw_captures.append(context)
	return context
func end_native_model(context: Dictionary) -> void:
	if context.is_empty():return
	native_draw_captures.erase(context)
	if context.has("facade"):NativeDrawCache.end_model(context)
func suspend_native_model(context: Dictionary) -> void:
	# A cooperative builder retains its ticket, never an active capture scope.
	# Unrelated model publication between steps cannot enter that ticket.
	native_draw_captures.erase(context)
func resume_native_model(context: Dictionary) -> void:
	if not context.is_empty() and not native_draw_captures.has(context):native_draw_captures.append(context)
func capture_native_geometry(source_sha: String,index: int,rigid_skin: bool,mesh: ArrayMesh) -> void:
	for context in native_draw_captures:
		if context.has("facade"):NativeDrawCache.capture(context,source_sha,index,rigid_skin,mesh)
func initial_tile_skin(source_sha: String,index: int) -> Dictionary:
	for context in native_draw_captures:
		if not bool(context.get("tile_initial_skin",false)) or str(context.get("tile_source_sha",""))!=source_sha:continue
		var model: Dictionary=context.tile_model
		if index<0 or index>=model.nodes.size() or not model.nodes[index].has("skin"):return {}
		var skins: Dictionary=context.tile_skins
		if not skins.has(index):skins[index]=MeshPreparation.initial_skin(model,index)
		return skins[index]
	return {}
func model_template(bundle: Dictionary):
	var began:=Time.get_ticks_usec() if completion_diagnose else Timing.begin()
	var prior_hits:=int(stats.template_hits) if completion_diagnose else 0
	var result=prepare_model_template(bundle)
	if completion_diagnose:_record_completion_template(bundle,result,Time.get_ticks_usec()-began,int(stats.template_hits)>prior_hits)
	Timing.finish("publication_template_cpu_ms",began); return result
func _record_completion_template(bundle: Dictionary,template,elapsed_us: int,cache_hit: bool) -> void:
	if elapsed_us<5000:return
	var row: Dictionary={"model":str(bundle.get("resource_name",bundle.value.name)).get_file().substr(0,96),"sha256":str(bundle.get("sha256","")),"callback_us":elapsed_us,"cache_hit":cache_hit,"phase_ms":template.preparation_timings.duplicate(true) if template!=null and not cache_hit else {},"failure":template==null}
	completion_template_peaks.append(row)
	completion_template_peaks.sort_custom(func(a,b):return int(a.callback_us)>int(b.callback_us))
	if completion_template_peaks.size()>8:completion_template_peaks.resize(8)
	if elapsed_us>completion_template_max_us and completion_template_logged<16:
		completion_template_max_us=elapsed_us;completion_template_logged+=1
		print("NWN62_TEMPLATE_TAIL ",JSON.stringify(row))
func prepare_model_template(bundle: Dictionary):
	if not main_thread(): return null
	failure=""
	var key:=_area_binding_key(Template.identity(bundle,self))
	if templates.has(key):
		stats.template_hits+=1; template_order.erase(key); template_order.append(key)
		return templates[key]
	var template:=Template.new()
	if not template.build(bundle,self): failure=template.failure; return null
	return _remember_template(key,bundle,template)
func _remember_template(key: String,bundle: Dictionary,template):
	# A cooperative peer may have published this identity while we yielded.
	# Preserve its binding/first-root ownership and keep exactly one LRU entry.
	if templates.has(key):
		stats.template_hits+=1;template_order.erase(key);template_order.append(key);return templates[key]
	if int(template.get("recipe_capture_successes"))>0:stats.recipe_templates_created=int(stats.get("recipe_templates_created",0))+1
	if template.diagnose_staged:
		# Private opt-in receipt, retained only for the eight largest completed
		# staged invocations. No extra clocks, scans or containers in normal play.
		if template_diagnostic_peaks==null:template_diagnostic_peaks=[]
		template_diagnostic_peaks.append({"model":str(bundle.get("resource_name",bundle.value.name)),"sha256":str(bundle.sha256),"step":template.staged_diagnostic_peak_step.duplicate(true),"phase_max_us":template.staged_diagnostic_phase_max_us.duplicate(),"staged_steps":int(template.staged_steps)})
		template_diagnostic_peaks.sort_custom(func(a,b):return int(a.step.get("step_us",0))>int(b.step.get("step_us",0)))
		if template_diagnostic_peaks.size()>8:template_diagnostic_peaks.resize(8)
	if not template.preparation_timings.is_empty():
		var measured: Dictionary=template.preparation_timings.duplicate(); measured.model=str(bundle.get("resource_name",bundle.value.name)); measured.sha256=str(bundle.sha256)
		if bool(measured.get("staged",false)):
			# Total active CPU spans yields; retain the actual largest invocation
			# separately so a per-model step tail is not inferred from that total.
			measured.staged_max_step_us=int(template.staged_max_step_us);measured.staged_steps=int(template.staged_steps)
		template_preparation_peaks.append(measured); template_preparation_peaks.sort_custom(func(a,b):return float(a.total_ms)>float(b.total_ms))
		if template_preparation_peaks.size()>16: template_preparation_peaks.resize(16)
	stats.templates_created+=1
	if maximum_templates>0:
		while not template_order.is_empty() and templates.size()>=maximum_templates:
			templates.erase(template_order.pop_front()); stats.template_evictions+=1
		templates[key]=template; template_order.append(key)
	return template
static func point(values: PackedFloat32Array, index: int) -> Vector3:
	return Vector3(values[index*3], values[index*3+2], -values[index*3+1])
func model_template_step(bundle: Dictionary,pending: Dictionary,maximum_units: int=8,budget_us: int=1500) -> Dictionary:
	if not main_thread():return {"status":"failed","reason":failure}
	if not Template.cooperative(self):
		var synchronous=model_template(bundle)
		return {"status":"ready" if synchronous!=null else "failed","template":synchronous,"reason":failure}
	var key:=_area_binding_key(Template.identity(bundle,self))
	# Each stream pins the request's source row until completion. A caller asking
	# for another key must not receive this job's success or failure as its own.
	if not pending.is_empty():
		if int(pending.pool)!=get_instance_id():cancel_template_step(pending);return {"status":"failed","reason":"Staged template pool changed"}
		# The current source identity already includes any mutation to this exact
		# Dictionary and current pool policy. A distinct request still needs its
		# own pinned-source validation before it can resume or replace this job.
		var pending_key: String=key if is_same(pending.bundle,bundle) else _area_binding_key(Template.identity(pending.bundle,self))
		if pending_key!=str(pending.key):cancel_template_step(pending);return {"status":"pending","phase":"policy-invalidated","units":0}
		if str(pending.key)!=key:return {"status":"pending","phase":"resume-original-source","active_key":str(pending.key),"requested_key":key,"units":0}
		if templates.has(key):
			cancel_template_step(pending);stats.template_hits+=1;template_order.erase(key);template_order.append(key)
			return {"status":"ready","template":templates[key],"created":false}
		var progress: Dictionary=pending.template.staged_build_step(maximum_units,budget_us)
		progress.key=key
		if progress.status=="failed":failure=str(progress.reason);pending.clear();return progress
		if progress.status=="pending":return progress
		var finished_key:=str(pending.key);var finished=_remember_template(finished_key,pending.bundle,pending.template);pending.clear()
		if finished_key==key:return {"status":"ready","template":finished,"created":true}
	if templates.has(key):
		stats.template_hits+=1;template_order.erase(key);template_order.append(key)
		return {"status":"ready","template":templates[key],"created":false}
	var builder:=Template.new()
	if not builder.begin_staged_build(bundle,self):failure=builder.failure;return {"status":"failed","reason":failure}
	pending.merge({"key":key,"pool":get_instance_id(),"bundle":bundle,"template":builder})
	return {"status":"pending","phase":"begin","units":0}
func cancel_template_step(pending: Dictionary) -> void:
	if pending.has("template"):pending.template.cancel_staged_build()
	pending.clear()
func raster_upload_preparation_active() -> bool:return use_raster_upload_preparation or use_worker_texture_creation
func accept_raster_upload_sidecar(sidecar: Dictionary) -> int:
	if not (use_raster_upload_preparation or use_worker_texture_creation) or not main_thread():return 0
	if sidecar.get("revision")!=RasterUpload.REVISION or not sidecar.get("rows") is Dictionary or not sidecar.get("stats") is Dictionary or not sidecar.get("thread") is int or int(sidecar.thread)<=0 or int(sidecar.thread)==OS.get_main_thread_id():raster_upload_counts.invalid_sidecars+=1;return 0
	var rows: Dictionary=sidecar.rows
	var gpu_rows: Dictionary={}
	if use_worker_texture_creation:
		if sidecar.get("gpu_revision")!=RasterUpload.WORKER_TEXTURE_REVISION or not sidecar.get("gpu_rows") is Dictionary:raster_upload_counts.invalid_sidecars+=1;return 0
		gpu_rows=sidecar.gpu_rows
		if gpu_rows.size()>rows.size():raster_upload_counts.invalid_sidecars+=1;return 0
	if rows.size()>RasterUpload.MAX_RETAINED_ENTRIES:raster_upload_counts.invalid_sidecars+=1;return 0
	raster_upload_counts.worker_jobs+=1;raster_upload_counts.worker_rows+=rows.size();raster_upload_counts.worker_declined+=int(sidecar.stats.get("declined",0))
	if not raster_upload_threads.has(int(sidecar.thread)) and raster_upload_threads.size()<64:raster_upload_threads.append(int(sidecar.thread))
	var accepted:=0
	for source_key in rows:
		if not source_key is String or not rows[source_key] is Dictionary:raster_upload_counts.invalid_packets+=1;continue
		var key:=_area_binding_key(source_key)
		if textures.has(key):raster_upload_counts.cached_skips+=1;continue
		if ready_raster_uploads.has(key):continue
		var packet: Dictionary=rows[source_key]
		if packet.get("source_sha256")!=source_key or not RasterUpload.packet_supported(packet) or RasterUpload.retained_size(packet)>MAX_READY_RASTER_BYTES:raster_upload_counts.invalid_packets+=1;continue
		var worker_texture: ImageTexture=null
		if use_worker_texture_creation and gpu_rows.has(source_key) and gpu_rows[source_key] is ImageTexture:
			var candidate: ImageTexture=gpu_rows[source_key]
			if candidate.get_rid().is_valid() and candidate.get_width()==int(packet.width) and candidate.get_height()==int(packet.height) and candidate.get_format()==int(packet.format) and candidate.has_mipmaps()==bool(packet.mipmaps):worker_texture=candidate
		var bytes: int=RasterUpload.retained_size(packet)+(packet.bytes.size() if worker_texture!=null else 0)
		if bytes>MAX_READY_RASTER_BYTES:raster_upload_counts.invalid_packets+=1;continue
		while not ready_raster_order.is_empty() and (ready_raster_order.size()>=RasterUpload.MAX_RETAINED_ENTRIES or ready_raster_bytes+bytes>MAX_READY_RASTER_BYTES):_take_ready_raster(ready_raster_order[0]);raster_upload_counts.evictions+=1
		ready_raster_uploads[key]=packet;ready_raster_order.append(key);ready_raster_bytes+=bytes;accepted+=1
		if worker_texture!=null:ready_worker_textures[key]=worker_texture;raster_upload_counts["worker_created_accepted"]=int(raster_upload_counts.get("worker_created_accepted",0))+1
	raster_upload_counts.accepted+=accepted;raster_upload_counts.peak_ready_bytes=maxi(int(raster_upload_counts.peak_ready_bytes),ready_raster_bytes)
	return accepted
func _take_ready_raster(key: String) -> Dictionary:
	var had_worker_texture:=ready_worker_textures.has(key)
	if had_worker_texture:ready_worker_textures.erase(key)
	if not ready_raster_uploads.has(key):return {}
	var packet: Dictionary=ready_raster_uploads[key];ready_raster_bytes-=RasterUpload.retained_size(packet)+(packet.bytes.size() if had_worker_texture else 0);ready_raster_uploads.erase(key);ready_raster_order.erase(key);return packet
func texture(record: Dictionary) -> Texture2D:
	var began:=Timing.begin(); var result:=prepare_texture(record)
	Timing.finish("publication_texture_cpu_ms",began); return result
static func complete_s3tc_mip_tail(mips: Array,format: String) -> PackedByteArray:
	# Image.create_from_data needs a terminal 1x1 chain. Preserve every authored
	# level verbatim; derive only missing levels from the last authored image.
	if mips.is_empty() or format not in ["rgba8","dxt1_rgb","dxt1_rgba","dxt3","dxt5"]: return PackedByteArray()
	var last: Dictionary=mips.back(); var width:=int(last.width); var height:=int(last.height)
	var previous: PackedByteArray=last.data; var tail:=PackedByteArray()
	while width>1 or height>1:
		var next_width:=maxi(1,width>>1); var next_height:=maxi(1,height>>1)
		var next:=PackedByteArray()
		if format=="rgba8":
			next.resize(next_width*next_height*4)
			for y in next_height:
				for x in next_width:
					var source:=((mini(height-1,y*2)*width)+mini(width-1,x*2))*4; var dest:=(y*next_width+x)*4
					for channel in 4: next[dest+channel]=previous[source+channel]
		else:
			var size:=8 if format in ["dxt1_rgb","dxt1_rgba"] else 16
			var previous_columns:=(width+3)/4; var next_columns:=(next_width+3)/4; var next_rows:=(next_height+3)/4
			next.resize(next_columns*next_rows*size)
			for by in next_rows:
				for bx in next_columns:
					var source:=(mini((height+3)/4-1,by*2)*previous_columns+mini(previous_columns-1,bx*2))*size
					var dest:=(by*next_columns+bx)*size
					for index in size: next[dest+index]=previous[source+index]
		tail.append_array(next); previous=next; width=next_width; height=next_height
	return tail
func prepare_texture(record: Dictionary) -> Texture2D:
	if not main_thread(): return null
	var key := _area_binding_key(str(record.sha256))
	if textures.has(key):
		stats.texture_hits += 1; touch("texture",key)
		if use_raster_upload_preparation or use_worker_texture_creation:_take_ready_raster(key)
		return textures[key]
	if use_worker_texture_creation and ready_worker_textures.has(key):
		var prepared: Dictionary=ready_raster_uploads.get(key,{})
		var precreated: ImageTexture=ready_worker_textures[key]
		var valid_worker:=RasterUpload.valid(record,prepared) and precreated.get_rid().is_valid() and precreated.get_width()==int(prepared.width) and precreated.get_height()==int(prepared.height) and precreated.get_format()==int(prepared.format) and precreated.has_mipmaps()==bool(prepared.mipmaps)
		_take_ready_raster(key)
		if valid_worker:
			retain("texture",textures,key,precreated,maximum_textures);stats.textures_created+=1
			stats["worker_textures_used"]=int(stats.get("worker_textures_used",0))+1
			if str(record.value.get("format",""))=="etc1":stats.native_decompressions+=1
			return precreated
		raster_upload_counts["worker_invalid_fallbacks"]=int(raster_upload_counts.get("worker_invalid_fallbacks",0))+1
	var data: Dictionary = record.value; var mips: Array = data.mips
	if mips.is_empty(): failure = "Native raster has no image levels"; return null
	var width := int(data.width); var height := int(data.height)
	var image_format: int = {"rgba8":Image.FORMAT_RGBA8,"dxt1_rgb":Image.FORMAT_DXT1,"dxt1_rgba":Image.FORMAT_DXT1,"dxt3":Image.FORMAT_DXT3,"dxt5":Image.FORMAT_DXT5,"etc1":Image.FORMAT_ETC,"bc6h_signed":Image.FORMAT_BPTC_RGBF,"bc6h_unsigned":Image.FORMAT_BPTC_RGBFU}.get(data.format,-1)
	if image_format < 0: failure = "Native upload format is unavailable"; return null
	var partial_chain:=mips.size()>1 and (int(mips.back().width)!=1 or int(mips.back().height)!=1)
	if partial_chain and not bool(data.get("s3tc_source",false)): failure = "Partial native mip chain needs completion before upload"; return null
	var image: Image=null
	if use_raster_upload_preparation or use_worker_texture_creation:
		var packet:=_take_ready_raster(key)
		if not packet.is_empty():image=RasterUpload.image(record,packet)
	if image==null:
		if use_raster_upload_preparation or use_worker_texture_creation:raster_upload_counts.fallbacks+=1
		var bytes := PackedByteArray()
		for mip in mips: bytes.append_array(mip.data)
		if partial_chain:
			var tail:=complete_s3tc_mip_tail(mips,str(data.format))
			if tail.is_empty(): failure="S3TC partial mip chain cannot be completed"; return null
			bytes.append_array(tail)
		image = Image.create_from_data(width,height,mips.size()>1,image_format,bytes)
		if image == null or image.is_empty(): failure = "Native image construction failed"; return null
		# Native desktop fallback avoids an unsupported compressed-format readback.
		if image_format == Image.FORMAT_ETC:
			if image.decompress() != OK: failure = "Native ETC decompression failed"; return null
			stats.native_decompressions += 1
		if bool(data.get("generate_mips",false)) and image.generate_mipmaps() != OK: failure = "Native mip generation failed"; return null
	else:
		raster_upload_counts.consumed+=1
		stats["prepared_raster_uses"]=int(stats.get("prepared_raster_uses",0))+1
		if image_format==Image.FORMAT_ETC:stats.native_decompressions+=1
	var result := ImageTexture.create_from_image(image)
	retain("texture",textures,key,result,maximum_textures); stats.textures_created += 1
	return result
func geometry(source_sha: String, index: int, data: Dictionary, rigid_skin: bool=false) -> ArrayMesh:
	var began:=Timing.begin(); var result:=prepare_geometry(source_sha,index,data,rigid_skin)
	Timing.finish("publication_mesh_cpu_ms",began); return result
func prepare_geometry(source_sha: String, index: int, data: Dictionary, rigid_skin: bool=false,retain_mesh: bool=true) -> ArrayMesh:
	if not main_thread(): return null
	var tile_skin: Dictionary=initial_tile_skin(source_sha,index)
	if not tile_skin.is_empty() and not str(tile_skin.get("error","")).is_empty():failure=str(tile_skin.error);return null
	var tile_vertices: PackedVector3Array=tile_skin.get("vertices",PackedVector3Array())
	var key := Cache.key(source_sha,"mesh:"+str(index)+("-rigid-skin" if rigid_skin else "")+("-tile-rest-skin-v1" if not tile_vertices.is_empty() else "")+("-pick" if picking else ""))
	if retain_mesh and meshes.has(key):
		stats.mesh_hits+=1;touch("mesh",key);capture_native_geometry(source_sha,index,rigid_skin,meshes[key]);return meshes[key]
	var phase_began:=Timing.begin()
	var vertices: PackedFloat32Array = data.vertices; var source_indices: PackedInt32Array = data.indices
	if vertices.size() % 3 != 0 or source_indices.size() % 3 != 0: failure = "Invalid native mesh stream lengths"; return null
	if vertices.is_empty() or source_indices.is_empty(): return null
	var source_count := vertices.size()/3; var positions := PackedVector3Array(); var normals := PackedVector3Array(); var uv := PackedVector2Array(); var indices:=PackedInt32Array()
	var prepared: Dictionary=data.get("native_upload",{}) if use_prepared_geometry and tile_vertices.is_empty() else {}
	if prepared.is_empty():
		stats.main_mesh_preparations+=1
		prepared=MeshPreparation.prepare(data,tile_vertices)
	else: stats.prepared_mesh_uses+=1
	if not valid_prepared(prepared,source_count,source_indices.size()):
		failure=str(prepared.get("error",""))
		if failure.is_empty():failure="Invalid prepared native geometry"
		return null
	positions=prepared.draw_positions; normals=prepared.draw_normals; uv=prepared.draw_uv
	# The old buildModelGeometry made non-indexed triangle corners. The indexed
	# original stream remains in native_scene_geometry and native_pick_geometry.
	var count:=positions.size()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions; arrays[Mesh.ARRAY_NORMAL] = normals; arrays[Mesh.ARRAY_TEX_UV] = uv
	var original_colors: PackedByteArray=data.get("vertex_colors",PackedByteArray())
	if not original_colors.is_empty():
		if original_colors.size()!=source_count*4: failure="Native vertex color count does not match geometry"; return null
		arrays[Mesh.ARRAY_COLOR]=prepared.draw_colors
	if rigid_skin:
		var bones:=PackedInt32Array(); var weights:=PackedFloat32Array(); bones.resize(count*4); weights.resize(count*4); bones.fill(0); weights.fill(0)
		for vertex in count: weights[vertex*4]=1.0
		arrays[Mesh.ARRAY_BONES]=bones; arrays[Mesh.ARRAY_WEIGHTS]=weights
	Timing.finish("publication_mesh_arrays_ms",phase_began); phase_began=Timing.begin()
	var mesh: ArrayMesh=null
	var native_buffers: Dictionary=data.get("native_draw_buffers",{}) if not rigid_skin and tile_vertices.is_empty() else {}
	if not native_buffers.is_empty() and NativeDrawCodec.valid_buffers(native_buffers) and native_buffers.surfaces.size()==1 and int(native_buffers.surfaces[0].vertex_count)==count and int(native_buffers.surfaces[0].get("index_count",-1))==indices.size():
		mesh=NativeDrawCodec.new().restore_draw_buffers(native_buffers)
		if mesh!=null:stats.native_draw_buffer_hits=int(stats.get("native_draw_buffer_hits",0))+1
	if mesh==null:
		mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# Optional merge workers reuse the immutable prepared CPU draw streams;
	# retrieving them must not force a GPU buffer readback per placement.
	if OS.get_cmdline_user_args().has("--static-scenery=merged") or OS.get_cmdline_user_args().has("--base-scenery-draw=merged"):mesh.set_meta("native_cpu_draw_streams",arrays)
	Timing.finish("publication_mesh_submit_ms",phase_began); phase_began=Timing.begin()
	var hit:=PickGeometry.new(); hit.vertices=prepared.positions; hit.indices=prepared.indices; hit.bounds=prepared.pick_bounds; mesh.set_meta("native_pick_geometry",hit)
	var scene_faces:=SceneGeometry.new(); scene_faces.configure(data,prepared); mesh.set_meta("native_scene_geometry",scene_faces)
	Timing.finish("publication_mesh_collision_ms",phase_began); phase_began=Timing.begin()
	if picking:
		mesh.set_meta("native_pick_shape",hit.get_shape())
	Timing.finish("publication_mesh_pick_ms",phase_began); phase_began=Timing.begin()
	if retain_mesh:
		retain("mesh",meshes,key,mesh,maximum_meshes)
		if maximum_meshes>0 and picking: pick_shapes[key]=mesh.get_meta("native_pick_shape")
	stats.meshes_created += 1
	capture_native_geometry(source_sha,index,rigid_skin,mesh)
	Timing.finish("publication_mesh_cache_ms",phase_began)
	return mesh
static func valid_prepared(value: Dictionary,count: int,indices: int) -> bool:
	return value.get("revision")==MeshPreparation.REVISION and value.get("positions") is PackedVector3Array and value.positions.size()==count and value.get("normals") is PackedVector3Array and value.normals.size()==count and value.get("uv") is PackedVector2Array and value.uv.size()==count and value.get("indices") is PackedInt32Array and value.indices.size()==indices and value.get("draw_positions") is PackedVector3Array and value.draw_positions.size()==indices and value.get("draw_normals") is PackedVector3Array and value.draw_normals.size()==indices and value.get("draw_uv") is PackedVector2Array and value.draw_uv.size()==indices and value.get("draw_colors") is PackedColorArray and value.get("pick_bounds") is AABB and value.get("source_bounds") is AABB and value.get("planes") is PackedFloat32Array
func hidden_geometry(source_sha: String,index: int,data: Dictionary) -> Resource:
	if not main_thread(): return null
	var key:=Cache.key(source_sha,"hidden-hit:"+str(index))
	if hidden_hit_geometry.has(key): hidden_hit_order.erase(key); hidden_hit_order.append(key); return hidden_hit_geometry[key]
	var vertices: PackedFloat32Array=data.vertices; var indices: PackedInt32Array=data.indices
	if vertices.size()%3!=0 or indices.size()%3!=0: failure="Invalid native hidden hit geometry"; return null
	# placeable_hit_mesh.js keeps the valid faces of an otherwise malformed
	# hidden trimesh. Preserve their source order and omit only invalid faces.
	var valid_faces:=PackedInt32Array(); var skipped_face:=false
	for face in range(0,indices.size(),3):
		var face_valid:=true
		for corner in 3:
			var vertex_index:=int(indices[face+corner])
			if vertex_index<0 or vertex_index>=vertices.size()/3 or not point(vertices,vertex_index).is_finite(): face_valid=false; break
		if face_valid:
			for corner in 3: valid_faces.append(int(indices[face+corner]))
		else: skipped_face=true
	if valid_faces.is_empty(): failure="Native hidden hit geometry has no valid triangles"; return null
	var hit:=PickGeometry.new(); var prepared: Dictionary=data.get("native_upload",{}) if use_prepared_geometry else {}
	var scene_data: Dictionary=data
	if skipped_face:
		# Compact only this malformed hidden-pick stream. Stale prepared planes,
		# bounds and collision indices still describe the rejected triangles.
		prepared={}
		var compact_vertices:=PackedFloat32Array()
		var compact_indices:=PackedInt32Array()
		for source_index in valid_faces:
			var at:=int(source_index)*3
			compact_vertices.append_array(PackedFloat32Array([vertices[at],vertices[at+1],vertices[at+2]]))
			compact_indices.append(compact_indices.size())
		scene_data=data.duplicate()
		scene_data.vertices=compact_vertices
		scene_data.indices=compact_indices
		for name in ["collision_indices","native_planes","native_surface_types","native_upload"]: scene_data.erase(name)
		vertices=compact_vertices; indices=compact_indices
	if not prepared.is_empty():
		if not valid_prepared(prepared,vertices.size()/3,indices.size()): failure="Invalid prepared native geometry"; return null
		hit.vertices=prepared.positions; hit.indices=prepared.indices; hit.bounds=prepared.pick_bounds; stats.prepared_hidden_uses+=1
	else:
		hit.vertices.resize(vertices.size()/3); hit.indices=indices.duplicate()
		for vertex in hit.vertices.size():
			hit.vertices[vertex]=point(vertices,vertex)
			hit.bounds=hit.bounds.expand(hit.vertices[vertex]) if vertex>0 else AABB(hit.vertices[vertex],Vector3.ZERO)
		for face in range(0,hit.indices.size(),3):
			for corner in 3:
				if int(hit.indices[face+corner])<0 or int(hit.indices[face+corner])>=hit.vertices.size(): failure="Native hidden triangle exceeds vertices"; return null
			var second: int=hit.indices[face+1]; hit.indices[face+1]=hit.indices[face+2]; hit.indices[face+2]=second
	var scene_faces:=SceneGeometry.new(); scene_faces.configure(scene_data,prepared); hit.set_meta("native_scene_geometry",scene_faces)
	if maximum_meshes>0:
		while hidden_hit_geometry.size()>=maximum_meshes and not hidden_hit_order.is_empty(): hidden_hit_geometry.erase(hidden_hit_order.pop_front())
		hidden_hit_geometry[key]=hit; hidden_hit_order.append(key)
	return hit
func material(part: Dictionary, raster: Dictionary = {}) -> Material:
	var began:=Timing.begin();var result:=prepare_material(part,raster)
	Timing.finish("publication_material_cpu_ms",began);return result
func model_material_options(part: Dictionary) -> Dictionary:
	# src/model_material.js::modelMaterialOptions: the authored controller base
	# applies even when no alpha animation track exists.
	var properties: Dictionary=part.get("properties",{})
	var raw_alpha: Variant=part.get("alpha")
	if raw_alpha==null: raw_alpha=properties.get("alpha",1)
	var authored_alpha:=float(raw_alpha)
	var opacity:=clampf(authored_alpha,0.0,1.0) if is_finite(authored_alpha) else 1.0
	var data: Dictionary=part.get("mesh",{})
	var raw_hint: Variant=part.get("transparencyHint")
	if raw_hint==null: raw_hint=data.get("transparency_hint",properties.get("transparencyhint",0))
	var numeric_hint:=float(raw_hint)
	var hint:=is_finite(numeric_hint) and numeric_hint!=0.0
	return {"opacity":opacity,"visible":opacity>0.0,"hint":hint,"transparent":hint or opacity<1.0,"depth_write":not hint and opacity>=1.0}
func prepare_material(part: Dictionary, raster: Dictionary = {}) -> Material:
	if not main_thread(): return null
	var options:=model_material_options(part); var opacity: float=options.opacity; var data: Dictionary = part.mesh
	var diffuse: Array = data.get("diffuse",[1.0,1.0,1.0]); var emission: Array = part.get("selfillum",[0.0,0.0,0.0]); var hint: bool = options.hint
	var ambient: Array=data.get("ambient",diffuse)
	var key := _area_binding_key(JSON.stringify([raster.get("sha256",""),diffuse,emission,opacity,hint,unshaded,texture_filter,native_lighting,ambient if native_lighting else [],native_standard,native_surface_output,TargetPreview.source_identity()]))
	if materials.has(key): stats.material_hits += 1; touch("material",key); return materials[key]
	if native_lighting and not unshaded and texture_filter>=0 and texture_filter<BaseMaterial3D.TEXTURE_FILTER_MAX:
		# Publish only the final ShaderMaterial. Avoid the unused StandardMaterial
		# CPU property bag; backend material resources are allocated lazily.
		# A native texture getter returns OBJECT-null. NIL would clear the shader
		# override instead; preserve the original Variant representation as well.
		var original_texture: Texture2D=type_convert(null,TYPE_OBJECT)
		if not raster.is_empty():
			original_texture=texture(raster)
			if original_texture==null:return null
		var alpha_mode:=BaseMaterial3D.TRANSPARENCY_DISABLED
		if options.transparent:alpha_mode=BaseMaterial3D.TRANSPARENCY_ALPHA
		elif not raster.is_empty() and raster.value.format!="dxt1_rgb":alpha_mode=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var configure_began:=Timing.begin()
		var corrected:=preload("res://systems/native_render/native_model_material.gd").new()
		corrected.configure_values(Color(diffuse[0],diffuse[1],diffuse[2],opacity),original_texture,texture_filter,alpha_mode,ambient,emission,native_standard,2,native_surface_output)
		corrected.native_world_fog=native_surface_output
		Timing.finish("publication_material_native_configure_ms",configure_began)
		retain("material",materials,key,corrected,maximum_materials);stats.materials_created+=1
		stats["direct_native_materials"]=int(stats.get("direct_native_materials",0))+1
		return corrected
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(diffuse[0],diffuse[1],diffuse[2],opacity)
	result.roughness = 1; result.metallic = 0; result.cull_mode = BaseMaterial3D.CULL_BACK
	result.texture_repeat = true; result.texture_filter = texture_filter
	if unshaded: result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if options.transparent: result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not options.depth_write: result.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if emission.any(func(value): return float(value)>0): result.emission_enabled = true; result.emission = Color(emission[0],emission[1],emission[2])
	if not raster.is_empty():
		result.albedo_texture = texture(raster)
		if result.albedo_texture == null: return null
		if not hint and opacity >= 1 and raster.value.format != "dxt1_rgb":
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; result.alpha_scissor_threshold = 0.035
	var published: Material=result
	if native_lighting and not unshaded:
		var configure_began:=Timing.begin()
		var corrected:=preload("res://systems/native_render/native_model_material.gd").new(); corrected.configure(result,ambient,emission,native_standard,2,native_surface_output); published=corrected
		corrected.native_world_fog=native_surface_output
		Timing.finish("publication_material_native_configure_ms",configure_began)
	elif preload("res://systems/native_render/native_target_preview_shader.gd").loaded():
		# The old root binder visits every native model mesh material, including
		# unshaded and standard fallback surfaces. Give those the same target
		# uniform stage without enabling the separate camera keyhole effect.
		var target_material:=preload("res://systems/native_render/standard_keyhole_material.gd").new()
		if target_material.configure(result,false):published=target_material
	retain("material",materials,key,published,maximum_materials); stats.materials_created += 1
	return published
func snapshot() -> Dictionary:
	var state:=stats.duplicate()
	state.static_part_layout="compact" if compact_static_parts else "separate"
	state.lighting_policy="native-enhanced-candidate" if native_lighting else "godot"
	state.native_standard_materials=native_standard
	state.native_surface_output=native_surface_output
	state.retained={"templates":templates.size(),"meshes":meshes.size(),"textures":textures.size(),"materials":materials.size(),"pick_shapes":pick_shapes.size(),"hidden_hit_geometry":hidden_hit_geometry.size()}
	state.model_geometry=model_geometry_stats.duplicate()
	state.model_geometry.scope="Live rigid placement leases keyed by parsed source Part; templates retain a source token without draw geometry"
	state.limits={"templates":maximum_templates,"meshes":maximum_meshes,"textures":maximum_textures,"materials":maximum_materials}
	state.mesh_preparation={"enabled":use_prepared_geometry,"revision":MeshPreparation.REVISION,"policy":"Immutable worker upload data; main-thread ArrayMesh/scene publication with legacy fallback"}
	var publication_owner: Node=publication_world.get_ref() if publication_world!=null else null
	state.publication_budget={"frame":publication_frame,"used_us":publication_us,"units":publications,"completion_units":completion_units,"completion_us":completion_us,"budget_us":publication_budget_us,"effective_budget_us":publication_budget_limit_us(),"entry_budget_configured_us":entry_publication_budget_us,"scenery_budget_configured_us":scenery_publication_budget_us,"scenery_loading_active":is_instance_valid(publication_owner) and publication_owner.get_meta("native_publication_loading",false),"maximum_units":maximum_publications_per_frame,"cooperative_templates":cooperative_templates,"scope":"Shared completion callback and scene/GPU submission CPU budget with nested accounting; asynchronous GPU work and indivisible API calls remain separate"}
	state.publication_budget.scenery_transitions={"activations":_scenery_budget_activations,"clears":_scenery_budget_clears,"active":_scenery_budget_active}
	if not foreground_model_delivery.is_empty():state.foreground_model_delivery=foreground_model_delivery.duplicate(true)
	state.raster_upload_preparation={"enabled":use_raster_upload_preparation,"counts":raster_upload_counts.duplicate(),"threads":raster_upload_threads.duplicate(),"ready_entries":ready_raster_uploads.size(),"ready_bytes":ready_raster_bytes,"maximum_ready_bytes":MAX_READY_RASTER_BYTES,"memo":RasterUpload.snapshot()}
	if use_worker_texture_creation:state.worker_texture_creation={"enabled":true,"ready_entries":ready_worker_textures.size(),"memo":RasterUpload.worker_texture_snapshot()}
	state.scope="Cumulative immutable GPU/template cache bindings; not live draw counts or a hard VRAM budget"
	state.template_preparation_peaks=template_preparation_peaks.duplicate(true)
	if Template.configured_staged_diagnostics():state.template_diagnostic_peaks=template_diagnostic_peaks.duplicate(true) if template_diagnostic_peaks!=null else []
	if completion_diagnose:state.completion_template_peaks=completion_template_peaks.duplicate(true)
	state.template_construction=Template.construction_totals()
	if NativeDrawCache.enabled():state.native_draw_cache=NativeDrawCache.snapshot()
	return state
func clear() -> void:
	if completion_diagnose and not completion_template_peaks.is_empty():
		print("NWN62_TEMPLATE_SUMMARY ",JSON.stringify({"top":completion_template_peaks}))
		completion_template_peaks.clear();completion_template_max_us=0;completion_template_logged=0
	ready_worker_textures.clear();ready_raster_uploads.clear();ready_raster_order.clear();ready_raster_bytes=0
	for context in native_draw_captures:
		if context.has("facade"):NativeDrawCache.end_model(context)
	native_draw_captures.clear()
	templates.clear(); template_order.clear(); meshes.clear(); textures.clear(); materials.clear(); pick_shapes.clear()
	model_geometry_stats.retired+=int(model_geometry_stats.active)
	model_geometry_stats.active=0;model_geometry_stats.owners=0
	for record in model_geometry_records.values():record.token.current=null
	model_geometry_records.clear();model_geometry_leases.clear();model_geometry_sources.clear()
	hidden_hit_geometry.clear(); hidden_hit_order.clear()
	for order in resource_order.values(): order.clear()
	if template_diagnostic_peaks!=null:template_diagnostic_peaks.clear();template_diagnostic_peaks=null
