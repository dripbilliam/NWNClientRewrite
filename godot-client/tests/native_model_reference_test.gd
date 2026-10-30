extends "res://tests/native_particle_schedule_test.gd"
const Binary=preload("res://systems/native_data/binary_model.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const ReferenceAssets=preload("res://systems/native_render/reference_assets.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
var observations: Dictionary={}
func emitters(owner: Node) -> Array: return owner.find_children("native_emitter","Node3D",true,false)
func references(owner: Node) -> Array: return owner.find_children("native_reference","Node3D",true,false)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); check(fixture.originalBinarySha256==BINARY_SHA and fixture.samples.size()==36,"Original reference reader observation identity/count")
	for sample in fixture.samples:
		var path:=str(fixture.folder).path_join(sample.name); var parser:=Binary.new(); var model:=parser.parse(FileAccess.get_file_as_bytes(path))
		check(FileAccess.get_sha256(path)==sample.sha256 and parser.failure.is_empty() and model.nodes.size()==1,"Authored original reference header parses "+str(sample.name))
		if model.is_empty(): continue
		var node: Dictionary=model.nodes[0]
		check(node.flags==int(sample.flags) and node.reference.model==sample.expectedModel and node.reference.reattachable==int(sample.reattachable),"Original terminated reference name, flags and signed reattach DWORD")
		check(node.reference.rawModel==PackedByteArray(sample.rawModel),"All 64 original reference name bytes retained")
	var truncated:=FileAccess.get_file_as_bytes(str(fixture.folder).path_join("header0.mdl")).slice(0,423); truncated.encode_u32(4,truncated.size()-12); var bad:=Binary.new()
	check(bad.parse(truncated).is_empty() and not bad.failure.is_empty(),"Truncated reference payload is rejected before name/flag reads")
	var ascii:=Ascii.new(); check(ascii.parse(FileAccess.get_file_as_string(str(fixture.folder).path_join("invalid.mdl"))).is_empty() and not ascii.failure.is_empty(),"Invalid ASCII reference DWORD is rejected")
	var catalog:=Catalog.new(); check(catalog.mount_directory(fixture.folder),"Authored native reference catalog mounts")
	if args.has("install"): check(catalog.mount_install(args.install),"Original local archive catalog mounts read-only")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var jobs: Dictionary={}; var delivered: Dictionary={}; assets.completed.connect(func(id,result):delivered[id]=result)
	for resource in ["beam","cycle_a","missing"]: jobs[assets.request(resource,2002,"static-model")]=resource
	if args.has("install"): jobs[assets.request("vim_raycold",2002,"static-model") ]="vim_raycold"
	var deadline:=Time.get_ticks_msec()+10000
	while delivered.size()<jobs.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(delivered.size()==jobs.size(),"Native root reference/beam preparations complete")
	var world:=Node3D.new(); root.add_child(world); var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(8,7,9); camera.look_at(Vector3(0,0,-2)); camera.current=true
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.background_mode=Environment.BG_COLOR; environment.environment.background_color=Color(0.03,0.04,0.07); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; world.add_child(environment)
	var pool:=Pool.new(); var hub:=ReferenceAssets.new(); world.add_child(hub); hub.configure(catalog,pool); world.set_meta("native_reference_hub",hub)
	var templates: Dictionary={}; var owners: Array=[]
	for id in jobs:
		var bundle: Dictionary=delivered.get(id,{}); var name:=str(jobs[id]); check(str(bundle.get("error","unfinished")).is_empty(),"Native reference-bearing root prepares "+name)
		if not bundle.has("value"): continue
		var template:=Template.new(); check(template.build(bundle,pool),"Reference-bearing native template builds "+name); templates[name]=template
	if not templates.has("beam"): hub.close(); world.free(); assets.close(); assets.free(); quit(1); return
	for index in 2:
		var owner=templates.beam.create(); world.add_child(owner); owner.position.x=-3 if index==0 else 3; owners.append(owner)
	deadline=Time.get_ticks_msec()+15000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	check(hub.ready() and int(hub.stats.published)==8 and int(hub.stats.jobs)==2,"Two source instances share two native asset jobs and own eight independent nested models")
	var a=emitters(owners[0])[0]; var b=emitters(owners[1])[0]; a.set_process(false); b.set_process(false)
	var first=a.get_node(a.reference_paths[0]); var second=a.get_node(a.reference_paths[1]); var other_first=b.get_node(b.reference_paths[0])
	check(is_instance_valid(first.model68) and is_instance_valid(second.model68) and first.model68!=second.model68 and first.model68!=other_first.model68,"Repeated reference resources create private model owners")
	check(absf(first.model68.global_basis.get_scale().x-1.0)<0.00001 and absf(first.get_parent().scale.x-3.0)<0.00001,"Reference P/Q attachment excludes anchor scale")
	check(first.model68.meshes.size()==1 and first.model68.meshes[0].mesh==second.model68.meshes[0].mesh,"Reference instances share immutable original native GPU geometry")
	for frame in 90:
		if frame==45: first.get_parent().position.x+=1.25
		first.synchronize_reference_pose(); second.synchronize_reference_pose(); other_first.synchronize_reference_pose(); a.tick(1.0/60.0); b.tick(1.0/60.0)
		if frame%10==0: await process_frame
	check(a.failure.is_empty() and b.failure.is_empty() and a.state.active188.records.size()==9 and b.state.active188.records.size()==9,"Native lightning connects to real referenced models and simulates fixed chains")
	check(a.state.target1c0==first.model68 and a.state.target1c0!=second.model68,"First direct physical reference wins over names and descendants")
	var source_position: Array=a.pose(a.get_parent()).position; var target_position: Array=a.pose(first.model68).position
	check(Vector3(a.state.active188.records[0].position10[0],a.state.active188.records[0].position10[1],a.state.active188.records[0].position10[2]).distance_to(Vector3(source_position[0],source_position[1],source_position[2]))<0.00001,"Moving chain source stays on original emitter")
	check(Vector3(a.state.active188.records.back().position10[0],a.state.active188.records.back().position10[1],a.state.active188.records.back().position10[2]).distance_to(Vector3(target_position[0],target_position[1],target_position[2]))<0.00001,"Moving chain endpoint follows live referenced model")
	check(a.surface.vertex_count==48 and b.surface.vertex_count==48,"Native linked chains publish their actual 48-vertex quad surfaces")
	var target_anchor:=Node3D.new(); world.add_child(target_anchor); target_anchor.position=Vector3(1,1,2)
	check(owners[0].reattach_references(target_anchor),"Original BFS reference owner attaches eligible children to an explicit resolved target")
	target_anchor.position.x+=2.0; first.synchronize_reference_pose(); second.synchronize_reference_pose(); a.tick(1.0/60.0)
	check(first.model68.global_position.distance_to(target_anchor.global_position)<0.00001 and second.model68.global_position.distance_to(target_anchor.global_position)<0.00001 and is_instance_valid(a.state.target1c0),"Both eligible reference models follow the moving external Part without sharing mutable ownership")
	check(owners[0].reattach_references(null),"Null reattachment restores each original physical reference anchor")
	first.synchronize_reference_pose(); check(first.model68.global_position.distance_to(first.get_parent().global_position)<0.00001,"Reset reference returns to its original physical anchor")
	if templates.has("vim_raycold"):
		var original_owner=templates.vim_raycold.create(); world.add_child(original_owner); original_owner.position=Vector3(0,1,-3); owners.append(original_owner)
		deadline=Time.get_ticks_msec()+15000
		while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
		check(hub.ready() and references(original_owner).all(func(reference):return reference.failure.is_empty() and is_instance_valid(reference.model68)),"Original cold-ray reference models prepare and instantiate through native workers")
		check(original_owner.reattach_references(target_anchor),"Original cold-ray eligible physical references attach to explicit target Part")
		var original_emitters:=emitters(original_owner); var lightning: Array=original_emitters.filter(func(emitter):return emitter.original_properties.get("update")=="Lightning")
		for emitter in original_emitters: emitter.set_process(false)
		for frame in 45:
			if frame==20: target_anchor.position.x+=1.0
			for reference in references(original_owner): reference.synchronize_reference_pose()
			for emitter in original_emitters: emitter.tick(1.0/60.0)
			if frame%10==0: await process_frame
		var counts: Array=lightning.map(func(emitter):return emitter.state.active188.records.size()); counts.sort()
		check(counts==[3,33] and lightning.all(func(emitter):return emitter.failure.is_empty() and is_instance_valid(emitter.state.target1c0)),"Actual original cold-ray retains native 3/33 particle chains with real reference endpoints")
		check(lightning.reduce(func(total,emitter):return total+int(emitter.surface.vertex_count),0)==204,"Original cold-ray linked chains publish 204 native vertices")
		observations.original_cold_ray={"emitters":original_emitters.map(func(emitter):return emitter.snapshot()),"references":references(original_owner).map(func(reference):return reference.snapshot())}
	var image_path:=""
	if DisplayServer.get_name()!="headless":
		await process_frame; await RenderingServer.frame_post_draw; image_path=str(args.report).trim_suffix(".json")+".png"; check(root.get_texture().get_image().save_png(image_path)==OK,"Native referenced chain image saves for inspection")
	observations.chains=[a.snapshot(),b.snapshot()]; observations.before_retirement=hub.snapshot()
	first.model68.queue_free(); await process_frame; a.tick(1.0/60.0)
	check(a.state.target1c0==null and a.state.active188.records.is_empty() and not a.surface.visible and is_instance_valid(second.model68),"Lost first model drains chain without guessing the second reference endpoint")
	var published_before:=int(hub.stats.published); var retired=templates.beam.create(); world.add_child(retired); retired.retire(); await process_frame; await process_frame
	check(int(hub.stats.published)==published_before,"Retiring a requesting instance discards cached pending publications")
	var actor_retired:=Actor.new(); world.add_child(actor_retired); var beam_bundle: Dictionary={}
	for id in jobs:
		if jobs[id]=="beam": beam_bundle=delivered[id]
	check(actor_retired.install([{"bundle":beam_bundle,"follow":false}],pool,11,{}),"Deferred-retirement actor reference fixture installs")
	actor_retired.retire(); hub._process(0.0); await process_frame
	check(int(hub.stats.published)==published_before and int(hub.stats.stale)>=2,"Reference publication rejects requests whose ancestor is queued for deletion")
	var cycle=templates.cycle_a.create(); world.add_child(cycle); owners.append(cycle); var missing=templates.missing.create(); world.add_child(missing); owners.append(missing)
	deadline=Time.get_ticks_msec()+10000
	while not hub.ready() and Time.get_ticks_msec()<deadline: await process_frame
	check(references(cycle).any(func(value):return "cycle/depth" in value.failure),"Nested resource cycle is diagnosed without recursive instantiation")
	check(references(missing).any(func(value):return "unavailable_model" in value.failure and not is_instance_valid(value.model68)),"Missing original reference does not create a replacement model")
	observations.final=hub.snapshot(); observations.failed_references=[]
	for owner in [cycle,missing]:
		for reference in references(owner):
			if not reference.failure.is_empty(): observations.failed_references.append(reference.snapshot())
	for owner in owners: owner.retire()
	hub.close(); assets.close(); assets.queue_free(); await process_frame; world.queue_free(); await process_frame; pool.clear(); await process_frame
	check(get_nodes_in_group("native_original_model_references").is_empty() and get_nodes_in_group("native_original_particle_emitters").is_empty(),"Reference models and emitters retire with their owning scopes")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalBinarySha256":BINARY_SHA,"originalEvidenceSha256":fixture.originalEvidenceSha256,"observations":observations,"rendered_image":image_path,"native_only":true,"network_connections":0,"scope":"Native authored reference graph/header/worker/private ownership and moving linked-chain fixture; original live-effect targeting/events/full render parity and performance remain incomplete"},"\t")); file.close()
	print("NATIVE_MODEL_REFERENCE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
