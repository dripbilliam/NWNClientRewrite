extends "res://tests/native_area_surface_output_test.gd"
const Post=preload("res://systems/native_render/native_postprocess.gd")
const TonalOriginal=preload("res://tests/original_postprocess_oracle.gd")
class OtherProfile extends RefCounted:
	func get_resource(_name: String,_type: int) -> PackedByteArray:return "different server shader".to_utf8_buffer()
func frame_boundary(area,properties: Dictionary,camera_x: float,fade: float,restricted: bool) -> PackedFloat32Array:
	# Independent known fixture boundary: one original non-fading admitted lamp
	# at (0,0,2), a translated/unrotated camera at (x,0,5), explicit area fade.
	var frame:=Post.empty_frame();var a: Array=area.sample.ambient;var d: Array=area.sample.diffuse
	var amb:=Policy.linear_rgb(a.map(func(v):return Policy.f(v*fade)));var diff:=Policy.linear_rgb(d.map(func(v):return Policy.f(v*fade)))
	Post.row(frame,0,Vector4(amb.x,amb.y,amb.z,1));Post.row(frame,1,Vector4(diff.x,diff.y,diff.z,0));Post.row(frame,2,Vector4(0,0,1,0))
	var fog: Array=area.sample.fog;Post.row(frame,3,Vector4(0 if restricted else fog[0],0 if restricted else fog[1],0 if restricted else fog[2],area.range_state.start));frame[16]=area.range_state.end
	for n in 4:Post.row(frame,5+n,area.camera.get_camera_projection()[n])
	var color:=Policy.linear_rgb(properties.color);var radius: float=float(properties.radius)*2.0
	Post.row(frame,9,Vector4(-camera_x,0,-3,1));Post.row(frame,10,Vector4(color.x,color.y,color.z,radius*radius))
	return frame
