extends SceneTree
# Read-only installed-rule inspection; output is derived speed metadata, not
# a copy of the original 2DA or any model/texture resource. No connection.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var catalog:=Catalog.new(); var errors: Array=[]
	if not catalog.mount_install(str(args.install)): errors.append(catalog.failure)
	var speed_bytes: PackedByteArray=catalog.get_resource("creaturespeed",2017); var speed_parser:=Table.new(); var speed:=speed_parser.parse(speed_bytes.get_string_from_ascii())
	if not speed_parser.failure.is_empty(): errors.append(speed_parser.failure)
	var appearance_bytes: PackedByteArray=catalog.get_resource("appearance",2017); var appearance_parser:=Table.new(); var appearance:=appearance_parser.parse(appearance_bytes.get_string_from_ascii())
	if not appearance_parser.failure.is_empty(): errors.append(appearance_parser.failure)
	var rates: Array=[]; var index:=0
	for row in speed.get("orderedRows",[]):
		rates.append({"physical_row":index,"label":str(row.get("Label","")),"name":str(row.get("2DAName","")),"walk_m_s":float(row.get("WALKRATE","0")),"run_m_s":float(row.get("RUNRATE","0"))}); index+=1
	var pc_appearances: Array=[]
	for id in mini(7,appearance.get("orderedRows",[]).size()):
		var row: Dictionary=appearance.orderedRows[id]; pc_appearances.append({"physical_row":id,"label":str(row.get("LABEL","")),"move_rate_category":str(row.get("MOVERATE",""))})
	var report:={"success":errors.is_empty(),"checks":3,"errors":errors,"network":false,"scope":"Original installed KEY/BIF rule projection; no server/module/Workshop overrides or live original process","creaturespeed_sha256":preload("res://systems/native_data/prepared_cache.gd").digest(speed_bytes),"appearance_sha256":preload("res://systems/native_data/prepared_cache.gd").digest(appearance_bytes),"rates":rates,"pc_appearances":pc_appearances}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); quit(0 if errors.is_empty() else 1)
