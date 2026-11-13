extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Native worker jobs own only data/FileAccess/RefCounted parsers. SceneTree,
# ArrayMesh/texture publication and consumers stay on the main thread.
signal completed(request_id: int, result: Dictionary)
const Gff = preload("res://systems/native_data/gff_document.gd")
const Table = preload("res://systems/native_data/two_da.gd")
const Binary = preload("res://systems/native_data/binary_data.gd")
const Model = preload("res://systems/native_data/binary_model.gd")
const AsciiModel = preload("res://systems/native_data/ascii_model.gd")
const Raster = preload("res://systems/native_data/texture_data.gd")
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
var prework_write:=false # Only the explicit preparation action publishes bundles.
var prework_read:=true
var status_only:=false # Preparation jobs keep/dispose large model graphs on workers.
var skin_preparation_enabled:=SkinPreparation.configured_enabled()
var prepared_write_lease:=false
var native_draw_cache_lease:=false
var catalog
var epoch := 0
var serial := 0
var maximum_workers := 4
var maximum_pending := 128
var high_priority:=false
var ancestor_preparation_enabled:=Ancestors.configured_enabled() # --ancestor-preparation=false retains the measured reference.
var mesh_preparation_enabled:=MeshPreparation.configured_enabled() # Immutable after requests start.
var shared_animation_preparation_enabled:=SharedAnimation.configured_enabled()
var failure := ""
var closed := false
var cache_directory := ""
var pending: Array = []
var running: Dictionary = {}
var results: Dictionary = {}
var mutex := Mutex.new()
func configure(source) -> void:
	retire_scope(); catalog = source; closed = false
	if CacheWrites.configured_enabled() and not prepared_write_lease: CacheWrites.acquire(); prepared_write_lease=true
	if NativeDrawCache.enabled() and not native_draw_cache_lease:NativeDrawCache.acquire();native_draw_cache_lease=true
func request(name: String, type: int, decoder: String = "bytes", options: Dictionary = {}) -> int:
	failure = ""
	if closed or catalog == null: failure = "Native asset service is unavailable"; return -1
	if decoder not in ["bytes", "gff", "2da", "mdl-binary", "mdl-original", "raster", "static-model", "actor-model", "gui-icon-v1", "tile-surface-v1", "pwk-surface-v1", "dwk-surface-v1", "nui-skin-v1", "font-v1", "bitmap-font-v1", "wave-native-v1", "ssf-native-v1", "ltr-native-v1"]: failure = "Unknown native decoder"; return -1
	if pending.size() + running.size() >= maximum_pending: failure = "Native asset queue is full"; return -1
	Prework.remember_request(catalog,name,type,decoder,options)
	serial += 1
	var store=catalog.preparation_cache() if catalog.has_method("preparation_cache") else null
	pending.append({"id": serial, "name": name, "type": type, "decoder": decoder, "epoch": epoch, "catalog": catalog.fork(), "cache_directory": cache_directory, "options":options.duplicate(true),"memory_store":store,"decoder_store":decoded_store(catalog),"memory_epoch":store.generation() if store!=null else -1,"requested_us":Time.get_ticks_usec(),"prework_write":prework_write,"prework_read":prework_read,"status_only":status_only,"prework_ticket":Prework.current_generation(cache_directory)})
	pump()
	return serial
