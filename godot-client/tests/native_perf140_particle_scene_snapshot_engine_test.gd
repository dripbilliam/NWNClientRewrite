extends SceneTree
# Requires the private builtin module. Source-only until that pinned engine is
# built; this file is not evidence of an executed engine check.
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func snapshot(ids: PackedInt64Array,roles: PackedByteArray) -> PackedByteArray:
	return ClassDB.class_call_static("NwnParticleSceneSnapshot","snapshot_nodes",ids,roles)
func flags(packet: PackedByteArray,index: int) -> int:return packet.decode_u32(32+index*64+8)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	if not ClassDB.class_exists("NwnParticleSceneSnapshot"):
		var absent:=FileAccess.open(args.report,FileAccess.WRITE);absent.store_string(JSON.stringify({"success":false,"checks":0,"failures":["Private builtin engine module is absent"],"engine_module_available":false}));absent.close();quit(2);return
	check(int(ClassDB.class_call_static("NwnParticleSceneSnapshot","abi_version"))==1,"Builtin version is explicit")
	var host:=Node3D.new();root.add_child(host)
	var part:=Node3D.new();host.add_child(part);part.position=Vector3(0.125,0.25,-0.5);part.rotation=Vector3(0.1,0.25,-0.125);part.scale=Vector3(-1,0.75,1.25)
	var detached:=Node3D.new();var other:=RefCounted.new();var freed:=Node3D.new();var stale:=freed.get_instance_id();freed.free()
	var ids:=PackedInt64Array([part.get_instance_id(),host.get_instance_id(),detached.get_instance_id(),other.get_instance_id(),stale,0])
	var roles:=PackedByteArray([7,1,6,2,2,0]);var packet:=snapshot(ids,roles)
	check(packet.size()==32+ids.size()*64 and packet.decode_u32(0)==0x3153574e and packet.decode_u16(4)==1 and packet[11]==0,"Builtin packet layout is exact")
	for index in ids.size():check(packet.decode_s64(32+index*64)==ids[index] and packet.decode_u32(32+index*64+12)==roles[index],"Every full ID and role echoes exactly")
	check(flags(packet,0)==63,"Live visible processable transform endpoint has all explicit bits")
	check(flags(packet,1)==31,"Eligibility-only endpoint has no transform bit")
	check(flags(packet,2)==3 and detached.is_visible_in_tree() and not detached.is_inside_tree(),"Detached but locally visible endpoint has no fabricated global transform or eligibility")
	check(flags(packet,3)==1,"Existing wrong native type differs from an absent object")
	check(flags(packet,4)==0 and flags(packet,5)==0,"Freed/tombstoned identities remain explicitly absent")
	var expected:=PackedByteArray();expected.resize(48);var pose:=part.global_transform
	# C++ Basis stores rows; GDScript Basis indexing exposes columns.
	for matrix_row in 3:
		for column in 3:expected.encode_float((matrix_row*3+column)*4,pose.basis[column][matrix_row])
	for axis in 3:expected.encode_float((9+axis)*4,pose.origin[axis])
	check(packet.slice(48,96)==expected,"Builtin copies exact original setter-derived Transform3D words")
	host.hide();packet=snapshot(ids,roles);check((flags(packet,0)&(8|16))==0,"Ancestor hide is visible in the same call")
	host.show();part.process_mode=Node.PROCESS_MODE_DISABLED;packet=snapshot(ids,roles);check((flags(packet,0)&8)!=0 and (flags(packet,0)&16)==0,"Process-disabled endpoint stays visible but cannot process")
	part.process_mode=Node.PROCESS_MODE_INHERIT;paused=true;packet=snapshot(ids,roles);check((flags(packet,0)&16)==0,"Inherited scene pause uses the actual process owner")
	part.process_mode=Node.PROCESS_MODE_ALWAYS;packet=snapshot(ids,roles);check((flags(packet,0)&16)!=0,"Always-processing endpoint keeps actual paused semantics");paused=false
	check(snapshot(ids,PackedByteArray([1]))[11]==2,"Mismatched roles return explicit unsupported request")
	var invalid:=roles.duplicate();invalid[0]=8;check(snapshot(ids,invalid)[11]==2,"Unknown roles never select guessed behavior")
	var subthread:=Node3D.new();subthread.process_thread_group=Node.PROCESS_THREAD_GROUP_SUB_THREAD;root.add_child(subthread)
	var threaded_child:=Node3D.new();subthread.add_child(threaded_child)
	check(snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))[11]==4,"Sub-thread-owned ancestry rejects the batch explicitly")
	var validation_only:=snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([2]))
	check(validation_only[11]==0 and flags(validation_only,0)==3,"Validate-only roles read identity/type without process ownership or eligibility getters")
	var notification_status: Array=[]
	var inspect_group:=func():notification_status.append(int(snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))[11]))
	subthread.property_list_changed.connect(inspect_group)
	# Ownership changes are synchronous at setter/reparent boundaries. The new
	# O(1) engine preflight must match the old ancestry walk immediately.
	subthread.process_thread_group=Node.PROCESS_THREAD_GROUP_MAIN_THREAD
	check(snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))[11]==0,"Changing the ancestor to main updates its descendant owner before the next snapshot")
	check(not notification_status.is_empty() and notification_status.back()==0,"Property-list callback sees complete descendant main-owner cache")
	subthread.process_thread_group=Node.PROCESS_THREAD_GROUP_SUB_THREAD
	check(snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))[11]==4,"Changing back to sub-thread rejects immediately")
	check(not notification_status.is_empty() and notification_status.back()==4,"Property-list callback sees complete descendant sub-owner cache")
	subthread.property_list_changed.disconnect(inspect_group)
	threaded_child.reparent(host,false)
	check(snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))[11]==0,"Reparenting into an implicit main group refreshes ownership immediately")
	threaded_child.process_thread_group=Node.PROCESS_THREAD_GROUP_SUB_THREAD
	check(snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))[11]==4,"Explicit child sub-thread mode is not replaced by parent state")
	threaded_child.process_thread_group=Node.PROCESS_THREAD_GROUP_INHERIT
	check(snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))[11]==0,"Restoring inheritance adopts current parent ownership immediately")
	host.remove_child(threaded_child)
	var exited:=snapshot(PackedInt64Array([threaded_child.get_instance_id()]),PackedByteArray([7]))
	check(exited[11]==0 and flags(exited,0)==3,"Exiting the tree drops process owner and leaves global TRS explicitly absent")
	threaded_child.free()
	var thread:=Thread.new();check(thread.start(func():return snapshot(ids,roles))==OK,"Worker-only unsupported probe starts")
	var worker_packet: PackedByteArray=thread.wait_to_finish();check(worker_packet[11]==1,"Worker call rejects before touching live Node data")
	var replacement:=Node3D.new();host.add_child(replacement);check(replacement.get_instance_id()!=stale and flags(snapshot(ids,roles),4)==0,"ID slot reuse cannot resolve an old full lifetime")
	detached.free();other=null;subthread.free();host.free();await process_frame;await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"engine_module_available":true,"gpu":false,"server_connections":0,"scope":"Private builtin packet vs live public Godot getters; exact transforms, explicit detached/missing/wrong-type data, inherited visibility/process/pause and unsupported thread gates. No FPS claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
