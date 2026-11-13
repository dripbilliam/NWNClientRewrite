extends "res://tests/native_particle_resident_test.gd"
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Metrics=preload("res://systems/native_render/particle_metrics.gd")
const Profile=preload("res://systems/native_render/frame_profile.gd")
const Summary=preload("res://systems/native_render/frame_summary_job.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const FrameGroup=preload("res://systems/native_render/particle_frame_group.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var gpu_timing: bool=args.get("gpu-timing","")=="true"
	if gpu_timing: RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var detailed: bool=args.get("detailed-profile","true")!="false"
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original installed resources mount")
	var selected: Dictionary=catalog.raster_location("fxpa_flame00")
	check(not selected.is_empty(),"Original particle bitmap resolves")
	if selected.is_empty(): quit(1); return
	var bytes: PackedByteArray=catalog.get_resource("fxpa_flame00",int(selected.type)); var parser:=Raster.new(); var raster:=parser.parse(bytes,int(selected.type))
	check(parser.failure.is_empty() and not raster.is_empty(),"Original compressed particle bitmap decodes without replacement")
	if not parser.failure.is_empty() or raster.is_empty(): quit(1); return
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); var texture_sha:=hash.finish().hex_encode()
	var pool:=Pool.new(); var texture:=pool.texture({"sha256":texture_sha,"value":raster})
	check(texture!=null and pool.failure.is_empty(),"Original bitmap publishes through the normal resource pool")
	if texture==null: quit(1); return
	var scene:=Node3D.new(); root.add_child(scene); var metrics:=Metrics.new(); scene.set_meta("native_particle_metrics",metrics)
	var camera:=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(0,35,45); camera.look_at(Vector3.ZERO); camera.fov=75; camera.current=true
	var environment:=WorldEnvironment.new(); scene.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.03,0.04,0.06)
	var profiler:=Profile.new(); root.add_child(profiler); profiler.configure(root); profiler.set_enabled(false)
	var group: Node
	if args.get("particle-frame-group","")=="ordered":
		group=FrameGroup.new(); scene.add_child(group); check(group.configure(scene,true),"Experimental engine-ordered frame inputs configure")
	var emitters: Array[Node3D]=[]; var count:=1506
	for index in count:
		var part:=Node3D.new(); scene.add_child(part); part.position=Vector3((index%41-20)*0.8,0.1,(int(index/41)-18)*0.8)
		var emitter:=Emitter.new(); emitter.source_path=NodePath(".."); emitter.source_model_flags=0; emitter.origin_resource="authored-high-emitter-density"
		emitter.original_properties={"update":"Single","render":"Normal","blend":"Lighten","flags":0,"texture":"fxpa_flame00","birthrate":1.0,"lifeexp":1.0,"loop":1,"velocity":0.0,"randvel":0.0,"spread":0.0,"mass":0.0,"xsize":0.0,"ysize":0.0,"sizestart":0.4,"sizeend":0.4,"alphastart":1.0,"alphaend":1.0,"colorstart":[1.0,1.0,1.0],"colorend":[1.0,1.0,1.0],"fps":0.0,"framestart":0.0,"frameend":0.0,"xgrid":1,"ygrid":1}
		emitter.original_texture=texture; part.add_child(emitter); emitters.append(emitter)
		check(emitter.failure.is_empty() and emitter.native_owner!=null,"High-density native emitter admits "+str(index))
	if not failures.is_empty(): quit(1); return
	for frame in 40: await process_frame
	profiler.set_enabled(detailed)
	# FrameProfile.configure()/set_enabled(false) owns this viewport flag.
	# Arm explicit GPU timing after that setup so baseline samples are real.
	if gpu_timing: RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var wall_rows: Array=[]; var previous_tick:=Time.get_ticks_usec()
	for frame in 260:
		await process_frame
		if not detailed:
			var tick:=Time.get_ticks_usec(); var row:={"wall_ms":(tick-previous_tick)/1000.0}; previous_tick=tick
			if gpu_timing:
				row.render_cpu_ms=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
				row.render_gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			wall_rows.append(row)
	await RenderingServer.frame_post_draw
	var captured: Array=profiler.rows.duplicate(true) if detailed else wall_rows.slice(-240); profiler.set_enabled(false)
	var summary: Dictionary=Summary.calculate(captured)
	if gpu_timing and not detailed: check(float(summary.metrics.render_gpu_ms.mean)>0 and float(summary.metrics.render_cpu_ms.mean)>0,"Explicit viewport CPU/GPU timestamps contain measured samples")
	var totals:=metrics.snapshot(); var typed:=0; var phase_batches:=0; var instance_streams:=0
	for emitter in emitters:
		check(emitter.failure.is_empty() and emitter.active_count()==1 and emitter.surface.vertex_count==6 and emitter.surface.visible,"Every effect remains present and drawn "+str(emitter.get_instance_id()))
		emitter.set_process(false)
		if emitter.native_typed_frame: typed+=1
		if emitter.batched_phase_collection: phase_batches+=1
		if emitter.native_instance_streams: instance_streams+=1
	check(totals.active==count and totals.vertices==count*6 and totals.failed==0 and totals.currently_culled==0,"All 1506 effects survive the complete graphical timing window")
	check(captured.size()==240,"Full post-warmup profiler window captured")
	var image:=root.get_texture().get_image(); var pixels:=0
	# Detect actual contribution against the same stopped scene with its
	# surfaces hidden; original dark artwork need not exceed an arbitrary
	# absolute brightness threshold to be visible and valid.
	for emitter in emitters: emitter.surface.hide()
	await RenderingServer.frame_post_draw
	var hidden:=root.get_texture().get_image()
	for y in range(0,image.get_height(),3):
		for x in range(0,image.get_width(),3):
			var color:=image.get_pixel(x,y); var background:=hidden.get_pixel(x,y)
			if maxf(absf(color.r-background.r),maxf(absf(color.g-background.g),absf(color.b-background.b)))>=1.0/255.0-0.00001: pixels+=1
	check(pixels>1000,"Graphical comparison contains visible original-texture particles")
	var prefix: String=str(args.report).trim_suffix(".json"); image.save_png(prefix+".png")
	var frame_file:=FileAccess.open(prefix+".frames.json",FileAccess.WRITE); frame_file.store_string(JSON.stringify(captured)); frame_file.close()
	var mode:={"typed_emitters":typed,"phase_batches":phase_batches,"instance_streams":instance_streams,"native_counters":metrics.native_counters!=null}
	if is_instance_valid(group):
		mode.frame_group=group.snapshot(); mode.group_fast_members=group.members.values().filter(func(member):return member.fast).size()
		check(group.failure.is_empty() and group.members.size()==count and mode.group_fast_members==count,"Every dense-scene effect uses the experimental native frame preparation")
	for emitter in emitters: emitter.retire()
	check(metrics.snapshot().emitters==0 and metrics.snapshot().active==0,"World retirement releases every counter record")
	if is_instance_valid(group): check(group.snapshot().native.registered==0,"World retirement releases every experimental frame entry")
	emitters.clear(); scene.queue_free(); profiler.queue_free(); texture=null; pool.clear(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"emitter_count":count,"native_mode":mode,"particle_totals":totals,"frame_profile":summary,"detailed_profiling":detailed,"visible_sample_pixels":pixels,"texture":{"name":"fxpa_flame00","sha256":texture_sha,"type":selected.type},"network_connections":0,"scope":"Actual production emitter callbacks, native simulation/pose, diagnostics, ArrayMesh/optional instance upload and GPU rendering for 1506 retained one-particle effects using an original installed bitmap. Authored density scene, not an Arelith capture or original-client FPS comparison. Detailed profiling uses all child spans; disabled mode records only process-frame intervals and no renderer timings. Full original-server Heal/crowd acceptance is separate."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
