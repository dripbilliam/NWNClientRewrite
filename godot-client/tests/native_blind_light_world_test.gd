extends "res://tests/native_area_surface_output_test.gd"
func advance_lights(area,focus) -> void:
	for n in 35: area.advance(0);focus.history_frame(.1)
	area.advance(0)
func expected_surface(original,world,area,lights: Array) -> Vector3:
	var fades: Array=world.focus_lighting.history_result.area_fades
	var ambient: Array=area.sample.ambient.map(func(v):return Policy.f(v*float(fades[0][0])))
	var diffuse: Array=area.sample.diffuse.map(func(v):return Policy.f(v*float(fades[1][0])))
	var raw: PackedFloat32Array=original.execute(selected_catalog,2,inputs(Vector3.ONE,[.7,.5,.3],[.4,.6,.8],[0,0,0],1.0,3,[0,0,0],Vector3.ZERO,{},Vector3.ZERO,Vector3(0,0,1),ambient,diffuse))
	var result:=Vector3(raw[0],raw[1],raw[2]) if raw.size()==4 else Vector3.ZERO
	for light in lights:
		if not light.native_admitted:continue
		var properties: Dictionary=light.get_meta("native_model_light_properties")
		var state: Dictionary=Policy.point(properties,2.0,.2,1.5,light.native_fade)
		var faded: Array=properties.color.map(func(v):return Policy.f(v*light.native_fade))
		raw=original.execute(selected_catalog,2,inputs(Vector3.ONE,[.7,.5,.3],[.4,.6,.8],[0,0,0],1.0,0,faded,light.global_position,state))
		if raw.size()==4:result+=Vector3(raw[0],raw[1],raw[2])
	check(original.failure.is_empty() and raw.size()==4,"Original material functions execute for actual admitted lamp/area channels")
	return result