func pump() -> void:
	while not closed and not pending.is_empty() and running.size() < maximum_workers:
		var job: Dictionary = pending.pop_front()
		job.dispatched_us=Time.get_ticks_usec()
		running[job.id] = WorkerThreadPool.add_task(_work.bind(job), high_priority, "Native NWN asset " + str(job.id))
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
	result.requested_ms=int(job.requested_us)/1000.0; result.started_ms=began/1000.0
	var memory_key:=""
	var phases:={"service_queue_ms":(int(job.dispatched_us)-int(job.requested_us))/1000.0,"worker_queue_ms":(began-int(job.dispatched_us))/1000.0,"memory_lookup_ms":0.0,"model_ms":0.0,"rig_ms":0.0,"textures_ms":0.0,"memory_save_ms":0.0}
	var phase_began:=Time.get_ticks_usec()
	var prework:=Prework.new(); var prework_key:=""; var icon_key:=""
	var eligible: bool=reader.failure.is_empty() and job.decoder in ["actor-model","static-model","gui-icon-v1"] and not str(job.cache_directory).is_empty()
	if eligible and prework.configure(str(job.cache_directory)):
		var preparation_policy: Array=[mesh_preparation_enabled,skin_preparation_enabled,mesh_revision()]
		if shared_animation_preparation_enabled: preparation_policy.append(SharedAnimation.REVISION)
		prework_key=Prework.request_key(str(job.name),int(job.type),str(job.decoder),job.options,Cache.digest(bytes),preparation_policy)
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
	if inputs!=null: inputs.remember(str(job.name),int(job.type),bytes); reader=inputs
	if reader.failure.is_empty() and job.memory_store!=null and job.decoder in ["2da","actor-model","static-model","gui-icon-v1"] and not (job.decoder=="2da" and job.options.get("immutable_source",false)):
		var preparation_revision:="native-preparation-5-vertex-colors"
		if job.decoder in ["actor-model","static-model"]:preparation_revision+=":"+Prework.MODEL_METADATA_REVISION
		if shared_animation_preparation_enabled: preparation_revision+=":"+SharedAnimation.REVISION
		memory_key=Cache.digest(var_to_bytes([preparation_revision,job.decoder,Cache.digest(bytes),job.options,mesh_preparation_enabled,skin_preparation_enabled]))
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
		var decoded := actor_data(reader,str(job.name),bytes,str(job.cache_directory),[],{} if job.options.get("relevant_tracks",false) else null) if job.decoder in ["actor-model","gui-icon-v1"] else decode(bytes,int(job.type),"mdl-original" if job.decoder == "static-model" else str(job.decoder),str(job.cache_directory),job.decoder_store,bool(job.options.get("immutable_source",false)))
		# Placeable/tile emitters can be driven by original pause/loop clips.
		# Retain those channels on the static-world route too, without expanding
		# inherited actor animation data for every non-animated static model.
		if job.decoder=="static-model" and str(decoded.get("error","")).is_empty() and decoded.value.nodes.any(func(row):return row.has("emitter")):
			decoded=actor_data(reader,str(job.name),bytes,str(job.cache_directory),[],{})
		phases.model_ms=(Time.get_ticks_usec()-phase_began)/1000.0
		phases.model_sources=decoded.get("preparation_sources",[])
		if decoded.has("ancestor_preparation"): phases.ancestor_preparation=decoded.ancestor_preparation
		if decoded.has("shared_animation_preparation"): phases.shared_animation_preparation=decoded.shared_animation_preparation
		result.merge(decoded,true)
		if job.decoder=="gui-icon-v1" and str(result.error).is_empty():
			if not result.value.animations.is_empty(): result.error="Animated original GUI icon template needs a native up-pose adapter"
			else: result.merge(icon_textures(reader,result.value,job.options.get("icon_layers",[]),str(job.cache_directory)),true)
		phase_began=Time.get_ticks_usec()
		if job.decoder in ["actor-model","static-model"] and str(result.error).is_empty() and result.value.has("animations"):
			if shared_animation_preparation_enabled: attach_shared_rig(job,result,phases)
			else: result.value.rig_asset=rig_data(result.value,result.animation_sources,str(job.cache_directory))
		phases.rig_ms=(Time.get_ticks_usec()-phase_began)/1000.0
		# Start the exact-cohort optional read before texture/prework work. Its
		# owned thread joins on this asset worker at publish_result, never main.
		if native_draw_cache_lease:NativeDrawCache.begin_on_worker(job,result)
		phase_began=Time.get_ticks_usec()
		if job.decoder in ["static-model","actor-model"] and str(result.error).is_empty():
			var textures := {}; var dependencies: Array = []; var missing_textures: Array=[]
			var palette_override: Dictionary={}
			# Body-part PLTs replace the model bitmap as a whole, following the
			# explicit original candidate order. Present corrupt PLTs are errors.
			for candidate in job.options.get("plt_candidates",[]):
				if not reader.has_resource(str(candidate),6): continue
				palette_override=Palette.new().prepare(reader,str(candidate),job.options.get("palette_colors",[]),str(job.cache_directory))
				if not str(palette_override.get("error","")).is_empty(): result.error=palette_override.error
				break
			for part in result.value.nodes:
				if not str(result.error).is_empty(): break
				# Collision-only / authored non-rendering parts retain their mesh
				# data, but their unused bitmaps are not display dependencies.
				if not part.mesh.get("render",false): continue
				for texture_name in part.mesh.get("textures",[]):
					var name := str(texture_name).to_lower()
					if name.is_empty() or name == "null" or textures.has(name): continue
					if not palette_override.is_empty():
						textures[name]=palette_override; dependencies.append({"name":name,"sha256":palette_override.sha256,"cache_hit":palette_override.cache_hit,"palette":true}); continue
					var replacement:Variant=job.options.get("texture_overrides",{}).get(name,name)
					if replacement is Dictionary:
						var gui_palette:=GuiPalette.prepare(reader,replacement,str(job.cache_directory))
						if not str(gui_palette.get("error","")).is_empty():result.error=gui_palette.error;break
						if job.options.has("gui_texture_info"):gui_palette=GuiTextureInfo.attach(reader,str(replacement.resource),gui_palette)
						if not reader.failure.is_empty():result.error=reader.failure;break
						textures[name]=gui_palette;dependencies.append({"name":name,"replacement":replacement.resource,"sha256":gui_palette.sha256,"cache_hit":gui_palette.cache_hit,"palette":true,"selector":gui_palette.selector,"palette_source":gui_palette.palette_source});continue
					var raster_name:=str(replacement)
					var selected: Dictionary = {"name":name,"type":6} if job.options.has("palette_colors") and reader.has_resource(name,6) else reader.raster_location(raster_name)
					if selected.is_empty():
						# An explicit original lookup failure is different from a
						# capture gap. Retain the mesh's untextured material and
						# expose the absence; never invent a replacement bitmap.
						if reader.has_method("recorded_texture_miss") and reader.recorded_texture_miss(name):
							textures[name]={}; missing_textures.append(name); dependencies.append({"name":name,"recorded_missing":true}); continue
						result.error = "Original texture unavailable: " + name; break
					if int(selected.type)==6:
						var palette:=Palette.new().prepare(reader,name,job.options.get("palette_colors",[]),str(job.cache_directory))
						if not str(palette.get("error","")).is_empty(): result.error=palette.error; break
						textures[name]=palette; dependencies.append({"name":name,"sha256":palette.sha256,"cache_hit":palette.cache_hit,"palette":true}); continue
					var read_began := Time.get_ticks_usec()
					var raw: PackedByteArray = reader.get_resource(raster_name,int(selected.type))
					var read_ms := (Time.get_ticks_usec()-read_began)/1000.0
					if not reader.failure.is_empty(): result.error = reader.failure; break
					var raster := decode(raw,int(selected.type),"raster",str(job.cache_directory),job.decoder_store)
					if not str(raster.error).is_empty(): result.error = name + ": " + str(raster.error); break
					if job.options.has("gui_texture_info"):
						raster=GuiTextureInfo.attach(reader,raster_name,raster)
						if not reader.failure.is_empty(): result.error=reader.failure; break
					textures[name] = raster; dependencies.append({"name":name,"sha256":raster.sha256,"cache_hit":raster.cache_hit,"read_ms":read_ms,"timings":raster.timings})
				if not str(result.error).is_empty(): break
			result.textures = textures; result.dependencies = dependencies; result.missing_textures=missing_textures
			if str(result.error).is_empty():
				var emitter:=prepare_emitter_textures(reader,result.value,str(job.cache_directory))
				if not str(emitter.error).is_empty(): result.error=emitter.error
				else:
					result.emitter_textures=emitter.textures; result.dependencies.append_array(emitter.dependencies)
		phases.textures_ms=(Time.get_ticks_usec()-phase_began)/1000.0
	phase_began=Time.get_ticks_usec()
	if inputs!=null and str(result.error).is_empty(): result.prework_inputs=inputs.snapshot()
	if job.prework_write and not prework_key.is_empty() and str(result.error).is_empty():
		result.prework_saved=prework.save_entry(prework_key,result.prework_inputs,bundle_content(result),int(job.prework_ticket))
		if not result.prework_saved: result.prework_error=prework.failure
	result.prework_icon_key=icon_key
	if not memory_key.is_empty() and str(result.error).is_empty() and not job.status_only:
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
	mutex.lock(); results[job.id]=packet; mutex.unlock()
