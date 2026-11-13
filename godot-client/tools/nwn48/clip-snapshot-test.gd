extends SceneTree

const WeatherWorld = preload("res://systems/weather_world.gd")

class FakeState extends RefCounted:
	var current := 1
	var instances := 6
	var intensity := 50.0
	var snapshots := 0
	func snapshot() -> Dictionary:
		snapshots += 1
		return {"clipFraction": intensity / 100.0}

class FakeClient extends Node:
	var world_scope := {"admitted":true,"ticket":7}
	var pivots: Dictionary = {}
	var controlled_id := 1
	var particles = null
	var commands: Array = []
	func command(value: Dictionary) -> void: commands.append(value)

class FakeEnvironment extends Node:
	var camera: Camera3D

class FakeModel extends Node3D:
	var id := 0
	var state: FakeState
	var events: Array
	var calls := 0
	var retired := false
	func sample_weather_clip(clip: String, fraction: float) -> bool:
		calls += 1
		events.append({"id":id,"clip":clip,"fraction":fraction})
		if id == 3 and calls == 2: state.intensity = 90.0
		return true
	func retire() -> void:
		retired = true
		queue_free()

var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path = arg.substr(9)
	if report_path.is_empty(): quit(2); return
	var client := FakeClient.new()
	root.add_child(client)
	var pivot := Node3D.new()
	client.add_child(pivot)
	client.pivots[1] = pivot
	var environment := FakeEnvironment.new()
	root.add_child(environment)
	var camera := Camera3D.new()
	environment.add_child(camera)
	environment.camera = camera
	var owner := WeatherWorld.new()
	root.add_child(owner)
	owner.client = client
	owner.environment_owner = environment
	owner.current_type = 1
	owner.batch_id = 3
	owner.types[1] = {"resourceId":4,"key":"fx_rain","animation":"rain"}
	var state := FakeState.new()
	var events: Array = []
	var models: Array[FakeModel] = []
	for id in range(1, 7):
		var model := FakeModel.new()
		model.id = id
		model.state = state
		model.events = events
		owner.add_child(model)
		owner.models[id] = model
		models.append(model)
	owner.advance(state)
	check(state.snapshots == 1, "one snapshot for six equal-intensity clips")
	check(events.size() == 6, "six ordered samples")
	for i in 6:
		check(events[i].id == i + 1 and events[i].clip == "rain" and is_equal_approx(events[i].fraction, 0.5), "first clip %d" % i)
	check(owner.stats.samples == 1 and owner.last_intensity == 50.0, "first sample bookkeeping")
	owner.advance(state)
	check(state.snapshots == 1 and events.size() == 6 and owner.stats.samples == 1, "unchanged intensity does not resample")
	state.intensity = 70.0
	owner.advance(state)
	check(state.snapshots == 3, "reentrant intensity change recomputes once per distinct value")
	check(events.size() == 12, "all six models sample in original order after change")
	for i in 6:
		var row: Dictionary = events[i + 6]
		check(row.id == i + 1 and is_equal_approx(row.fraction, 0.7 if i < 3 else 0.9), "changed clip %d" % i)
	check(owner.stats.samples == 2 and owner.last_intensity == 90.0, "final intensity bookkeeping")
	state.current = 0
	state.instances = 0
	owner.advance(state)
	check(owner.models.is_empty() and owner.current_type == 0 and owner.stats.removed == 6, "clear retires six models")
	check(models.all(func(model): return model.retired), "all models received retire")
	check(client.commands.size() == 1 and client.commands[0].kind == "weather-release" and client.commands[0].batchId == 3, "clear sends one release")
	owner.retire()
	owner.advance(state)
	check(owner.retired and events.size() == 12 and client.commands.size() == 1, "retired owner cannot resample or send another release")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify({"issue":"NWN-48","checks":checks,"passed":failures.is_empty(),"failures":failures,"snapshots":state.snapshots,"events":events,"commands":client.commands,"scope":"Six model clip order, reentrant intensity and clear; no FPS"},"  ") + "\n")
	file.close()
	print(JSON.stringify({"checks":checks,"failures":failures.size(),"snapshots":state.snapshots}))
	quit(0 if failures.is_empty() else 1)
