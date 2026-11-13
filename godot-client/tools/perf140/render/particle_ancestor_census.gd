extends RefCounted
# Explicit cold diagnostic only. This is not a frame callback or a visibility
# cache. All returned IDs are full decimal strings, never truncated/float IDs.
const CANONICAL_EMITTER="res://systems/native_render/particle_emitter.gd"
const ROLES=["emitter","pose","source"]
const DEFAULTS={"maximum_members":8192,"maximum_depth":128,"maximum_visits":131072,"maximum_nodes":32768}
const HARD={"maximum_members":32768,"maximum_depth":256,"maximum_visits":262144,"maximum_nodes":65536}

static func capture(members: Dictionary,context: Dictionary,limits: Dictionary={}) -> Dictionary:
	return _capture(members,context,limits,null,false)

# A separate fixture entry: exact trusted Script identity, transient only.
# It must never be used by the production caller to admit arbitrary getters.
static func capture_fixture(members: Dictionary,context: Dictionary,trusted_script: Script,limits: Dictionary={}) -> Dictionary:
	return _capture(members,context,limits,trusted_script,true)

static func _result() -> Dictionary:
	return {"version":2,"read_only":true,"status":"complete","reasons":[],"id_domain":"godot-object-instance-id","id_encoding":"full-decimal-string","members_total":0,"members_examined":0,"members_available":0,"members_unavailable":0,"same_pose_source_members":0,"node_visits":0,"unique_any_endpoints":0,"roles":{"emitter":{"uses":0,"unique":0},"pose":{"uses":0,"unique":0},"source":{"uses":0,"unique":0}},"visibility_potential":{"emitter":{"paths":0,"node_occurrences":0,"unique_nodes":0,"complete_paths":0,"scope_limited_paths":0,"truncated_paths":0,"cyclic_paths":0},"pose":{"paths":0,"node_occurrences":0,"unique_nodes":0,"complete_paths":0,"scope_limited_paths":0,"truncated_paths":0,"cyclic_paths":0},"source":{"paths":0,"node_occurrences":0,"unique_nodes":0,"complete_paths":0,"scope_limited_paths":0,"truncated_paths":0,"cyclic_paths":0}},"members":[],"nodes":[],"limits":{},"scope_root_id":null,"fixture_only":false,"semantics":"Structural parents and contiguous Node3D visibility-chain POTENTIAL only, NOT observed per-frame getter frequency. Potential ignores hidden-node early exits and stops at plain Node/outside tree; scope-limited tails stay unknown. Pose/source are not guaranteed visibility queries. No hiding, deduplication, vi_visible cache or runtime policy."}

static func _reason(result: Dictionary,reason: String,status: String="truncated") -> void:
	if not result.reasons.has(reason):result.reasons.append(reason)
	if result.status!="unavailable":
		if status=="truncated" or result.status=="complete":result.status=status

static func _capture(members: Dictionary,context: Dictionary,limits: Dictionary,trusted: Script,fixture: bool) -> Dictionary:
	var result:=_result()
	# Refuse before touching WeakRefs, scene nodes, source properties or scripts.
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():result.status="unavailable";result.reasons=["not_main_thread"];return result
	for field in ["post_window","measurement_active","group_running","group_closed"]:
		var flag: Variant=context.get(field)
		if not flag is bool or flag!=(field=="post_window"):
			result.status="unavailable";result.reasons=["explicit_quiescent_post_window_context_required"];return result
	var scope: Variant=context.get("scope_root_id")
	if not scope is int or scope<=0:result.status="unavailable";result.reasons=["full_scope_root_id_required"];return result
	if fixture and trusted==null:result.status="unavailable";result.reasons=["trusted_fixture_script_required"];return result
	for key in DEFAULTS:
		var value: Variant=limits.get(key,DEFAULTS[key])
		if not value is int or value<1 or value>HARD[key]:result.status="unavailable";result.reasons=["invalid_limit_"+key];return result
		result.limits[key]=value
	result.fixture_only=fixture;result.scope_root_id=str(scope);result.members_total=members.size()
	var nodes: Dictionary={};var endpoint_ids: Dictionary={};var role_ids:={"emitter":{},"pose":{},"source":{}}
	for key in members:
		if result.members_examined>=result.limits.maximum_members:_reason(result,"maximum_members");break
		result.members_examined+=1
		var row:={"member_id":str(key) if key is int else null,"status":"unavailable","reason":null,"emitter_id":null,"pose_id":null,"source_id":null,"pose_source_same":null,"fast":null,"paths":{}}
		var record: Variant=members[key]
		if not key is int or key<=0:row.reason="invalid_full_member_id"
		elif not record is Dictionary or not record.get("emitter") is WeakRef:row.reason="weak_emitter_required"
		else:
			var emitter: Object=record.emitter.get_ref()
			if not is_instance_valid(emitter):row.reason="emitter_retired"
			elif not emitter is Node3D:row.reason="emitter_not_node3d"
			elif emitter.get_instance_id()!=key:row.reason="emitter_identity_mismatch"
			else:
				var script: Script=emitter.get_script()
				var allowed: bool=is_same(script,trusted) if fixture else script!=null and script.resource_path==CANONICAL_EMITTER
				if not allowed:row.reason="noncanonical_emitter_script"
				else:
					# Canonical source declares this as a plain var, with no getter.
					var source: Variant=emitter.get("source")
					var pose: Node=emitter.get_parent()
					row.status="available";row.fast=record.get("fast") if record.get("fast") is bool else null
					for role in ROLES:
						var endpoint: Variant=emitter if role=="emitter" else pose if role=="pose" else source
						if result.status=="truncated":row.paths[role]=_unavailable_path("earlier_bound");continue
						if not is_instance_valid(endpoint) or not endpoint is Node3D:
							row.paths[role]=_unavailable_path("endpoint_absent_or_not_node3d");continue
						var id: int=endpoint.get_instance_id();row[role+"_id"]=str(id)
						result.roles[role].uses+=1;role_ids[role][id]=true;endpoint_ids[id]=true
						row.paths[role]=_walk(endpoint,role,int(scope),nodes,result)
					if row.pose_id!=null and row.source_id!=null:
						row.pose_source_same=row.pose_id==row.source_id
						if row.pose_source_same:result.same_pose_source_members+=1
		if row.status=="available":result.members_available+=1
		else:result.members_unavailable+=1
		result.members.append(row)
		if result.status=="truncated":break
	for role in ROLES:result.roles[role].unique=role_ids[role].size()
	result.unique_any_endpoints=endpoint_ids.size()
	for id in nodes:
		for role in ROLES:
			if nodes[id].visibility_potential_roles[role]>0:result.visibility_potential[role].unique_nodes+=1
		result.nodes.append(nodes[id])
	# Every retained value above is newly created scalar/array/dictionary data.
	return result

