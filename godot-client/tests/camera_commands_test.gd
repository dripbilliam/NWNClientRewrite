extends SceneTree
const Core = preload("res://systems/game_camera_state.gd")
var checks := 0
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(v: bool,label: String) -> void:
	checks += 1
	if not v and failures.size() < 40: failures.append(label)
func near(v: Variant,w: Variant,label: String) -> void:
	check(v != null and w != null and absf(float(v)-float(w)) <= 0.0001,label+": "+str(v)+" vs "+str(w))
func run() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/camera-commands-original-v1.json"))
	check(fixture.target == "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Immutable original camera observations")
	for row in fixture.commands:
		var core := Core.new(); var c: Dictionary = row.case; var mode := int(c.get("mode",1)); core.reset(mode,1.75 if mode == 1 else 1.25,null,c.get("yaw",35))
		core.state.distance = c.get("distance",20); core.state.pitch = c.get("pitch",50)
		for i in row.steps.size():
			var step: Dictionary = row.steps[i]; var expected: Dictionary = step.state
			if i == 1 and int(row.steps[0].minor) == 3: core.state.merge({"distance":7.0,"yaw":-20.0,"pitch":30.0},true)
			check(core.apply_command(step.command),"Original command accepted "+JSON.stringify(step.command))
			var s: Dictionary = core.state
			for key in ["flags","mode","distance","yaw","pitch"]: near(s[key],expected[key],"Receiver "+key)
			for j in 3: near(s.offset[j],expected.height[j],"Height offset")
			var clamps := ["clampYaw","minYaw","maxYaw","clampPitch","minPitch","maxPitch","clampDist","minDist","maxDist"]
			for j in clamps.size(): near(s[clamps[j]],expected.clamps[j],"Receiver "+clamps[j])
			var limits := ["minPitch","maxPitch","minDist","maxDist"]
			for j in 4: near(s.rawLimits[limits[j]],expected.limits[j],"Raw limit")
			for j in 3: check(int(s.locks[["distance","pitch","yaw"][j]]) == expected.locks[j],"Original axis lock")
			if int(expected.saved.mode) == 255: check(s.savedCamera == null,"Saved camera consumed or absent")
			else:
				check(s.savedCamera != null and s.savedCamera.mode == expected.saved.mode,"Saved camera mode")
				for j in 3: near(s.savedCamera[["distance","yaw","pitch"][j]],expected.saved.values[j],"Saved value")
	for row in fixture.packets:
		var core := Core.new(); core.reset(); core.state.merge(row.case,true)
		check(core.apply_command(row.command),"Original location mask accepted")
		for key in ["yaw","pitch","distance"]: near(core.state[key],row.observation[key],"Location packet "+key)
		for i in 4: near(core.state.scriptLocation[["distance","yaw","pitch","rate"][i]],row.observation.target[i],"Location target")
	for row in fixture.frames:
		var c: Dictionary = row.case; var s: Dictionary = c.duplicate(true)
		s.merge({"turn":0.0,"tilt":0.0,"speed":0.0,"scriptLocation":{"distance":c.target[0],"yaw":c.target[1],"pitch":c.target[2],"rate":Core.f(c.transition)}},true)
		check(int(Core.location(s,c.dt,bool(c.get("paused",false)))) == row.result,"Original location completion")
		for key in ["yaw","pitch","distance","turn","tilt","speed"]: near(s[key],row.observation[key],"Transition "+key+" "+JSON.stringify(c))
	for row in fixture.attachments:
		if not row.follow.created: continue # Object lookup belongs to the live owner.
		var core := Core.new(); core.reset(); var c: Dictionary = row.case; core.state.mode = int(c.get("mode",1))
		core.state.locks.pitch = bool(c.get("pitchLocked",false)); core.state.locks.distance = bool(c.get("distanceLocked",false))
		var cached: Array = c.get("cached",[12.75,35.125,42.5]); core.state.rememberedPose = {"distance":cached[0],"yaw":cached[1],"pitch":cached[2]}
		core.attach(c.get("position",[2,3,0.5]),c.get("height",1.75),c.get("creature",true),bool(c.get("findClear",false)))
		for key in ["distance","yaw","pitch","spring"]: near(core.state[key],row.follow[key],"Original attach "+key)
		for key in ["focus","offset"]:
			for j in 3: near(core.state[key][j],row.follow[key][j],"Attach "+key)
		var clamps := ["clampYaw","minYaw","maxYaw","clampPitch","minPitch","maxPitch","clampDist","minDist","maxDist"]
		for j in 9: near(core.state[clamps[j]],row.follow.clamps[j],"Attach "+clamps[j])
		check(core.state.findClearView == bool(row.findClear),"Original clear-view request storage")
	var core := Core.new(); core.reset(1,1.75,[0,0,0]); core.apply_command({"kind":"camera-height","height":3}); core.set_height(2,true)
	check(core.state.height == 3,"Deferred appearance preserves script height")
	core.apply_command({"kind":"camera-height","height":0}); check(core.state.height == 1.5,"Zero height restores current default")
	core.state.scriptLocation = {"distance":5.0,"yaw":70.0,"pitch":60.0,"rate":90.0}
	var complete := false
	for frame in 10000:
		complete = Core.location(core.state,1.0/60.0); Core.follow(core.state,1.0/60.0,[0,0,0])
		if complete: break
	check(complete,"Synchronized location integrates to completion through native Follow")
	near(core.state.yaw,70,"Integrated yaw"); near(core.state.pitch,60,"Integrated pitch"); near(core.state.distance,5,"Integrated distance")
	for invalid in [{"kind":"camera-location","mask":1},{"kind":"camera-limits","limits":{"minPitch":NAN}},{"kind":"camera-height","height":"3"},{"kind":"camera-lock","axis":"bogus","locked":true},{"kind":"camera-flags","flags":1.5}]: check(not core.apply_command(invalid),"Malformed command rejected")
	var f := FileAccess.open(output,FileAccess.WRITE); f.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty(),"originalGroups":[52,104,378,216,10],"scope":"Original command/location/attachment math, with decoded original packets; scene lookup/collision/clear-view and actual server integration separate"},"\t")); f.close()
	print(JSON.stringify({"checks":checks,"failures":failures.size()})); quit(0 if failures.is_empty() else 1)
