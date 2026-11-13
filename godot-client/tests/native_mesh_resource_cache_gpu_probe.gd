extends SceneTree
const Codec=preload("res://systems/native_render/native_mesh_resource_cache.gd")
const Store=preload("res://systems/native_data/prepared_resource_store.gd")
var checks:=0
var failures: Array=[]
var measurements: Array=[]
var scope: Node3D
var geometry: MeshInstance3D
var camera: Camera3D
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func grid(triangles: int) -> Dictionary:
	var columns:=ceili(sqrt(float(triangles)));var count:=triangles*3
	var positions:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array();var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
	positions.resize(count);normals.resize(count);uv.resize(count);colors.resize(count);indices.resize(count);bones.resize(count*4);weights.resize(count*4)
	for triangle in triangles:
		var x:=float(triangle%columns)*0.4;var z:=-float(triangle/columns)*0.4
		for corner in 3:
			var index:=triangle*3+corner
			positions[index]=Vector3(x+(0.35 if corner==1 else 0.0),0,z-(0.35 if corner==2 else 0.0))
			normals[index]=Vector3(float(index%3)*0.1,1.0,float(index%5)*0.03).normalized();uv[index]=Vector2(float(index%7)/6.0,float(index%11)/10.0);colors[index]=Color(float(index%13)/12.0,float(index%17)/16.0,float(index%19)/18.0,1)
			for bone in 4:bones[index*4+bone]=bone;weights[index*4+bone]=0.25
		indices[triangle*3]=triangle*3;indices[triangle*3+1]=triangle*3+2;indices[triangle*3+2]=triangle*3+1
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices;arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
	return {"arrays":arrays,"side":float(columns)*0.4,"vertices":count}
func drain(codec) -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		codec.poll(8,0.75)
		if codec.reads.is_empty() and codec.writes.is_empty():return true
		await process_frame
	return false
func image() -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	var report:="";var cache_root:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--cache-root="):cache_root=arg.substr(13)
	if report.is_empty() or cache_root.is_empty() or FileAccess.file_exists(report):quit(2);return
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	check(RenderingServer.get_current_rendering_method()=="forward_plus" and RenderingServer.get_current_rendering_driver_name()=="vulkan","Actual GPU codec probe uses Vulkan Forward+")
	check(DisplayServer.window_get_current_screen()!=DisplayServer.get_primary_screen() and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"GPU probe preserves secondary/unfocused/visible-mouse policy")
	scope=Node3D.new();root.add_child(scope);camera=Camera3D.new();scope.add_child(camera);camera.current=true;geometry=MeshInstance3D.new();scope.add_child(geometry)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true;geometry.material_override=material
	var store:=Store.new();check(store.configure(cache_root),"Actual resource store configures with default25GiB budget")
	for triangles in [100,5000,30000]:
		var input:=grid(triangles);var began:=Time.get_ticks_usec();var source:=ArrayMesh.new();source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,input.arrays);var legacy_us:=Time.get_ticks_usec()-began
		source.set_meta("native_pick_geometry",Resource.new());source.set_meta("test_original_metadata",17)
		geometry.mesh=source;var center:=Vector3(input.side*0.5,0,-input.side*0.5);camera.position=center+Vector3(0,input.side*1.3,input.side*1.0);camera.look_at(center)
		var original_image: Image=await image();original_image.save_png(report.get_basename()+"."+str(triangles)+".original.png")
		began=Time.get_ticks_usec();var surfaces: Array=source.get("_surfaces");var get_us:=Time.get_ticks_usec()-began
		var original_hash:=Codec.digest(var_to_bytes(surfaces))
		for mode in ["packed-buffers","array-mesh"]:
			var codec:=Codec.new();check(codec.configure(store,mode),"GPU codec configures "+mode)
			var key:=Codec.key_for(Codec.digest(var_to_bytes([triangles,"authored-gpu-codec-fixture"])),0,"gpu-probe-v1",{"bones":true},[],mode)
			began=Time.get_ticks_usec();check(codec.queue_save(key,source),"Real GPU buffer save queues "+str(triangles)+"/"+mode);var queue_save_us:=Time.get_ticks_usec()-began
			check(await drain(codec),"Real GPU buffer save/publication settles");var save_elapsed_us:=Time.get_ticks_usec()-began
			var path:=store.lookup(key);var file:=FileAccess.open(path,FileAccess.READ);var bytes:=file.get_length();file.close()
			began=Time.get_ticks_usec();check(codec.prefetch(key)=="loading","Real GPU prefetch starts on worker");var prefetch_us:=Time.get_ticks_usec()-began
			check(await drain(codec) and codec.state(key)=="ready","Actual threaded ready resource arrives");var ready_elapsed_us:=Time.get_ticks_usec()-began
			began=Time.get_ticks_usec();var loaded:=codec.take_ready(key);var take_us:=Time.get_ticks_usec()-began
			check(loaded!=null and Codec.pure_mesh(loaded),"Real GPU resource is pure builtin ArrayMesh")
			if loaded!=null:
				var result_surfaces: Array=loaded.get("_surfaces")
				check(Codec.digest(var_to_bytes(result_surfaces))==original_hash,"Actual native packed vertex/normal/UV/color/index/bone/weight buffers roundtrip byte-exact")
				check(loaded.surface_get_arrays(0)==source.surface_get_arrays(0),"Actual Vulkan decoded arrays match all source channels")
				geometry.mesh=loaded;began=Time.get_ticks_usec();var loaded_image: Image=await image();var render_boundary_us:=Time.get_ticks_usec()-began
				loaded_image.save_png(report.get_basename()+"."+str(triangles)+"."+mode+".png")
				check(original_image.get_data()==loaded_image.get_data(),"Original/cached real GPU images are byte-identical "+str(triangles)+"/"+mode)
				check(source.get_meta("test_original_metadata")==17 and source.has_meta("native_pick_geometry"),"Original collision/metadata remains independent")
				measurements.append({"triangles":triangles,"vertices":input.vertices,"mode":mode,"artifact_bytes":bytes,"legacy_add_surface_submit_cpu_us":legacy_us,"source_get_surfaces_cpu_us":get_us,"queue_save_cpu_us":queue_save_us,"save_elapsed_us":save_elapsed_us,"prefetch_queue_cpu_us":prefetch_us,"prefetch_ready_elapsed_us":ready_elapsed_us,"take_cpu_us":take_us,"post_take_render_boundary_us":render_boundary_us,"byte_identical_image":original_image.get_data()==loaded_image.get_data(),"codec":codec.snapshot(),"scope":"One authored sample; CPU submission and scheduling, not GPU duration or clean FPS"})
			check(codec.close(),"GPU codec closes with all leases/tasks drained")
			geometry.mesh=source
	geometry.mesh=null;scope.free();await process_frame;check(store.close(),"GPU resource store closes with no outstanding tickets")
	var output:=FileAccess.open(report,FileAccess.WRITE);output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"actual_renderer":RenderingServer.get_current_rendering_method(),"actual_driver":RenderingServer.get_current_rendering_driver_name(),"measurements":measurements,"scope":"Actual Vulkan native-buffer/array/image fidelity with100/5000/30000triangle authored meshes, both resource codecs and legacy constructor; not original captured asset or representative performance acceptance"},"\t")+"\n");output.close();print("NATIVE_MESH_RESOURCE_CACHE_GPU ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
