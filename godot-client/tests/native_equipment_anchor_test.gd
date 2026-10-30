extends SceneTree
const Actor=preload("res://systems/native_render/actor_instance.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Setup=preload("res://systems/native_data/session_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func authored(name: String,hand: bool) -> Dictionary:
	var text:="newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\n"
	if hand: text+="node dummy rhand\nparent root\nposition 2 0 1\nendnode\n"
	text+="endmodelgeom "+name+"\n"; var parser:=ActorData.new(); var model:=parser.parse(text.to_utf8_buffer()); model.rig_asset=parser.rig_asset(model)
	return {"value":model,"sha256":Cache.digest(text.to_utf8_buffer()),"error":"","textures":{},"animation_sources":[]}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var host:=Node3D.new(); root.add_child(host); var pool:=Pool.new(); var base:=authored("auth_base",true); var item:=authored("auth_item",false)
	var actor:=Actor.new(); host.add_child(actor)
	check(actor.install([{"bundle":base},{"bundle":item,"anchor":"lhand","attachment":"pq"},{"bundle":item,"anchor":"rhand","attachment":"pq"}],pool,1,{}),"Missing left equipment anchor does not reject the complete actor")
	check(actor.failure.is_empty() and actor.unattached_equipment.size()==1 and actor.unattached_equipment[0].anchor=="lhand","Missing equipment attachment is explicitly diagnosed")
	check(actor.model_names==["auth_base","auth_item"] and actor.meshes.size()==2,"Body and valid later equipment retain compact model/asset indexing")
	actor.set_animation(0); await process_frame
	check(actor.rigs.stats.failures.is_empty(),"Rig remains usable after skipping a middle attachment")
	var strict:=Actor.new(); host.add_child(strict)
	check(not strict.install([{"bundle":base},{"bundle":item,"anchor":"missing_body_anchor","follow":true}],pool,2,{}),"Missing required body-part anchors remain errors")
	strict.retire()
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-world-attachment-admission-v1.json"))
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==168,"Original attachment oracle identity and case count")
	var missing_cases:=0
	for row in oracle.rows:
		if row.case.parent and row.case.part: continue
		missing_cases+=1
		check(not row.attached and not row.sceneChanged and row.calls.back()==["behavior",false],"Original missing parent/part clears attachment without scene admission")
	check(missing_cases==126,"All original missing-anchor/null-parent cases compared")
	var owned: Array=[weakref(actor)]
	if args.has("install"):
		var sources:={"install":args.install,"modsDirectory":args.mods,"profileDirectory":args.profile,"nwsync":[{"hash":args.manifest,"nativeDirectory":str(args.profile).path_join("nwsync"),"cacheDirectory":str(args.profile).path_join("replacement-client/server-content"),"helper":ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")}]}
		var mounted:=Setup.prepare(sources); var catalog=mounted.catalog; check(str(mounted.get("error","unfinished")).is_empty(),"Original install/Workshop/cached resource catalog mounts")
		var service:=Assets.new(); root.add_child(service); service.configure(catalog); var jobs: Dictionary={}; var delivered: Dictionary={}
		service.completed.connect(func(id,result):delivered[jobs[id]]=result)
		for name in ["c_direrat","c_minowiza","it_torch_000"]: jobs[service.request(name,2002,"actor-model",{"relevant_tracks":true})]=name
		var deadline:=Time.get_ticks_msec()+60000
		while delivered.size()<3 and Time.get_ticks_msec()<deadline: await process_frame
		check(delivered.size()==3,"Original models from failed live batch prepare on native workers")
		for name in ["c_direrat","c_minowiza","it_torch_000"]: check(str(delivered.get(name,{}).get("error","unfinished")).is_empty(),"Original model prepares: "+name+": "+str(delivered.get(name,{}).get("error","unfinished")))
		if delivered.size()==3 and delivered.values().all(func(value):return str(value.error).is_empty()):
			for index in 2:
				var name: String=["c_direrat","c_minowiza"][index]; var body: Dictionary=delivered[name]; var instance:=Actor.new(); host.add_child(instance)
				check(instance.install([{"bundle":body},{"bundle":delivered.it_torch_000,"anchor":"lhand","attachment":"pq","initial_clip":"equip","follow":false}],pool,10+index,{}),"Original creature survives requested equipment: "+name)
				var has_hand: bool=body.value.nodes.any(func(part):return str(part.name).to_lower()=="lhand")
				check(instance.unattached_equipment.is_empty()==has_hand and instance.meshes.size()>0 and instance.failure.is_empty(),"Only original physical hand controls equipment attachment: "+name)
				instance.position=Vector3(index*3,0,-2); owned.append(weakref(instance)); observations.append({"model":name,"sha256":body.sha256,"has_lhand":has_hand,"models":instance.model_names.duplicate(),"meshes":instance.meshes.size(),"unattached_equipment":instance.unattached_equipment.duplicate(true)})
				instance.set_animation(0)
				if not has_hand: check(instance.model_names==[body.value.name],"Handless creature keeps its body without a fabricated held-item root")
		service.close(); service.queue_free()
		for layer in catalog.layers:
			if layer.kind=="nwsync": layer.store.close()
	var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(4,5,9); camera.look_at(Vector3(1,0,-1)); camera.current=true
	var environment:=WorldEnvironment.new(); environment.environment=Environment.new(); environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.environment.ambient_light_color=Color.WHITE; host.add_child(environment)
	for frame in 20: await process_frame
	var image_path:=""
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		image_path=str(args.report).trim_suffix(".json")+".png"; root.get_texture().get_image().save_png(image_path)
	for reference in owned:
		var node=reference.get_ref()
		if is_instance_valid(node): node.retire()
	await process_frame; await process_frame; host.queue_free(); await process_frame; await process_frame; pool.clear()
	check(owned.all(func(reference):return reference.get_ref()==null),"Native actors and remaining equipment retire without scene survivors")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_models":observations,"rendered_image":image_path,"network_connections":0,"scope":"Original missing-anchor branch and native actor/equipment admission; original pair from failed batch, not complete public-world or frame-pacing acceptance"},"\t")); file.close(); print("NATIVE_EQUIPMENT_ANCHOR ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
