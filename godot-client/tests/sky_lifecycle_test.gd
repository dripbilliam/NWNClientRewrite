extends SceneTree
const EnvironmentOwner = preload("res://systems/area_environment.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := "";var fixture := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
		if arg.begins_with("--fixture="): fixture = arg.substr(10)
	if output.is_empty() or fixture.is_empty() or FileAccess.file_exists(output): quit(2); return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var host := Node3D.new();root.add_child(host)
	var camera := Camera3D.new();host.add_child(camera);camera.position = Vector3(0,2,0);camera.current = true
	var owner := EnvironmentOwner.new();owner.configure({},host);host.add_child(owner);owner.camera = camera
	var fields := {"98":0,"9c":0,"a0":0x221133,"a4":0,"a8":false,"b8":0,"bc":0,"c0":0x557799,"c4":0,"c8":false,"d8":false,"dc":false,"e0":1,"104":0,"108":45}
	var state := {"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}
	var failures: Array = [];var retired: Array = [];var observations: Array = []
	for i in 24:
		fields.dc = i%2 == 1
		if not owner.receive({"revision":i+1,"state":state}): failures.append({"iteration":i,"stage":"atmosphere"})
		if not owner.receive_sky(source.skyResources[i%3]): failures.append({"iteration":i,"stage":"sky"});break
		if owner.sky.resources.stats.imports != 5: failures.append({"iteration":i,"stage":"resource-count"})
		retired.append(weakref(owner.sky))
		for model in owner.sky.instances.values(): retired.append(weakref(model))
		camera.position.x += 1;owner.advance(.016)
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		observations.append({"iteration":i,"liveResources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"textureBytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)})
	var empty: Dictionary = source.skyResources[0].duplicate(true);empty.skyId = 0;empty.phases = [];empty.horizon = null;empty.resources = {}
	if not owner.receive_sky(empty): failures.append({"stage":"clear"})
	for i in 6: await process_frame
	var survivors := retired.filter(func(ref):return ref.get_ref() != null).size()
	if survivors: failures.append({"stage":"owner-retirement","survivors":survivors})
	host.free();for i in 3: await process_frame
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty() and observations.size() == 24,"replacements":observations.size(),"originalModelImports":observations.size()*5,"retiredReferences":retired.size(),"survivors":survivors,"observations":observations,"failures":failures,"scope":"Offline native sky/horizon import/render/replacement stress; not whole-world/public stability acceptance or proof of a one-off shutdown crash cause"},"\t"));file.close()
	print("SKY_LIFECYCLE ",observations.size()," replacements; ",survivors," survivors")
	quit(0 if failures.is_empty() and observations.size() == 24 else 1)
