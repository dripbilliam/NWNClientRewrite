extends "res://tests/native_global_wind_scene_test.gd"
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false); world.point_wind.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.current=true; camera.position=Vector3(0,3,10); camera.look_at(Vector3.ZERO)
	check(world.point_wind.set_area({"e4":2}),"Strong original ambient wind is active")
	var a=wind_emitter(world,false); var b=wind_emitter(world,true)
	check(a.native_owner!=null and b.native_owner==null,"Compare resident wind admission with retained reference")
	var quiet_rejections:=0; var windy_rejections:=0
	for frame in 180:
		if frame%45==0: check(world.point_wind.set_area({"e4":0 if frame%90==0 else 2}),"Ambient wind updates before admission "+str(frame))
		if frame in [70,120]: check(world.point_wind.add_source([0,0,0],4.0,0.15,1.0),"Active impulse requires conservative admission "+str(frame))
		world.point_wind.tick(1.0/60.0)
		var far:=frame%45>=15 and frame%45<30
		camera.position=Vector3(2000 if far else 0,3,10); camera.look_at(Vector3(2000 if far else 0,0,0)); camera.fov=30 if frame%2==0 else 90
		var position:=Vector3(sin(frame*0.04),0,cos(frame*0.03)); a.get_parent().position=position; b.get_parent().position=position
		a.tick(1.0/60.0); b.tick(1.0/60.0); compare(a,b,"Wind admission frame "+str(frame))
		if world.point_wind.point_count>0: check(not a.last_culled,"Impulses cannot be rejected by an ambient-only bound "+str(frame))
		elif far:
			check(a.last_culled and not a.surface.visible,"Far wind emitter skips simulation and publication "+str(frame))
			if frame<45 or frame>=90 and frame<135: quiet_rejections+=1
			else: windy_rejections+=1
		if frame%30==0: await process_frame
	check(quiet_rejections>0 and windy_rejections>0,"Culling operates both with zero and nonzero ambient wind")
	check(a.surface.visible and a.frames<180,"Camera return resumes wind particles without catch-up")
	# This wind radius reaches a camera far beyond the zero-wind envelope.
	camera.position=Vector3(2000,3,10); camera.look_at(Vector3(2000,0,0)); await process_frame
	check(world.point_wind.set_area({"e4":3,"e8":1.0,"ec":0.0,"f0":0.0,"f4":2000.0,"f8":0.0,"fc":0.0}),"Large authoritative wind changes the radius immediately")
	world.point_wind.tick(0.0); a.tick(0.0); b.tick(0.0); compare(a,b,"Wind-expanded viewport edge")
	check(not a.last_culled and a.last_radius>=4000.0,"An offscreen source with a wind-expanded sphere remains admitted")
	check(world.point_wind.set_area({"e4":0}),"Zero wind restores the small radius")
	world.point_wind.tick(0.0); a.tick(0.0); b.tick(0.0); compare(a,b,"Wind radius shrinks immediately")
	check(a.last_culled,"Wind-only radius cache cannot stay stale after server update")
	# An unbound child model can be much larger than sprite size parameters.
	var parent:=Node3D.new(); world.add_child(parent)
	var chunk:=Emitter.new(); chunk.source_path=NodePath(".."); chunk.source_model_flags=0
	chunk.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":0,"chunkname":"NULL","birthrate":3.0,"lifeexp":1.0,"velocity":0.1,"sizestart":0.01,"sizeend":0.01}
	parent.add_child(chunk); chunk.set_process(false); chunk.tick(0.1)
	check(chunk.native_owner!=null and chunk.failure.is_empty() and not chunk.last_culled and chunk.culling_fallbacks>0,"Unknown chunk child bounds retain simulation instead of using sprite extents")
	var metrics: Dictionary=a.snapshot(); world.close(); world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"quiet_rejections":quiet_rejections,"windy_rejections":windy_rejections,"network_connections":0,"scope":"Actual native GPU wind emitter and reference leave/re-entry, original ambient radius, immediate server-wind changes, point-impulse fallback and unbound child-model safety. Complete point/child bounds and original camera/BSP parity remain open."},"\t")); file.close()
	print("NATIVE_PARTICLE_WIND_ADMISSION ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
