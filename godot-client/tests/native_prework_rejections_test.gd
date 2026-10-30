extends SceneTree
const Controller=preload("res://systems/native_asset_prework.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Store=preload("res://systems/native_data/prework_store.gd")
const Settings=preload("res://systems/native_render_settings.gd")
var checks:=0
var failures: Array=[]
var folder:=""
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func write_model(name: String,valid: bool,parent: String="NULL") -> void:
	var file:=FileAccess.open(folder.path_join("input/"+name+".mdl"),FileAccess.WRITE)
	file.store_string("newmodel %s\nsetsupermodel %s %s\nbeginmodelgeom %s\nnode dummy root\nparent NULL\n%s\nendnode\nendmodelgeom %s\n"%[name,name,parent,name,"" if valid else "verts invalid",name]); file.close()
func prepare() -> Dictionary:
	var catalog:=Catalog.new(); catalog.mount_directory(folder.path_join("input")); catalog.build_resource_index()
	var owner:=Controller.new(); root.add_child(owner); owner.set_workers(8)
	var events: Array=[]; var bounded: Array=[true]
	owner.diagnostic_event.connect(func(event):events.append(event.duplicate(true)))
	owner.changed.connect(func(state):
		if state.get("active_jobs",[]).size()>8: bounded[0]=false)
	check(owner.start(catalog,folder.path_join("cache")),"Explicit preparation starts")
	var deadline:=Time.get_ticks_msec()+30000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not owner.state.active and owner.state.completed==6,"All six actual worker jobs finish")
	check(bounded[0] and owner.state.get("active_jobs",[]).is_empty(),"Active model tracking stays bounded and drains")
	for event in events:
		check(not event.model.is_empty() and event.route in ["static-model","actor-model"] and event.worker_ms>0,"Failure diagnostics identify the worker, model and elapsed time")
	var state: Dictionary=owner.state.duplicate(true); state.events=events
	owner.close(); owner.queue_free(); await process_frame
	return state
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("folder") or not args.has("report") or FileAccess.file_exists(str(args.report)): quit(2); return
	folder=str(args.folder); var cold: bool=args.get("phase","")=="cold"
	if cold:
		DirAccess.make_dir_recursive_absolute(folder.path_join("input"))
		write_model("broken",false); write_model("parent",false); write_model("child",true,"parent")
	var first:=await prepare()
	check(first.failed==5 and first.saved+first.reused==1,"Rejected assets remain unavailable, never successful cache hits")
	check(first.rejection_hits==(0 if cold else 5),"A fresh process reuses persisted failures only after the first run")
	if not cold:
		var settings:=Settings.new(); root.add_child(settings); settings.setup(folder.path_join("options.cfg"),""); settings.update_prework(first)
		check(settings.prework_status.text.contains(first.last_error_model) and settings.prework_status.text.contains(first.last_error_route),"The UI attributes the retained issue to its own model and route")
		root.size=Vector2i(1100,800); settings.tabs.current_tab=settings.tabs.get_tab_count()-1; settings.show(); await process_frame; await process_frame
		check(settings.prework_folder.get_global_rect().end.y<=800 and settings.prework_status.get_parent().get_global_rect().end.y<=settings.prework_folder.global_position.y,"Issue text leaves file actions visible inside the viewport")
		if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(str(args.report)+".png")
		settings.queue_free()
		write_model("parent",true)
		var updated:=await prepare()
		check(updated.failed==2 and updated.rejection_hits==2 and updated.saved==3 and updated.reused==1,"Changing a supermodel retries dependent failures and keeps unrelated failure memos")
		write_model("broken",true)
		var repaired:=await prepare()
		check(repaired.failed==0 and repaired.saved==2 and repaired.reused==4,"Changing rejected root bytes retries and saves repaired models")
		var store:=Store.new(); store.configure(folder.path_join("cache")); var cleared:=store.clear()
		check(cleared.removed>6 and DirAccess.get_files_at(store.directory).is_empty(),"Clear removes both generated bundles and rejection records")
		write_model("broken",false)
		var after_clear:=await prepare()
		check(after_clear.failed==2 and after_clear.rejection_hits==0,"Cleared failure records are rebuilt on an explicit later preparation")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"phase":args.get("phase","")}
	var output:=FileAccess.open(str(args.report),FileAccess.WRITE); output.store_string(JSON.stringify(result,"\t")); output.close(); print(JSON.stringify(result)); quit(0 if result.success else 1)
