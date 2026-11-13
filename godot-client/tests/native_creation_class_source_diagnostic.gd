extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Post=preload("res://systems/native_data/creation_post_feats.gd")
class SourceRules extends RefCounted:
	var draft: Dictionary={"classId":4}
	var tables: Dictionary={}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();var mounted:=catalog.mount_install(str(args.install));var bytes:=catalog.get_resource("classes",2017) if mounted else PackedByteArray();var parser:=Parser.new();var table: Dictionary=parser.parse(preload("res://systems/native_data/binary_data.gd").new(bytes).text(0,bytes.size()))
	var rules:=SourceRules.new();rules.tables={"classes":table};var cells: Dictionary={}
	for field in ["PickDomains","PickSchool","SpellbookRestricted","SkipSpellSelection","MinAssociateLevel","Arcane"]:cells[field]={"cell":Tables.cell(table,4,field),"integer":Tables.integer(table,4,field)}
	var source:=Post.creation_source(rules);var result:=Post.new().advance(source,0x800e)
	var value: Dictionary={"success":mounted and catalog.failure.is_empty() and parser.failure.is_empty(),"checks":1,"classId":4,"label":table.get("orderedRows",[])[4].get("Label") if table.get("orderedRows",[]).size()>4 else null,"columns":table.get("columns",[]),"defaultValue":table.get("defaultValue"),"physicalRows":table.get("orderedRows",[]).size(),"cells":cells,"source":source,"continuation":result,"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes),"scope":"Original installed base-key classes.2da only. Not the 91-layer live Prelude catalog with Workshop/user precedence.","error":catalog.failure+parser.failure}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(value,"\t"));file.close();quit(0 if value.success else 1)
