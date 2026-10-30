extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func hits(node: Node3D) -> Dictionary:
	return node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,-2,0),7))
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var results: Array=[]
	for scan in [true,false]:
		var area:=World.new(); root.add_child(area); area.set_process(false); area.retirement_physics_scan=scan
		var holders: Array=[]
		for index in 1000:
			var holder:=Node3D.new(); area.add_child(holder); holders.append(holder)
			for part in 24: holder.add_child(Node3D.new())
		var body:=StaticBody3D.new(); body.collision_layer=7; body.collision_mask=5; holders[0].add_child(body)
		var shape:=CollisionShape3D.new(); shape.shape=BoxShape3D.new(); body.add_child(shape)
		await physics_frame; await physics_frame; await process_frame
		check(hits(area).get("collider")==body,"Actual inherited body participates before area retirement: "+str(scan))
		check(body.disable_mode==CollisionObject3D.DISABLE_MODE_REMOVE and body.process_mode==Node.PROCESS_MODE_INHERIT,"Native default body policy is remove-on-disable with inherited processing")
		var began:=Time.get_ticks_usec(); area.begin_retirement(); var retire_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(hits(area).is_empty(),"Old area stops intercepting rays immediately, before a frame boundary: "+str(scan))
		await physics_frame; await process_frame
		check(hits(area).is_empty(),"Old area stays absent from physics while still retained in SceneTree: "+str(scan))
		area.process_mode=Node.PROCESS_MODE_INHERIT
		if scan: body.collision_layer=7; body.collision_mask=5
		await physics_frame; await process_frame
		check(hits(area).get("collider")==body,"Body was disabled rather than destroyed or stripped of its original shape: "+str(scan))
		results.append({"scan":scan,"authored_descendants":25002,"retire_ms":retire_ms})
		area.close(); area.queue_free(); await process_frame; await process_frame
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"results":results,"publicConnections":0,"scope":"Actual engine physics ray queries before/after immediate inherited area disable, retained hierarchy and re-enable on two authored 25k-node scenes; comparison of redundant collision scan, not complete transition/FPS acceptance"},"\t")); output.close(); quit(0 if failures.is_empty() else 1)
