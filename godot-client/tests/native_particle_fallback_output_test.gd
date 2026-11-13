extends "res://tests/native_particle_world_output_test.gd"
const SurfaceState=preload("res://systems/native_render/native_surface_state.gd")
const Quant=preload("res://systems/native_render/particle_math.gd")
const FallbackInstances=preload("res://systems/particle_instance_surface.gd")
func make_fallback(world: Node3D,texture: Texture2D,reference: bool,lit: bool,additive: bool) -> Node3D:
	var part:=Node3D.new(); world.add_child(part); part.position=Vector3(5,0,0)
	var out:=Emitter.new(); out.force_reference=reference; out.source_path=NodePath(".."); out.source_model_flags=0
	out.original_properties={"update":"Single","render":"Normal","blend":"Lighten" if additive else "Normal","flags":8 if lit else 0,"birthrate":1.0,"lifeexp":1.0,"loop":1,"velocity":0.0,"randvel":0.0,"spread":0.0,"mass":0.0,"xsize":0.0,"ysize":0.0,"sizestart":2.0,"sizeend":2.0,"alphastart":.6,"alphaend":.6,"colorstart":[.8,.3,.1],"colorend":[.8,.3,.1],"fps":0.0,"framestart":0.0,"frameend":0.0,"xgrid":1,"ygrid":1}
	out.original_texture=texture; part.add_child(out); return out
func run() -> void:
	var report:=""; var install:=""; var gd_only:=false; var expect_instances:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg=="--particle-kernel=gd": gd_only=true
		if arg=="--particle-streams=instances": expect_instances=true
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256); var catalog:=ParticleCatalog.new(); check(catalog.mount_install(install),"Original catalog mounts for fallback pixel comparison")
	var original:=ParticleOracle.new(); var world:=LiveWorld.new(); world.set_meta("native_surface_output",true); world.set_meta("native_enhanced_lighting",true); root.add_child(world); world.set_process(false)
	check(world.particle_stream_group==null,"Fallback fixture uses its real per-emitter paths")
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16; camera.current=true
	var bg:=Vector3(.025,.04,.07); var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color.BLACK; environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR; environment.environment.fog_enabled=true; environment.environment.fog_mode=Environment.FOG_MODE_DEPTH; environment.environment.fog_depth_begin=2; environment.environment.fog_depth_end=10; environment.environment.fog_light_color=Color(.1,.2,.4); environment.environment.fog_sun_scatter=0; environment.environment.fog_aerial_perspective=0
	var backdrop:=MeshInstance3D.new(); var quad:=QuadMesh.new(); quad.size=Vector2(32,32); backdrop.mesh=quad; backdrop.position.z=-1; world.add_child(backdrop)
	var backdrop_shader:=Shader.new(); backdrop_shader.code="shader_type spatial;render_mode unshaded,fog_disabled;void fragment(){ALBEDO=vec3(.025,.04,.07);}"; var backdrop_material:=ShaderMaterial.new(); backdrop_material.shader=backdrop_shader; backdrop.material_override=backdrop_material
	world.focus_lighting.set_area([.1,.05,.02],[.02,.03,.04])
	var light:=PointLight.new(); light.set_meta("native_enhanced_light",true); light.configure({"color":[.5,.6,.7],"radius":10}); world.add_child(light); light.position=Vector3(5,2,0); light.force_update_transform()
	var gamma:=Gamma.new(); root.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color(.2,.4,.6,.7)); var texture:=ImageTexture.create_from_image(image); var texel:=image.get_pixel(0,0); var samples: Array=[]
	var variants: Array=[true] if gd_only else [true,false]
	for reference in variants:
		for lit in [false,true]:
			for additive in [false,true]:
				var emitter:=make_fallback(world,texture,reference,lit,additive); await settle(12)
				check(emitter.failure.is_empty() and emitter.native_surface_output and emitter.surface.native_surface_output and emitter.surface.vertex_count==6,"Actual fallback publishes one native-carrier particle")
				check((emitter.native_owner!=null)==(not reference and not gd_only),"Actual fallback backend matches the requested ownership")
				if not reference: check((emitter.surface is FallbackInstances)==expect_instances,"Actual resident selects the requested surface ABI")
				var lighting: Dictionary=world.focus_lighting.particle_lighting(); lighting.point=[5,0,0]; var shade:=LightSample.sample(lighting) if lit else Vector3.ONE; var tint:=PackedFloat32Array()
				var base:=[.8,.3,.1]
				for n in 3: tint.append(int(Quant.f(clampf(Quant.f(Quant.f(base[n])*shade[n]),0,1)*255.99000549316406))/255.0)
				tint.append(int(Quant.f(Quant.f(.6)*255.99000549316406))/255.0)
				for amount in [-.1,.25,.75,1.1]:
					var begin: float=5-float(amount)*8; var end: float=begin+8
					if begin>environment.environment.fog_depth_end: environment.environment.fog_depth_end=end
					environment.environment.fog_depth_begin=begin; environment.environment.fog_depth_end=end
					for value in [2.2,1.2]:
						gamma.set_gamma(value); await settle(6)
						var data:=PackedFloat32Array([texel.r,texel.g,texel.b,texel.a,tint[0],tint[1],tint[2],tint[3],.1,.2,.4,amount,bg.x,bg.y,bg.z,value,1 if additive else 0,0,100,-5])
						var expected: PackedFloat32Array=original.execute(catalog,0,data); check(expected.size()==4 and original.failure.is_empty(),"Original fragment oracle executes: "+original.failure)
						if expected.size()!=4: quit(1); return
						var actual:=image_pixel(camera); var error:=0.0
						for n in 3: error=maxf(error,absf(actual[n]-clampf(expected[n],0,1)))
						check(error<.009,"Fallback original texel/tint/fog/blend "+str([reference,lit,additive,amount,value])+" error="+str(error))
						samples.append({"reference":reference,"lit":lit,"additive":additive,"amount":amount,"gamma":value,"actual":[actual.r,actual.g,actual.b],"expected":Array(expected.slice(0,3)),"max_error":error})
				emitter.retire(); emitter.get_parent().free(); await settle(4)
	check(gamma.snapshot().failure.is_empty() and SurfaceState.snapshot().failure.is_empty(),"Fallback GPU/global publication remains valid")
	var state:=SurfaceState.snapshot(); world.close(); gamma.free(); world.free(); original.close(); await settle(4); texture=null
	check(SurfaceState.active_id==0 and Palette.active.is_empty(),"Fallback world releases native fog and physical lamp ownership")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"gd_only":gd_only,"instances":expect_instances,"state":state,"shader_sha256":original.hashes,"publicConnections":0,"scope":"Real GD/stateless and resident ArrayMesh/MultiMesh fallback particles versus unchanged original fsparticle/fog/Gamma/tonemap. Native CPU tint, raw texels, off-axis view-depth fog and both blends; not soft-depth, actual alpha-threshold binding, full world or room performance acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