func bundle_content(result: Dictionary) -> Dictionary:
	var content: Dictionary={}
	for field in ["value","sha256","animation_sources","animation_view_identity","textures","emitter_textures","dependencies","missing_textures","prework_inputs"]:
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
	var prepared_rig:=shared_rig_data(result.value,result.get("animation_sources",[]),str(job.cache_directory),job.decoder_store,str(result.get("animation_view_identity","")),result.value.get("rig_asset",{}))
	result.value.rig_asset=prepared_rig.value
	phases.shared_rig_preparation={"hit":prepared_rig.hit,"wait_ms":int(prepared_rig.wait_us)/1000.0,"elapsed_ms":prepared_rig.elapsed_ms,"resident":prepared_rig.resident,"first_use":prepared_rig.first_use,"seeded":prepared_rig.seeded,"admitted":prepared_rig.admitted,"derived_cache":SharedAnimation.snapshot(job.decoder_store)}
func prepare_emitter_textures(reader,model: Dictionary,cache_path: String) -> Dictionary:
	# Emitter bitmaps are original particle textures, never body-part PLT
	# replacements, even if the same model also contains a recolored mesh.
	var textures: Dictionary={}; var dependencies: Array=[]
	for part in model.nodes:
		if not part.has("emitter"): continue
		var name:=str(part.emitter.get("texture","")).to_lower()
		if name in ["","null"] or textures.has(name): continue
		var selected: Dictionary=reader.raster_location(name)
		if selected.is_empty():
			if reader.has_resource(name,6): return {"error":"Original emitter PLT requires a particle palette provider: "+name}
			var recorded: bool=reader.has_method("recorded_texture_miss") and reader.recorded_texture_miss(name)
			# Stock models contain dormant damage emitters naming absent bitmaps
			# (for example fxpa_cloud02). Keep their real geometry and preserve
			# the unavailable emitter explicitly; never invent a replacement.
			textures[name]={}; dependencies.append({"name":name,"role":"emitter","missing":true,"recorded_missing":recorded}); continue
		var raw: PackedByteArray=reader.get_resource(name,int(selected.type))
		if not reader.failure.is_empty(): return {"error":reader.failure}
		var raster:=decode(raw,int(selected.type),"raster",cache_path,decoded_store(reader))
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
			var raw: PackedByteArray=reader.get_resource(str(layer.name),int(selected.type))
			if not reader.failure.is_empty(): return {"error":reader.failure}
			raster=decode(raw,int(selected.type),"raster",cache_path,decoded_store(reader))
		if not str(raster.get("error","")).is_empty(): return {"error":raster.error}
		raster=GuiTextureInfo.attach(reader,str(layer.name),raster)
		if not reader.failure.is_empty(): return {"error":reader.failure}
		var replacement:="gui_replace"+str(index+1).pad_zeros(2); textures[replacement]=raster; dependencies.append({"name":layer.name,"sha256":raster.sha256,"cache_hit":raster.cache_hit})
	for part in model.nodes:
		if not part.mesh.get("render",false): continue
		for name in part.mesh.get("textures",[]):
			if str(name) not in ["","null"] and not textures.has(str(name).to_lower()): return {"error":"Original GUI icon has an unmatched replacement texture: "+str(name)}
	return {"textures":textures,"dependencies":dependencies}