func run() -> void:
	var report:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--install="):install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	root.size=Vector2i(256,256);selected_catalog=Catalog.new();check(selected_catalog.mount_install(install),"Original native lighting catalog mounts read-only")
	var world:=LiveWorld.new();world.set_meta("native_enhanced_lighting",true);world.set_meta("native_surface_output",true);world.pool.native_lighting=true;world.pool.native_standard=true;world.pool.native_surface_output=true;root.add_child(world);world.set_process(false)
	var focus=world.focus_lighting;focus.set_process(false);focus.enable_history()
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.current=true
	var area:=Area.new();world.add_child(area);area.configure({},world);area.camera=camera;area.set_process(false)
	var fields:={"98":0,"9c":0,"a0":0,"a4":0,"a8":false,"b8":0x332211,"bc":0x223344,"c0":0x664422,"c4":28,"c8":false,"cc":0,"d0":-1,"d4":0,"d8":true,"dc":false,"e0":0,"104":0,"108":10}
	check(area.receive({"revision":1,"state":{"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}}),"Actual area admits lighting and depth fog")
	var actors: Array=[];var lights: Array=[]
	for color in [[.8,.1,.03],[.02,.3,.9],[.1,.7,.05]]:
		var actor:=Node3D.new();actor.set_meta("native_light_source",true);world.add_child(actor);actors.append(actor)
		var light:=PointLight.new();light.set_meta("native_enhanced_light",true);light.configure({"color":color,"radius":4});actor.add_child(light);light.position=Vector3(0,0,2);light.force_update_transform();lights.append(light)
	actors[2].set_meta("native_light_anchor",weakref(actors[0]))
	var static_source:=Node3D.new();static_source.set_meta("native_light_source",true);world.add_child(static_source)
	var static_light:=PointLight.new();static_light.set_meta("native_enhanced_light",true);static_light.configure({"color":[.3,.4,.5],"radius":4,"isdynamic":0,"affectdynamic":0});static_source.add_child(static_light);static_light.position=Vector3(20,0,2);static_light.force_update_transform()
	var surface:=MeshInstance3D.new();surface.mesh=QuadMesh.new();surface.material_override=world.pool.material({"mesh":{"diffuse":[.7,.5,.3],"ambient":[.4,.6,.8]}});world.add_child(surface)
	var gamma:=Gamma.new();root.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true)
	var original:=Original.new();var observations: Array=[];advance_lights(area,focus)
	var original_fog: Array=area.sample.fog.duplicate();var background:=Vector3(original_fog[0],original_fog[1],original_fog[2]);var clear_color:=area.environment.background_color
	check(lights.all(func(light):return light.native_admitted and light.native_fade==1.0) and static_light.native_admitted,"Baseline admits physical dynamic lights and retains the documented static-bake fallback")
	await compare_output(expected_surface(original,world,area,lights),1.0,background,.375,background,2.2,"Actual baseline world before only-Gob restriction")
	var outsider:=Node3D.new();root.add_child(outsider)
	check(not focus.set_blind_lights(outsider) and focus.only_light_owner()==0,"A different world's render object cannot become the restriction owner");outsider.free()
	var non_gob:=Node3D.new();world.add_child(non_gob);check(not focus.set_blind_lights(non_gob) and focus.only_light_owner()==0,"A physical part without a Gob light-owner identity cannot become the restriction owner");non_gob.free()
	for index in [0,2]:
		check(focus.set_blind_lights(actors[index]),"Exact physical render object becomes the native restriction owner")
		advance_lights(area,focus)
		check(focus.only_light_owner()==actors[index].get_instance_id(),"Restriction retains physical Gob identity")
		check(lights[index].native_admitted and lights[index].native_fade==1.0 and not lights[(index+1)%3].native_admitted and not lights[(index+2)%3].native_admitted,"Original history retains only that owner's dynamic lamps after outgoing fades")
		check(focus.history_result.area_fades[0][0]==0.0 and focus.history_result.area_fades[1][0]==0.0,"Independent area ambient and diffuse fade to zero")
		check(not static_light.native_admitted and focus.history_static_suppressed==1,"Temporary static fallback cannot illuminate through only-Gob restriction")
		check(area.environment.fog_light_color==Color.BLACK and SurfaceState.packet(world).slice(0,3)==[0.0,0.0,0.0],"Actual geometry fog switches to original black fog")
		check(area.environment.background_color==clear_color and area.sample.fog==original_fog,"Only-Gob fog leaves authored clear/sky colors intact")
		await compare_output(expected_surface(original,world,area,lights),1.0,Vector3.ZERO,.375,background,2.2,"Actual restricted world, black fog and original output owner "+str(index))
		observations.append(focus.snapshot())
	check(focus.set_blind_lights(),"Null Scene::SetBlindLights clears the restriction")
	advance_lights(area,focus)
	check(lights.all(func(light):return light.native_admitted and light.native_fade==1.0) and static_light.native_admitted and focus.only_light_owner()==0,"Reset restores physical lamps and baseline static fallback")
	check(area.environment.fog_light_color.is_equal_approx(Color(background.x,background.y,background.z)),"Reset restores the received raw area fog")
	await compare_output(expected_surface(original,world,area,lights),1.0,background,.375,background,2.2,"Actual cleared world restores area lighting and original fog")
	focus.set_blind_lights(actors[0]);actors[0].free();advance_lights(area,focus)
	check(focus.only_light_owner()==0 and area.environment.fog_light_color.is_equal_approx(Color(background.x,background.y,background.z)),"A retired physical owner cannot leave stale restriction or black fog")
	focus.set_blind_lights(actors[1]);focus.disable_history();area.advance(0)
	check(focus.only_light_owner()==0 and lights[1].native_admitted,"Explicit history rollback also clears its dependent restriction")
	check(gamma.snapshot().failure.is_empty() and focus.history_error.is_empty(),"Actual world has no renderer/history failure")
	var final_state: Dictionary=focus.snapshot();gamma.free();world.close();world.free();original.close();output_original.close();await process_frame;await process_frame
	check(SurfaceState.snapshot().owner==0 and Palette.active.is_empty(),"World retirement releases restricted-light and fog ownership")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":output_samples,"states":observations,"final":final_state,"publicConnections":0,"scope":"Actual enhanced LiveWorld Scene::SetBlindLights-equivalent physical-owner API, original finite history/area fades, independent attached Gob identity, raw black geometry fog with unchanged clear color, real GPU original material/fog/output comparison, clear/retired-owner/rollback. No inferred race/effect-ID or non-null native gameplay caller binding; static vertex baking and full vision/server acceptance remain open."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
