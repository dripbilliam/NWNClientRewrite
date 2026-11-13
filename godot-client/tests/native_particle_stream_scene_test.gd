extends "res://tests/native_particle_many_scene_test.gd"
const Effect=preload("res://systems/native_render/particle_stream_effect.gd")
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
class Driver extends Node:
	var presentation: RefCounted
	var renderer: RefCounted
	var camera: Camera3D
	var failure:=""
	var last: Dictionary={}
	func _process(delta: float) -> void:
		last=presentation.call("dispatch",1,{"delta":delta,"view":Bounds.native_view(camera,false)})
		if last.has("error"): failure=str(last.error); set_process(false); return
		var result: Variant=renderer.call("dispatch",1,{})
		if result is Dictionary and result.has("error"): failure=str(result.error); set_process(false)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	if args.has("msaa"): root.msaa_3d=int(args.msaa)
	var gpu_timing: bool=args.get("gpu-timing","")=="true"
	if gpu_timing: RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original installed resources mount")
	var selected: Dictionary=catalog.raster_location("fxpa_flame00"); var bytes: PackedByteArray=catalog.get_resource("fxpa_flame00",int(selected.type)); var parser:=Raster.new(); var raster:=parser.parse(bytes,int(selected.type))
	check(parser.failure.is_empty(),"Original particle bitmap decodes")
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); var texture_sha:=hash.finish().hex_encode(); var pool:=Pool.new(); var texture:=pool.texture({"sha256":texture_sha,"value":raster})
	var scene:=Node3D.new(); root.add_child(scene)
	var camera:=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(0,35,45); camera.look_at(Vector3.ZERO); camera.fov=75; camera.current=true
	var environment:=WorldEnvironment.new(); scene.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.03,0.04,0.06)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation"); var renderer: RefCounted=ClassDB.instantiate("NwnParticleStreamRender")
	check(not renderer.call("dispatch",0,{"presentation":presentation,"debug_no_depth":args.get("no-depth","")=="true","debug_readback":args.get("readback","")=="true"}).has("error"),"Shared native GPU consumer retains its presentation")
	var effect:=Effect.new(); effect.configure(renderer); var compositor:=Compositor.new(); compositor.compositor_effects=[effect]; environment.compositor=compositor
	var emitters: Array[Node3D]=[]; var count:=int(args.get("count","1506"))
	for index in count:
		var part:=Node3D.new(); scene.add_child(part); part.position=Vector3((index%41-20)*0.8,0.1,(int(index/41)-18)*0.8)
		var emitter:=Emitter.new(); emitter.source_path=NodePath(".."); emitter.source_model_flags=0
		emitter.original_properties={"update":"Single","render":"Normal","blend":"Lighten","flags":0,"texture":"fxpa_flame00","birthrate":1.0,"lifeexp":1.0,"loop":1,"velocity":0.0,"randvel":0.0,"spread":0.0,"mass":0.0,"xsize":0.0,"ysize":0.0,"sizestart":0.4,"sizeend":0.4,"alphastart":1.0,"alphaend":1.0,"colorstart":[1.0,1.0,1.0],"colorend":[1.0,1.0,1.0],"fps":0.0,"framestart":0.0,"frameend":0.0,"xgrid":1,"ygrid":1}
		emitter.original_texture=texture; part.add_child(emitter); emitter.set_process(false); emitters.append(emitter)
		var result: Dictionary=presentation.call("dispatch",0,{"id":emitter.get_instance_id(),"owner":emitter.native_owner,"providers":emitter.providers,"source_flags":0,"culling":true,"texture":texture,"additive":true,"two_sided":args.get("two-sided","")=="true"})
		check(not result.has("error"),"Every original-textured effect enters native shared frame "+str(index)+" "+str(result.get("error","")))
	var driver:=Driver.new(); driver.presentation=presentation; driver.renderer=renderer; driver.camera=camera; driver.process_priority=20; scene.add_child(driver)
	for frame in 40: await process_frame
	var rows: Array=[]; var previous_tick:=Time.get_ticks_usec()
	for frame in 260:
		await process_frame
		var tick:=Time.get_ticks_usec(); var row:={"wall_ms":(tick-previous_tick)/1000.0}; previous_tick=tick
		if gpu_timing:
			row.render_cpu_ms=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			row.render_gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		rows.append(row)
		if not driver.failure.is_empty() or int(renderer.call("dispatch",2,{}).error)!=0: break
	driver.set_process(false); await RenderingServer.frame_post_draw
	var stats: Dictionary=renderer.call("dispatch",2,{}); var last:=driver.last.duplicate(); var effect_stats:=effect.snapshot()
	check(driver.failure.is_empty() and effect_stats.failure.is_empty() and stats.error==0,"Shared native scene/renderer remains valid "+driver.failure+" "+str(effect_stats)+" "+str(stats))
	check(int(last.get("active",0))==count and int(last.get("vertices",0))==count*6 and int(last.get("draws",0))==count,"All effects retain actual active native geometry")
	check(stats.uploads>0 and stats.draws>=count and stats.vertices>=count*6,"Actual RenderingDevice submits active ranges from one shared buffer")
	RenderingServer.force_sync()
	var image:=root.get_texture().get_image(); effect.enabled=false; await process_frame; await RenderingServer.frame_post_draw; RenderingServer.force_sync(); var hidden:=root.get_texture().get_image(); var pixels:=0
	for y in range(0,image.get_height(),3):
		for x in range(0,image.get_width(),3):
			var c:=image.get_pixel(x,y); var b:=hidden.get_pixel(x,y)
			if maxf(absf(c.r-b.r),maxf(absf(c.g-b.g),absf(c.b-b.b)))>=1.0/255.0-0.00001: pixels+=1
	check(pixels>1000 if count==1506 else pixels>0,"Original texture contributes visible pixels through actual shared raster pass")
	var prefix: String=str(args.report).trim_suffix(".json"); image.save_png(prefix+".png")
	var differences: Dictionary={}
	if args.has("reference"):
		var reference:=Image.load_from_file(args.reference); var different:=0; var max_error:=0.0
		check(reference.get_size()==image.get_size(),"Matched graphical reference dimensions")
		if reference.get_size()==image.get_size():
			for y in image.get_height():
				for x in image.get_width():
					var c:=image.get_pixel(x,y); var b:=reference.get_pixel(x,y); var distance:=maxf(absf(c.r-b.r),maxf(absf(c.g-b.g),absf(c.b-b.b))); max_error=maxf(max_error,distance)
					if distance>1.0/255.0+0.00001: different+=1
			differences={"pixels_over_one_code":different,"max_error":max_error}
			check(different==0,"Shared raster matches reference within one channel code "+str(differences))
	var snapshot: Dictionary=presentation.call("dispatch",2,{})
	if gpu_timing: check(float(Summary.calculate(rows.slice(-240)).metrics.render_gpu_ms.mean)>0,"Shared raster CPU/GPU timestamps contain measured samples")
	var stream_sample: Array=[]
	if snapshot.buffer.size()>=24:
		stream_sample=[snapshot.buffer.decode_u32(0),snapshot.buffer.decode_float(4),snapshot.buffer.decode_float(8),snapshot.buffer.decode_float(12),snapshot.buffer.decode_float(16),snapshot.buffer.decode_float(20)]
	for entry: Dictionary in snapshot.emitters: check(entry.legacy_position_bytes==0 and entry.legacy_attribute_bytes==0,"GPU stream never allocates old capacity arrays "+str(entry.id))
	environment.compositor=null; effect.close(); presentation.call("dispatch",5,{})
	for emitter in emitters: emitter.retire()
	await RenderingServer.frame_post_draw; await process_frame; await process_frame
	RenderingServer.force_sync()
	scene.free(); effect=null; compositor=null; renderer=null; presentation=null; texture=null; pool.clear()
	RenderingServer.force_sync()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"frame_profile":Summary.calculate(rows.slice(-240)),"emitter_count":count,"renderer":stats,"native_frame":last,"pixels":pixels,"image_difference":differences,"stream_sample":stream_sample,"effect":effect_stats,"texture_sha256":texture_sha,"network_connections":0,"scope":"Experimental native shared-frame raster consumer: original texture, active-only upload/ranges and cached native draw state. Authored fixture only; no gameplay acceptance, fog/scene-lighting or full-world integration."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
