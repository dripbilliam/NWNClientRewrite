extends "res://tests/native_particle_stream_world_test.gd"
const Gamma=preload("res://systems/native_render/native_gamma.gd")
const Settings=preload("res://systems/native_render_settings.gd")
var samples: Array=[]
func compare_gamma(before: Image,after: Image,value: float,label: String) -> void:
	var worst:=0.0; var measured:=0
	for y in range(36,before.get_height()-8,3):
		for x in range(8,before.get_width()-8,3):
			var color:=before.get_pixel(x,y); var actual:=after.get_pixel(x,y)
			for component in 3:
				var expected:=1.0 if value==0 else pow(float(color[component]),value/2.2)
				worst=maxf(worst,absf(float(actual[component])-expected))
			measured+=1
	check(measured>500 and worst<.018,label+" max error "+str(worst))
	samples.append({"name":label,"gamma":value,"samples":measured,"max_error":worst})
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	root.size=Vector2i(256,256)
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,1,6); camera.look_at(Vector3(0,.5,0)); camera.current=true
	var base:=Compositor.new(); var unrelated:=CompositorEffect.new(); unrelated.enabled=false; base.compositor_effects=[unrelated]; camera.compositor=base
	var gamma:=Gamma.new(); root.add_child(gamma); gamma.attach(camera)
	var environment:=WorldEnvironment.new(); world.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(.08,.12,.16); environment.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var quad:=MeshInstance3D.new(); quad.mesh=QuadMesh.new(); quad.mesh.size=Vector2(3,3); quad.position=Vector3(-.5,.5,-.5); world.add_child(quad)
	var material:=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color(.1,.2,.3); quad.material_override=material
	var translucent:=MeshInstance3D.new(); translucent.mesh=QuadMesh.new(); translucent.position=Vector3(-.8,.3,1); world.add_child(translucent)
	var blend:=StandardMaterial3D.new(); blend.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; blend.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; blend.albedo_color=Color(.5,.2,.1,.4); translucent.material_override=blend
	var layer:=CanvasLayer.new(); root.add_child(layer); var ui:=ColorRect.new(); layer.add_child(ui); ui.position=Vector2(8,8); ui.size=Vector2(24,24); ui.color=Color(.4,.2,.8)
	make_emitter(world,"Fountain",false,2); await settle(35)
	var group: Node=world.particle_stream_group
	check(is_instance_valid(group) and group.fast_members==1 and group.renderer.call("dispatch",2,{}).draws>0,"Native shared particles draw in gamma fixture")
	world.process_mode=Node.PROCESS_MODE_DISABLED; await settle()
	check(camera.compositor.compositor_effects==[unrelated,group.effect,gamma.effect],"Particle pass sorts before final color even when admitted later")
	var neutral:=root.get_texture().get_image(); var unchanged_ui:=neutral.get_pixel(16,16)
	check(gamma.snapshot().passes==0,"Neutral native Gamma performs no GPU pass")
	for value in [1.0,1.2,1.8,3.0,0.0,1000.0]:
		gamma.set_gamma(value); await settle()
		var image:=root.get_texture().get_image(); compare_gamma(neutral,image,value,"Original display-space gamma over world, transparency and particles")
		check(image.get_pixel(16,16)==unchanged_ui,"Gamma preserves later GUI colors at "+str(value))
	check(gamma.snapshot().failure.is_empty() and gamma.snapshot().passes>0,"Real native gamma GPU pipeline executes without failure")
	gamma.set_gamma(2.2); await settle(); var stopped: int=gamma.snapshot().passes; await settle()
	check(neutral.get_data()==root.get_texture().get_image().get_data() and gamma.snapshot().passes==stopped,"Neutral restores exact original pixels and stops dispatching")
	root.msaa_3d=Viewport.MSAA_2X; root.size=Vector2i(239,193); await settle(6)
	var msaa:=root.get_texture().get_image(); gamma.set_gamma(1.2); await settle()
	compare_gamma(msaa,root.get_texture().get_image(),1.2,"MSAA resolve, target resize and partial compute groups preserve gamma")
	gamma.attach(null)
	check(camera.compositor.compositor_effects==[unrelated,group.effect],"Removing final color preserves a live particle pass")
	gamma.attach(camera)
	check(camera.compositor.compositor_effects==[unrelated,group.effect,gamma.effect],"Late final-color admission preserves the required order")
	world.close(); await settle()
	check(camera.compositor.compositor_effects==[unrelated,gamma.effect],"Area retirement cannot remove or duplicate the retained gamma owner")
	gamma.attach(null); check(camera.compositor==base,"Last owned removal restores the exact pre-existing compositor")
	check(gamma.snapshot().failure.is_empty(),"Framebuffer resize and owner retirement have no gamma failure")
	var menu:=Settings.new(); layer.add_child(menu); menu.setup(path+".cfg","")
	check(menu.gamma_value==2.2 and menu.gamma_control.value==2.2,"Client Gamma defaults neutral without reading or changing original profiles")
	var changes: Array=[]; menu.gamma_changed.connect(func(value):changes.append(value))
	menu.gamma_control.value=1.2
	var saved:=Settings.new(); layer.add_child(saved); saved.setup(path+".cfg","")
	check(is_equal_approx(saved.gamma_value,1.2) and changes==[1.2],"Gamma control persists and emits immediately")
	var config:=ConfigFile.new(); config.set_value("rendering","gamma","invalid"); config.save(path+".bad.cfg")
	var invalid:=Settings.new(); layer.add_child(invalid); invalid.setup(path+".bad.cfg","")
	check(invalid.gamma_value==2.2,"Malformed saved gamma cannot poison rendering")
	var state: Dictionary=gamma.snapshot(); gamma.free(); world.free(); layer.free(); await settle()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"gamma":state,"publicConnections":0,"scope":"Real GPU display-space native Gamma equation with scene alpha, shared particles, MSAA, resize, neutral bypass, independent compositor retirement and settings persistence. Bounded colors under linear tonemapping; not full native fog/HDR/vision or matched-room acceptance."}
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
