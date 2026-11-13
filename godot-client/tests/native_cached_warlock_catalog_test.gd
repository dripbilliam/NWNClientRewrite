extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","fixture","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture).path_join("fixture.json")))
	check(fixture.success and fixture.captureGaps.is_empty() and fixture.originalDatabaseMetadataUnchanged,"Exact captured manifest closure has no declared missing bytes or database changes")
	var base:=Catalog.new();var active:=Catalog.new()
	var mounted:bool=base.mount_install(args.install) and active.mount_install(args.install)
	if fixture.has("privateNwsyncCatalog"):mounted=mounted and active.mount_nwsync(str(fixture.manifest),str(args.fixture).path_join("nwsync"),"","",100000001)
	else:mounted=mounted and active.mount_directory(str(args.fixture).path_join("resources"),100000001)
	check(mounted,"Original fallback and exact captured full-namespace active bytes mount separately")
	var tables:Dictionary={};var observations:Array=[]
	for resource in fixture.resources:
		var bytes:PackedByteArray=active.get_resource(str(resource.name),int(resource.type));var expected:String=str(args.fixture).path_join(str(resource.file))
		check(active.failure.is_empty() and FileAccess.get_sha256(expected)==str(resource.sha256) and preload("res://systems/native_data/prepared_cache.gd").digest(bytes)==str(resource.sha256),"Native catalog resolves exact cached bytes: "+str(resource.name))
		if int(resource.type)==2017:
			var parser:=Parser.new();var table:Dictionary=parser.parse(Binary.new(bytes).text(0,bytes.size()));check(parser.failure.is_empty(),"Actual native parser accepts captured table: "+str(resource.name));tables[str(resource.name)]=table
	for fallback in fixture.baseFallbacks:
		var name:String=str(fallback.name);var exists:bool=base.has_resource(name,int(fallback.type));var row:Dictionary={"name":name,"type":fallback.type,"installedPresent":exists,"knownAbsent":not exists,"reason":"Not declared by selected manifest; checked actual original installed catalog."}
		if exists:
			var bytes:PackedByteArray=base.get_resource(name,int(fallback.type));row.sha256=preload("res://systems/native_data/prepared_cache.gd").digest(bytes)
			var parser:=Parser.new();var table:Dictionary=parser.parse(Binary.new(bytes).text(0,bytes.size()));check(base.failure.is_empty() and parser.failure.is_empty(),"Native original fallback bytes parse: "+name);tables[name]=table;row.rows=table.get("orderedRows",[]).size()
		observations.append(row)
	var matches:Array=[]
	for id in tables.get("classes",{}).get("orderedRows",[]).size():
		if str(tables.classes.orderedRows[id].get("Label","")).to_lower()=="warlock":matches.append(id)
	check(matches==[92],"Fixture physical pin is92, while production lookup remains active Label based")
	var warlock:Dictionary=tables.classes.orderedRows[92];var required:Array=["feat","skills","ruleset","spells","racialtypes","classes","packages","masterfeats"]
	for field in ["PreReqTable","SkillsTable","FeatsTable","BonusFeatsTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable"]:
		var name:String=str(warlock.get(field,"")).to_lower()
		if name not in ["","****"]:required.append(name)
	for name in required:check(tables.has(name) and not tables[name].is_empty(),"Actual Warlock required table has cached or verified installed ownership: "+str(name))
	var output:Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"manifest":fixture.manifest,"fallbacks":observations,"capturedResources":fixture.resources.size(),"knownInstalledAbsences":observations.filter(func(row):return row.knownAbsent),"scope":"Exact cached Arelith tables/custom TLK resolve through actual native active catalog, native2DA parser and original installed fallback. No rule overrides, Creator bypass, server, key or GPU.","gpu":false,"serverConnections":0}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
