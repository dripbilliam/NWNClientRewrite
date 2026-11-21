extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Native worker jobs ordinarily own only data/FileAccess/RefCounted parsers.
# The private worker-texture option creates immutable ImageTexture resources
# through Forward+; scene consumers and cache ownership stay on the main thread.
signal completed(request_id: int, result: Dictionary)
const Gff = preload("res://systems/native_data/gff_document.gd")
const Table = preload("res://systems/native_data/two_da.gd")
const Binary = preload("res://systems/native_data/binary_data.gd")
const Model = preload("res://systems/native_data/binary_model.gd")
const AsciiModel = preload("res://systems/native_data/ascii_model.gd")
const Raster = preload("res://systems/native_data/texture_data.gd")
const RasterUpload=preload("res://systems/native_data/raster_upload_preparation.gd")
const Cache = preload("res://systems/native_data/prepared_cache.gd")
const Palette = preload("res://systems/native_data/palette_texture.gd")
const GuiPalette=preload("res://systems/native_data/gui_palette_texture.gd")
const ActorModel = preload("res://systems/native_data/actor_model.gd")
const TileSurface = preload("res://systems/native_data/tile_surface.gd")
const ObjectSurface = preload("res://systems/native_data/object_surface.gd")
const UiSkin = preload("res://systems/native_data/ui_skin.gd")
const FontData = preload("res://systems/native_data/font_data.gd")
const WaveData = preload("res://systems/native_data/wave_data.gd")
const SoundSet = preload("res://systems/native_data/sound_set.gd")
const LetterTable=preload("res://systems/native_data/letter_table.gd")
const Ancestors=preload("res://systems/native_data/ancestor_preparation.gd")
const MeshPreparation=preload("res://systems/native_data/mesh_preparation.gd")
const CacheWrites=preload("res://systems/native_data/prepared_write_queue.gd")
const SkinPreparation=preload("res://systems/native_data/skin_preparation.gd")
const Prework=preload("res://systems/native_data/prework_store.gd")
const GuiTextureInfo=preload("res://systems/native_data/gui_texture_info.gd")
const SharedAnimation=preload("res://systems/native_data/shared_animation_preparation.gd")
const NativeDrawCache=preload("res://systems/native_render/native_draw_cache_runtime.gd")
const BaseStaticDrawProof=preload("res://systems/native_render/base_static_draw_proof.gd")
const ModelLimitations=preload("res://systems/native_data/model_limitations.gd")
const ANIMATION_INHERITANCE_REVISION:="full-inherited-clips-v1"
const WORKER_TIMEOUT_ERROR:=Palette.WORKER_TIMEOUT_ERROR
var prework_write:=false # Only the explicit preparation action publishes bundles.
var prework_read:=true
var status_only:=false # Preparation jobs keep/dispose large model graphs on workers.
var skin_preparation_enabled:=SkinPreparation.configured_enabled()
var prepared_write_lease:=false
var native_draw_cache_lease:=false
var catalog
var epoch := 0
var serial := 0
var maximum_workers := mini(4,maxi(1,floori(float(OS.get_processor_count())/2.0)))
var maximum_pending := 128
var worker_timeout_ms := 30000
var high_priority:=false
var ancestor_preparation_enabled:=Ancestors.configured_enabled() # --ancestor-preparation=false retains the measured reference.
var mesh_preparation_enabled:=MeshPreparation.configured_enabled() # Immutable after requests start.
var shared_animation_preparation_enabled:=SharedAnimation.configured_enabled()
var raster_upload_preparation_enabled:=RasterUpload.configured_enabled()
var worker_texture_creation_enabled:=RasterUpload.configured_worker_texture_creation()
var failure := ""
var closed := false
var cache_directory := ""
var pending: Array = []
var running: Dictionary = {}
var jobs: Dictionary = {}
var dispatch_guards: Dictionary = {} # Main-thread admission only; never part of a worker job.
var repairing: Dictionary = {}
var results: Dictionary = {}
var worker_decode_scopes: Dictionary = {}
var worker_decode_deadlines: Dictionary = {}
var mutex := Mutex.new()
var completion_budget_us:=1500
var maximum_completions_per_pass:=8
var completion_pool
var world_texture_worker:=false
var _consuming_completions:=false
const JoinDiagnostics=preload("res://systems/native_render/join_publication_diagnostics.gd")
const FOREGROUND_PREPARED_US:=&"_foreground_prepared_us"
static var _early_foreground_models:=OS.get_cmdline_user_args().has("--benchmark-foreground-model-completion=true")
var _early_completion_frame:=-1
var _early_completion_us:=0
var completion_stats:={"passes":0,"delivered":0,"stale":0,"deferred":0,"reentrant":0,"max_pass_us":0,"max_callback_us":0}
var completion_diagnose:=OS.get_cmdline_user_args().has("--publication-completion-diagnose")
var completion_diagnostic_requests: Dictionary={}
var completion_diagnostic_peaks: Array=[]
var completion_diagnostic_reported_max_us:=0
var completion_diagnostic_logged:=0
var worker_capacity_stats:={"dispatches":0,"completed_slot_reuses":0,"maximum_reserved_active":0,"maximum_inflight":0,"backlog_bound_blocks":0}
var worker_reply_stats:={"completed":0,"failed":0,"cancelled":0,"cpuMs":0.0,"maxQueued":0,"kinds":{}}
func _init() -> void: set_process(false)
func _ready() -> void:
	_bind_completion_pool()
	_refresh_processing()
func _bind_completion_pool() -> void:
	# A world supplies its existing pool through the scene service boundary.
	# Standalone data/UI services retain their own bounded completion drain.
	var ancestor:=get_parent()
	while ancestor!=null and completion_pool==null:
		if ancestor.has_meta("native_publication_pool"):
			completion_pool=ancestor.get_meta("native_publication_pool")
			# Live area texture loads own worker decoding. Standalone UI and
			# character previews have their own publication owners.
			world_texture_worker=ancestor.has_meta("native_area_graphics_owner")
		ancestor=ancestor.get_parent()
func _publish_model_limitations(job: Dictionary,result: Dictionary) -> void:
	if str(result.get("error",""))!="" or int(job.get("type",0))!=2002 or str(job.get("decoder","")) not in ["actor-model","static-model"]:return
	var model: Variant=result.get("value")
	if not model is Dictionary or not model.get("nodes") is Array:return
	var ancestor:=get_parent()
	while ancestor!=null:
		if ancestor.has_meta("native_model_diagnostic"):
			var reporter: Variant=ancestor.get_meta("native_model_diagnostic")
			if reporter is Callable and reporter.is_valid():
				for row in ModelLimitations.entries(model,bool(job.get("options",{}).get("references",false))):reporter.call(row)
			return
		ancestor=ancestor.get_parent()
func _refresh_processing() -> void:
	# The process-owned draw-cache driver maintains its leases independently.
	# Only this service's queued/running jobs need per-frame completion polling.
	var active:=not closed and (not pending.is_empty() or not running.is_empty())
	set_process(active)
	if _early_foreground_models and not active:_detach_foreground_completion()
func _watch_foreground_request(type: int,decoder: String)->bool:
	if not JoinDiagnostics.enabled or type!=2002 or decoder not in ["actor-model","static-model"]:return false
	var owner:=get_parent()
	if not is_instance_valid(owner) or not owner.has_method("publication_current"):return false
	var area:=owner.get_parent()
	return JoinDiagnostics.owns_area(area) and owner.get("admission_parent")==area and JoinDiagnostics.owns_pool(completion_pool)
func _detach_foreground_completion()->void:
	var tree:=get_tree() if is_inside_tree() else null
	if tree!=null and tree.process_frame.is_connected(_deliver_foreground_completion):tree.process_frame.disconnect(_deliver_foreground_completion)
func _deliver_foreground_completion()->void:
	if not JoinDiagnostics.enabled:
		_detach_foreground_completion()
		return
	if closed or high_priority or running.is_empty() or not is_processing() or _consuming_completions:return
	var began:=Timing.begin()
	_consuming_completions=true
	_drain_completed_tasks(true,Time.get_ticks_usec())
	_consuming_completions=false
	Timing.finish("callback_assets",began)
func configure(source) -> void:
	retire_scope(); catalog = source; closed = false
	_bind_completion_pool()
	if CacheWrites.configured_enabled() and not prepared_write_lease: CacheWrites.acquire(); prepared_write_lease=true
	if NativeDrawCache.enabled() and not native_draw_cache_lease:NativeDrawCache.acquire();native_draw_cache_lease=true
func request(name: String, type: int, decoder: String = "bytes", options: Dictionary = {},dispatch_guard: Callable=Callable()) -> int:
	failure = ""
	if closed or catalog == null: failure = "Native asset service is unavailable"; return -1
	if decoder not in ["bytes", "gff", "2da", "mdl-binary", "mdl-original", "raster", "static-model", "actor-model", "gui-icon-v1", "tile-surface-v1", "pwk-surface-v1", "dwk-surface-v1", "dwk-pick-v1", "nui-skin-v1", "font-v1", "bitmap-font-v1", "wave-native-v1", "ssf-native-v1", "ltr-native-v1"]: failure = "Unknown native decoder"; return -1
	if pending.size() + running.size() + repairing.size() >= maximum_pending: failure = "Native asset queue is full"; return -1
	Prework.remember_request(catalog,name,type,decoder,options)
	serial += 1
	if completion_diagnose:completion_diagnostic_requests[serial]={"name":name.get_file().substr(0,96),"type":type,"decoder":decoder,"epoch":epoch}
	var store=catalog.preparation_cache() if catalog.has_method("preparation_cache") else null
	var pool_ready: bool=(raster_upload_preparation_enabled or worker_texture_creation_enabled) and OS.get_thread_caller_id()==OS.get_main_thread_id() and completion_pool is Object and is_instance_valid(completion_pool) and completion_pool.has_method("raster_upload_preparation_active") and completion_pool.raster_upload_preparation_active()
	var job: Dictionary={"id": serial, "name": name, "type": type, "decoder": decoder, "epoch": epoch, "catalog": catalog.fork(), "cache_directory": cache_directory, "options":options.duplicate(true),"memory_store":store,"decoder_store":decoded_store(catalog),"memory_epoch":store.generation() if store!=null else -1,"requested_us":Time.get_ticks_usec(),"raster_upload_preparation":raster_upload_preparation_enabled and pool_ready,"worker_texture_creation":worker_texture_creation_enabled and pool_ready,"prework_write":prework_write,"prework_read":prework_read,"status_only":status_only,"prework_ticket":Prework.current_generation(cache_directory),"nwsync_repair_attempted":false}
	if world_texture_worker and decoder in ["static-model","actor-model"] and not options.has("gui_texture_info"):
		job.texture_worker_timeout_ms=worker_timeout_ms
	if JoinDiagnostics.enabled and _watch_foreground_request(type,decoder):
		job.watch_foreground_delivery=true
		if _early_foreground_models and not high_priority:
			var tree:=get_tree()
			if not tree.process_frame.is_connected(_deliver_foreground_completion):tree.process_frame.connect(_deliver_foreground_completion)
	jobs[serial]=job
	if dispatch_guard.is_valid():dispatch_guards[serial]=dispatch_guard
	pending.append(job)
	worker_reply_stats.maxQueued=maxi(int(worker_reply_stats.maxQueued),pending.size())
	pump()
	return serial