func actor_data(reader, name: String, bytes: PackedByteArray, cache_path: String, ancestors: Array, relevant_nodes: Variant=null) -> Dictionary:
	# Only the required/high-priority actor can start helpers. Other sources may
	# reuse its immutable decoded work, without spawning competing helper waves.
	var prefetch: Dictionary={}
	if ancestors.is_empty() and high_priority and ancestor_preparation_enabled: prefetch=Ancestors.start(reader,name,bytes,cache_path,decode)
	var result:=actor_data_serial(reader,name,bytes,cache_path,ancestors,relevant_nodes)
	# Join on every normal/error return before the asset owner can retire. Child
	# results affect caching/timings only; authoritative parsing owns correctness.
	if not prefetch.is_empty(): result.ancestor_preparation=Ancestors.finish(prefetch)
	return result
func actor_data_serial(reader, name: String, bytes: PackedByteArray, cache_path: String, ancestors: Array, relevant_nodes: Variant=null) -> Dictionary:
	if ancestors.size()>=16 or ancestors.has(name.to_lower()): return {"error":"Original actor supermodel inheritance cycle/depth"}
	var decoded:=decode(bytes,2002,ActorModel.SOURCE_DECODER,cache_path,decoded_store(reader))
	if not str(decoded.error).is_empty(): return decoded
	decoded.preparation_sources=[{"name":name,"source_bytes":bytes.size(),"memory_hit":decoded.get("memory_decode_hit",false),"timings":decoded.get("timings",{})}]
	var model: Dictionary=decoded.value; var parent_name:=str(model.get("supermodel","")).to_lower()
	# Runtime rigs can only bind tracks to this piece's actual nodes. Carry that
	# selection up the supermodel chain before expanding inherited keyframes.
	# Keep empty clips, overrides, clocks/events and root aliases unchanged.
	var selected: Variant=null
	if relevant_nodes is Dictionary:
		selected=relevant_nodes.duplicate()
		if selected.is_empty():
			for node in model.nodes: selected[str(node.name).to_lower()]=true
		selected[str(model.name).to_lower()]=true
		var clips: Array=[]
		for original in model.animations:
			var clip: Dictionary=original.duplicate(); clip.tracks=[]
			for track in original.tracks:
				if selected.has(str(track.node).to_lower()): clip.tracks.append(track)
			clip.emitter_tracks=[]
			for track in original.get("emitter_tracks",[]):
				if selected.has(str(track.node).to_lower()): clip.emitter_tracks.append(track)
			clips.append(clip)
		model.animations=clips
	decoded.animation_sources=[{"name":name,"sha256":decoded.sha256}]
	if parent_name in ["","null","****"]:
		if shared_animation_preparation_enabled: decoded.animation_view_identity=SharedAnimation.view_identity(decoded.animation_sources,selected)
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
	if shared_animation_preparation_enabled: decoded.animation_view_identity=SharedAnimation.view_identity(decoded.animation_sources,selected)
	model.animations.append_array(inherited_clips(model,parent.value,parent_name).clips)
	return decoded
