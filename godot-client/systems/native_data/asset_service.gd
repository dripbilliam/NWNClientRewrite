extends Node
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
const ActorModel = preload("res://systems/native_data/actor_model.gd")
var catalog
var epoch := 0
var serial := 0
var maximum_workers := 4
var maximum_pending := 128
var failure := ""
var closed := false
var cache_directory := ""
var pending: Array = []
var running: Dictionary = {}
var results: Dictionary = {}
var mutex := Mutex.new()
func configure(source) -> void:
	retire_scope(); catalog = source; closed = false
func request(name: String, type: int, decoder: String = "bytes", options: Dictionary = {}) -> int:
	failure = ""
	if closed or catalog == null: failure = "Native asset service is unavailable"; return -1
	if decoder not in ["bytes", "gff", "2da", "mdl-binary", "mdl-original", "raster", "static-model", "actor-model"]: failure = "Unknown native decoder"; return -1
	if pending.size() + running.size() >= maximum_pending: failure = "Native asset queue is full"; return -1
	serial += 1
	pending.append({"id": serial, "name": name, "type": type, "decoder": decoder, "epoch": epoch, "catalog": catalog.fork(), "cache_directory": cache_directory, "options":options.duplicate(true)})
	pump()
	return serial
func pump() -> void:
	while not closed and not pending.is_empty() and running.size() < maximum_workers:
		var job: Dictionary = pending.pop_front()
		running[job.id] = WorkerThreadPool.add_task(_work.bind(job), false, "Native NWN asset " + str(job.id))
