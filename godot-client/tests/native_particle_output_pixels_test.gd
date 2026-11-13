extends "res://tests/native_particle_stream_world_test.gd"
const ParticleCatalog=preload("res://systems/native_data/resource_catalog.gd")
const ParticleOracle=preload("res://tests/original_particle_output_oracle.gd")
const ParticleEffect=preload("res://systems/native_render/particle_stream_effect.gd")
const ParticleBounds=preload("res://systems/native_render/particle_bounds.gd")
const Gamma=preload("res://systems/native_render/native_gamma.gd")
const Stack=preload("res://systems/native_render/camera_effects.gd")
const LightSample=preload("res://systems/native_render/focus_light_sample.gd")
class Driver extends Node:
	var presentation: RefCounted
	var renderer: RefCounted
	var camera: Camera3D
	var fog: Array=[0,0,0,0,0,1,1,0]
	var lighting: Dictionary={}
	var failure:=""
	func _process(_delta: float) -> void:
		var result: Dictionary=presentation.call("dispatch",1,{"delta":1.0/60,"view":ParticleBounds.native_view(camera,false),"fog":fog,"native_surface_output":true,"lighting":lighting})
		if not result.has("error"): result=renderer.call("dispatch",1,{})
		if result.has("error"): failure=str(result.error); set_process(false)
func particle(world: Node3D,texture: Texture2D,additive: bool,opacity: float=.6,lit: bool=false) -> Node3D:
	var part:=Node3D.new(); world.add_child(part); part.position=Vector3(5,0,0)
	var out:=Emitter.new(); out.source_path=NodePath(".."); out.source_model_flags=0
	out.original_properties={"update":"Single","render":"Normal","blend":"Lighten" if additive else "Normal","flags":0,"birthrate":1.0,"lifeexp":1.0,"loop":1,"velocity":0.0,"randvel":0.0,"spread":0.0,"mass":0.0,"xsize":0.0,"ysize":0.0,"sizestart":2.0,"sizeend":2.0,"alphastart":opacity,"alphaend":opacity,"colorstart":[.8,.3,.1],"colorend":[.8,.3,.1],"fps":0.0,"framestart":0.0,"frameend":0.0,"xgrid":1,"ygrid":1}
	if lit: out.original_properties.flags=8
	out.original_texture=texture; part.add_child(out); out.set_process(false); out.surface.retire(); return out
