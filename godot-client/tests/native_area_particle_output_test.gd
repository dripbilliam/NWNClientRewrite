extends "res://tests/native_particle_world_output_test.gd"
const ActualArea=preload("res://systems/area_environment.gd")
const SurfaceState=preload("res://systems/native_render/native_surface_state.gd")
func run() -> void:
	var report:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report): quit(2);return
	root.size=Vector2i(256,256);var catalog:=ParticleCatalog.new();check(catalog.mount_install(install),"Original particle catalog mounts read-only")
	var world:=LiveWorld.new();world.set_meta("native_surface_output",true);world.set_meta("native_enhanced_lighting",true);root.add_child(world);world.set_process(false)
	var group: Node=world.particle_stream_group
	check(group!=null and group.native_surface_output,"Actual shared world selects native output")
	if group==null:world.close();world.free();quit(1);return
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;camera.current=true
	var area:=ActualArea.new();world.add_child(area);area.configure({},world);area.camera=camera;area.set_process(false)
	var fields:={"98":0,"9c":0,"a0":0,"a4":0,"a8":false,"b8":0x050d1a,"bc":0x0a0805,"c0":0x66331a,"c4":28,"c8":false,"d8":true,"dc":false,"e0":0,"104":0,"108":10}
	check(area.receive({"revision":1,"state":{"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}}),"Actual area admits raw fog and both particle lighting channels")
	check(not area.environment.fog_enabled and SurfaceState.authoritative(world),"Particle world uses authoritative raw fog with engine fog disabled")
	var light:=PointLight.new();light.set_meta("native_enhanced_light",true);light.configure({"color":[.5,.6,.7],"radius":10});world.add_child(light);light.position=Vector3(5,2,0);light.force_update_transform()
	var gamma:=Gamma.new();root.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true)
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8);image.fill(Color(.2,.4,.6,.7));var texture:=ImageTexture.create_from_image(image);var texel:=image.get_pixel(0,0)
	var original:=ParticleOracle.new();var observations: Array=[]
	for additive in [false,true]:
		var emitter:=particle(world,texture,additive,.6,true);await settle(12)
		check(emitter.failure.is_empty() and group.failure.is_empty(),"Actual emitter publishes through shared area lighting")
		var packet: Array=SurfaceState.packet(world);var native: Dictionary=group.native.call("dispatch",2,{})
		check(native.buffer.size()==6*24 and packet[7]==3.0,"Actual CPU tint and authoritative area fog remain available")
		if native.buffer.size()!=6*24:emitter.get_parent().free();continue
		var tint:=Color(float(native.buffer[0])/255,float(native.buffer[1])/255,float(native.buffer[2])/255,float(native.buffer[3])/255)
		var sample: Dictionary=world.focus_lighting.particle_lighting();sample.point=[5,0,0];var expected_tint:=LightSample.sample(sample)
		for n in 3:check(absf(tint[n]-[.8,.3,.1][n]*expected_tint[n])<=1.01/255,"Actual area/physical light sample reaches packed tint "+str(n))
		for value in [2.2,1.2]:
			gamma.set_gamma(value);await settle()
			var fog_amount: float=(5.0-float(packet[4]))*float(packet[6])
			var data:=PackedFloat32Array([texel.r,texel.g,texel.b,texel.a,tint.r,tint.g,tint.b,tint.a,packet[0],packet[1],packet[2],fog_amount,packet[0],packet[1],packet[2],value,1 if additive else 0,0,100,-5])
			var expected: PackedFloat32Array=original.execute(catalog,0,data);check(expected.size()==4 and original.failure.is_empty(),"Original particle/fog/output functions execute against actual area")
			if expected.size()!=4:continue
			var actual:=image_pixel(camera);var error:=0.0
			for n in 3:error=maxf(error,absf(actual[n]-clampf(expected[n],0,1)))
			check(error<.009,"Actual raw background plus shared particle/fog/Gamma pixel matches original: "+str(error))
			observations.append({"additive":additive,"gamma":value,"actual":[actual.r,actual.g,actual.b],"expected":Array(expected.slice(0,3)),"max_error":error})
		check(SurfaceState.packet(world)==packet,"Shared camera fallback preserves the authoritative raw area packet")
		emitter.get_parent().free();await settle(4)
	check(gamma.snapshot().failure.is_empty(),"Combined native area and particle final output has no GPU failure")
	var state: Dictionary=group.snapshot();gamma.free();world.close();world.free();original.close();texture=null;await settle(4)
	check(SurfaceState.snapshot().owner==0 and Palette.active.is_empty(),"Combined native area, particle and lamp owners retire cleanly")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":observations,"group":state,"publicConnections":0,"scope":"Actual LiveWorld shared CPU-tinted particles against actual AreaEnvironment raw world fog and flat background, with Godot fog disabled, normal/additive blends and Gamma; original installed shader execution. No isolated backdrop, soft depth or matched dense-room acceptance; research carrier only."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
