extends SceneTree
const Before=preload("res://tests/fixtures/native_perf140_loading_model_material_before.gd")
const Target=preload("res://systems/native_render/native_model_material.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
var expect_batched:=false
var product_counts: Dictionary={}
const FIELDS=["native_surface_output","native_tile_fog_enabled","native_world_fog","standard_specular","standard_quality","albedo_color","emission","emission_enabled","transparency","albedo_texture","ambient_color","filter_mode","scissor"]
const UNIFORMS=["native_diffuse","native_alpha","native_ambient","native_texture","native_has_texture","native_emission","native_emission_enabled","native_world_fog"]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	expect_batched=OS.get_cmdline_user_args().has("--expect-batched=true");call_deferred("run")
func equivalent(before,target,label: String) -> void:
	check(before.shader!=null and target.shader!=null,label+": shader exists")
	if before.shader==null or target.shader==null:return
	check(before.shader.code==target.shader.code,label+": exact final shader source")
	for field in FIELDS:check(before.get(field)==target.get(field),label+": property "+field)
	for uniform in UNIFORMS:check(before.get_shader_parameter(uniform)==target.get_shader_parameter(uniform),label+": uniform "+uniform)
	check(before.has_meta("native_surface_output")==target.has_meta("native_surface_output"),label+": surface metadata presence")
	if before.has_meta("native_surface_output"):check(before.get_meta("native_surface_output")==target.get_meta("native_surface_output"),label+": surface metadata value")
	check(before.has_meta("native_tile_fog_enabled")==target.has_meta("native_tile_fog_enabled"),label+": tile-fog metadata presence")
	if before.has_meta("native_tile_fog_enabled"):check(before.get_meta("native_tile_fog_enabled")==target.get_meta("native_tile_fog_enabled"),label+": tile-fog metadata value")
func configure_pair(source: StandardMaterial3D,standard: bool,quality: int,output: bool,label: String) -> Array:
	var before:=Before.new();before.configure(source,[.25,.5,.75],[.1,.2,.3],standard,quality);before.native_surface_output=output;before.native_world_fog=output
	var target:=Target.new()
	if expect_batched:target.call("configure",source,[.25,.5,.75],[.1,.2,.3],standard,quality,output)
	else:target.configure(source,[.25,.5,.75],[.1,.2,.3],standard,quality);target.native_surface_output=output
	target.native_world_fog=output;equivalent(before,target,label);return [before,target]
func material_checks() -> void:
	Before.shaders.clear();Target.shaders.clear()
	var source:=StandardMaterial3D.new();source.albedo_color=Color(.7,.4,.2,.65)
	for transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
		source.transparency=transparency
		var pair:=configure_pair(source,true,2,true,"product variant "+str(transparency));pair.clear()
	product_counts={"before":Before.shaders.size(),"target":Target.shaders.size()}
	check(product_counts.before==6,"three product variants originally construct six shader programs")
	check(product_counts.target==(3 if expect_batched else 6),"batched initialization creates only the three final product shader variants")
	Before.shaders.clear();Target.shaders.clear()
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.3,.4,.5));var texture:=ImageTexture.create_from_image(image)
	for output in [false,true]:
		for standard in [false,true]:
			for quality in [1,2]:
				for filter_mode in range(6):
					for transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
						source.texture_filter=filter_mode;source.transparency=transparency;source.albedo_texture=texture if (filter_mode%2)==0 else null
						var pair:=configure_pair(source,standard,quality,output,str([output,standard,quality,filter_mode,transparency]));pair.clear()
	var pair:=configure_pair(source,true,2,true,"live setter base")
	for mutation in [["native_surface_output",false],["standard_quality",1],["filter_mode",BaseMaterial3D.TEXTURE_FILTER_NEAREST],["scissor",true],["transparency",BaseMaterial3D.TRANSPARENCY_ALPHA],["native_world_fog",false],["albedo_color",Color(.2,.7,.1,.3)],["ambient_color",Vector3(.8,.2,.6)],["emission",Color(.3,.1,.4)],["emission_enabled",true],["albedo_texture",texture]]:
		pair[0].set(mutation[0],mutation[1]);pair[1].set(mutation[0],mutation[1]);equivalent(pair[0],pair[1],"later setter "+str(mutation[0]))
	pair[0].native_surface_output=true;pair[1].native_surface_output=true
	pair[0].configure(source,[.5,.7,.3],[.2,.1,.4],true,1);pair[1].configure(source,[.5,.7,.3],[.2,.1,.4],true,1)
	equivalent(pair[0],pair[1],"legacy reconfigure keeps current surface policy")
	pair[0].native_tile_fog_enabled=true;pair[1].native_tile_fog_enabled=true
	equivalent(pair[0],pair[1],"later tile-fog policy setter")
	pair[0].configure(source,[.3,.4,.5],[.1,.2,.4],false,2);pair[1].configure(source,[.3,.4,.5],[.1,.2,.4],false,2)
	equivalent(pair[0],pair[1],"legacy reconfigure keeps tile-fog policy")
	pair.clear()
func pool_checks() -> void:
	var pool:=Pool.new();pool.native_lighting=true;pool.native_standard=true;pool.native_surface_output=true
	var part:={"alpha":1.0,"selfillum":[.1,.2,.3],"mesh":{"diffuse":[.7,.4,.2],"ambient":[.25,.5,.75]}}
	var material=pool.material(part)
	var source:=StandardMaterial3D.new();source.albedo_color=Color(.7,.4,.2,1);source.texture_filter=pool.texture_filter
	var before:=Before.new();before.configure(source,[.25,.5,.75],[.1,.2,.3],true,2);before.native_surface_output=true;before.native_world_fog=true
	equivalent(before,material,"actual ResourcePool selects final native carrier")
	check(pool.material(part)==material,"material cache identity preserved")
	pool.native_surface_output=false;var rollback=pool.material(part)
	check(rollback!=material and not rollback.native_surface_output and not rollback.native_world_fog,"surface policy remains part of material cache key")
	var duplicate=material.duplicate();check(duplicate.native_surface_output and duplicate.native_world_fog,"private material duplication retains exported policy")
	pool.clear()
func run() -> void:
	preload("res://systems/native_render/native_light_palette.gd").ensure();preload("res://systems/native_render/native_surface_state.gd").ensure()
	material_checks();pool_checks();Before.shaders.clear();Target.shaders.clear()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"expect_batched":expect_batched,"product_shader_programs":product_counts,"scope":"Headless final shader-source/property/uniform/metadata parity across 144 configurations, later setters, legacy reconfigure and actual pool selection. No pixels/GPU/FPS or live-client acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
	print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
