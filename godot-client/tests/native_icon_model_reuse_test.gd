extends SceneTree
const Icons=preload("res://systems/native_item_icons.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func wait_texture(owner,key: String) -> Texture2D:
	var deadline:=Time.get_ticks_msec()+30000
	while not owner.textures.has(key) and Time.get_ticks_msec()<deadline and owner.stats.errors.is_empty(): await process_frame
	return owner.textures.get(key)
func run() -> void:
	var report:=""; var catalog_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--catalog="): catalog_path=arg.substr(10)
	if report.is_empty() or catalog_path.is_empty() or FileAccess.file_exists(report): quit(2); return
	var catalog:=Recorded.new(); check(catalog.mount(catalog_path),"Sealed original GUI corpus opens without network/install fallback")
	var owners: Array=[]; var images: Array=[]; var bounds: Array=[]
	for enabled in [false,true]:
		var owner:=Icons.new(); root.add_child(owner); owner.reuse_models_enabled=enabled; owner.maximum_cached_models=1; owner.configure(catalog,""); owners.append(owner)
		var rendered: Array=[]; var boxes: Array=[]
		for clip in ["up","down","hilite"]:
			var key: String=owner.request_model("pb_but_inv",clip); var texture:=await wait_texture(owner,key)
			check(texture!=null,"Actual original GUI state renders: "+str(enabled)+":"+clip+" "+str(owner.stats.errors))
			if texture!=null: rendered.append(texture.get_image().get_data()); boxes.append(owner.image_bounds[key])
		images.append(rendered); bounds.append(boxes)
		check(owner.cached_models.size()==(1 if enabled else 0),"Model cache respects configured mode and one-root bound")
		if enabled:
			check(owner.stats.model_reuses==2,"Three original animation states reuse one private physical GUI model")
			# Preserve the failure and finish/drain even when a corpus is missing
			# dependencies or its current pose adapter is deliberately transient.
			if owner.cached_models.is_empty(): continue
			var held: Node3D=owner.cached_models.values()[0]
			check(not held.visible and not held.rigs.is_processing(),"Cached GUI model is hidden with animation processing disabled")
			var key: String=owner.request_model("pb_but_map","up"); check(await wait_texture(owner,key)!=null,"A second model still renders when the bounded cache is full")
			check(owner.cached_models.size()==1 and owner.stats.model_cache_full==1,"Full cache keeps its bound and uses the compatible transient path")
			key=owner.request_model("pb_but_inv","up",{},1); check(await wait_texture(owner,key)!=null,"Turned GUI art retains the transient rendering path")
			check(owner.cached_models.size()==1 and owner.stats.model_reuses==2,"Turned art cannot accumulate rotation on a reused actor")
	check(images[0].size()==3 and images[0]==images[1],"Every original GUI state has byte-exact GPU pixels with and without reuse")
	check(bounds[0]==bounds[1],"State-specific original artwork bounds stay exact")
	var held_refs: Array=[]
	for owner in owners:
		for model in owner.cached_models.values(): held_refs.append(weakref(model))
		owner.close(); check(owner.cached_models.is_empty() and owner.assets.running.is_empty(),"Owner close clears every cache binding and drains asset workers"); owner.queue_free()
	await process_frame; await process_frame
	check(held_refs.all(func(value):return value.get_ref()==null),"Session teardown frees every retained private GUI actor")
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Original GUI up/down/hilite pixels and bounds on actual graphical viewports; private model reuse, fixed bound, compatible overflow/turn paths and final drain. No full-world FPS claim"},"\t")); output.close(); quit(0 if failures.is_empty() else 1)
