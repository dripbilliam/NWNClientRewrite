extends SceneTree
const Names=preload("res://systems/native_data/creation_character_names.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Letters=preload("res://systems/native_data/letter_table.gd")
const Generator=preload("res://systems/native_data/name_generation.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func _initialize()->void:run.call_deferred()
func table(a:String,b:String,count:int=301)->Dictionary:
	var rows:Array=[];var cells:Array=[]
	for at in count:rows.append({"NameGenTableA":a,"NameGenTableB":b});cells.append([a,b])
	return {"columns":["NameGenTableA","NameGenTableB"],"orderedRows":rows,"orderedCells":cells,"defaultValue":""}
func rng(seed:int)->Callable:
	var state:Dictionary={"seed":seed}
	return func()->int:state.seed=(int(state.seed)*214013+2531011)&0xffffffff;return (int(state.seed)>>16)&32767
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-character-name-routing-original-v1.json"))
	check(oracle.success and oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Name routing oracle is the pinned unchanged original")
	var comparisons:=0;var cached_skips:=0
	for row in oracle.rows:
		var value:Dictionary=row.input
		if value.cached and int(value.cacheRace)==int(value.race) and int(value.cacheType)==int(value.kind):
			check(row.calls==[["generate"]],"Original retained name table skips resolution only on the exact race/kind key");cached_skips+=1;continue
		var result:=Names.route({"status":"ready","value":table(str(value.a),str(value.b))} if value.tableLoaded else {"status":"native-load-failed"},int(value.race),int(value.kind),int(value.sample))
		var loads:Array=row.calls.filter(func(call):return call[0]=="load")
		check(result.ready and result.resource==(str(loads[0][1]).left(16).to_lower() if not loads.is_empty() else null),"Original complete name-route case "+str(comparisons));comparisons+=1
		check(bool(result.choiceRequired)==(not row.calls.filter(func(call):return call[0]=="rand").is_empty()),"Original route consumes table-choice RNG at exactly the source boundary")
	check(not Names.route({},0,0).ready,"Uncaptured racialtypes bytes are unavailable rather than a known native load failure")
	check(not Names.route({"status":"ready","value":{}},0,0).ready,"A malformed decoded table is not confused with known native load failure")
	check(not Names.route({"status":"ready","value":table("human","elf")},6,0).ready,"Two active names require a known table-choice sample")
	var single:=Names.plan({"status":"ready","value":table("","human")},6,1)
	check(single.ready and single.resources==["humanf","humanl"] and not single.rows[0].choiceRequired,"B-only routes become A without consuming a choice draw; source gender==1 selects female")
	var missing:=Names.plan({"status":"ready","value":table("****","****")},6,2)
	check(missing.ready and missing.resources==["humanm","humanl"],"Literal missing markers clear native strings before fallback; non1gender uses male")
	check(not Names.plan({"status":"ready","value":table("","")},300,0).ready,"Unsupported race with no active table cannot invent a Human name")
	var defaults:=table("","");defaults.defaultValue="CustomDefault"
	check(Names.route({"status":"ready","value":defaults},400,0,1).resource=="customdefaultm","Invalid physical row uses native table default output despite false string-getter result")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed catalog mounts privately for actual original letter bytes")
	var plan:=Names.plan({"status":"ready","value":table("human","elf")},6,0);var loaded:Dictionary={}
	for resource in plan.resources:
		var bytes:PackedByteArray=catalog.get_resource(resource,2036);var decoded:=Letters.decode(bytes)
		check(decoded.ready and Letters.valid(decoded),"Actual installed original LTR decodes: "+resource)
		loaded[resource]=decoded
	var pair:=Names.generate_pair(plan,loaded,[],rng(1));check(pair.ready and not str(pair.firstName).is_empty() and not str(pair.lastName).is_empty(),"Prepared actual installed letter tables generate both native names")
	var reference_rng:=rng(1);var first_resource:String=plan.rows[0].even if reference_rng.call()%2==0 else plan.rows[0].odd
	var first:=Generator.new().generate(loaded[first_resource],reference_rng,[])
	var last_resource:String=plan.rows[1].even if reference_rng.call()%2==0 else plan.rows[1].odd
	var last:=Generator.new().generate(loaded[last_resource],reference_rng,[])
	check(pair.ready and pair.firstName==first.name and pair.lastName==last.name and pair.resources==[first_resource,last_resource] and pair.draws==first.draws+last.draws+2,"First probability generation precedes the independent last-name table choice on one captured RNG stream")
	var filtered:=Names.generate_pair(plan,loaded,[str(pair.firstName).to_lower()],rng(1));check(filtered.ready and filtered.firstName.nocasecmp_to(pair.firstName)!=0,"Current native NameFilter applies to the generated pair without invented replacement names")
	check(not Names.generate_pair(plan,loaded,[],rng(1),1).ready,"Name generation has an explicit finite shared draw budget")
	check(not Names.generate_pair(plan,{},[],rng(1)).ready,"Unprepared active letter resources are unavailable")
	check(not Names.generate_pair(plan,loaded,null,rng(1)).ready,"Unknown NameFilter status is unavailable rather than silently unfiltered")
	var later:=Names.plan({"status":"ready","value":table("dwarf","")},6,0)
	check(later.resources==["dwarfm","dwarfl"] and plan.resources.has("humanm"),"A replacement active table publication changes only the new detached resource plan")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalRoutes":comparisons,"originalCacheObservations":cached_skips,"gpu":false,"serverConnections":0,"scope":"Detached original name resource routing and installed-LTR pair generation. No async owner, creator draft, audio, BIC, UI or runtime integration."},"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
