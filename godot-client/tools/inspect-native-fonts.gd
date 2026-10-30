extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new()
	if not catalog.mount_install(install): quit(3); return
	var rows: Dictionary={}
	for name in ["fnt_galahad14","fnt_galahad18","fnt_galahad20","fnt_floaty_smal","fnt_default","fnt_maintext"]:
		rows[name]={}
		for type in [3,2005,2022,2074]:
			if not catalog.has_resource(name,type): continue
			var bytes: PackedByteArray=catalog.get_resource(name,type)
			rows[name][str(type)]={"sha256":Cache.digest(bytes),"bytes":bytes.size(),"head":bytes.slice(0,32).hex_encode()}
			if type==2022: rows[name][str(type)].text=bytes.get_string_from_ascii()
	var methods: Array=[]
	for method in ClassDB.class_get_method_list("FontFile"):
		var key:=str(method.name)
		if key.begins_with("set_") and ("glyph" in key or "texture" in key or "ascent" in key or "descent" in key or "scale" in key or "fixed" in key) or key in ["get_glyph_index","has_char"]: methods.append(method)
	var constants: Dictionary={}
	for class_name_ in ["FontFile","TextServer"]:
		constants[class_name_]={}
		for key in ClassDB.class_get_integer_constant_list(class_name_):
			if "FIXED" in str(key): constants[class_name_][key]=ClassDB.class_get_integer_constant(class_name_,key)
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":true,"resources":rows,"font_api":methods,"constants":constants},"\t")); file.close(); quit()
