extends SceneTree

const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Lobby=preload("res://systems/native_character_lobby.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")

class RosterOwner extends Node:
	var choices: Array=[]
	var preview: Dictionary={}
	var sync_calls:=0
	func catalog_choices(_text) -> Array: return choices
	func record_preview() -> Variant: return preview
	func sync_native() -> void: sync_calls+=1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var install:=""; var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--report="): output=arg.substr(9)
	var failures: Array[String]=[]
	var catalog=Catalog.new()
	if install.is_empty() or not catalog.mount_install(install): failures.append("Could not mount the original installation")
	if failures.is_empty(): catalog.mount_directory(install.path_join("data/prt"),90000000,[3,2033],"portraitsinstall")
	var base:=""
	if failures.is_empty():
		for candidate in catalog.resource_names(3):
			var name:=str(candidate)
			if name.ends_with("s") and catalog.has_resource(name.trim_suffix("s")+"l",3): base=name.trim_suffix("s"); break
	if base.is_empty(): failures.append("Original installation has no matching small/large portrait pair")
	var owner:=RosterOwner.new(); root.add_child(owner)
	var art:=Art.new(); root.add_child(art); art.configure(catalog,ProjectSettings.globalize_path("user://nwn84-character-portrait-cache"))
	var lobby:=Lobby.new(); root.add_child(lobby); lobby.owner_ui=owner; lobby.data_art=art; lobby.data_catalog=catalog; lobby.text_owner=Talk.new(); lobby.rules.text=lobby.text_owner
	owner.choices=[{"portraitRef":base,"source":"server"}]
	var first:=lobby.warm_portraits()
	if int(first.total)!=2: failures.append("Roster did not request both original chooser portrait sizes")
	var settled:=false
	for i in 600:
		await process_frame
		var state:=lobby.portrait_warm_state()
		if not str(state.failure).is_empty(): failures.append(str(state.failure)); break
		if state.ready: settled=true; break
	if not settled: failures.append("Original portrait warm did not complete")
	if settled:
		for key in lobby.portrait_warm_targets:
			if art.ui_assets.lookup("raster",str(key)).is_empty(): failures.append("Portrait was not retained by the shared session owner: "+str(key))
		var before: int=art.assets.serial
		var repeat:=lobby.warm_portraits()
		if not repeat.ready or art.assets.serial!=before: failures.append("A warm roster repeated portrait reads")
		owner.choices=[]; var empty:=lobby.warm_portraits()
		if not empty.ready or not lobby.portrait_warm_targets.is_empty(): failures.append("Roster retirement retained obsolete hidden targets")
		for key in art.textures:
			if art.ui_assets.lookup("raster",str(key)).is_empty(): failures.append("Raster residency ended when a roster target retired")
	owner.choices=[{"portrait":0,"source":"server"}]
	var table_pending:=lobby.warm_portraits()
	if table_pending.ready or int(table_pending.total)!=1: failures.append("Numeric portrait was admitted before its original portraits table")
	lobby.text_owner.tables["portraits"]={"orderedRows":[{"BaseResRef":base.trim_prefix("po_")}]}
	var numeric:=lobby.warm_portraits()
	if not numeric.ready or int(numeric.total)!=2: failures.append("Numeric portrait did not resolve to the same resident original rasters")
	lobby.clear_portrait_warm_targets(); lobby.owner_ui=null; lobby.free(); art.close(); art.free(); owner.free()
	var report:={"success":failures.is_empty(),"originalPortraitBase":base,"failures":failures,"scope":"Original installed chooser raster preparation, shared strong residency, stable repeat, roster target retirement"}
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
