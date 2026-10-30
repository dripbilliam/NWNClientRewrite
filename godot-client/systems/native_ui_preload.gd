extends Node
# Explicit UI-only preparation. Original resource discovery/decoding and disk
# publication run on workers; the bounded private GUI viewport stays native.
signal changed(state: Dictionary)
const Sources=preload("res://systems/native_data/session_catalog.gd")
const Plan=preload("res://systems/native_data/ui_prebake_plan.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Fonts=preload("res://systems/native_bitmap_fonts.gd")
const Store=preload("res://systems/native_data/prework_store.gd")
var state: Dictionary={"active":false,"completed":0,"total":0,"saved":0,"reused":0,"failed":0,"message":"Choose local content, then preload its menus."}
var loader
var catalog
var owns_catalog:=false
var assets
var icons
var fonts
var plan_task:=-1
var plan_result: Dictionary={}
var gate:=Mutex.new()
var stopping:=false
var closed:=false
var cache_path:=""
var store:=Store.new()
var ticket:=0
var jobs: Array=[]
var cursor:=0
var data_jobs: Array=[]
var active_icon:=""
var active_hit_count:=0
var pending_packet: Dictionary={}
var saves: Dictionary={}
var save_results: Dictionary={}
var save_serial:=0
var save_bytes:=0
var maximum_save_bytes:=64*1024*1024
var maximum_saves:=2
var models_in_batch:=0
var previous_model:=""
var started_ms:=0
var last_publish:=0
var font_counted:=false
var font_names: Array=[]
var capture_opened:=false
var captures: Array=[]
# Test fixtures may bound the discovery set; the user action leaves this empty.
var model_filter: Array=[]
func start_sources(sources: Dictionary,path: String) -> bool:
	if not begin(path): return false
	loader=Sources.new(); add_child(loader)
	loader.completed.connect(func(_serial: int,prepared: RefCounted,error: String,_stats: Dictionary):
		var finished=loader; loader=null; finished.queue_free()
		catalog=prepared; owns_catalog=true
		if stopping: finish(true); return
		if not error.is_empty(): issue(error); finish(false); return
		start_plan())
	loader.start(sources); publish(true); return true
func start(source,path: String) -> bool:
	if not begin(path): return false
	catalog=source; owns_catalog=false; start_plan(); return true
func begin(path: String) -> bool:
	if closed or state.active: return false
	if DisplayServer.get_name()=="headless": state.message="UI preload needs the graphical client."; publish(true); return false
	if not store.configure(path): state.message=store.failure; publish(true); return false
	cache_path=path; ticket=store.generation(); stopping=false; cursor=0; jobs=[]; data_jobs=[]; font_names=[]; previous_model=""; models_in_batch=0; font_counted=false; started_ms=Time.get_ticks_msec()
	state={"active":true,"completed":0,"total":0,"saved":0,"reused":0,"failed":0,"rendered":0,"cancelled":false,"issues":[],"message":"Finding menus in selected local content…","peak_save_bytes":0,"peak_saves":0,"peak_private_images":0,"renderer_batches":0}
	captures=[]
	if capture_opened:
		for owner in get_tree().get_nodes_in_group("native_prework_icons"):
			if not owner.closed and owner.cache_directory==path:
				for key in owner.prework_records: captures.append({"owner":weakref(owner),"key":key})
	return true
func start_plan() -> void:
	var reader=catalog.fork(); var filter:=model_filter.duplicate()
	plan_task=WorkerThreadPool.add_task(func():
		var result:=Plan.discover(reader); var images: Array=[]; var skipped:=0
		for name in result.models:
			if cancelled(): break
			if not filter.is_empty() and name not in filter: continue
			var bytes: PackedByteArray=reader.get_resource(str(name),2002); var parser:=Model.new(); parser.packed_keys=true
			var model: Dictionary=parser.parse(bytes) if reader.failure.is_empty() else {}
			var error: String=reader.failure if not reader.failure.is_empty() else parser.failure
			if not error.is_empty(): result.issues.append({"resource":name,"error":error}); continue
			if str(model.get("supermodel","")).to_lower() in ["","null"] and not model.get("nodes",[]).any(func(row):return row.get("mesh",{}).get("render",false)):
				skipped+=1; continue # Non-drawing helper resources have no menu pixels.
			var states: Array=Plan.states(model)
			# Consumers also request the default up state for static models.
			if not "up" in states: states.append("up")
			for clip in states: images.append({"name":name,"clip":clip})
		result.images=images; result.skipped_helpers=skipped
		var names: Dictionary={}
		for font in result.fonts: names[str(font)]=true
		for font in reader.resource_names(2022):
			# Bitmap fonts use TXI metadata, but ordinary texture TXIs are not
			# fonts. GUI-declared custom names above need no stock prefix.
			if str(font).begins_with("fnt_") and not reader.raster_location(str(font)).is_empty(): names[str(font)]=true
		if reader.has_resource("fnt_default",2074): names["ttf fnt_default 14"]=true
		result.fonts=names.keys(); result.fonts.sort()
		gate.lock(); plan_result=result; gate.unlock(),false,"Discover original menu assets")
	publish(true)
func cancelled() -> bool:
	gate.lock(); var value:=stopping; gate.unlock(); return value
func cancel() -> void:
	if not state.active: return
	gate.lock(); stopping=true; gate.unlock()
	if is_instance_valid(loader): loader.cancel()
	state.message="Finishing active UI work; completed menus remain saved…"; publish(true)
func _process(_delta: float) -> void:
	if not state.active or loader!=null: return
	collect_saves()
	if plan_task>=0:
		if not WorkerThreadPool.is_task_completed(plan_task): publish(); return
		WorkerThreadPool.wait_for_task_completion(plan_task); plan_task=-1
		gate.lock(); var plan:=plan_result; plan_result={}; gate.unlock()
		if stopping: finish(true); return
		jobs=plan.images; data_jobs=[]
		for source in plan.gui_sources: data_jobs.append({"name":source.name,"type":2047,"decoder":"gff","options":{}})
		# Layout owners inspect original model bounds/controllers before asking
		# for pixels. Bake their default assembled-model request too, so opening
		# a menu does not redo that preparation merely to construct its controls.
		for name in plan.models:
			if not model_filter.is_empty() and name not in model_filter: continue
			data_jobs.append({"name":name,"type":2002,"decoder":"actor-model","options":{}})
		state.gui_documents=plan.gui_sources.size(); state.models=plan.models.size(); state.fonts=plan.fonts.size(); state.skipped_helpers=plan.skipped_helpers; state.missing_references=plan.missing_references
		for problem in plan.issues: issue(str(problem.resource)+": "+str(problem.error))
		state.total=jobs.size()+data_jobs.size()+plan.fonts.size()+captures.size()
		assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.maximum_pending=2; assets.status_only=true; assets.prework_write=true; assets.cache_directory=cache_path; assets.configure(catalog); assets.completed.connect(data_ready)
		fonts=Fonts.new(); add_child(fonts); fonts.configure(catalog,cache_path)
		font_names=plan.fonts.duplicate()
		new_renderer(); publish(true)
	if stopping:
		if not active_icon.is_empty() or not pending_packet.is_empty() or not saves.is_empty(): flush_packet(); publish(); return
		if is_instance_valid(assets) and not assets.running.is_empty(): publish(); return
		if is_instance_valid(fonts) and not fonts.pending.is_empty(): publish(); return
		finish(true); return
	while not font_names.is_empty() and fonts.pending.size()<2: fonts.request(str(font_names.pop_front()))
	if is_instance_valid(fonts) and not font_counted and font_names.is_empty() and fonts.pending.is_empty():
		font_counted=true
		for name in fonts.failed: issue(str(name)+": "+str(fonts.failed[name]))
		state.completed+=int(state.fonts)
	while not data_jobs.is_empty() and assets.running.size()+assets.pending.size()<2:
		var row: Dictionary=data_jobs.pop_front()
		if assets.request(str(row.name),int(row.type),str(row.decoder),row.options)<0: issue(assets.failure); state.completed+=1
	flush_packet()
	if active_icon.is_empty() and pending_packet.is_empty() and saves.size()<maximum_saves and save_bytes<maximum_save_bytes and cursor<jobs.size():
		var job: Dictionary=jobs[cursor]; cursor+=1
		if str(job.name)!=previous_model:
			if models_in_batch>=16: new_renderer()
			models_in_batch+=1; previous_model=str(job.name)
		state.message="Preloading menus · "+str(job.name)+(" · "+str(job.clip) if not str(job.clip).is_empty() else "")
		active_hit_count=int(icons.stats.get("prework_hits",0)); active_icon=icons.request_model(str(job.name),str(job.clip))
		if active_icon.is_empty(): issue("Could not prepare "+str(job.name)); state.completed+=1
	if cursor>=jobs.size() and not captures.is_empty() and active_icon.is_empty() and pending_packet.is_empty() and saves.size()<maximum_saves:
		var capture: Dictionary=captures.pop_front(); var owner=capture.owner.get_ref()
		pending_packet=owner.prework_packet(str(capture.key)) if is_instance_valid(owner) and not owner.closed else {}
		if pending_packet.is_empty(): state.completed+=1; state.skipped_retired=int(state.get("skipped_retired",0))+1
		else: flush_packet()
	if cursor>=jobs.size() and captures.is_empty() and data_jobs.is_empty() and active_icon.is_empty() and pending_packet.is_empty() and saves.is_empty() and assets.running.is_empty() and assets.pending.is_empty() and font_counted: finish(false); return
	publish()
func new_renderer() -> void:
	if is_instance_valid(icons): icons.close(); icons.queue_free()
	icons=Icons.new(); add_child(icons); icons.configure(catalog,cache_path); icons.assets.prework_write=true; icons.maximum_cached_models=16; icons.assets.maximum_workers=2; icons.assets.maximum_pending=2; icons.completed.connect(image_ready)
	models_in_batch=0; state.renderer_batches+=1
func image_ready(key: String,_texture: Texture2D,error: String) -> void:
	if key!=active_icon or not state.active: return
	active_icon=""
	if not error.is_empty(): issue(key+": "+error); state.completed+=1
	elif int(icons.stats.get("prework_hits",0))>active_hit_count:
		state.reused+=1; state.completed+=1
	else:
		state.rendered+=1; pending_packet=icons.prework_packet(key)
		if pending_packet.is_empty(): issue("Menu pixels could not be saved: "+key); state.completed+=1
	state.peak_private_images=maxi(int(state.peak_private_images),icons.textures.size())
	# The baking owner has no visible consumers. Retain only saved immutable
	# packets, never thousands of full-size menu textures in VRAM.
	icons.textures.erase(key); icons.image_bounds.erase(key); icons.prework_records.erase(key)
	flush_packet()
func flush_packet() -> void:
	if pending_packet.is_empty() or saves.size()>=maximum_saves: return
	var bytes: int=pending_packet.data.pixels.size()
	if save_bytes+bytes>maximum_save_bytes and not saves.is_empty(): return
	var packet:=pending_packet; pending_packet={}; var path:=cache_path; var epoch_ticket:=ticket; var reader=catalog.fork()
	save_serial+=1; var id:=save_serial
	var task:=WorkerThreadPool.add_task(func():
		var writer:=Store.new(); var ok:=writer.configure(path) and writer.save_entry(str(packet.key),packet.inputs,packet.data,epoch_ticket)
		if ok: ok=Store.valid_icon(writer.load_entry(str(packet.key),reader))
		gate.lock(); save_results[id]={"ok":ok,"error":writer.failure}; gate.unlock(),false,"Save prepared menu pixels")
	saves[id]={"task":task,"bytes":bytes}; save_bytes+=bytes
	state.peak_save_bytes=maxi(int(state.peak_save_bytes),save_bytes); state.peak_saves=maxi(int(state.peak_saves),saves.size())
func collect_saves() -> void:
	for id in saves.keys():
		if not WorkerThreadPool.is_task_completed(int(saves[id].task)): continue
		WorkerThreadPool.wait_for_task_completion(int(saves[id].task)); save_bytes-=int(saves[id].bytes); saves.erase(id)
		gate.lock(); var result: Dictionary=save_results.get(id,{}); save_results.erase(id); gate.unlock()
		if result.get("ok",false): state.saved+=1
		else: issue("Could not verify saved menu pixels. "+str(result.get("error","")))
		state.completed+=1
func data_ready(_id: int,result: Dictionary) -> void:
	var error:=str(result.get("error",""))
	if error.is_empty(): error=str(result.get("prework_error",""))
	if not error.is_empty(): issue(str(result.get("resource_name","GUI"))+": "+error)
	state.completed+=1
func issue(message: String) -> void:
	if message in state.issues: return
	state.failed+=1
	if state.issues.size()<24: state.issues.append(message)
	state.last_error=message
func publish(force: bool=false) -> void:
	if not force and Time.get_ticks_msec()-last_publish<100: return
	last_publish=Time.get_ticks_msec(); state.elapsed_ms=last_publish-started_ms if started_ms>0 else 0; state.running=saves.size()+(1 if not active_icon.is_empty() else 0); changed.emit(state.duplicate(true))
func release_resources() -> void:
	for owner in [icons,fonts,assets]:
		if is_instance_valid(owner): owner.close(); owner.queue_free()
	icons=null; fonts=null; assets=null
	if owns_catalog and catalog!=null:
		for layer in catalog.layers:
			if layer.get("kind","")=="nwsync": layer.store.close()
	catalog=null; owns_catalog=false
func finish(was_cancelled: bool) -> void:
	release_resources(); jobs=[]; data_jobs=[]; captures=[]; state.active=false; state.cancelled=was_cancelled; state.running=0
	state.message="UI preload cancelled. Completed menus remain saved." if was_cancelled else "Menu preload complete. Saved artwork will be reused when menus open."
	if not was_cancelled and int(state.failed)>0: state.message="Menu preload finished with unavailable resources; see details below."
	publish(true)
func close() -> void:
	if closed: return
	closed=true; gate.lock(); stopping=true; gate.unlock()
	if is_instance_valid(loader): loader.close(); loader.queue_free(); loader=null
	if plan_task>=0: WorkerThreadPool.wait_for_task_completion(plan_task); plan_task=-1
	for row in saves.values(): WorkerThreadPool.wait_for_task_completion(int(row.task))
	collect_saves(); pending_packet={}; active_icon=""; plan_result={}; release_resources(); jobs=[]; data_jobs=[]; captures=[]; state.active=false
func _exit_tree() -> void: close()
