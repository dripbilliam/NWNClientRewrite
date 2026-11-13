extends SceneTree
const Baseline=preload("res://baseline/model_point_light.gd")
const Candidate=preload("res://candidate/model_point_light.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var output:=""
var directory:=""
var checks:=0
var failures: Array=[]
var stages: Array=[]
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func scene(script)->Dictionary:
	var viewport:=SubViewport.new();viewport.size=Vector2i(320,240);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.positional_shadow_atlas_size=1024
	root.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color(.04,.04,.04)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.025
	environment.environment=env;world.add_child(environment)
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.65,.65,.65);material.roughness=1;material.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	var plane:=MeshInstance3D.new();var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(14,14)
	plane.mesh=floor_mesh;plane.material_override=material;world.add_child(plane)
	var caster:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=Vector3(1.7,2,1.7)
	caster.mesh=cube;caster.material_override=material;caster.position=Vector3(0,1,0);world.add_child(caster)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(8,9,11);camera.look_at(Vector3(0,0,0));camera.current=true;camera.fov=50
	var lamp=script.new();lamp.set_meta("native_enhanced_light",true);lamp.position=Vector3(-3,5,2)
	lamp.configure({"color":[.7,.6,.5],"radius":8,"multiplier":1,"shadow":1,"ambientonly":0})
	world.add_child(lamp);lamp.shadow_enabled=true
	return {"viewport":viewport,"world":world,"lamp":lamp,"caster":caster}
func settle()->void:
	Palette.flush()
	for frame in 5:await process_frame;await RenderingServer.frame_post_draw
func delta(a: Image,b: Image)->Dictionary:
	var aa:=a.get_data();var bb:=b.get_data();var total:=0;var different:=0;var maximum:=0
	for index in aa.size():
		var amount:=absi(int(aa[index])-int(bb[index]));total+=amount
		if amount>0:different+=1
		maximum=maxi(maximum,amount)
	return {"mean_byte_delta":float(total)/aa.size(),"changed_bytes":different,"max_byte_delta":maximum}
func paired(a: Dictionary,b: Dictionary,label: String)->void:
	await settle()
	var first: Image=a.viewport.get_texture().get_image();var second: Image=b.viewport.get_texture().get_image()
	first.convert(Image.FORMAT_RGBA8);second.convert(Image.FORMAT_RGBA8)
	first.save_png(directory+"/"+label+"-control.png");second.save_png(directory+"/"+label+"-candidate.png")
	var difference:=delta(first,second);stages.append({"label":label,"delta":difference})
	check(difference.mean_byte_delta<=.05 and difference.max_byte_delta<=4,label+" equivalent fixed-scene shadow/range/color pixels")
func run()->void:
	root.unfocusable=true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	directory=output.get_base_dir()
	check(RenderingServer.get_current_rendering_method()!="gl_compatibility","Current RD renderer exercises production shadow/range pipeline")
	var a:=scene(Baseline);var b:=scene(Candidate)
	await paired(a,b,"initial-shadow")
	for lamp in [a.lamp,b.lamp]:lamp.publish_native_light(Color(.3,.7,.4),8,6,0,1)
	await paired(a,b,"color-selected-shadow")
	for lamp in [a.lamp,b.lamp]:lamp.apply_native_admission(true,.4)
	await paired(a,b,"fade-selected-shadow")
	for lamp in [a.lamp,b.lamp]:lamp.publish_native_light(Color(.3,.7,.4),5,6,0,1)
	await paired(a,b,"changed-support-shadow")
	for lamp in [a.lamp,b.lamp]:lamp.apply_native_admission(false,.4)
	await paired(a,b,"not-admitted")
	for lamp in [a.lamp,b.lamp]:lamp.apply_native_admission(true,1.0);lamp.publish_native_light(Color(.7,.6,.5),8,6,0,1)
	await paired(a,b,"readmitted-selected-shadow")
	var correct: Image=b.viewport.get_texture().get_image();correct.convert(Image.FORMAT_RGBA8)
	b.lamp.shadow_enabled=false
	await settle()
	var no_shadow: Image=b.viewport.get_texture().get_image();no_shadow.convert(Image.FORMAT_RGBA8);no_shadow.save_png(directory+"/negative-no-shadow.png")
	var shadow_delta:=delta(correct,no_shadow);stages.append({"label":"negative-no-shadow","delta":shadow_delta})
	check(shadow_delta.mean_byte_delta>.05 and shadow_delta.changed_bytes>100,"Negative control proves scene actually observes shadow suppression")
	b.lamp.shadow_enabled=true;b.lamp.omni_range=.01
	await settle()
	var no_range: Image=b.viewport.get_texture().get_image();no_range.convert(Image.FORMAT_RGBA8);no_range.save_png(directory+"/negative-no-range.png")
	var range_delta:=delta(correct,no_range);stages.append({"label":"negative-no-range","delta":range_delta})
	check(range_delta.mean_byte_delta>.05 and range_delta.changed_bytes>100,"Negative control proves scene actually observes light support")
	a.viewport.free();b.viewport.free();await process_frame
	check(Palette.active.is_empty(),"GPU fixture releases both real palette owners")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"stages":stages,"gpu":true,"fpsClaim":false,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Fixed deterministic native-engine light/shadow validity fixture; full-world native-material parity requires separate matched replay"}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
