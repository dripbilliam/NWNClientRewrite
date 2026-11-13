extends SceneTree
# Local functional regression: real pooled NativeModelMaterial on 4200 physical
# MeshInstance3D owners. Primitive triangles deliberately keep pixel work small.
# No server, gameplay input, native build or FPS measurement.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Surface=preload("res://systems/native_render/native_surface_state.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
const COUNT:=4200
const COLUMNS:=70
const ROWS:=60
var checks:=0
var failures: Array=[]
var report:=""
var mode:=""
var captures: Array=[]
var samples: Array=[]
var observations: Dictionary={}
var world: Node3D
var camera: Camera3D
var gamma
var pool
var shared_mesh: ArrayMesh
var opaque
var ghost
var nodes: Array=[]
var reference: Array=[]
var identities: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:
	if DisplayServer.get_name()!="headless":
		for index in DisplayServer.get_screen_count():
			if index!=DisplayServer.get_primary_screen():root.current_screen=index;break
	run.call_deferred()
func location(index: int) -> Vector3:
	return Vector3(float(index%COLUMNS)-34.5,float(floori(float(index)/float(COLUMNS)))-29.5,0)
func point(index: int) -> Vector2i:
	var projected:=camera.unproject_position(location(index)+Vector3(0,-.08,0))
	return Vector2i(roundi(projected.x),roundi(projected.y))
func material_for(index: int):return opaque if index%2==0 else ghost
func publish(index: int) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.name="PhysicalNativeSurface"+str(index);node.mesh=shared_mesh;node.material_override=material_for(index);node.position=location(index);world.add_child(node);return node
func identity(node: MeshInstance3D) -> Array:
	return [str(node.get_instance_id()),str(node.mesh.get_instance_id()),str(node.material_override.get_instance_id()),str(node.material_override.shader.get_instance_id())]
func alpha_stable() -> bool:
	return opaque.albedo_color.a==1. and ghost.albedo_color.a==.5 and opaque.get_shader_parameter("native_alpha")==1. and ghost.get_shader_parameter("native_alpha")==.5
func physical_stable(skip: int=-1) -> bool:
	if nodes.size()!=COUNT:return false
	for index in COUNT:
		if index==skip:continue
		var node: MeshInstance3D=nodes[index]
		if not is_instance_valid(node) or not node.is_inside_tree() or identity(node)!=identities[index] or node.mesh!=shared_mesh or node.material_override!=material_for(index):return false
	return alpha_stable()
