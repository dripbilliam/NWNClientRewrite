extends "res://tests/native_static_pose_test.gd"
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var world:=World.new(); root.add_child(world); world.set_process(false); world.area_id=42
	var rows: Array=[row(1,5,1.0)]
	for id in range(2,602): rows.append(row(id,9,float(id)))
	world.receive(rows,1)
	for object in rows:
		var body:=Body.new(); world.add_child(body); world.instances[int(object.id)]=body; world.installed[int(object.id)]=world.signature(object)
	world.apply_poses(true); world.motion.objects[1].render=Vector3(40,2,3); world.apply_poses()
	var evaluations:=int(world.stats.static_pose_evaluations); var update:=row(2,9,123.0)
	world.receive_delta([update],[],1)
	check(int(world.stats.static_pose_evaluations)-evaluations==1,"One changed static updates one pose among 600")
	check(world.instances[2].position==Vector3(123,3,-2) and world.instances[3].position==Vector3(3,3,-2),"Changed pose applies; unchanged objects remain")
	world.receive_delta([row(1,5,1.0)],[],1)
	check(world.instances[1].position.x==40,"Repeated creature metadata does not restart native path/motion")
	world.receive_delta([], [2],1)
	check(not world.instances.has(2) and not world.desired.has(2) and world.instances.has(3),"Explicit removal retires only the selected object")
	world.failed_objects[3]={"key":"old-appearance"}; world.receive_delta([row(3,9,99)],[],1)
	check(not world.failed_objects.has(3),"Changed appearance clears its previous admission failure")
	var removed:=row(3,9,0); removed.replicationRemoved=true; world.receive_delta([removed],[],1)
	check(not world.instances.has(3) and not world.desired.has(3),"Authoritative removed flag retires the object")
	world.receive_delta([row(3,9,7)],[],1)
	check(world.desired.has(3) and not world.installed.has(3),"Reused server ID requires fresh visual admission")
	var outside:=row(4,9,0); outside.areaId=999; world.receive_delta([outside],[],1)
	check(not world.desired.has(4) and not world.instances.has(4),"Changed area membership removes old appearance")
	var count:=world.desired.size(); world.receive_delta([],[],1)
	check(world.desired.size()==count,"Metadata-only delta preserves all desired objects")
	world.close(); world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native delta application with 600 static objects, motion preservation, deletion, lifetime reuse, membership and failure recovery; no public network."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
