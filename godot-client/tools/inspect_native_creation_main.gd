extends SceneTree
# Source-only CPU inspection; no textures, viewports, game or server.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
var catalog:=Catalog.new()
var models: Dictionary={}
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func collect(node: Dictionary) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty() and not models.has(name):
		var parser:=Actor.new(); var model:=parser.parse(catalog.get_resource(name,2002))
		if not parser.failure.is_empty(): failures.append(name+": "+parser.failure)
		else: models[name]={"geometry":Geometry.model(model),"clips":model.animations.map(func(clip):return clip.name)}
	for child in node.get("Obj_ChildList",[]): collect(child)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	if not catalog.mount_install(args.install): failures.append(catalog.failure)
	var sources: Dictionary={}
	for name in ["cg_main","cg_sex","cg_race","util_editpopup"]:
		var parser:=Gff.new(); var source:=parser.parse(catalog.get_resource(name,2047))
		if not parser.failure.is_empty(): failures.append(name+": "+parser.failure)
		else: sources[name]=source.root; collect(source.root)
	for name in ["pnl_chrsht2","ctl_chrsht_nosiz","ctl_chr_btn_tab5","ctl_chr_btn_tab6","ctl_chr_btn_tab7","ctl_chr_btn_tab8","ctl_cg_btn_class"]: collect({"Obj_ResRef":name})
	var result:={"success":failures.is_empty(),"checks":sources.size(),"failures":failures,"sources":sources,"models":models,"publicConnections":0,"scope":"Original character-generation parent, gender and race GUI source geometry only. No rendered pixels or full workflow acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
