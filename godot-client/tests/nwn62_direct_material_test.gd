extends SceneTree
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Policy=preload("res://systems/native_render/native_light_policy.gd")
const FIELDS:=["native_surface_output","native_tile_fog_enabled","native_world_fog","standard_specular","standard_quality","albedo_color","emission","emission_enabled","transparency","albedo_texture","ambient_color","filter_mode","scissor"]
const UNIFORMS:=["native_diffuse","native_alpha","native_ambient","native_texture","native_has_texture","native_emission","native_emission_enabled","native_world_fog"]
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func native_script(path: String):
	var source:=FileAccess.get_file_as_string(path).replace("set_shader_parameter(","_record_parameter(")
	source=source.replace("var _configuring_shader:=false","var parameter_writes: Dictionary={}\nvar _configuring_shader:=false")
	source+="\nfunc _record_parameter(parameter: StringName,value: Variant)->void:\n\tparameter_writes[str(parameter)]=int(parameter_writes.get(str(parameter),0))+1\n\tset_shader_parameter(parameter,value)\n"
	var script:=GDScript.new();script.source_code=source;check(script.reload()==OK,"Actual native material instrumented source parses");return script
func native_state(material)->Dictionary:
	var fields: Dictionary={};var uniforms: Dictionary={};var metadata: Dictionary={}
	for field in FIELDS:fields[field]=material.get(field)
	for name in UNIFORMS:uniforms[name]=material.get_shader_parameter(name)
	for name in material.get_meta_list():metadata[name]=material.get_meta(name)
	return {"fields":fields,"uniforms":uniforms,"metadata":metadata,"shader":material.shader.code,"variant":material.shader_variant_key()}
func material_state(material: Material)->Dictionary:
	if material is ShaderMaterial:return native_state(material)
	var result: Dictionary={}
	for row in material.get_property_list():
		if int(row.usage)&PROPERTY_USAGE_STORAGE:result[row.name]=material.get(row.name)
	return result
func texture_pool(path: String):
	var script:=GDScript.new();script.source_code="extends "+JSON.stringify(path)+"\nvar fixture_texture: Texture2D\nfunc texture(_record: Dictionary)->Texture2D:\n\treturn fixture_texture\n"
	check(script.reload()==OK,"Actual ResourcePool texture-only observer parses");return script.new()
func configure_observer(material,index: int)->void:
	material.native_tile_fog_enabled=index%3==0
	if index%7==0:material.native_surface_output=true
	material.parameter_writes.clear()
