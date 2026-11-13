extends "res://tests/native_enhanced_lighting_pixels_test.gd"
const Focus=preload("res://systems/native_render/focus_lighting.gd")
const Area=preload("res://systems/area_environment.gd")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	root.size=Vector2i(256,256)
	var world:=Node3D.new(); root.add_child(world); world.add_child(Palette.new())
	var focus:=Focus.new(); world.add_child(focus); focus.configure(world); focus.set_process(false); focus.enable_history(1)
	var environment:=Area.new(); world.add_child(environment); environment.configure({},world); environment.set_process(false)
	environment.environment.ambient_light_color=Color.BLACK
	focus.history_environment=weakref(environment); focus.set_area([0,0,0],[0,0,0])
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,0,5); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=4; camera.make_current()
	var surface:=MeshInstance3D.new(); surface.mesh=QuadMesh.new(); world.add_child(surface)
	var material:=NativeMaterial.new(); material.configure(StandardMaterial3D.new(),[1.0,1.0,1.0],[0.0,0.0,0.0]); surface.material_override=material
	Palette.ambient(Vector3.ZERO)
	var light:=PointLight.new(); var props:={"color":[.6,.4,.2],"radius":4,"ambientonly":1,"fadinglight":1}
	light.set_meta("native_enhanced_light",true); light.configure(props); world.add_child(light); light.position=Vector3(0,0,2); light.force_update_transform()
	focus.history_frame(.05)
	var fade:=light.native_fade; var state:=Policy.point(props,2.0,.2,1.5,fade)
	check(fade>0 and fade<.2 and light.native_admitted,"Physical lamp receives native first-frame fade")
	var first:=await capture(); close_color(first,state.color*Policy.attenuation(2,state),"Rendered fade precedes native color conversion")
	var wrong:=Policy.point(props); var wrong_color:=Color(wrong.color.x*fade,wrong.color.y*fade,wrong.color.z*fade).linear_to_srgb()
	check(absf(first.r-wrong_color.r)>.03,"Fixture distinguishes raw RGB fade from incorrect linear-energy fade")
	focus.refresh()
	var expected_cpu:=Vector3(.6,.4,.2)*(.5*fade)
	check(focus.value.distance_to(expected_cpu)<.000001,"Vision CPU sample uses the same admitted physical light and fade")
	focus.history_frame(.2); var second:=await capture(); check(second.r>first.r*2,"Retained fade increases visible illumination over time")
	var competitor:=PointLight.new(); competitor.set_meta("native_enhanced_light",true); competitor.configure({"color":[0,0,.6],"radius":4,"ambientonly":1,"fadinglight":0,"lightpriority":0}); world.add_child(competitor); competitor.position=Vector3(0,0,2); competitor.force_update_transform()
	focus.history_frame(.01)
	check(competitor.native_admitted and competitor.native_fade==1 and not light.native_admitted,"Non-fading incoming light evicts retained outgoing slot")
	var blue:=await capture(); var blue_state:=Policy.point({"color":[0,0,.6],"radius":4,"ambientonly":1})
	close_color(blue,blue_state.color*Policy.attenuation(2,blue_state),"Actual rendered slots follow native non-fading eviction")
	competitor.free(); focus.history_frame(.05)
	check(light.native_admitted and light.native_fade>0 and light.native_fade<.2,"Retired selected light allows physical predecessor to re-enter")
	check(focus.history_rows.size()==1 and focus.history.dispatch(2,{}).lights.size()==1,"Retirement releases native identities rather than accumulating registry history")
	light.publish_native_light(Color(.2,.6,.3),6,4,.25,1)
	var kept:=light.native_fade; focus.history_frame(.02)
	check(light.native_fade>kept and light.get_meta("native_model_light_properties").radius==6,"Animated publication preserves slot history and updates live fade speed")
	state=Policy.point(light.get_meta("native_model_light_properties"),2.0,.2,1.5,light.native_fade)
	close_color(await capture(),state.color*Policy.attenuation(2,state),"Animated lamp plus retained fade reaches the actual GPU")
	light.free(); focus.history.dispatch(0,{"enhanced":true}); focus.set_area([.5,.4,.3],[0,0,0]); focus.history_frame(.05)
	var area_fade: float=focus.history_result.area_fades[0][0]
	check(area_fade>0 and area_fade<.1,"Area GPU sample exercises a genuinely intermediate fade")
	close_color(await capture(),Policy.linear_rgb([.5*area_fade,.4*area_fade,.3*area_fade]),"Area ambient uses its independent native fade before conversion")
	var static_light:=PointLight.new(); static_light.set_meta("native_enhanced_light",true); static_light.configure({"color":[.4,.4,.4],"radius":4,"ambientonly":1,"isdynamic":0,"affectdynamic":0}); world.add_child(static_light); static_light.position=Vector3(0,0,2); static_light.force_update_transform()
	focus.history_frame(.01)
	check(static_light.native_admitted and static_light.native_fade==1 and focus.history_result.active0.is_empty() and focus.history_static_fallbacks==1,"Static-only contribution is preserved outside native dynamic slots pending the separate vertex bake")
	var static_pixel:=await capture(); var static_state:=Policy.point({"color":[.4,.4,.4],"radius":4,"ambientonly":1})
	area_fade=focus.history_result.area_fades[0][0]
	close_color(static_pixel,static_state.color*Policy.attenuation(2,static_state)+Policy.linear_rgb([.5*area_fade,.4*area_fade,.3*area_fade]),"Research slot limit does not silently remove visible static-only illumination")
	static_light.free()
	var sun:=DirectionalLight3D.new(); environment.add_child(sun); environment.sunlight=sun
	focus.set_area([0,0,0],[.4,.5,.6]); focus.history_frame(.1)
	var sun_fade: float=focus.history_result.area_fades[1][0]
	check(sun.light_color.is_equal_approx(Color(Policy.linear(.4*sun_fade),Policy.linear(.5*sun_fade),Policy.linear(.6*sun_fade)).linear_to_srgb()),"Area directional RGB receives its independent retained fade")
	var restored:=PointLight.new(); restored.set_meta("native_enhanced_light",true); restored.configure({"color":[.5,.5,.5],"radius":5,"fadinglight":1}); world.add_child(restored)
	focus.history_frame(.01); check(restored.native_fade>0 and restored.native_fade<1,"Rollback fixture begins with actual partial native fade")
	var snapshot: Dictionary=focus.snapshot(); focus.disable_history()
	check(focus.history==null and restored.native_admitted and restored.native_fade==1,"Disabling history restores baseline lamp contribution")
	check(sun.light_color.is_equal_approx(Color(Policy.linear(.4),Policy.linear(.5),Policy.linear(.6)).linear_to_srgb()),"Disabling history restores baseline area RGB")
	restored.free(); focus.close()
	check(focus.history==null and focus.closed and focus.members.is_empty(),"Retirement closes native history and weak lamp ownership")
	world.free(); material=null
	for frame in 3: await process_frame
	check(Palette.active.is_empty(),"History GPU fixture releases all palette ownership")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"focus":snapshot,"publicConnections":0,"scope":"Native history through real weak world lamp registry, material/palette GPU pixels, CPU vision sample, area channels, animated publication and retirement. Research candidate: original BSP collection and special view plane remain separate; no dense-room performance acceptance."}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
