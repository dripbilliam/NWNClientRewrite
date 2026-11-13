extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
class Rig extends RefCounted:
	func clip_length(_id: int,_code: int) -> float: return 1.0
class Body extends Node3D:
	var rigs:=Rig.new()
	func set_animation(_code: int,_speed: float) -> void: pass
	func retire() -> void: queue_free()
var checks:=0
var failures: Array=[]
var receive_timings: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func advance(world,frames: int=120) -> void:
	for frame in frames: world.motion.update(1.0/60.0); world.apply_pose(0xffffffce)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var parts:=arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2: args[parts[0]]=parts[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var world:=World.new(); root.add_child(world); world.set_process(false); world.area_id=int(data.area)
	world.receive(data.initial,int(data.actor)); var body:=Body.new(); world.add_child(body); world.instances[int(data.actor)]=body; world.installed[int(data.actor)]=world.signature(world.desired[int(data.actor)].object)
	world.motion.adopt([{"id":int(data.actor),"state":{"modelType":1,"walkDistance":1.0,"runDistance":1.0}}])
	var source_before:=JSON.stringify(world.desired[int(data.actor)].object)
	for step in data.steps:
		check(step.records.size()==1,"Actual World projected %s without raw snapshot"%step.label)
		if step.records.is_empty(): continue
		var began:=Time.get_ticks_usec(); world.observe_movement(step.records)
		receive_timings.append({"label":step.label,"cpuUs":Time.get_ticks_usec()-began})
		check(int(world.motion.objects[int(data.actor)].facingTarget)==int(step.target),"Immediate native owner accepted exact %s lock"%step.label)
		advance(world)
		if step.label=="right": check((-body.basis.z).dot(Vector3.RIGHT)>0.99,"Actual pivot faces right before any new raw world snapshot")
		if step.label=="unlock": check((-body.basis.z).dot(Vector3.RIGHT)>0.99,"Native unlock retains derived bearing")
		if step.label=="left": check((-body.basis.z).dot(Vector3.LEFT)>0.99,"Actual pivot follows next received facing-only lock")
	check(source_before==JSON.stringify(world.desired[int(data.actor)].object),"Immediate facing does not mutate authoritative source snapshot")
	world.observe_movement(data.steps[0].records); check(int(world.motion.objects[int(data.actor)].facingTarget)==int(data.left),"Older movement revision cannot restore an old facing lock")
	var before: Vector3=world.motion.objects[int(data.actor)].orientation
	world.receive_delta([], [int(data.left)],int(data.actor)); advance(world)
	check(before.is_equal_approx(world.motion.objects[int(data.actor)].orientation),"Removed target cannot provide stale position")
	world.close(); world.observe_movement(data.steps[0].records); check(world.motion.objects.is_empty(),"Closed world ignores late facing events")
	world.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"receiveTimings":receive_timings,"scope":"Actual accepted NetworkWorld projection -> native movement owner -> original facing math -> real Node3D pivot before raw snapshot; captured model playback, no server/pixel claim."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
