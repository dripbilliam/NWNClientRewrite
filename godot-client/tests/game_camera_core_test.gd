extends SceneTree
const CameraState = preload("res://systems/game_camera_state.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,text: String) -> void:
	checks += 1
	if not value and failures.size() < 30: failures.append(text)
func close_value(actual: Variant,expected: Variant,label: String) -> void:
	check(actual != null and absf(float(actual)-float(expected)) <= 0.0001,label+": "+str(actual)+" vs "+str(expected))
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/camera-core-original-v1.json"))
	check(oracle.target == "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original camera oracle target is pinned")
	check(oracle.frames.size() == 432 and oracle.modes.size() == 720 and oracle.pointers.size() == 100 and oracle.rates.size() == 403,"Original observation groups are complete")
	for row in oracle.frames:
		var c: Dictionary = row.case
		var s: Dictionary = {"height":1.7,"distance":20.0,"minDist":1.0,"maxDist":25.0,"clampDist":1,"minPitch":1.0,"maxPitch":89.0,"clampPitch":1,"focus":[1.0,1.0,1.0]}
		s.merge(c,true); s.quaternion = CameraState.quaternion(c.oldYaw,c.oldPitch)
		CameraState.follow(s,c.dt,[2,3,0.5])
		for key in ["distance","yaw","pitch","turn","tilt","speed"]: close_value(s[key],row[key],"Follow "+key+" "+JSON.stringify(c))
		for key in ["focus","position","quaternion"]:
			for i in row[key].size(): close_value(s[key][i],row[key][i],"Follow "+key+" "+JSON.stringify(c))
	for row in oracle.modes:
		var c: Dictionary = row.case
		var s: Dictionary = {"turn":0.0,"manualLatch":0,"wasIdle":0}; s.merge(c,true); s.quaternion = CameraState.quaternion(c.yaw,50)
		CameraState.steering(s,c,c.dt)
		for key in ["turn","manual","turning","manualLatch","wasIdle"]: close_value(s.get(key),row[key],"Steering "+key+" "+JSON.stringify(c))
	for row in oracle.pointers:
		var c: Dictionary = row.case; var actual: Dictionary = CameraState.pointer(c.dx,c.dy,c.width)
		for event in row.events: close_value(actual[event.axis],event.value,"Pointer "+event.axis+" "+JSON.stringify(c))
	for row in oracle.rates:
		var s: Dictionary = {"flags":int(row.flags),"turn":1.25,"tilt":-2.5,"speed":3.75,"turnDelta":4.5,"tiltDelta":-5.5,"predictionInputs":{"tilt":100.0,"turn":200.0,"tiltDelta":300.0,"turnDelta":400.0,"speed":500.0},"manual":0,"yawEvent":0,"zoomEvent":0}
		for step in row.steps:
			CameraState.rate(s,step.axis,step.value,bool(step.impulse))
			for key in step.follow: close_value(s[key],step.follow[key],"Rate "+key+" "+JSON.stringify(row.flags))
			var prediction: Array = [s.predictionInputs.tilt,s.predictionInputs.turn,s.predictionInputs.tiltDelta,s.predictionInputs.turnDelta,s.predictionInputs.speed]
			for i in 5: close_value(prediction[i],step.prediction[i],"Rate prediction "+str(i))
			for key in ["manual","yawEvent","zoomEvent"]: check(s[key] == step[key],"Rate event "+key)
	var camera := CameraState.new(); camera.reset(1,1.7,[2,3,0]); check(camera.update({"position":[2,3,0],"facing":0,"animation":0},1.0/60.0),"Native camera core advances without renderer or JS frame IO")
	check(not camera.set_mode(255) and camera.state.mode == 1,"Invalid native modes cannot replace the current mode")
	check(camera.set_mode(0) and camera.state.pitch == 50 and camera.state.distance == 20,"Changing to Chase uses the original default pose")
	camera.input({"zoom":7.5}); camera.update({"position":[2,3,0],"facing":0,"animation":4},1.0/60.0)
	check(camera.state.distance < 20 and camera.state.zoomImpulse == 0,"Wheel input is consumed once through native exponential zoom")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"originalObservations":1655,"scope":"Retained original camera Follow/steering/pointer/rate observations and authored core state tests; live camera integration, collision, scripted commands and full parity remain pending"},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures.size(),"report":output})); quit(0 if failures.is_empty() else 1)
