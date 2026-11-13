extends SceneTree
# Actual pooled ordinary terrain and existing terrain MultiMesh publication.
# No server, gameplay input, native build, FPS measurement or global mode change.
const Fog=preload("res://systems/native_render/native_tile_fog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Terrain=preload("res://systems/native_render/area_stream.gd")
const Batches=preload("res://systems/native_render/terrain_batches.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
const SurfaceState=preload("res://systems/native_render/native_surface_state.gd")
var checks:=0
var failures: Array=[]
var samples: Array=[]
var report:=""
var folder:=""
class World extends Node3D:
	var terrain
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func bundle() -> Dictionary:
	# Source coordinates are native Z-up; the real pool maps (x,y,z)->(x,z,-y).
	return {"sha256":"native-tile-fog-pixels-flat-quad-v2","resource_name":"fog_pixels","value":{"name":"fog_pixels","nodes":[{"name":"surface","parent":-1,"position":[0,0,0],"orientation":[0,0,0,1],"scale":1.0,"features":[],"flags":33,"alpha":1.0,"selfillum":[0,0,0],"mesh":{"vertices":PackedFloat32Array([-.5,0,-.5,.5,0,-.5,.5,0,.5,-.5,0,.5]),"indices":PackedInt32Array([0,1,2,0,2,3]),"normals":PackedFloat32Array([0,-1,0,0,-1,0,0,-1,0,0,-1,0]),"uv":[],"textures":[],"render":true,"shadow":false,"diffuse":[1,1,1],"ambient":[0,0,0]}}]}}
func capture(name: String) -> Image:
	Palette.flush()
	for frame in 6:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.save_png(folder+"/"+name+".png")
	return image
func expected(scene: Array,factor: float) -> Vector3:
	var selected: Dictionary=Fog.packet(scene,factor)
	var packet: Array=selected.packet
	var amount:=clampf((5.0-float(packet[4]))*float(packet[6]),0,1) if float(packet[7])!=0 else 0.0
	return Vector3(pow(.03,1.0/2.2),pow(.08,1.0/2.2),pow(.15,1.0/2.2)).lerp(Vector3(packet[0],packet[1],packet[2]),amount)
func compare(image: Image,camera: Camera3D,x: float,want: Vector3,label: String) -> void:
	var point:=camera.unproject_position(Vector3(x,0,0));var actual:=image.get_pixel(roundi(point.x),roundi(point.y));var error:=0.0
	for axis in 3:error=maxf(error,absf(actual[axis]-want[axis]))
	check(error<.012,label+" max_error="+str(error))
	samples.append({"label":label,"actual":[actual.r,actual.g,actual.b],"expected":[want.x,want.y,want.z],"max_error":error})
func run() -> void:
	var screen:=-1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--expected-screen="):screen=int(arg.substr(18))
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	folder=report.get_base_dir()
	check(DisplayServer.get_name()!="headless" and screen>=0 and screen<DisplayServer.get_screen_count() and screen!=DisplayServer.get_primary_screen() and DisplayServer.window_get_current_screen()==screen,"Actual GPU fixture starts on explicit nonprimary screen")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE and root.unfocusable,"Fixture does not capture the mouse or request focus")
	if not failures.is_empty():finish();return
	root.size=Vector2i(480,288)
	var world:=World.new();root.add_child(world);world.terrain=Terrain.new();world.add_child(world.terrain);world.terrain.set_process(false)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;world.add_child(environment)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3;camera.make_current()
	var gamma:=Gamma.new();world.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true)
	var pool:=Pool.new();pool.native_lighting=true;pool.native_surface_output=true
	var template=pool.model_template(bundle());check(template!=null and pool.failure.is_empty(),"Actual pooled native terrain quad prepares")
	if template==null:world.free();finish();return
	Palette.ambient(Vector3.ZERO)
	var scope: Array=[7,8,9];var valid:={"current":true};var guard:=func(value):return value==scope and valid.current
	var ordinary=template.create();world.terrain.add_child(ordinary);ordinary.position=Vector3(-1,0,0);world.terrain.instances[0]=ordinary
	var fog:=Fog.new();fog.configure(world,scope,1,"constructor",0,guard);check(fog.model_ready(0,ordinary).available,"Actual ordinary tile publication binds native instance uniform")
	var batcher:=Batches.new();world.terrain.add_child(batcher)
	var prepared: Dictionary=batcher.prepare(bundle(),pool,[{"index":0,"position":Vector3(1,0,0),"rotation_y":0.0,"model":"fog_pixels"},{"index":1,"position":Vector3(2,0,0),"rotation_y":0.0,"model":"fog_pixels"}])
	check(not prepared.is_empty() and prepared.groups.size()==1,"Actual terrain group batches two separate native tile IDs")
	for group in prepared.get("groups",[]):batcher.publish(group)
	var material=ordinary.meshes[0].material_override;material.native_world_fog=false;material.set_shader_parameter("native_emission_enabled",true);material.set_shader_parameter("native_emission",Vector3(.03,.08,.15))
	var mesh=ordinary.meshes[0].mesh;var base_alpha: float=material.albedo_color.a
	check(batcher.owners.size()==1 and batcher.owners[0] is MultiMeshInstance3D and batcher.owners[0].material_override==material,"Ordinary and real MultiMesh genuinely share immutable native material")
	if batcher.owners.is_empty():world.terrain.instances.clear();ordinary.retire();pool.clear();world.terrain.closed=true;world.free();finish();return
	var data: MultiMesh=batcher.owners[0].multimesh
	var scene: Array=[.7,.4,.2,0.0,1.0,16.0,0.0,0.0]
	material.set_shader_parameter("native_surface_fog_color",Vector3(scene[0],scene[1],scene[2]));material.set_shader_parameter("native_surface_fog_range",Vector2(scene[4],scene[5]));material.set_shader_parameter("native_surface_fog_params",Vector3.ZERO)
	var image:=await capture("baseline-default-one")
	compare(image,camera,-1,expected(scene,1),"Ordinary default1 preserves existing unfogged native surface")
	compare(image,camera,1,expected(scene,1),"Batched default1 preserves existing unfogged native surface")
	check(data.get_instance_custom_data(0)==Color(1,1,0,0) and data.get_instance_custom_data(1)==Color(1,1,0,0),"Real renderer reads per-slot default1 custom data")
	for factor in [0.0,0.5]:
		fog.receive({"tile_index":0,"fogged":true});fog.receive({"tile_index":0,"fogged":false})
		if factor!=0:fog.advance_collected([0],factor/4.0)
		batcher.set_native_tile_fog(0,factor)
		image=await capture("forced-disabled-scene-"+str(int(factor*10)))
		compare(image,camera,-1,expected(scene,factor),"Ordinary forcefog raw math with ordinary fog disabled factor"+str(factor))
		compare(image,camera,1,expected(scene,factor),"Actual MultiMesh forcefog raw math with ordinary fog disabled factor"+str(factor))
		compare(image,camera,2,expected(scene,1),"Adjacent batch slot stays at1 after another tile changes")
		check(data.get_instance_custom_data(0)==Color(factor,1,0,0) and data.get_instance_custom_data(1)==Color(1,1,0,0),"Real renderer reads only changed native custom-data slot factor"+str(factor))
	# Ordinary enabled fog remains authoritative for settled factor1.
	scene[6]=1.0/(scene[5]-scene[4]);scene[7]=3.0;material.set_shader_parameter("native_surface_fog_params",Vector3(1,scene[4],scene[6]))
	fog.advance_collected([0],1);batcher.set_native_tile_fog(0,1)
	image=await capture("ordinary-enabled-restored")
	compare(image,camera,-1,expected(scene,1),"Settled ordinary tile returns to original enabled scene fog")
	compare(image,camera,1,expected(scene,1),"Settled batch tile returns to original enabled scene fog")
	SurfaceState.bind(world);material.native_world_fog=true;scene[6]=0.0;scene[7]=0.0
	check(SurfaceState.publish(world,Vector3(scene[0],scene[1],scene[2]),false,scene[4],scene[5]),"Actual world fog owner retains raw range while ordinary scene fog disabled")
	for factor in [0.0,0.5,1.0]:
		fog.receive({"tile_index":0,"fogged":true});fog.receive({"tile_index":0,"fogged":false})
		if factor!=0:fog.advance_collected([0],factor/4.0)
		batcher.set_native_tile_fog(0,factor)
		image=await capture("global-disabled-scene-"+str(int(factor*10)))
		compare(image,camera,-1,expected(scene,factor),"Actual global world fog ordinary factor"+str(factor))
		compare(image,camera,1,expected(scene,factor),"Actual global world fog batched factor"+str(factor))
	SurfaceState.retire(world)
	check(ordinary.meshes[0].material_override==material and ordinary.meshes[0].mesh==mesh and material.albedo_color.a==base_alpha,"Actual pixel changes preserve native material identity, geometry and opacity")
	var gamma_state: Dictionary=gamma.snapshot();check(gamma_state.failure.is_empty() and gamma_state.passes>0,"Actual native output compositor executes on RD GPU")
	valid.current=false;fog.close();batcher.close();world.terrain.instances.clear();ordinary.retire();pool.clear();world.terrain.closed=true;world.free()
	for frame in 3:await process_frame
	finish()
func finish() -> void:
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Real GPU pooled ordinary and existing MultiMesh terrain use exact recovered TileData draw-fog formulas. Original disabled/enabled fog, native-gamma output, default1, factors0/.5, adjacent-slot isolation and physical publication. No live server or FPS acceptance."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_TILE_FOG_PIXELS ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
