extends "res://tests/native_surface_output_pixels_test.gd"
const SkyOwner=preload("res://systems/area_sky.gd")
const SkyOriginal=preload("res://tests/original_sky_output_oracle.gd")
func run() -> void:
	var report:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2);return
	root.size=Vector2i(256,256);selected_catalog=Catalog.new();check(selected_catalog.mount_install(install),"Original sky shader catalog mounts read-only")
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();world.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var background:=Vector3(.03,.07,.11);env.environment.background_color=Color(background.x,background.y,background.z).linear_to_srgb()
	var camera:=Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.current=true;camera.near=.01;camera.far=3
	var gamma:=Gamma.new();world.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true)
	var original:=SkyOriginal.new();var surface:=MeshInstance3D.new();world.add_child(surface);var material:=ShaderMaterial.new();material.shader=SkyOwner._shader(true);surface.material_override=material
	var colors:=PackedColorArray([Color(.2,.4,.6,.4),Color(.8,.2,.4,.8),Color(.4,.8,.2,.6)])
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-4,-4,-2),Vector3(4,-4,-2),Vector3(0,4,-2)]);arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN])
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);surface.mesh=mesh
	# Pixel-center orthographic barycentrics. Vertex colors are byte attributes;
	# use exact UNORM8 inputs rather than assuming the original floats survive.
	var packed: PackedColorArray=mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var bary:=Vector3(.24951171875,.25146484375,.4990234375)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.6,.8));var texture:=ImageTexture.create_from_image(image);var texel:=image.get_pixel(0,0)
	material.set_shader_parameter("original_texture",texture)
	for horizon in [false,true]:
		for tint in [false,true]:
			for textured in [false,true]:
				for weight in [.25,1.0]:
					for value in [2.2,1.2]:
						var raw:=Color(.1,.3,.7,1.0) if horizon else Color(1,1,1,.6)
						material.set_shader_parameter("horizon",horizon);SkyOwner.color_parameter(material,"horizon_color",raw,true);SkyOwner.color_parameter(material,"original_color",raw,true);material.set_shader_parameter("vertex_tint",tint);material.set_shader_parameter("textured",textured);material.set_shader_parameter("sky_weight",weight);gamma.set_gamma(value)
						var data:=PackedFloat32Array()
						for c in packed: data.append_array(PackedFloat32Array([c.r,c.g,c.b,c.a]))
						data.append_array(PackedFloat32Array([bary.x,bary.y,bary.z,0,raw.r,raw.g,raw.b,raw.a,texel.r,texel.g,texel.b,texel.a,background.x,background.y,background.z,0,value,weight,1 if textured else 0,1 if tint else 0]))
						var expected: PackedFloat32Array=original.execute(selected_catalog,0,data)
						check(expected.size()==4 and original.failure.is_empty(),"Unchanged original sky entries and shader functions execute: "+original.failure)
						if expected.size()!=4: continue
						var actual:=await capture();var worst:=0.0
						for n in 3: worst=maxf(worst,absf(actual[n]-expected[n]))
						var label:=str([horizon,tint,textured,weight,value]);check(worst<.009,"Native sky vertex interpolation, tint, blend and output "+label+" error="+str(worst))
						output_samples.append({"case":label,"actual":[actual.r,actual.g,actual.b],"expected":Array(expected.slice(0,3)),"maximum_error":worst})
	check(gamma.snapshot().passes>0 and gamma.snapshot().failure.is_empty(),"Actual final native output executes for sky")
	var hashes: Dictionary=original.hashes.duplicate();original.close();world.free();texture=null;material=null;mesh=null
	for frame in 3: await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":output_samples,"original_shader_sha256":hashes,"publicConnections":0,"scope":"Actual native-output sky shader GPU versus unchanged original vsvtc/fstc/retail inc_standard functions, explicit texel/orthographic rasterizer/CPU global-color boundaries: vertex-color pre-interpolation, sky and horizon tint, texture, alpha weight, Gamma. Synthetic geometry; no original sky resource/native-loader or matched-room acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
