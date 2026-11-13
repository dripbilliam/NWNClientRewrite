extends "res://tests/native_particle_resident_scene_test.gd"
func wind_emitter(world: Node3D,reference: bool) -> Node3D:
	var part:=Node3D.new(); world.add_child(part)
	var out:=Emitter.new(); out.force_reference=reference; out.source_path=NodePath(".."); out.source_model_flags=0
	out.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":4|32|128|256,"xgrid":2,"ygrid":4,"birthrate":20,"lifeexp":2,"velocity":0.2,"randvel":0.3,"spread":0.8,"xsize":5,"ysize":3,"sizestart":0.1,"sizeend":0.2,"alphastart":1,"alphaend":0.2,"fps":12,"frameend":7}
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); out.original_texture=ImageTexture.create_from_image(image)
	part.add_child(out); out.set_process(false)
	out.rng=Random.new(); out.providers.random=out.rng.next
	return out
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var world:=LiveWorld.new(); root.add_child(world); world.set_process(false); world.point_wind.set_process(false)
	var camera:=Camera3D.new(); world.add_child(camera); camera.current=true; camera.position=Vector3(0,3,10); camera.look_at(Vector3.ZERO)
	var source:=ProjectSettings.globalize_path("res://../backups/animations/native-area-wind-observations-v1.json").simplify_path()
	var area: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	for row in area.rows:
		if not row.accepted: continue
		var fields:={"e4":int(row.power)}
		if int(row.power)==3:
			for index in 6: fields[["e8","ec","f0","f4","f8","fc"][index]]=row.input[index]
		check(world.point_wind.set_area(fields),"Original preset/custom area wind admits "+str(row.power))
		for name in ["wind","deviation","pitch"]:
			var a: Variant=world.point_wind.parameters[name]; var b: Variant=row.expected[name]
			check(PackedFloat32Array(a if a is Array else [a]).to_byte_array()==PackedFloat32Array(b if b is Array else [b]).to_byte_array(),"Original preset normalization and renderer decimal/radian boundary "+str(row.power)+" "+name)
	check(world.point_wind.set_area({"e4":2}),"Strong original area wind is applied before emission")
	var a=wind_emitter(world,false); var b=wind_emitter(world,true)
	check(a.native_owner!=null and b.native_owner==null and a.failure.is_empty() and b.failure.is_empty(),"Wind sprites use resident native simulation with explicit reference comparison")
	for frame in 180:
		if frame in [30,120]:
			# Other emitters can consume this world stream between wind ticks.
			world.point_wind.rng.next(); var seed: int=world.point_wind.rng.state; var draws: int=world.point_wind.rng.draws
			check(world.point_wind.add_source([0,0,0],4.0,0.5,1.0),"Live world accepts an explosion point wind")
			check(world.point_wind.rng.state==seed and world.point_wind.rng.draws==draws,"Registering wind cannot rewind another emitter's shared random stream")
		var delta: float=[1.0/60.0,0.025,0.0,-0.002,0.7][frame%5]; world.point_wind.tick(delta)
		var position:=Vector3(sin(frame*0.04),0,cos(frame*0.03)); a.get_parent().position=position; b.get_parent().position=position
		var before: int=world.point_wind.stats.samples
		a.tick(delta)
		check(world.point_wind.stats.samples==before,"Resident wind samples bypass per-particle GDScript publication "+str(frame))
		b.tick(delta); compare(a,b,"Live wind frame "+str(frame))
		if frame%30==0: await process_frame
	check(a.surface.vertex_count>0 and a.surface.visible,"Native wind particles publish visible GPU geometry")
	var wind: Dictionary=world.point_wind.snapshot()
	check(int(wind.native.cache_hits)>0 and int(wind.native.queries)>int(wind.samples),"Original wind cells are cached inside native simulation")
	check(int(wind.native.draws)>682 and world.point_wind.rng.draws==int(wind.native.draws)+2,"Shared local stream accounts for noise refills and external particle draws")
	var retained: RefCounted=world.point_wind.native_owner
	world.close(); world.queue_free(); await process_frame; await process_frame
	var retired: Variant=retained.call("dispatch",2,{"position":[0,0,0],"factor":1.0})
	check(retired is Dictionary and retired.has("error"),"Retaining a native diagnostic cannot sample a retired world's wind")
	retained=null
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"wind":wind,"network_connections":0,"scope":"Original area presets plus180 actual native wind emitter frames vs reference, point impulses, shared RNG ordering, direct native queries, GPU publication and retirement; global original frame/seed and grass parity remain open"})); file.close(); quit(0 if failures.is_empty() else 1)
