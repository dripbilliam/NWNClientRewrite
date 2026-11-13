extends SceneTree
const Policy=preload("res://systems/native_render/exit_acceptance.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var states:=[{}, {"playable":false,"object_visuals_complete":false,"interactive":true}, {"playable":true,"object_visuals_complete":false,"interactive":true,"environment_accepted":true}, {"playable":true,"object_visuals_complete":true,"interactive":true,"environment_accepted":true}, {"playable":true,"object_visuals_complete":true,"controlled_distance":1,"environment_accepted":true}]
	for index in states.size():
		var input: Dictionary=states[index]; var expected:=index>=3
		var app:=Policy.classify(input,{},true); var renderer:=Policy.classify(input,{},false)
		check(app.success and app.gameplay_success==expected,"Normal lifecycle can exit without claiming complete gameplay "+str(index))
		check(renderer.success==expected and renderer.gameplay_success==expected,"Standalone renderer retains its strict evidence boundary "+str(index))
		for flag in ["settings-check","actions-check","offline-replay"]:
			check(Policy.classify(input,{flag:"true"},true).success==expected,"Automated "+flag+" cannot pass through the application exemption "+str(index))
		input=input.duplicate(true); input.failure="deliberate transport failure"
		check(not Policy.classify(input,{},true).success and not Policy.classify(input,{},false).success,"Real failure survives either exit policy "+str(index))
	var retired:={"last_world":{"world":states[3]},"world_end_history":[{"ready":true,"complete":true}]}
	check(not Policy.classify(retired,{"offline-replay":"true"},true).success,"A retired world cannot silently satisfy a new active-world replay assertion")
	check(Policy.classify(retired,{},true).success and not Policy.classify(retired,{},true).gameplay_success,"Returning to Main Menu can exit cleanly with historical diagnostics kept separate")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Lifecycle/gameplay evidence boundary, explicit automated modes, real error preservation and historical-world separation. Actual source Exit input and reconnect retention are separate process/local-server checks."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
