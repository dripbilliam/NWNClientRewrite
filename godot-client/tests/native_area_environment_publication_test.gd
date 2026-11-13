extends "res://native_session_world.gd"
# Actual Root/Session callback and real AreaEnvironment. Launcher, protocol,
# scene/model loading and native input are deliberately not initialized.
class HeaderWorld extends Node3D:
	var area_id:=91
	var generation:=7
	var closed:=false
	var retiring:=false
	var minutes_per_hour:=1
	var placeable_lights=null
	var point_wind=null
	var effects=null
	var full_updates:=0
	var delta_updates:=0
	func receive(_objects: Array,_controlled: int)->void:full_updates+=1
	func receive_delta(_objects: Array,_removed: Array,_controlled: int)->void:delta_updates+=1
class HeaderUi extends Node:
	var full_updates:=0
	var delta_updates:=0
	func set_world(_generation: int,_area: int,_controlled: int,_objects: Array,_inventory: Dictionary,_data: Dictionary)->void:full_updates+=1
	func update_world(_generation: int,_area: int,_controlled: int,_objects: Array,_removed: Array,_inventory: Dictionary,_data: Dictionary)->void:delta_updates+=1
class HeaderTargets extends RefCounted:
	func receive(_objects: Array,_removed: Array,_delta: bool)->bool:return false
class SkySelection extends Node3D:
	var camera: Camera3D
	var selected: Array=[]
	var sources: Array=[]
	func select_sky(id: int)->bool:selected.append(id);return true
	func advance(value: Dictionary,elapsed: float,_fog: Color)->void:sources.append({"period":value.time.timeOfDay,"elapsed":elapsed})
	func snapshot()->Dictionary:return {"selected":selected.duplicate()}
var checks:=0
var failures: Array=[]
var observations: Array=[]
func _initialize()->void:run_publication.call_deferred()
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func header()->Dictionary:
	# JSON round trip preserves the actual numeric wire shape, not a bool-only
	# authored admission assumption. Calendar/bridge fields are intentionally present.
	return JSON.parse_string(JSON.stringify({"area":{"id":91,"fields":{"98":0x101010,"9c":0x202020,"a0":0x776655,"a4":20,"a8":false,"ac":0.0,"b0":0.0,"b4":-1.0,"b8":0x303030,"bc":0x404040,"c0":0x112233,"c4":5,"c8":true,"cc":0.0,"d0":0.0,"d4":-1.0,"d8":true,"dc":false,"e0":1,"104":60,"108":45.0,"e8":0.5}},"time":{"timeOfDay":1,"transition":0,"hour":12,"day":1,"month":1,"year":1372},"module":{"minutesPerHour":1},"objects":[],"controlledId":42,"inventory":{},"ui":{},"bridgeMode":"full"}))
func make_environment(owner: HeaderWorld):
	var sky:=SkySelection.new();owner.add_child(sky);owner.set_meta("native_sky_owner",sky)
	var value:=AreaEnvironment.new();root.add_child(value);value.configure({},owner);value.camera=camera;value.set_process(false)
	return value
func route(value: Dictionary,generation_value: int=7,connection_value: int=3)->void:
	# Real Session admission then real NativeLiveWorld's same-generation snapshot
	# branch. No override of receive/publish/accept_connection is used.
	receive({"kind":"snapshot","connection":connection_value,"generation":generation_value,"data":value})
