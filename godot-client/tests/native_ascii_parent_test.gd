extends SceneTree
const Setup=preload("res://systems/native_data/session_catalog.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var checks:=0
var failures: Array=[]
var observed: Dictionary={}
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var parser:=Ascii.new()
	var authored:="newmodel auth\nbeginmodelgeom auth\nnode dummy RoOt\nparent NULL\nposition 2 3 4\nendnode\nnode dummy Child\nparent root\nposition 5 6 7\nendnode\nendmodelgeom auth\n"
	var parsed:=parser.parse(authored)
	check(parser.failure.is_empty() and parsed.nodes[1].parent==0 and parsed.nodes[0].name=="RoOt" and parsed.nodes[1].position==[5.0,6.0,7.0],"Mixed-case parent resolves without renaming or changing local transforms")
	check(parser.parse(authored.replace("parent root","parent absent")).is_empty() and parser.failure=="ASCII MDL parent missing","Genuinely missing parents remain errors")
	check(parser.parse(authored.replace("parent NULL","parent Child")).is_empty() and "cycle" in parser.failure,"Mixed-case cycle remains rejected")
	var ambiguous:=authored.replace("node dummy Child","node dummy ROOT\nparent NULL\nendnode\nnode dummy Child")
	check(parser.parse(ambiguous).is_empty() and "ambiguous" in parser.failure,"Conflicting case aliases are diagnosed rather than guessed")
	parsed=parser.parse(ambiguous.replace("parent root","parent RoOt"))
	check(parser.failure.is_empty() and parsed.nodes[2].parent==0,"Exact-case parent keeps its physical identity when another case variant exists")
	var repeated:=authored.replace("node dummy Child","node dummy RoOt\nparent NULL\nendnode\nnode dummy Child").replace("parent root","parent RoOt")
	parsed=parser.parse(repeated)
	check(parser.failure.is_empty() and parsed.nodes[2].parent==1,"Existing final exact-declaration behavior for duplicate names is preserved")
	var sources:={"install":args.install,"modsDirectory":args.mods,"profileDirectory":args.profile,"nwsync":[{"hash":args.manifest,"nativeDirectory":str(args.profile).path_join("nwsync"),"cacheDirectory":str(args.profile).path_join("replacement-client/server-content"),"helper":ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")} ]}
	var mounted:=Setup.prepare(sources); var catalog=mounted.catalog
	check(str(mounted.get("error","unfinished")).is_empty(),"Offline install/Workshop/NWSync catalog mounts: "+str(mounted.get("error","unfinished")))
	if str(mounted.get("error","unfinished")).is_empty():
		var raw: PackedByteArray=catalog.get_resource("ashto_041",2002); parser=Ascii.new(); var model:=parser.parse(raw.get_string_from_ascii())
		observed={"model":"ashto_041","bytes":raw.size(),"sha256":Cache.digest(raw),"error":parser.failure,"nodes":parser.source_nodes.size(),"missing_parents":[]}
		for part in parser.source_nodes:
			if str(part.parent_name).to_upper()=="NULL" or parser.by_name.has(part.parent_name): continue
			observed.missing_parents.append({"node":part.name,"parent":part.parent_name,"case_matches":parser.by_name.keys().filter(func(name):return str(name).nocasecmp_to(str(part.parent_name))==0)})
		print(JSON.stringify(observed))
		check(catalog.failure.is_empty() and not raw.is_empty(),"Exact original model bytes read offline")
		check(parser.failure.is_empty() and not model.is_empty(),"Previously fatal original hierarchy parses: "+parser.failure)
		if not model.is_empty():
			var root_index: int=model.nodes.find_custom(func(part):return part.name=="AShTo_041")
			check(root_index>=0 and model.nodes.filter(func(part):return part.name in ["Box013","imp_shield_1.009","imp_shield_2.009"]).all(func(part):return int(part.parent)==root_index),"All three original mixed-case edges attach to the existing physical root")
			var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var result: Dictionary={}
			assets.completed.connect(func(_id,value):result.merge(value)); assets.request("ashto_041",2002,"actor-model",{"relevant_tracks":true})
			var deadline:=Time.get_ticks_msec()+60000
			while result.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
			check(not result.is_empty() and str(result.get("error","unfinished")).is_empty(),"Full native actor-model preparation succeeds: "+str(result.get("error","unfinished")))
			observed.worker_error=result.get("error","unfinished"); observed.meshes=result.get("value",{}).get("nodes",[]).filter(func(part):return not part.mesh.is_empty()).size()
			assets.close(); assets.queue_free(); await process_frame
	for layer in catalog.layers:
		if layer.kind=="nwsync": layer.store.close()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original":observed,"network_connections":0,"scope":"Offline exact previously fatal original ASCII hierarchy and native worker preparation; no public connection or full affected-world acceptance"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
