extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Postprocess=preload("res://systems/native_render/native_postprocess.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var output:="";var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.substr(9)
	var catalog:=Catalog.new();var mounted:=catalog.mount_install(install);var rows: Array=[];var keys: Array=[];var success:=mounted
	for name in ["data/nwn_base.key","data/nwn_retail.key","lang/en/data/nwn_base_loc.key"]:
		var file:=install.path_join(name)
		if FileAccess.file_exists(file):keys.append({"file":file,"sha256":FileAccess.get_sha256(file)})
	if mounted:
		for name in Postprocess.SHADERS:
			var found: Dictionary=catalog.location(name,2069);var bytes: PackedByteArray=catalog.get_resource(name,2069);var error:=catalog.failure
			var row:={"name":name,"type":2069,"bytes":bytes.size(),"sha256":Cache.digest(bytes),"expected_sha256":Postprocess.SHADERS[name],"error":error}
			row.matches=not bytes.is_empty() and row.sha256==row.expected_sha256 and error.is_empty();success=success and row.matches
			if not found.is_empty():
				row.selection={"kind":found.layer.kind,"priority":found.layer.priority,"serial":found.layer.serial,"binding_identity":found.layer.binding_identity,"entry":found.entry.duplicate(true)}
				if found.layer.kind=="key":
					var file: String=found.layer.root.path_join(found.entry.bif);var handle:=FileAccess.open(file,FileAccess.READ)
					row.archive={"file":file,"bytes":handle.get_length(),"modified":FileAccess.get_modified_time(file),"selected_entry":catalog.bif_store.entries[file].entries[int(found.entry.slot)]};handle.close()
			rows.append(row)
	var result:={"success":success,"mount_failure":catalog.failure if not mounted else "","installed_root":install,"native_catalog_script_sha256":FileAccess.get_sha256("res://systems/native_data/resource_catalog.gd"),"profile_script_sha256":FileAccess.get_sha256("res://systems/native_render/native_postprocess.gd"),"key_sources":keys,"resources":rows,"raw_asset_exports":0,"source_writes":0,"scope":"Read-only actual native ResourceCatalog mount_install KEY priority/selection and original BIF payload SHA comparison against exact accepted enhanced shader profile. Provenance/pins only; no derived fixture sealed or game assets exported; no FPS timing."}
	if not output.is_empty():
		var report:=FileAccess.open(output,FileAccess.WRITE);report.store_string(JSON.stringify(result,"  "));report.close()
	print(JSON.stringify(result));quit(0 if success else 1)
