extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Sources=preload("res://systems/native_data/spellbook_icon_sources.gd")
class OtherBinding extends RefCounted:
	func location(_name: String,_type: int) -> Dictionary:
		return {"layer":{"binding_identity":"different binding"}}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.trim_prefix("--install=")
	var catalog:=Catalog.new()
	if install.is_empty() or not catalog.mount_install(install): quit(2); return
	catalog.build_resource_index()
	var last_progress: Dictionary={}
	var result: Dictionary=Sources.preload_all(catalog,Callable(),func(phase: String,completed: int,total: int):last_progress.merge({"phase":phase,"completed":completed,"total":total},true))
	if result.total<1100 or not result.failures.is_empty() or result.loaded+result.reused+result.item_reused+result.missing.size()!=result.total:
		push_error("Original icon source admission mismatch: "+JSON.stringify(result)); quit(3); return
	if last_progress.get("phase")!="spellbook-icons" or int(last_progress.get("completed",-1))!=int(result.total):
		push_error("Source progress did not finish"); quit(4); return
	var sample: String=""; var type:=0
	for name in Sources.referenced(catalog):
		var selected: Dictionary=catalog.raster_location(str(name))
		if not selected.is_empty() and not Sources.lookup(catalog,str(name),int(selected.type)).is_empty():
			sample=str(name); type=int(selected.type); break
	if sample.is_empty() or Sources.lookup(catalog,sample,type)!=catalog.read_resource(sample,type):
		push_error("Resident bytes differ from selected original binding"); quit(5); return
	if not Sources.lookup(OtherBinding.new(),sample,type).is_empty():
		push_error("Different binding reused stale source bytes"); quit(6); return
	print(JSON.stringify({"total":result.total,"loaded":result.loaded,"item_reused":result.item_reused,"missing":result.missing,"resident_bytes":result.resident_bytes,"progress":last_progress,"binding":"pass"}))
	quit()
