extends "res://tests/native_surface_output_pixels_test.gd"
const Post=preload("res://systems/native_render/native_postprocess.gd")
const TonalOriginal=preload("res://tests/original_postprocess_oracle.gd")
func authored_frame(count: int,ambient: Vector3,diffuse: Vector3,direction: Vector3,fog: Vector3,start: float,end: float,projection: Projection) -> PackedFloat32Array:
	var frame:=Post.empty_frame();Post.row(frame,0,Vector4(ambient.x,ambient.y,ambient.z,count));Post.row(frame,1,Vector4(diffuse.x,diffuse.y,diffuse.z,0));Post.row(frame,2,Vector4(direction.x,direction.y,direction.z,0));Post.row(frame,3,Vector4(fog.x,fog.y,fog.z,start));frame[16]=end
	for n in 4:Post.row(frame,5+n,projection[n])
	for n in count:
		Post.row(frame,9+n*2,Vector4(float(n%5)-2.0,float(n%3)-1.0,2.0+float(n%7) if n%7==3 else -2.0-float(n%7),1))
		Post.row(frame,10+n*2,Vector4(.01+float(n%4)*.03,.02+float(n%6)*.02,.03+float(n%7)*.01,-64.0 if n%3==0 else 64.0))
	return frame
func run() -> void:
	var report:="";var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--install="):install=arg.substr(10)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	root.size=Vector2i(256,256);selected_catalog=Catalog.new();check(selected_catalog.mount_install(install),"Original postprocess catalog mounts read-only");check(Post.profile(selected_catalog).is_empty(),"Actual original postprocess shader profile matches")
	var world:=Node3D.new();root.add_child(world);var env:=WorldEnvironment.new();world.add_child(env);env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,0,5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.current=true
	var gamma:=Gamma.new();world.add_child(gamma);gamma.attach(camera)
	check(not gamma.effect.set_postprocess({"mask":28}),"Ordinary output cannot silently select research postprocessing")
	gamma.effect.set_surface_output(true)
	var original:=TonalOriginal.new();var observations: Array=[]
	var layer:=CanvasLayer.new();world.add_child(layer);var ui:=ColorRect.new();layer.add_child(ui);ui.position=Vector2(5,5);ui.size=Vector2(20,20);ui.color=Color(.2,.4,.8)
	var frames: Array=[authored_frame(0,Vector3(.001,.002,.025),Vector3(.11,.01,.01),Vector3(.43,.49,.76),Vector3(.06,.008,.008),10,45,Projection.create_perspective(55,1,.01,100)),authored_frame(8,Vector3(.02,.03,.01),Vector3(.1,.07,.02),Vector3(.3,.4,-.8660254),Vector3(.08,.12,.2),-3,12,Projection.create_perspective(75,1.4,.01,100)),authored_frame(128,Vector3(.001,.002,.003),Vector3(.01,.02,.03),Vector3(0,0,-1),Vector3(.005,.01,.02),2,10,Projection.IDENTITY)]
	for mask in [0,4,8,12,16,20,24,28]:
		var options:={"mask":mask,"midpoint":.4,"intensity":.35,"vibrance":.7};check(gamma.effect.set_postprocess(options),"Supported original effect-mask combination is admitted")
		for frame: PackedFloat32Array in frames:
			var state: Dictionary=gamma.effect.postprocess_state();check(gamma.effect.publish_postprocess_frame(frame,int(state.revision)),"Authored admitted-light/frame boundary publishes")
			for value in [2.2,1.2]:
				gamma.set_gamma(value)
				for color in [Color(.001,.005,.02),Color(.1,.3,.15),Color(.5,.51,.49),Color(1.4,.3,.1)]:
					env.environment.background_color=color.linear_to_srgb()
					var expected: PackedFloat32Array=original.execute(selected_catalog,mask,TonalOriginal.inputs(frame,color,options,value));check(expected.size()==4 and original.failure.is_empty(),"Unchanged original midpoint and fragment chain execute: "+original.failure)
					if expected.size()!=4:continue
					var actual:=await capture();var error:=0.0
					for n in 3:error=maxf(error,absf(actual[n]-clampf(expected[n],0,1)))
					check(error<.009,"Actual contrast/vibrance/Gamma/tonemap pixel "+str([mask,int(frame[3]),value,color])+" error="+str(error))
					observations.append({"mask":mask,"lights":int(frame[3]),"gamma":value,"actual":[actual.r,actual.g,actual.b],"expected":Array(expected.slice(0,3)),"midpoint":expected[3],"max_error":error})
	var state: Dictionary=gamma.effect.postprocess_state();var invalid: PackedFloat32Array=frames[0].duplicate();invalid[3]=129
	check(not gamma.effect.publish_postprocess_frame(invalid,int(state.revision)),"Oversized native admitted-light packets are rejected")
	check(not gamma.effect.set_postprocess({"mask":1}) and gamma.effect.postprocess_state()==state,"Unsupported spatial stage cannot silently replace a working color chain")
	check(not gamma.effect.set_postprocess({"mask":4,"intensity":INF}) and gamma.effect.postprocess_state()==state,"Nonfinite settings cannot poison the working chain")
	check(gamma.effect.set_postprocess({"mask":8,"vibrance":.7}),"Vibrance-only selection prepares without a scene-light scan")
	check(not gamma.effect.publish_postprocess_frame(frames[0],int(state.revision)),"Stale scene publication cannot rewrite new options")
	await capture();var before:=gamma.snapshot();await capture();var after:=gamma.snapshot()
	check(after.midpoint_passes==before.midpoint_passes,"Unchanging vibrance-only settings do not dispatch the midpoint light kernel every frame")
	root.msaa_3d=Viewport.MSAA_2X;root.size=Vector2i(239,193);await capture()
	check(root.get_texture().get_image().get_pixel(10,10).is_equal_approx(ui.color),"Native tonal processing preserves later UI after MSAA/resize")
	check(gamma.snapshot().failure.is_empty() and gamma.snapshot().midpoint_passes>0,"Actual midpoint and final-output GPU pipelines execute without failure")
	gamma.effect.set_surface_output(false);check(gamma.effect.postprocess_state().options.is_empty(),"Output rollback clears dependent native postprocessing")
	var final_state: Dictionary=gamma.snapshot();original.close();world.free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":observations,"gamma":final_state,"original_shader_sha256":original.hashes,"publicConnections":0,"scope":"Actual compositor GPU versus unchanged original dynamic contrast vertex midpoint and ordered contrast/vibrance/Gamma/retail tonemap functions. Explicit gamma-framebuffer texel, admitted-light, projection/area/fog boundaries; all supported masks, 0/8/128 lamps, HDR/dark colors, raw background and UI/MSAA/resize. Spatial stages and actual-world snapshot binding/matched-room acceptance remain separate."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
