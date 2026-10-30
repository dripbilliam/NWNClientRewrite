extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var catalog:=Catalog.new()
	for index in 48:
		var entries: Dictionary={}
		for resource in 400: entries["auth"+str(resource)+":2017"]={"owner":index}
		entries["unique"+str(index)+":2017"]={"owner":index}
		catalog.layers.append({"kind":"authored","entries":entries,"serial":index,"priority":100-index})
	var expected: Dictionary={}
	for index in 448:
		var name:="auth"+str(index) if index<400 else "unique"+str(index-400)
		expected[name]=catalog.location(name,2017)
	var built:=catalog.build_resource_index()
	check(built.resolved_entries==448,"Resolved index deduplicates ordered table bindings")
	var match_all:=true
	for name in expected:
		if catalog.location(name.to_upper(),2017)!=expected[name]: match_all=false
	check(match_all,"All collision-heavy winners and unique resources match original ordered lookup")
	check(catalog.location("absent",2017).is_empty(),"Missing bindings remain missing")
	check(catalog.resource_names(2017).size()==448 and catalog.resource_names(3).is_empty(),"Name enumeration preserves unique identities and resource types")
	var copy=catalog.fork()
	check(copy.resolved_ready and copy.location("unique47",2017)==catalog.location("unique47",2017),"Worker fork retains compiled immutable bindings")
	catalog.reset()
	check(copy.location("auth0",2017).entry.owner==0 and catalog.location("auth0",2017).is_empty(),"Reset does not mutate already published fork bindings")
	var raster:=Catalog.new()
	raster.layers=[{"kind":"loose","storage_class":2,"entries":{"image:3":{}}},{"kind":"nwsync","storage_class":5,"entries":{"image:2033":{}}}]
	var before:=raster.raster_location("image"); raster.build_resource_index()
	check(before==raster.raster_location("image") and before.type==3,"Cross-format storage precedence survives flattening")
	var folder:=OS.get_temp_dir().path_join("nwn-resource-index-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var file:=FileAccess.open(folder.path_join("auth.2da"),FileAccess.WRITE); file.store_string("original"); file.close()
	var live:=Catalog.new(); check(live.mount_directory(folder),"Real loose source mounts")
	live.build_resource_index(); var old=live.fork()
	check(old.get_resource("auth",2017).get_string_from_utf8()=="original" and old.stats.loose_read_us>=0 and old.stats.lookups>0,"Native source read records stage diagnostics")
	var override:=folder.path_join("override"); DirAccess.make_dir_recursive_absolute(override)
	file=FileAccess.open(override.path_join("auth.2da"),FileAccess.WRITE); file.store_string("override"); file.close()
	check(live.mount_directory(override,20000000) and not live.resolved_ready,"New mounted precedence invalidates only the new catalog's compiled bindings")
	live.build_resource_index()
	check(live.get_resource("auth",2017).get_string_from_utf8()=="override" and old.get_resource("auth",2017).get_string_from_utf8()=="original","New session index honors override without changing old reader ownership")
	for path in [override.path_join("auth.2da"),folder.path_join("auth.2da")]: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(override); DirAccess.remove_absolute(folder)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"index_stats":built,"publicConnections":0}
	file=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result)); file.close()
	quit(0 if result.success else 1)
