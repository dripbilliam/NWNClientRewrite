extends "res://tests/native_particle_admission_test.gd"
const LiveWorld=preload("res://systems/native_render/live_world.gd")
const Random=preload("res://systems/native_render/particle_random.gd")
func spawn(world: Node3D,reference: bool) -> Node3D:
	var part:=Node3D.new(); world.add_child(part)
	var out:=Emitter.new(); out.force_reference=reference; out.source_path=NodePath(".."); out.source_model_flags=0
	out.original_properties={"update":"Fountain","render":"Motion_Blur","blend":"Normal","flags":32|128|256,"xgrid":2,"ygrid":4,"birthrate":20,"lifeexp":2,"velocity":0.2,"randvel":0.3,"spread":0.8,"blurlength":0.1,"xsize":5,"ysize":3,"sizestart":0.1,"sizeend":0.2,"alphastart":1,"alphaend":0.2,"fps":12,"frameend":7}
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); out.original_texture=ImageTexture.create_from_image(image)
	part.add_child(out); out.set_process(false)
	# The world normally shares one stream. A/B owners need independent copies
	# of that stream, otherwise sequential births deliberately draw different RNG.
	out.rng=Random.new(); out.providers.random=out.rng.next
	return out
func compare(a: Node3D,b: Node3D,label: String) -> void:
	check(a.failure.is_empty() and b.failure.is_empty(),label+" no failures")
	check(a.last_culled==b.last_culled and a.frames==b.frames and a.rng.state==b.rng.state and a.rng.draws==b.rng.draws,label+" admission/frame/RNG parity")
	var difference:=same(a.state,b.state)
	check(difference.is_empty(),label+" native state parity "+difference)
	check(a.surface.vertex_count==b.surface.vertex_count and a.surface.visible==b.surface.visible,label+" GPU publication parity")
	var totals: Dictionary=a.metrics_owner.snapshot()
	check(int(totals.active)==a.active_count()+b.active_count() and int(totals.vertices)==a.surface.vertex_count+b.surface.vertex_count,label+" incremental counters include resident particles")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false); var camera:=Camera3D.new(); world.add_child(camera); camera.current=true
	var a=spawn(world,false); var b=spawn(world,true)
	check(a.native_owner!=null and b.native_owner==null,"Default resident C++ path and explicit retained reference both active")
	for frame in 180:
		var far:=frame%60>=30 and frame%60<45
		camera.position=Vector3(2000 if far else 0,1,10); camera.look_at(Vector3(2000 if far else 0,0,0)); camera.fov=30 if frame%2==0 else 90
		var position:=Vector3(sin(frame*0.04),0,cos(frame*0.03)); a.get_parent().position=position; b.get_parent().position=position
		a.get_parent().rotation.y=frame*0.002; b.get_parent().rotation.y=frame*0.002
		var scale_value:=Vector3(2,1,3) if frame>=90 else Vector3.ONE; a.get_parent().scale=scale_value; b.get_parent().scale=scale_value
		a.tick(1.0/60.0); b.tick(1.0/60.0); compare(a,b,"Frame "+str(frame))
		if frame%30==0: await process_frame
	check(a.culled_frames>0 and a.frames<180 and a.surface.visible,"Actual GPU surface leaves and re-enters view without catch-up")
	var first: Dictionary=a.state; first.active188.records.clear()
	check(a.active_count()>0 and not a.state.active188.records.is_empty(),"Debug snapshots cannot mutate private native records")
	var retained: RefCounted=a.native_owner
	a.retire(); b.retire(); check(a.native_owner==null and a.active_count()==0,"Retirement releases resident RefCounted state")
	world.close(); world.queue_free(); await process_frame; await process_frame
	var stale: Dictionary=retained.call("dispatch",1,{"clip":"","time":0},{})
	check(stale.get("error","").contains("pose owner is absent"),"Retained diagnostic owner rejects freed scene IDs without dereferencing old pointers")
	retained=null
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"network_connections":0,"scope":"180 actual native GPU emitter frames, moving/scaled source, camera leave/re-entry and same-frame FOV changes vs retained reference; private snapshot/retirement ownership"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
