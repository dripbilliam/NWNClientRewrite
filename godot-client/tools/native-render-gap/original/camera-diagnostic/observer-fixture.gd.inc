extends SceneTree
class ProbeWorld extends RefCounted:
	var area_id:=3
	var complete:=true
	func ready_for_control() -> bool:return true
	func snapshot(_details: bool) -> Dictionary:return {"object_visuals_complete":complete,"pending_batches":0,"entities":12}
class ProbeController extends RefCounted:
	var follow_state: Variant={"state":{}}
var world=ProbeWorld.new()
var controller=ProbeController.new()
var args:={"camera-motion-probe":"true","offline-replay":"true"}
var epoch:=2
var session_connection:=1
var closing:=false
var report: Dictionary={}
var sent: Array=[]
var checks:=0
var failures: Array=[]
var actor:={"actor_id":4,"lifetime":5,"generation":2,"area_id":3,"active":false,"script":0,"driveHeld":false,"received_position":[5.0,6.0,7.0],"position":[5.0,6.0,7.0],"render":[5.0,6.0,7.0]}
var actual_yaw:=30.0
func send(value: Dictionary) -> void:sent.append(value.duplicate(true))
func observed_camera_snapshot() -> Dictionary:return {"controlled":actor.duplicate(true),"pose_valid":true,"pose_space":"world","position":[actual_yaw,4.0,25.0],"quaternion":[0.0,0.0,0.0,1.0],"follow":{"yaw":actual_yaw}}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func command(sequence: float,phase: String,observe: bool=true) -> Dictionary:return {"connection":1,"generation":2,"areaId":3,"value":{"camera_state":{"yaw":actual_yaw},"camera_probe":{"sequence":sequence,"phase":phase,"observe":observe,"expected":{"connection":1,"generation":2,"areaId":3,"actorId":4,"lifetime":5}}}}
func apply(message: Dictionary) -> bool:return private_camera_probe_admit(message,message.value)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(apply(command(1.0,"bind")),"JSON floating integer sequence admitted")
	await process_frame;await process_frame;await process_frame;await process_frame
	check(sent.size()==1 and sent[0].kind=="camera-probe-observed" and sent[0].sequence==1 and sent[0].camera.follow.yaw==30,"Deferred actual camera observation")
	actual_yaw=42.0;check(apply(command(2.0,"measure-start")),"Measurement starts")
	await process_frame;await process_frame;await process_frame;await process_frame
	check(report.camera_probe_native.has("begin_process_frames") and sent[-1].camera.position[0]==42,"Native frame/time and actual transform read")
	actor.active=true;check(not apply(command(3.0,"measure")),"Actor activity cancels")
	actor.active=false;actor.lifetime=6;check(not apply(command(3.0,"measure")),"Actor lifetime cancels")
	actor.lifetime=5;actor.position=[9.0,6.0,7.0];check(not apply(command(3.0,"measure")),"Presented movement cancels")
	actor.position=[5.0,6.0,7.0];var bad:=command(3.5,"measure");check(not apply(bad),"Fractional sequence rejected")
	bad=command(3.0,"measure");bad.generation=9;check(not apply(bad),"Retired generation rejected")
	actual_yaw=30.0;check(apply(command(3.0,"measure-end")),"Valid next sequence after rejected requests")
	await process_frame;await process_frame;await process_frame;await process_frame
	check(report.camera_probe_native.frames_delta>0 and report.camera_probe_native.elapsed_usec>0 and report.camera_probe_native.average_fps>0,"Exact positive native delta")
	check(apply(command(4.0,"restored")),"Restore observation admitted")
	world.complete=false
	await process_frame;await process_frame;await process_frame;await process_frame
	check(sent[-1].kind=="camera-probe-error" and sent[-1].reason=="world became incomplete","Deferred world readiness retirement rejected")
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.substr(9)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Standalone headless private observer/parser/deferred/scoping oracle. No real world, camera GPU, input or FPS test."}));file.close()
	world=null;controller=null
	quit(0 if failures.is_empty() else 1)