func run() -> void:
	var report:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--install="):install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	root.size=Vector2i(256,256);selected_catalog=Catalog.new();check(selected_catalog.mount_install(install),"Original catalog mounts read-only for native scene postprocessing")
	var world:=LiveWorld.new();world.catalog=selected_catalog;world.set_meta("native_surface_output",true);world.set_meta("native_enhanced_lighting",true);root.add_child(world);world.set_process(false)
	var focus=world.focus_lighting;focus.set_process(false);focus.enable_history(1)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.current=true
	var area:=Area.new();world.add_child(area);area.configure({},world);area.camera=camera;area.set_process(false)
	var fields:={"98":0x221133,"9c":0x331122,"a0":0x082040,"a4":28,"a8":false,"ac":0,"b0":-1,"b4":0,"b8":0x110a08,"bc":0x050e18,"c0":0x664422,"c4":28,"c8":false,"cc":0,"d0":-1,"d4":0,"d8":true,"dc":false,"e0":0,"104":0,"108":10}
	var state:={"fields":fields,"time":{"timeOfDay":1,"transition":0},"minutesPerHour":1,"elapsed":0}
	check(area.receive({"revision":1,"state":state}),"Actual native area admits received lighting/fog")
	var actor:=Node3D.new();actor.set_meta("native_light_source",true);world.add_child(actor)
	var properties:={"color":[.9,.1,.03],"radius":4.0,"fadinglight":0}
	var light:=PointLight.new();light.set_meta("native_enhanced_light",true);light.configure(properties);actor.add_child(light);light.position=Vector3(0,0,2);light.force_update_transform()
	var spare:=PointLight.new();spare.set_meta("native_enhanced_light",true);spare.configure({"color":[1,1,1],"radius":8,"lightpriority":1000,"fadinglight":0});world.add_child(spare);spare.position=Vector3(20,0,2);spare.force_update_transform()
	for n in 15:area.advance(0);focus.history_frame(.1)
	check(light.native_admitted and not spare.native_admitted,"Actual finite admission selects one lamp and excludes a bright physical spare")
	var gamma:=Gamma.new();root.add_child(gamma);gamma.attach(camera);gamma.effect.set_surface_output(true)
	var options:={"mask":28,"midpoint":.4,"intensity":.35,"vibrance":.7}
	check(gamma.configure_postprocess(world,area,options),"Actual final-output owner validates the original profile and binds the native area")
	var original:=TonalOriginal.new();var observations: Array=[]
	for phase in 6:
		var fade:=1.0;var restricted:=false
		if phase==1:camera.position.x=2
		if phase==2:
			properties.color=[.3,.8,.7];properties.radius=6.0;light.publish_native_light(Color(.3,.8,.7),6,0,0,1);focus.history_frame(.1)
		if phase==3:state.time.timeOfDay=2;area.receive({"revision":2,"state":state});focus.history_frame(.1)
		if phase==4:
			focus.set_blind_lights(actor)
			for n in 15:area.advance(0);focus.history_frame(.1)
			fade=0.0;restricted=true
		if phase==5:focus.set_blind_lights();focus.history_frame(.25);fade=.25
		area.advance(0)
		var frame:=frame_boundary(area,properties,camera.position.x,fade,restricted)
		var actual_frame: Dictionary=Post.capture(world,area,camera)
		var differences: Array=[]
		if not actual_frame.has("error"):
			# Packed-array equality compares signed-zero storage. The independent
			# x translation produces -0 at x=0; require exact numerical equality
			# of every finite coefficient, without a tolerance for other changes.
			for n in frame.size():
				if actual_frame.value[n]!=frame[n]:differences.append({"at":n,"actual":actual_frame.value[n],"expected":frame[n]})
		if not differences.is_empty():
			print("NATIVE_POSTPROCESS_INPUT_DIFFERENCE ",JSON.stringify({"phase":phase,"values":differences,"actual_header":Array(actual_frame.value.slice(0,44)),"expected_header":Array(frame.slice(0,44))}))
		check(not actual_frame.has("error") and differences.is_empty(),"Actual physical admission/camera/area-fade/fog snapshot equals the independent known scene boundary "+str(phase))
		for value in [2.2,1.2]:
			gamma.set_gamma(value);var fog: Array=area.sample.fog;var color:=Color(fog[0],fog[1],fog[2],1)
			var expected: PackedFloat32Array=original.execute(selected_catalog,28,TonalOriginal.inputs(frame,color,options,value));check(expected.size()==4 and original.failure.is_empty(),"Original midpoint and final chain execute for actual world state")
			if expected.size()!=4:continue
			var actual:=await capture();var error:=0.0
			for n in 3:error=maxf(error,absf(actual[n]-clampf(expected[n],0,1)))
			check(error<.009,"Actual scene-state updates reach compositor pixels "+str([phase,value])+" error="+str(error))
			observations.append({"phase":phase,"gamma":value,"actual":[actual.r,actual.g,actual.b],"expected":Array(expected.slice(0,3)),"midpoint":expected[3],"max_error":error})
	check(gamma.snapshot().scene_inputs.frames>0 and gamma.snapshot().scene_inputs.error.is_empty() and gamma.snapshot().postprocess_lights==1,"Native scene owner publishes actual selected lights without registry over-admission")
	var before: Dictionary=gamma.effect.postprocess_state();world.catalog=OtherProfile.new()
	check(not gamma.configure_postprocess(world,area,options) and gamma.effect.postprocess_state()==before,"Unknown server shader profile cannot silently replace a verified working chain");world.catalog=selected_catalog
	light.free();var retired_frame: Dictionary=Post.capture(world,area,camera)
	check(not retired_frame.has("error") and retired_frame.value[3]==0,"A lamp retired after history selection cannot leave stale postprocess illumination")
	var next:=LiveWorld.new();next.set_meta("native_surface_output",true);root.add_child(next);next.set_process(false);SurfaceState.publish(next,Vector3(.1,.2,.3),true,1,10)
	await capture()
	check(gamma.effect.postprocess_state().options.is_empty() and not gamma.snapshot().scene_inputs.bound,"A successor world invalidates old scene postprocessing inputs before old world deletion")
	var successor:=SurfaceState.packet(next);world.close();world.free();await capture()
	check(SurfaceState.packet(next)==successor and not is_instance_valid(camera),"Old world retirement releases its camera without clearing successor fog")
	var final_state: Dictionary=gamma.snapshot();gamma.free();next.close();next.free();original.close();await process_frame;await process_frame
	check(Palette.active.is_empty() and SurfaceState.snapshot().owner==0,"Scene postprocess and physical lamp owners release cleanly")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":observations,"gamma":final_state,"publicConnections":0,"scope":"Actual LiveWorld/AreaEnvironment/native admission to final GPU tonal chain: independent one-lamp boundary, excluded bright spare, camera translation, native animated lamp update, day/night, only-Gob black fog, pre-power area fade, shader-profile rejection and successor retirement. Original installed midpoint/ordered color oracle; spatial stages and matched dense-room acceptance remain open."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
