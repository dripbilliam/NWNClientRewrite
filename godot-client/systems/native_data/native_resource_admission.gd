extends RefCounted
# Server requirements must be present before character selection. This checks
# the same manifest/language and named-resource order as the native client.
const Extensions=preload("res://systems/native_data/resource_extensions.gd")
const Workshop=preload("res://systems/native_data/workshop_index.gd")
const Archive=preload("res://systems/native_data/archive_index.gd")

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

static func named_resource(kind: String,name: String,catalogs: Array[Dictionary],roots: Array[String],workshop_directories: Array[String]=[])->Dictionary:
	if name.is_empty() or name.length()>16 or name in [".",".."]:return {}
	for character in name:
		if character.unicode_at(0)<32 or character in ["/","\\",":"]:return {}
	var extension_type: int=int(Extensions.TYPES.get(kind,-1))
	var key:=name.to_lower()+":"+str(extension_type)
	var filename: String=name if name.to_lower().ends_with("."+kind) else name+"."+kind
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
		for directory in directories:
			var path:=root.path_join(directory).path_join(filename)
			if FileAccess.file_exists(path): return {"kind":kind,"name":name,"source":"file","path":path}
	for directory in workshop_directories:
		var path:=directory.path_join(filename)
		if FileAccess.file_exists(path): return {"kind":kind,"name":name,"source":"file","path":path}
	return {}

static func archive_tlk(name: String,selected: Array,store: RefCounted,roots: Array,workshop_haks: Array,workshop_overrides: Array)->Dictionary:
	var resref:=name.to_lower().trim_suffix(".tlk")
	if resref.is_empty() or resref.length()>16 or resref.contains("/") or resref.contains("\\") or resref.contains(":"):return {}
	var key:=resref+":2018"
	var archives: Array[Dictionary]=[]
	for row in selected:
		if str(row.get("kind",""))=="hak":archives.append(row)
	for row in selected:
		if str(row.get("kind",""))=="nwm":archives.append(row)
	for row in archives:
		var reader:=Archive.new();var index: Dictionary={}
		if row.get("source")=="file":
			index=reader.erf(str(row.get("path","")))
		elif row.get("source")=="nwsync":
			if not store.has_method("resource_borrowed"):return {"error":"Verified NWSync archive bytes are unavailable"}
			var source: Dictionary=store.resource_borrowed(row.get("entry",{}))
			if source.has("error"):return {"error":str(source.error),"repair":{"store":store,"entry":row.get("entry",{}).duplicate(true)}}
			index=reader.erf_bytes_index(source.bytes,str(row.get("entry",{}).get("hash","")))
		if not reader.failure.is_empty():return {"error":reader.failure}
		if index.get("entries",{}).has(key):return {"kind":"tlk","name":name,"source":"archive"}
	for directory in workshop_haks:
		var folder:=DirAccess.open(directory)
		if folder==null:return {"error":"Selected Workshop HAK directory is unreadable"}
		var files:=Array(folder.get_files());files.sort_custom(func(a,b):return str(a).nocasecmp_to(str(b))<0)
		for filename in files:
			if str(filename).get_extension().to_lower()!="hak" or folder.is_link(str(filename)):continue
			var reader:=Archive.new();var index: Dictionary=reader.erf(directory.path_join(str(filename)))
			if not reader.failure.is_empty():return {"error":reader.failure}
			if index.get("entries",{}).has(key):return {"kind":"tlk","name":name,"source":"archive"}
	var override_directories: Array[String]=[]
	if not roots.is_empty():override_directories.append(roots[0].path_join("override"))
	if roots.size()>1:override_directories.append_array([roots[1].path_join("ovr"),roots[1].path_join("override")])
	override_directories.append_array(workshop_overrides)
	for directory in override_directories:
		var path:=directory.path_join(resref+".tlk")
		if FileAccess.file_exists(path):return {"kind":"tlk","name":name,"source":"file","path":path}
	for root in roots:
		for suffix in ["data/nwn_base.key","data/nwn_retail.key","lang/en/data/nwn_base_loc.key"]:
			var path: String=str(root).path_join(suffix)
			if not FileAccess.file_exists(path):continue
			var reader:=Archive.new();var index: Dictionary=reader.key(path)
			if not reader.failure.is_empty():return {"error":reader.failure}
			if index.get("entries",{}).has(key):return {"kind":"tlk","name":name,"source":"archive"}
	return {}

static func resolve_cached(requirements: Dictionary,store: RefCounted,language: int,roots: Array[String]=[],mods_directory: String="",disabled_mods: Array=[])->Dictionary:
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
	var workshop:=Workshop.new()
	var workshop_roots: Array=workshop.scan(mods_directory,disabled_mods)
	if not workshop.failure.is_empty():return {"error":workshop.failure}
	var workshop_aliases: Dictionary={}
	for kind in ["nwm","hak","tlk","override"]:
		workshop_aliases[kind]=workshop.directories_for(workshop_roots,"modules" if kind=="nwm" else kind)
		if not workshop.failure.is_empty():return {"error":workshop.failure}
	var module_name:=str(requirements.get("nwmResourceName",""))
	if not module_name.is_empty():
		var module:=named_resource("nwm",module_name,catalogs,roots,workshop_aliases.nwm)
		if module.is_empty():missing.append({"kind":"nwm","name":module_name})
		else:named.append(module)
	for hak in requirements.get("haks",[]):
		var name:=str(hak)
		var found:=named_resource("hak",name,catalogs,roots,workshop_aliases.hak) if not name.is_empty() else {}
		if found.is_empty(): missing.append({"kind":"hak","name":name})
		else: named.append(found)
	var tlk_name:=str(requirements.get("customTlk",""))
	if not tlk_name.is_empty():
		var tlk:=named_resource("tlk",tlk_name,catalogs,[],[])
		if tlk.is_empty():tlk=archive_tlk(tlk_name,named,store,roots,workshop_aliases.hak,workshop_aliases["override"])
		if tlk.has("error"):return tlk
		if tlk.is_empty():tlk=named_resource("tlk",tlk_name,[],roots,workshop_aliases.tlk)
		if tlk.is_empty():missing.append({"kind":"tlk","name":tlk_name})
		else:named.append(tlk)
	return {"ready":missing.is_empty() and missing_blob_count==0,"catalogs":catalogs,"named":named,"missing":missing,"missing_blob_count":missing_blob_count,"missing_blob_samples":missing_blob_samples}
