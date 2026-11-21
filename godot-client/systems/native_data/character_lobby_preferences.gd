extends RefCounted
# Original CPlayModulePanel loads this boolean in708660 and saves in70a6b0.
# Storage belongs to this client; never change the original game's profile.
const SECTION:="game.character-generation"
const KEY:="show-pregenerated"
var path:=""
var show_pregenerated:=false
var failure:=""
var writes:=0
func open_file(value: String) -> void:
	path=value; show_pregenerated=false; failure=""; writes=0
	if path.is_empty() or not FileAccess.file_exists(path): return
	var saved:=ConfigFile.new()
	if saved.load(path)!=OK: failure="Could not read character-list preferences; the existing file was preserved."; return
	var checked: Variant=saved.get_value(SECTION,KEY,false)
	if not checked is bool: failure="Saved pregenerated-character preference is not a boolean; the existing file was preserved."; return
	show_pregenerated=checked
func save(value: bool) -> bool:
	show_pregenerated=value
	if path.is_empty(): return true
	if not failure.is_empty(): return false
	if DirAccess.dir_exists_absolute(path) or not DirAccess.dir_exists_absolute(path.get_base_dir()): failure="Could not save character-list preferences: the destination is unavailable."; return false
	# Preserve unrelated settings, including changes made since the chooser opened.
	var saved:=ConfigFile.new()
	if FileAccess.file_exists(path) and saved.load(path)!=OK: failure="Could not save character-list preferences; the existing file was preserved."; return false
	saved.set_value(SECTION,KEY,value)
	if saved.save(path)!=OK: failure="Could not save character-list preferences."; return false
	writes+=1; return true
func snapshot() -> Dictionary:
	return {"path":path,"show_pregenerated":show_pregenerated,"failure":failure,"writes":writes,"persistent":not path.is_empty(),"native_only":true}
