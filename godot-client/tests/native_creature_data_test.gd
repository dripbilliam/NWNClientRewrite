extends SceneTree
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Creature=preload("res://systems/native_data/creature_appearance.gd")
const Palette=preload("res://systems/native_data/palette_texture.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var differences: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func equal_values(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equal_values(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not equal_values(a[index],b[index]): return false
		return true
	if a is int or a is float: return (b is int or b is float) and a==b
	return typeof(a)==typeof(b) and a==b
func canonical(plan: Dictionary) -> Dictionary:
	var parts: Array=[]
	for part in plan.parts: parts.append({"model":part.model,"fallbackModel":part.get("fallbackModel"),"pltCandidates":part.get("pltCandidates",[]),"node":part.get("node"),"partIndex":part.get("partIndex"),"paletteColors":part.get("paletteColors",plan.paletteColors)})
	return {"model":plan.model,"fallbackModel":plan.get("fallbackModel"),"paletteColors":plan.paletteColors,"parts":parts,"attachments":plan.get("attachments",[])}
func compare_details(a: Variant,b: Variant,path: String) -> void:
	if equal_values(a,b) or differences.size()>=24: return
	if a is Dictionary and b is Dictionary:
		for key in a:
			if b.has(key): compare_details(a[key],b[key],path+"."+str(key))
			else: differences.append({"path":path+"."+str(key),"actual":a[key],"expected":"absent"})
	elif a is Array and b is Array and a.size()==b.size():
		for index in a.size(): compare_details(a[index],b[index],path+"["+str(index)+"]")
	else: differences.append({"path":path,"actual":a,"expected":b})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	check(FileAccess.get_sha256(fixture.input)==fixture.inputSha256,"Original raw protocol fixture checksum")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture.input)); var catalog:=Capture.new()
	check(catalog.mount(data.capture,data.context,data.supplements),"Original capture catalog opens: "+catalog.failure)
	var tables: Dictionary={}
	for name in fixture.tables:
		var bytes:=catalog.get_resource(name,2017); var parser:=Table.new()
		tables[name]=parser.parse(Binary.new(bytes).text(0,bytes.size()))
		check(catalog.failure.is_empty() and parser.failure.is_empty(),"Original creature table: "+name)
	var original_objects: Dictionary={}
	for object in data.objects: original_objects[int(object.id)]=object
	for item in fixture.cases:
		var parser:=Creature.new(); var plan:=parser.plan(original_objects[int(item.id)],tables)
		check(not plan.is_empty() and parser.failure.is_empty(),"Original native creature plan: "+str(item.id)+" "+parser.failure)
		if not plan.is_empty():
			check(equal_values(canonical(plan),item.expected),"Exact body parts/colors/robe/tail/wing rules: "+str(item.id))
			compare_details(canonical(plan),item.expected,str(item.id))
	var cache_path:=ProjectSettings.globalize_path("user://native-plt-test-"+str(OS.get_process_id()))
	var selected_bundle: Dictionary={}; var selected_case: Dictionary={}
	for item in fixture.plts:
		var parser:=Palette.new(); var result:=parser.prepare(catalog,item.name,item.rows,cache_path)
		check(str(result.get("error","")).is_empty(),"Original native palette decode: "+item.name+" "+str(result.get("error","")))
		if not result.has("value"): continue
		check(int(result.value.width)==int(item.width) and int(result.value.height)==int(item.height),"Original palette dimensions: "+item.name)
		check(Cache.digest(result.value.mips[0].data)==item.sha256,"Exact original PLT pixels/colors/row order: "+item.name)
		var warm:=parser.prepare(catalog,item.name,item.rows,cache_path)
		check(warm.get("cache_hit",false) and Cache.digest(warm.value.mips[0].data)==item.sha256,"Persistent native palette read-back: "+item.name)
		if selected_bundle.is_empty(): selected_bundle=result; selected_case=item
	if fixture.plts.size()>1:
		var parser:=Palette.new(); var second:=parser.prepare(catalog,fixture.plts[1].name,fixture.plts[1].rows,cache_path)
		check(selected_bundle.get("sha256")!=second.get("sha256"),"Different palette rows cannot alias pooled texture identities")
	var invalid:=Palette.new()
	check(invalid.decode(PackedByteArray(),{}).is_empty() and not invalid.failure.is_empty(),"Truncated PLT rejects")
	if not selected_case.is_empty():
		var bytes:=catalog.get_resource(selected_case.name,6)
		check(invalid.decode(bytes,{}).is_empty() and not invalid.failure.is_empty(),"Missing original palette rejects")
		var bad:=bytes.duplicate(); bad.encode_u32(16,0xffffffff)
		check(invalid.header(bad).is_empty(),"Unbounded PLT dimensions reject before allocation")
		bad=bytes.slice(0,bytes.size()-1); check(invalid.header(bad).is_empty(),"Truncated PLT pixel tail rejects")
	# Exercise the real background service with independent per-request colors.
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=cache_path
	var delivered: Dictionary={}
	service.completed.connect(func(id: int,result: Dictionary): delivered[id]=result)
	var eligible: Dictionary={}
	for item in fixture.plts:
		if not item.rows.is_empty() and catalog.has_resource(item.name,2002): eligible=item; break
	if not eligible.is_empty():
		var options:={"plt_candidates":[eligible.name],"palette_colors":eligible.rows.duplicate()}
		var first:=service.request(eligible.name,2002,"static-model",options)
		options.palette_colors.fill(0)
		var second:=service.request(eligible.name,2002,"static-model",options)
		var deadline:=Time.get_ticks_msec()+30000
		while delivered.size()<2 and Time.get_ticks_msec()<deadline: await process_frame
		check(delivered.has(first) and delivered.has(second),"Both native model/PLT worker jobs complete")
		for id in [first,second]:
			if not delivered.has(id): continue
			var result: Dictionary=delivered[id]
			check(str(result.error).is_empty(),"Original body model and palette prepared together: "+str(result.error))
			check(result.thread!=OS.get_main_thread_id(),"Model/palette preparation runs on native worker")
			for texture in result.get("textures",{}).values():
				if texture.is_empty(): continue
				check(texture.value.type==6,"Original per-part PLT replaces model bitmap")
				if id==first: check(Cache.digest(texture.value.mips[0].data)==eligible.sha256,"Queued worker owns a deep copy of palette options after caller mutation")
	else: check(false,"Original body model/PLT pair exists for worker coverage")
	service.close(); service.queue_free(); await process_frame
	var sources: Dictionary={}
	for name in ["systems/native_data/palette_texture.gd","systems/native_data/creature_appearance.gd","systems/native_data/asset_service.gd","systems/native_data/texture_data.gd","systems/native_data/capture_catalog.gd","tests/native_creature_data_test.gd"]: sources[name]=FileAccess.get_sha256("res://"+name)
	var report:={"passed":failures.is_empty(),"native_only":true,"scope":"Native original creature appearance, palette pixels/cache and worker preparation; scene/skinning/gameplay integration pending","checks":checks,"failures":failures,"differences":differences,"creatures":fixture.cases.size(),"originalPltVariants":fixture.plts.size(),"sourceSha256":sources}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