func inherited_clips(model: Dictionary,parent: Dictionary,parent_name: String) -> Dictionary:
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
			if str(track.property)=="position" and scale_value!=1.0:
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
	return {"clips":inherited}
func shared_rig_data(model: Dictionary,sources: Array,cache_path: String,store,view_identity: String,seed: Dictionary={}) -> Dictionary:
	# Source-chain bytes plus selected node names distinguish filtered skeleton
	# views. In particular, a filtered derivative must never satisfy a full rig.
	var identity:=Cache.digest(var_to_bytes([sources,view_identity]))
	return SharedAnimation.acquire(store,"rig:"+identity,build_shared_rig.bind(model,identity,cache_path),seed)
func build_shared_rig(model: Dictionary,identity: String,cache_path: String) -> Dictionary:
	var decoder:="actor-rig-shared-v1"; var key:=Cache.key(identity,decoder)
	var cache:=Cache.new(); var enabled:=not cache_path.is_empty() and cache.configure(cache_path)
	if enabled:
		var saved:=cache.load_data(key,identity,decoder)
		if not saved.is_empty(): return saved
	var result:=ActorModel.new().rig_asset(model)
	if enabled: cache.save_data(key,identity,decoder,result)
	return result
func rig_data(model: Dictionary,sources: Array,cache_path: String) -> Dictionary:
	var identity:=Cache.digest(var_to_bytes(sources)); var decoder:="actor-rig-emitter-v12-ascii-native"; var key:=Cache.key(identity,decoder)
	var cache:=Cache.new(); var enabled:=not cache_path.is_empty() and cache.configure(cache_path)
	if enabled:
		var saved:=cache.load_data(key,identity,decoder)
		if not saved.is_empty(): return saved
	var result:=ActorModel.new().rig_asset(model)
	if enabled: cache.save_data(key,identity,decoder,result)
	return result
func resource_metrics(reader) -> Dictionary:
	var value: Variant=reader.get("stats")
	return value.duplicate() if value is Dictionary else {}
