extends SceneTree
const Group=preload("res://systems/native_render/particle_stream_group.gd")
const Fog=preload("res://systems/native_render/particle_stream_fog.gd")
const State=preload("res://systems/native_render/native_surface_state.gd")
var checks:=0
var failures: Array=[]

func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)

func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var owner:=Node3D.new();root.add_child(owner)
	var next_owner:=Node3D.new();root.add_child(next_owner)
	var camera:=Camera3D.new();root.add_child(camera)
	camera.environment=Environment.new()
	camera.environment.fog_enabled=true
	camera.environment.fog_light_color=Color(0.13,0.26,0.71)
	camera.environment.fog_depth_begin=4
	camera.environment.fog_depth_end=125
	State.bind(owner)
	State.publish(owner,Vector3(0.7,0.2,0.4),true,11,99,true)
	var area_packet: Array=State.packet(owner)
	var publications: int=int(State.snapshot().publications)
	check(Group.frame_fog(camera,owner,true)==area_packet,"area packet used exactly")
	check(State.authoritative(owner) and State.packet(owner)==area_packet and int(State.snapshot().publications)==publications,"authoritative area fog not republished")
	camera.environment.fog_light_color=Color(0.9,0.1,0.1)
	check(Group.frame_fog(camera,owner,true)==area_packet,"camera change cannot replace area packet")
	State.publish(owner,Vector3(0.4,0.3,0.2),false,4,80,true)
	var disabled: Array=State.packet(owner)
	check(Group.frame_fog(camera,owner,true)==disabled and disabled[7]==0.0,"disabled area packet retained")
	State.bind(owner)
	var raw: Array=Fog.sample(camera,true)
	State.publish_camera(owner,raw)
	var expected: Array=Fog.sample(camera,true,owner)
	var old_publications: int=int(State.snapshot().publications)
	State.bind(owner)
	var actual: Array=Group.frame_fog(camera,owner,true)
	check(actual==expected and actual==State.packet(owner),"camera fallback matches old sample/publish/sample path")
	check(int(State.snapshot().publications)==old_publications+1 and not State.authoritative(owner),"camera fallback publishes once")
	camera.environment.fog_depth_end=140
	check(Group.frame_fog(camera,owner,true)==State.packet(owner) and State.packet(owner)[5]==140.0,"camera fallback updates on camera change")
	State.bind(next_owner)
	State.publish(next_owner,Vector3(0.8,0.6,0.1),true,8,120,true)
	var successor: Array=State.packet(next_owner)
	check(Group.frame_fog(camera,owner,true)==Fog.sample(camera,true),"stale owner receives camera fallback")
	check(State.packet(next_owner)==successor and State.authoritative(next_owner),"stale owner cannot change successor")
	check(Group.frame_fog(camera,owner,false)==Fog.sample(camera,false,owner),"ordinary surface route unchanged")
	State.retire(next_owner)
	check(Group.frame_fog(camera,owner,true)==Fog.sample(camera,true),"retired binding has camera fallback")
	owner.free();next_owner.free();camera.free()
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null:quit(3);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Accepted shared CPU presentation fog selection parity; no simulation, render, FPS or Arelith claim"},"  "))
	file.close();quit(0 if failures.is_empty() else 1)
