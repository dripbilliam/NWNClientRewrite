extends "res://tests/native_enhanced_lighting_pixels_test.gd"
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Original=preload("res://tests/original_standard_light_oracle.gd")
func inputs(texture: Vector3,diffuse: Array,ambient: Array,emission: Array,opacity: float,kind: int,color: Array,position: Vector3,state: Dictionary,reflection: Vector3=Vector3.ZERO,normal: Vector3=Vector3.FORWARD,area_ambient: Array=[0,0,0],area_diffuse: Array=[0,0,0]) -> PackedFloat32Array:
	var result:=PackedFloat32Array([texture.x,texture.y,texture.z,opacity])
	for value in [Policy.linear_rgb(diffuse),Policy.linear_rgb(ambient),Policy.linear_rgb(emission)]: result.append_array(PackedFloat32Array([value.x,value.y,value.z,0]))
	var rgb:=Policy.linear_rgb(color); result.append_array(PackedFloat32Array([rgb.x,rgb.y,rgb.z,kind,position.x,position.y,position.z,state.get("range",1)*state.get("range",1),0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,state.get("inverse",1),state.get("factor",0),0,0]))
	result.append_array(PackedFloat32Array([reflection.x,reflection.y,reflection.z,0]))
	if normal==Vector3.FORWARD: normal=Vector3(0,0,1)
	for n in 3: result[24+n]=normal[n]; result[32+n]=Policy.linear(float(area_ambient[n])); result[36+n]=Policy.linear(float(area_diffuse[n]))
	return result
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original shader catalog mounts read-only")
	var original:=Original.new()
	var world:=Node3D.new(); root.add_child(world); world.add_child(Palette.new())
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color.BLACK; environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.BLACK; environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world.add_child(environment)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.make_current()
	var surface:=MeshInstance3D.new(); surface.mesh=QuadMesh.new(); world.add_child(surface)
	var source:=StandardMaterial3D.new(); var diffuse:=[.7,.5,.3]; var ambient:=[.4,.6,.8]; var emission:=[.03,.02,.01]
	source.albedo_color=Color(diffuse[0],diffuse[1],diffuse[2])
	var texture_image:=Image.create(1,1,false,Image.FORMAT_RGBA8); texture_image.fill(Color(.6,.4,.2,1)); source.albedo_texture=ImageTexture.create_from_image(texture_image)
	var raw:=texture_image.get_pixel(0,0); var tex:=Policy.linear_rgb([raw.r,raw.g,raw.b])
	var material:=NativeMaterial.new(); material.configure(source,ambient,emission,true,2); surface.material_override=material
	Palette.ambient(Vector3.ZERO)
	var positions:=[Vector3(0,0,2),Vector3(1,0,2),Vector3(2,0,.1),Vector3(2,0,-.2),Vector3(2,0,-1)]
	var reflection:=Vector3.ZERO
	for reflect_raw in [Color.BLACK,Color(.4,.6,.8)]:
		var reflection_image:=Image.create(1,1,false,Image.FORMAT_RGBA8); reflection_image.fill(reflect_raw); Palette.environment(ImageTexture.create_from_image(reflection_image))
		var reflect_texel:=reflection_image.get_pixel(0,0); reflection=Policy.linear_rgb([reflect_texel.r,reflect_texel.g,reflect_texel.b])
		for quality in [1,2]:
			material.standard_quality=quality
			for kind in [0,2]:
				for point in positions:
					var color:=[.7,.5,.9]; var props:={"color":color,"radius":4,"ambientonly":1 if kind==2 else 0}; var state:=Policy.point(props)
					var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure(props); world.add_child(light); light.position=point; light.force_update_transform()
					var expected:=original.execute(catalog,quality,inputs(tex,diffuse,ambient,emission,1.0,kind,color,point,state,reflection))
					check(original.failure.is_empty() and expected.size()==4,"Original unmodified shader functions execute quality "+str(quality)+" "+original.failure)
					if expected.size()!=4: light.free(); original.close(); world.free(); quit(1); return
					close_color(await capture(),Vector3(expected[0],expected[1],expected[2]),"Original fragment light quality/kind/position/environment "+str([quality,kind,point,reflect_raw]),.008)
					light.free()
		var area_ambient:=[.3,.4,.5]; var area_diffuse:=[.4,.3,.2]; Palette.ambient(Policy.linear_rgb(area_ambient))
		var sun:=DirectionalLight3D.new(); var sun_color:=Policy.linear_rgb(area_diffuse); sun.light_color=Color(sun_color.x,sun_color.y,sun_color.z).linear_to_srgb(); world.add_child(sun)
		for quality in [1,2]:
			material.standard_quality=quality
			var expected:=original.execute(catalog,quality,inputs(tex,diffuse,ambient,emission,1.0,3,[0,0,0],Vector3.ZERO,{},reflection,Vector3(0,0,1),area_ambient,area_diffuse))
			close_color(await capture(),Vector3(expected[0],expected[1],expected[2]),"Original area diffuse/ambient and indirect environment "+str([quality,reflect_raw]),.008)
		sun.free(); Palette.ambient(Vector3.ZERO)
	material.standard_quality=2
	var copy:=material.duplicate(); check(copy.standard_specular and copy.standard_quality==2,"Private copies preserve native standard-light shader selection")
	surface.material_override=copy; copy.publish_native_pose(Color(.3,.6,.9,.4),Color.BLACK,true)
	check(copy.standard_specular and material.transparency!=copy.transparency,"Animated color/alpha keeps standard-light inputs private")
	var color:=[.4,.7,.8]; var point:=Vector3(0,0,2); var props:={"color":color,"radius":4}; var state:=Policy.point(props)
	var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure(props); world.add_child(light); light.position=point; light.force_update_transform()
	for quality in [1,2]:
		copy.standard_quality=quality
		for angle in [0.0,.7,1.2]:
			surface.rotation.y=angle
			var normal:=Vector3(sin(angle),0,cos(angle)); var expected:=original.execute(catalog,quality,inputs(tex,[.3,.6,.9],ambient,[0,0,0],.4,0,color,point,state,reflection,normal))
			close_color(await capture(),Vector3(expected[0],expected[1],expected[2])*expected[3],"Original alpha/specular compensation and translucence "+str([quality,angle]),.009)
	light.free(); copy=null; original.close(); world.free(); material=null; source=null; Palette.environment(null)
	for frame in 3: await process_frame
	check(Palette.active.is_empty(),"Standard-light fixture releases all palette ownership")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"original_shader_sha256":original.hashes,"publicConnections":0,"scope":"GPU pixels versus runtime execution of selected retail override shader functions: ordinary unmapped fragment-lit materials, quality 1/2, area/diffuse/ambient lamps, explicit constant environment inputs and alpha. No original final fog/output-transfer, directional environment sampling, mapped/cube, quality-0 vertex or matched-room performance acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