func image_pixel(camera: Camera3D) -> Color:
	var image:=root.get_texture().get_image()
	return image.get_pixel(int(image.get_width()/2+5*image.get_height()/camera.size),image.get_height()/2)
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256); var catalog:=ParticleCatalog.new(); check(catalog.mount_install(install),"Original particle shader catalog mounts read-only")
	var original:=ParticleOracle.new(); var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	check(world.particle_stream_group==null,"Isolated particle fixture does not select the normal world shared owner")
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=16; camera.current=true
	var bg:=Vector3(.025,.04,.07); var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(bg.x,bg.y,bg.z).linear_to_srgb(); environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation"); var renderer: RefCounted=ClassDB.instantiate("NwnParticleStreamRender")
	check(not renderer.call("dispatch",0,{"presentation":presentation,"native_surface_output":true,"alpha_discard":.2}).has("error"),"Shared native GPU renderer selects original particle color carrier")
	var effect:=ParticleEffect.new(); effect.configure(renderer); Stack.install(camera,effect)
	var gamma:=Gamma.new(); world.add_child(gamma); gamma.attach(camera); gamma.effect.set_surface_output(true)
	var driver:=Driver.new(); driver.presentation=presentation; driver.renderer=renderer; driver.camera=camera; world.add_child(driver)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color(.2,.4,.6,.7)); var texture:=ImageTexture.create_from_image(image); var texel:=image.get_pixel(0,0)
	var samples: Array=[]
	for variant in [{"lit":false,"additive":false},{"lit":false,"additive":true},{"lit":true,"additive":false},{"lit":true,"additive":true}]:
		var additive: bool=variant.additive; var lit: bool=variant.lit
		driver.lighting={"lights":[{"position":[5,0,2],"color":[.5,.6,.7],"radius":10,"fade":.8}],"ambient":{"color":[.1,.05,.02],"fade":.7},"diffuse":{"color":[.02,.03,.04],"fade":.5}}
		var emitter:=particle(world,texture,additive,.6,lit)
		check(not presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":emitter.native_owner,"providers":emitter.providers,"source_flags":0,"culling":false,"texture":texture,"additive":additive,"two_sided":false,"lighting":lit}).has("error"),"Original emitter registers with active native geometry")
		await settle(12)
		var snapshot: Dictionary=presentation.call("dispatch",2,{})
		check(snapshot.buffer.size()==6*24,"One original particle publishes the active 24-byte vertex stream")
		if snapshot.buffer.size()!=6*24: quit(1); return
		var tint:=Color(float(snapshot.buffer[0])/255,float(snapshot.buffer[1])/255,float(snapshot.buffer[2])/255,float(snapshot.buffer[3])/255)
		var sample_input: Dictionary=driver.lighting.duplicate(true); sample_input.point=[5,0,0]
		var native_tint:=LightSample.sample(sample_input) if lit else Vector3.ONE
		var base:=[.8,.3,.1]
		for n in 3: check(absf(tint[n]-base[n]*native_tint[n])<=1.01/255,"CPU sampled tint reaches original packed particle color "+str([lit,n]))
		for amount in [-.1,0.0,.25,.75,1.0,1.2]:
			var fog_color:=Vector3(.1,.2,.4); driver.fog=[fog_color.x,fog_color.y,fog_color.z,0,5-amount*8,5-amount*8+8,.125,3]
			for value in [2.2,1.2]:
				gamma.set_gamma(value); await settle(6)
				var input:=PackedFloat32Array([texel.r,texel.g,texel.b,texel.a,tint.r,tint.g,tint.b,tint.a,fog_color.x,fog_color.y,fog_color.z,amount,bg.x,bg.y,bg.z,value,1 if additive else 0,0.0,100.0,-5.0])
				var expected: PackedFloat32Array=original.execute(catalog,0,input)
				check(original.failure.is_empty() and expected.size()==4,"Unchanged original particle/fog/Gamma functions execute: "+original.failure)
				if expected.size()!=4: quit(1); return
				var actual:=image_pixel(camera); var error:=0.0
				for n in 3: error=maxf(error,absf(actual[n]-clampf(expected[n],0,1)))
				check(error<.009,"Native particle raw texture/tint, view-depth fog and blend "+str([additive,amount,value])+" error="+str(error))
				samples.append({"lit":lit,"additive":additive,"amount":amount,"gamma":value,"actual":[actual.r,actual.g,actual.b],"expected":Array(expected.slice(0,3)),"max_error":error})
		presentation.call("dispatch",3,{"id":emitter.get_instance_id()}); emitter.retire(); emitter.get_parent().free(); await settle()
	check(driver.failure.is_empty() and renderer.call("dispatch",2,{}).error==0,"Shared native particle frame/render callbacks remain valid")
	var stats: Dictionary=renderer.call("dispatch",2,{}); driver.set_process(false); Stack.remove(camera,effect); effect.close(); presentation.call("dispatch",5,{}); original.close(); world.close(); world.free(); await settle(4); texture=null; renderer=null; presentation=null
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"renderer":stats,"shader_sha256":original.hashes,"publicConnections":0,"scope":"Actual shared C++ particle raster versus unchanged original fsparticle/fog/Gamma/retail tonemap functions; raw texel and packed vertex inputs, CPU point-sampled tint, off-axis view-depth fog, normal/additive blending and negative/full fog boundaries. Full native-world integration, alpha-discard setting binding, soft depth and fallback families remain separate."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
