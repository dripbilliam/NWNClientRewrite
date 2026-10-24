extends SceneTree
const Catalog = preload("res://systems/native_data/resource_catalog.gd")
const Assets = preload("res://systems/native_data/asset_service.gd")
const Cache = preload("res://systems/native_data/prepared_cache.gd")
const Pool = preload("res://systems/native_render/resource_pool.gd")
const Instance = preload("res://systems/native_render/model_instance.gd")
const Raster = preload("res://systems/native_data/texture_data.gd")
var checks := 0
var failures: Array = []
var observations := {}
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)
func quad() -> Dictionary:
	var pixels := PackedByteArray([255,0,0,255,0,255,0,255,0,0,255,255,255,255,255,255])
	var raster := {"sha256":Cache.digest(pixels),"value":{"width":2,"height":2,"format":"rgba8","mips":[{"width":2,"height":2,"data":pixels}],"generate_mips":false}}
	var mesh := {"vertices":PackedFloat32Array([-1,-1,0,1,-1,0,1,1,0,-1,1,0]),"normals":PackedFloat32Array([0,0,1,0,0,1,0,0,1,0,0,1]),"uv":[PackedFloat32Array([0,0,1,0,1,1,0,1])],"indices":PackedInt32Array([0,1,2,0,2,3]),"textures":["auth_quadrant"],"diffuse":[1.0,1.0,1.0],"render":true,"shadow":false}
	var part := {"name":"quad","parent":-1,"position":[0.0,0.0,0.0],"orientation":[0.0,0.0,0.0,1.0],"scale":1.0,"alpha":1.0,"selfillum":[0.0,0.0,0.0],"features":[],"mesh":mesh}
	return {"sha256":Cache.digest(var_to_bytes(mesh)),"error":"","value":{"nodes":[part]},"textures":{"auth_quadrant":raster}}
