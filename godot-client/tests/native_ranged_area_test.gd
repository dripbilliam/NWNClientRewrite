extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Model=preload("res://systems/native_data/binary_model.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Parts=preload("res://systems/native_data/model_random_part.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const Effects=preload("res://systems/native_render/effect_world.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report) or not FileAccess.file_exists(args.oracle): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original binary models mount read-only")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); var skins:=0
	for source in oracle.models:
		var bytes: PackedByteArray=catalog.get_resource(source.name,2002); var h:=HashingContext.new(); h.start(HashingContext.HASH_SHA256); h.update(bytes)
		check(h.finish().hex_encode()==source.sha256,"Installed original bytes identity "+str(source.name))
		var parser:=Model.new(); var model:=parser.parse(bytes); check(parser.failure.is_empty() and model.get("nodes",[]).size()==source.nodes.size(),"Original binary area physical hierarchy parses "+str(source.name))
		for i in model.get("nodes",[]).size():
			var part: Dictionary=model.nodes[i]; var expected: Dictionary=source.nodes[i]
			check(part.name==expected.name and (part.mesh.get("native_area")==null if expected.area==null else M.f(part.mesh.native_area)==M.f(expected.area)),"Exact original stored mesh area "+str(source.name)+"/"+str(i))
			if part.features.has("skin"): skins+=1; check(part.mesh.has("native_area") and (int(part.flags)&0x21)==0x21,"Skinned part retains the original mesh-area field")
	check(skins>0,"Actual original skin models participate in area metadata checks")
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); var result: Dictionary={}; service.completed.connect(func(_id,data):result.merge(data)); service.request("plc_a08",2002,"static-model")
	var deadline:=Time.get_ticks_msec()+15000
	while result.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(str(result.get("error","unfinished")).is_empty(),"Original chest prepares through actual native model worker")
	var pool:=Pool.new(); pool.picking=false
	if result.has("value"):
		var template:=Template.new(); check(template.build(result,pool),"Original chest publishes native physical template")
		var instance=template.create(); root.add_child(instance); var graph: Dictionary=instance.impact_model(); var selected: Variant=Parts.choose(graph,func():return 1)
		check(not graph.has("error") and float(graph.partArea)>0 and selected!=null and instance.physical_part(str(selected))!=null,"Weighted original chest Part resolves to an actual private native physical anchor")
		instance.scale=Vector3(3,4,5); var retained: float=graph.partArea; Parts.choose(graph,func():return 9999)
		check(graph.partArea==retained,"Renderer scale cannot change stored impact weights")
		instance.retire(); await process_frame; template=null
	service.close(); service.free(); pool.clear(); var effects:=Effects.new(); effects.free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"skins":skins,"scope":"Exact stored areas on installed original binary chest/skin data and native worker/PackedScene physical-part resolution; no art copied and no live attack outcome synthesized"},"\t")); file.close()
	print("NATIVE_RANGED_AREA ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
