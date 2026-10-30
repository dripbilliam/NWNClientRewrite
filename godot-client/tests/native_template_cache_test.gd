extends SceneTree
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Stream=preload("res://systems/native_render/object_stream.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func write(path: String,text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir()); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()
func source(name: String) -> String:
	return "newmodel "+name+"\nbeginmodelgeom "+name+"\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 0 1\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom "+name+"\n"
func bundle(name: String) -> Dictionary:
	var text:=source(name); var parser:=ActorData.new(); var model:=parser.parse(text.to_utf8_buffer()); return {"value":model,"sha256":Cache.digest(text.to_utf8_buffer()),"textures":{},"error":"","animation_sources":[]}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-world-model-cache-v1.json"))
	check(original.rows.size()==80 and original.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original complete FindModel cache/load oracle identity")
	var pool:=Pool.new(); var value:=bundle("auth_mesh"); var first=pool.model_template(value); var second=pool.model_template(value)
	check(first!=null and first==second and pool.stats.templates_created==1 and pool.stats.template_hits==1,"Unchanged original content shares one prepared native template")
	var host:=Node3D.new(); root.add_child(host); var a=first.create(); var b=second.create(); host.add_child(a); host.add_child(b)
	check(a!=b and a.parts[0]!=b.parts[0] and a.meshes[0].mesh==b.meshes[0].mesh,"Private physical trees share only immutable GPU source")
	a.parts[0].position=Vector3(3,4,5)
	var fresh=second.create()
	check(b.parts[0].position==Vector3.ZERO and fresh.parts[0].position==Vector3.ZERO,"One instance cannot mutate another or the cached rest template")
	fresh.free()
	var modified:=value.duplicate(true); modified.sha256="a".repeat(64)
	check(pool.model_template(modified)!=first,"Changed original source identity creates a distinct template")
	var previous:=pool.unshaded; pool.unshaded=not previous
	check(pool.model_template(value)!=first,"Material publication settings participate in template identity")
	pool.unshaded=previous; pool.maximum_templates=1; pool.model_template(bundle("auth_other"))
	check(pool.templates.size()==1 and pool.stats.template_evictions>0 and b.parts.size()==1,"Bounded cache eviction leaves live physical instances intact")
	a.retire(); b.retire(); await process_frame; await process_frame; pool.clear()
	check(pool.templates.is_empty() and pool.template_order.is_empty(),"World retirement releases all template cache bindings")
	var folder:=OS.get_temp_dir().path_join("nwn-template-stream-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	write(folder.path_join("auth_mesh.mdl"),source("auth_mesh"))
	for name in ["placeables","genericdoors","doortypes"]: write(folder.path_join(name+".2da"),"2DA V2.0\n\nModelName\n0 auth_mesh\n")
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored raw static model/table catalog mounts")
	var streamed:=Pool.new(); var alive: Array=[]; var tracked: Array=[]; var batch_metrics: Array=[]
	for batch_index in 4:
		var rows: Array=[]
		for index in 12: rows.append({"id":100+batch_index*12+index,"objectType":9,"areaId":1,"replicated":{"appearance":0,"position":[float(index),float(batch_index),0]}})
		var owner:=Stream.new(); host.add_child(owner); owner.configure(catalog,streamed,rows,1,"")
		var deadline:=Time.get_ticks_msec()+10000
		while not owner.done and Time.get_ticks_msec()<deadline: await process_frame
		check(owner.done and owner.stats.errors.is_empty() and owner.instances.size()==12,"Real background batch completes "+str(batch_index))
		batch_metrics.append(owner.stats.duplicate(true))
		for id in owner.instances.keys():
			var instance=owner.instances[id]; instance.reparent(host,true); owner.instances.erase(id); alive.append(instance); tracked.append(weakref(instance))
		owner.close(); owner.queue_free(); await process_frame
	check(streamed.stats.templates_created==1 and streamed.stats.template_hits==3,"Four independently retired stream owners build the model template only once")
	check(alive.size()==48 and alive[0].parts[0]!=alive[12].parts[0] and alive[0].meshes[0].mesh==alive[12].meshes[0].mesh,"Cross-batch scenes preserve all 48 private instances and shared geometry")
	var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(5,10,14); camera.look_at(Vector3(5,0,-1)); camera.current=true
	var metrics:=streamed.stats.duplicate(); var image_path:=""
	for frame in 5: await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw; image_path=str(args.report).trim_suffix(".json")+".png"; root.get_texture().get_image().save_png(image_path)
	for instance in alive: instance.retire()
	alive.clear(); first=null; second=null; await process_frame; await process_frame; streamed.clear(); host.queue_free(); await process_frame; await process_frame
	check(tracked.all(func(reference):return reference.get_ref()==null),"All actual streamed instances retire after cached template reuse")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"batch_metrics":batch_metrics,"pool":metrics,"rendered_image":image_path,"network_connections":0,"scope":"Original model-cache routing and native cross-batch template reuse/ownership/eviction; authored static source, no FPS/cold-load or complete visual parity acceptance"},"\t")); file.close(); print("NATIVE_TEMPLATE_CACHE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
