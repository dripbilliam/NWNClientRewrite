extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Setup=preload("res://systems/native_data/session_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func write(path: String,bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func model(texture: String) -> PackedByteArray:
	return ("newmodel auth_mesh\nbeginmodelgeom auth_mesh\nnode trimesh root\nparent NULL\nbitmap "+texture+"\ndiffuse 0.2 0.4 0.6\nverts 3\n0 0 0\n1 0 0\n0 1 0\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom auth_mesh\n").to_utf8_buffer()
func prepare(catalog, names: Array) -> Dictionary:
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog)
	var delivered: Dictionary={}; var jobs: Dictionary={}
	assets.completed.connect(func(id,value):delivered[jobs[id]]=value)
	for name in names: jobs[assets.request(name,2002,"static-model")]=name
	var deadline:=Time.get_ticks_msec()+60000
	while delivered.size()<names.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(delivered.size()==names.size(),"Native model workers finish")
	assets.close(); assets.queue_free(); await process_frame
	return delivered
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-material-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	write(folder.path_join("missing.mdl"),model("absent_bitmap")); write(folder.path_join("broken.mdl"),model("broken_bitmap")); write(folder.path_join("palette.mdl"),model("only_palette"))
	write(folder.path_join("broken_bitmap.tga"),"invalid present raster".to_utf8_buffer()); write(folder.path_join("only_palette.plt"),"invalid unresolved palette".to_utf8_buffer())
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored live resources mount")
	check(catalog.recorded_texture_miss("absent_bitmap") and not catalog.recorded_texture_miss("broken_bitmap") and not catalog.recorded_texture_miss("only_palette"),"Absent bitmap distinguished from corrupt raster and unresolved PLT")
	var results: Dictionary=await prepare(catalog,["missing","broken","palette"])
	var missing: Dictionary=results.get("missing",{})
	check(str(missing.get("error","unfinished")).is_empty() and missing.get("missing_textures",[])==["absent_bitmap"],"Missing live bitmap retains model with explicit diagnostic")
	if missing.has("value"):
		var part: Dictionary=missing.value.nodes[0]; var pool:=Pool.new(); var material:=pool.material(part,missing.textures.absent_bitmap)
		check(part.mesh.vertices.size()==9 and part.mesh.indices.size()==3,"Original mesh remains intact")
		check(material!=null and material.albedo_texture==null and material.albedo_color.is_equal_approx(Color(0.2,0.4,0.6)),"Original material colors retained without a guessed bitmap")
	check(not str(results.get("broken",{}).get("error","")).is_empty(),"Present corrupt raster remains a diagnosed preparation failure")
	check(not str(results.get("palette",{}).get("error","")).is_empty(),"Unresolved PLT remains a diagnosed preparation failure")
	var capture_folder:=folder.path_join("capture"); var raw:=model("absent_bitmap"); var events:="Authored events".to_utf8_buffer()
	write(capture_folder.path_join("events.bin"),events); write(capture_folder.path_join("objects").path_join(Cache.digest(raw)),raw)
	write(capture_folder.path_join("manifest.json"),JSON.stringify({"version":1,"complete":true,"eventsSha256":Cache.digest(events),"contexts":{"context-1":{"resources":{"missing:2002":{"sha256":Cache.digest(raw),"bytes":raw.size()}},"textures":{}}}}).to_utf8_buffer())
	var capture:=Capture.new(); check(capture.mount(capture_folder,"context-1"),"Strict authored capture mounts")
	var captured: Dictionary=await prepare(capture,["missing"])
	check(str(captured.get("missing",{}).get("error",""))=="Original texture unavailable: absent_bitmap","Unrecorded capture gap remains explicit; live policy does not hide capture gaps")
	if args.has("install"):
		var setup:=Setup.new(); root.add_child(setup); var ready: Dictionary={}
		setup.completed.connect(func(_serial,value,error,stats):ready.merge({"catalog":value,"error":error,"stats":stats}))
		var sources:={"install":args.install,"modsDirectory":args.mods,"profileDirectory":args.profile,"nwsync":[{"hash":args.manifest,"nativeDirectory":str(args.profile).path_join("nwsync"),"cacheDirectory":str(args.profile).path_join("replacement-client/server-content"),"helper":ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")} ]}
		setup.start(sources); var deadline:=Time.get_ticks_msec()+60000
		while ready.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(not ready.is_empty() and str(ready.get("error","unfinished")).is_empty(),"Original install/Workshop/cached NWSync catalog mounts offline: "+str(ready.get("error","unfinished")))
		if ready.has("catalog") and str(ready.get("error","unfinished")).is_empty():
			var actual: Dictionary=await prepare(ready.catalog,["trm_udoor_10","dwc_gen_04"])
			for name in ["trm_udoor_10","dwc_gen_04"]:
				var value: Dictionary=actual.get(name,{}); var meshes: int=value.get("value",{}).get("nodes",[]).filter(func(part):return not part.mesh.is_empty()).size()
				check(str(value.get("error","unfinished")).is_empty() and meshes>0,"Previously fatal original model prepares: "+name)
				observations.append({"model":name,"error":value.get("error","unfinished"),"meshes":meshes,"missing_textures":value.get("missing_textures",[]),"sha256":value.get("sha256","")})
			for layer in ready.catalog.layers:
				if layer.kind=="nwsync": layer.store.close()
		setup.close(); setup.queue_free(); await process_frame
	write(args.report,JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"models":observations,"network_connections":0,"scope":"Missing live mesh bitmap handling, actual two previously fatal models from local install/Workshop/cache; no public connection or full-world acceptance"},"\t").to_utf8_buffer())
	print("NATIVE_MISSING_MATERIAL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