func pump() -> void:
	if closed or pending.is_empty():_refresh_processing();return
	# Completed workers retain their original task/result ownership until the
	# budgeted callback drain joins them. They need not leave CPU workers idle.
	# Retain at most one extra completed wave; max_pending still bounds ALL
	# queued/in-flight requests. A reduced limit never dispatches above either
	# new bound, while already-running tasks finish under their existing lease.
	var worker_limit:=maxi(0,maximum_workers);var active:=0
	for task in running.values():
		if not WorkerThreadPool.is_task_completed(int(task)):active+=1
	while not closed and not pending.is_empty() and active<worker_limit and running.size()<worker_limit*2:
		var job: Dictionary = pending.pop_front()
		if dispatch_guards.has(job.id):
			var guard: Callable=dispatch_guards[job.id]
			dispatch_guards.erase(job.id)
			if not guard.is_valid() or not guard.call():
				jobs.erase(job.id)
				if completion_diagnose:completion_diagnostic_requests.erase(job.id)
				worker_reply_stats.cancelled+=1
				# request() pumps synchronously. Deliver only after its caller has
				# received the ID and installed its completion correlation.
				call_deferred("_skipped_dispatch",int(job.id),int(job.epoch),str(job.name))
				continue
		job.dispatched_us=Time.get_ticks_usec()
		if running.size()>=worker_limit:worker_capacity_stats.completed_slot_reuses+=1
		running[job.id] = WorkerThreadPool.add_task(_work.bind(job), high_priority, "Native NWN asset " + str(job.id))
		active+=1;worker_capacity_stats.dispatches+=1;worker_capacity_stats.maximum_reserved_active=maxi(int(worker_capacity_stats.maximum_reserved_active),active);worker_capacity_stats.maximum_inflight=maxi(int(worker_capacity_stats.maximum_inflight),running.size())
	if not pending.is_empty() and active<worker_limit and running.size()>=worker_limit*2:worker_capacity_stats.backlog_bound_blocks+=1
	_refresh_processing()
func _skipped_dispatch(id: int,source_epoch: int,name: String)->void:
	if closed or epoch!=source_epoch:return
	completed.emit(id,{"id":id,"epoch":source_epoch,"resource_name":name,"error":"Resource prefetch request retired before read","cancelled":true})
	completion_stats.delivered+=1
func prioritize(request_ids: Array) -> void:
	# Reorder only queued work; an executing private-data job is never aborted.
	var ranks: Dictionary={}
	for index in request_ids.size(): ranks[int(request_ids[index])]=index
	pending.sort_custom(func(a,b):return int(ranks.get(int(a.id),2147483647))<int(ranks.get(int(b.id),2147483647)))
