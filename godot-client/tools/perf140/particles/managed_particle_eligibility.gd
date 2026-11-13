extends RefCounted
# Explicit writer-owned grant, separate from immutable pose ownership.
static var batch_depth:=0
static var pending: Dictionary={}
static func enabled() -> bool:
	return (OS.get_cmdline_user_args().has("--particle-eligibility=managed") or OS.get_environment("NWN_PARTICLE_ELIGIBILITY")=="managed") and ClassDB.class_exists("NwnParticleEligibilityLease")
static func create_scope(owner: Node3D) -> RefCounted:
	if not enabled() or OS.get_thread_caller_id()!=OS.get_main_thread_id():return null
	var token: RefCounted=ClassDB.instantiate("NwnParticlePoseLease")
	return token if bool(ClassDB.class_call_static("NwnParticlePoseLease","bind_scope",token,owner)) else null
static func scope_for(owner: Node) -> RefCounted:
	var current:=owner
	while current!=null:
		if current.has_meta("native_particle_eligibility_scope"):return current.get_meta("native_particle_eligibility_scope")
		current=current.get_parent()
	return null
static func revoke_scope(owner: Node) -> void:
	if owner.has_meta("native_particle_eligibility_scope"):
		var token: RefCounted=owner.get_meta("native_particle_eligibility_scope")
		if token!=null:ClassDB.class_call_static("NwnParticlePoseLease","revoke",token)
static func revoke(token: RefCounted) -> void:
	if token!=null:ClassDB.class_call_static("NwnParticleEligibilityLease","revoke",token)
static func grant(placement,scope: RefCounted) -> RefCounted:
	if not enabled() or scope==null or OS.get_thread_caller_id()!=OS.get_main_thread_id() or placement.retired or placement.reference_graph!=null or placement.parts.is_empty():return null
	var source: Node3D=placement.parts[0]
	while source!=null and source.get_parent()!=placement:source=source.get_parent() as Node3D
	if source==null or source.get_script()!=null:return null
	var token: RefCounted=ClassDB.instantiate("NwnParticleEligibilityLease")
	if not bool(ClassDB.class_call_static("NwnParticleEligibilityLease","bind",token,scope,placement,source)):return null
	var count:=0
	for part in placement.parts:
		var emitter=part.get_node_or_null("native_emitter")
		if emitter!=null and emitter.source==source and emitter.native_owner!=null:
			# Set the explicit writer handle even if currently disabled: enabling
			# later can publish a new checked grant, rather than guessing state.
			emitter.native_eligibility_placement=weakref(placement)
			if bool(ClassDB.class_call_static("NwnParticleEligibilityLease","attach",token,emitter.native_owner,emitter)):
				emitter.native_eligibility_token=token;count+=1
	if count==0:revoke(token);return null
	return token
static func before_emitter_write(emitter) -> void:
	revoke(emitter.native_eligibility_token);emitter.native_eligibility_token=null
static func after_emitter_write(emitter) -> void:
	var placement: Object=emitter.native_eligibility_placement.get_ref() if emitter.native_eligibility_placement!=null else null
	if not is_instance_valid(placement) or placement.retired:return
	if batch_depth>0:pending[placement.get_instance_id()]=weakref(placement)
	else:placement.refresh_particle_eligibility()
static func begin_batch() -> void:batch_depth+=1
static func end_batch() -> void:
	batch_depth=maxi(0,batch_depth-1)
	if batch_depth>0:return
	var values:=pending.values();pending.clear()
	for weak: WeakRef in values:
		var placement: Object=weak.get_ref()
		if is_instance_valid(placement) and not placement.retired:placement.refresh_particle_eligibility()
