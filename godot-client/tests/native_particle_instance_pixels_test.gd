extends "res://tests/native_particle_resident_test.gd"
const ArraySurface=preload("res://systems/particle_surface.gd")
const InstanceSurface=preload("res://systems/particle_instance_surface.gd")
func viewport_surface(instanced: bool,texture: Texture2D,additive: bool,lit: bool) -> Dictionary:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(320,240); viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var camera:=Camera3D.new(); viewport.add_child(camera); camera.position=Vector3(0,0,5); camera.look_at(Vector3.ZERO); camera.current=true
	var environment:=WorldEnvironment.new(); viewport.add_child(environment); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.02,0.03,0.05)
	var light:=OmniLight3D.new(); viewport.add_child(light); light.position=Vector3(1,1,2); light.omni_range=10; light.light_energy=2
	var surface: Node3D=InstanceSurface.new() if instanced else ArraySurface.new(); viewport.add_child(surface); surface.configure(texture,1,additive,not OS.get_cmdline_user_args().has("--particle-cull-front"),lit)
	return {"viewport":viewport,"surface":surface}
func compare_pixels(a: Image,b: Image) -> Dictionary:
	var changed:=0; var maximum:=0.0; var total:=0.0
	for y in a.get_height():
		for x in a.get_width():
			var p:=a.get_pixel(x,y); var q:=b.get_pixel(x,y)
			var delta:=maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))
			if delta>0: changed+=1
			maximum=maxf(maximum,delta); total+=delta
	return {"changed":changed,"max_error":maximum,"mean_error":total/(a.get_width()*a.get_height())}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16: image.set_pixel(x,y,Color(0.2+x/20.0,0.3+y/24.0,0.7,0.3+(x+y)/48.0))
	image.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(image); var observations: Array=[]
	for mode in [0,3,5,6]:
		for lit in [false,true]:
			var additive: bool=mode in [3,6]
			var seed:=make_owner(false,"fountain",512 if mode==5 else 0,false,false); var e: Dictionary=seed.state
			e.renderMode1a8=mode; e.lifeExp=2.0; e.sizeStart=1.0; e.sizeEnd=0.6; e.alphaStart=0.9; e.alphaEnd=0.5
			e.xGrid=2; e.yGrid=2; e.frameStart=0.0; e.frameEnd=3.0; e.fps=0.0; e.position1e0=[0,0,0]
			e.colorStart=[0.8,0.4,0.7]; e.colorEnd=[0.6,0.8,0.3]; e.source50.opacity108=0.8
			e.active188={"records":[],"capacity":2}
			for id in 2: e.active188.records.append({"position10":[-0.5+id,0,0],"trail64":[-0.7+id,0,-0.5],"quaternion34":[0.70710677,0.70710677,0,0],"direction4c":[0,-1,0],"rotation1c":0.15,"age":0.2+id*0.3,"field48":0,"frame44":id,"stopped70":int(mode==5),"inheritedSpeed20":0.0,"inheritedDirection24":[0,0,0],"velocity58":[0,0,0]})
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			var configured: Dictionary=owner.call("dispatch",0,{"state":e,"update":"fountain","compactRecords":true},{})
			check(not configured.has("error"),"Pixel fixture configures")
			var input:={"factor":1.0,"camera":[0.70710677,0.70710677,0,0],"tint":[1,1,1],"capacity":192}
			var arrays: Dictionary=owner.call("dispatch",6,input,{})
			input.instances=true; var packed: Dictionary=owner.call("dispatch",6,input,{})
			var a:=viewport_surface(false,texture,additive,lit); var b:=viewport_surface(true,texture,additive,lit)
			var bounds:=AABB(Vector3(arrays.bounds[0],arrays.bounds[1],arrays.bounds[2]),Vector3(arrays.bounds[3],arrays.bounds[4],arrays.bounds[5]))
			check(a.surface.apply_frame(1,0,int(arrays.count),192,arrays.positions,arrays.attributes,bounds),"Array GPU packet accepted")
			check(b.surface.apply_instances(1,0,int(packed.count),192,packed.instances,bounds),"Instance prefix accepted on first frame")
			for frame in 6: await RenderingServer.frame_post_draw
			check(b.surface.upload_error().is_empty(),"Render-thread upload completed without a driver error "+str(b.surface.upload_error()))
			check(b.surface.native_upload!=null,"Actual render-thread submission uses the native owner")
			var old: Image=a.viewport.get_texture().get_image(); var new: Image=b.viewport.get_texture().get_image()
			var difference:=compare_pixels(old,new); difference.mode=mode; difference.lit=lit; difference.additive=additive; observations.append(difference)
			check(float(difference.max_error)<=1.0/255.0+0.00001,"Equivalent particle pixels "+str(difference))
			if mode==0:
				a.surface.hide(); await RenderingServer.frame_post_draw
				var hidden: Image=a.viewport.get_texture().get_image(); a.surface.show()
				var visibility:=compare_pixels(old,hidden)
				check(int(visibility.changed)>100,"Pixel comparison includes visible textured quads")
			if mode==0 and not lit:
				old.save_png(str(args.report).trim_suffix(".json")+"-array.png"); new.save_png(str(args.report).trim_suffix(".json")+"-instances.png")
				# Shrink without clearing the previously uploaded second record.
				var positions: PackedByteArray=arrays.positions.duplicate(); var attributes: PackedByteArray=arrays.attributes.duplicate()
				positions.fill(0); attributes.fill(0)
				for byte in 72: positions[byte]=arrays.positions[byte]; attributes[byte]=arrays.attributes[byte]
				a.surface.apply_frame(1,1,6,192,positions,attributes,bounds); b.surface.apply_instances(1,1,6,192,packed.instances.slice(0,80),bounds)
				for frame in 3: await RenderingServer.frame_post_draw
				var shrunk:=compare_pixels(a.viewport.get_texture().get_image(),b.viewport.get_texture().get_image()); observations.append({"shrunk":shrunk})
				check(float(shrunk.max_error)<=1.0/255.0+0.00001 and b.surface.instances.visible_instance_count==1,"Shrinking draws only the active record without tail clearing")
				check(not b.surface.apply_instances(1,1,6,192,packed.instances.slice(0,80),bounds),"Duplicate sequence is rejected")
				b.surface.apply_instances(1,2,12,192,packed.instances,bounds)
				b.surface.retire(); check(b.surface.instances==null and not b.surface.visible,"Retirement cancels queued uploads and detaches the renderer")
			a.surface.retire(); b.surface.retire(); a.viewport.queue_free(); b.viewport.queue_free(); seed.providers.clear(); owner=null
			await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"network_connections":0,"scope":"Actual ArrayMesh versus packed-quad MultiMesh pixels, alpha/additive and lit/unlit, atlas UVs, exact corners, shrink with stale GPU tail, sequence rejection and queued retirement. Not a performance test."},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
