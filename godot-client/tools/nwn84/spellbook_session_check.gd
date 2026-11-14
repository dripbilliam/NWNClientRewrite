extends SceneTree
const Session=preload("res://systems/native_data/session_catalog.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.trim_prefix("--install=")
	if install.is_empty(): quit(2); return
	var phases: Array=[]; var last: Dictionary={}
	var prepared: Dictionary=Session.prepare({"install":install,"language":"en","preloadBulkIconSources":true},Callable(),func(phase: String,completed: int,total: int):
		if phases.is_empty() or phases.back()!=phase: phases.append(phase)
		last.merge({"phase":phase,"completed":completed,"total":total},true))
	if not str(prepared.get("error","")).is_empty(): push_error("Session preparation failed: "+str(prepared.error)); quit(3); return
	var stats: Dictionary=prepared.stats
	var icons: Dictionary=stats.get("spellbook_icon_sources",{})
	if phases!=["item-icons","spellbook-icons"] or int(icons.get("completed",-1))!=int(icons.get("total",-2)) or int(icons.get("total",0))<1100:
		push_error("Spellbook source phase missing from startup publication: "+JSON.stringify({"phases":phases,"icons":icons,"last":last})); quit(4); return
	print(JSON.stringify({"phases":phases,"spellbook_total":icons.total,"spellbook_loaded":icons.loaded,"item_reused":icons.item_reused,"missing":icons.missing,"resident_bytes":icons.resident_bytes,"last_progress":last,"rendering_prepared":stats.rendering_prepared}))
	quit()
