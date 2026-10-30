extends "res://tests/native_particle_schedule_test.gd"
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Channels=preload("res://systems/native_render/particle_channels.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
var world: Node3D
var observations: Array=[]
func _emitters(owner: Node) -> Array:
	return owner.find_children("native_emitter","Node3D",true,false)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var catalog:=Catalog.new(); check(catalog.mount_directory(fixture.folder),"Native authored resource mount")
	if args.has("install"): check(catalog.mount_install(args.install),"Original resource install mounts read-only")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var delivered: Dictionary={}; assets.completed.connect(func(id,result):delivered[id]=result)
	var jobs: Dictionary={assets.request("ascii",2002,"static-model"):"authored"}
	if args.has("install"):
		for name in ["it_torch_000","plc_portal2"]: jobs[assets.request(name,2002,"static-model")]=name
	var deadline:=Time.get_ticks_msec()+20000
	while delivered.size()<jobs.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(delivered.size()==jobs.size(),"All native particle model jobs complete")
	world=Node3D.new(); root.add_child(world); var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(8,6,10); camera.look_at(Vector3(0,1,0)); camera.current=true
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.04,0.05,0.08); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.6; world.add_child(environment)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-30,0); world.add_child(light)
	var pool:=Pool.new(); var owners: Array=[]; var authored: Array=[]; var actor_owner; var index:=0
	for id in jobs:
		var bundle: Dictionary=delivered.get(id,{}); var name:=str(jobs[id]); check(str(bundle.get("error","unfinished")).is_empty(),"Native model/bitmap preparation "+name)
		if not bundle.has("value"): continue
		if name=="authored":
			bundle=bundle.duplicate(true); var properties: Dictionary=bundle.value.nodes[1].emitter
			properties.flags=32; properties.p2p=0; properties.birthrate=12.0; properties.alphastart=1.0; properties.alphaend=0.0; properties.lifeexp=1.0; properties.xsize=10.0; properties.ysize=10.0; properties.velocity=0.4
			var channels:=Channels.new(); channels.configure(bundle.value.rig_asset,1); var parameters: Dictionary=properties.duplicate(true)
			check(channels.sample("pulse",0.5,parameters) and M.f(parameters.fps)==9 and M.values(parameters.colorstart)==[0.5,0.25,0.125],"ASCII linear scalar/vector emitter playback uses native model clock")
			var binary_job:=assets.request("channels",2002,"actor-model"); var binary_deadline:=Time.get_ticks_msec()+5000
			while not delivered.has(binary_job) and Time.get_ticks_msec()<binary_deadline: await process_frame
			var binary: Dictionary=delivered.get(binary_job,{})
			check(str(binary.get("error","unfinished")).is_empty(),"Binary original controller pool prepares")
			if binary.has("value"):
				var binary_channels:=Channels.new(); binary_channels.configure(binary.value.rig_asset,0); var binary_parameters: Dictionary={}
				check(binary_channels.sample("pulse",0.5,binary_parameters) and M.f(binary_parameters.fps)==9 and M.values(binary_parameters.colorstart)==[0.5,0.25,0.125],"Binary scalar/vector playback retains original value-pool ownership")
				var binary_clip: Dictionary=binary.value.rig_asset.clips[0]
				check(binary_clip.emitterStorage.size()==1 and binary_clip.emitterTracks.size()==4 and binary_clip.emitterTracks.all(func(track):return int(track.nativeStorageIndex)==0 and not track.has("nativeStorage")),"Binary emitter channels serialize one shared value pool per source node")
			actor_owner=Actor.new(); world.add_child(actor_owner); actor_owner.position=Vector3(-4,0,3)
			check(actor_owner.install([{"bundle":bundle,"initial_clip":"pulse","follow":false}],pool,7,{}),"Actor pipeline binds native emitter to private physical part and model clock")
			owners.append(actor_owner); observations.append({"model":"authored-actor","sha256":bundle.sha256,"owner":actor_owner})
			var direct:=Instance.new(); world.add_child(direct); direct.position=Vector3(-4,0,-3)
			check(direct.install(bundle,pool),"Direct native model installs emitters after entering SceneTree")
			owners.append(direct); observations.append({"model":"authored-direct","sha256":bundle.sha256,"owner":direct})
		var template:=Template.new(); check(template.build(bundle,pool),"Native emitter-bearing template builds "+name)
		if template.scene==null: continue
		for clone_index in 2 if name=="authored" else 1:
			var instance=template.create(); world.add_child(instance); instance.position=Vector3(index*3-4,0,0); index+=1; owners.append(instance)
			if name=="authored": authored.append(instance)
			observations.append({"model":name,"sha256":bundle.sha256,"owner":instance})
	await process_frame
	check(authored.size()==2 and _emitters(authored[0]).size()==1 and _emitters(authored[1]).size()==1,"Packed template clones retain native emitter owners")
	# Torches are inactive in their original base pose. Exercise the actual
	# resource's equip clip explicitly, rather than inventing a static birth rate.
	for row in observations:
		if row.model!="it_torch_000": continue
		for emitter in _emitters(row.owner):
			check(emitter.state.active188.records.is_empty() and emitter.channels.clips.has("equip"),"Original torch starts dormant and retains equip channel")
			var equip_time: float=emitter.channels.clips.equip.length
			emitter.clock_provider=func():return {"clip":"equip","time":equip_time}
	var before_frames:=Engine.get_process_frames(); var fixed_delta:=1.0/60.0
	# Deterministic native frame calls: no OS input, server or JS simulation.
	for owner in owners:
		for emitter in _emitters(owner): emitter.set_process(false)
	for frame in 120:
		if authored.size()==2 and frame==60: authored[1].position.x+=1.0
		if is_instance_valid(actor_owner): actor_owner.rigs._update(fixed_delta)
		for owner in owners:
			for emitter in _emitters(owner): emitter.tick(fixed_delta)
		if frame%12==0: await process_frame
	if authored.size()==2:
		var a=_emitters(authored[0])[0]; var b=_emitters(authored[1])[0]
		check(a.failure.is_empty() and b.failure.is_empty() and a.frames>=120 and b.frames>=120,"Independent native simulation clocks advance")
		check(a.state.active188.records.size()>0 and a.surface.vertex_count>0 and a.surface.mesh!=null,"Native particles reach Godot dynamic GPU surface")
		var unchanged: int=b.state.active188.records.size(); var cleared: Dictionary=a.state; cleared.active188.records.clear()
		check(b.state.active188.records.size()==unchanged and unchanged>0 and a.surface!=b.surface and a.surface.mesh!=b.surface.mesh,"Template clones have private lists/surfaces")
		check(a.original_texture==b.original_texture,"Original emitter texture remains shared immutable GPU resource")
		if a.native_owner!=null: a.upload(Kernel.build_streams(cleared,a.providers,a.surface.capacity))
		else: a.tick(0)
		check(a.surface.vertex_count==0 and not a.surface.visible,"Native shrinking list removes stale GPU quads")
	if is_instance_valid(actor_owner):
		var actor_emitters:=_emitters(actor_owner)
		check(actor_emitters.size()==1 and actor_emitters[0].clock_provider.is_valid() and actor_emitters[0].frames>0 and actor_emitters[0].surface.vertex_count>0,"Animated actor's native clock drives emitter curves and GPU quads")
	var report_rows: Array=[]
	for row in observations:
		var summaries: Array=_emitters(row.owner).map(func(emitter):return emitter.snapshot())
		if row.model!="authored": check(summaries.any(func(value):return int(value.vertices)>0 and value.failure.is_empty()),"Original installed model emits visible native quads: "+str(row.model))
		report_rows.append({"model":row.model,"sha256":row.sha256,"emitters":summaries})
	var image_path:=""
	if DisplayServer.get_name()!="headless":
		await process_frame; await RenderingServer.frame_post_draw; image_path=str(args.report).trim_suffix(".json")+".png"; check(root.get_texture().get_image().save_png(image_path)==OK,"Native GPU image is saved for inspection")
	for owner in owners: owner.retire()
	assets.close(); assets.queue_free(); await process_frame; world.queue_free(); await process_frame
	check(get_nodes_in_group("native_original_particle_emitters").is_empty(),"Native emitter nodes retire with their scene owners")
	pool.clear(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"models":report_rows,"rendered_image":image_path,"frames_elapsed":Engine.get_process_frames()-before_frames,"native_only":true,"network_connections":0,"scope":"Native authored/installed emitter templates, deterministic simulation and dynamic Godot GPU upload. Incomplete effects/services/animation blending; no full-world or frame-pacing acceptance"},"\t")); file.close()
	print("NATIVE_PARTICLE_RUNTIME ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