func run_publication()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	root.size=Vector2i(640,480);epoch=7;session_connection=3;cancelled_connection=-1;initialized=true
	world=HeaderWorld.new();root.add_child(world)
	camera=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,8,8);camera.look_at(Vector3.ZERO)
	gameplay_ui=HeaderUi.new();root.add_child(gameplay_ui);transition_targets=HeaderTargets.new()
	environment=make_environment(world)
	var value:=header();var before:=value.duplicate(true)
	route(value)
	var first_revision: int=environment.revision
	check(first_revision>=0 and report.get("environment_accepted",false),"Actual accepted Root full snapshot publishes the first atmosphere")
	check(environment.source.time.timeOfDay==1 and environment.sample.complete and environment.sample.fog==AreaEnvironment.packed(0x112233),"Real AreaEnvironment applies received daytime fog and phase")
	check(environment.get_meta("native_header_scope",[])==[3,world.get_instance_id(),7,91,environment.get_instance_id()],"Existing Environment carries exact connection/World/area/generation/owner witness")
	check(value==before and environment.lighting_world.get_ref()==world,"Publication detaches source and retains the configured current World")
	check(world.full_updates==1 and gameplay_ui.full_updates==1,"Existing World and UI full-snapshot handling still runs")
	environment.advance(5.0);var revision: int=environment.revision
	route(value)
	check(environment.revision==revision and environment.elapsed==5.0 and environment.source.elapsed==0.0,"Unchanged full header never resets the separate advancing elapsed clock")
	value.bridgeMode="delta";route(value)
	check(environment.revision==revision and environment.elapsed==5.0 and world.delta_updates==1 and gameplay_ui.delta_updates==1,"Actual delta branch preserves unchanged atmosphere without suppressing World/UI updates")
	value.time.hour=13;value.time.day=2;value.area.fields.e8=4.0;route(value)
	check(environment.revision==revision and environment.elapsed==5.0,"Calendar and wind-only header changes do not republish the compact atmosphere")
	value.time.timeOfDay=3;value.time.transition=1000;route(value)
	check(environment.revision==revision+1 and environment.source.time.timeOfDay==3 and environment.elapsed==1.0 and not environment.sample.complete,"Same-area received dawn/transition update replaces the stale entry phase")
	check(environment.sample.isNight and environment.sample.fog!=AreaEnvironment.packed(0x112233),"Real native phase arithmetic changes authored fog immediately after publication")
	environment.advance(6.0);revision=environment.revision
	value.area.fields.c0=0x334455;route(value)
	check(environment.revision==revision+1 and environment.elapsed==7.0 and environment.source.elapsed==7.0,"Changed authored atmosphere carries existing dawn progress instead of restarting it")
	revision=environment.revision;route(value);route(value)
	check(environment.revision==revision and environment.elapsed==7.0,"Carried source.elapsed is compared correctly on repeated identical headers")
	value.module.minutesPerHour=2;route(value)
	check(environment.revision==revision+1 and environment.elapsed==7.0 and environment.source.minutesPerHour==2,"Module duration update reaches the existing owner while retaining elapsed progress")
	revision=environment.revision;route(value)
	check(environment.revision==revision and environment.elapsed==7.0,"Repeated changed-duration header does not keep resetting its clock")
	value.time.timeOfDay=2;value.time.transition=0;route(value)
	check(environment.source.time.timeOfDay==2 and environment.elapsed==0.0 and environment.sample.complete and environment.sample.fog==AreaEnvironment.packed(0x776655),"Later same-generation night update changes the real fog/light source")
	value.area.fields.e0=6;value.area.fields["108"]=35.0;route(value)
	check(environment.sky.selected.back()==6 and environment.range_state.end==35.0,"Changed received sky ID and clip reach existing native selection/fog owners")
	var stable: Dictionary=environment.source.duplicate(true);revision=environment.revision
	var invalid:=value.duplicate(true);invalid.time.timeOfDay=19
	check(not publish_area_environment(invalid,7) and environment.source==stable and environment.revision==revision,"Malformed phase does not replace the accepted atmosphere")
	invalid=value.duplicate(true);invalid.area.fields.erase("108")
	check(not publish_area_environment(invalid,7) and environment.source==stable,"Incomplete authored atmosphere is explicit rejection, never a default")
	check(not publish_area_environment(value,6) and environment.source==stable,"Stale generation is rejected before source mutation")
	invalid=value.duplicate(true);invalid.area.id=92
	check(not publish_area_environment(invalid,7) and environment.source==stable,"Different area with the same generation cannot publish")
	world.generation=8
	check(not publish_area_environment(value,7) and environment.source==stable,"World generation must agree with Root and packet")
	world.generation=7;world.retiring=true
	check(not publish_area_environment(value,7) and environment.source==stable,"Retiring World cannot publish late environment input")
	world.retiring=false;world.closed=true
	check(not publish_area_environment(value,7) and environment.source==stable,"Closed World cannot publish")
	world.closed=false;closing=true
	check(not publish_area_environment(value,7) and environment.source==stable,"Closing Root cannot publish")
	closing=false;session_connection=4
	check(not publish_area_environment(value,7) and environment.source==stable,"Existing Environment cannot adopt a new accepted connection without replacement")
	session_connection=3
	var old_world=world;var old_environment=environment
	world=HeaderWorld.new();root.add_child(world)
	check(not publish_area_environment(value,7) and old_environment.source==stable,"An Environment configured for a former World cannot bind its replacement")
	environment=make_environment(world)
	check(publish_area_environment(value,7) and environment.revision==first_revision and environment.get_meta("native_header_scope")[1]==world.get_instance_id(),"Fresh current Environment owns its independent source/revision after World replacement")
	var captured: Dictionary=environment.source.duplicate(true);value.area.fields.c0=0
	check(environment.source==captured,"Later header mutation cannot alter the detached accepted source")
	observations.append({"oldSource":stable,"newSource":environment.source.duplicate(true),"newRange":environment.range_state.duplicate(true),"nativeHeaderScope":environment.get_meta("native_header_scope").duplicate()})
	old_environment.queue_free();old_world.queue_free();environment.queue_free();world.queue_free();gameplay_ui.queue_free()
	environment=null;world=null;gameplay_ui=null;transition_targets=null;initialized=false
	await process_frame;await process_frame
	var stale_count:=int(report.get("stale_session_messages",0))
	check(not accept_connection({"kind":"raw-world-begin","connection":2}) and int(report.get("stale_session_messages",0))==stale_count+1,"Actual Session boundary rejects a retired connection before any Root helper call")
	check(accept_connection({"kind":"raw-world-begin","connection":3}),"Actual Session boundary retains the current admitted connection")
	cancelled_connection=3
	check(not accept_connection({"kind":"raw-world-begin","connection":3}),"Actual Session boundary rejects canceled connection data")
	cancelled_connection=-1
	check(accept_connection({"kind":"session-reset","connection":4}) and session_connection==4 and epoch==-1 and environment==null,"Actual reconnect boundary resets prior World/environment without opening a session")
	check(not accept_connection({"kind":"raw-world-begin","connection":3}),"Old connection stays rejected after reconnect")
	epoch=7;world=HeaderWorld.new();root.add_child(world);environment=make_environment(world)
	check(publish_area_environment(header(),7) and environment.get_meta("native_header_scope")[0]==4,"New connection may reuse area/generation only through a fresh Environment owner")
	world.retiring=true
	check(not publish_area_environment(header(),7),"Reopened owner also rejects retirement-time input")
	environment.queue_free();world.queue_free();camera.queue_free();environment=null;world=null;camera=null
	await process_frame;await process_frame
	render_pool.clear();catalog=null
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual current NativeSessionWorld admission/NativeLiveWorld full+delta callback and real AreaEnvironment publication/phase/fog, same-clock carry, unchanged suppression, malformed input and exact owner/World/generation/area/connection lifetime. World/UI/source headers controlled; sky selection observed at a passive provider. No renderer startup, model resources, network/server/keys/profiles/GPU, native builds, user processes or pixel/full-clock parity."})+"\n");file.close();print("NATIVE_AREA_ENVIRONMENT_PUBLICATION ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
