extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("list") or not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new()
	if not catalog.mount_install(args.install):print("CATALOG_FAILURE ",catalog.failure);quit(1);return
	var listing: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.list))
	if not listing.has("models") or not listing.models is Array or listing.models.is_empty():print("LIST_FAILURE ",args.list);quit(1);return
	var modes: Dictionary={};var updates: Dictionary={};var errors: Array=[];var parsed:=0;var emitters:=0
	for sample: Dictionary in listing.models:
		var name:=str(sample.name);var bytes:=catalog.get_resource(name,2002)
		if bytes.is_empty() or not catalog.failure.is_empty():errors.append({"name":name,"error":catalog.failure});continue
		var model: Dictionary={};var parser_error:=""
		if bytes.size()>=4 and bytes.decode_u32(0)==0:
			var parser:=Actor.new();model=parser.parse(bytes);parser_error=parser.failure
		else:
			var parser:=Ascii.new();model=parser.parse(Binary.new(bytes).text(0,bytes.size()));parser_error=parser.failure
		if not parser_error.is_empty() or model.is_empty():errors.append({"name":name,"error":parser_error});continue
		parsed+=1
		for node: Dictionary in model.nodes:
			if not node.has("emitter"):continue
			emitters+=1
			var mode:=str(node.emitter.get("render",""));var update:=str(node.emitter.get("update",""))
			if not modes.has(mode):modes[mode]={"count":0,"examples":[]}
			modes[mode].count+=1
			if modes[mode].examples.size()<3:modes[mode].examples.append({"model":name,"sha256":Cache.digest(bytes),"node":str(node.name),"update":update,"flags":int(node.emitter.get("flags",0))})
			updates[update]=int(updates.get(update,0))+1
		if parsed%8==0:await process_frame
	var result:={"success":true,"list_sha256":FileAccess.get_sha256(args.list),"requested":listing.models.size(),"parsed":parsed,"emitters":emitters,"modes":modes,"updates":updates,"errors":errors,"gpu_execution":false,"scope":"Read-only installed original MDL mode census over the sealed recorded model-name list; no particle simulation, GPU or FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0)
