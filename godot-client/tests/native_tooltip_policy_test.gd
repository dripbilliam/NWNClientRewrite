extends SceneTree
const Timing=preload("res://systems/native_data/tooltip_timing.gd")
var failures: Array=[]
var checks:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var oracle:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output=argument.trim_prefix("--report=")
		if argument.begins_with("--oracle="): oracle=argument.trim_prefix("--oracle=")
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(source is Dictionary and source.get("binarySha256","")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and source.get("observations",[]).size()==224,"Pinned original complete timing/motion/instant/trigger/removal routines produced 224 observations")
	if source is Dictionary:
		for index in source.get("observations",[]).size():
			var observation: Dictionary=source.observations[index]; var input: Dictionary=observation.input; var expected: Dictionary=observation.output
			var policy:=Timing.new(); policy.remaining=int(input.remaining); policy.delay=int(input.delay); policy.saved=int(input.saved); policy.active=int(input.active)
			policy.point=Vector2i(100,200); var origin: Array=input.get("origin",[10,20]); policy.origin=Vector2i(int(origin[0]),int(origin[1]))
			var event: Dictionary
			match str(observation.kind):
				"advance": event=policy.advance(int(input.delta),int(input.hit),bool(input.allowed),int(input.flags))
				"motion": event=policy.motion(int(input.hit),Vector2i(int(input.point[0]),int(input.point[1])))
				"instant": event=policy.instant(bool(input.enabled),bool(input.visible),int(input.hit),bool(input.allowed),int(input.flags))
				"trigger": event=policy.trigger(bool(input.visible),int(input.hit),bool(input.allowed),int(input.flags))
				"remove": event=policy.remove(int(input.owner))
			var events: Array=[]
			if int(event.finish)!=0: events.append(["finish",int(event.finish)])
			if int(event.trigger)!=0: events.append(["trigger",int(event.trigger)])
			var actual: Dictionary={"remaining":policy.remaining,"delay":policy.delay,"saved":policy.saved,"active":policy.active,"point":[policy.point.x,policy.point.y],"origin":[policy.origin.x,policy.origin.y],"events":events}
			# JSON observations decode integers as floats; normalize the actual
			# snapshot through the same decoder before comparing every field.
			check(JSON.parse_string(JSON.stringify(actual))==expected,"Original observation %d (%s): expected %s; actual %s"%[index,str(observation.kind),JSON.stringify(expected),JSON.stringify(actual)])
	var configured:=Timing.new(); configured.remaining=12345; configured.configure(275000)
	check(configured.remaining==12345 and configured.delay==275000 and configured.saved==275000,"Configuration changes the next delay and saved instant-mode delay without resetting the active countdown")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Pure native policy compared with complete original machine-code execution under explicit hit/modal/cursor/virtual callback providers; actual GUI input and pixels require separate checks."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
