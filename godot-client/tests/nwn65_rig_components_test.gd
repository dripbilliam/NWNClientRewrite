extends SceneTree
# Native component publication fixture. Timing is opt-in and must be scheduled
# by the coordinator; default execution is correctness only, never FPS.
var options: Dictionary={}
var checks:=0
var failures: Array=[]
var roots: Array=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	call_deferred("run")

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)

func create_case(part_count: int=24) -> Dictionary:
	var host:=Node3D.new();root.add_child(host);roots.append(host)
	var nodes: Array=[];var parents: Array=[]
	for index in part_count:
		var part:=Node3D.new();var parent: int=-1 if index==0 else (index-1)/2
		(host if parent<0 else nodes[parent]).add_child(part)
		part.position=Vector3(index*0.07,index*-0.13,index*0.11)
		part.quaternion=Quaternion.from_euler(Vector3(index*0.017,index*0.023,index*-0.019))
		part.scale=Vector3(1.0+index*0.03,0.7+index*0.01,1.1-index*0.01)
		nodes.append(part);parents.append(parent)
	var skins: Array=[]
	for skin_index in 2:
		var skeleton:=Skeleton3D.new();host.add_child(skeleton)
		var bones: Array=[]
		for slot in 64:
			skeleton.add_bone("slot_"+str(slot));skeleton.set_bone_rest(slot,Transform3D.IDENTITY)
			bones.append(slot%part_count if slot<48 else -1)
		skins.append({"part":skin_index+2,"bones":bones,"skeleton":skeleton})
	var entry:={"nodes":nodes,"parents":parents,"skins":skins}
	var publisher: RefCounted=ClassDB.instantiate("NwnRigSkinPublisher")
	check(bool(publisher.call("configure",entry)),"Native publisher configures exact live components")
	return {"host":host,"nodes":nodes,"parents":parents,"skins":skins,"entry":entry,"publisher":publisher}

func original_publish(row: Dictionary) -> void:
	var rigid: Array=[]
	for index in row.nodes.size():
		var node: Node3D=row.nodes[index];var local:=Transform3D(Basis(node.quaternion),node.position);var parent:=int(row.parents[index])
		rigid.append(local if parent<0 else rigid[parent]*local)
	for skin in row.skins:
		var inverse: Transform3D=rigid[int(skin.part)].affine_inverse();var skeleton: Skeleton3D=skin.skeleton
		for slot in skin.bones.size():
			var part:=int(skin.bones[slot]);var value: Transform3D=Transform3D.IDENTITY if part<0 else inverse*rigid[part]
			skeleton.set_bone_pose_position(slot,value.origin);skeleton.set_bone_pose_rotation(slot,value.basis.get_rotation_quaternion());skeleton.set_bone_pose_scale(slot,Vector3.ONE)
		skeleton.force_update_all_bone_transforms()

func capture(row: Dictionary) -> PackedByteArray:
	var poses: Array=[]
	for skin in row.skins:
		var skeleton: Skeleton3D=skin.skeleton
		for slot in skeleton.get_bone_count():
			poses.append([skeleton.get_bone_pose_position(slot),skeleton.get_bone_pose_rotation(slot),skeleton.get_bone_pose_scale(slot),skeleton.get_bone_global_pose(slot)])
	return var_to_bytes(poses)

func percentile(values: Array,part: float) -> int:
	return int(values[mini(values.size()-1,int(ceil(values.size()*part))-1)])

func benchmark(animated: bool) -> Dictionary:
	var cases: Array=[]
	for index in 48:cases.append(create_case())
	var samples: Array=[]
	for frame in 360:
		if animated:
			for row in cases:row.nodes[4].position.x=float(frame%31)*0.003
		var began:=Time.get_ticks_usec()
		for row in cases:row.publisher.call("publish")
		if frame>=40:samples.append(Time.get_ticks_usec()-began)
	samples.sort()
	var sum:=0
	for value in samples:sum+=int(value)
	var counts:={"bone_writes":0,"bone_setter_calls":0,"force_calls":0,"node_reads":0}
	for row in cases:
		var state: Dictionary=row.publisher.call("inspect")
		for key in counts:counts[key]+=int(state.get(key,int(state.bone_writes)*3 if key=="bone_setter_calls" else 0))
		row.publisher=null;roots.erase(row.host);row.host.free()
	return {"median_us":percentile(samples,0.5),"p95_us":percentile(samples,0.95),"p99_us":percentile(samples,0.99),"mean_us":float(sum)/samples.size(),"samples":samples.size(),"rigs":cases.size(),"skins_per_rig":2,"slots_per_skin":64,"counts":counts}

func run() -> void:
	if not options.has("report") or FileAccess.file_exists(options.report):quit(2);return
	if not ClassDB.class_exists("NwnRigSkinPublisher"):check(false,"Native publisher available");finish({});return
	var original:=create_case();var optimized:=create_case()
	var forces_original: Array=[];var forces_optimized: Array=[]
	for index in 2:
		original.skins[index].skeleton.pose_updated.connect(func():forces_original.append(index))
		optimized.skins[index].skeleton.pose_updated.connect(func():forces_optimized.append(index))
	for frame in 24:
		for row in [original,optimized]:
			row.nodes[3].position.y=frame*0.07;row.nodes[7].quaternion=Quaternion.from_euler(Vector3(frame*0.031,frame*-0.017,frame*0.023))
			if frame==6:row.parents[4]=0
			if frame==10:row.skins[1].bones[4]=7
			if frame==14:row.skins[1].part=5
			if frame==18:row.skins[0].skeleton.set_bone_pose_scale(1,Vector3(2.3,0.8,1.4))
		original_publish(original)
		check(int(optimized.publisher.call("publish"))==0,"Native publication completes frame "+str(frame))
		check(capture(original)==capture(optimized),"Exact local/global bone component bytes frame "+str(frame))
	check(forces_original==forces_optimized and forces_optimized.size()==48,"Force-update order/count retained")
	var inspected: Dictionary=optimized.publisher.call("inspect")
	check(int(inspected.bone_writes)==24*2*64 and int(inspected.force_calls)==48,"All intended bone publications retained")
	if inspected.has("bone_components_batched"):
		check(int(inspected.bone_setter_calls)==int(inspected.bone_writes)*(1 if inspected.bone_components_batched else 3),"Selected component setter count is explicit")
	var timings: Dictionary={}
	if options.get("benchmark","off")=="on":timings={"stationary":benchmark(false),"animated":benchmark(true)}
	original.publisher=null;optimized.publisher=null
	finish({"publication":inspected,"benchmark":timings,"force_order":forces_optimized})

func finish(extra: Dictionary) -> void:
	for host in roots:host.free()
	roots.clear();await process_frame
	var report:={"issue":"NWN-65","success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Exact original scalar setter arithmetic versus native publisher, live local/global bone state, preserved force boundaries; optional isolated normal-engine component timing, no FPS measurement."}
	report.merge(extra)
	var file:=FileAccess.open(options.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("NWN65_RIG_COMPONENTS ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
