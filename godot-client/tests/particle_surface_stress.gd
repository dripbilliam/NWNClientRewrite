extends SceneTree
# Authored bitmap/numbers only. Exercise the actual production surface and
# material factory under repeated growth/replacement; no original game assets.
const Surface = preload("res://systems/particle_surface.gd")
var checks: Array = []
var cycles: Array = []
var retired_refs: Array = []
var material_ids: Dictionary = {}
var material_refs: Array = []
func check(value: bool,label: String) -> void: checks.append({"passed":value,"name":label})
func _initialize() -> void: call_deferred("run")
func buffers(capacity: int) -> Dictionary:
	var positions := PackedByteArray();positions.resize(capacity*12)
	var attributes := PackedByteArray();attributes.resize(capacity*12)
	var corners := [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]
	for index in capacity:
		var q := index/6;var corner: Vector2 = corners[index%6]
		positions.encode_float(index*12,(q%16-7.5)*.12+corner.x*.045)
		positions.encode_float(index*12+4,(q/16%16-7.5)*.12+corner.y*.045)
		positions.encode_float(index*12+8,0)
		attributes.encode_u32(index*12,0x98ffffff)
		attributes.encode_float(index*12+4,(corner.x+1)/2);attributes.encode_float(index*12+8,(corner.y+1)/2)
	return {"positions":positions,"attributes":attributes}

func run() -> void:
	var output := ""
	var verify_capture := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
		if arg == "--verify-exception-capture": verify_capture = true
	if output.is_empty() or FileAccess.file_exists(output): quit(2);return
	# Explicit negative infrastructure test in this authored, owned process.
	# It must never qualify as a completed rendering workload.
	if verify_capture: OS.crash("Owned authored debugger-capture verification");return
	root.size = Vector2i(640,360)
	var world := Node3D.new();root.add_child(world)
	var camera := Camera3D.new();world.add_child(camera);camera.position = Vector3(0,0,4);camera.make_current()
	var light := DirectionalLight3D.new();world.add_child(light)
	var environment := WorldEnvironment.new();environment.environment = Environment.new();environment.environment.background_mode = Environment.BG_COLOR;environment.environment.background_color = Color.BLACK;environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color = Color(.15,.2,.3);world.add_child(environment)
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var packets: Dictionary = {}
	var capacities := [96,192,384,768,1536,3072,6144,12288]
	for capacity in capacities: packets[capacity] = buffers(capacity)
	var total_allocations := 0
	var begun := Time.get_ticks_msec()
	for cycle in 12:
		var surfaces: Array = []
		for index in 24:
			var surface := Surface.new();world.add_child(surface)
			surface.configure(texture,cycle+1,(cycle%4)&1,(cycle%4)&2,true);surfaces.append(surface)
		for step in capacities.size():
			var capacity: int = capacities[step];var packet: Dictionary = packets[capacity]
			for surface in surfaces:
				check(surface.apply_frame(cycle+1,step,capacity,capacity,packet.positions,packet.attributes,AABB(Vector3(-2,-2,-.01),Vector3(4,4,.02))),"Actual lit dynamic surface accepts a larger original-format stream")
				var material: Material = surface.mesh.surface_get_material(0)
				if not material_ids.has(material.get_instance_id()): material_ids[material.get_instance_id()] = true;material_refs.append(weakref(material))
				if step == 0: surface.set_meta("first_material",material.get_instance_id())
				check(material.get_instance_id() == surface.get_meta("first_material"),"Buffer growth retains the same configured material instance")
				total_allocations += 1
			await RenderingServer.frame_post_draw
		var sample := root.get_texture().get_image()
		var lit_pixels := 0
		for y in range(0,360,8):
			for x in range(0,640,8):
				var value := sample.get_pixel(x,y)
				if value.r+value.g+value.b > .03: lit_pixels += 1
		check(lit_pixels > 20,"Real Vulkan readback remains productive after all growth steps")
		for surface in surfaces:
			retired_refs.append(weakref(surface));surface.retire();surface.queue_free()
		surfaces.clear();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		var survivors := retired_refs.filter(func(v):return v.get_ref() != null).size()
		check(survivors == 0,"Every prior-cycle particle surface is destroyed before replacement")
		check(material_refs.all(func(v):return v.get_ref() == null),"Retirement releases every configured material")
		var row := {"cycle":cycle+1,"allocations":total_allocations,"retired":retired_refs.size(),"survivors":survivors,"litPixels":lit_pixels}
		cycles.append(row);print("SURFACE_STRESS_CYCLE ",JSON.stringify(row))
	world.queue_free();await process_frame;await process_frame;await RenderingServer.frame_post_draw
	var result := {"passed":checks.all(func(v):return v.passed),"cycles":cycles,"checks":checks,"allocations":total_allocations,"materialsCreated":material_ids.size(),"materialSurvivors":material_refs.filter(func(v):return v.get_ref() != null).size(),"surfacesRetired":retired_refs.size(),"survivors":retired_refs.filter(func(v):return v.get_ref() != null).size(),"elapsedMs":Time.get_ticks_msec()-begun,"scope":"Authored native Vulkan material/stream growth and owner destruction stress; no original art, gameplay, timing benchmark or heap-fault-cause claim"}
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("PARTICLE_SURFACE_STRESS ",JSON.stringify({"passed":result.passed,"allocations":total_allocations,"survivors":result.survivors}));quit(0 if result.passed else 1)