static func _walk(endpoint: Node3D,role: String,scope: int,nodes: Dictionary,result: Dictionary) -> Dictionary:
	var path:={"status":"complete","reason":null,"ancestors":[],"scope_found":false,"visibility_potential":{"status":"pending","stop":null,"ids":[],"barrier_id":null}}
	var potential: Dictionary=path.visibility_potential
	var current: Node=endpoint;var seen: Dictionary={};var depth:=0;var visibility_open:=true
	while is_instance_valid(current):
		if result.node_visits>=result.limits.maximum_visits:path.status="truncated";path.reason="maximum_visits";_reason(result,path.reason);break
		if depth>=result.limits.maximum_depth:path.status="truncated";path.reason="maximum_depth";_reason(result,path.reason);break
		result.node_visits+=1
		var id: int=current.get_instance_id()
		if _repeated(seen,id):path.status="cyclic";path.reason="repeated_parent_id";_reason(result,path.reason,"cyclic");break
		seen[id]=true
		if not nodes.has(id):
			if nodes.size()>=result.limits.maximum_nodes:path.status="truncated";path.reason="maximum_nodes";_reason(result,path.reason);break
			var spatial: Node3D=current as Node3D
			nodes[id]={"id":str(id),"node3d":spatial!=null,"inside_tree":current.is_inside_tree(),"local_visible":spatial.is_visible() if spatial!=null else null,"endpoint_roles":{"emitter":0,"pose":0,"source":0},"ancestor_roles":{"emitter":0,"pose":0,"source":0},"visibility_potential_roles":{"emitter":0,"pose":0,"source":0}}
		if depth==0:nodes[id].endpoint_roles[role]+=1
		else:nodes[id].ancestor_roles[role]+=1;path.ancestors.append(str(id))
		if visibility_open:
			if not nodes[id].node3d:
				potential.status="complete";potential.stop="plain_node_barrier";potential.barrier_id=str(id);visibility_open=false
			else:
				potential.ids.append(str(id));nodes[id].visibility_potential_roles[role]+=1
				# Node3D data.parent is assigned on enter-tree and cleared on exit.
				# The public walking getter has no parent chain outside the tree.
				if not nodes[id].inside_tree:potential.status="complete";potential.stop="outside_tree";visibility_open=false
		if id==scope:
			path.scope_found=true
			if visibility_open:potential.status="scope_limited";potential.stop="scope_boundary";visibility_open=false
			break
		current=current.get_parent();depth+=1
	if visibility_open:
		if path.status in ["truncated","cyclic"]:potential.status=path.status;potential.stop=path.reason
		else:potential.status="complete";potential.stop="tree_root"
	if path.status=="complete" and not path.scope_found:path.status="unavailable";path.reason="scope_not_in_parent_chain"
	var summary: Dictionary=result.visibility_potential[role]
	summary.paths+=1;summary.node_occurrences+=potential.ids.size()
	if potential.status=="complete":summary.complete_paths+=1
	elif potential.status=="scope_limited":summary.scope_limited_paths+=1
	elif potential.status=="truncated":summary.truncated_paths+=1
	elif potential.status=="cyclic":summary.cyclic_paths+=1
	return path

static func _unavailable_path(reason: String) -> Dictionary:
	return {"status":"unavailable","reason":reason,"ancestors":[],"scope_found":false,"visibility_potential":{"status":"unavailable","stop":reason,"ids":[],"barrier_id":null}}

static func _repeated(seen: Dictionary,id: int) -> bool:return seen.has(id)

# Public Node APIs cannot construct an actual cyclic parent tree. This fixture
# entry exercises the SAME repeated-ID guard using detached integer paths only.
static func inspect_fixture_path(ids: Array,maximum_depth: int=128) -> Dictionary:
	var result:={"status":"complete","ids":[]};var seen: Dictionary={}
	if maximum_depth<1 or maximum_depth>256:result.status="unavailable";return result
	for id in ids:
		if not id is int or id<=0:result.status="unavailable";break
		if _repeated(seen,id):result.status="cyclic";break
		if result.ids.size()>=maximum_depth:result.status="truncated";break
		seen[id]=true;result.ids.append(str(id))
	return result
