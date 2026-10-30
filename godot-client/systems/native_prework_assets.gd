extends "res://systems/native_data/asset_service.gd"
# Preparation-only diagnostics and dependency-checked rejection memoization.
# A remembered failure remains unavailable, never a successfully baked model.
func _work(submitted: Dictionary) -> void:
	# The dispatcher still reads its envelope after add_task returns. Keep all
	# instrumentation mutations private; Dictionary writes can rehash its keys.
	var job:=submitted.duplicate()
	Prework.take_save_timing() # Discard any previous job's timing on this thread.
	job.prework_started=Time.get_ticks_usec()
	var tracked=Prework.Inputs.new(job.catalog); job.catalog=tracked
	var bytes: PackedByteArray=tracked.get_resource(str(job.name),int(job.type))
	var memo:=Prework.new(); job.rejection_store=memo; job.rejection_key=""
	if job.prework_read and tracked.failure.is_empty() and memo.configure(str(job.cache_directory)):
		var identity:=Prework.request_key(str(job.name),int(job.type),str(job.decoder),job.options,Cache.digest(bytes),[mesh_preparation_enabled,skin_preparation_enabled,mesh_revision()])
		job.rejection_key=Cache.key(identity,"prework-rejection-v1")
		var saved:=memo.load_entry(str(job.rejection_key),tracked.source)
		if not str(saved.get("error","")).is_empty():
			publish_result(job,{"id":job.id,"epoch":job.epoch,"resource_name":job.name,"error":str(saved.error),"thread":OS.get_thread_caller_id(),"rejection_hit":true}); return
	super._work(job)
	var saved_timing:=Prework.take_save_timing()
	# Include temporary decoded graphs released as the base worker returns.
	mutex.lock()
	if results.has(job.id):
		results[job.id].worker_ms=(Time.get_ticks_usec()-int(job.prework_started))/1000.0
		if not saved_timing.is_empty(): results[job.id].prework_phases.save=saved_timing
	mutex.unlock()
func deterministic_error(error: String) -> bool:
	for prefix in ["Invalid ASCII","ASCII MDL","Non-finite or invalid ASCII","Truncated or missing ASCII","Truncated ASCII","Original ASCII skin"]:
		if error.begins_with(prefix): return true
	return false
func publish_result(job: Dictionary,result: Dictionary) -> void:
	var rejection_hit:=bool(result.get("rejection_hit",false)); var error:=str(result.get("error",""))
	if job.prework_write and not rejection_hit and deterministic_error(error) and not str(job.get("rejection_key","")).is_empty():
		job.rejection_store.save_entry(str(job.rejection_key),job.catalog.snapshot(),{"error":error},int(job.prework_ticket))
	var phases: Dictionary={}
	for name in ["memory_lookup_ms","model_ms","rig_ms","textures_ms","memory_save_ms"]:
		if result.get("phases",{}).has(name): phases[name]=float(result.phases[name])
	super.publish_result(job,result)
	mutex.lock()
	if results.has(job.id):
		results[job.id].prework_route=str(job.decoder); results[job.id].rejection_hit=rejection_hit; results[job.id].prework_phases=phases
		results[job.id].worker_ms=(Time.get_ticks_usec()-int(job.prework_started))/1000.0
	mutex.unlock()
