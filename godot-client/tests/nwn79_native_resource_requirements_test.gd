extends SceneTree
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Admission=preload("res://systems/native_data/native_resource_admission.gd")
func _initialize()->void:
	var path:=ProjectSettings.globalize_path("res://.cache/nwn79/arelith-resource-record.bin")
	var record:=FileAccess.get_file_as_bytes(path)
	if record.is_empty():fail("captured public resource record unavailable");return
	var result: Dictionary=Requirements.decode_record(record)
	if result.has("error"):fail(str(result.error));return
	var ad: Variant=result.get("advertisement")
	if not ad is Dictionary or ad.get("hash",null)==null or str(ad.hash).length()!=40 or not str(ad.url).begins_with("http") or not result.get("haks") is Array:fail("resource fields");return
	print("NWN79 resource hash=",ad.hash," repository=",ad.url," additional=",ad.manifests.size()," haks=",result.haks.size()," custom_tlk=",not str(result.customTlk).is_empty())
	var documents:=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var cache:=documents.path_join("Neverwinter Nights.0/replacement-client/server-content")
	var store:=Store.new()
	var native:=documents.path_join("Neverwinter Nights.0/nwsync")
	var helper:=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
	if not store.configure(cache,native,helper):fail("NWSync cache configuration");return
	var manifest: Dictionary=store.manifest(str(ad.hash))
	if manifest.has("error"):fail("NWSync manifest: "+str(manifest.error));return
	if not manifest.has("entries") or manifest.entries.size()<1:fail("NWSync manifest is empty");return
	var tlk_key:=str(result.customTlk).to_lower()+":2018"
	print("NWN79 cached manifest entries=",manifest.entries.size()," custom_tlk=",result.customTlk," in_manifest=",manifest.entries.has(tlk_key))
	var resolved: Dictionary=Admission.resolve_cached(result,store,0,[documents.path_join("Neverwinter Nights.0")])
	if resolved.has("error"):fail("resource admission: "+str(resolved.error));return
	if not resolved.has("ready"):fail("resource admission returned no result");return
	print("NWN79 cached resource admission ready=",resolved.ready," missing_named=",resolved.missing.size()," missing_blobs=",resolved.missing_blob_count)
	if not resolved.ready:fail("required Arelith content is unavailable");return
	store.close()
	print("NWN79 Godot server resource requirements PASS")
	quit(0)
func fail(stage: String)->void:
	printerr("NWN79 Godot server resource requirements failed: "+stage)
	quit(1)
