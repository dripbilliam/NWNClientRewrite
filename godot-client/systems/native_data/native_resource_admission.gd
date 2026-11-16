extends RefCounted
# Server requirements must be present before character selection. This checks
# the same manifest/language and named-resource order as the native client.
const Extensions=preload("res://systems/native_data/resource_extensions.gd")

static func manifest_hashes(requirements: Dictionary,language: int)->Dictionary:
	var advertisement: Variant=requirements.get("advertisement")
	var hashes: Array[String]=[]
	var manifests: Array[Dictionary]=[]
	var missing: Array[Dictionary]=[]
	if advertisement is Dictionary:
		var primary: Variant=advertisement.get("hash")
		if primary is String and not primary.is_empty(): hashes.append(primary);manifests.append({"hash":primary,"required":true})
		else: missing.append({"kind":"nwsync","name":"primary manifest"})
		for entry in advertisement.get("manifests",[]):
			if not entry is Dictionary: continue
			if int(entry.get("language",-1))!=255 and int(entry.get("language",-1))!=language: continue
			var hash: Variant=entry.get("hash")
			if hash is String and not hash.is_empty(): hashes.append(hash);manifests.append({"hash":hash,"required":(int(entry.get("flags",0)) & 1)!=0})
			elif int(entry.get("flags",0)) & 1: missing.append({"kind":"nwsync","name":"required additional manifest"})
	return {"hashes":hashes,"manifests":manifests,"missing":missing}

static func named_resource(kind: String,name: String,catalogs: Array[Dictionary],roots: Array[String])->Dictionary:
	if name.is_empty() or name.length()>16 or name in [".",".."]:return {}
	for character in name:
		if character.unicode_at(0)<32 or character in ["/","\\",":"]:return {}
	var extension_type: int=int(Extensions.TYPES.get(kind,-1))
	var key:=name.to_lower()+":"+str(extension_type)
	for catalog in catalogs:
		var entries: Dictionary=catalog.get("entries",{})
		if entries.has(key): return {"kind":kind,"name":name,"source":"nwsync","entry":entries[key],"manifest":catalog.get("hash","")}
	for root in roots:
		if root.is_empty() or not root.is_absolute_path(): continue
		# The profile and installed game use different archive layouts. Match
		# the original installed-resource lookup instead of assuming kind(s)/.
		var directories: Array[String]=[kind,kind+"s"]
		match kind:
			"nwm":directories.append("data/nwm")
			"hak":directories.append_array(["data/hk","data/hak"])
			"tlk":directories.append_array(["lang/en/data/tlk","data/tlk"])
		var filename:=name if name.to_lower().ends_with("."+kind) else name+"."+kind
		for directory in directories:
			var path:=root.path_join(directory).path_join(filename)
			if FileAccess.file_exists(path): return {"kind":kind,"name":name,"source":"file","path":path}
	return {}

static func resolve_cached(requirements: Dictionary,store: RefCounted,language: int,roots: Array[String]=[])->Dictionary:
	var selected: Dictionary=manifest_hashes(requirements,language)
	var missing: Array[Dictionary]=selected.missing
	var catalogs: Array[Dictionary]=[]
	for selected_manifest in selected.manifests:
		var hash: String=selected_manifest.hash
		var manifest: Dictionary=store.manifest(hash)
		if manifest.has("error"):
			if selected_manifest.required:missing.append({"kind":"nwsync","name":hash,"reason":str(manifest.error)})
		else:
			catalogs.append({"hash":hash,"entries":manifest.entries})
	var missing_blob_count:=0
	var missing_blob_samples: Array[String]=[]
	if not catalogs.is_empty():
		var inventory: Dictionary=store.available_blob_hashes()
		if inventory.has("error"): return {"error":str(inventory.error)}
		var available: Dictionary=inventory.hashes
		var checked: Dictionary={}
		for catalog in catalogs:
			for entry in catalog.entries.values():
				var hash:=str(entry.get("hash",""))
				if checked.has(hash): continue
				checked[hash]=true
				if not available.has(hash):
					missing_blob_count+=1
					if missing_blob_samples.size()<16: missing_blob_samples.append(hash)
	var named: Array[Dictionary]=[]
	for item in [{"kind":"nwm","name":requirements.get("nwmResourceName","")},{"kind":"tlk","name":requirements.get("customTlk","")}]:
		var name:=str(item.name)
		if name.is_empty(): continue
		var found:=named_resource(str(item.kind),name,catalogs,roots)
		if found.is_empty(): missing.append({"kind":item.kind,"name":name})
		else: named.append(found)
	for hak in requirements.get("haks",[]):
		var name:=str(hak)
		var found:=named_resource("hak",name,catalogs,roots) if not name.is_empty() else {}
		if found.is_empty(): missing.append({"kind":"hak","name":name})
		else: named.append(found)
	return {"ready":missing.is_empty() and missing_blob_count==0,"catalogs":catalogs,"named":named,"missing":missing,"missing_blob_count":missing_blob_count,"missing_blob_samples":missing_blob_samples}
