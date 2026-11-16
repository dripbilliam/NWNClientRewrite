extends RefCounted
# Turn admitted server resources into the descriptor consumed by SessionCatalog.
# The order and priorities follow the former native-session-host sourceDescriptor.

static func build(resolution: Dictionary,install: String,profile: String,cache: String,native_directory: String,helper: String,mods_directory: String="",disabled_mods: Array=[])->Dictionary:
	if not bool(resolution.get("ready",false)) or not install.is_absolute_path() or not profile.is_absolute_path() or not cache.is_absolute_path() or not helper.is_absolute_path():return {"error":"Server resources are not admitted for catalog mounting"}
	var manifests: Array=[]
	var seen_hashes: Dictionary={}
	for row in resolution.get("catalogs",[]):
		var hash:=str(row.get("hash",""))
		if hash.length()!=40 or not hash.is_valid_hex_number():return {"error":"Invalid admitted NWSync manifest identity"}
		if seen_hashes.has(hash):continue
		seen_hashes[hash]=true
		manifests.append({"hash":hash,"cacheDirectory":cache,"nativeDirectory":native_directory,"helper":helper})
	var archives: Array=[]
	var seen_paths: Dictionary={}
	var groups: Dictionary={}
	var named: Array=resolution.get("named",[])
	var custom_tlk: Variant=null
	for index in range(named.size()-1,-1,-1):
		var row: Dictionary=named[index]
		var kind:=str(row.get("kind",""))
		if kind=="tlk":
			custom_tlk={"name":str(row.get("name","")),"path":str(row.get("path","")) if row.get("source")=="file" else null}
			continue
		if kind not in ["nwm","hak"]:continue
		if row.get("source")=="nwsync":continue
		var path:=str(row.get("path",""))
		if row.get("source")!="file" or not path.is_absolute_path():return {"error":"Admitted server archive has no file-backed path"}
		var identity:=path.simplify_path().to_lower()
		if seen_paths.has(identity):continue
		seen_paths[identity]=true
		var base:=23000000 if kind=="nwm" else 31000000 if path.get_base_dir().to_lower()==profile.path_join("hak").to_lower() else 30000000
		var order:=int(groups.get(base,0));groups[base]=order+1
		archives.append({"path":path.simplify_path(),"priority":base+order})
	return {"install":install,"archives":archives,"nwsync":manifests,"customTlk":custom_tlk,"profileDirectory":profile,"modsDirectory":mods_directory,"disabledMods":disabled_mods.duplicate(true)}
