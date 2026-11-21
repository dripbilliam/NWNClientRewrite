extends Node3D
# One native bundle binding per emitter, shared resource jobs in the world hub.
# Every allocated particle still owns a private model/rig and its own lifetime.
var resource:=""
var origin_resource:=""
var hub
var generation:=-1
var retired:=false
var failure:=""
var bundle: Dictionary={}
var no_model:=false
var models: Array=[]
var stats:={"created":0,"destroyed":0,"impact_requests":0,"detached":0,"missing_clips":0,"instance_ms":0.0,"max_instance_ms":0.0}
func _ready() -> void:
	set_meta("native_nonblocking_effect",true)
	var ancestors: Array=[origin_resource.to_lower()]; var depth:=0; var ancestor:=get_parent()
	while ancestor!=null:
		for field in ["native_chunk_origin","native_reference_origin"]:
			if ancestor.has_meta(field): ancestors.append(str(ancestor.get_meta(field)).to_lower()); depth+=1
		if hub==null and ancestor.has_meta("native_reference_hub"): hub=ancestor.get_meta("native_reference_hub")
		ancestor=ancestor.get_parent()
	resource=resource.to_lower()
	# Original FindModel explicitly returns null for case-insensitive NULL,
	# without resource I/O. The nonempty emitter field still selects chunks.
	if resource=="null": no_model=true; return
	if resource.is_empty() or resource in ancestors or depth>=16: reject("Original chunk model resource cycle/depth: "+resource); return
	set_meta("native_chunk_origin",resource)
	if not is_instance_valid(hub): reject("Native chunk catalog scope is unavailable: "+resource); return
	hub.request_bundle(self,resource)
func install_bundle(value: Dictionary,epoch: int) -> bool:
	if retired or not is_inside_tree() or epoch!=generation or not bundle.is_empty(): return false
	bundle=value; return true
func ready() -> bool:
	return not retired and failure.is_empty() and (no_model or not bundle.is_empty() and is_instance_valid(hub) and not hub.closed and generation==hub.generation)
func reject(reason: String) -> void:
	if retired: return
	failure=reason; push_warning(reason)
func create_model(_name: String):
	if no_model: return null
	if not ready(): return null
	var began:=Time.get_ticks_usec(); var model=hub.create_chunk_model(self,bundle)
	var elapsed:=(Time.get_ticks_usec()-began)/1000.0; stats.instance_ms+=elapsed; stats.max_instance_ms=maxf(float(stats.max_instance_ms),elapsed)
	if model==null: reject("Native chunk model publication failed: "+resource); return null
	models.append(model); stats.created+=1; return model
func scene(model,attached: bool) -> void:
	if not is_instance_valid(model): return
	model.visible=attached; model.process_mode=Node.PROCESS_MODE_INHERIT if attached else Node.PROCESS_MODE_DISABLED
	if not attached: stats.detached+=1
func scale_model(model,factor: float,_kind: int) -> void:
	if is_instance_valid(model): model.scale=Vector3.ONE*factor
func play(model,name: String,speed: float,flags: int,time: float) -> void:
	if not is_instance_valid(model) or not is_instance_valid(model.rigs): return
	stats.impact_requests+=1
	if model.rigs.play_native(0,0,name,speed,flags,time): return
	# ASCII originals retain Godot-native compiled clips. Missing impact is a
	# normal failed animation request; the source model remains the real model.
	var state: Dictionary=model.rigs.entities[0].models[0]
	model.rigs._play(state,name,flags==1,speed,time,true)
	if state.clip!=name: stats.missing_clips+=1
func position_model(model,position: Array) -> void:
	if is_instance_valid(model): model.global_position=Vector3(position[0],position[2],-position[1])
func orientation(model,q: Array) -> void:
	if is_instance_valid(model): model.quaternion=Quaternion(q[1],q[3],-q[2],q[0])
func destroy_model(model,_flag: int) -> void:
	if models.has(model): models.erase(model); stats.destroyed+=1
	if is_instance_valid(model): model.retire()
func services() -> Dictionary:
	return {"createChunkModel":create_model,"chunkScene":scene,"chunkScale":scale_model,"chunkPlay":play,"chunkPosition":position_model,"chunkOrientation":orientation,"destroyChunkModel":destroy_model}
func snapshot() -> Dictionary:
	var value:=stats.duplicate(true); value.merge({"resource":resource,"ready":ready(),"failure":failure,"models":models.size(),"no_model":no_model}); return value
func retire() -> void:
	if retired: return
	retired=true
	if is_instance_valid(hub): hub.cancel_reference(self)
	for model in models.duplicate(): destroy_model(model,1)
	bundle={}; hub=null
func _exit_tree() -> void: retire()