func decoded_store(reader):
	return reader.decoded_cache() if reader.has_method("decoded_cache") else (reader.preparation_cache() if reader.has_method("preparation_cache") else null)
func decode(bytes: PackedByteArray, type: int, decoder: String, cache_path: String, store=null, immutable_source: bool=false) -> Dictionary:
	if store==null or decoder=="bytes": return decode_uncached(bytes,type,decoder,cache_path)
	var began:=Time.get_ticks_usec(); var source_sha:=Cache.digest(bytes)
	var request_key:="decoded-native-v1:"+str(type)+":"+decoder+":"+source_sha+(":ambient-1:vertex-color-1:"+Prework.MODEL_METADATA_REVISION if decoder.begins_with("mdl-") else "")+(":"+mesh_revision() if mesh_preparation_enabled and decoder.begins_with("mdl-") else "")
	var immutable_model:=decoder in ["mdl-actor-v2","mdl-actor-packed-v1","mdl-actor-packed-v2","mdl-actor-packed-v3",ActorModel.SOURCE_DECODER]
	var borrowed:=immutable_model or decoder=="2da" and immutable_source
	var generation:=int(store.generation()); var lease: Dictionary=store.begin_data(request_key,generation,not borrowed)
	if not lease.owner:
		var shared: Dictionary=lease.value.result
		var saved: Dictionary=private_model_source(shared) if immutable_model and str(shared.get("error","")).is_empty() else (shared.duplicate() if borrowed else shared)
		saved.memory_decode_hit=true; saved.timings={"memory_decode_ms":(Time.get_ticks_usec()-began)/1000.0,"coalesced_wait_ms":int(lease.wait_us)/1000.0}
		return saved
	var decoded:=decode_uncached(bytes,type,decoder,cache_path,source_sha,prepared_write_lease and decoder.begins_with("mdl-"))
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
		var write_began:=Time.get_ticks_usec()
		var accepted:=CacheWrites.enqueue(cache_path,str(deferred_write.key),source_sha,decoder,decoded.value,store.retained_size(request_key,generation))
		owned.timings.cache_write_deferred=accepted; owned.timings.cache_write_skipped=not accepted; owned.timings.cache_write_enqueue_ms=(Time.get_ticks_usec()-write_began)/1000.0
	return owned
func private_model_source(source: Dictionary) -> Dictionary:
	# Geometry, original controller/keyframe streams and node definitions remain
	# immutable shared input. Inheritance/filtering modifies only these owners.
	var result:=source.duplicate(); var model: Dictionary=source.value.duplicate()
	model.animations=model.animations.duplicate(); result.value=model
	return result
