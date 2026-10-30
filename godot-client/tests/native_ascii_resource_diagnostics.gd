extends SceneTree
const Catalog=preload("res://systems/native_data/session_catalog.gd")
const Static=preload("res://systems/native_data/ascii_model.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Text=preload("res://systems/native_data/binary_data.gd")
var result: Dictionary={}
var task:=-1
func _initialize() -> void: call_deferred("run")
func inspect(sources: Dictionary,names: Array) -> void:
	var prepared:=Catalog.prepare(sources)
	if not str(prepared.error).is_empty(): result={"error":prepared.error}; return
	var catalog=prepared.catalog; var rows: Array=[]
	for name in names:
		var bytes: PackedByteArray=catalog.get_resource(str(name),2002)
		if not catalog.failure.is_empty(): rows.append({"name":name,"error":catalog.failure}); continue
		if bytes.size()<4 or bytes.decode_u32(0)==0: rows.append({"name":name,"binary":true}); continue
		var source:=Text.new(bytes).text(0,bytes.size()); var parser:=Static.new(); var began:=Time.get_ticks_usec(); var model:=parser.parse(source)
		var row:={"name":name,"bytes":bytes.size(),"static_error":parser.failure,"static_ms":(Time.get_ticks_usec()-began)/1000.0,"source_nodes":parser.source_nodes.size(),"bad_counts":[],"duplicate_names":[],"self_parents":[]}
		var regex:=RegEx.new(); regex.compile("\\s+"); var number:=0
		for line in source.split("\n"):
			number+=1; var tokens:=Text.ascii_tokens(str(line).strip_edges(),regex)
			if tokens.size()>0 and tokens[0] in ["verts","tverts","faces"] and (tokens.size()!=2 or not tokens[1].is_valid_int() or int(tokens[1])<0 or int(tokens[1])>1000000): row.bad_counts.append({"line":number,"text":str(line).left(180)})
		var seen: Dictionary={}
		for node in parser.source_nodes:
			if seen.has(node.name) and row.duplicate_names.size()<8: row.duplicate_names.append(node.name)
			seen[node.name]=true
			if node.name==node.parent_name and row.self_parents.size()<8: row.self_parents.append(node.name)
		var actor:=Actor.new(); began=Time.get_ticks_usec(); actor.parse(bytes)
		row.actor_error=actor.failure; row.actor_ms=(Time.get_ticks_usec()-began)/1000.0; rows.append(row)
	for layer in catalog.layers:
		if layer.get("kind","")=="nwsync": layer.store.close()
	result={"models":rows,"public_connections":0}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("request") or not args.has("report"): quit(2); return
	var request: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.request)))
	var names: Array=Array(str(args.get("models","ashlw_051,ashlw_050,ashlw_052,ashto_041,atj16_s05_01,c_holstein,aef19b_o11_01")).split(","))
	task=WorkerThreadPool.add_task(inspect.bind(request.sources,names),false,"Inspect selected original ASCII resources")
	while not WorkerThreadPool.is_task_completed(task): await process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var output:=FileAccess.open(str(args.report),FileAccess.WRITE); output.store_string(JSON.stringify(result,"\t")); output.close(); print(JSON.stringify(result)); quit(0)
