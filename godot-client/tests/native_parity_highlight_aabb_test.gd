extends SceneTree
const Bounds=preload("res://tools/native_parity/highlighting/candidates/bounds_aabb.gd")
const MaterialProgram=preload("res://tools/native_parity/highlighting/native_highlight_material.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Sampler=preload("res://systems/native_data/gui_texture_info.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var catalog:=Catalog.new()
	check(catalog.mount_install("C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall"),"Original install catalog mounts read-only")
	check(catalog.mount_directory("C:/Users/Niflheim/Documents/Neverwinter Nights.0/override",10000000),"Actual user profile overrides participate in texture lookup")
	var selected:=catalog.raster_location("fxpa_dot02")
	check(not selected.is_empty() and int(selected.type)==2033,"Original provider picks preferred native DDS at matching storage class")
	var bytes:=catalog.get_resource("fxpa_dot02",int(selected.type));var digest:=preload("res://systems/native_data/prepared_cache.gd").digest(bytes)
	check(digest=="4f3688a2e18273278988eb748a217b3316b59ab23bbec2dd3ac806b8acd7c8ec","Actual selected original highlight DDS bytes match bounded asset receipt")
	var parser:=Raster.new();var image_data:=parser.parse(bytes,int(selected.type))
	check(parser.failure.is_empty() and image_data.width==32 and image_data.height==32 and image_data.format=="dxt1_rgb" and image_data.mips.size()==6,"Native parser retains original RGB falloff and all six authored mip levels")
	var sampler:=Sampler.read(catalog,"fxpa_dot02")
	check(sampler.filter and sampler.mipmap and sampler.clamp==0,"Original TXI plus constructor defaults provide repeat and trilinear sampler")
	var pool:=Pool.new();var texture:=pool.texture({"sha256":digest,"value":image_data})
	check(texture!=null and texture.get_width()==32 and texture.get_height()==32,"Existing immutable resource pool publishes original compressed highlight texture")
	var material:=MaterialProgram.new()
	check(material.configure(texture,sampler,true) and material.get_shader_parameter("native_highlight_texture")==texture,"Shader binds active provider Texture2D without replacing pixel data")
	check(material.shader.code.contains("apply_native(COLOR.rgb)*apply_native(texel.rgb)") and material.shader.code.contains("ALPHA=COLOR.a*texel.a;") and not material.shader.code.contains("source_color"),"Native2.2 fullRGBA modulation avoids automatic IECsRGB decode or alpha-only mask")
	check(material.shader.code.contains("ALBEDO=native_display;") and material.get_meta("native_surface_output"),"Established native-surface compositor receives gamma-space carrier")
	check(material.configure(texture,sampler,false) and material.shader.code.contains("ALBEDO=display_to_linear(native_display);"),"Ordinary output mode explicitly converts display carrier for Godot output")
	for clamp_mask in [0,3,4,7,-1]:
		var policy:=sampler.duplicate();policy.clamp=clamp_mask
		check(material.configure(texture,policy,true),"Native effective clamp bitmask0/3 and ignored higher bits supported")
	for clamp_mask in [1,2]:
		var policy:=sampler.duplicate();policy.clamp=clamp_mask
		check(not material.configure(texture,policy,true),"Unsupported independent S/T clamp remains explicit")
	for modes in [[false,true],[true,false]]:
		var policy:=sampler.duplicate();policy.filter=modes[0];policy.mipmap=modes[1]
		check(not material.configure(texture,policy,true),"Unrepresentable native mixed min/mag mode cannot silently use a different Godot hint")
	var nearest:=sampler.duplicate();nearest.filter=false;nearest.mipmap=false
	check(material.configure(texture,nearest,true) and material.shader.code.contains("filter_nearest,repeat_enable"),"Native nearest/no-mipmap sampler is explicit")
	var owner:=Node3D.new();root.add_child(owner);var physical:=MeshInstance3D.new();owner.add_child(physical);physical.visible=false
	var helper:=Bounds.new();root.add_child(helper);var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(10,0,0)
	helper.register_entity(1,owner,[1],[{"anchor":physical,"native_bounds":{"min":[-1,-1,-1],"max":[1,1,1]},"is_skin":false,"subtree_enabled":true}],Color.GREEN,func(_model):return 1.0);helper.mark([1])
	check(not helper.tick(camera,2.5,0.3) and not helper.batch.visible,"Missing original highlight texture suppresses the bounds pass explicitly")
	check(helper.configure_texture(texture,sampler,true) and helper.tick(camera,2.5,0.3),"Original texture readiness enables native bounds publication")
	check(helper.uvs.size()==18 and helper.attributes.size()==18*12 and helper.color_bytes.size()==18*4,"COLOR RGBA8 plus UV float2 uses correct retained twelve-byte attribute stride")
	var uv_valid:=true;var colors_valid:=true
	for vertex in 18:
		var expected: Vector2=Bounds.UVS[vertex%6]
		if helper.uvs[vertex]!=expected or helper.attributes.decode_float(vertex*12+4)!=expected.x or helper.attributes.decode_float(vertex*12+8)!=expected.y:uv_valid=false
		for component in 4:
			if helper.attributes[vertex*12+component]!=helper.color_bytes[vertex*4+component]:colors_valid=false
	check(uv_valid and colors_valid,"Every native six-vertex UV sequence and packed color occupy the correct non-overlapping attribute bytes")
	var previous_uv:=helper.uvs.duplicate();var mesh_id:=helper.surface.get_instance_id();camera.position=Vector3(7,4,9);helper.tick(camera,2.6,0.3)
	check(helper.uvs==previous_uv and helper.surface.get_instance_id()==mesh_id,"Camera/pulse color updates retain UVs and mesh identity")
	helper.clear_texture();check(not helper.tick(camera,2.5,0.3) and not helper.batch.visible,"Texture retirement never renders a stale or untextured mask")
	check(helper.configure_texture(texture,sampler,true) and helper.tick(camera,2.5,0.3),"Explicit original resource replacement can resume current selection")
	var snapshot:=helper.snapshot();snapshot.texture.sampler.clamp=99
	check(helper.snapshot().texture.sampler.clamp==0,"Cold texture/sampler diagnostics remain detached")
	var second:=Node3D.new();owner.add_child(second)
	var a:={"anchor":physical,"native_bounds":{"min":[-1,-1,-1],"max":[1,1,1]},"is_skin":false,"subtree_enabled":true,"model_index":0}
	var b:=a.duplicate(true);b.anchor=second;b.model_index=1
	var reads: Array=[0,0]
	helper.register_entity(2,owner,[],[a,b],Color.GREEN,func(_model):return 1.0,func(model):reads[int(model)]+=1;return Vector3.RIGHT if model==0 else Vector3(0,0,1))
	helper.mark([2]);helper.tick(camera,2.5,0.3)
	check(helper.color_bytes[0]==255 and helper.color_bytes[1]==0 and helper.color_bytes[2]==0 and helper.color_bytes[72]==0 and helper.color_bytes[74]==255,"Two Gobs in one entity retain independent current channel colors instead of model0 fallback")
	check(reads==[1,1],"Current color provider reads each highlighted model exactly once")
	helper.register_entity(3,owner,[],[a],Color.GREEN,func(_model):return 1.0,func(_model):return null);helper.mark([3])
	check(not helper.tick(camera,2.5,0.3) and not helper.batch.visible,"Provided unavailable model color cannot silently use original entity color")
	helper.register_entity(4,owner,[],[a],Color.GREEN,func(_model):return 1.0,func(_model):helper.forget(4);return Vector3.ONE);helper.mark([4]);var updates: int=helper.stats.updates
	check(not helper.tick(camera,2.5,0.3) and helper.stats.updates==updates and not helper.batch.visible,"Color callback membership retirement revokes the pending batch before publication")
	helper.close();check(not helper.configure_texture(texture,sampler,true) and not helper.texture_ready,"Closed owner cannot regain retired texture")
	material.clear_texture();helper.free();owner.free();camera.free();pool.clear();await process_frame
	print("NATIVE_PARITY_HIGHLIGHT_AABB ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