func run()->void:
	var image:=Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(Color(0.3,0.5,0.7,0.8));var texture:=ImageTexture.create_from_image(image)
	var old_script=native_script("res://.cache/nwn62/direct-material-before/native_model_material.gd")
	var new_script=native_script("res://systems/native_render/native_model_material.gd")
	var colors: Array=[Color(0.0031308,1.00000006,2.5,0.333333333333),Color(-0.25,0.0,0.75,1.0),Color(1.0,0.5,0.25,0.0)]
	for index in 90:
		var source:=StandardMaterial3D.new();source.albedo_color=colors[index%colors.size()];source.albedo_texture=texture if index%2==0 else null
		source.texture_filter=index%6;source.transparency=(index/6)%5
		var ambient: Array=[0.0031308,0.333333333333,1.25];var emission: Array=[-0.1,0.0,1.25] if index%3==0 else [0.0,0.0,0.0]
		var policy: Variant=[null,false,true][(index/30)%3];var standard:=index%2==0;var quality:=1+(index/2)%2
		var original=old_script.new();var wrapper=new_script.new();var direct=new_script.new()
		for material in [original,wrapper,direct]:configure_observer(material,index)
		original.configure(source,ambient,emission,standard,quality,policy)
		wrapper.configure(source,ambient,emission,standard,quality,policy)
		direct.configure_values(source.albedo_color,source.albedo_texture,source.texture_filter,source.transparency,ambient,emission,standard,quality,policy)
		check(native_state(original)==native_state(wrapper),"Legacy configure wrapper preserves exact f32/uniform/meta/variant output "+str(index))
		check(native_state(original)==native_state(direct),"Typed value configuration preserves exact original output "+str(index))
		for name in ["native_ambient","native_texture","native_has_texture"]:check(int(original.parameter_writes[name])==int(wrapper.parameter_writes[name])+1,"Only proven duplicate uniform write removed: "+name)
		check(wrapper.albedo_color==source.albedo_color and wrapper.emission==Color(emission[0],emission[1],emission[2]).srgb_to_linear(),"Original Color-f32 and emission transfer are retained")
		# Reconfigure existing objects with omitted surface policy and changed pose
		# after their first setup; their existing surface/tile fog state survives.
		original.configure(source,ambient,[0.1,0.2,0.3]);wrapper.configure(source,ambient,[0.1,0.2,0.3])
		original.publish_native_pose(Color(0.2,0.3,0.4,0.5),Color(0.1,0.2,0.3),true);wrapper.publish_native_pose(Color(0.2,0.3,0.4,0.5),Color(0.1,0.2,0.3),true)
		check(native_state(original)==native_state(wrapper),"Existing reconfiguration/pose/fog/surface behavior remains exact")
	# Before Pool keeps its exact body and old NativeMaterial implementation;
	# only texture creation is supplied identically to isolate material policy.
	var before_source:=FileAccess.get_file_as_string("res://.cache/nwn62/direct-material-before/resource_pool.gd")
	before_source=before_source.replace("preload(\"res://systems/native_render/native_model_material.gd\")","preload(\"res://.cache/nwn62/direct-material-before/native_model_material.gd\")")
	var before_path:="res://.cache/nwn62/direct-material-before/pool-test-view.gd"
	var file:=FileAccess.open(before_path,FileAccess.WRITE);file.store_string(before_source);file.close()
	for index in 72:
		var old=texture_pool(before_path);var current=texture_pool("res://systems/native_render/resource_pool.gd")
		var native_route:=(index/6)%3==0;var unshaded:=index%4==0
		for pool in [old,current]:pool.native_lighting=native_route;pool.unshaded=unshaded;pool.native_standard=index%2==0;pool.native_surface_output=index%5==0;pool.texture_filter=index%6;pool.fixture_texture=texture
		var input:={"alpha":[0.0,0.333333333333,1.0][index%3],"selfillum":[-0.1,0.0,0.2],"mesh":{"diffuse":[0.0031308,1.00000006,2.5],"ambient":[0.5,0.6,0.7],"transparency_hint":(index/2)%2==0}}
		var raster: Dictionary={} if index%3==0 else {"sha256":"original_pixels","value":{"format":"dxt1_rgb" if index%2==0 else "rgba8"}}
		var first: Material=old.material(input,raster);var next: Material=current.material(input,raster)
		var first_state:=material_state(first);var next_state:=material_state(next)
		if first_state!=next_state and index==3:
			print("MATERIAL_SHADER_EQUAL ",first_state.get("shader")==next_state.get("shader")," VARIANT ",first_state.get("variant")," / ",next_state.get("variant")," TYPES ",first.get_class()," / ",next.get_class())
			print("TEXTURE_VARIANT_TYPES fields=",typeof(first_state.fields.albedo_texture),"/",typeof(next_state.fields.albedo_texture)," uniforms=",typeof(first_state.uniforms.native_texture),"/",typeof(next_state.uniforms.native_texture))
			for group in ["fields","uniforms","metadata"]:
				for field in first_state.get(group,{}):
					if first_state[group][field]!=next_state.get(group,{}).get(field):print("MATERIAL_DIFFERENCE ",group,".",field," old=",first_state[group][field]," new=",next_state.get(group,{}).get(field))
		check(first_state==next_state,"Actual Pool final native/legacy/unshaded material state remains exact "+str(index))
		check(old.materials.keys()==current.materials.keys() and old.stats.materials_created==current.stats.materials_created,"Material cache key bytes and accounting remain exact")
		check(old.material(input,raster)==first and current.material(input,raster)==next and old.stats.material_hits==current.stats.material_hits,"Cache hits preserve exact resource reuse")
		check(int(current.stats.get("direct_native_materials",0))==int(native_route and not unshaded),"Direct route is positively engaged only for supported native materials")
		old.clear();current.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual frozen/current native configure and ResourcePool bodies; exact Color-f32, all6filter/5transparency/null-policy modes, shader/uniform/meta/emission/fog/pose/cache/resource output and three fewer duplicate writes. Identical supplied immutable texture isolates material policy; no GPU pixel or performance claim."}
	var path:="res://.cache/nwn62/checks/direct-material-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
