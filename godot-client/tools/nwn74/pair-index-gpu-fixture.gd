extends SceneTree

# Same private engine OFF/ON fixture. Pixels and public cull names compare
# across runs; render-thread counts prove engagement. This is synthetic and
# cannot establish an original-scene speedup.
var report_file: String
var failures: Array[String]=[]
var checks:=0
var viewport: SubViewport
var second_viewport: SubViewport
var world: Node3D
var second_world: Node3D
var camera: Camera3D
var boxes: Array[MeshInstance3D]=[]
var lights: Array[OmniLight3D]=[]
var named_nodes: Array[Node3D]=[]
var steps: Array[Dictionary]=[]
var last_probe_id:=-1

func _initialize() -> void:
	call_deferred("run")

func check(okay: bool, label: String) -> void:
	checks+=1
	if not okay:
		failures.append(label)
		push_error(label)

func sha_bytes(data: PackedByteArray) -> String:
	var context:=HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func make_viewport(label: String) -> SubViewport:
	var value:=SubViewport.new()
	value.name=label
	value.size=Vector2i(640,480)
	value.own_world_3d=true
	value.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	value.positional_shadow_atlas_size=2048
	root.add_child(value)
	return value

func build() -> void:
	viewport=make_viewport("MainView")
	world=Node3D.new()
	world.name="MainWorld"
	viewport.add_child(world)
	var env_node:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.1,0.12,0.16)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.65,0.72,0.8)
	env.ambient_light_energy=0.35
	env_node.environment=env
	world.add_child(env_node)
	camera=Camera3D.new()
	camera.position=Vector3(15,23,28)
	camera.fov=52
	world.add_child(camera)
	camera.look_at(Vector3(0,0,0),Vector3.UP)
	camera.current=true
	var floor:=MeshInstance3D.new()
	floor.name="Floor"
	var plane:=PlaneMesh.new()
	plane.size=Vector2(42,42)
	floor.mesh=plane
	var floor_material:=StandardMaterial3D.new()
	floor_material.albedo_color=Color(0.38,0.39,0.42)
	floor.material_override=floor_material
	world.add_child(floor)
	named_nodes.append(floor)
	for index in 64:
		var box:=MeshInstance3D.new()
		box.name="Box%02d" % index
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(1.2,2.0,1.2)
		box.mesh=mesh
		box.position=Vector3((index%8-3.5)*4,1.0,(index/8-3.5)*4)
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color.from_hsv(float(index%8)/8.0,0.55,0.75)
		box.material_override=material
		world.add_child(box)
		boxes.append(box)
		named_nodes.append(box)
	for index in 48:
		var light:=OmniLight3D.new()
		light.name="Light%02d" % index
		light.position=Vector3((index%8-3.5)*4,5.0,(index/8-2.5)*5)
		light.omni_range=5.0
		light.light_energy=0.8
		light.light_color=Color.from_hsv(float(index%6)/6.0,0.4,1.0)
		light.shadow_enabled=index%11==0
		world.add_child(light)
		lights.append(light)
		named_nodes.append(light)
	var sun:=DirectionalLight3D.new()
	sun.name="Sun"
	sun.light_energy=0.7
	sun.shadow_enabled=true
	sun.rotation_degrees=Vector3(-55,-20,0)
	world.add_child(sun)
	named_nodes.append(sun)
	second_viewport=make_viewport("OtherView")
	second_world=Node3D.new()
	second_world.name="OtherWorld"
	second_viewport.add_child(second_world)
	var other_camera:=Camera3D.new()
	other_camera.position=Vector3(0,8,14)
	second_world.add_child(other_camera)
	other_camera.look_at(Vector3.ZERO,Vector3.UP)
	other_camera.current=true

func public_cull_names() -> Array[String]:
	var by_id: Dictionary={}
	for node in named_nodes:
		if is_instance_valid(node): by_id[node.get_instance_id()]=node.name
	var found: Array[String]=[]
	for object_id in RenderingServer.instances_cull_aabb(AABB(Vector3(-200,-100,-200),Vector3(400,200,400)),world.get_world_3d().scenario):
		found.append(str(by_id.get(int(object_id),"unknown")))
	found.sort()
	return found

func snap(label: String) -> void:
	var totals:={"pair_query_visits":0,"pair_matches":0,"light_pair_candidates":0,"light_pair_kept":0,"light_pair_excluded":0,"pair_repair_us":0,"dirty_drain_setup_us":0}
	var observed_frames:=0
	for ignored in 8:
		await process_frame
		await RenderingServer.frame_post_draw
		var completed: Dictionary=ClassDB.class_call_static("NwnFrameProbe","completed_frame")
		var frame_id:=int(completed.get("frame_id",-1))
		if bool(completed.get("available",false)) and frame_id>last_probe_id:
			last_probe_id=frame_id
			observed_frames+=1
			for key in totals: totals[key]=int(totals[key])+int(completed.get(key,0))
	check(observed_frames>0,label+" render frames")
	var image:=viewport.get_texture().get_image()
	check(image!=null and image.get_width()==640 and image.get_height()==480,label+" image")
	if image==null: return
	var bytes:=image.get_data()
	var png:=report_file.trim_suffix(".json")+"-"+label+".png"
	check(image.save_png(png)==OK,label+" png")
	var names:=public_cull_names()
	check(not names.is_empty(),label+" public cull")
	steps.append({"label":label,"pixel_sha256":sha_bytes(bytes),"png":png,"visible_names":names,"probe":{"last_frame_id":last_probe_id,"observed_frames":observed_frames,"totals":totals}})

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): report_file=argument.substr(9)
	check(not report_file.is_empty(),"explicit report path")
	check(ClassDB.class_exists("NwnFrameProbe"),"private frame probe")
	if report_file.is_empty() or not ClassDB.class_exists("NwnFrameProbe"):
		quit(1)
		return
	ClassDB.class_call_static("NwnFrameProbe","set_enabled",true)
	build()
	await snap("initial")
	boxes[8].position=Vector3(3,1,1)
	await snap("geometry_move_first")
	lights[0].position=Vector3(3,5,1)
	await snap("light_move_second")
	lights[1].shadow_enabled=true
	await snap("consumer_enable")
	lights[0].shadow_enabled=false
	await snap("consumer_disable")
	boxes[8].layers=2
	lights[1].light_cull_mask=2
	await snap("layer_mask")
	lights[3].visible=false
	await snap("light_hidden")
	lights[3].visible=true
	await snap("light_shown")
	var retired:=lights.pop_back()
	named_nodes.erase(retired)
	retired.queue_free()
	await snap("light_retired")
	boxes[9].reparent(second_world)
	await snap("scenario_detach")
	boxes[9].reparent(world)
	await snap("scenario_reinsert")
	var report:={"issue":"NWN-74","scope":"Private synthetic GPU/scene relation parity, not an FPS or original-asset result","checks":checks,"failures":failures,"steps":steps,"pair_index_requested":OS.get_cmdline_user_args().has("--nwn74-pair-index=consumer")}
	var file:=FileAccess.open(report_file,FileAccess.WRITE)
	check(file!=null,"report file")
	if file!=null:
		file.store_string(JSON.stringify(report,"  ")+"\n")
		file.close()
	ClassDB.class_call_static("NwnFrameProbe","set_enabled",false)
	viewport.queue_free()
	second_viewport.queue_free()
	quit(0 if failures.is_empty() else 1)
