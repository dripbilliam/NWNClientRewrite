extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
var pending: Dictionary={}
var observed: Dictionary={}
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new()
	if not catalog.mount_install(args.install):quit(3);return
	var parser:=Gff.new();var source:=parser.parse(catalog.get_resource("cg_skills",2047));var labels: Array=[]
	for child in source.root.Obj_ChildList:
		var fields: Dictionary={}
		for key in child:
			if key in ["Obj_Parent","Obj_Parent_Hook","Obj_Tag","Obj_Type","Obj_Layer","Obj_NumTags","Obj_Caption"]:fields[key]=child[key]
		labels.append(fields)
	var assets:=Assets.new();root.add_child(assets);assets.configure(catalog);assets.maximum_workers=2
	assets.completed.connect(func(id,result):
		var name: String=pending[id];pending.erase(id)
		if not str(result.error).is_empty():failures.append(result.error)
		else:observed[name]=Geometry.model(result.value))
	for name in ["pnl_chr_genm","ctl_cg_lstbxsk","ctl_cg_btn_skill","ctl_cg_btn_skup","ctl_cg_btn_skdn","ctl_cg_numbox3","ctl_cg_help"]:pending[assets.request(name,2002,"actor-model")]=name
	var deadline:=Time.get_ticks_msec()+60000
	while not pending.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	assets.close();assets.free();await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty() and pending.is_empty(),"checks":observed.size(),"failures":failures,"source":source.root,"labels":labels,"models":observed,"publicConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
