extends RefCounted
# Private opt-in canonical publisher. No polling or per-frame scene traversal.
static func enabled() -> bool:
	return (OS.get_cmdline_user_args().has("--particle-pose-leases=managed") or OS.get_environment("NWN_PARTICLE_POSE_LEASES")=="managed") and ClassDB.class_exists("NwnParticlePoseLease")
static func create_scope(owner: Node3D) -> RefCounted:
	if not enabled() or OS.get_thread_caller_id()!=OS.get_main_thread_id():return null
	var token: RefCounted=ClassDB.instantiate("NwnParticlePoseLease")
	return token if bool(ClassDB.class_call_static("NwnParticlePoseLease","bind_scope",token,owner)) else null
static func scope_for(owner: Node) -> RefCounted:
	if not enabled():return null
	var current:=owner
	while current!=null:
		if current.has_meta("native_particle_pose_lease_scope"):return current.get_meta("native_particle_pose_lease_scope")
		current=current.get_parent()
	return null
static func revoke(token: RefCounted) -> void:
	if token!=null:ClassDB.class_call_static("NwnParticlePoseLease","revoke",token)
static func revoke_scope(owner: Node) -> void:
	if owner.has_meta("native_particle_pose_lease_scope"):revoke(owner.get_meta("native_particle_pose_lease_scope"))
static func grant(placement,scope: RefCounted) -> RefCounted:
	if scope==null or not enabled() or OS.get_thread_caller_id()!=OS.get_main_thread_id() or placement.retired or placement.reference_graph!=null or placement.parts.is_empty():return null
	var source: Node3D=placement.parts[0]
	while source!=null and source.get_parent()!=placement:source=source.get_parent() as Node3D
	if source==null or source.get_script()!=null:return null
	var token: RefCounted=ClassDB.instantiate("NwnParticlePoseLease")
	if not bool(ClassDB.class_call_static("NwnParticlePoseLease","bind_placement",token,scope,placement,source)):return null
	var attached:=0
	for part in placement.parts:
		var emitter=part.get_node_or_null("native_emitter")
		if emitter!=null and emitter.source==source and emitter.native_owner!=null:
			if bool(ClassDB.class_call_static("NwnParticlePoseLease","attach",token,emitter.native_owner)):attached+=1
	if attached==0:revoke(token);return null
	return token
