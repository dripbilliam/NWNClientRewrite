extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const BookFrame=preload("res://systems/native_spellbook_frame.gd")
const Book=preload("res://systems/server_spellbook.gd")
class FakeArt extends RefCounted:
	var textures: Dictionary={}
class FakeFrame extends RefCounted:
	var art=FakeArt.new()
class FakeText extends RefCounted:
	var tables: Dictionary={}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.trim_prefix("--install=")
	var catalog:=Catalog.new()
	if install.is_empty() or not catalog.mount_install(install): quit(2); return
	var skin:=BookFrame.new(); skin.icon_catalog=catalog; skin.frame=FakeFrame.new(); skin.text_owner=FakeText.new(); skin.layout_ready=true
	skin.queue_original_icons()
	if skin.icon_seen.size()<1100 or skin.icon_queue.size()<1100: push_error("Installed icon census unexpectedly incomplete"); quit(3); return
	var last: String=skin.icon_queue.back()
	var view:={"classes":[],"known":[{"icon":last}],"memory":[],"family":[]}
	if skin.view_icons_ready(view) or skin.icon_queue.front()!=last: push_error("Current view was not admitted ahead of preload tail"); quit(4); return
	skin.frame.art.textures[last]=ImageTexture.new()
	if not skin.view_icons_ready(view): push_error("Resident view icon did not release admission"); quit(5); return
	if Book==null: push_error("Server spellbook script failed to load"); quit(6); return
	print(JSON.stringify({"installed_icons":skin.icon_seen.size(),"queued_rasters":skin.icon_queue.size(),"missing_rasters":skin.icon_failures.size(),"view_gate":"pass"}))
	quit()
