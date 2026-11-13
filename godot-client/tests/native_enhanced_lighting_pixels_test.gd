extends SceneTree
const Policy=preload("res://systems/native_render/native_light_policy.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
const PointLight=preload("res://systems/native_render/model_point_light.gd")
var checks:=0
var failures: Array=[]
var samples: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func capture() -> Color:
	Palette.flush()
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_pixel(128,128)
func close_color(actual: Color,expected_linear: Vector3,label: String,tolerance: float=.006) -> void:
	var expected:=Color(expected_linear.x,expected_linear.y,expected_linear.z).linear_to_srgb()
	var error:=maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b)))
	samples.append({"name":label,"actual":[actual.r,actual.g,actual.b],"expected":[expected.r,expected.g,expected.b],"maximum_error":error})
	check(error<tolerance,label)
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256)
	var world:=Node3D.new(); root.add_child(world); world.add_child(Palette.new())
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color.BLACK; environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.BLACK; environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.add_child(environment)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.make_current()
	var surface:=MeshInstance3D.new(); surface.mesh=QuadMesh.new(); world.add_child(surface)
	var source:=StandardMaterial3D.new(); source.albedo_color=Color(0,0,0,1)
	var material:=NativeMaterial.new(); material.configure(source,[1.0,.5,.25],[0.0,0.0,0.0]); surface.material_override=material
	var ambient_source:=[.15,.2,.25]; Palette.ambient(Policy.linear_rgb(ambient_source))
	var ambient:=await capture(); close_color(ambient,Policy.linear_rgb(ambient_source)*Policy.linear_rgb([1.0,.5,.25]),"Independent ambient survives a zero diffuse material")
	Palette.ambient(Vector3.ZERO)
	var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure({"color":[.5,.75,1.0],"radius":5,"ambientonly":1}); world.add_child(light); light.position=Vector3(0,0,2); light.force_update_transform()
	var lamp:=await capture(); var state:=Policy.point({"color":[.5,.75,1.0],"radius":5,"ambientonly":1})
	close_color(lamp,state.color*Policy.attenuation(2,state)*Policy.linear_rgb([1.0,.5,.25]),"Native ambient-only point lamp bypasses Lambert and uses enhanced falloff")
	light.position=Vector3(0,0,7); light.force_update_transform()
	var distant:=await capture(); close_color(distant,state.color*Policy.attenuation(7,state)*Policy.linear_rgb([1.0,.5,.25]),"Light remains present beyond authored radius up to native adjusted range")
	light.position=Vector3(0,0,11); light.force_update_transform()
	var outside:=await capture(); close_color(outside,Vector3.ZERO,"Native adjusted range has finite support",.005)
	light.free()
	material.albedo_color=Color(.3,.6,.9,1); material.ambient_color=Vector3.ZERO
	var sun:=DirectionalLight3D.new(); sun.light_color=Color.WHITE; world.add_child(sun)
	var directional:=await capture(); close_color(directional,Policy.linear_rgb([.3,.6,.9]),"Directional light preserves independent material diffuse")
	sun.free()
	# A normal Godot point light must not alias native palette slot zero.
	var ordinary:=OmniLight3D.new(); ordinary.omni_range=10; ordinary.omni_attenuation=0; ordinary.position=Vector3(0,0,2); world.add_child(ordinary)
	var ordinary_color:=await capture(); close_color(ordinary_color,Policy.linear_rgb([.3,.6,.9])*pow(1-pow(2.0/10,4),2),"Unencoded Godot lights keep ordinary light behavior")
	ordinary.free()
	material.albedo_color=Color(.7,.7,.7,1)
	var shadow_light:=PointLight.new(); shadow_light.set_meta("native_enhanced_light",true); shadow_light.configure({"color":[1.0,1.0,1.0],"radius":5}); world.add_child(shadow_light); shadow_light.position=Vector3(1.5,0,2); shadow_light.force_update_transform()
	var before_shadow:=await capture()
	var shadow_state:=Policy.point({"color":[1.0,1.0,1.0],"radius":5})
	close_color(before_shadow,Policy.linear_rgb([.7,.7,.7])*Policy.attenuation(2.5,shadow_state)*.8,"Diffuse lamps retain the surface normal cosine")
	var blocker:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.45,.45,.45); blocker.mesh=box; blocker.position=Vector3(.75,0,1); world.add_child(blocker)
	shadow_light.shadow_enabled=true
	var with_shadow:=await capture()
	check(before_shadow.r>.1 and with_shadow.r<before_shadow.r*.3,"Native falloff correction preserves Godot point-light shadows")
	samples.append({"name":"Point-light shadow retention","lit":before_shadow.r,"shadowed":with_shadow.r})
	blocker.free(); shadow_light.free()
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color(.7,.4,.2,1)); source.albedo_texture=ImageTexture.create_from_image(image); source.albedo_color=Color.WHITE
	var textured:=NativeMaterial.new(); textured.configure(source,[1.0,1.0,1.0],[0.0,0.0,0.0]); surface.material_override=textured; Palette.ambient(Policy.linear_rgb([.5,.5,.5]))
	var texture_sample:=await capture(); var raw:=image.get_pixel(0,0)
	close_color(texture_sample,Policy.linear_rgb([raw.r,raw.g,raw.b])*Policy.linear_rgb([.5,.5,.5]),"Original texture and ambient values each use one native color conversion")
	textured.publish_native_pose(Color(1,1,1,.5),Color.BLACK,true)
	var blended:=await capture()
	close_color(blended,Policy.linear_rgb([raw.r,raw.g,raw.b])*Policy.linear_rgb([.5,.5,.5])*.5,"Animated alpha variant retains texture and ambient shader bindings")
	var empty_texel:=Image.create(1,1,false,Image.FORMAT_RGBA8); empty_texel.fill(Color(1,1,1,0)); source.albedo_texture=ImageTexture.create_from_image(empty_texel); source.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; source.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var cutout:=NativeMaterial.new(); cutout.configure(source,[1.0,1.0,1.0],[0.0,0.0,0.0]); var cutout_copy=cutout.duplicate(); surface.material_override=cutout_copy
	close_color(await capture(),Vector3.ZERO,"Private material copies preserve texture alpha cutouts",.005)
	# Reach the highest exact half-precision index without drawing thousands of
	# lights. Reserved rows own no GPU lights and never enter a lighting loop.
	var reserved: Array[int]=[]
	for index in Palette.CAPACITY-1: reserved.append(Palette.acquire(world))
	source.albedo_texture=null; source.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	var high_material:=NativeMaterial.new(); high_material.configure(source,[0.0,0.0,0.0],[0.0,0.0,0.0]); surface.material_override=high_material; Palette.ambient(Vector3.ZERO)
	var high_light:=PointLight.new(); high_light.set_meta("native_enhanced_light",true); high_light.configure({"color":[1.0,1.0,1.0],"radius":5}); world.add_child(high_light); high_light.position=Vector3(0,0,2); high_light.force_update_transform()
	check(high_light.native_slot==Palette.CAPACITY-1 and high_light.light_specular*2==2047,"Highest palette entry stays exactly representable")
	close_color(await capture(),Vector3.ONE*Policy.attenuation(2,shadow_state),"Highest metadata index resolves the correct light on the GPU")
	high_light.free()
	for slot in reserved: Palette.release(slot)
	world.free(); material=null; source=null; textured=null; cutout=null; cutout_copy=null; high_material=null
	for frame in 3: await process_frame
	check(Palette.active.is_empty(),"GPU fixture releases all lamp palette slots")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"GPU readback of original-compatible material/point-light equations in bounded authored fixture; no real-room FPS or full color/fog/vision parity acceptance"}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); print(JSON.stringify(result)); quit(0 if result.success else 1)