func mesh_revision() -> String:
	return MeshPreparation.REVISION+(":"+SkinPreparation.REVISION if skin_preparation_enabled else "")
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
	if mesh_preparation_enabled and decoder.begins_with("mdl-"): identity=Cache.key(identity,mesh_revision())
	if decoder=="tile-surface-v1": identity=Cache.key(source_sha,decoder+":"+str(type)+":vertical-bounds-1")
	var timings := {"identity_ms":(Time.get_ticks_usec()-began)/1000.0,"cache_read_ms":0.0,"decode_ms":0.0,"cache_write_ms":0.0}
	if decoder=="2da": timings.cache_policy="original-bytes-and-session-decoding"
	if cache_ok and decoder != "bytes":
		began = Time.get_ticks_usec()
		var saved := cache.load_data(identity,source_sha,decoder)
		timings.cache_read_ms = (Time.get_ticks_usec()-began)/1000.0
		if not saved.is_empty(): return {"value":saved,"error":"","sha256":source_sha,"cache_hit":true,"timings":timings}
	var result := {"error":"","sha256":source_sha,"cache_hit":false,"timings":timings}
	began = Time.get_ticks_usec()
	match decoder:
		"ltr-native-v1":
			var decoded:=LetterTable.decode(bytes);result.value=decoded;result.error="" if decoded.ready else str(decoded.reason)
		"wave-native-v1":
			var parser:=WaveData.new(); result.value=parser.parse(bytes); result.error=parser.failure
		"ssf-native-v1":
			var parser:=SoundSet.new(); result.value=parser.parse(bytes); result.error=parser.failure
		"nui-skin-v1":
			var parser := UiSkin.new(); result.value = parser.parse(bytes.get_string_from_utf8()); result.error = parser.failure
		"bitmap-font-v1":
			var parser:=preload("res://systems/native_data/bitmap_font.gd").new(); result.value=parser.parse(bytes.get_string_from_ascii()); result.error=parser.failure
		"font-v1":
			var parser := FontData.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"tile-surface-v1":
			var parser := TileSurface.new(); result.value = parser.parse_bytes(bytes); result.error = parser.failure
		"pwk-surface-v1", "dwk-surface-v1":
			var parser := ObjectSurface.new(); result.value = parser.parse(bytes,decoder=="dwk-surface-v1"); result.error = parser.failure
		"gff":
			var parser := Gff.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"2da":
			var parser := Table.new(); result.value = parser.parse(Binary.new(bytes).text(0,bytes.size())); result.error = parser.failure
		"mdl-binary":
			var parser := Model.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"mdl-actor-v2":
			var parser := ActorModel.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"mdl-actor-packed-v1", "mdl-actor-packed-v2", "mdl-actor-packed-v3", "mdl-actor-packed-v4", ActorModel.SOURCE_DECODER:
			var parser:=ActorModel.new(); parser.packed_keys=true; result.value=parser.parse(bytes); result.error=parser.failure
		"mdl-original":
			if bytes.size()>=4 and bytes.decode_u32(0)==0:
				var parser := Model.new(); result.value = parser.parse(bytes); result.error = parser.failure
			else:
				var parser := AsciiModel.new(); result.value = parser.parse(Binary.new(bytes).text(0,bytes.size())); result.error = parser.failure
		"raster":
			var parser := Raster.new(); result.value = parser.parse(bytes,type); result.error = parser.failure; timings.raster_conversion=parser.stats.duplicate()
	timings.decode_ms = (Time.get_ticks_usec()-began)/1000.0
	if mesh_preparation_enabled and decoder.begins_with("mdl-") and str(result.error).is_empty():
		var prepared:=MeshPreparation.model(result.value,skin_preparation_enabled); timings.mesh_preparation=prepared
		if not str(prepared.error).is_empty(): result.error=prepared.error
	if cache_ok and decoder != "bytes" and str(result.error).is_empty():
		began = Time.get_ticks_usec()
		if defer_write and CacheWrites.configured_enabled() and Cache.configured_writes_enabled(): result.deferred_cache_write={"key":identity}
		else: cache.save_data(identity,source_sha,decoder,result.value)
		timings.cache_write_ms = (Time.get_ticks_usec()-began)/1000.0
		timings.cache_write_phases=cache.last_save
	return result
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_assets",began)
func _profile_process(_delta: float) -> void:
	if native_draw_cache_lease:NativeDrawCache.poll()
	Timing.count("count_asset_workers",running.size()); Timing.count("count_asset_queued",pending.size())
	for id in running.keys():
		if not running.has(id): continue
		var task: int = running[id]
		if not WorkerThreadPool.is_task_completed(task): continue
		WorkerThreadPool.wait_for_task_completion(task)
		running.erase(id)
		mutex.lock(); var result: Dictionary = results.get(id, {}); results.erase(id); mutex.unlock()
		if not closed and int(result.get("epoch", -1)) == epoch: completed.emit(int(id), result)
	pump()
func retire_scope() -> void:
	epoch += 1; pending.clear()
func detach_retired_results() -> Dictionary:
	# World retirement calls this after observing real worker completion. The
	# pure decoded result graphs can then be released by the data worker owner.
	if running.values().any(func(task):return not WorkerThreadPool.is_task_completed(int(task))): return {}
	mutex.lock(); var detached:=results; results={}; mutex.unlock()
	return {"asset_results":detached} if not detached.is_empty() else {}
func close() -> void:
	closed = true; retire_scope()
	for task in running.values(): WorkerThreadPool.wait_for_task_completion(int(task))
	running.clear(); mutex.lock(); results.clear(); mutex.unlock()
	catalog = null
	if prepared_write_lease: prepared_write_lease=false; CacheWrites.release()
	if native_draw_cache_lease:native_draw_cache_lease=false;NativeDrawCache.release()
func _exit_tree() -> void: close()
