extends "res://tests/native_template_cache_test.gd"
const EntryCamera=preload("res://systems/native_render/entry_camera.gd")
const Camera=preload("res://systems/camera_controller.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var pool:=Pool.new()
	check(pool.can_publish(),"First complete model can progress in a new frame")
	pool.publication_finished(Time.get_ticks_usec()-4000)
	check(not pool.can_publish(),"Another stream cannot independently spend a second publication budget")
	check(pool.can_publish(true),"Controlled actor has one priority reservation above background work")
	pool.publication_finished(Time.get_ticks_usec(),true)
	check(not pool.can_publish(true) and not pool.can_publish(),"Controlled priority does not become an unlimited budget bypass")
	var last_frame:=Engine.get_process_frames()
	while Engine.get_process_frames()==last_frame: await process_frame
	check(pool.can_publish() and pool.publications==0,"Publication quota resets on actual engine frames")
	pool.maximum_publications_per_frame=2
	pool.publication_finished(Time.get_ticks_usec()); pool.publication_finished(Time.get_ticks_usec())
	check(not pool.can_publish(),"A large number of cheap publications still observes the shared unit cap")
	var host:=Node3D.new(); root.add_child(host)
	var camera:=Camera3D.new(); host.add_child(camera)
	var controller:=Camera.new(); host.add_child(controller); controller.set_process(false)
	var entry:=EntryCamera.new(); var position:=Vector3(40,2,-80)
	check(entry.anchor(camera,controller,position) and entry.anchored,"Server entry anchors camera before any physical actor exists")
	var pose:=camera.transform; var remembered:=controller.remembered_pose()
	check(not entry.anchor(camera,controller,Vector3(42,2,-80)) and camera.transform==pose and controller.remembered_pose()==remembered,"Actor readiness does not reset the camera pose a second time")
	var next:=EntryCamera.new()
	check(next.anchor(camera,controller,Vector3(-5,0,12),remembered),"A new area gets an independent initial camera anchor")
	var assets:=Assets.new(); host.add_child(assets); var store:=Store.new()
	var bytes:=source("auth_shared").to_utf8_buffer()
	var first:=assets.decode(bytes,2002,"mdl-actor-v2","",store)
	var second:=assets.decode(bytes,2002,"mdl-actor-v2","",store)
	check(first.error.is_empty() and second.memory_decode_hit,"Base actor definitions reuse native decoded data")
	check(is_same(first.value.nodes,second.value.nodes) and not is_same(first.value,second.value) and not is_same(first.value.animations,second.value.animations),"Immutable physical definitions share while mutable inheritance owners remain private")
	first.value.animations.append({"name":"private"}); first.value.rig_asset={"private":true}
	check(second.value.animations.is_empty() and not second.value.has("rig_asset"),"Rig preparation and inherited clip changes cannot leak into another actor")
	assets.close(); host.queue_free(); await process_frame; await process_frame; pool.clear()
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0})); file.close()
	quit(0 if failures.is_empty() else 1)
