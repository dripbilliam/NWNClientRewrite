extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const Connection=preload("res://systems/native_data/connection_dialog_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var models: Dictionary={}
var hashes: Dictionary={}
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func collect(node: Dictionary,catalog) -> void:
	var name:=str(node.get("Obj_ResRef","")).to_lower()
	if not name.is_empty() and not models.has(name):
		var raw: PackedByteArray=catalog.get_resource(name,2002); var parser:=Actor.new(); models[name]=parser.parse(raw); hashes[name]=Cache.digest(raw)
		if not parser.failure.is_empty(): failures.append(name+": "+parser.failure)
	for child in node.get("Obj_ChildList",[]): collect(child,catalog)
func find(node: Dictionary,tag: String) -> Dictionary:
	if str(node.get("Obj_Tag","")).to_lower()==tag: return node
	for child in node.get("Obj_ChildList",[]):
		var result:=find(child,tag)
		if not result.is_empty(): return result
	return {}
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var layouts: Dictionary={}; var summary: Dictionary={}
	if not catalog.mount_install(install): failures.append(catalog.failure)
	for name in ["serverlist_panel","serverlist_page1","serverlist_page3","serverlist_page4","serverlist_filt"]:
		var raw: PackedByteArray=catalog.get_resource(name,2047); var parser:=Gff.new(); var doc:=parser.parse(raw,"GUI "); hashes[name]=Cache.digest(raw)
		if not parser.failure.is_empty(): failures.append(name+": "+parser.failure); continue
		layouts[name]=doc.root; collect(doc.root,catalog)
	for name in layouts:
		var source: Dictionary=layouts[name]; var main:=Geometry.model(models[str(source.Obj_ResRef).to_lower()]); var entries: Dictionary={}; var error:=Connection.flatten(source,models,Vector2.ZERO,entries)
		if not error.is_empty(): failures.append(name+": "+error); continue
		var controls: Dictionary={}
		for tag in entries:
			var entry: Dictionary=entries[tag]; var child:=find(source,tag)
			controls[tag]={"rect":entry.rect,"offset":entry.get("offset"),"hooks":entry.get("model",{}).get("hooks",{}),"caption":entry.caption,"type":child.get("Obj_Type"),"fields":child.keys()}
		summary[name]={"root_position":[source.get("Obj_X"),source.get("Obj_Y")],"main":main.bounds,"hooks":main.hooks,"controls":controls}
	var table_bytes: PackedByteArray=catalog.get_resource("gamespyrooms",2017); var table=preload("res://systems/native_data/two_da.gd").new(); var game_types: Dictionary=table.parse(preload("res://systems/native_data/binary_data.gd").new(table_bytes).text(0,table_bytes.size()))
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":layouts.size(),"failures":failures,"layouts":summary,"resourceSha256":hashes,"gameTypes":game_types,"gameTypesError":table.failure,"publicConnections":0,"scope":"Read-only original GUI/model geometry and attachment evidence; no visual or functional acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
