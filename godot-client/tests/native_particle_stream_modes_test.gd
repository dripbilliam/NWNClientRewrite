extends "res://tests/native_particle_presentation_test.gd"
const Effect=preload("res://systems/native_render/particle_stream_effect.gd")
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
const Surface=preload("res://systems/particle_surface.gd")
const Fog=preload("res://systems/native_render/particle_stream_fog.gd")
func texture(seed_value: int) -> ImageTexture:
	var image:=Image.create(8,8,false,Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8: image.set_pixel(x,y,Color(0.2+0.7*float((x+seed_value)%8)/7,0.15+0.7*float((y+seed_value)%8)/7,0.6,0.2+float((x+y)%8)*0.1))
	image.generate_mipmaps(); return ImageTexture.create_from_image(image)
func compare_images(a: Image,b: Image,label: String) -> Dictionary:
	var over:=0; var maximum:=0.0; var exact:=true
	check(a.get_size()==b.get_size(),label+" dimensions")
	if a.get_size()!=b.get_size(): return {"invalid":true}
	for y in a.get_height():
		for x in a.get_width():
			var p:=a.get_pixel(x,y); var q:=b.get_pixel(x,y); var difference:=maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))
			maximum=maxf(maximum,difference); exact=exact and difference==0
			if difference>1.0/255.0+0.00001: over+=1
	check(over==0,label+" RGB pixels within one channel code; "+str(over)+" outliers, maximum "+str(maximum))
	return {"pixels_above_one_code":over,"max_error":maximum,"exact":exact}
func freeze() -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw; RenderingServer.force_sync()
func publish(presentation: RefCounted,renderer: RefCounted,camera: Camera3D,stamp: int) -> Dictionary:
	var view:=Bounds.native_view(camera)
	view=view.duplicate(); view.stamp=stamp
	var result: Dictionary=presentation.call("dispatch",1,{"delta":0.0,"animating":false,"view":view,"fog":Fog.sample(camera)})
	check(not result.has("error"),"Mixed native modes generate one complete active frame "+str(result))
	if result.has("error"): return {}
	var submitted: Dictionary=renderer.call("dispatch",1,{})
	check(not submitted.has("error"),"Mixed GPU packet submission succeeds")
	return presentation.call("dispatch",2,{})
func baseline_surfaces(snapshot: Dictionary,surfaces: Dictionary,sequence: int) -> void:
	for range_index in snapshot.ranges.size():
		var range_data: Dictionary=snapshot.ranges[range_index]
		var count:=int(range_data.count); var capacity:=maxi(count,96); var positions:=PackedByteArray(); positions.resize(capacity*12); var attributes:=positions.duplicate()
		for vertex in count:
			var source: int=(int(range_data.first)+vertex)*24; var target:=vertex*12
			for byte in 12: positions[target+byte]=snapshot.buffer[source+4+byte]
			for byte in 4: attributes[target+byte]=snapshot.buffer[source+byte]
			for byte in 8: attributes[target+4+byte]=snapshot.buffer[source+16+byte]
		var b: Array=range_data.bounds
		check(surfaces[int(range_data.id)].apply_frame(1,sequence,count,capacity,positions,attributes,AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5]))),"Established surface receives exact same native range")
		# Isolate GPU state against the SAME captured native range order. Godot
		# otherwise chooses a different transparent sort from source distances.
		surfaces[int(range_data.id)].draw_material.render_priority=range_index-128