func _work(job: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	var reader = job.catalog
	var bytes: PackedByteArray = reader.get_resource(job.name, job.type)
	var result := {"id": job.id, "epoch": job.epoch, "resource_name":str(job.name),"resource_error":reader.failure,"error": reader.failure, "thread": OS.get_thread_caller_id(), "bytes": bytes, "read_ms":(Time.get_ticks_usec()-began)/1000.0}
	var digest_began:=Time.get_ticks_usec();var source_sha:=Cache.digest(bytes) if reader.failure.is_empty() else ""
	var source_digest_ms:=(Time.get_ticks_usec()-digest_began)/1000.0
	result.requested_ms=int(job.requested_us)/1000.0; result.started_ms=began/1000.0
	var memory_key:=""
	var phases:={"service_queue_ms":(int(job.dispatched_us)-int(job.requested_us))/1000.0,"worker_queue_ms":(began-int(job.dispatched_us))/1000.0,"source_digest_ms":source_digest_ms,"memory_lookup_ms":0.0,"model_ms":0.0,"rig_ms":0.0,"textures_ms":0.0,"memory_save_ms":0.0}
	var phase_began:=Time.get_ticks_usec()
	var prework:=Prework.new(); var prework_key:=""; var icon_key:=""
	var eligible: bool=reader.failure.is_empty() and job.decoder in ["actor-model","static-model","gui-icon-v1"] and not str(job.cache_directory).is_empty()
	if eligible and prework.configure(str(job.cache_directory)):
		var preparation_policy: Array=[mesh_preparation_enabled,skin_preparation_enabled,mesh_revision(),"s3tc-textures-v3"]
		if job.decoder in ["actor-model","static-model","gui-icon-v1"]:preparation_policy.append(ANIMATION_INHERITANCE_REVISION)
		if job.decoder=="static-model" and bool(job.options.get("tile_initial_skin",false)):preparation_policy.append("static-tile-skin-v1")
		if shared_animation_preparation_enabled: preparation_policy.append(SharedAnimation.REVISION)
		prework_key=Prework.request_key(str(job.name),int(job.type),str(job.decoder),job.options,source_sha,preparation_policy)
		if job.options.has("icon_descriptor"): icon_key=Cache.key(prework_key,"finished-icon-v1:"+Cache.digest(var_to_bytes(job.options.icon_descriptor)))
		if job.prework_read:
			var saved: Dictionary=prework.load_entry(icon_key,reader,true) if not icon_key.is_empty() else {}
			if Prework.valid_icon(saved.get("data",{})):
				result.prework_icon=saved.data; result.prework_inputs=saved.inputs; result.prework_icon_key=icon_key; result.prework_hit=true; result.worker_ms=(Time.get_ticks_usec()-began)/1000.0
				publish_result(job,result); return
	# Track actual reads and format/absence decisions, including supermodels,
	# palette images and optional emitters. A later catalog must revalidate them.
	reader.failure=str(result.error) # Restore the original read status after a rejected cache entry.
	var inputs=Prework.Inputs.new(reader) if eligible else null
	if inputs!=null:inputs.remember(str(job.name),int(job.type),bytes,source_sha);reader=inputs
	if reader.failure.is_empty() and job.memory_store!=null and job.decoder in ["2da","actor-model","static-model","gui-icon-v1"] and not (job.decoder=="2da" and job.options.get("immutable_source",false)):
		var preparation_revision:="native-preparation-5-vertex-colors"
		if job.decoder in ["actor-model","static-model","gui-icon-v1"]:preparation_revision+=":s3tc-textures-v3"
		if job.decoder in ["actor-model","static-model","gui-icon-v1"]:preparation_revision+=":"+ANIMATION_INHERITANCE_REVISION
		if job.decoder=="static-model" and bool(job.options.get("tile_initial_skin",false)):preparation_revision+=":static-tile-skin-v1"
		if job.decoder in ["actor-model","static-model"]:preparation_revision+=":"+Prework.MODEL_METADATA_REVISION
		if shared_animation_preparation_enabled: preparation_revision+=":"+SharedAnimation.REVISION
		memory_key=Cache.digest(var_to_bytes([preparation_revision,job.decoder,source_sha,job.options,mesh_preparation_enabled,skin_preparation_enabled]))
		var saved: Dictionary=job.memory_store.load_data(memory_key,int(job.memory_epoch))
		phases.memory_lookup_ms=(Time.get_ticks_usec()-phase_began)/1000.0
		if not saved.is_empty():
			result.merge(saved,true); result.cache_hit=true; result.memory_cache_hit=true; result.worker_ms=(Time.get_ticks_usec()-began)/1000.0; result.phases=phases
			attach_shared_rig(job,result,phases)
			result.phases.resource_io=resource_metrics(reader)
			if job.prework_write and not prework_key.is_empty() and result.has("prework_inputs"):
				result.prework_saved=prework.save_entry(prework_key,result.prework_inputs,bundle_content(result),int(job.prework_ticket))
				if not result.prework_saved: result.prework_error=prework.failure
			result.prework_icon_key=icon_key
			if shared_animation_preparation_enabled: result.worker_ms=(Time.get_ticks_usec()-began)/1000.0
			publish_result(job,result); return
	if job.prework_read and not prework_key.is_empty():
		var saved:=prework.load_entry(prework_key,job.catalog)
		if not saved.is_empty():
			result.merge(saved,true); result.prework_hit=true; result.cache_hit=true; result.prework_icon_key=icon_key
			attach_shared_rig(job,result,phases)
			if job.memory_store!=null and not memory_key.is_empty() and not job.status_only:
				job.memory_store.save_data(memory_key,Cache.digest(var_to_bytes(saved.get("prework_inputs",[]))),saved,int(job.memory_epoch))
			result.worker_ms=(Time.get_ticks_usec()-began)/1000.0; phases.prework_hit=true; result.phases=phases
			publish_result(job,result); return
		reader.failure=str(result.error)
	if reader.failure.is_empty():
		phase_began=Time.get_ticks_usec()
		var standalone_parse: bool=job.decoder in ["2da","mdl-binary","mdl-original","raster"]
		var timed_parse: bool=worker_timeout_ms>0 and (standalone_parse or int(job.get("texture_worker_timeout_ms",0))>0) and not job.options.has("gui_texture_info")
		if timed_parse: _set_decode_scope(int(job.id))
		var decoded := actor_data(reader,str(job.name),bytes,str(job.cache_directory),[],{} if job.options.get("relevant_tracks",false) else null,source_sha) if job.decoder in ["actor-model","gui-icon-v1"] else decode(bytes,int(job.type),"mdl-original" if job.decoder == "static-model" else str(job.decoder),str(job.cache_directory),job.decoder_store,bool(job.options.get("immutable_source",false)),source_sha)
		# Placeable/tile emitters can be driven by original pause/loop clips.
		# Retain those channels on the static-world route too, without expanding
		# inherited actor animation data for every non-animated static model.
		if job.decoder=="static-model" and str(decoded.get("error","")).is_empty() and decoded.value.nodes.any(func(row):return row.has("emitter") or bool(job.options.get("tile_initial_skin",false)) and (bool(row.get("skinned",false)) or row.get("features",[]).has("skin"))):
			decoded=actor_data(reader,str(job.name),bytes,str(job.cache_directory),[],{},source_sha)
		if timed_parse: _set_decode_scope(-1)
		phases.model_ms=(Time.get_ticks_usec()-phase_began)/1000.0
		phases.model_sources=decoded.get("preparation_sources",[])
		if decoded.has("ancestor_preparation"): phases.ancestor_preparation=decoded.ancestor_preparation
		if decoded.has("shared_animation_preparation"): phases.shared_animation_preparation=decoded.shared_animation_preparation
		result.merge(decoded,true)
		if job.decoder=="gui-icon-v1" and str(result.error).is_empty():
			if not result.value.animations.is_empty(): result.error="Animated original GUI icon template needs a native up-pose adapter"
			else:
				var icon_textures_began:=Time.get_ticks_usec()
				result.merge(icon_textures(reader,result.value,job.options.get("icon_layers",[]),str(job.cache_directory)),true)
				phases.icon_textures_ms=(Time.get_ticks_usec()-icon_textures_began)/1000.0
		phase_began=Time.get_ticks_usec()
		if job.decoder in ["actor-model","static-model"] and str(result.error).is_empty() and result.value.has("animations"):
			if not result.has("animation_sources"):
				# Standalone static decoding retains local clips without the actor inheritance chain.
				result.animation_sources=[{"name":str(job.name),"sha256":source_sha,"decoder":"mdl-original"}]
			if shared_animation_preparation_enabled: attach_shared_rig(job,result,phases)
			else: result.value.rig_asset=rig_data(result.value,result.animation_sources,str(job.cache_directory),result.get("animation_binding_nodes"))
		phases.rig_ms=(Time.get_ticks_usec()-phase_began)/1000.0
		# Start the exact-cohort optional read before texture/prework work. Its
		# owned thread joins on this asset worker at publish_result, never main.
		if native_draw_cache_lease:NativeDrawCache.begin_on_worker(job,result)
		phase_began=Time.get_ticks_usec()
		if job.decoder in ["static-model","actor-model"] and str(result.error).is_empty():
			var textures := {}; var dependencies: Array = []; var missing_textures: Array=[]
			var palette_override: Dictionary={}
			# The original tries the next candidate only when reading PLT bytes
			# fails. Once bytes are selected, a corrupt PLT decode is an error.
			var selected_plt:="";var selected_plt_bytes:=PackedByteArray()
			for candidate in job.options.get("plt_candidates",[]):
				if not reader.has_resource(str(candidate),6): continue
				var candidate_bytes: PackedByteArray=reader.get_resource(str(candidate),6)
				if not reader.failure.is_empty():result.plt_candidate_read_failed=true;continue
				selected_plt=str(candidate);selected_plt_bytes=candidate_bytes
				break
			if selected_plt.is_empty() and bool(result.get("plt_candidate_read_failed",false)):reader.failure=""
			if not selected_plt.is_empty():
				palette_override=_prepare_model_palette(job,reader,selected_plt,selected_plt_bytes)
				if not str(palette_override.get("error","")).is_empty():result.error=palette_override.error
			var names: Array[String]=[]; var seen: Dictionary={}
			# Both original ASCII and binary parsers preserve materialNames in
			# physical node order, including dormant meshes and emitter bitmaps.
			for texture_name in result.value.get("materialNames",[]):
				var name:=str(texture_name).to_lower()
				if name in ["","null"] or seen.has(name):continue
				seen[name]=true;names.append(name)
			# Older decoded-model entries predate materialNames while retaining the
			# original mesh and emitter names. Merge those owned node fields before
			# material publication; a cache hit must not omit a drawable bitmap.
			for part in result.value.nodes:
				var node_names: Array=part.get("mesh",{}).get("textures",[]).duplicate()
				if part.get("emitter") is Dictionary:node_names.append(part.emitter.get("texture",""))
				for texture_name in node_names:
					var name:=str(texture_name).to_lower()
					if name in ["","null"] or seen.has(name):continue
					seen[name]=true;names.append(name)
			if str(result.error).is_empty() and not palette_override.is_empty():
				for name in names:
					textures[name]=palette_override
					dependencies.append({"name":name,"sha256":palette_override.sha256,"cache_hit":palette_override.cache_hit,"palette":true})
			elif str(result.error).is_empty() and not names.is_empty():
				var batch:=prepare_model_textures(job,names,inputs!=null)
				# NativeUiAssets.model catches each optional GUI material bitmap
				# failure and still builds the model with its diffuse material.
				# World actor textures retain their existing failure policy.
				var optional_gui_textures: bool=job.decoder=="actor-model" and job.options.has("gui_texture_info")
				var gui_texture_warnings: Array[String]=[]
				for row in batch.rows:
					if not str(row.get("error","")).is_empty() or bool(row.get("missing",false)):
						if optional_gui_textures:
							gui_texture_warnings.append(str(row.name)+": "+(str(row.error) if not str(row.get("error","")).is_empty() else "Original texture unavailable"))
							# ActorInstance requires an explicit empty raster record to
							# select the untextured material for this authored bitmap.
							textures[row.name]={}; missing_textures.append(row.name)
							dependencies.append(row.get("dependency",{"name":row.name,"missing":true}))
							continue
						if not str(row.get("error","")).is_empty():result.error=row.error;break
					textures[row.name]=row.texture
					if row.get("missing",false):missing_textures.append(row.name)
					dependencies.append(row.dependency)
				if not gui_texture_warnings.is_empty():result.gui_texture_warnings=gui_texture_warnings
				if inputs!=null:
					for input_row in batch.inputs:
						var key:=str(input_row.operation)+":"+str(input_row.name)+":"+str(input_row.get("type",""))
						inputs.rows[key]=input_row
			result.textures = textures; result.dependencies = dependencies; result.missing_textures=missing_textures
			if str(result.error).is_empty():
				# loadNetworkSceneAsset passes only the chosen body PLT to buildObject
				# when an override wins. Its emitter lookup therefore has no separate
				# bitmap; do not fetch an extra texture or invent one for that path.
				if not selected_plt.is_empty():result.emitter_textures={}
				else:
					# Reuse the indexed material-name batch for emitter names. This
					# fallback covers only parser names absent from materialNames.
					var prepared_emitters: Dictionary={}
					for part in result.value.nodes:
						if not part.has("emitter"):continue
						var emitter_name:=str(part.emitter.get("texture","")).to_lower()
						if textures.has(emitter_name):prepared_emitters[emitter_name]=textures[emitter_name]
					var emitter:=prepare_emitter_textures(reader,result.value,str(job.cache_directory),prepared_emitters)
					if not str(emitter.error).is_empty(): result.error=emitter.error
					else:
						result.emitter_textures=emitter.textures; result.dependencies.append_array(emitter.dependencies)
		phases.textures_ms=(Time.get_ticks_usec()-phase_began)/1000.0
	phase_began=Time.get_ticks_usec()
	if inputs!=null and str(result.error).is_empty(): result.prework_inputs=inputs.snapshot()
	if job.prework_write and not prework_key.is_empty() and str(result.error).is_empty() and result.get("gui_texture_warnings",[]).is_empty() and not bool(result.get("plt_candidate_read_failed",false)):
		result.prework_saved=prework.save_entry(prework_key,result.prework_inputs,bundle_content(result),int(job.prework_ticket))
		if not result.prework_saved: result.prework_error=prework.failure
	result.prework_icon_key=icon_key
	if not memory_key.is_empty() and str(result.error).is_empty() and result.get("gui_texture_warnings",[]).is_empty() and not job.status_only:
		var content:=bundle_content(result)
		for field in ["cache_hit","timings"]:
			if result.has(field): content[field]=result[field]
		var identities: Array=[]
		for name in result.get("textures",{}): identities.append([name,result.textures[name].get("sha256","missing")])
		for name in result.get("emitter_textures",{}): identities.append(["emitter:"+str(name),result.emitter_textures[name].get("sha256","missing")])
		identities.sort_custom(func(a,b): return str(a[0])<str(b[0]))
		var identity:=Cache.digest(var_to_bytes([memory_key,result.get("animation_sources",[]),identities]))
		job.memory_store.save_data(memory_key,identity,content,int(job.memory_epoch))
	phases.memory_save_ms=(Time.get_ticks_usec()-phase_began)/1000.0
	result.phases=phases
	result.phases.resource_io=resource_metrics(reader)
	result.worker_ms = (Time.get_ticks_usec()-began)/1000.0
	publish_result(job,result)
func publish_result(job: Dictionary,result: Dictionary) -> void:
	if not job.status_only and (bool(job.get("raster_upload_preparation",false)) or bool(job.get("worker_texture_creation",false))) and str(result.get("error","")).is_empty():
		var upload_began:=Time.get_ticks_usec();var sidecar:=RasterUpload.sidecar_on_worker(result,bool(job.get("worker_texture_creation",false)))
		if not sidecar.get("rows",{}).is_empty():result._raster_upload_sidecar=sidecar
		var upload_ms:=(Time.get_ticks_usec()-upload_began)/1000.0
		result.worker_ms=float(result.get("worker_ms",0.0))+upload_ms
		var upload_phases: Dictionary=result.get("phases",{}).duplicate();var upload_stats: Dictionary=sidecar.get("stats",{}).duplicate()
		upload_stats.merge({"enabled":true,"thread":OS.get_thread_caller_id(),"cpu_ms":upload_ms,"maximum_job_bytes":RasterUpload.MAX_JOB_BYTES});upload_phases.raster_upload_preparation=upload_stats;result.phases=upload_phases
	if not job.status_only:
		if OS.get_cmdline_user_args().has("--base-scenery-draw=merged") and job.decoder=="static-model" and str(result.get("error","")).is_empty() and result.get("value") is Dictionary:
			result.static_draw_proof=BaseStaticDrawProof.capture(result.get("bytes",PackedByteArray()),result.value,str(result.get("sha256","")))
		if native_draw_cache_lease:
			var draw_began:=Time.get_ticks_usec();NativeDrawCache.attach_on_worker(job,result)
			result.worker_ms=float(result.get("worker_ms",0.0))+(Time.get_ticks_usec()-draw_began)/1000.0
	var packet:=result
	if job.status_only:
		packet={}
		for field in ["id","epoch","resource_name","error","thread","worker_ms","prework_hit","prework_saved","prework_error"]:
			if result.has(field): packet[field]=result[field]
		result.clear() # Release unused private model/texture graphs on this worker.
	if job.get("watch_foreground_delivery",false):packet[FOREGROUND_PREPARED_US]=Time.get_ticks_usec()
	mutex.lock(); results[job.id]=packet; mutex.unlock()
func bundle_content(result: Dictionary) -> Dictionary:
	var content: Dictionary={}
	for field in ["value","sha256","animation_sources","animation_view_identity","animation_binding_nodes","textures","emitter_textures","dependencies","missing_textures","prework_inputs"]:
		if result.has(field): content[field]=result[field]
	# Normal saves occur before runtime attachment. Also keep this helper safe
	# for later consumers saving an already-delivered result.
	if result.has("native_draw_cache") and content.get("value") is Dictionary:
		var model: Dictionary=content.value.duplicate();var nodes: Array=model.nodes.duplicate();model.nodes=nodes
		for index in nodes.size():
			if not nodes[index].get("mesh",{}).has("native_draw_buffers"):continue
			var row: Dictionary=nodes[index].duplicate();var mesh: Dictionary=row.mesh.duplicate()
			mesh.erase("native_draw_buffers");row.mesh=mesh;nodes[index]=row
		content.value=model
	return content
func attach_shared_rig(job: Dictionary,result: Dictionary,phases: Dictionary) -> void:
	if not shared_animation_preparation_enabled or not result.get("value",{}).has("animations"): return
	# Complete bundle hits already contain calculated rig data. Seed from that
	# immutable candidate instead of re-reading/reconstructing it after eviction.
	var prepared_rig:=shared_rig_data(result.value,result.get("animation_sources",[]),str(job.cache_directory),job.decoder_store,str(result.get("animation_view_identity","")),result.value.get("rig_asset",{}),result.get("animation_binding_nodes"))
	result.value.rig_asset=prepared_rig.value
	phases.shared_rig_preparation={"hit":prepared_rig.hit,"wait_ms":int(prepared_rig.wait_us)/1000.0,"elapsed_ms":prepared_rig.elapsed_ms,"resident":prepared_rig.resident,"first_use":prepared_rig.first_use,"seeded":prepared_rig.seeded,"admitted":prepared_rig.admitted,"derived_cache":SharedAnimation.snapshot(job.decoder_store)}
func prepare_model_textures(job: Dictionary,names: Array[String],track_inputs: bool) -> Dictionary:
	# NetworkScene first settles every bitmap fetch and raises the first read
	# error in source order. Only then does loadTextures start its decode batch.
	# Keep that barrier even though both stages live under this asset worker.
	var single_phase_texture: bool=job.decoder=="actor-model" and job.options.has("gui_texture_info")
	for replacement in job.options.get("texture_overrides",{}).values():
		if replacement is Dictionary:single_phase_texture=true
	if single_phase_texture:
		return _model_texture_batch(job,names,track_inputs,"gui")
	var fetched: Dictionary=_model_texture_batch(job,names,track_inputs,"read")
	for row in fetched.rows:
		if not str(row.get("error","")).is_empty():return {"rows":[row],"inputs":fetched.inputs}
	var decoded: Dictionary=_model_texture_batch(job,names,track_inputs,"decode",fetched.rows)
	decoded.inputs.append_array(fetched.inputs)
	return decoded
func _model_texture_batch(job: Dictionary,names: Array[String],track_inputs: bool,phase: String,prepared: Array=[]) -> Dictionary:
	var lane_count:=mini(4,names.size());var threads: Array=[];var lane_results: Array=[]
	var queue: Dictionary={"next":0,"mutex":Mutex.new()}
	for lane in lane_count:
		if lane_count==1:
			threads.append(null);lane_results.append(_model_texture_lane(job,names,queue,track_inputs,phase,prepared));continue
		var thread:=Thread.new()
		if thread.start(_model_texture_lane.bind(job,names,queue,track_inputs,phase,prepared))==OK:
			threads.append(thread);lane_results.append({})
		else:
			threads.append(null);lane_results.append(_model_texture_lane(job,names,queue,track_inputs,phase,prepared))
	for lane in lane_count:
		if threads[lane]!=null:lane_results[lane]=threads[lane].wait_to_finish()
	var ordered: Array=[];ordered.resize(names.size());var input_rows: Array=[]
	for lane_result in lane_results:
		for entry in lane_result.rows:ordered[int(entry.index)]=entry.value
		input_rows.append_array(lane_result.inputs)
	return {"rows":ordered,"inputs":input_rows}
func _model_texture_lane(job: Dictionary,names: Array[String],queue: Dictionary,track_inputs: bool,phase: String,prepared: Array) -> Dictionary:
	# A fork owns its failure state and file handles. Dependency rows are merged
	# only after every lane joins, before the model/prework bundle is published.
	var reader=job.catalog.fork()
	var inputs=Prework.Inputs.new(reader) if track_inputs else null
	if inputs!=null:reader=inputs
	var rows: Array=[]
	var gui_inputs: Array=[]
	while true:
		queue.mutex.lock();var index: int=queue.next;queue.next=index+1;queue.mutex.unlock()
		if index>=names.size():break
		if phase=="gui":
			# The old GUI model loads each material bitmap in an independent
			# catch boundary. A failed read must not poison the next bitmap.
			var texture_reader=job.catalog.fork()
			var texture_inputs=Prework.Inputs.new(texture_reader) if track_inputs else null
			if texture_inputs!=null:texture_reader=texture_inputs
			rows.append({"index":index,"value":_model_texture_one(job,texture_reader,names[index])})
			if texture_inputs!=null:gui_inputs.append_array(texture_inputs.snapshot())
		elif phase=="read":rows.append({"index":index,"value":_model_texture_read_one(job,reader,names[index])})
		else:rows.append({"index":index,"value":_model_texture_decode_one(job,reader,names[index],prepared[index])})
	return {"rows":rows,"inputs":gui_inputs if phase=="gui" else (inputs.snapshot() if inputs!=null else [])}
func _model_texture_read_one(job: Dictionary,reader,name: String) -> Dictionary:
	var raster_name:=str(job.options.get("texture_overrides",{}).get(name,name))
	var began:=Time.get_ticks_usec();var source: Dictionary={}
	if reader.has_method("get_texture_resource"):
		source=reader.get_texture_resource(raster_name)
		if source.has("error") and str(source.get("code",""))!="RESOURCE_NOT_FOUND":return {"name":name,"error":str(source.error)}
	var selected: Dictionary={"name":raster_name,"type":int(source.type)} if source.has("type") else reader.raster_location(raster_name)
	if selected.is_empty() and reader.has_resource(raster_name,6):selected={"name":raster_name,"type":6}
	if selected.is_empty():
		var recorded: bool=reader.has_method("recorded_texture_miss") and reader.recorded_texture_miss(name)
		return {"name":name,"error":"","texture":{},"missing":true,"dependency":{"name":name,"missing":true,"recorded_missing":recorded}}
	if int(selected.type)==2059:return {"name":name,"error":"Native16-bit texture2059 "+raster_name+" requires an unsupported decoder"}
	var read_pair: Dictionary={"bytes":source.bytes,"sha256":""} if source.has("bytes") else (reader.get_resource_with_digest(raster_name,int(selected.type)) if reader is Prework.Inputs else {"bytes":reader.get_resource(raster_name,int(selected.type)),"sha256":""})
	if not reader.failure.is_empty():return {"name":name,"error":reader.failure}
	return {"name":name,"error":"","resource_name":raster_name,"type":int(selected.type),"bytes":read_pair.bytes,"sha256":str(read_pair.sha256),"read_ms":(Time.get_ticks_usec()-began)/1000.0}
func _prepare_model_palette(job: Dictionary,reader,name: String,bytes: Variant) -> Dictionary:
	var timeout_ms:=int(job.get("texture_worker_timeout_ms",0))
	var report:=Callable(job.catalog,"record_diagnostic") if timeout_ms>0 and job.catalog.has_method("record_diagnostic") else Callable()
	return Palette.new().prepare(reader,name,job.options.get("palette_colors",[]),str(job.cache_directory),false,bytes,timeout_ms,report,prepared_write_lease)
func _model_texture_decode_one(job: Dictionary,reader,name: String,source: Dictionary) -> Dictionary:
	if bool(source.get("missing",false)) or not str(source.get("error","")).is_empty():return source
	var raster_name:=str(source.resource_name);var resource_type:=int(source.type)
	if resource_type==6:
		var palette:=_prepare_model_palette(job,reader,raster_name,source.bytes)
		if not str(palette.get("error","")).is_empty():return {"name":name,"error":str(palette.error)}
		return {"name":name,"error":"","texture":palette,"dependency":{"name":name,"sha256":palette.sha256,"cache_hit":palette.cache_hit,"palette":true}}
	var timed_parse:=int(job.get("texture_worker_timeout_ms",0))>0 and resource_type==3
	# The caller selects the first decode error only after settling the batch.
	if timed_parse: _set_decode_scope(0)
	var raster:=decode(source.bytes,resource_type,"raster",str(job.cache_directory),job.decoder_store,false,str(source.sha256))
	if timed_parse: _set_decode_scope(-1)
	if raster.error==WORKER_TIMEOUT_ERROR:return {"name":name,"error":WORKER_TIMEOUT_ERROR}
	if not str(raster.error).is_empty():return {"name":name,"error":name+": "+str(raster.error)}
	return {"name":name,"error":"","texture":raster,"dependency":{"name":name,"sha256":raster.sha256,"cache_hit":raster.cache_hit,"read_ms":float(source.read_ms),"timings":raster.timings}}
func _model_texture_one(job: Dictionary,reader,name: String) -> Dictionary:
	var replacement: Variant=job.options.get("texture_overrides",{}).get(name,name)
	if replacement is Dictionary:
		var gui_palette:=GuiPalette.prepare(reader,replacement,str(job.cache_directory))
		if not str(gui_palette.get("error","")).is_empty():return {"name":name,"error":str(gui_palette.error)}
		if job.options.has("gui_texture_info"):gui_palette=GuiTextureInfo.attach(reader,str(replacement.resource),gui_palette)
		if not reader.failure.is_empty():return {"name":name,"error":reader.failure}
		return {"name":name,"error":"","texture":gui_palette,"dependency":{"name":name,"replacement":replacement.resource,"sha256":gui_palette.sha256,"cache_hit":gui_palette.cache_hit,"palette":true,"selector":gui_palette.selector,"palette_source":gui_palette.palette_source}}
	var raster_name:=str(replacement)
	var source_read_began:=Time.get_ticks_usec();var source: Dictionary={}
	if reader.has_method("get_texture_resource"):
		source=reader.get_texture_resource(raster_name)
		if source.has("error") and str(source.get("code",""))!="RESOURCE_NOT_FOUND":return {"name":name,"error":str(source.error)}
	var selected: Dictionary={"name":raster_name,"type":int(source.type)} if source.has("type") else reader.raster_location(raster_name)
	if selected.is_empty() and reader.has_resource(raster_name,6):selected={"name":raster_name,"type":6}
	if selected.is_empty():
		# The original bitmap reader omits RESOURCE_NOT_FOUND from the ordered
		# file batch; malformed or unreadable present resources still fail.
		var recorded: bool=reader.has_method("recorded_texture_miss") and reader.recorded_texture_miss(name)
		return {"name":name,"error":"","texture":{},"missing":true,"dependency":{"name":name,"missing":true,"recorded_missing":recorded}}
	if int(selected.type)==6:
		var palette:=_prepare_model_palette(job,reader,raster_name,source.get("bytes"))
		if not str(palette.get("error","")).is_empty():return {"name":name,"error":str(palette.error)}
		return {"name":name,"error":"","texture":palette,"dependency":{"name":name,"sha256":palette.sha256,"cache_hit":palette.cache_hit,"palette":true}}
	var read_began:=source_read_began if source.has("bytes") else Time.get_ticks_usec()
	var read_pair: Dictionary={"bytes":source.bytes,"sha256":""} if source.has("bytes") else (reader.get_resource_with_digest(raster_name,int(selected.type)) if reader is Prework.Inputs else {"bytes":reader.get_resource(raster_name,int(selected.type)),"sha256":""})
	var raw: PackedByteArray=read_pair.bytes;var read_ms:=(Time.get_ticks_usec()-read_began)/1000.0
	if not reader.failure.is_empty():return {"name":name,"error":reader.failure}
	var raster:=decode(raw,int(selected.type),"raster",str(job.cache_directory),job.decoder_store,false,str(read_pair.sha256))
	if not str(raster.error).is_empty():return {"name":name,"error":name+": "+str(raster.error)}
	if job.options.has("gui_texture_info"):
		raster=GuiTextureInfo.attach(reader,raster_name,raster)
		if not reader.failure.is_empty():return {"name":name,"error":reader.failure}
	return {"name":name,"error":"","texture":raster,"dependency":{"name":name,"sha256":raster.sha256,"cache_hit":raster.cache_hit,"read_ms":read_ms,"timings":raster.timings}}
func prepare_emitter_textures(reader,model: Dictionary,cache_path: String,prepared: Dictionary={}) -> Dictionary:
	# Emitter bitmaps are original particle textures, never body-part PLT
	# replacements, even if the same model also contains a recolored mesh.
	var textures: Dictionary=prepared.duplicate(); var dependencies: Array=[]
	for part in model.nodes:
		if not part.has("emitter"): continue
		var name:=str(part.emitter.get("texture","")).to_lower()
		if name in ["","null"] or textures.has(name): continue
		var source: Dictionary=reader.get_texture_resource(name) if reader.has_method("get_texture_resource") else {}
		if source.has("error") and str(source.get("code",""))!="RESOURCE_NOT_FOUND":return {"error":str(source.error)}
		var selected: Dictionary={"name":name,"type":int(source.type)} if source.has("type") else reader.raster_location(name)
		if not selected.is_empty() and int(selected.type)==6:return {"error":"Original emitter PLT requires a particle palette provider: "+name}
		if selected.is_empty():
			if reader.has_resource(name,6): return {"error":"Original emitter PLT requires a particle palette provider: "+name}
			var recorded: bool=reader.has_method("recorded_texture_miss") and reader.recorded_texture_miss(name)
			# Stock models contain dormant damage emitters naming absent bitmaps
			# (for example fxpa_cloud02). Keep their real geometry and preserve
			# the unavailable emitter explicitly; never invent a replacement.
			textures[name]={}; dependencies.append({"name":name,"role":"emitter","missing":true,"recorded_missing":recorded}); continue
		var read_pair: Dictionary={"bytes":source.bytes,"sha256":""} if source.has("bytes") else (reader.get_resource_with_digest(name,int(selected.type)) if reader is Prework.Inputs else {"bytes":reader.get_resource(name,int(selected.type)),"sha256":""})
		var raw: PackedByteArray=read_pair.bytes
		if not reader.failure.is_empty(): return {"error":reader.failure}
		var raster:=decode(raw,int(selected.type),"raster",cache_path,decoded_store(reader),false,str(read_pair.sha256))
		if not str(raster.error).is_empty(): return {"error":name+": "+str(raster.error)}
		textures[name]=raster; dependencies.append({"name":name,"role":"emitter","sha256":raster.sha256,"cache_hit":raster.cache_hit})
	return {"error":"","textures":textures,"dependencies":dependencies}
func icon_textures(reader,model: Dictionary,layers: Array,cache_path: String) -> Dictionary:
	var textures: Dictionary={}; var dependencies: Array=[]
	for index in layers.size():
		var layer: Dictionary=layers[index]; var raster: Dictionary={}
		if int(layer.type)==6: raster=Palette.new().prepare(reader,str(layer.name),layer.get("palette",[]),cache_path,true)
		else:
			var selected: Dictionary=reader.raster_location(str(layer.name))
			if selected.is_empty(): return {"error":"Original icon raster is absent: "+str(layer.name)}
			var read_pair: Dictionary=reader.get_resource_with_digest(str(layer.name),int(selected.type)) if reader is Prework.Inputs else {"bytes":reader.get_resource(str(layer.name),int(selected.type)),"sha256":""}
			var raw: PackedByteArray=read_pair.bytes
			if not reader.failure.is_empty(): return {"error":reader.failure}
			raster=decode(raw,int(selected.type),"raster",cache_path,decoded_store(reader),false,str(read_pair.sha256))
		if not str(raster.get("error","")).is_empty(): return {"error":raster.error}
		raster=GuiTextureInfo.attach(reader,str(layer.name),raster)
		if not reader.failure.is_empty(): return {"error":reader.failure}
		var replacement:="gui_replace"+str(index+1).pad_zeros(2); textures[replacement]=raster; dependencies.append({"name":layer.name,"sha256":raster.sha256,"cache_hit":raster.cache_hit})
	for part in model.nodes:
		if not part.mesh.get("render",false): continue
		for name in part.mesh.get("textures",[]):
			if str(name) not in ["","null"] and not textures.has(str(name).to_lower()): return {"error":"Original GUI icon has an unmatched replacement texture: "+str(name)}
	return {"textures":textures,"dependencies":dependencies}
func actor_data(reader, name: String, bytes: PackedByteArray, cache_path: String, ancestors: Array, relevant_nodes: Variant=null,known_sha: String="") -> Dictionary:
	# Only the required/high-priority actor can start helpers. Other sources may
	# reuse its immutable decoded work, without spawning competing helper waves.
	var prefetch: Dictionary={}
	if ancestors.is_empty() and high_priority and ancestor_preparation_enabled: prefetch=Ancestors.start(reader,name,bytes,cache_path,decode)
	var result:=actor_data_serial(reader,name,bytes,cache_path,ancestors,relevant_nodes,known_sha)
	# Join on every normal/error return before the asset owner can retire. Child
	# results affect caching/timings only; authoritative parsing owns correctness.
	if not prefetch.is_empty(): result.ancestor_preparation=Ancestors.finish(prefetch)
	return result
func actor_data_serial(reader, name: String, bytes: PackedByteArray, cache_path: String, ancestors: Array, relevant_nodes: Variant=null,known_sha: String="") -> Dictionary:
	if ancestors.has(name.to_lower()): return {"error":"MDL supermodel inheritance cycle."}
	var decoded:=decode(bytes,2002,ActorModel.SOURCE_DECODER,cache_path,decoded_store(reader),false,known_sha)
	if not str(decoded.error).is_empty(): return decoded
	decoded.preparation_sources=[{"name":name,"source_bytes":bytes.size(),"memory_hit":decoded.get("memory_decode_hit",false),"timings":decoded.get("timings",{})}]
	var model: Dictionary=decoded.value; var parent_name:=str(model.get("supermodel","")).to_lower()
	# Keep the logical source clip complete through supermodel inheritance.
	# Runtime rigs still bind only tracks for this piece's actual nodes.
	var selected: Variant=null
	if relevant_nodes is Dictionary:
		selected=relevant_nodes.duplicate()
		if selected.is_empty():
			for node in model.nodes: selected[str(node.name).to_lower()]=true
		selected[str(model.name).to_lower()]=true
		decoded.animation_binding_nodes=selected
	decoded.animation_sources=[{"name":name,"sha256":decoded.sha256}]
	if parent_name in ["","null","****"]:
		if shared_animation_preparation_enabled: decoded.animation_view_identity=Cache.digest(var_to_bytes([ANIMATION_INHERITANCE_REVISION,SharedAnimation.view_identity(decoded.animation_sources,selected)]))
		return decoded
	if ancestors.size()>=16 or ancestors.has(parent_name) or parent_name==str(model.get("modelName",model.get("name",""))).to_lower():
		decoded.error="MDL supermodel inheritance cycle."
		return decoded
	var parent_bytes: PackedByteArray=reader.get_resource(parent_name,2002)
	if not reader.failure.is_empty(): decoded.error=reader.failure; return decoded
	var path:=ancestors.duplicate(); path.append(name.to_lower())
	var parent:=actor_data(reader,parent_name,parent_bytes,cache_path,path,selected)
	if not str(parent.error).is_empty(): decoded.error=parent.error; return decoded
	decoded.animation_sources.append_array(parent.animation_sources)
	decoded.preparation_sources.append_array(parent.get("preparation_sources",[]))
	# V1's broad projection cache had no reuse in the captured room and evicted
	# parsed MDLs. Preserve the original composition; only rig data is admitted
	# selectively to its own small derived partition after actual repeated use.
	if shared_animation_preparation_enabled: decoded.animation_view_identity=Cache.digest(var_to_bytes([ANIMATION_INHERITANCE_REVISION,SharedAnimation.view_identity(decoded.animation_sources,selected)]))
	model.animations.append_array(inherited_clips(model,parent.value,parent_name).clips)
	return decoded
func inherited_clips(model: Dictionary,parent: Dictionary,parent_name: String) -> Dictionary:
	if model.get("animationsInherited",false):return {"clips":[]}
	var inherited: Array=[]
	var own: Dictionary={}
	for clip in model.animations: own[clip.name]=true
	var scale_value:=float(model.get("animation_scale",1.0))
	for source in parent.animations:
		if own.has(source.name): continue
		var clip: Dictionary=source.duplicate(); clip.inheritedFrom=parent_name; clip.tracks=[]
		clip.emitter_tracks=[]
		for original in source.get("emitter_tracks",[]):
			var track: Dictionary=original.duplicate()
			if str(track.node).to_lower()==str(parent.name).to_lower(): track.node=model.name
			clip.emitter_tracks.append(track)
		for original in source.tracks:
			var track: Dictionary=original.duplicate()
			if str(track.node).to_lower()==str(parent.name).to_lower(): track.node=model.name
			if str(track.property)=="position":
				if track.has("packed_frames"):
					track.position_scale=float(track.get("position_scale",1.0))*scale_value
				track.frames=[]
				for original_frame in original.frames:
					var frame: Dictionary=original_frame.duplicate()
					for field in ["value","in","out"]:
						if frame.has(field): frame[field]=frame[field].map(func(value): return float(value)*scale_value)
					track.frames.append(frame)
			clip.tracks.append(track)
		inherited.append(clip)
	var unsupported: Array=model.get("unsupportedAnimations",[]).duplicate()
	for message in parent.get("unsupportedAnimations",[]):
		var inherited_message:=parent_name+": "+str(message)
		if not unsupported.has(inherited_message):unsupported.append(inherited_message)
	model.unsupportedAnimations=unsupported
	model.animationsInherited=true
	return {"clips":inherited}
func binding_model(model: Dictionary,selected: Variant)->Dictionary:
	if not selected is Dictionary:return model
	var binding: Dictionary=model.duplicate(); var clips: Array=[]
	for original in model.animations:
		var clip: Dictionary=original.duplicate(); clip.tracks=[]
		for track in original.tracks:
			if selected.has(str(track.node).to_lower()):clip.tracks.append(track)
		clip.emitter_tracks=[]
		for track in original.get("emitter_tracks",[]):
			if selected.has(str(track.node).to_lower()):clip.emitter_tracks.append(track)
		clips.append(clip)
	binding.animations=clips
	return binding
func shared_rig_data(model: Dictionary,sources: Array,cache_path: String,store,view_identity: String,seed: Dictionary={},selected: Variant=null) -> Dictionary:
	# Source-chain bytes plus selected node names distinguish filtered skeleton
	# views. In particular, a filtered derivative must never satisfy a full rig.
	var identity:=Cache.digest(var_to_bytes([sources,view_identity]))
	var builder: Callable=func()->Dictionary:
		return build_shared_rig(binding_model(model,selected),identity,cache_path)
	return SharedAnimation.acquire(store,"rig:"+identity,builder,seed)
func build_shared_rig(model: Dictionary,identity: String,cache_path: String) -> Dictionary:
	return cached_rig(model,identity,"actor-rig-shared-v1",cache_path)
func rig_data(model: Dictionary,sources: Array,cache_path: String,selected: Variant=null) -> Dictionary:
	var identity:=SharedAnimation.view_identity(sources,selected)
	return cached_rig(model,identity,"actor-rig-emitter-v12-ascii-native:"+ANIMATION_INHERITANCE_REVISION,cache_path,selected)
func cached_rig(model: Dictionary,identity: String,decoder: String,cache_path: String,selected: Variant=null) -> Dictionary:
	var cache:=Cache.new(); var enabled:=not cache_path.is_empty() and cache.configure(cache_path)
	var key:=""
	if enabled:
		key=Cache.key(identity,decoder)
		var saved:=cache.load_data(key,identity,decoder)
		if not saved.is_empty(): return saved
	var result:=ActorModel.new().rig_asset(binding_model(model,selected))
	if enabled:
		# A rig is ready as soon as its immutable data is built. The optional
		# disk copy must never wait behind trimming when the normal writer is active.
		if prepared_write_lease: CacheWrites.enqueue(cache.directory,key,identity,decoder,result.duplicate(true))
		else: cache.save_data(key,identity,decoder,result)
	return result
func resource_metrics(reader) -> Dictionary:
	var value: Variant=reader.get("stats")
	return value.duplicate() if value is Dictionary else {}
func decoded_store(reader):
	return reader.decoded_cache() if reader.has_method("decoded_cache") else (reader.preparation_cache() if reader.has_method("preparation_cache") else null)
func decode(bytes: PackedByteArray, type: int, decoder: String, cache_path: String, store=null, immutable_source: bool=false,known_sha: String="") -> Dictionary:
	if decoder=="bytes":return decode_uncached(bytes,type,decoder,cache_path,known_sha)
	if store==null:
		var result:=decode_uncached(bytes,type,decoder,cache_path,known_sha,prepared_write_lease)
		if result.has("deferred_cache_write"):
			var key: String=result.deferred_cache_write.key
			result.erase("deferred_cache_write")
			queue_decoded_cache_write(result.timings,cache_path,key,result.sha256,decoder,result.value.duplicate(true))
		return result
	var began:=Time.get_ticks_usec();var source_sha:=known_sha if not known_sha.is_empty() else Cache.digest(bytes)
	var request_key:="decoded-native-v1:"+str(type)+":"+decoder+":"+source_sha+(":ambient-1:vertex-color-1:"+Prework.MODEL_METADATA_REVISION if decoder.begins_with("mdl-") else "")+(":"+mesh_revision() if mesh_preparation_enabled and decoder.begins_with("mdl-") else "")+(":s3tc-textures-v3" if decoder=="raster" and type in [2033,2073] else "")+(":lazy-ssf-2" if decoder=="ssf-native-v1" else "")
	var immutable_model:=decoder in ["mdl-actor-v2","mdl-actor-packed-v1","mdl-actor-packed-v2","mdl-actor-packed-v3",ActorModel.SOURCE_DECODER]
	var borrowed:=immutable_model or decoder=="2da" and immutable_source
	var generation:=int(store.generation()); var lease: Dictionary=store.begin_data(request_key,generation,not borrowed)
	if not lease.owner:
		var shared: Dictionary=lease.value.result
		var saved: Dictionary=private_model_source(shared) if immutable_model and str(shared.get("error","")).is_empty() else (shared.duplicate() if borrowed else shared)
		saved.memory_decode_hit=true; saved.timings={"memory_decode_ms":(Time.get_ticks_usec()-began)/1000.0,"coalesced_wait_ms":int(lease.wait_us)/1000.0}
		return saved
	var decoded:=decode_uncached(bytes,type,decoder,cache_path,source_sha,prepared_write_lease)
	var deferred_write: Dictionary=decoded.get("deferred_cache_write",{}); decoded.erase("deferred_cache_write")
	decoded.memory_decode_hit=false
	var value:={"result":decoded}
	var publish_began:=Time.get_ticks_usec()
	# A table's source strings plus conservative per-cell/dictionary overhead
	# avoid serializing its entire aliased row graph merely to estimate RAM.
	var size_hint:=-1
	if decoder=="2da" and str(decoded.error).is_empty(): size_hint=bytes.size()*4+decoded.value.orderedRows.size()*(decoded.value.columns.size()*128+256)+1024
	# Freeze the newly decoded graph itself. Publish it before making a private
	# copy for a mutable consumer, so read-only waiters do not wait on that copy.
	if str(decoded.error).is_empty(): store.save_data(request_key,request_key,value,generation,size_hint,true)
	store.finish_data(request_key,generation,value)
	var owned: Dictionary=private_model_source(decoded) if immutable_model and str(decoded.error).is_empty() else (decoded.duplicate() if borrowed else decoded.duplicate(true))
	owned.timings=owned.get("timings",{}).duplicate(); owned.timings.memory_publish_ms=(Time.get_ticks_usec()-publish_began)/1000.0
	if not deferred_write.is_empty():
		queue_decoded_cache_write(owned.timings,cache_path,str(deferred_write.key),source_sha,decoder,decoded.value,store.retained_size(request_key,generation))
	return owned
func queue_decoded_cache_write(timings: Dictionary,cache_path: String,key: String,source_sha: String,decoder: String,value: Dictionary,estimated_bytes: int=-1) -> void:
	var began:=Time.get_ticks_usec()
	var accepted:=CacheWrites.enqueue(cache_path,key,source_sha,decoder,value,estimated_bytes)
	timings.cache_write_deferred=accepted; timings.cache_write_skipped=not accepted; timings.cache_write_enqueue_ms=(Time.get_ticks_usec()-began)/1000.0
func private_model_source(source: Dictionary) -> Dictionary:
	# Geometry, original controller/keyframe streams and node definitions remain
	# immutable shared input. Inheritance/filtering modifies only these owners.
	var result:=source.duplicate(); var model: Dictionary=source.value.duplicate()
	model.animations=model.animations.duplicate(); result.value=model
	return result
func mesh_revision() -> String:
	return MeshPreparation.REVISION+(":"+SkinPreparation.REVISION if skin_preparation_enabled else "")
func _set_decode_scope(request_id: int) -> void:
	# A positive ID permits early completion for a required parser. Zero keeps
	# a texture timeout in its ordered batch result.
	var thread:=OS.get_thread_caller_id()
	mutex.lock()
	if request_id<0: worker_decode_scopes.erase(thread)
	else: worker_decode_scopes[thread]=request_id
	mutex.unlock()
func decode_uncached(bytes: PackedByteArray, type: int, decoder: String, cache_path: String, known_sha: String="",defer_write: bool=false) -> Dictionary:
	var began := Time.get_ticks_usec()
	var source_sha := known_sha if not known_sha.is_empty() else Cache.digest(bytes); var cache := Cache.new()
	# 2DA exposes both physical cells and keyed/ordered row views. Generic Variant
	# persistence serializes those aliases repeatedly: the captured 2.8 MB table
	# becomes 40.8 MB, and verified reload is slower than parsing original text.
	# Keep authoritative bytes plus shared session decoding, without putting that
	# expanded derivative on the critical path. Model/raster persistence remains.
	var cache_ok := decoder!="2da" and not cache_path.is_empty() and cache.configure(cache_path)
	var identity := Cache.key(source_sha,decoder+":"+str(type)+(":emitter-3:reference-1:clip-duration-1:classification-1:mesh-area-1:hit-faces-1:ambient-1:vertex-color-1:"+Prework.MODEL_METADATA_REVISION if decoder.begins_with("mdl-") else ""))
	if decoder=="raster" and type in [2033,2073]: identity=Cache.key(identity,"s3tc-textures-v3")
	if decoder=="bitmap-font-v1": identity=Cache.key(identity,"normalized-glyph-metrics-v2")
	if decoder=="ssf-native-v1":identity=Cache.key(identity,"lazy-ssf-2")
	if mesh_preparation_enabled and decoder.begins_with("mdl-"): identity=Cache.key(identity,mesh_revision())
	if decoder=="tile-surface-v1": identity=Cache.key(source_sha,decoder+":"+str(type)+":vertical-bounds-2:aabb-rows-1")
	var timings := {"identity_ms":(Time.get_ticks_usec()-began)/1000.0,"cache_read_ms":0.0,"decode_ms":0.0,"cache_write_ms":0.0}
	if decoder=="2da": timings.cache_policy="original-bytes-and-session-decoding"
	if cache_ok and decoder != "bytes":
		began = Time.get_ticks_usec()
		var saved := cache.load_data(identity,source_sha,decoder)
		timings.cache_read_ms = (Time.get_ticks_usec()-began)/1000.0
		if not saved.is_empty(): return {"value":saved,"error":"","sha256":source_sha,"cache_hit":true,"timings":timings}
	var result := {"error":"","sha256":source_sha,"cache_hit":false,"timings":timings}
	var timeout_ms:=worker_timeout_ms if decoder=="2da" or decoder.begins_with("mdl-") or (decoder=="raster" and type==3) else 0
	var request_id:=-1
	began = Time.get_ticks_usec()
	if timeout_ms>0:
		mutex.lock()
		request_id=int(worker_decode_scopes.get(OS.get_thread_caller_id(),-1))
		if request_id>0:worker_decode_deadlines[request_id]={"at_us":began+timeout_ms*1000,"timeout_ms":timeout_ms}
		mutex.unlock()
	match decoder:
		"ltr-native-v1":
			var decoded:=LetterTable.decode(bytes);result.value=decoded;result.error="" if decoded.ready else str(decoded.reason)
		"wave-native-v1":
			var parser:=WaveData.new(); result.value=parser.parse(bytes); result.error=parser.failure
		"ssf-native-v1":
			var parser:=SoundSet.new(); result.value=parser.parse(bytes); result.error=parser.failure
		"nui-skin-v1":
			# The old TextDecoder used fatal UTF-8. A replacement character must
			# reject this asset rather than silently changing its TOML keys/values.
			var text: String=bytes.get_string_from_utf8()
			if text.to_utf8_buffer()!=bytes: result.error="Invalid NUI skin UTF-8"
			else:
				var parser := UiSkin.new(); result.value = parser.parse(text); result.error = parser.failure
		"bitmap-font-v1":
			var parser:=preload("res://systems/native_data/bitmap_font.gd").new(); result.value=parser.parse(bytes.get_string_from_ascii()); result.error=parser.failure
		"font-v1":
			var parser := FontData.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"tile-surface-v1":
			var parser := TileSurface.new(); result.value = parser.parse_bytes(bytes); result.error = parser.failure
		"pwk-surface-v1", "dwk-surface-v1":
			var parser := ObjectSurface.new(); result.value = parser.parse(bytes,decoder=="dwk-surface-v1"); result.error = parser.failure
		"dwk-pick-v1":
			var parser:=preload("res://systems/native_data/legacy_door_pick_walkmesh.gd").new();result.value=parser.parse(bytes);result.error=parser.failure
		"gff":
			var parser := Gff.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"2da":
			var parser := Table.new(); result.value = parser.parse(Binary.new(bytes).text(0,bytes.size())); result.error = parser.failure
		"mdl-binary":
			var parser = Model.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"mdl-actor-v2":
			var parser := ActorModel.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"mdl-actor-packed-v1", "mdl-actor-packed-v2", "mdl-actor-packed-v3", "mdl-actor-packed-v4", ActorModel.SOURCE_DECODER:
			var parser:=ActorModel.new(); parser.packed_keys=true; result.value=parser.parse(bytes); result.error=parser.failure
		"mdl-original":
			var parser := ActorModel.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"raster":
			var parser := Raster.new(); result.value = parser.parse(bytes,type); result.error = parser.failure; timings.raster_conversion=parser.stats.duplicate()
	var elapsed_us:=Time.get_ticks_usec()-began
	if request_id>0:
		mutex.lock()
		elapsed_us=Time.get_ticks_usec()-began
		if elapsed_us<timeout_ms*1000:worker_decode_deadlines.erase(request_id)
		mutex.unlock()
	timings.decode_ms = elapsed_us/1000.0
	if request_id>=0 and elapsed_us>=timeout_ms*1000:
		result.erase("value")
		result.error=WORKER_TIMEOUT_ERROR
		return result
	if mesh_preparation_enabled and decoder.begins_with("mdl-") and str(result.error).is_empty():
		var prepared:=MeshPreparation.model(result.value,skin_preparation_enabled); timings.mesh_preparation=prepared
		if not str(prepared.error).is_empty(): result.error=prepared.error
	if not mesh_preparation_enabled and decoder=="mdl-original" and str(result.error).is_empty():
		for deferred in result.value.get("deferredGeometryErrors",[]):
			if deferred.get("renderRequested",false):result.error=str(deferred.reason)+" in "+str(deferred.name);break
	if cache_ok and decoder != "bytes" and str(result.error).is_empty():
		began = Time.get_ticks_usec()
		if defer_write and CacheWrites.configured_enabled() and Cache.configured_writes_enabled(): result.deferred_cache_write={"key":identity}
		else: cache.save_data(identity,source_sha,decoder,result.value)
		timings.cache_write_ms = (Time.get_ticks_usec()-began)/1000.0
		timings.cache_write_phases=cache.last_save
	return result
func _queue_nwsync_repair(id: int,result: Dictionary)->bool:
	if str(result.get("resource_error","")).is_empty() or not jobs.has(id):return false
	var job: Dictionary=jobs[id]
	if bool(job.get("nwsync_repair_attempted",false)) or catalog==null or not catalog.has_method("nwsync_repair_binding"):return false
	var callback: Callable=catalog.nwsync_repair
	if not callback.is_valid():return false
	var binding: Dictionary=catalog.nwsync_repair_binding(str(job.name),int(job.type))
	if binding.is_empty():return false
	job.nwsync_repair_attempted=true
	repairing[id]=true
	_repair_nwsync.call_deferred(id,int(job.epoch),job,binding,result,callback)
	return true
func _repair_nwsync(id: int,source_epoch: int,job: Dictionary,binding: Dictionary,failed: Dictionary,callback: Callable)->void:
	if closed or epoch!=source_epoch or not jobs.has(id):repairing.erase(id);jobs.erase(id);return
	var reply: Variant={"error":"NWSync repository is unavailable"}
	if callback.is_valid():reply=await callback.call(binding.store,binding.entry)
	var repaired: Dictionary=reply if reply is Dictionary else {"error":"NWSync repository returned no result"}
	if closed or epoch!=source_epoch or not jobs.has(id):repairing.erase(id);jobs.erase(id);return
	repairing.erase(id)
	if not repaired.has("error"):
		# Source and preparation stores retain successes only. A fresh fork reads
		# the newly verified object while preserving the original request ID.
		job.catalog=catalog.fork()
		pending.push_front(job)
		pump()
		return
	failed.nwsync_repair_error=str(repaired.error)
	jobs.erase(id)
	completed.emit(id,failed)
	completion_stats.delivered+=1
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_assets",began)
func _profile_process(_delta: float) -> void:
	if native_draw_cache_lease:NativeDrawCache.poll()
	Timing.count("count_asset_workers",running.size()); Timing.count("count_asset_queued",pending.size())
	if _consuming_completions:completion_stats.reentrant+=1;return
	_consuming_completions=true
	var began:=Time.get_ticks_usec()
	_expire_worker_deadlines()
	_drain_completed_tasks(false,began)
	_consuming_completions=false;completion_stats.passes+=1;completion_stats.max_pass_us=maxi(int(completion_stats.max_pass_us),Time.get_ticks_usec()-began)
	pump()
func _expire_worker_deadlines()->void:
	# Each required parser gets its own deadline. The pool still owns an
	# expired task until it can safely join and release its late result.
	mutex.lock()
	var checked_us:=Time.get_ticks_usec()
	var deadlines:=worker_decode_deadlines.duplicate()
	mutex.unlock()
	for id in deadlines:
		if not jobs.has(id) or not running.has(id) or WorkerThreadPool.is_task_completed(int(running[id])):continue
		var deadline: Dictionary=deadlines[id]
		if checked_us<int(deadline.at_us):continue
		var job: Dictionary=jobs[id]
		jobs.erase(id)
		worker_reply_stats.failed+=1
		completed.emit(int(id),{"id":int(id),"epoch":int(job.epoch),"resource_name":str(job.name),"error":WORKER_TIMEOUT_ERROR,"worker_ms":float(deadline.timeout_ms)})
		completion_stats.delivered+=1
func _foreground_ready(id: int)->bool:
	if not jobs.has(id) or not jobs[id].get("watch_foreground_delivery",false):return false
	mutex.lock()
	var result: Dictionary=results.get(id,{})
	var ready:=not result.is_empty() and int(result.get("epoch",-1))==epoch and str(result.get("error","")).is_empty()
	mutex.unlock()
	return ready
func _drain_completed_tasks(foreground_only: bool,began: int)->void:
	var used_early:=not foreground_only and _early_completion_frame>=0 and _early_completion_frame==Engine.get_process_frames()
	var consumed:=int(used_early)
	var early_us:=_early_completion_us if used_early else 0
	for id in running.keys():
		if not running.has(id): continue
		var task: int = running[id]
		if not WorkerThreadPool.is_task_completed(task): continue
		if consumed>=maxi(1,maximum_completions_per_pass) or consumed>0 and completion_budget_us>0 and Time.get_ticks_usec()-began+early_us>=completion_budget_us:
			completion_stats.deferred+=1;break
		var budget_owner=completion_pool
		var budgeted: bool=budget_owner is Object and is_instance_valid(budget_owner) and budget_owner.has_method("can_consume_completion")
		if foreground_only:
			# Keep this service's ordinary completion ordering. An unrelated or
			# failed result at the front still waits for its normal pass.
			if not budgeted or not budget_owner.has_method("reserve_foreground_model_completion") or not _foreground_ready(int(id)) or not budget_owner.reserve_foreground_model_completion():break
		elif budgeted and not budget_owner.can_consume_completion(high_priority and consumed==0):completion_stats.deferred+=1;break
		var callback_began:=Time.get_ticks_usec()
		var diagnostic_phases: Variant=null
		if completion_diagnose:diagnostic_phases={}
		var diagnostic_began:=Time.get_ticks_usec() if completion_diagnose else 0
		if budgeted:
			if budget_owner.has_method("begin_prioritized_completion_scope"):budget_owner.begin_prioritized_completion_scope(high_priority and consumed==0)
			else:budget_owner.begin_completion_scope()
		if completion_diagnose:diagnostic_phases.scope_begin_us=Time.get_ticks_usec()-diagnostic_began;diagnostic_began=Time.get_ticks_usec()
		WorkerThreadPool.wait_for_task_completion(task)
		if completion_diagnose:diagnostic_phases.join_us=Time.get_ticks_usec()-diagnostic_began;diagnostic_began=Time.get_ticks_usec()
		running.erase(id)
		mutex.lock(); var result: Dictionary = results.get(id, {}); results.erase(id); worker_decode_deadlines.erase(id); mutex.unlock()
		var foreground_prepared:=int(result.get(FOREGROUND_PREPARED_US,0))
		if foreground_prepared>0:result.erase(FOREGROUND_PREPARED_US)
		if completion_diagnose:diagnostic_phases.result_take_us=Time.get_ticks_usec()-diagnostic_began;diagnostic_began=Time.get_ticks_usec()
		var diagnostic_sha: String=str(result.get("sha256","")) if completion_diagnose else ""
		var diagnostic_request: Variant=null
		if completion_diagnose:diagnostic_request=completion_diagnostic_requests.get(id,{})
		var deferred_for_repair:=false
		if not closed and jobs.has(id):
			if result.is_empty() or int(result.get("epoch",-1))!=int(jobs[id].epoch):result={"id":int(id),"epoch":epoch,"resource_name":str(jobs[id].name),"error":"Resource worker response could not be decoded","worker_ms":0.0}
			var kind: String=str(jobs[id].decoder)
			var kind_stats: Dictionary=worker_reply_stats.kinds.get(kind,{"completed":0,"cpuMs":0.0})
			var cpu_ms:=float(result.get("worker_ms",0.0))
			worker_reply_stats.cpuMs+=cpu_ms;kind_stats.cpuMs+=cpu_ms
			if str(result.get("error","")).is_empty():worker_reply_stats.completed+=1;kind_stats.completed+=1
			else:worker_reply_stats.failed+=1
			worker_reply_stats.kinds[kind]=kind_stats
			var upload_sidecar: Variant=result.get("_raster_upload_sidecar")
			result.erase("_raster_upload_sidecar") # Never expose ready pixels to caller key/serialization/template code.
			if upload_sidecar is Dictionary and budget_owner is Object and is_instance_valid(budget_owner) and budget_owner.has_method("accept_raster_upload_sidecar"):budget_owner.accept_raster_upload_sidecar(upload_sidecar)
			upload_sidecar=null
			if completion_diagnose:diagnostic_phases.sidecar_us=Time.get_ticks_usec()-diagnostic_began;diagnostic_began=Time.get_ticks_usec()
			deferred_for_repair=_queue_nwsync_repair(int(id),result)
			if not deferred_for_repair:
				_publish_model_limitations(jobs[id],result)
				if foreground_prepared>0 and is_instance_valid(budget_owner) and budget_owner.has_method("record_foreground_model_delivery"):
					budget_owner.record_foreground_model_delivery(kind,foreground_prepared,foreground_only)
				completed.emit(int(id), result);completion_stats.delivered+=1
			if completion_diagnose:diagnostic_phases.consumer_us=Time.get_ticks_usec()-diagnostic_began;diagnostic_began=Time.get_ticks_usec()
		else:completion_stats.stale+=1
		if not deferred_for_repair:jobs.erase(id)
		# Drop the drain's result reference inside the measured scope. Consumers
		# which retained it keep ownership; stale graphs release here as well.
		result={}
		if completion_diagnose:diagnostic_phases.release_us=Time.get_ticks_usec()-diagnostic_began;diagnostic_began=Time.get_ticks_usec()
		if budgeted:budget_owner.end_completion_scope()
		var callback_us:=Time.get_ticks_usec()-callback_began
		completion_stats.max_callback_us=maxi(int(completion_stats.max_callback_us),callback_us)
		if completion_diagnose:
			diagnostic_phases.scope_end_us=Time.get_ticks_usec()-diagnostic_began
			_record_completion_diagnostic(int(id),diagnostic_request,diagnostic_sha,callback_us,diagnostic_phases)
		consumed+=1
		if foreground_only:
			_early_completion_frame=Engine.get_process_frames()
			_early_completion_us=Time.get_ticks_usec()-began
			break
func _record_completion_diagnostic(id: int,request: Dictionary,source_sha: String,callback_us: int,phases: Dictionary) -> void:
	completion_diagnostic_requests.erase(id)
	if callback_us<5000 or request.is_empty():return
	var row: Dictionary={"service":str(get_path()),"request_id":id,"resource":str(request.get("name","")),"type":int(request.get("type",-1)),"decoder":str(request.get("decoder","")),"epoch":int(request.get("epoch",-1)),"sha256":source_sha,"callback_us":callback_us,"phases_us":phases}
	completion_diagnostic_peaks.append(row)
	completion_diagnostic_peaks.sort_custom(func(a,b):return int(a.callback_us)>int(b.callback_us))
	if completion_diagnostic_peaks.size()>8:completion_diagnostic_peaks.resize(8)
	if callback_us>completion_diagnostic_reported_max_us and completion_diagnostic_logged<16:
		completion_diagnostic_reported_max_us=callback_us
		completion_diagnostic_logged+=1
		print("NWN62_COMPLETION_TAIL ",JSON.stringify(row))
func retire_scope() -> void:
	if _early_foreground_models:_detach_foreground_completion()
	if completion_diagnose and not completion_diagnostic_peaks.is_empty():
		print("NWN62_COMPLETION_SUMMARY ",JSON.stringify({"service":str(get_path()),"top":completion_diagnostic_peaks}))
		completion_diagnostic_peaks.clear();completion_diagnostic_reported_max_us=0;completion_diagnostic_logged=0
	worker_reply_stats.cancelled+=jobs.size()
	epoch += 1;pending.clear();jobs.clear();dispatch_guards.clear();repairing.clear();completion_pool=null;world_texture_worker=false
	if completion_diagnose:completion_diagnostic_requests.clear()
	# Stale workers still need to finish and release their results, without
	# delivering completion into the replacement scope.
	_refresh_processing()
func worker_snapshot() -> Dictionary:
	var active:=0
	for task in running.values():
		if not WorkerThreadPool.is_task_completed(int(task)):active+=1
	var result: Dictionary=worker_reply_stats.duplicate(true)
	result.merge({"limit":maximum_workers,"workers":active,"pending":active,"queued":pending.size(),"closed":closed},true)
	return result
func detach_retired_results() -> Dictionary:
	# World retirement calls this after observing real worker completion. The
	# pure decoded result graphs can then be released by the data worker owner.
	if running.values().any(func(task):return not WorkerThreadPool.is_task_completed(int(task))): return {}
	mutex.lock(); var detached:=results; results={}; mutex.unlock()
	return {"asset_results":detached} if not detached.is_empty() else {}
func close() -> void:
	closed = true; retire_scope()
	for task in running.values(): WorkerThreadPool.wait_for_task_completion(int(task))
	running.clear(); mutex.lock(); results.clear();worker_decode_scopes.clear();worker_decode_deadlines.clear(); mutex.unlock()
	catalog = null
	if prepared_write_lease: prepared_write_lease=false; CacheWrites.release()
	if native_draw_cache_lease:native_draw_cache_lease=false;NativeDrawCache.release()
func _exit_tree() -> void: close()
