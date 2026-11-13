extends SceneTree
const Extensions=preload("res://systems/native_data/resource_extensions.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Loose=preload("res://systems/native_data/loose_index.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not source is Dictionary or not source.has_all(["rows","lookups"]):quit(2);return
	for row in source.lookups:check(Extensions.from_extension(str(row.extension))==int(row.type),"Original exact extension lookup: "+str(row.extension))
	var folder:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(folder);var expected:=0
	for row in source.rows:
		if int(row.type)==65535:continue
		expected+=1
		var file:=FileAccess.open(folder.path_join("asset."+str(row.extension).to_upper()),FileAccess.WRITE);file.store_string("Original type "+str(int(row.type)));file.close()
	for extension in ["unknown_extension",""]:
		var file:=FileAccess.open(folder.path_join("ignored"+("."+extension if not extension.is_empty() else "")),FileAccess.WRITE);file.store_string("Unknown");file.close()
	var catalog:=Catalog.new();check(catalog.mount_directory(folder),"Actual loose catalog mounts without eagerly reading payloads")
	check(catalog.layers.size()==1 and catalog.layers[0].entries.size()==expected and expected==92,"Every native recognized extension is indexed, while unknown/no extension is ignored")
	for row in source.rows:
		if int(row.type)==65535:continue
		var type:=int(row.type);var key:="asset:"+str(type)
		check(catalog.has_resource("ASSET",type) and catalog.get_resource("asset",type).get_string_from_ascii()=="Original type "+str(type),"Actual native catalog indexes and reads exact bytes for type "+str(type))
		check(str(catalog.layers[0].entries[key].path).ends_with("."+str(row.extension).to_upper()),"Reads retain the inventoried filename instead of reconstructing a path: "+str(row.extension))
	var filtered:=Catalog.new();check(filtered.mount_directory(folder,1,[2036,2027]) and filtered.layers[0].entries.size()==2 and filtered.has_resource("asset",2036) and filtered.has_resource("asset",2027),"Explicit type filters still restrict loose indexing to requested resources")
	var unknown:=Loose.new().scan_names(folder,PackedStringArray(["file.unlisted","file"]),[]);check(unknown.entries.is_empty(),"Invalid native type65535 never becomes a resource entry")
	check(not Extensions.REVISION.is_empty(),"Loose-index cache identity includes the recovered map revision")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalRows":source.rows.size(),"originalLookups":source.lookups.size(),"scope":"Complete original extension-table/lookup execution comparisons and actual native loose-folder payload reads for all92 valid native types; unknown/case/exact-filename/type-filter behavior. No renderer/server/GPU/complete resource-loading parity acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