func frame() -> void:
	await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var pair := arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	if DisplayServer.get_name()=="headless": quit(2); return
	root.size = Vector2i(800,600); RenderingServer.set_default_clear_color(Color.BLACK)
	var host := Node3D.new(); root.add_child(host)
	var camera := Camera3D.new(); host.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 3; camera.position = Vector3(0,4,0); camera.look_at(Vector3.ZERO,Vector3.FORWARD); camera.current = true
	var pool := Pool.new(); pool.unshaded = true; pool.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; var authored := quad()
	var first := Instance.new(); var second := Instance.new(); host.add_child(first); host.add_child(second)
	check(first.install(authored,pool) and second.install(authored,pool),"Direct native authored model scene construction succeeds")
	check(is_same(first.meshes[0].mesh,second.meshes[0].mesh) and is_same(first.meshes[0].material_override,second.meshes[0].material_override),"Separate native model instances share immutable mesh/material resources")
	check(not is_same(first.parts[0],second.parts[0]),"Model instances retain private physical part transforms")
	var arrays: Array = first.meshes[0].mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_INDEX]==PackedInt32Array([0,2,1,0,3,2]),"Original CCW faces are converted once to Godot's front-face convention")
	check(arrays[Mesh.ARRAY_TEX_UV]==PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),"Original UV values are retained without a GLB conversion")
	second.position.x = 10
	await frame(); await frame()
	var image := root.get_texture().get_image()
	observations.quadrants = []
	for sample in [[Vector3(-0.5,0,0.5),Color.RED],[Vector3(0.5,0,0.5),Color.GREEN],[Vector3(-0.5,0,-0.5),Color.BLUE],[Vector3(0.5,0,-0.5),Color.WHITE]]:
		var screen: Vector2 = camera.unproject_position(sample[0]); var pixel := image.get_pixelv(Vector2i(screen)); var expected: Color = sample[1]
		observations.quadrants.append({"point":str(sample[0]),"screen":str(screen),"actual":[pixel.r,pixel.g,pixel.b],"expected":[expected.r,expected.g,expected.b]})
		check(Vector3(pixel.r,pixel.g,pixel.b).distance_to(Vector3(expected.r,expected.g,expected.b))<0.08,"Native GPU UV/front-face quadrant: "+str(sample[0]))
	image.save_png(args.report.get_basename()+"-quadrants.png")
	var weak_mesh: WeakRef = weakref(first.meshes[0].mesh)
	first.retire(); await frame()
	check(weak_mesh.get_ref()!=null and is_instance_valid(second.meshes[0]),"Retiring one model preserves another instance's shared resources")
	second.retire(); await frame(); await frame(); pool.clear(); await frame()
	check(weak_mesh.get_ref()==null,"Retiring all instances and clearing the pool releases the native mesh")
	var raster_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-texture-fixture-v1/fixture.json"))
	var raster_pool := Pool.new(); var raster_parser := Raster.new()
	for item in raster_fixture.cases:
		var bytes := FileAccess.get_file_as_bytes(str(raster_fixture.folder).path_join(item.name)); var data: Dictionary = raster_parser.parse(bytes,int(item.type))
		var uploaded := raster_pool.texture({"sha256":Cache.digest(bytes),"value":data})
		check(uploaded!=null and uploaded.get_width()==int(data.width) and uploaded.get_height()==int(data.height),"Native GPU upload preserves raster dimensions: "+str(item.name)+" "+raster_pool.failure)
		if uploaded!=null:
			var uploaded_image: Image = uploaded.get_image(); var top_bytes: PackedByteArray = data.mips[0].data
			if data.format == "etc1":
				var compressed := PackedByteArray()
				for mip in data.mips: compressed.append_array(mip.data)
				var reference := Image.create_from_data(int(data.width),int(data.height),data.mips.size()>1,Image.FORMAT_ETC,compressed)
				check(reference.decompress()==OK,"Native ETC codec produces a desktop upload reference")
				top_bytes = reference.get_data().slice(0,int(data.width)*int(data.height)*4)
			check(uploaded_image.get_data().slice(0,top_bytes.size())==top_bytes,"Native GPU retains original top pixels/blocks: "+str(item.name))
	raster_pool.clear(); await frame()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var catalog := Catalog.new(); check(catalog.mount_install(fixture.install),"Installed original catalog mounts directly in Godot")
	var directory := OS.get_temp_dir().path_join("nwn-native-render-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var service := Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory = directory
	var received: Array = []; service.completed.connect(func(_id,result): received.append(result))
	var started := Time.get_ticks_usec(); service.request("c_golstone",2002,"static-model")
	var deadline := Time.get_ticks_msec()+20000
	while received.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	observations.cold_load_ms = (Time.get_ticks_usec()-started)/1000.0
	check(received.size()==1 and str(received[0].error).is_empty(),"Original model and original texture dependencies prepare natively: "+(str(received[0].error) if not received.is_empty() else "timeout"))
	if not received.is_empty() and str(received[0].error).is_empty():
		var original: Dictionary = received[0]
		observations.cold_worker_ms = original.worker_ms
		observations.cold_phases = {"read_ms":original.read_ms,"model":original.timings,"dependencies":original.dependencies}
		check(int(original.thread)!=OS.get_main_thread_id() and not original.cache_hit,"Cold original model is decoded on a native worker")
		check(not original.textures.is_empty(),"Original bitmap dependencies are present, not substituted")
		started = Time.get_ticks_usec(); service.request("c_golstone",2002,"static-model"); deadline=Time.get_ticks_msec()+20000
		while received.size()<2 and Time.get_ticks_msec()<deadline: await process_frame
		observations.warm_load_ms = (Time.get_ticks_usec()-started)/1000.0
		if received.size()==2:
			observations.warm_worker_ms = received[1].worker_ms
			observations.warm_phases = {"read_ms":received[1].read_ms,"model":received[1].timings,"dependencies":received[1].dependencies}
		check(received.size()==2 and str(received[1].error).is_empty() and received[1].cache_hit and received[1].dependencies.all(func(row):return row.cache_hit),"Warm load reuses checked native disk data for both model and every bitmap")
		var live_pool := Pool.new(); live_pool.unshaded = true
		var live := Instance.new(); host.add_child(live)
		check(live.install(original,live_pool),"Installed original MDL reaches native ArrayMesh/material/texture publication: "+live.failure)
		observations.resources = live_pool.stats.duplicate(); observations.meshes = live.meshes.size(); observations.limitations = live.limitations
		camera.projection=Camera3D.PROJECTION_PERSPECTIVE; camera.position=Vector3(8,6,10); camera.look_at(Vector3(0,2,0)); await frame(); await frame()
		var active := root.get_texture().get_image(); live.hide(); await frame(); var hidden := root.get_texture().get_image(); var pixels := 0
		for y in active.get_height():
			for x in active.get_width():
				if active.get_pixel(x,y)!=hidden.get_pixel(x,y): pixels += 1
		observations.changed_pixels = pixels
		check(pixels>500,"Original model and textures produce actual native Vulkan pixels without JS/Three/glTF")
		active.save_png(args.report.get_basename()+"-original.png")
		live.retire(); await frame(); await frame(); live_pool.clear(); await frame()
	service.close(); check(service.running.is_empty() and service.results.is_empty(),"Native model/texture workers drain at session retirement")
	service.free(); host.free(); await frame(); await frame()
	var sources := {}
	for folder in ["native_data","native_render"]:
		for filename in DirAccess.get_files_at("res://systems/"+folder):
			if filename.ends_with(".gd"): sources[folder+"/"+filename]=FileAccess.get_sha256("res://systems/"+folder+"/"+filename)
	var report := {"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"cache_directory":directory,"sourceSha256":sources,"scope":"Native original-resource/static-model GPU and cache milestone, not full scene/animation/multiplayer or performance acceptance"}
	var file := FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
