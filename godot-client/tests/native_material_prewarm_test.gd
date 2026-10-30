extends SceneTree
const Warmup=preload("res://systems/native_render/material_prewarm.gd")
const Catalog=preload("res://systems/native_data/recorded_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var checks:=0
var failures: Array=[]
var results: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""; var catalog_path:=""; var enabled:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--catalog="): catalog_path=arg.substr(10)
		elif arg=="--prewarm=true": enabled=true
	if report.is_empty() or catalog_path.is_empty() or FileAccess.file_exists(report): quit(2); return
	var warm:=Warmup.new(); root.add_child(warm); warm.start(enabled); warm.set_process(false)
	while not warm.recipes.is_empty(): warm.step()
	var warmed:=warm.snapshot()
	check(warmed.failures.is_empty() and warmed.done,"Requested native warmup completes without fallback/error")
	check(warmed.prepared==(20 if enabled else 0) and warmed.retained_materials==(20 if enabled else 0),"Exact bounded material variant set is retained only when enabled")
	check(warmed.retained_textures==(2 if enabled else 0),"Only two authored white warmup rasters are retained")
	check(warm.pool.templates.is_empty() and warm.pool.meshes.is_empty(),"Warmup creates no gameplay templates, mesh geometry or scene objects")
	var catalog:=Catalog.new(); check(catalog.mount(catalog_path),"Sealed actual material/model corpus mounts")
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.completed.connect(func(id,result):results[id]=result)
	var observations: Array=[]; Timing.enabled=true
	for name in ["ttu01_a02_03","ttu01_l08_04","ttu01_m01_04"]:
		var id:=service.request(name,2002,"static-model"); var deadline:=Time.get_ticks_msec()+60000
		while not results.has(id) and Time.get_ticks_msec()<deadline: await process_frame
		check(results.has(id) and str(results.get(id,{}).get("error","missing")).is_empty(),name+": actual original model/textures prepare")
		if not results.has(id) or not str(results[id].error).is_empty(): continue
		var pool:=Pool.new(); var instance:=Instance.new(); check(instance.install(results[id],pool),name+": original scene installation succeeds with original textures")
		observations.append({"model":name,"parts":instance.parts.size(),"meshes":instance.meshes.size(),"install":instance.install_timings.duplicate(true)})
		instance.free(); pool.clear(); results.erase(id); await process_frame
	service.close(); service.free(); results.clear()
	warm.close(); check(warm.materials.is_empty() and warm.pool.textures.is_empty() and warm.pool.materials.is_empty(),"Warmup close releases every owned material/texture binding")
	warm.free(); Timing.enabled=false; await process_frame; await process_frame
	var output:=FileAccess.open(report,FileAccess.WRITE); output.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"warmup":warmed,"observations":observations,"public_connections":0,"scope":"Actual native production material recipes and bounded retained shader request owners; sealed original source installs unchanged. Separate-process descriptive timing comparison, not world/FPS acceptance."},"\t")); output.close(); quit(0 if failures.is_empty() else 1)
