extends SceneTree
# Dedicated plain-Node fixture. No native particle class, autoload, server, GPU
# renderer, models or textures are required. Root owns its eventual execution.
const Census=preload("res://tools/perf140/render/particle_ancestor_census.gd")
class SafeEmitter extends Node3D:
	var source: Node3D
class UntrustedEmitter extends Node3D:
	var accesses:=0
	func _get(_property: StringName) -> Variant:
		accesses+=1;return null
var checks:=0
var failures: Array=[]
var members: Dictionary={}
var context: Dictionary={}
var trusted: Script

func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func scalar_tree(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			if not scalar_tree(key) or not scalar_tree(value[key]):return false
		return true
	if value is Array:
		for item in value:
			if not scalar_tree(item):return false
		return true
	return typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING]
func row(result: Dictionary,id: int) -> Dictionary:
	for value in result.nodes:
		if value.id==str(id):return value
	return {}
func capture(limits: Dictionary={}) -> Dictionary:return Census.capture_fixture(members,context,trusted,limits)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var scope:=Node3D.new();root.add_child(scope)
	var shared:=Node3D.new();scope.add_child(shared)
	var pose:=Node3D.new();shared.add_child(pose)
	var first:=SafeEmitter.new();pose.add_child(first);first.source=pose
	var second:=SafeEmitter.new();pose.add_child(second);second.source=pose
	trusted=first.get_script()
	context={"post_window":true,"measurement_active":false,"group_running":false,"group_closed":false,"scope_root_id":scope.get_instance_id()}
	members={first.get_instance_id():{"emitter":weakref(first),"fast":true},second.get_instance_id():{"emitter":weakref(second),"fast":false}}
	var before:=members.duplicate(true);var first_parent:=first.get_parent();var source_before:=first.source;var transform_before:=pose.transform
	var value:=capture()
	check(value.status=="complete" and value.members_available==2,"Both weak canonical fixture members are captured")
	check(value.roles.emitter=={"uses":2,"unique":2},"Emitter identity count remains separate")
	check(value.roles.pose=={"uses":2,"unique":1} and value.roles.source=={"uses":2,"unique":1},"Repeated physical/source IDs are counted by role")
	check(value.same_pose_source_members==2 and value.unique_any_endpoints==3,"Same source=pose is explicit rather than counted as two unique endpoints")
	check(row(value,pose.get_instance_id()).endpoint_roles=={"emitter":0,"pose":2,"source":2},"Pose/source direct multiplicity is separate from ancestry")
	check(row(value,pose.get_instance_id()).ancestor_roles=={"emitter":2,"pose":0,"source":0},"Physical Part is an ancestor of each emitter")
	check(row(value,shared.get_instance_id()).ancestor_roles=={"emitter":2,"pose":2,"source":2},"Shared ancestor multiplicity retains all roles")
	check(row(value,scope.get_instance_id()).ancestor_roles=={"emitter":2,"pose":2,"source":2},"Scope root bounds the structural chain")
	check(value.version==2 and value.visibility_potential.emitter.node_occurrences==8,"V2 separates topological visibility-chain node occurrences")
	check(value.visibility_potential.pose.node_occurrences==6 and value.visibility_potential.source.node_occurrences==6,"Pose/source potential remains separate from actual eligibility work")
	check(value.members[0].paths.emitter.visibility_potential.status=="scope_limited","Unobserved visibility chain beyond explicit scope is not invented")
	var barrier:=Node.new();scope.add_child(barrier)
	var bridged_pose:=Node3D.new();barrier.add_child(bridged_pose)
	var bridged:=SafeEmitter.new();bridged_pose.add_child(bridged);bridged.source=bridged_pose
	members[bridged.get_instance_id()]={"emitter":weakref(bridged),"fast":true}
	var bounded:=capture();var bridge_path: Dictionary=bounded.members[2].paths.emitter
	check(bridge_path.ancestors==[str(bridged_pose.get_instance_id()),str(barrier.get_instance_id()),str(scope.get_instance_id())],"Structural ancestors continue through a plain Node")
	check(bridge_path.visibility_potential.ids==[str(bridged.get_instance_id()),str(bridged_pose.get_instance_id())],"Visibility potential stops at the first non-Node3D parent")
	check(bridge_path.visibility_potential.status=="complete" and bridge_path.visibility_potential.stop=="plain_node_barrier" and bridge_path.visibility_potential.barrier_id==str(barrier.get_instance_id()),"Plain-node barrier is explicit and detached")
	check(row(bounded,scope.get_instance_id()).ancestor_roles=={"emitter":3,"pose":3,"source":3} and row(bounded,scope.get_instance_id()).visibility_potential_roles=={"emitter":2,"pose":2,"source":2},"Above-barrier structural counts cannot masquerade as visibility potential")
	check(row(bounded,barrier.get_instance_id()).visibility_potential_roles=={"emitter":0,"pose":0,"source":0},"Plain Node itself is not a visibility flag read")
	check(bounded.visibility_potential.emitter.node_occurrences==10 and bounded.visibility_potential.pose.node_occurrences==7 and bounded.visibility_potential.source.node_occurrences==7,"Shared roles retain separate barrier-limited counts")
	check(bounded.visibility_potential.emitter.complete_paths==1 and bounded.visibility_potential.emitter.scope_limited_paths==2,"Complete barrier path and scope-limited tails stay distinct")
	check(bridged.get_parent()==bridged_pose and bridged_pose.get_parent()==barrier and barrier.get_parent()==scope and scalar_tree(bounded),"Barrier census does not mutate links or return objects")
	var wrong_context:=context.duplicate();wrong_context.group_running=true
	check(Census.capture_fixture(members,wrong_context,trusted).status=="unavailable","Barrier cohort cannot bypass quiescent context")
	members.erase(bridged.get_instance_id());barrier.free()
	check(value.nodes.size()==5 and scalar_tree(value),"Result is detached scalar data with no live objects/resources")
	check(members==before and first.get_parent()==first_parent and first.source==source_before and pose.transform==transform_before,"Capture does not mutate members/endpoints/transforms")
	value.nodes[0].endpoint_roles.emitter=999
	var isolated:=capture()
	check(isolated.roles.emitter.uses==2 and scalar_tree(isolated),"Mutating one detached result cannot affect another capture")
	var other:=Node3D.new();scope.add_child(other);second.reparent(other)
	value=capture()
	check(value.roles.pose.unique==2 and value.roles.source.unique==1 and value.same_pose_source_members==1,"Reparented physical pose/source distinction is observed live")
	check(value.members[1].pose_id==str(other.get_instance_id()),"Full new parent ID is observed")
	pose.hide();value=capture()
	check(row(value,pose.get_instance_id()).local_visible==false,"Hiding is observed without changing any node visibility")
	check(value.roles.emitter.uses==2 and value.same_pose_source_members==1,"Hidden ancestors do not manufacture a new hide/dedup policy")
	check(row(value,scope.get_instance_id()).visibility_potential_roles.source==2,"Potential deliberately does not claim hidden-node early-exit call frequency")
	var old_second:=second.get_instance_id();second.free();value=capture()
	check(value.members_available==1 and value.members_unavailable==1 and value.members[1].reason=="emitter_retired","Dead WeakRef is explicit")
	var replacement:=SafeEmitter.new();other.add_child(replacement);replacement.source=pose
	members[old_second]={"emitter":weakref(replacement)};value=capture()
	check(value.members[1].reason=="emitter_identity_mismatch","A stale member key cannot resolve to a replacement endpoint")
	members.erase(old_second);members[replacement.get_instance_id()]={"emitter":weakref(replacement)}
	var untrusted:=UntrustedEmitter.new();scope.add_child(untrusted);members[untrusted.get_instance_id()]={"emitter":weakref(untrusted)}
	value=capture();check(value.members_unavailable==1 and untrusted.accesses==0,"Unknown scripts are refused before custom source getters")
	check(Census.capture(members,context).members_available==0,"Production entry cannot use the fixture Script allowlist")
	members.erase(untrusted.get_instance_id());untrusted.free()
	var resource:=RefCounted.new();members[42]={"emitter":weakref(resource)};value=capture()
	check(value.members[2].reason=="emitter_not_node3d","Weak non-Node object is unavailable")
	members[42]={"emitter":first};value=capture();check(value.members[2].reason=="weak_emitter_required","Strong node input is not silently retained/admitted")
	members.erase(42)
	for limit in ["maximum_members","maximum_depth","maximum_visits","maximum_nodes"]:
		value=capture({limit:1});check(value.status=="truncated" and value.reasons.has(limit),"Bound is explicit: "+limit)
	check(capture({"maximum_depth":0}).status=="unavailable","Invalid bound is rejected")
	for field in ["post_window","measurement_active","group_running","group_closed"]:
		var old: bool=context[field];context[field]=not old;check(capture().status=="unavailable","Cold context rejects "+field);context[field]=old
	context.post_window=1;check(capture().status=="unavailable","Integer is not a Boolean context grant");context.post_window=true
	var thread:=Thread.new();check(thread.start(Callable(self,"worker_capture"))==OK,"Worker fixture starts")
	var worker: Dictionary=thread.wait_to_finish();check(worker.status=="unavailable" and worker.reasons==["not_main_thread"],"Worker call exits before touching scene endpoints")
	check(Census.inspect_fixture_path([11,22,11]).status=="cyclic","Detached synthetic cycle exercises the same repeated-ID guard")
	check(Census.inspect_fixture_path([11,22,33],2).status=="truncated","Detached path bound is explicit")
	check(Census.inspect_fixture_path([11,"22"]).status=="unavailable","Fixture path does not coerce full IDs")
	var detached_parent:=Node3D.new();var detached:=SafeEmitter.new();detached_parent.add_child(detached);detached.source=detached_parent
	var detached_context:=context.duplicate();detached_context.scope_root_id=detached_parent.get_instance_id()
	var detached_result:=Census.capture_fixture({detached.get_instance_id():{"emitter":weakref(detached)}},detached_context,trusted)
	check(detached_result.members[0].paths.emitter.ancestors==[str(detached_parent.get_instance_id())],"Detached structural parent is still observable")
	check(detached_result.members[0].paths.emitter.visibility_potential.ids==[str(detached.get_instance_id())] and detached_result.members[0].paths.emitter.visibility_potential.stop=="outside_tree","Detached Node3D has no retained visibility parent")
	detached_parent.free()
	check(scalar_tree(capture()) and first.get_parent()==pose and first.source==pose and not pose.visible,"Final state remains unchanged by diagnostic reads")
	scope.free();members.clear();trusted=null;resource=null
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"V2 cold structural and contiguous Node3D visibility POTENTIAL only; plain-Node barrier/outside-tree cases, synthetic cycle guard, no observed call frequency, native ABI, real cyclic scene, GPU, server or performance acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func worker_capture() -> Dictionary:return capture()
