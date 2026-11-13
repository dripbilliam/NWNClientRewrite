extends SceneTree
# Actual current LiveWorld._profile_process with no admitted appearance batch.
# A tiny one-pending-owner case checks the nonempty fallback without adoption.
const ControlWorld=preload("res://systems/native_render/live_world.gd")
const CandidateWorld=preload("res://tools/nwn78/live_world_empty_batches_candidate.gd")
var output:=""
var checks:=0
var failures: Array=[]
class Combat extends RefCounted:
	var updates:=0
	func update(_delta: float,_desired: Dictionary) -> void:updates+=1
class Pending extends Node:
	var actors: Dictionary={}
	var instances: Dictionary={}
	var done:=false
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func make(script: Script,pending: bool) -> Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var world=script.new();host.add_child(world);world.set_process(false)
	world.combat=Combat.new();world.catalog=null
	if pending:
		var owner:=Pending.new();host.add_child(owner)
		world.batches.append({"owner":owner,"actors":true,"keys":{}})
	return {"host":host,"world":world}
func leg(script: Script,pending: bool,tag: String) -> Dictionary:
	var row:=make(script,pending)
	var world=row.world
	for sample in 100:world._profile_process(0.016)
	var samples: Array=[]
	for sample in 180:
		var before:=Time.get_ticks_usec()
		for iteration in 32:world._profile_process(0.016)
		samples.append(Time.get_ticks_usec()-before)
	samples.sort()
	var result:={"tag":tag,"pending":pending,"median_group_us":samples[90],"p95_group_us":samples[170],"frames":int(world.stats.simulated_motion_frames),"combat_updates":row.world.combat.updates,"batch_count":world.batches.size(),"candidate_state":var_to_bytes([world.stats,world.motion.objects,world.batches.size()]).hex_encode()}
	row.host.free()
	return result
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var cases: Array=[]
	for pending in [false,true]:
		var legs: Array=[]
		for mode in ["control","candidate","candidate","control"]:
			legs.append(leg(ControlWorld if mode=="control" else CandidateWorld,pending,mode))
			await process_frame
		for item in legs:
			check(item.frames==5860 and item.combat_updates==5860 and item.batch_count==int(pending),"actual World callbacks and pending owner persist")
			check(item.candidate_state==legs[0].candidate_state,"World final state identical to control")
		cases.append({"pending":pending,"legs":legs})
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"Actual current LiveWorld headless SceneTree empty/pending adoption loop component; no dense assets, FPS or ownership claim"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