func run() -> void:
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): path=arg.substr(9)
	if path.is_empty() or FileAccess.file_exists(path): quit(2); return
	var scene:=Node3D.new(); root.add_child(scene)
	var camera:=Camera3D.new(); scene.add_child(camera); camera.position=Vector3(0,9,14); camera.look_at(Vector3(0,0.5,0)); camera.fov=65; camera.current=true
	var environment:=WorldEnvironment.new(); scene.add_child(environment); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.03,0.04,0.06)
	var blocker:=MeshInstance3D.new(); scene.add_child(blocker); var box:=BoxMesh.new(); box.size=Vector3(3,1.2,1.2); blocker.mesh=box; blocker.position=Vector3(0,0.7,0)
	var solid:=StandardMaterial3D.new(); solid.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; solid.albedo_color=Color(0.2,0.3,0.4); blocker.material_override=solid
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation"); var renderer: RefCounted=ClassDB.instantiate("NwnParticleStreamRender")
	check(not renderer.call("dispatch",0,{"presentation":presentation,"debug_readback":true}).has("error"),"Mixed native GPU consumer configures")
	var effect:=Effect.new(); effect.configure(renderer); effect.enabled=false; var compositor:=Compositor.new(); compositor.compositor_effects=[effect]; environment.compositor=compositor
	var textures: Array[ImageTexture]=[texture(0),texture(3)]; var surfaces: Dictionary={}; var modes: Dictionary={}; var identities: Array[int]=[]
	var owners: Array[RefCounted]=[]
	for variant_index in 4:
		for mode in 7:
			var node:=Node3D.new(); scene.add_child(node); node.position=Vector3((mode-3)*1.8,0.5,(variant_index-1.5)*2.1)
			if variant_index%2==1: node.rotation.x=PI
			var initial:=make_owner(false,"fountain",32|128,false,false); var e: Dictionary=initial.state
			var parts: Array=[]
			for n in 3:
				parts.append({"position10":[node.position.x+n*0.12,-node.position.z+n*0.08,node.position.y+n*0.06],"trail64":[node.position.x-0.3,-node.position.z-0.3,node.position.y-0.15],"quaternion34":[0.5,-0.5,0.5,0.5],"direction4c":[0,0,1],"rotation1c":0.2+n*0.1,"age":0.25+n*0.2,"field48":0.0,"frame44":n%4,"stopped70":0,"inheritedSpeed20":0.0,"inheritedDirection24":[0,0,0],"velocity58":[0,0,0]})
			e.merge({"initialized208":1,"renderMode1a8":mode,"active188":{"records":parts,"capacity":3},"lifeExp":2.0,"sizeStart":1.1,"sizeEnd":0.7,"sizeStartY":0.9,"sizeEndY":0.7,"alphaStart":0.7,"alphaEnd":0.3,"colorStart":[0.7,0.8,0.6],"colorEnd":[0.4,0.5,0.9],"xGrid":2,"yGrid":2,"fps":8.0,"frameStart":0.0,"frameEnd":3.0,"blendMode68":int(variant_index>=2),"twoSided":variant_index%2==1},true)
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			check(not owner.call("dispatch",0,{"state":e,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":node.get_instance_id(),"sourceId":node.get_instance_id()},{}).has("error"),"Mixed mode native owner configures")
			var image: ImageTexture=textures[(mode+variant_index)%2]
			check(not presentation.call("dispatch",0,{"id":node.get_instance_id(),"owner":owner,"providers":{},"culling":false,"source_flags":0,"texture":image,"additive":variant_index>=2,"two_sided":variant_index%2==1}).has("error"),"All mode/blend/cull combinations register")
			var surface:=Surface.new(); scene.add_child(surface); surface.configure(image,1,variant_index>=2,variant_index%2==1,false); surfaces[node.get_instance_id()]=surface; modes[node.get_instance_id()]=mode; identities.append(node.get_instance_id()); owners.append(owner); initial.providers.clear()
	var snapshot:=publish(presentation,renderer,camera,100000001); baseline_surfaces(snapshot,surfaces,1); await freeze()
	var baseline:=root.get_texture().get_image()
	for surface in surfaces.values(): surface.hide()
	effect.enabled=true; await freeze(); var candidate:=root.get_texture().get_image()
	var first:=compare_images(baseline,candidate,"All seven draw modes, both blends/cull states, atlas/colors and real opaque depth")
	check(snapshot.ranges.size()==28,"No mixed-mode draw is silently dropped")
	for row: Dictionary in snapshot.ranges: check(int(row.count)==12 if int(modes[int(row.id)])==3 else int(row.count)==18,"Exact active count for linked/ordinary modes")
	var fog_comparisons: Array=[]
	var sequence:=10
	# All original geometry/material modes are checked under the same depth
	# and exponential fog used by real scenes; no fog-disabled test material.
	for config in [{"mode":Environment.FOG_MODE_DEPTH,"begin":12.0,"end":22.0,"curve":1.0,"density":1.0},{"mode":Environment.FOG_MODE_DEPTH,"begin":-5.0,"end":26.0,"curve":2.3,"density":0.7},{"mode":Environment.FOG_MODE_EXPONENTIAL,"begin":0.0,"end":0.0,"curve":1.0,"density":0.04}]:
		environment.environment.fog_enabled=true; environment.environment.fog_mode=config.mode; environment.environment.fog_depth_begin=config.begin; environment.environment.fog_depth_end=config.end; environment.environment.fog_depth_curve=config.curve; environment.environment.fog_density=config.density
		environment.environment.fog_light_color=Color(0.2,0.4,0.7); environment.environment.fog_light_energy=0.8; environment.environment.fog_sun_scatter=0.0; environment.environment.fog_aerial_perspective=0.0; environment.environment.fog_height_density=0.0
		check(Fog.unsupported(camera).is_empty(),"Actual depth/exponential fog is supported without retiring the fast path")
		snapshot=publish(presentation,renderer,camera,100000000+sequence); baseline_surfaces(snapshot,surfaces,sequence); effect.enabled=false
		for surface in surfaces.values(): surface.show()
		await freeze(); var fog_baseline:=root.get_texture().get_image()
		for surface in surfaces.values(): surface.hide()
		effect.enabled=true; await freeze(); var fog_candidate:=root.get_texture().get_image()
		fog_comparisons.append(compare_images(fog_baseline,fog_candidate,"Scene fog "+str(config)))
		sequence+=1
	# Return to no fog so the subsequent replacement/lifetime checks retain
	# their original meaning. This also exercises enabling/disabling in flight.
	environment.environment.fog_enabled=false
	# The same publication is retained while a bound material is changed and
	# its script reference is dropped. Old and new packets own their leases.
	var previous: PackedByteArray=snapshot.buffer; var saved:=previous.duplicate(); var replacement:=texture(6); var changed: Dictionary={"id":identities[0],"texture":replacement,"additive":false,"two_sided":false}
	check(not presentation.call("dispatch",4,changed).has("error"),"A frame-boundary texture change configures a new immutable material lease")
	surfaces[identities[0]].configure(replacement,1,false,false,false); replacement=null
	snapshot=publish(presentation,renderer,camera,100000002); effect.enabled=false; baseline_surfaces(snapshot,surfaces,20)
	for surface in surfaces.values(): surface.show()
	await freeze(); var changed_baseline:=root.get_texture().get_image()
	for surface in surfaces.values(): surface.hide()
	effect.enabled=true; await freeze(); var changed_candidate:=root.get_texture().get_image(); var second:=compare_images(changed_baseline,changed_candidate,"Texture replacement retains exact new pixels")
	check(previous==saved,"Old immutable geometry survives new material publication")
	# Verify that real depth removes visible particle pixels; disabling the
	# opaque blocker changes candidate output, without a depth-disabled mode.
	blocker.hide(); await freeze(); var unobstructed:=root.get_texture().get_image(); var occlusion_changes:=0
	for y in range(0,candidate.get_height(),2):
		for x in range(0,candidate.get_width(),2):
			if changed_candidate.get_pixel(x,y)!=unobstructed.get_pixel(x,y): occlusion_changes+=1
	check(occlusion_changes>100,"Opaque scene geometry participates in the shared pass's depth-tested image")
	var state: Dictionary=renderer.call("dispatch",2,{}); check(state.error==0 and state.debug_readback=="exact" and state.uploads==5,"GPU data matches exact packets and redraws reuse unchanged uploads "+str(state))
	check(effect.snapshot().failure.is_empty(),"Compositor remains valid through material changes")
	var prefix:=path.trim_suffix(".json"); baseline.save_png(prefix+".baseline.png"); candidate.save_png(prefix+".candidate.png")
	# Closing with a freshly queued frame must not revive a cancelled renderer.
	publish(presentation,renderer,camera,100000003); environment.compositor=null; effect.close(); presentation.call("dispatch",5,{}); owners.clear(); textures.clear(); await freeze()
	check(not renderer.call("dispatch",2,{}).alive,"Queued publication is cancelled before renderer retirement")
	check(not renderer.call("dispatch",1,{}).has("error"),"Late submissions are harmless after cancellation")
	for surface in surfaces.values(): surface.retire()
	scene.free(); effect=null; compositor=null; presentation=null; renderer=null; RenderingServer.force_sync()
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"first":first,"fog_comparisons":fog_comparisons,"replacement":second,"occlusion_changes":occlusion_changes,"renderer":state,"network_connections":0,"scope":"Actual shared raster vs established ArrayMesh using exact same native packets: all7 modes, normal/additive and cull/two-sided states, atlas/color/alpha, two textures, opaque depth, depth/exponential scene fog, material replacement, immutable old packet, cached upload reuse and queued cancellation. No whole-world or gameplay performance acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
