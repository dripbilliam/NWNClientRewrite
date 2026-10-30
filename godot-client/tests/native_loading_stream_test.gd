extends SceneTree
const Setup=preload("res://systems/native_data/capture_setup.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Visibility=preload("res://systems/native_render/particle_visibility.gd")
var failures: Array=[]
var checks:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture.input))
	var host:=Node3D.new(); root.add_child(host); var visibility:=Visibility.new(); host.add_child(visibility)
	var setup:=Setup.new(); host.add_child(setup); var prepared: Dictionary={}
	setup.completed.connect(func(catalog,error,stats):prepared.merge({"catalog":catalog,"error":error,"stats":stats}))
	setup.start(data,str(fixture.get("sourceSupplement","")),str(fixture.get("sourceSupplementSha256","")))
	while prepared.is_empty(): await process_frame
	check(str(prepared.error).is_empty(),"Existing captured resource catalog mounts without a server connection")
	var world:=World.new(); host.add_child(world); world.open(prepared.catalog,data.area,1,ProjectSettings.globalize_path("user://native-prepared-v2")); world.receive(data.objects,int(data.controlledId))
	var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(data.view.position[0],data.view.position[1],data.view.position[2]); camera.quaternion=Quaternion(data.view.quaternion[0],data.view.quaternion[1],data.view.quaternion[2],data.view.quaternion[3]); camera.current=true
	root.size=Vector2i(1280,800); var deadline:=Time.get_ticks_msec()+120000; var began:=Time.get_ticks_usec(); var worst:=0.0; var before:=began
	while Time.get_ticks_msec()<deadline:
		await process_frame; var now:=Time.get_ticks_usec(); worst=maxf(worst,(now-before)/1000.0); before=now
		if world.ready_for_control() and world.instances.size()+world.hidden.size()+world.failed_objects.size()==world.desired.size() and world.batches.is_empty(): break
	var elapsed:=(Time.get_ticks_usec()-began)/1000.0; var state:=world.snapshot(); check(state.ready,"Captured player's complete model and tiles become ready"); check(state.pending_batches==0,"All bounded background batches complete")
	for frame in 20: await process_frame
	check(world.instances.size()==state.entities and world.ready_for_control(),"Live entities remain valid after completed-batch data disposal")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"elapsed_ms":elapsed,"worst_frame_ms":worst,"adoption":state.get("adoption_timings",{}),"batches":state.batches,"entities":state.entities,"desired":state.desired,"failed_objects":state.failed_objects.size(),"terrain_errors":state.terrain.errors,"data_retirement":state.data_retirement,"network":false,"scope":"Offline captured live-world path; functional diagnostic, not clean FPS acceptance"}
	world.close(); result.data_retirement=world.data_retirement.snapshot(); check(result.data_retirement.pending==0 and result.data_retirement.submitted==result.data_retirement.completed,"All data-only retirement workers drain on close")
	result.success=failures.is_empty(); result.checks=checks; setup.close(); host.free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); quit(0 if failures.is_empty() else 1)
