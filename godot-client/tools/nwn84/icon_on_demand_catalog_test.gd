extends SceneTree
const Session=preload("res://systems/native_data/session_catalog.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Sources=preload("res://systems/native_data/item_icon_sources.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func run() -> void:
	var install:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): report=arg.substr(9)
	var cache_root:=ProjectSettings.globalize_path("res://.cache").simplify_path()
	var report_path:=ProjectSettings.globalize_path("res://").path_join(report).simplify_path()
	if install.is_empty() or report.is_empty() or not report_path.begins_with(cache_root+"/") or FileAccess.file_exists(report_path): quit(2); return
	var phases: Array=[]; var began:=Time.get_ticks_msec()
	var prepared: Dictionary=Session.prepare({"install":install},Callable(),func(phase,_completed,_total):phases.append(phase))
	var catalog=prepared.get("catalog"); var startup_ms:=Time.get_ticks_msec()-began
	check(str(prepared.get("error","")).is_empty() and catalog!=null,"Default installed catalog prepares")
	var stats: Dictionary=prepared.get("stats",{})
	check(bool(stats.get("item_icon_sources",{}).get("deferred",false)) and bool(stats.get("spellbook_icon_sources",{}).get("deferred",false)) and not phases.has("item-icons") and not phases.has("spellbook-icons"),"Default catalog skips both bulk icon byte phases")
	var names: Array=["iashlw_011","is_acidfog","gui_chrsht_str"]
	var first_reads:=int(catalog.stats.reads)
	for name in names:
		var selected: Dictionary=catalog.raster_location(name)
		check(not selected.is_empty(),"Selected original raster format exists for "+name)
		var first: PackedByteArray=catalog.get_resource(name,int(selected.get("type",-1)))
		check(not first.is_empty() and catalog.failure.is_empty(),"On-demand original raster read succeeds for "+name)
		var after_first:=int(catalog.stats.reads); var hits_before:=int(catalog.stats.source_memory_hits)
		var second: PackedByteArray=catalog.get_resource(name,int(selected.type))
		check(second==first and int(catalog.stats.reads)==after_first and int(catalog.stats.source_memory_hits)>hits_before,"Second lookup reuses catalog source store for "+name)
	check(int(catalog.stats.reads)>=first_reads+names.size() and Sources.snapshot().sources==0,"First-use originals read from selected archives without global icon source residency")
	var override_dir:=report_path.trim_suffix(".json")+"-override"; check(DirAccess.make_dir_recursive_absolute(override_dir)==OK,"Contained server override directory created")
	var original: PackedByteArray=catalog.get_resource("is_acidfog",3)
	var override_file:=override_dir.path_join("is_acidfog.tga")
	var file:=FileAccess.open(override_file,FileAccess.WRITE); file.store_buffer(original); file.close()
	var server:=Catalog.new(); check(server.mount_install(install) and server.mount_directory(override_dir,50000000),"Server catalog mounts selected loose override")
	var base_key: String=str(catalog.location("is_acidfog",3).layer.get("binding_identity",""))
	var server_key: String=str(server.location("is_acidfog",3).layer.get("binding_identity",""))
	var server_bytes: PackedByteArray=server.get_resource("is_acidfog",3)
	check(base_key!=server_key and server_bytes==original and int(server.stats.reads)>0 and Sources.lookup(server,"is_acidfog",3).is_empty(),"Demand lookup uses server-selected identity without installed payload aliasing")
	check(DirAccess.remove_absolute(override_file)==OK and DirAccess.remove_absolute(override_dir)==OK,"Only fixture-created override is removed")
	var diagnostic:={"startup_ms":startup_ms,"phases":phases,"item_source_stats":stats.get("item_icon_sources",{}),"spell_source_stats":stats.get("spellbook_icon_sources",{}),"catalog_reads":catalog.stats.reads,"catalog_source_memory_hits":catalog.stats.source_memory_hits,"server_reads":server.stats.reads}
	file=FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
