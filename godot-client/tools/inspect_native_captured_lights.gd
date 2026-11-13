extends SceneTree
# Read-only captured original light metadata. No world, renderer or network.
const Catalog=preload("res://systems/native_data/recorded_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
func scene_metadata(catalog,index: Dictionary,path: String) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ);var header: Dictionary={};var focus: Array=[]
	if file==null:return {"error":"Captured timeline unavailable"}
	while not file.eof_reached():
		var line:=file.get_line()
		if line.is_empty():continue
		var event: Variant=JSON.parse_string(line)
		if not event is Dictionary or event.get("kind","")!="frame":continue
		var message: Dictionary=event.get("value",{})
		if message.get("kind","")=="raw-world-begin":header=message.data
		if message.get("kind","")=="raw-world-chunk":
			for object in message.objects:
				if int(object.id)==int(header.get("controlledId",-1)) and object.get("replicated",{}).get("position") is Array:focus=object.replicated.position
	file.close()
	if header.is_empty():return {"error":"Captured raw-world header unavailable"}
	if focus.size()!=3:focus=header.get("entry",{}).get("position",[0,0,0])
	var bytes: PackedByteArray=catalog.get_resource("placeables",2017)
	if not catalog.failure.is_empty():return {"error":catalog.failure}
	var parser:=Table.new();var table:=parser.parse(Binary.new(bytes).text(0,bytes.size()))
	if not parser.failure.is_empty():return {"error":parser.failure}
	var rows: Array=[]
	for family in ["placeableLights","staticPlaceables"]:
		for item in header.area.get(family,[]):
			var appearance:=int(item.appearance);var source: Dictionary=table.orderedRows[appearance] if appearance>=0 and appearance<table.orderedRows.size() else {}
			var name:=str(source.get("ModelName",source.get("Model",""))).to_lower();var point: Array=item.position
			var delta:=Vector3(point[0]-focus[0],point[1]-focus[1],point[2]-focus[2])
			rows.append({"id":item.id,"family":family,"appearance":appearance,"model":name,"position":point,"distance":delta.length(),"table":source,"model_metadata":index.get(name,{})})
	rows.sort_custom(func(a,b):return float(a.distance)<float(b.distance))
	return {"error":"","area":header.area.id,"focus":focus,"objects":rows,"scope":"Captured physical appearance/model metadata around the captured player; no live/GPU admission or lamp placement proof."}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["catalog","report"]) or FileAccess.file_exists(args.report): quit(2);return
	var catalog:=Catalog.new();var failures: Array=[];var models: Array=[];var model_index: Dictionary={};var known_misses: Array=[];var checked:=0
	if not catalog.mount(args.catalog): failures.append(catalog.failure)
	else:
		var identities: Array=catalog.manifest.resources.keys();identities.sort()
		for identity in identities:
			if not str(identity).ends_with(":2002"):continue
			if catalog.manifest.resources[identity].has("error"):
				known_misses.append({"resource":identity,"error":catalog.manifest.resources[identity].error});continue
			var name:=str(identity).trim_suffix(":2002");var bytes:=catalog.get_resource(name,2002)
			if not catalog.failure.is_empty():failures.append(name+": "+catalog.failure);continue
			var parser:=Actor.new();var value:=parser.parse(bytes);checked+=1
			if not parser.failure.is_empty():failures.append(name+": "+parser.failure);continue
			var lamps: Array=[];var emitters:=0
			for node in value.get("nodes",[]):
				if not node.get("light",{}).is_empty():lamps.append({"name":node.name,"parent":node.get("parent",-1),"position":node.get("position",[]),"properties":node.light})
				if not node.get("emitter",{}).is_empty():emitters+=1
			var metadata:={"name":name,"sha256":catalog.manifest.resources[identity].sha256,"lights":lamps,"emitters":emitters}
			model_index[name]=metadata
			if not lamps.is_empty():models.append(metadata)
	if models.is_empty():failures.append("No physical light metadata was decoded")
	var result:={"success":failures.is_empty(),"checks":checked,"failures":failures,"models":models,"recorded_lookup_misses":known_misses,"publicConnections":0,"scope":"Read-only native decoding of recorded original MDL light metadata. Recorded lookup failures are listed separately; unexpected read/parse errors fail. No world, GPU, live instance placement, admission or shadow rendering acceptance."}
	if args.has("timeline"):
		result.scene=scene_metadata(catalog,model_index,args.timeline)
		if not str(result.scene.error).is_empty():result.success=false;failures.append(result.scene.error)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
