extends "res://tests/native_particle_stream_modes_test.gd"
const SceneBatches=preload("res://systems/native_render/particle_scene_batches.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var scene:=Node3D.new(); root.add_child(scene)
	var camera:=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(0,9,14); camera.look_at(Vector3(0,0.5,0)); camera.fov=65; camera.current=true
	var environment:=WorldEnvironment.new(); scene.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.03,0.04,0.06)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color(0.15,0.2,0.3)
	environment.environment.fog_enabled=true; environment.environment.fog_mode=Environment.FOG_MODE_DEPTH; environment.environment.fog_depth_begin=12; environment.environment.fog_depth_end=22; environment.environment.fog_density=0.8; environment.environment.fog_light_color=Color(0.2,0.4,0.7); environment.environment.fog_sun_scatter=0
	var sun:=DirectionalLight3D.new(); scene.add_child(sun); sun.rotation_degrees=Vector3(-40,25,0); sun.light_color=Color(0.8,0.7,0.5); sun.light_energy=1.7
	var point:=OmniLight3D.new(); scene.add_child(point); point.position=Vector3(-4,3,5); point.omni_range=30; point.light_color=Color(0.5,0.2,0.8); point.light_energy=2.0
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation"); var batcher:=SceneBatches.new(); scene.add_child(batcher)
	var textures: Array[ImageTexture]=[texture(0),texture(3)]; var owners: Array[RefCounted]=[]; var surfaces: Dictionary={}
	for variant_index in 4:
		for mode in 7:
			var node:=Node3D.new(); scene.add_child(node); node.position=Vector3((mode-3)*1.8,0.5,(variant_index-1.5)*2.1)
			var initial:=make_owner(false,"fountain",32|128|8,false,false); var e: Dictionary=initial.state; var parts: Array=[]
			for n in 3: parts.append({"position10":[node.position.x+n*0.12,-node.position.z+n*0.08,node.position.y+n*0.06],"trail64":[node.position.x-0.3,-node.position.z-0.3,node.position.y-0.15],"quaternion34":[0.5,-0.5,0.5,0.5],"direction4c":[0,0,1],"rotation1c":0.2+n*0.1,"age":0.25+n*0.2,"field48":0.0,"frame44":n%4,"stopped70":0,"inheritedSpeed20":0.0,"inheritedDirection24":[0,0,0],"velocity58":[0,0,0]})
			e.merge({"initialized208":1,"renderMode1a8":mode,"active188":{"records":parts,"capacity":3},"lifeExp":2.0,"sizeStart":1.1,"sizeEnd":0.7,"sizeStartY":0.9,"sizeEndY":0.7,"alphaStart":0.7,"alphaEnd":0.3,"colorStart":[0.7,0.8,0.6],"colorEnd":[0.4,0.5,0.9],"xGrid":2,"yGrid":2,"fps":8.0,"frameStart":0.0,"frameEnd":3.0,"blendMode68":int(variant_index>=2),"twoSided":variant_index%2==1},true)
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			check(not owner.call("dispatch",0,{"state":e,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":scene.get_instance_id()},{}).has("error"),"Exact native lit owner configures")
			var image: ImageTexture=textures[variant_index%2]
			check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":{},"culling":false,"source_flags":0,"node_order":variant_index*7+mode,"texture":image,"lighting":true,"additive":variant_index>=2,"two_sided":variant_index%2==1}).has("error"),"All lit geometry modes register")
			var surface:=Surface.new(); scene.add_child(surface); surface.configure(image,1,variant_index>=2,variant_index%2==1,true); surfaces[node.get_instance_id()]=surface; owners.append(owner); initial.providers.clear()
	var view:=Bounds.native_view(camera)
	var result: Dictionary=presentation.call("dispatch",1,{"delta":0.0,"animating":false,"view":view})
	check(not result.has("error"),"Reference exact native geometry generates")
	var reference: Dictionary=presentation.call("dispatch",2,{}); baseline_surfaces(reference,surfaces,1); await freeze(); var baseline:=root.get_texture().get_image()
	result=presentation.call("dispatch",1,{"delta":0.0,"animating":false,"view":view,"scene_instances":true})
	check(not result.has("error") and int(result.scene_batches)==4 and int(result.scene_vertices)==int(reference.vertices) and int(result.vertices)==int(reference.vertices),"Twenty-eight sorted lit ranges become exactly four active GPU batches")
	var frame: Dictionary=presentation.call("dispatch",9,{})
	check(batcher.consume(frame),"Exact native instance batches publish "+batcher.failure)
	for surface in surfaces.values(): surface.hide()
	await freeze(); var candidate:=root.get_texture().get_image(); var difference:=compare_images(baseline,candidate,"Seven original geometry modes and exact colors/atlas under real directional+point lighting and depth fog")
	check(not batcher.priority_overflow and batcher.last_vertices==int(reference.vertices),"Pooled draws preserve every active lit vertex")
	var state:=batcher.snapshot(); var prefix: String=str(args.report).trim_suffix(".json"); baseline.save_png(prefix+".baseline.png"); candidate.save_png(prefix+".candidate.png")
	# A complete empty publication must hide retained old buffers immediately.
	for row: Dictionary in reference.ranges: presentation.call("dispatch",4,{"id":int(row.id),"enabled":false})
	result=presentation.call("dispatch",1,{"delta":0.0,"animating":false,"view":view,"scene_instances":true})
	check(not result.has("error") and batcher.consume(presentation.call("dispatch",9,{})),"Empty next generation hides all prior GPU ranges")
	check(batcher.last_vertices==0 and batcher.surfaces.values().all(func(surface):return surface.vertex_count==0 and not surface.visible),"No stale particle tail survives an empty batch")
	batcher.close(); presentation.call("dispatch",5,{}); owners.clear(); textures.clear()
	for surface in surfaces.values(): surface.retire()
	scene.free(); presentation=null; await freeze()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"difference":difference,"batches":state,"network_connections":0,"scope":"Exact native geometry vs the established lit renderer for all7 modes, both blends and cull states, atlas/color/alpha, two textures, actual sun/point lights and depth fog; active-only four-batch publication, stale-buffer hiding and cleanup. No whole-room performance or complete native lighting parity claim."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
