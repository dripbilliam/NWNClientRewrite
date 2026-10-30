extends SceneTree
const Loader=preload("res://systems/native_data/session_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Workshop=preload("res://systems/native_data/workshop_index.gd")
const Vdf=preload("res://systems/native_data/steam_vdf.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func digest(bytes: PackedByteArray) -> String:
	var context:=HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty(): context.update(bytes)
	return context.finish().hex_encode()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var metrics: Array=[]
	for variant in fixture.variants:
		var loader:=Loader.new(); root.add_child(loader); var prepared: Dictionary={}
		loader.completed.connect(func(_serial: int,catalog: RefCounted,error: String,stats: Dictionary):prepared.merge({"catalog":catalog,"error":error,"stats":stats}))
		loader.start(variant.sources)
		var deadline:=Time.get_ticks_msec()+10000
		while prepared.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(not prepared.is_empty() and str(prepared.get("error","unfinished")).is_empty(),"Native local content setup")
		if prepared.is_empty() or not str(prepared.error).is_empty(): print(prepared.get("error","unfinished")); loader.close(); loader.queue_free(); continue
		var catalog=prepared.catalog
		check(int(prepared.stats.worker_thread)!=OS.get_main_thread_id(),"Directory/Steam/archive discovery runs on worker")
		check(prepared.stats.workshop_mods==variant.roots,"Installed Workshop membership/order and disabled mods match oracle")
		check(catalog.stats.payload_bytes==0 and catalog.stats.reads==0,"Mounting local catalogs reads no payloads")
		for query in variant.resources:
			check(catalog.has_resource(query.name,int(query.type))==query.present,"Native resource presence: "+str(query.name))
			if query.present:
				var bytes: PackedByteArray=catalog.get_resource(query.name,int(query.type))
				check(catalog.failure.is_empty() and digest(bytes)==str(query.sha256),"Native priority and original bytes: "+str(query.name))
				var fork=catalog.fork()
				check(digest(fork.get_resource(query.name,int(query.type)))==str(query.sha256),"Worker fork retains local selection")
		for texture in variant.textures:
			var selected: Dictionary=catalog.raster_location(texture.name)
			check(not selected.is_empty() and int(selected.type)==int(texture.type),"Native format/storage class selection: "+str(texture.name))
			if not selected.is_empty(): check(digest(catalog.get_resource(texture.name,int(selected.type)))==str(texture.sha256),"Native selected texture bytes: "+str(texture.name))
		var names: Array=catalog.resource_names(2017); names.sort()
		check(names==variant.names2017,"Native resource inventory matches installed/Workshop/override oracle")
		var worker:=Assets.new(); root.add_child(worker); worker.configure(catalog)
		var delivered: Dictionary={}; worker.completed.connect(func(id: int,result: Dictionary):delivered[id]=result)
		var request:=worker.request("globaltable",2017,"2da") if catalog.has_resource("globaltable",2017) else -1
		deadline=Time.get_ticks_msec()+5000
		while request>=0 and not delivered.has(request) and Time.get_ticks_msec()<deadline: await process_frame
		if request>=0: check(delivered.has(request) and str(delivered[request].get("error","unfinished")).is_empty() and delivered[request].value.orderedRows.size()==1,"Native worker decodes selected global Workshop table")
		worker.close(); worker.queue_free(); metrics.append(prepared.stats); loader.close(); loader.queue_free()
	var parser:=Vdf.new(); var value:=parser.parse('"AppWorkshop" { // comment\n "WorkshopItemsInstalled" { "1" { "label" "brace } and \\\"quote\\\"" } } }')
	check(parser.failure.is_empty() and Vdf.section(value,"WorkshopItemsInstalled")[0][0].key=="1","Steam parser handles comments and quoted braces/escapes")
	check(parser.parse('"a" { "b" "c"').is_empty() and not parser.failure.is_empty(),"Truncated Steam section is rejected")
	var workshop:=Workshop.new()
	check(workshop.scan(str(fixture.variants[0].sources.modsDirectory),["../bad"]).is_empty() and not workshop.failure.is_empty(),"Workshop selection IDs cannot become paths")
	var selected: Dictionary=Loader.prepare(fixture.variants[0].sources)
	if str(selected.error).is_empty():
		var path:=str(fixture.deletePath); var owner:=str(fixture.root).replace("\\","/").trim_suffix("/")
		check(path.replace("\\","/").begins_with(owner+"/"),"Deletion test stays inside authored private fixture")
		if path.replace("\\","/").begins_with(owner+"/"):
			var original:=FileAccess.get_file_as_bytes(path); DirAccess.remove_absolute(path)
			var missing: PackedByteArray=selected.catalog.get_resource("empty",4)
			check(missing.is_empty() and not selected.catalog.failure.is_empty(),"Selected loose read failure never falls through to a different KEY resource")
			var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(original); file.close()
	await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"metrics":metrics,"network_connections":0,"native_only":true,"scope":fixture.scope}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
