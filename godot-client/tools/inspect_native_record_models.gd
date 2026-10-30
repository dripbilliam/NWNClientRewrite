extends SceneTree
# Programmatic CPanelCharSheet resources are absent from the GUI2047 catalog.
# Inspect their original geometry/hooks without rendering or executing actions.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var failures: Array=[]; var models: Dictionary={}; var decoder:=Assets.new()
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var names: Array=["pnl_chrsht","pnl_chrsht2","pnl_chrsht_char","pnl_chrsht_char2","pnl_chrsht_skils","pnl_chrsht_skil2","ctl_chrsht_resiz","ctl_chrsht_nosiz","ctl_chrsht_lstbx","ctl_chrsht_lvlup","ctl_chrsht_desc","gui_chrsht_hilit","ctl_iconlst_20"]
	for index in 8: names.append("ctl_chr_btn_tab"+str(index+1))
	for name in names:
		var raw: PackedByteArray=catalog.get_resource(name,2002); var prepared:=decoder.decode(raw,2002,"mdl-original","")
		if not str(prepared.error).is_empty(): failures.append(str(name)+": "+str(prepared.error)); continue
		var geometry:=Geometry.model(prepared.value)
		if not str(geometry.error).is_empty(): failures.append(str(name)+": "+str(geometry.error)); continue
		var hooks: Dictionary={}
		for key in geometry.hooks: hooks[key]=[geometry.hooks[key].x,geometry.hooks[key].y]
		models[name]={"sha256":Cache.digest(raw),"bytes":raw.size(),"drawn":geometry.drawn,"bounds":[geometry.bounds.position.x,geometry.bounds.position.y,geometry.bounds.size.x,geometry.bounds.size.y],"hooks":hooks,"animations":prepared.value.get("animations",[]).map(func(a):return str(a.get("name","")))}
	decoder.free()
	var result:={"success":failures.is_empty() and models.size()==names.size(),"checks":models.size(),"failures":failures,"models":models,"publicConnections":0,"toolSha256":FileAccess.get_sha256(ProjectSettings.globalize_path("res://tools/inspect_native_record_models.gd")),"scope":"Original programmatically assembled character-sheet model geometry/hook metadata. No pixels exported, UI implemented, callbacks executed or character-sheet visual/action parity accepted."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
