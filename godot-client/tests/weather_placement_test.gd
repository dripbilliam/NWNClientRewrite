extends SceneTree
const Placement = preload("res://systems/weather_placement.gd")
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2);return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-weather-placement-v1.json"))
	if source.target != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a": quit(2);return
	var comparisons := 0
	for row in source.rows:
		var poses := Placement.layout(row.position,row.quaternion)
		for i in 6:
			for name in ["position","quaternion"]:
				var bytes: PackedByteArray = str(row.poses[i][name+"Bits"]).hex_decode()
				for j in poses[i][name].size():
					comparisons += 1
					var actual := PackedByteArray();actual.resize(4);actual.encode_float(0,poses[i][name][j])
					# Position arithmetic is exact. Independent engine/libm trig
					# output may differ at the last float bit from the CRT stub.
					if (actual != bytes.slice(j*4,j*4+4) if name == "position" else absf(poses[i][name][j]-bytes.decode_float(j*4)) > .00000012): failures.append({"row":source.rows.find(row),"model":i,"field":name,"component":j,"actual":poses[i][name][j],"expected":bytes.decode_float(j*4)})
	var host := Node3D.new();root.add_child(host)
	var camera := Camera3D.new();host.add_child(camera)
	var actor := Vector3(15.22,.31,-49.38)
	var adapter_checks := 0
	for yaw in [0.0,.7,1.5,3.2]:
		for height in [4.0,10.0,30.0]:
			camera.position = actor+Vector3(sin(yaw)*20,height,cos(yaw)*20);camera.look_at(actor)
			var poses := Placement.from_camera(actor,camera)
			var center: Array = poses[1].position;var forward: Array = poses[4].position
			var global_center := Vector3(center[0],center[2],-center[1])
			var step := Vector3(forward[0]-center[0],0,-forward[1]+center[1]).normalized()
			var expected := Vector3(camera.global_position.x-actor.x,0,camera.global_position.z-actor.z).normalized()
			adapter_checks += 2
			if global_center.distance_to(actor+Vector3.UP*15) > .00002 or step.distance_to(expected) > .000002: failures.append({"adapterYaw":yaw,"height":height,"center":[global_center.x,global_center.y,global_center.z],"directionError":step.distance_to(expected)})
	host.free()
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"rows":source.rows.size(),"comparisons":comparisons,"adapterChecks":adapter_checks,"failures":failures,"scope":"Original weather-grid position arithmetic plus independent camera/world-frame invariants; native camera getters and CRT trig/pixels are separate boundaries"},"\t"));file.close()
	print("WEATHER_PLACEMENT_TEST ",comparisons," comparisons, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