func distance(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func pixel(image: Image,index: int) -> Color:
	var at:=point(index);return image.get_pixel(at.x,at.y)
func capture(label: String) -> Image:
	Palette.flush()
	for frame in 7:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image();var file:=report.trim_suffix(".json")+"-"+label+".png"
	check(image.save_png(file)==OK,"Saved actual GPU pixels "+label);captures.append(file);return image
func inspect(image: Image,label: String,skip: int=-1) -> Dictionary:
	var matched:=0;var black:=0;var maximum:=0.;var failed: Array=[]
	for index in nodes.size():
		if index==skip:continue
		var actual:=pixel(image,index);var difference:=distance(actual,reference[index%2]);maximum=maxf(maximum,difference)
		if difference<.012:matched+=1
		else:
			if failed.size()<20:failed.append({"index":index,"pixel":point(index),"actual":[actual.r,actual.g,actual.b],"reference":[reference[index%2].r,reference[index%2].g,reference[index%2].b],"error":difference})
		if maxf(actual.r,maxf(actual.g,actual.b))<.015:black+=1
	var result:={"label":label,"sampled":nodes.size()-(1 if skip>=0 else 0),"matched_reference":matched,"black":black,"maximum_error":maximum,"first_mismatches":failed};samples.append(result);return result
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		elif arg.begins_with("--case="):mode=arg.substr(7)
	if report.is_empty() or FileAccess.file_exists(report) or mode not in ["baseline","candidate"]:quit(2);return
	check(DisplayServer.get_name()!="headless" and root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Graphical regression remains on nonprimary monitor unfocused with pointer visible")
	if not failures.is_empty():finish();return
	root.size=Vector2i(1008,864);root.msaa_3d=Viewport.MSAA_DISABLED
	world=Node3D.new();root.add_child(world);world.add_child(Palette.new());Surface.bind(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.BLACK;environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR;world.add_child(environment)
	camera=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,10);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=60.;camera.make_current()
	gamma=Gamma.new();world.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true);gamma.set_gamma(1.2)
	Palette.ambient(Vector3.ZERO);Palette.environment(null)
	check(Surface.publish(world,Vector3(.7,.4,.2),false,1.,16.),"Actual native world owner publishes disabled ordinary fog with retained source range")
	pool=Pool.new();pool.native_lighting=true;pool.native_standard=true;pool.native_surface_output=true
	var part: Dictionary={"alpha":1.,"selfillum":[.2,.3,.4],"mesh":{"diffuse":[1.,1.,1.],"ambient":[0.,0.,0.]}}
	opaque=pool.material(part);part.alpha=.5;ghost=pool.material(part)
	check(opaque is NativeMaterial and ghost is NativeMaterial and opaque!=ghost and opaque.get_meta("native_surface_output",false) and ghost.get_meta("native_surface_output",false),"Actual ResourcePool factory returns distinct original native-surface opaque and translucent materials")
	var instance_declaration: bool=opaque.shader.code.contains("instance uniform float nwn_tile_fog_factor")
	check(instance_declaration==(mode=="baseline"),"Exact baseline/candidate shader carrier has expected per-instance fog allocation contract")
	if mode=="candidate":check(opaque.native_tile_fog_enabled==false and ghost.native_tile_fog_enabled==false,"New default does not activate parked ordinary instance-fog carrier")
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.34,-.34,0),Vector3(0,.34,0),Vector3(.34,-.34,0)]);arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.BACK,Vector3.BACK,Vector3.BACK]);shared_mesh=ArrayMesh.new();shared_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	nodes.append(publish(0));nodes.append(publish(1));var calibration:=await capture("calibration-two-original-materials")
	reference=[pixel(calibration,0),pixel(calibration,1)]
	check(reference[0].b>.04 and reference[1].b>.02 and distance(reference[0],reference[1])>.01,"Actual opaque/translucent calibration pixels carry nonblack distinguishable native emission")
	for index in range(2,COUNT):nodes.append(publish(index))
	for node in nodes:identities.append(identity(node))
	check(nodes.size()==COUNT and physical_stable(),"All4200 physical MeshInstance owners share exact triangle geometry and retained native materials/alpha")
	var large:=await capture("large-scene-no-highlight");var grid: Dictionary=inspect(large,"large-scene")
	check(physical_stable(),"Publishing large scene retains every exact physical mesh/material/shader owner and alpha")
	if mode=="baseline":
		if int(ProjectSettings.get_setting("rendering/limits/global_shader_variables/buffer_size"))==65536:
			check(grid.matched_reference<COUNT and grid.black>0,"Unchanged V6 baseline reproduces actual black output under large-scene instance-uniform allocation pressure")
		else:
			check(grid.matched_reference==COUNT and grid.black==0,"Explicit larger-buffer baseline control restores all4200 real physical mesh pixels without changing the material carrier")
	else:
		check(grid.matched_reference==COUNT and grid.black==0,"Candidate renders every one of4200 actual physical mesh owners with correct calibrated pixels")
		var target:=COUNT-2;var old_material=nodes[target].material_override;var old_mesh=nodes[target].mesh
		var source:=StandardMaterial3D.new();var opted=NativeMaterial.new();opted.configure(source,[0.,0.,0.],[.2,.3,.4],true,2);opted.native_surface_output=true;opted.native_world_fog=true;opted.set("native_tile_fog_enabled",true)
		check(opted.shader!=opaque.shader and opted.shader.code.contains("instance uniform float nwn_tile_fog_factor"),"Explicit opt-in creates genuine old instance-fog carrier with separate shared shader cache identity")
		nodes[target].material_override=opted;nodes[target].set_instance_shader_parameter("nwn_tile_fog_factor",1.)
		var swapped:=await capture("explicit-opt-in-one");check(distance(pixel(swapped,target),reference[0])<.012 and physical_stable(target),"Opt-in material swap preserves target pixels and every other physical owner/alpha")
		nodes[target].set_instance_shader_parameter("nwn_tile_fog_factor",0.);var fogged:=await capture("explicit-opt-in-zero");var dark:=pixel(fogged,target)
		check(maxf(dark.r,maxf(dark.g,dark.b))<.015 and distance(dark,reference[0])>.02,"Explicit opt-in factor0 actually blackens the target GPU pixel")
		check(inspect(fogged,"opt-in-zero-neighbor-isolation",target).matched_reference==COUNT-1 and physical_stable(target),"Explicit per-instance fog leaves all4199 adjacent ordinary/alpha owners unchanged")
		nodes[target].set_instance_shader_parameter("nwn_tile_fog_factor",1.);var restored:=await capture("explicit-opt-in-restored")
		check(distance(pixel(restored,target),reference[0])<.012 and opted.albedo_color.a==1.,"Explicit opt-in factor restoration preserves actual GPU output and original alpha")
		nodes[target].material_override=old_material;nodes[target].set_instance_shader_parameter("nwn_tile_fog_factor",0.);var ordinary:=await capture("swap-back-default-ignores-stale-parameter")
		check(inspect(ordinary,"swap-back-default").matched_reference==COUNT and physical_stable(),"Swapping back to default ignores retained parameter0 without altering shared material or mesh")
		var old_id: int=nodes[target].get_instance_id();nodes[target].free();nodes[target]=null
		var retired:=await capture("retired-physical-owner");check(maxf(pixel(retired,target).r,maxf(pixel(retired,target).g,pixel(retired,target).b))<.015,"Retiring actual physical owner removes its triangle pixels")
		nodes[target]=publish(target);identities[target]=identity(nodes[target]);var recreated:=await capture("recreated-default-owner")
		check(nodes[target].get_instance_id()!=old_id and nodes[target].mesh==old_mesh and nodes[target].material_override==old_material and inspect(recreated,"recreated").matched_reference==COUNT and physical_stable(),"Recreated physical lifetime retains shared geometry/material and all4200 correct pixels without old instance parameter")
		observations.opt_in={"separate_shader":opted.shader!=opaque.shader,"opaque_alpha":opted.albedo_color.a,"old_instance":str(old_id),"new_instance":str(nodes[target].get_instance_id())};opted=null;source=null
	observations.configuration={"buffer_entries":ProjectSettings.get_setting("rendering/limits/global_shader_variables/buffer_size"),"physical_mesh_owners":COUNT,"shared_geometry":str(shared_mesh.get_instance_id()),"native_materials":2,"opaque_material":str(opaque.get_instance_id()),"ghost_material":str(ghost.get_instance_id()),"opaque_alpha":opaque.albedo_color.a,"ghost_alpha":ghost.albedo_color.a,"shader_instance_declaration":instance_declaration,"highlight_entities":0,"camera_gamma":1.2,"grid_columns":COLUMNS,"grid_rows":ROWS,"geometry":"three authored primitive vertices per physical instance; actual ResourcePool NativeModelMaterial"}
	observations.gamma=gamma.snapshot();check(observations.gamma.failure.is_empty() and observations.gamma.passes>0,"Exact native surface-output compositor executes actual GPU passes")
	check(root.current_screen!=DisplayServer.get_primary_screen() and root.unfocusable and not root.has_focus() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Completion preserves nonprimary unfocused pointer-visible policy")
	Surface.retire(world);world.free();world=null;nodes.clear();identities.clear();shared_mesh=null;opaque=null;ghost=null;pool.clear();pool=null;gamma=null
	for frame in 3:await process_frame
	finish()
func finish() -> void:
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"case":mode,"observations":observations,"samples":samples,"captures":captures,"serverConnections":0,"nativeBuilds":0,"performanceClaim":false,"scope":"Bounded4200 physical mesh owner regression of actual frozen native-surface material factory and output compositor. Primitive geometry, calibrated real GPU pixels. No full-room/source-room match, live server, highlight participation or FPS claim. Baseline allocation errors are expected and separately required by runner; candidate errors are forbidden."}
	FileAccess.open(report,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_SURFACE_CAPACITY ",checks," checks ",failures.size()," failures");quit(0 if result.success else 1)
