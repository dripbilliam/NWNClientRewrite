extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Plan=preload("res://systems/native_data/key_settings_layout.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func collect(source: Dictionary,found: Dictionary) -> void:
	var name:=str(source.get("Obj_ResRef","")).to_lower()
	if not name.is_empty(): found[name]=true
	for child in source.get("Obj_ChildList",[]): collect(child,found)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var sources: Dictionary={}; var models: Dictionary={}; var hashes: Dictionary={}; var requested:={"ctl_opt_btn_key":true}
	check(catalog.mount_install(install),"Original key-settings resources mount read-only")
	for name in ["options_key_pnl","options_key_page"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2047); var reader:=Gff.new(); var document:=reader.parse(bytes,"GUI ")
		check(catalog.failure.is_empty() and reader.failure.is_empty(),"Original key-settings GUI parses: "+name)
		if not reader.failure.is_empty(): continue
		sources[name]=document.root; hashes[name]=Cache.digest(bytes); collect(document.root,requested)
	for name in requested:
		var bytes: PackedByteArray=catalog.get_resource(name,2002); var reader:=Model.new(); var value:=reader.parse(bytes)
		check(catalog.failure.is_empty() and reader.failure.is_empty(),"Original key-settings component model parses: "+str(name))
		models[name]=value; hashes[name]=Cache.digest(bytes)
	var before: Dictionary=sources.duplicate(true); var definition:=Plan.parse(sources,models)
	check(str(definition.error).is_empty(),"Original key-panel page and dynamic rows resolve without guessed rectangles")
	if str(definition.error).is_empty():
		check(definition.size.distance_to(Vector2(430,447))<0.001 and definition.page.attachment.distance_to(Vector2(0,73))<0.001,"Source page hook extends the73px header into the430×447 complete panel")
		check(definition.entries.size()==6 and definition.page.entries.size()==4,"All original tabs, title, close, cancel, defaults and list controls remain distinct")
		check(definition.row.model.bounds.size.distance_to(Vector2(401,32))<0.001 and definition.row.step.distance_to(Vector2(0,35))<0.001,"Runtime key rows retain source401×32 artwork with35px progression")
		check(definition.row.first.distance_to(Vector2(5,107))<0.001 and definition.clip.position.distance_to(Vector2(6,73))<0.001,"First key row and list clipping derive from original listitem/top/bottom hooks")
		check(definition.row.text.align==Vector2(0,0.5) and definition.row.binding.align==Vector2(1,1),"Separate action/binding captions use original left-middle and right-bottom anchoring")
		check(definition.row.text.anchor.distance_to(Vector2(21,-16))<0.001 and definition.row.binding.anchor.distance_to(Vector2(394,-7))<0.001,"Key captions retain original text and label attachment positions")
		check(definition.entries.xbutton.callback==definition.page.entries.closebutton.callback and definition.page.entries.cancelbutton.callback!=definition.page.entries.closebutton.callback,"X and Close commit while Cancel retains its separate original discard callback")
		for tag in Plan.PANEL_ACTIONS: check(definition.entries[tag].callback==Plan.PANEL_ACTIONS[tag],"Original key-panel callback: "+str(tag))
		for tag in Plan.PAGE_ACTIONS: check(definition.page.entries[tag].callback==Plan.PAGE_ACTIONS[tag],"Original key-page callback: "+str(tag))
		var replacement: Dictionary=sources.duplicate(true)
		for child in replacement.options_key_page.Obj_ChildList:
			if str(child.Obj_Tag).to_lower()=="buttonlist": child.Obj_X+=0.1
		var shifted:=Plan.parse(replacement,models)
		check(str(shifted.error).is_empty() and shifted.row.first.distance_to(definition.row.first+Vector2(10,0))<0.001 and shifted.clip.position.distance_to(definition.clip.position+Vector2(10,0))<0.001,"Active GUI list replacement relocates row and clipping metadata together")
		var missing: Dictionary=models.duplicate(); missing.erase("ctl_opt_btn_key")
		check(not str(Plan.parse(sources,missing).error).is_empty(),"Missing original dynamic row artwork is an explicit preparation failure")
		var absent: Dictionary=sources.duplicate(true); absent.options_key_page.Obj_ChildList.pop_back()
		check(not str(Plan.parse(absent,models).error).is_empty(),"Missing original Cancel control cannot produce a misleading partial page")
		check(sources==before and definition.native_data_only and not definition.visible_keys_accepted and not definition.input_remapping_accepted and not definition.full_key_settings_parity,"Immutable key-layout data does not certify a visible window or gameplay remapping")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"resourceSha256":hashes,"definition":definition,"publicConnections":0,"fullKeySettingsParity":false,"scope":"Original installed key-settings GUI/models, attachments, callbacks and row text geometry only. Native visible page, keyboard dispatch, configuration persistence and original-window comparison remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
