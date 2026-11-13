extends "res://systems/native_render/placeable_lights.gd"
# Independent opt-in source experiment. Does NOT extend the pure-plan cache.
# Original plans/dirty/readiness/apply attachments and palette are retained.
const CanonicalEffectModel=preload("res://systems/native_render/effect_model.gd")
var static_pose_stats: Dictionary={"original_publications":0,"skipped_publications":0,"dynamic_original":0,"ineligible_original":0,"revocations":0,"reentrant_boundaries":0}
var _static_records: Dictionary={}
var _dynamic_instances: Dictionary={}
var _publication_epoch:=0

func _revoke_static(id: int) -> void:
	# Epoch also fences an in-flight FIRST publication that has no record yet.
	_publication_epoch+=1
	if _static_records.erase(id):static_pose_stats.revocations+=1

func _revoke_all_static() -> void:
	_publication_epoch+=1
	static_pose_stats.revocations+=_static_records.size()
	_static_records.clear()

func configure(owner,source,shared_pool,cache_path: String,area_lights: Array) -> void:
	_revoke_all_static();_dynamic_instances.clear()
	super.configure(owner,source,shared_pool,cache_path,area_lights)

func prepared(id: int,result: Dictionary) -> void:
	if not closed and requests.has(id):_revoke_all_static()
	super.prepared(id,result)

func instance_ready(id: int,source: Dictionary,instance) -> void:
	_revoke_static(id)
	super.instance_ready(id,source,instance)

func instance_removed(id: int) -> void:
	_revoke_static(id)
	super.instance_removed(id)

func erase(id: int) -> void:
	_revoke_static(id);_dynamic_instances.erase(id)
	super.erase(id)

func _static_key(id: int,model: Node3D,plan: Dictionary) -> Array:
	if closed or not is_instance_valid(world) or world.closed or world.retiring:return []
	if not is_instance_valid(model) or instances.get(id)!=model or not model.is_inside_tree():return []
	# Unknown subclass/notification behavior is outside this narrow ownership.
	if model.get_script()!=CanonicalEffectModel or not model.installed or model.retired:return []
	if model.get_parent()!=self or model.top_level or model.anchor_node!=null or model.has_meta("native_light_anchor"):return []
	if _dynamic_instances.get(id,-1)==model.get_instance_id():return []
	if not plan.get("dynamic") is bool or plan.dynamic:return []
	var raw: Variant=plan.get("position")
	if not raw is Array or raw.size()!=3:return []
	for value in raw:
		if not (value is int or value is float) or not is_finite(float(value)):return []
	var local: Transform3D=model.transform
	var local_scale: Vector3=model.scale
	# General nonuniform/Euler/negative-scale stability is NOT inferred. Zero
	# signs in an identity basis may differ, so exact byte readback below is the
	# retention witness after two completed original publications.
	if local.basis!=Basis.IDENTITY or local_scale!=Vector3.ONE:return []
	return [world.get_instance_id(),world.generation,world.area_id,model.get_instance_id(),get_instance_id(),var_to_bytes(plan),var_to_bytes(local),var_to_bytes(local_scale),model.rotation_order,model.visible,model.is_visible_in_tree(),model.process_mode]

func _ordinary_static_pose(id: int,model: Node3D,point: Vector3) -> void:
	# Single original execution body; a dedicated test subclass can trigger a
	# canonical removal wake after it to exercise the epoch fence.
	static_pose_stats.original_publications+=1
	model.rotation=Vector3.ZERO
	model.position=point

func _publish_static_pose(id: int,model: Node3D,plan: Dictionary,point: Vector3) -> void:
	var before:=_static_key(id,model,plan)
	var previous: Dictionary=_static_records.get(id,{})
	if not before.is_empty() and not previous.is_empty() and int(previous.stable)>=2 and before==previous.key:
		static_pose_stats.skipped_publications+=1
		return
	if not previous.is_empty() and (before.is_empty() or before!=previous.key):
		_revoke_static(id);previous={}
	var boundary:=_publication_epoch
	_ordinary_static_pose(id,model,point)
	# No record can be granted across callback/reentrant scope/identity changes.
	if boundary!=_publication_epoch:
		static_pose_stats.reentrant_boundaries+=1
		_revoke_static(id)
		return
	var after:=_static_key(id,model,plan)
	if after.is_empty():
		static_pose_stats.ineligible_original+=1
		_revoke_static(id)
		return
	var stable:=1
	if not previous.is_empty() and before==previous.key and after==previous.key:stable=int(previous.stable)+1
	_static_records[id]={"key":after,"stable":mini(stable,2)}

func apply(id: int,plan: Dictionary) -> bool:
	var model: Node3D=instances[id]
	# Revoke before real configuration/manual-Part writes or dynamic attachment.
	# Plan bytes preserve numeric types/signed-zero, unlike Variant equality.
	var record: Dictionary=_static_records.get(id,{})
	if not record.is_empty() and record.key[5]!=var_to_bytes(plan):_revoke_static(id)
	if plan.dynamic:
		_revoke_static(id);_dynamic_instances[id]=model.get_instance_id()
	# The following configuration and anchor branches are the original apply
	# body. Palette/Part configuration/attach_to/detach calls are not suppressed.
	if configurations.get(id,{})!=plan:
		var part: Node3D=model.node_for(0,"auroralight01")
		for light in part.get_children():
			if not light is OmniLight3D:continue
			var properties: Dictionary=light.get_meta("native_model_light_properties",{}).duplicate(true)
			properties.color=plan.color;light.configure(properties)
		var root_part: Node3D=model.node_for(0,"root")
		var initial: Array=bundle.value.nodes[0].position;var offset: Array=plan.offset
		var p: Array=[initial[0]+offset[0],initial[1]+offset[1],initial[2]+offset[2]]
		var q:=root_part.quaternion
		model.set_part_local_pose("root",p,[q.w,q.x,-q.z,q.y])
		configurations[id]=plan.duplicate(true)
	var target:=anchor(id) if plan.dynamic else null
	if is_instance_valid(target):
		static_pose_stats.dynamic_original+=1
		model.attach_to(target)
	else:
		# A real/unknown prior anchor revokes before detach; dynamic lifetimes
		# never enroll again even after they temporarily lose their body anchor.
		if model.anchor_node!=null or model.has_meta("native_light_anchor"):_revoke_static(id)
		model.detach()
		_publish_static_pose(id,model,plan,Vector3(plan.position[0],plan.position[2],-plan.position[1]))
	return true

func snapshot() -> Dictionary:
	var result:=super.snapshot()
	result.static_outer_pose={"mode":"generated-static-outer-pose-v1","enabled":true,"retained":_static_records.size(),"dynamic_lifetimes":_dynamic_instances.size(),"stats":static_pose_stats.duplicate(true)}
	return result

func close() -> void:
	_revoke_all_static();_dynamic_instances.clear()
	super.close()
