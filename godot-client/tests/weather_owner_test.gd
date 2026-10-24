extends SceneTree
const Owner = preload("res://systems/area_environment.gd")
var checks: Array = []
func check(value: bool,label: String) -> void: checks.append({"passed":value,"name":label})
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2);return
	var owner := Owner.new()
	var message := {"revision":1,"weather":{"type":1,"enabled":true},"rows":{"0":{"fadeTime":6000},"1":{"fadeTime":6000}}}
	check(owner.receive_weather(message),"Valid physical weather row and byte/bool request are admitted")
	message.rows["1"].fadeTime = 1
	check(owner.weather_fades["1"] == 6000,"Received rules metadata is privately owned")
	owner.advance_weather(.0004);owner.advance_weather(.0006)
	check(owner.weather.remaining == 5999 and owner.weather_clock_fraction < .000001,"Sub-millisecond rendered frames accumulate integer native elapsed time")
	for change in [func(v):v.revision=1,func(v):v.weather.type=1.5,func(v):v.weather.type=256,func(v):v.weather.enabled=1,func(v):v.rows["1"].fadeTime=1.5,func(v):v.rows["256"]={"fadeTime":0}]:
		var bad: Dictionary = message.duplicate(true);bad.revision = 2;change.call(bad)
		check(not owner.receive_weather(bad) and owner.weather_revision == 1 and owner.weather.remaining == 5999,"Invalid or stale weather metadata cannot partially reset an active fade")
	owner.advance_weather(6)
	check(owner.weather.current == 1 and owner.weather.instances == 6 and owner.weather.intensity == 100,"State reaches full rain through the owner integer clock")
	message.revision = 2;message.weather.enabled = false
	check(owner.receive_weather(message),"Newer clear request restarts the native off fade")
	owner.advance_weather(6)
	check(owner.weather.instances == 0 and owner.weather.removed == 6 and owner.weather.intensity == 0,"Clear endpoint retires every planned weather model")
	var ref: WeakRef = weakref(owner.weather);owner.free()
	check(ref.get_ref() == null,"Weather state lifetime ends with the area environment owner")
	var passed := checks.all(func(v):return v.passed)
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"checks":checks,"scope":"Weather state ownership, validation and integer frame clock; precipitation presentation and native pause timing pending"},"\t"));file.close()
	print("WEATHER_OWNER_TEST ",checks.size()," checks, passed=",passed);quit(0 if passed else 1)
