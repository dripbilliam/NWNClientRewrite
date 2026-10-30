extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Plan=preload("res://systems/native_data/ui_prebake_plan.gd")
const Model=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"UI prebake discovery mounts original assets read-only")
	var plan:=Plan.discover(catalog.fork())
	check(plan.issues.is_empty() and plan.gui_sources.size()==104,"All104 installed GUI documents are discovered before any menu must be opened")
	for name in ["ctl_opt_btn_key","pnl_opt_key","pnl_opt_key_page","ctl_btr_btn_acpt","inv_box_10x6","inv_box_3x10","gui_ra_menu","qb_but66","qb_but67","gui_qbar_ends"]:
		check(name in plan.models,"Original declared or programmatic widget enters UI discovery: "+name)
	check("fnt_galahad14" in plan.fonts and "fnt_dialog16x16" in plan.fonts,"Unopened GUI caption fonts enter the separate bake plan")
	check(not "c_golstone" in plan.models and not "pmh0_chest001" in plan.models,"UI discovery does not turn into a world/creature model bake")
	var bytes: PackedByteArray=catalog.get_resource("ctl_btn_64x24",2002); var reader:=Model.new(); var model:=reader.parse(bytes)
	check(reader.failure.is_empty(),"Original multi-state key tab model parses")
	var states:=Plan.states(model)
	check(states.size()==9 and states[0]=="" and Plan.STATES.all(func(state):return state in states),"Original rest and all eight button states enter native pixel preparation")
	check(Plan.states({"animations":[{"name":"size"},{"name":"thumbsize"},{"name":"UP"},{"name":"up"}]})==["","up"],"Generated size controllers are not mistaken for correctly posed static artwork")
	var models: Dictionary={}; var fonts: Dictionary={}
	Plan.collect({"Obj_ResRef":"CUSTOM_MENU","Obj_Caption":{"AurString_Font":"custom_font"},"Obj_ChildList":[{"Obj_ResRef":"custom_button","Obj_ChildList":[{"Obj_Caption":{"AurString_Font":"other_font"}}]}]},models,fonts)
	check(models=={"custom_menu":true,"custom_button":true} and fonts=={"custom_font":true,"other_font":true},"Server/custom nested GUI artwork and fonts are discovered without a fixed stock-only list")
	check(plan.native_data_only and not plan.pixels_prebaked and not plan.full_ui_prebake,"Discovery does not pretend the separate bake option or native pixels are finished")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"plan":plan,"tabModelSha256":Cache.digest(bytes),"publicConnections":0,"scope":"Read-only unopened GUI/widget/font discovery and original state planning. Native GPU baking, persistence, cancellation, the separate options control and cold-menu reuse remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
