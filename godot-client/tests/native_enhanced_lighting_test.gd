extends SceneTree
const Policy=preload("res://systems/native_render/native_light_policy.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const MaterialOwner=preload("res://systems/native_render/native_model_material.gd")
const PointLight=preload("res://systems/native_render/model_point_light.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Binary=preload("res://systems/native_data/binary_model.gd")
const Reader=preload("res://systems/native_data/binary_data.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	# Values are observed effective GLRender area globals from the original
	# live client, not expected values recomputed through this implementation.
	var ambient:=Policy.linear_rgb([12.0/255,16.0/255,48.0/255])
	var diffuse:=Policy.linear_rgb([95.0/255,33.0/255,33.0/255])
	check(ambient.distance_to(Vector3(.001201749197,.002262944821,.025371188298))<.000001,"Observed original ambient upload within native/Godot power boundary tolerance")
	check(diffuse.distance_to(Vector3(.113920912147,.011126125231,.011126125231))<.000001,"Observed original diffuse upload within native/Godot power boundary tolerance")
	var state:=Policy.point({"color":[2.0,1.0,.5],"radius":10,"multiplier":3})
	check(state.range==120 and state.color.x==1,"Native radius consumes multiplier, HDR peak and 2x cutoff")
	check(absf(state.color.y-pow(.5,2.2))<.0000001,"Enhanced normalization precedes transfer")
	check(Policy.point({"color":[2.0,1.0,.5],"radius":1000,"multiplier":3}).range==1000,"Native infinite-light radius boundary bypasses range scaling")
	check(Policy.attenuation(0,state)>2 and Policy.attenuation(120,state)==0,"Enhanced peak and exact finite support")
	var ascii:="newmodel room\nbeginmodelgeom room\nnode trimesh floor\nparent NULL\nambient 0.8 0.6 0.4\ndiffuse 0.2 0.3 0.4\nverts 3\n0 0 0\n1 0 0\n0 1 0\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 0 0 1 2 0\nendnode\nendmodelgeom room\ndonemodel room\n"
	var parser:=Ascii.new(); var model:=parser.parse(ascii)
	check(parser.failure.is_empty() and not model.is_empty(),"Real ASCII MDL parsing")
	if not model.is_empty():
		check(model.nodes[0].mesh.ambient==[.8,.6,.4] and model.nodes[0].mesh.diffuse==[.2,.3,.4],"ASCII ambient remains independent of diffuse")
	var bytes:=PackedByteArray(); bytes.resize(600)
	for i in 3: bytes.encode_float(12+60+i*4,.75-i*.1); bytes.encode_float(12+72+i*4,.1+i*.1)
	var binary:=Binary.new(); binary.reader=Reader.new(bytes); binary.model_size=588
	var mesh:=binary.read_mesh(12)
	check(binary.failure.is_empty() and mesh.ambient==[Policy.f(.75),Policy.f(.65),Policy.f(.55)],"Original binary mesh ambient offsets are preserved independently")
	var pool:=Pool.new(); pool.native_lighting=true
	var source:={"mesh":{"ambient":[.8,.6,.4],"diffuse":[.2,.3,.4],"transparency_hint":false},"selfillum":[.1,0.0,0.0]}
	var material=pool.material(source)
	check(material is MaterialOwner,"Opt-in pool produces native material")
	check(material.get_shader_parameter("native_ambient").distance_to(Policy.linear_rgb([.8,.6,.4]))<.0000001,"Material keeps independent ambient response")
	var copy=material.duplicate()
	check(copy.albedo_color==material.albedo_color and copy.ambient_color==material.ambient_color,"Private animation copy preserves material inputs")
	copy.publish_native_pose(Color(.3,.4,.5,.5),Color(.1,0,0),true)
	check(copy.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"Animation alpha and color changes stay placement-local")
	var clipped_source:=StandardMaterial3D.new(); clipped_source.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; clipped_source.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var clipped:=MaterialOwner.new(); clipped.configure(clipped_source,[1.0,1.0,1.0],[0.0,0.0,0.0]); var clipped_copy=clipped.duplicate()
	check("if(texel.a<0.035)discard;" in clipped_copy.shader.code and "repeat_enable,filter_nearest;" in clipped_copy.shader.code,"Packed/private material copies retain cutout and sampler variants")
	clipped_copy=null; clipped=null; clipped_source=null
	var legacy:=Pool.new(); check(legacy.material(source) is StandardMaterial3D,"Unrequested/default material path stays unchanged")
	var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure({"color":[1.0,.5,.25],"radius":10,"multiplier":2,"ambientonly":1}); root.add_child(light)
	check(light.native_slot>=0 and light.omni_range==40 and light.light_energy==1 and light.omni_attenuation==0,"Native point-light range and GPU envelope")
	check(light.light_specular>=16,"Ordinary specular values cannot alias metadata slots")
	light.position=Vector3(3,4,5); light.force_update_transform(); Palette.flush()
	check(Palette.image.get_pixel(0,light.native_slot)==Color(3,4,5,40),"Moved model lamp updates metadata without scanning scenery")
	var slot:=light.native_slot; light.free(); check(not Palette.active.has(slot),"Retired lamp releases metadata ownership")
	copy=null; material=null; pool.clear(); legacy.clear()
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"ambient":[ambient.x,ambient.y,ambient.z],"diffuse":[diffuse.x,diffuse.y,diffuse.z],"publicConnections":0,"scope":"Native observed color uploads (absolute 1e-6 pow-boundary tolerance), direct ASCII/binary data, opt-in material/animation ownership and lamp metadata; no FPS acceptance"}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); print(JSON.stringify(result)); quit(0 if result.success else 1)
