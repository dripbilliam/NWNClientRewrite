extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const World=preload("res://systems/native_render/live_world.gd")
const SkyOwner=preload("res://systems/native_render/sky_world.gd")
const Area=preload("res://systems/area_environment.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
const Parser=preload("res://systems/native_data/binary_model.gd")
var checks: Array=[]
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks.append({"passed":value,"name":label})
	if not value: failures.append(label)
func wait_sky(sky,id: int) -> bool:
	var deadline:=Time.get_ticks_msec()+20000
	while sky.sky_id!=id or not sky.configured:
		if not sky.error.is_empty() or Time.get_ticks_msec()>deadline: return false
		await process_frame
	for n in 3: await process_frame
	return true
func pixel() -> Color:
	for n in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image(); return image.get_pixel(image.get_width()/2,image.get_height()/2)
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256); var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original catalog mounts read-only")
	var native_output:=OS.get_cmdline_user_args().has("--native-sky-output=true")
	var world:=World.new(); world.set_meta("native_surface_output",native_output); root.add_child(world); world.set_process(false)
	var sky:=SkyOwner.new(); world.add_child(sky); sky.configure(world,catalog,world.pool); world.native_sky=sky; world.set_meta("native_sky_owner",sky)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,2,0); camera.current=true; camera.far=135
	var area:=Area.new(); world.add_child(area); area.configure({},world); area.camera=camera; area.set_process(false)
	var gamma:=Gamma.new(); world.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(native_output)
	var fields:={"98":0,"9c":0,"a0":0x223344,"a4":0,"a8":false,"b8":0,"bc":0,"c0":0x334455,"c4":0,"c8":false,"d8":false,"dc":false,"e0":1,"104":60,"108":45}
	var state:={"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}
	check(area.receive({"revision":1,"state":state}),"Actual area receive triggers native sky selection")
	var ready: bool=await wait_sky(sky,1); check(ready,"Four phase models and horizon finish native worker publication: "+sky.error)
	var color_offsets: Array=[]; var day:=Color.BLACK; var night:=Color.BLACK
	if ready:
		area.advance(0)
		check(sky.phases==["skyda_001","sky_001","skyd_001","skyn_001"] and sky.instances.size()==5,"Physical original SkyBoxes row resolves four original phases plus horizon")
		var programs: Dictionary={}
		for name in sky.instances:
			var triangles:=0
			for row in sky.materials[name]:
				triangles+=row.mesh.mesh.surface_get_array_index_len(0)/3; programs[row.base.shader.get_instance_id()]=true
				check(row.mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and row.base.get_shader_parameter("horizon")==bool(name=="skyfade1"),"Original sky/horizon stays outside world lighting/shadow passes: "+name)
			check(triangles==112 if name=="skyfade1" else triangles==160,"Actual native sky geometry retains original triangle count: "+name)
			var bytes: PackedByteArray=catalog.get_resource(name,2002); var parser:=Parser.new(); parser.parse(bytes)
			var color_surface:=0
			for offset in parser.visited:
				var at: int=12+int(offset); var flags:=bytes.decode_u32(at+108)
				if flags&32:
					var mesh: int=at+112+(92 if flags&2 else 0)+(216 if flags&4 else 0)+(68 if flags&16 else 0)
					var color_offset:=bytes.decode_u32(mesh+472); var count:=bytes.decode_u16(mesh+448)
					color_offsets.append({"model":name,"offset":color_offset})
					if count>0 and bytes.decode_u32(mesh+108)==1:
						if color_offset!=0xffffffff:
							var actual_colors: PackedColorArray=sky.materials[name][color_surface].mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
							var exact: bool=actual_colors.size()==count
							for vertex in mini(actual_colors.size(),count):
								for c in 4: exact=exact and absf(actual_colors[vertex][c]*255-bytes[12+bytes.decode_u32(4)+color_offset+vertex*4+c])<.0001
							check(exact and sky.materials[name][color_surface].base.get_shader_parameter("vertex_tint"),"Original normalized RGBA bytes survive worker preparation and ArrayMesh upload: "+name+"/"+str(color_surface))
						color_surface+=1
		check(programs.size()==1 and sky.snapshot().glb_imports==0 and sky.snapshot().table_reads==1,"All native phases share one shader and use zero GLB imports")
		day=await pixel(); fields.dc=true; area.receive({"revision":2,"state":state}); area.advance(0); night=await pixel()
		check(Vector3(day.r,day.g,day.b).length()>.03 and Vector3(day.r-night.r,day.g-night.g,day.b-night.b).length()>.02,"Actual original day/night models reach distinct GPU pixels")
		camera.position=Vector3(40,15,20); area.advance(0); check(sky.global_position==camera.global_position,"Native sky remains camera-centered independently of area coordinates")
		var identity: int=sky.instances[sky.phases[0]].get_instance_id(); sky.select_sky(255)
		for n in 6: await process_frame
		check(not sky.error.is_empty() and sky.instances[sky.phases[0]].get_instance_id()==identity,"Invalid replacement row preserves preceding working native sky")
		sky.select_sky(6); check(await wait_sky(sky,6),"A second native sky loads without repeating table I/O: "+sky.error)
		area.advance(0); check(sky.instances.size()==2 and sky.phases==["skybl_001","skybl_001","skybl_001","skybl_001"],"Repeated original phases share one physical sky model and retain horizon")
		sky.select_sky(1); sky.select_sky(0)
		for n in 20: await process_frame
		check(sky.instances.is_empty() and sky.configured and sky.sky_id==0,"No-sky admission rejects late jobs and releases previous phase/horizon nodes")
	# The active catalog's physical row order wins even when labels differ.
	var directory:=OS.get_cache_dir().path_join("nwn-native-sky-"+str(OS.get_process_id())); DirAccess.make_dir_recursive_absolute(directory)
	var table_path:=directory.path_join("skyboxes.2da"); var file:=FileAccess.open(table_path,FileAccess.WRITE)
	file.store_string("2DA V2.0\n\nDAWN DAY DUSK NIGHT\n99 **** **** **** ****\n77 skybl_001 skybl_001 skybl_001 skybl_001\n"); file.close()
	var override_catalog:=catalog.fork(); check(override_catalog.mount_directory(directory),"Generic catalog admits a local sky table override")
	var other:=SkyOwner.new(); world.add_child(other); other.configure(world,override_catalog,world.pool); other.select_sky(1)
	check(await wait_sky(other,1),"Overridden sky table loads through native workers: "+other.error)
	check(other.phases==["skybl_001","skybl_001","skybl_001","skybl_001"] and other.instances.size()==2,"Physical row selection honors server-style override rather than numeric row label")
	other.select_sky(2); other.stop()
	for n in 5: await process_frame
	check(other.closed,"Retiring world stops pending native sky admission")
	other.close(); check(other.assets.running.is_empty(),"Native sky close joins all owned workers"); other.free()
	DirAccess.remove_absolute(table_path); DirAccess.remove_absolute(directory)
	var final_state:=sky.snapshot(); world.close(); check(sky.assets.running.is_empty(),"World lifetime closes native sky workers"); world.free()
	for n in 3: await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"native_surface_output":native_output,"sky":final_state,"day":[day.r,day.g,day.b],"night":[night.r,night.g,night.b],"serialized_color_offsets":color_offsets,"publicConnections":0,"scope":"Actual native catalog/2DA worker/MDL/texture/GPU sky and horizon, original physical row override, phase deduplication, camera anchoring, no-sky/cancellation and world retirement. Ordinary and explicit native output modes are separately run; no matched-room acceptance."}
	file=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
