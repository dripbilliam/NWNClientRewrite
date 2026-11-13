extends "res://tests/native_particle_output_pixels_test.gd"
const PointLight=preload("res://systems/native_render/model_point_light.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256); var catalog:=ParticleCatalog.new(); check(catalog.mount_install(install),"Original catalog mounts for real-world particle output")
	var world:=LiveWorld.new(); world.set_meta("native_surface_output",true); world.set_meta("native_enhanced_lighting",true); root.add_child(world); world.set_process(false)
	var group: Node=world.particle_stream_group
	check(group!=null and group.native_surface_output and group.scene_batches==null,"Actual shared world selects CPU-tinted native particle output, without engine-lit batches")
	if group==null: world.free(); quit(1); return
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16; camera.current=true
	var bg:=Vector3(.025,.04,.07); var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(bg.x,bg.y,bg.z).linear_to_srgb(); environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; environment.environment.fog_enabled=true; environment.environment.fog_mode=Environment.FOG_MODE_DEPTH; environment.environment.fog_depth_begin=2; environment.environment.fog_depth_end=10; environment.environment.fog_light_color=Color(.1,.2,.4); environment.environment.fog_sun_scatter=0; environment.environment.fog_aerial_perspective=0
	# Godot replaces a flat fog-enabled background with its linear fog color.
	# Use an explicit fog-disabled native-gamma backdrop as the service boundary;
	# native sky/background integration remains separate from this particle test.
	environment.environment.fog_sky_affect=0
	var backdrop:=MeshInstance3D.new(); var quad:=QuadMesh.new(); quad.size=Vector2(32,32); backdrop.mesh=quad; backdrop.position.z=-1; world.add_child(backdrop)
	var backdrop_shader:=Shader.new(); backdrop_shader.code="shader_type spatial;render_mode unshaded,fog_disabled;void fragment(){ALBEDO=vec3(.025,.04,.07);}"
	var backdrop_material:=ShaderMaterial.new(); backdrop_material.shader=backdrop_shader; backdrop.material_override=backdrop_material
	world.focus_lighting.enable_history(); world.focus_lighting.focus=Vector3(5,0,0); world.focus_lighting.set_area([.1,.05,.02],[.02,.03,.04])
	var actor:=Node3D.new(); actor.set_meta("native_light_source",true); world.add_child(actor); actor.position=Vector3(5,0,0); world.focus_lighting.set_controlled(actor)
	var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure({"color":[.5,.6,.7],"radius":10,"fadinglight":0}); actor.add_child(light); light.position=Vector3(0,2,0); light.force_update_transform()
	var gamma:=Gamma.new(); root.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color(.2,.4,.6,.7)); var texture:=ImageTexture.create_from_image(image); var texel:=image.get_pixel(0,0)
	var emitter:=particle(world,texture,false,.6,true); await settle(20)
	check(group.failure.is_empty() and emitter.failure.is_empty() and group.fast_members==1,"Actual emitter joins and draws through the native shared world")
	world.focus_lighting.refresh(); var input: Dictionary=world.focus_lighting.particle_lighting(); input.point=[5,0,0]
	check(input.lights.size()==1 and world.focus_lighting.excluded_lights==1,"Particle sample includes the attached lamp that the vision gate correctly excludes")
	var expected_tint:=LightSample.sample(input); var snapshot: Dictionary=group.native.call("dispatch",2,{})
	check(snapshot.buffer.size()==6*24,"Actual CPU-tinted world publishes one active particle")
	if snapshot.buffer.size()!=6*24: gamma.free(); world.close(); world.free(); quit(1); return
	var tint:=Color(float(snapshot.buffer[0])/255,float(snapshot.buffer[1])/255,float(snapshot.buffer[2])/255,float(snapshot.buffer[3])/255); var base:=[.8,.3,.1]
	for n in 3: check(absf(tint[n]-base[n]*expected_tint[n])<=1.01/255,"Actual registry/admission/area data reaches packed tint "+str(n))
	var original:=ParticleOracle.new(); var data:=PackedFloat32Array([texel.r,texel.g,texel.b,texel.a,tint.r,tint.g,tint.b,tint.a,.1,.2,.4,.375,bg.x,bg.y,bg.z,2.2,0,0,100,-5])
	var expected: PackedFloat32Array=original.execute(catalog,0,data); check(expected.size()==4 and original.failure.is_empty(),"Original particle output oracle executes for the actual world: "+original.failure)
	if expected.size()==4:
		var actual:=image_pixel(camera); var error:=maxf(absf(actual.r-expected[0]),maxf(absf(actual.g-expected[1]),absf(actual.b-expected[2])))
		check(error<.009,"Actual world pixel follows native CPU tint, gamma-space view-depth fog and final output: "+str(error))
	check(group.renderer.call("dispatch",2,{}).error==0 and gamma.snapshot().failure.is_empty(),"Actual native world has no GPU color-carrier mismatch")
	world.process_mode=Node.PROCESS_MODE_DISABLED; await settle(); var before:=root.get_texture().get_image(); var rng_before: int=world.get_meta("native_particle_random").draws
	emitter.get_parent().hide(); await settle(); var hidden:=image_pixel(camera)
	check(absf(hidden.r-bg.x)<.005 and absf(hidden.g-bg.y)<.005 and absf(hidden.b-bg.z)<.005,"Paused visibility publication retains native color carrier and hides the source")
	emitter.get_parent().show(); await settle(); check(before.get_data()==root.get_texture().get_image().get_data(),"Restoring a paused original-color packet restores exact frozen pixels")
	check(world.get_meta("native_particle_random").draws==rng_before,"Visibility/color publication consumes no simulation RNG")
	var state: Dictionary=group.snapshot(); var lighting: Dictionary=world.focus_lighting.snapshot(); world.close(); await settle()
	check(camera.compositor.compositor_effects==[gamma.effect],"Native area retirement preserves only the independent final output owner")
	gamma.free(); world.free(); original.close(); await settle(4); texture=null
	check(Palette.active.is_empty(),"Actual native-output world retires its physical lamp slots")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"group":state,"lighting":lighting,"shader_sha256":original.hashes,"publicConnections":0,"scope":"Actual LiveWorld shared native particle output with original CPU tint, physical registry, native admission, area channels, attached-light exclusion distinction, real GPU pixel/fog comparison, paused visibility/RNG and independent retirement. No full-world/fallback/soft-depth or matched dense-room acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
