extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Rules=preload("res://systems/native_data/native_object_rules.gd")
const Frames=preload("res://systems/native_data/native_network_messages.gd")
const Inflater=preload("res://systems/native_data/native_network_inflater.gd")
const Module=preload("res://systems/native_data/native_module_info.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")
const Roster=preload("res://systems/native_data/native_player_roster.gd")
const Updates=preload("res://systems/native_data/native_object_updates.gd")
const World=preload("res://systems/native_data/native_network_world.gd")
const RenderWorld=preload("res://systems/native_render/live_world_pending_appearances.gd")

func _initialize()->void:call_deferred("run")

func run()->void:
	var path:=ProjectSettings.globalize_path("res://../backups/animations/local-network-character-v5.json")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary:fail("Original world fixture unavailable");return
	var catalog:=Catalog.new()
	if not catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")):fail("Original install catalog unavailable");return
	var tables: Dictionary={}
	for name in ["baseitems","classes","visualeffects","skills"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2017)
		if bytes.is_empty():fail("Original "+name+" table unavailable");return
		tables[name]=Parser.new().parse(bytes.get_string_from_utf8())
	var rules:=Rules.new()
	if not rules.configure(tables):fail("Original object rules unavailable");return
	var world:=World.new();var assembler:=Frames.new();var inflater:=Inflater.new()
	for hex in fixture.transport.applicationFrames:assembler.push(str(hex).hex_decode())
	for row in assembler.drain():
		var decoded: Dictionary=inflater.decode(row.bytes)
		if decoded.has("error"):fail(str(decoded.error));return
		var bytes: PackedByteArray=decoded.bytes
		if bytes.size()<3 or bytes[0]!=80:continue
		var major:=int(bytes[1]);var minor:=int(bytes[2]);var data: Dictionary={}
		if major==3 and minor==1:
			data=Module.decode_packet(bytes,fixture.remote.build)
			if data.has("error") or not world.apply_module(data):fail("Native module state "+str(world.error));return
		elif major==4 and minor==1:
			data=Area.decode_packet(bytes,fixture.remote.build)
			if data.has("error") or not world.apply_area(data):fail("Native area state "+str(world.error));return
		elif major==10 and minor in [1,2,3] or major==5 and minor==2:
			data=Roster.decode_packet(bytes)
			if data.has("error") or not world.apply_roster(data):fail("Native roster state "+str(world.error));return
		elif major==5 and minor==1:
			data=Updates.decode_packet(bytes,fixture.remote.build,rules.providers())
			if data.has("error") or not world.apply_updates(data):fail("Native object state "+str(data.get("error",world.error)));return
	inflater.close()
	var expected: Dictionary=fixture.transport.world;var summary: Dictionary=world.summary()
	for key in ["areaId","objects","entry","time","controls"]:
		if not expected.has(key) or not same(summary[key],expected[key]):fail("Original world summary differs at "+key+": "+str(summary[key])+" / "+str(expected.get(key)));return
	var presentation: Dictionary=world.presentation()
	if presentation.has("error") or presentation.objects.size()!=int(expected.objects):fail("Native renderer handoff is incomplete");return
	var early:=World.new()
	if not early.apply_module(presentation.module) or not early.apply_area({"area":presentation.area,"loadingScreen":presentation.entry.get("loadingScreen",0),"position":presentation.entry.position,"facing":presentation.entry.facing,"flag":presentation.entry.flag}):fail("Native pre-admission area cannot be staged");return
	var pre_admission: Dictionary=early.presentation(true)
	if not early.presentation().has("error") or pre_admission.has("error") or pre_admission.objects.is_empty():fail("Native pre-admission world published a controlled creature or omitted terrain state");return
	if OS.get_cmdline_user_args().has("--render-world"):
		if not await render_presentation(catalog,pre_admission,presentation):return
	print("NWN79 Godot native world state PASS (",summary.objects," objects)")
	quit(0)

func render_presentation(catalog,pre_admission: Dictionary,presentation: Dictionary)->bool:
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	if not catalog.mount_erf(install.path_join("data/nwm/Prelude.nwm"),100000000):fail("Original Prelude module unavailable for Godot renderer");return false
	var host:=Node3D.new();root.add_child(host)
	var render_world:=RenderWorld.new();host.add_child(render_world)
	render_world.minutes_per_hour=int(pre_admission.module.get("minutesPerHour",5))
	render_world.open(catalog,pre_admission.area,1,OS.get_temp_dir().path_join("nwn79-render-handoff-"+str(OS.get_process_id())),null,pre_admission.entry)
	if render_world.closed or not render_world.begin_received_snapshot(pre_admission.objects,int(pre_admission.controlledId)):
		fail("Godot renderer rejected its native pre-admission area");render_world.close();host.queue_free();return false
	var deadline:=Time.get_ticks_msec()+30000
	var result: Dictionary={"done":false}
	while not result.done and Time.get_ticks_msec()<deadline:
		result=render_world.advance_received_snapshot(Time.get_ticks_usec()+3000)
		if not result.done:await process_frame
	while not render_world.ready_for_admission() and Time.get_ticks_msec()<deadline:await process_frame
	if not result.done or not render_world.ready_for_admission() or render_world.ready_for_control():fail("Godot area did not prepare before controlled-creature replication");render_world.close();host.queue_free();return false
	# The cooperative receiver is entry-only. Subsequent admitted full updates
	# use the established live receiver on the same prepared terrain owner.
	render_world.receive(presentation.objects,int(presentation.controlledId))
	var controlled:=int(presentation.controlledId)
	var accepted:=render_world.desired.has(controlled) and render_world.controlled_id==controlled
	if not accepted:fail("Godot renderer did not stage the controlled creature from native packets")
	render_world.close();host.queue_free()
	return accepted

func same(actual: Variant,expected: Variant)->bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size()!=expected.size():return false
		for key in expected:
			if not actual.has(key) or not same(actual[key],expected[key]):return false
		return true
	if actual is Array and expected is Array:
		if actual.size()!=expected.size():return false
		for index in range(actual.size()):
			if not same(actual[index],expected[index]):return false
		return true
	if (actual is int or actual is float or actual is bool) and (expected is int or expected is float or expected is bool):return absf(float(actual)-float(expected))<0.0001
	return actual==expected

func fail(reason: String)->void:
	printerr("NWN79 Godot world state failed: "+reason)
	quit(1)
