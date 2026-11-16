extends SceneTree
const Repository=preload("res://systems/native_data/native_nwsync_repository.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")

func _initialize()->void:
	run.call_deferred()

func run()->void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var report_path:=str(args.get("report",""))
	if report_path.is_empty() or FileAccess.file_exists(report_path):quit(2);return
	var cache:=str(args.get("cache",""))
	var hash:=str(args.get("manifest",""))
	var resource:=str(args.get("resource",""))
	var repository:=Repository.new()
	root.add_child(repository)
	var store:=Store.new()
	var result: Dictionary={"format":"nwn79-nwsync-blob-repair-v1","success":false,"manifestHash":hash,"resourceHash":resource,"wasCorrupt":false,"blobRefetched":false,"error":""}
	if not store.configure(cache) or not repository.configure(str(args.get("url","")),cache):
		result.error="Invalid private NWSync repository or cache"
	else:
		var manifest: Dictionary=await repository.ensure_manifest(store,hash)
		if manifest.has("error"):
			result.error=str(manifest.error)
		else:
			var entry: Dictionary={}
			for row in manifest.entries.values():
				if str(row.hash)==resource:entry=row;break
			if entry.is_empty():
				result.error="Authored resource absent from manifest"
			else:
				result.wasCorrupt=store.resource(entry).has("error")
				if not result.wasCorrupt:
					result.error="Resource cache was not corrupt before repair"
				else:
					var repaired: Dictionary=await repository.ensure_blob(store,entry)
					if repaired.has("error"):
						result.error=str(repaired.error)
					else:
						var verified: Dictionary=store.resource(entry)
						result.blobRefetched=not verified.has("error") and Store.sha1(repaired.bytes)==resource
						result.success=result.blobRefetched
						if not result.success:result.error="Refetched authored resource failed cache verification"
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:
		printerr("NWN79 NWSync repair report is unwritable")
		quit(2);return
	file.store_string(JSON.stringify(result,"  ")+"\n")
	file.close()
	store.close()
	repository.close()
	print(JSON.stringify(result))
	quit(0 if result.success else 1)
