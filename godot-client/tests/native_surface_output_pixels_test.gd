extends "res://tests/native_standard_light_pixels_test.gd"
const OutputOriginal=preload("res://tests/original_surface_output_oracle.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
var output_original=OutputOriginal.new()
var selected_catalog
var output_samples: Array=[]
func capture() -> Color:
	Palette.flush()
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	return image.get_pixel(image.get_width()/2,image.get_height()/2)
func compare_output(linear: Vector3,opacity: float,fog_color: Vector3,amount: float,background: Vector3,value: float,label: String) -> void:
	var data:=PackedFloat32Array([linear.x,linear.y,linear.z,opacity,fog_color.x,fog_color.y,fog_color.z,amount,background.x,background.y,background.z,value])
	var expected: PackedFloat32Array=output_original.execute(selected_catalog,0,data)
	check(output_original.failure.is_empty() and expected.size()==4,"Original surface/output functions execute: "+output_original.failure)
	if expected.size()!=4: return
	var actual: Color=await capture(); var worst:=0.0
	for n in 3: worst=maxf(worst,absf(actual[n]-clampf(expected[n],0.0,1.0)))
	check(worst<.009,label+" error="+str(worst))
	output_samples.append({"name":label,"actual":[actual.r,actual.g,actual.b],"expected":Array(expected.slice(0,3)),"max_error":worst})
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256); selected_catalog=Catalog.new()
	check(selected_catalog.mount_install(install),"Original catalog mounts read-only")
	var world:=Node3D.new(); root.add_child(world); world.add_child(Palette.new())
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color.BLACK; environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.BLACK; environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.add_child(environment)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.make_current()
	var gamma:=Gamma.new(); world.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var layer:=CanvasLayer.new(); world.add_child(layer); var ui:=ColorRect.new(); layer.add_child(ui); ui.position=Vector2(5,5); ui.size=Vector2(20,20); ui.color=Color(.2,.4,.8)
	var surface:=MeshInstance3D.new(); surface.mesh=QuadMesh.new(); world.add_child(surface)
	var source:=StandardMaterial3D.new(); var material:=NativeMaterial.new(); material.configure(source,[1,1,1],[0,0,0],true,2); material.native_surface_output=true; surface.material_override=material
	Palette.ambient(Vector3.ZERO); Palette.environment(null)
	material.set_shader_parameter("native_emission_enabled",true)
	material.set_shader_parameter("native_emission",Vector3(.0012,.0012,.0012)); material.native_surface_output=false; gamma.effect.set_surface_output(false)
	var old_dark:=await capture(); material.native_surface_output=true; gamma.effect.set_surface_output(true)
	var native_dark:=await capture()
	check(old_dark.r<.02 and native_dark.r>.04,"Actual original power transfer explains the bounded dark-color mismatch without a brightness multiplier")
	var transfer_comparison:={"linear":.0012,"previous_srgb":old_dark.r,"native_power":native_dark.r}
	for value in [0.0,.000001,.0001,.0012,.01,.1,.7,1.0,2.0,10.0]:
		var linear:=Vector3(value,value*.7,value*.3); material.set_shader_parameter("native_emission",linear)
		await compare_output(linear,1.0,Vector3.ZERO,0.0,Vector3.ZERO,2.2,"Original dark/HDR surface "+str(value))
	for linear in [Vector3(1.5,.001,.1),Vector3(.001,1.3,.01),Vector3(.01,.001,1.1)]:
		material.set_shader_parameter("native_emission",linear)
		await compare_output(linear,1.0,Vector3.ZERO,0.0,Vector3.ZERO,2.2,"Original retail HDR hue redistribution "+str(linear))
	var original:=Original.new(); var lights: Array=[]; var total:=Vector3.ZERO; var emission:=Vector3(.001,.002,.003); material.set_shader_parameter("native_emission",emission)
	for n in 32:
		var point:=Vector3(float(n%3)*.3,0,2); var color:=[.07,.1,.15]; var props:={"color":color,"radius":4}; var state:=Policy.point(props)
		var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure(props); world.add_child(light); light.position=point; light.force_update_transform(); lights.append(light)
		var raw:=original.execute(selected_catalog,2,inputs(Vector3.ONE,[1,1,1],[1,1,1],[0,0,0],1.0,0,color,point,state))
		if raw.size()==4: total+=Vector3(raw[0],raw[1],raw[2])
		else: check(false,"Original direct-light oracle failed: "+original.failure); break
		if n+1 in [1,2,8,32]: await compare_output(total+emission,1.0,Vector3.ZERO,0.0,Vector3.ZERO,2.2,"Accumulation before transfer with "+str(n+1)+" lights")
	var fog_color:=Vector3(.1,.2,.4); material.set_shader_parameter("native_surface_fog_color",fog_color)
	for amount in [-.1,.375,.8,1.1]:
		material.set_shader_parameter("native_surface_fog_params",Vector3(1,5-amount*8,.125))
		await compare_output(total+emission,1.0,fog_color,amount,Vector3.ZERO,2.2,"Original gamma-space fog "+str(amount))
	material.set_shader_parameter("native_surface_fog_params",Vector3.ZERO)
	# Exercise compensated HDR accumulation, including the renderer's optional
	# separate-specular attachment. A failure here is a real method limitation.
	var bright_total:=Vector3.ZERO
	for n in lights.size():
		var point: Vector3=lights[n].position; var color:=[1.0,.03,.02]; var props:={"color":color,"radius":4}; var state:=Policy.point(props); lights[n].configure(props)
		var raw:=original.execute(selected_catalog,2,inputs(Vector3.ONE,[1,1,1],[1,1,1],[0,0,0],1.0,0,color,point,state))
		if raw.size()==4: bright_total+=Vector3(raw[0],raw[1],raw[2])
	await compare_output(bright_total+emission,1.0,Vector3.ZERO,0.0,Vector3.ZERO,2.2,"Bright overlapping lights retain HDR compensation")
	environment.environment.ssr_enabled=true
	await compare_output(bright_total+emission,1.0,Vector3.ZERO,0.0,Vector3.ZERO,2.2,"Separate-specular attachment retains HDR compensation")
	environment.environment.ssr_enabled=false
	for light in lights: light.free()
	# Same accumulator policy without GGX, retaining Godot's real shadow factor.
	material.standard_specular=false; var props:={"color":[.4,.6,.8],"radius":5}; var lambert_state:=Policy.point(props)
	var shadow_light:=PointLight.new(); shadow_light.set_meta("native_enhanced_light",true); shadow_light.configure(props); world.add_child(shadow_light); shadow_light.position=Vector3(1.5,0,2); shadow_light.force_update_transform()
	await compare_output(emission+lambert_state.color*Policy.attenuation(2.5,lambert_state)*.8,1.0,Vector3.ZERO,0.0,Vector3.ZERO,2.2,"Unmapped Lambert mode retains transfer after lighting")
	var before_shadow:=await capture(); var blocker:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.45,.45,.45); blocker.mesh=box; blocker.position=Vector3(.75,0,1); world.add_child(blocker); shadow_light.shadow_enabled=true
	var after_shadow:=await capture(); check(before_shadow.b>.2 and after_shadow.b<before_shadow.b*.6,"Native surface transfer preserves actual point-light shadows")
	blocker.free(); shadow_light.free(); material.standard_specular=true
	var back:=MeshInstance3D.new(); back.mesh=QuadMesh.new(); back.position.z=-.5; world.add_child(back)
	var backing:=NativeMaterial.new(); backing.configure(source,[0,0,0],[0,0,0]); backing.native_surface_output=true; backing.set_shader_parameter("native_emission_enabled",true); var back_linear:=Vector3(.02,.04,.08); backing.set_shader_parameter("native_emission",back_linear); back.material_override=backing
	var back_display:=Vector3(pow(back_linear.x,1.0/2.2),pow(back_linear.y,1.0/2.2),pow(back_linear.z,1.0/2.2))
	for opacity in [.2,.5,.9]:
		material.albedo_color=Color(1,1,1,opacity); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		await compare_output(emission,opacity,Vector3.ZERO,0.0,back_display,2.2,"Original surface alpha blending "+str(opacity))
	for value in [1.2,1.8,3.0]:
		gamma.set_gamma(value)
		await compare_output(emission,.9,Vector3.ZERO,0.0,back_display,value,"Native Gamma follows blend "+str(value))
	gamma.set_gamma(2.2); root.msaa_3d=Viewport.MSAA_2X; root.size=Vector2i(239,193)
	await compare_output(emission,.9,Vector3.ZERO,0.0,back_display,2.2,"Resolved MSAA, resize and partial compute groups")
	var empty_texel:=Image.create(1,1,false,Image.FORMAT_RGBA8); empty_texel.fill(Color(1,1,1,0)); material.albedo_texture=ImageTexture.create_from_image(empty_texel); material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED; material.scissor=true
	await compare_output(back_linear,1.0,Vector3.ZERO,0.0,Vector3.ZERO,2.2,"Native gamma-space alpha cutout preserves background")
	check(root.get_texture().get_image().get_pixel(10,10).is_equal_approx(ui.color),"Native world output preserves later UI colors")
	check(gamma.snapshot().failure.is_empty() and gamma.snapshot().passes>0,"Actual native output GPU pass executes without failure")
	var copied=material.duplicate(); check(copied.native_surface_output,"Private material copies preserve research surface transfer")
	check(not NativeMaterial.new().native_surface_output,"Ordinary material default does not select research output")
	var state: Dictionary=gamma.snapshot(); output_original.close(); original.close(); world.free(); material=null; backing=null; copied=null; source=null
	for frame in 3: await process_frame
	check(Palette.active.is_empty(),"All surface-output fixture lamps retire")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":output_samples,"dark_transfer_comparison":transfer_comparison,"original_shader_sha256":output_original.hashes,"gamma":state,"publicConnections":0,"scope":"Research-only real GPU native surface transfer and gamma-space fog/alpha/retail output versus unchanged original functions; clustered overlap, actual point shadow, cutout, MSAA/resize and UI preservation. No world activation, particles, mapped/cube material, performance or matched-room acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
