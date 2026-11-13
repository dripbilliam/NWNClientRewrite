extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
func _initialize()->void: call_deferred("run")
func run()->void:
	var install:=""; var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		elif arg.begins_with("--report="): output=arg.substr(9)
	if install.is_empty() or output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new()
	if not catalog.mount_install(install): quit(3); return
	var names: Array=catalog.resource_names(2002); var candidates: Array=[]
	for name in names:
		var value:=str(name)
		if "cloak" in value or "_clo" in value or "clo_" in value or "cl01" in value or "cl03" in value: candidates.append(value)
	candidates.sort()
	var result:={"model_count":names.size(),"candidates":candidates,"probe":{}}
	result["texture_candidates"]={}
	for type in [3,6,2033,2059,2073]:
		var found: Array=[]
		for name in catalog.resource_names(type):
			if "cloak" in str(name): found.append(str(name))
		found.sort()
		result.texture_candidates[str(type)]=found
	for prefix in ["pme0","pme1","pmh0","pmh1","pfe0","pfh0"]:
		for suffix in ["_cloak001","_cloak003","_clo001","_clo003","_cl01","_cl03","_cloak1","_cloak3"]:
			var key: String=str(prefix)+str(suffix)
			if catalog.has_resource(key,2002): result.probe[key]=true
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	print(JSON.stringify({"models":names.size(),"cloak_name_candidates":candidates.size(),"probe_hits":result.probe.size(),"report":output}))
	quit(0)