func _work(job: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	var reader = job.catalog
	var bytes: PackedByteArray = reader.get_resource(job.name, job.type)
	var result := {"id": job.id, "epoch": job.epoch, "error": reader.failure, "thread": OS.get_thread_caller_id(), "bytes": bytes, "read_ms":(Time.get_ticks_usec()-began)/1000.0}
	if reader.failure.is_empty():
		var decoded := actor_data(reader,str(job.name),bytes,str(job.cache_directory),[]) if job.decoder=="actor-model" else decode(bytes,int(job.type),"mdl-original" if job.decoder == "static-model" else str(job.decoder),str(job.cache_directory))
		result.merge(decoded,true)
		if job.decoder=="actor-model" and str(result.error).is_empty(): result.value.rig_asset=rig_data(result.value,result.animation_sources,str(job.cache_directory))
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
					var selected: Dictionary = {"name":name,"type":6} if job.options.has("palette_colors") and reader.has_resource(name,6) else reader.raster_location(name)
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
					var raw: PackedByteArray = reader.get_resource(name,int(selected.type))
					var read_ms := (Time.get_ticks_usec()-read_began)/1000.0
					if not reader.failure.is_empty(): result.error = reader.failure; break
					var raster := decode(raw,int(selected.type),"raster",str(job.cache_directory))
					if not str(raster.error).is_empty(): result.error = name + ": " + str(raster.error); break
					textures[name] = raster; dependencies.append({"name":name,"sha256":raster.sha256,"cache_hit":raster.cache_hit,"read_ms":read_ms,"timings":raster.timings})
				if not str(result.error).is_empty(): break
			result.textures = textures; result.dependencies = dependencies; result.missing_textures=missing_textures
	result.worker_ms = (Time.get_ticks_usec()-began)/1000.0
	mutex.lock(); results[job.id] = result; mutex.unlock()
func actor_data(reader, name: String, bytes: PackedByteArray, cache_path: String, ancestors: Array) -> Dictionary:
	if ancestors.size()>=16 or ancestors.has(name.to_lower()): return {"error":"Original actor supermodel inheritance cycle/depth"}
	var decoded:=decode(bytes,2002,"mdl-actor-v2",cache_path)
	if not str(decoded.error).is_empty(): return decoded
	var model: Dictionary=decoded.value; var parent_name:=str(model.get("supermodel","")).to_lower()
	decoded.animation_sources=[{"name":name,"sha256":decoded.sha256}]
	if parent_name in ["","null","****"]: return decoded
	var parent_bytes: PackedByteArray=reader.get_resource(parent_name,2002)
	if not reader.failure.is_empty(): decoded.error=reader.failure; return decoded
	var path:=ancestors.duplicate(); path.append(name.to_lower())
	var parent:=actor_data(reader,parent_name,parent_bytes,cache_path,path)
	if not str(parent.error).is_empty(): decoded.error=parent.error; return decoded
	decoded.animation_sources.append_array(parent.animation_sources)
	var own: Dictionary={}
	for clip in model.animations: own[clip.name]=true
	var scale_value:=float(model.get("animation_scale",1.0))
	for source in parent.value.animations:
		if own.has(source.name): continue
		var clip: Dictionary=source.duplicate(); clip.inheritedFrom=parent_name; clip.tracks=[]
		for original in source.tracks:
			var track: Dictionary=original.duplicate(); track.frames=[]
			if str(track.node).to_lower()==str(parent.value.name).to_lower(): track.node=model.name
			for original_frame in original.frames:
				var frame: Dictionary=original_frame.duplicate()
				if str(track.property)=="position":
					for field in ["value","in","out"]:
						if frame.has(field): frame[field]=frame[field].map(func(value): return float(value)*scale_value)
				track.frames.append(frame)
			clip.tracks.append(track)
		model.animations.append(clip)
	return decoded
func rig_data(model: Dictionary,sources: Array,cache_path: String) -> Dictionary:
	var identity:=Cache.digest(var_to_bytes(sources)); var decoder:="actor-rig-v1"; var key:=Cache.key(identity,decoder)
	var cache:=Cache.new(); var enabled:=not cache_path.is_empty() and cache.configure(cache_path)
	if enabled:
		var saved:=cache.load_data(key,identity,decoder)
		if not saved.is_empty(): return saved
	var result:=ActorModel.new().rig_asset(model)
	if enabled: cache.save_data(key,identity,decoder,result)
	return result
func decode(bytes: PackedByteArray, type: int, decoder: String, cache_path: String) -> Dictionary:
	var began := Time.get_ticks_usec()
	var source_sha := Cache.digest(bytes); var cache := Cache.new(); var cache_ok := not cache_path.is_empty() and cache.configure(cache_path)
	var identity := Cache.key(source_sha,decoder+":"+str(type))
	var timings := {"identity_ms":(Time.get_ticks_usec()-began)/1000.0,"cache_read_ms":0.0,"decode_ms":0.0,"cache_write_ms":0.0}
	if cache_ok and decoder != "bytes":
		began = Time.get_ticks_usec()
		var saved := cache.load_data(identity,source_sha,decoder)
		timings.cache_read_ms = (Time.get_ticks_usec()-began)/1000.0
		if not saved.is_empty(): return {"value":saved,"error":"","sha256":source_sha,"cache_hit":true,"timings":timings}
	var result := {"error":"","sha256":source_sha,"cache_hit":false,"timings":timings}
	began = Time.get_ticks_usec()
	match decoder:
		"gff":
			var parser := Gff.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"2da":
			var parser := Table.new(); result.value = parser.parse(Binary.new(bytes).text(0,bytes.size())); result.error = parser.failure
		"mdl-binary":
			var parser := Model.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"mdl-actor-v2":
			var parser := ActorModel.new(); result.value = parser.parse(bytes); result.error = parser.failure
		"mdl-original":
			if bytes.size()>=4 and bytes.decode_u32(0)==0:
				var parser := Model.new(); result.value = parser.parse(bytes); result.error = parser.failure
			else:
				var parser := AsciiModel.new(); result.value = parser.parse(Binary.new(bytes).text(0,bytes.size())); result.error = parser.failure
		"raster":
			var parser := Raster.new(); result.value = parser.parse(bytes,type); result.error = parser.failure
	timings.decode_ms = (Time.get_ticks_usec()-began)/1000.0
	if cache_ok and decoder != "bytes" and str(result.error).is_empty():
		began = Time.get_ticks_usec()
		cache.save_data(identity,source_sha,decoder,result.value)
		timings.cache_write_ms = (Time.get_ticks_usec()-began)/1000.0
	return result
func _process(_delta: float) -> void:
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
func close() -> void:
	closed = true; retire_scope()
	for task in running.values(): WorkerThreadPool.wait_for_task_completion(int(task))
	running.clear(); mutex.lock(); results.clear(); mutex.unlock()
	catalog = null
func _exit_tree() -> void: close()
