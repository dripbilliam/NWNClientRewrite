extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.trim_prefix("--install=")
	var catalog:=Catalog.new()
	if install.is_empty() or not catalog.mount_install(install): quit(2); return
	var names: Dictionary={}; var rows: Dictionary={}
	for table_name in ["spells","classes","actions","feat","skills"]:
		var table:=Table.new().parse(catalog.get_resource(table_name,2017).get_string_from_ascii())
		var found:=0
		for row in table.get("orderedRows",[]):
			var name:=""
			for key in row:
				if str(key).to_lower() in ["icon","iconresref"]: name=str(row[key]); break
			if name in ["","****"]: continue
			names[name.to_lower()]=true; found+=1
		rows[table_name]={"rows":table.get("orderedRows",[]).size(),"withIcon":found}
	var available:=0
	for name in names:
		if not catalog.raster_location(str(name)).is_empty(): available+=1
	print(JSON.stringify({"rows":rows,"unique":names.size(),"available":available,"missing":names.size()-available}))
	quit()
