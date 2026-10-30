extends SceneTree
# Read-only installed GUI metadata inventory. No game connection, rendering,
# action execution or original artwork/text payload export.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var failures: Array=[]
func visit(node: Dictionary,location: String,controls: Array,depth: int) -> void:
	if depth>64 or controls.size()>10000: failures.append("GUI tree exceeds metadata inventory bounds: "+location); return
	var fields: Array=node.keys(); fields.sort(); var caption: Dictionary=node.get("Obj_Caption",{}); var metadata: Dictionary={}
	for key in caption:
		if caption[key] is int or caption[key] is float or caption[key] is bool or str(key)=="AurString_Font": metadata[key]=caption[key]
	var geometry: Dictionary={}
	for key in ["Obj_X","Obj_Y","Obj_Z","Obj_Label_X","Obj_Label_Y","Obj_Label_Width","Obj_Label_Height","Obj_Locked","SliderLength"]:
		if node.has(key): geometry[key]=node[key]
	controls.append({"path":location,"tag":str(node.get("Obj_Tag","")),"type":int(node.get("Obj_Type",-1)),"model":str(node.get("Obj_ResRef","")),"caption":metadata,"geometry":geometry,"fields":fields})
	var children: Array=node.get("Obj_ChildList",[])
	for index in children.size(): visit(children[index],location+"/"+str(index),controls,depth+1)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var resources: Array=[]; var types: Dictionary={}; var fonts: Dictionary={}; var models: Dictionary={}; var controls_count:=0
	if not catalog.mount_install(install): failures.append(catalog.failure)
	var names: Array=catalog.resource_names(2047); names.sort()
	for name in names:
		var raw: PackedByteArray=catalog.get_resource(name,2047); var parser:=Gff.new(); var gui:=parser.parse(raw,"GUI ")
		if not parser.failure.is_empty(): failures.append(str(name)+": "+parser.failure); continue
		var controls: Array=[]; visit(gui.root,"root",controls,0); controls_count+=controls.size()
		for control in controls:
			var type:=str(control.type); types[type]=int(types.get(type,0))+1
			var font:=str(control.caption.get("AurString_Font","")); var model:=str(control.model)
			if not font.is_empty(): fonts[font]=int(fonts.get(font,0))+1
			if not model.is_empty(): models[model]=int(models.get(model,0))+1
		resources.append({"name":name,"sha256":Cache.digest(raw),"bytes":raw.size(),"controls":controls})
	var result:={"success":failures.is_empty() and resources.size()==names.size() and not names.is_empty(),"checks":resources.size(),"failures":failures,"resourceCount":names.size(),"controlCount":controls_count,"types":types,"fonts":fonts,"models":models,"resources":resources,"toolSha256":FileAccess.get_sha256(ProjectSettings.globalize_path("res://tools/inspect_native_ui_resources.gd")),"publicConnections":0,"scope":"Complete GUI2047 resource metadata inventory for this installed catalog only. Not a complete runtime UI/action inventory; programmatic/internal controls, callbacks, contexts, server overrides/NUI and original-client behavior require separate audit. No original pixels or resolved TLK text exported."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); print("NATIVE_UI_RESOURCES ",resources.size()," / ",controls_count," controls"); quit(0 if result.success else 1)
