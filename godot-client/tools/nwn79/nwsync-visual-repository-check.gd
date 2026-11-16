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
	var descriptor_path:=str(args.get("descriptor","")).replace("\\","/")
	var report_path:=str(args.get("report","")).replace("\\","/")
	var cache_path:=str(args.get("cache","")).replace("\\","/")
	var result: Dictionary={"format":"nwn79-nwsync-visual-repository-v1","success":false,"phase":str(args.get("phase","")),"entries":[],"manifestEntries":0,"iconPixel":false,"error":""}
	if descriptor_path.is_empty() or report_path.is_empty() or cache_path.is_empty() or not cache_path.is_absolute_path() or not FileAccess.file_exists(descriptor_path) or FileAccess.file_exists(report_path):quit(2);return
	var descriptor=JSON.parse_string(FileAccess.get_file_as_string(descriptor_path))
	if not descriptor is Dictionary or str(descriptor.get("format",""))!="nwn79-private-nwsync-visual-v1":quit(2);return
	var repository:=Repository.new();root.add_child(repository)
	var store:=Store.new()
	if not store.configure(cache_path) or not repository.configure(str(descriptor.url),cache_path):
		result.error="Private Godot NWSync repository configuration failed"
	else:
		var manifest: Dictionary=await repository.ensure_manifest(store,str(descriptor.manifestHash))
		if manifest.has("error"):
			result.error=str(manifest.error)
		else:
			result.manifestEntries=manifest.entries.size()
			for authored in descriptor.entries:
				var key:=str(authored.name)+":"+str(int(authored.type))
				if not manifest.entries.has(key):result.error="Authored resource missing from mounted manifest: "+key;break
				var entry: Dictionary=manifest.entries[key]
				if str(entry.hash)!=str(authored.hash) or int(entry.size)!=int(authored.size):result.error="Mounted manifest resource identity differs: "+key;break
				var bytes: Dictionary=await repository.ensure_blob(store,entry)
				if bytes.has("error"):result.error=str(bytes.error);break
				var mounted: Dictionary=store.resource(entry)
				if mounted.has("error") or Store.sha1(mounted.bytes)!=str(authored.hash) or mounted.bytes.size()!=int(authored.size):result.error="Mounted Godot resource bytes or digest differ: "+key;break
				result.entries.append({"name":str(authored.name),"type":int(authored.type),"hash":Store.sha1(mounted.bytes),"size":mounted.bytes.size(),"algorithm":int(authored.algorithm),"passed":true})
				if str(authored.name)=="gd_sync_icon":
					var image:=Image.new()
					if image.load_tga_from_buffer(mounted.bytes)!=OK or image.get_size()!=Vector2i(16,16):result.error="Mounted TGA did not decode in Godot";break
					var pixel:=image.get_pixel(0,0)
					result.iconPixel=absf(pixel.r-240.0/255.0)<0.001 and absf(pixel.g-170.0/255.0)<0.001 and absf(pixel.b-20.0/255.0)<0.001 and absf(pixel.a-1.0)<0.001
			if result.error.is_empty() and result.manifestEntries==13 and result.entries.size()==13 and result.iconPixel:result.success=true
			elif result.error.is_empty():result.error="Mounted Godot visual cohort is incomplete"
	store.close();repository.close()
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:printerr("NWN79 visual repository report is unwritable");quit(2);return
	file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print(JSON.stringify({"phase":result.phase,"success":result.success,"entries":result.entries.size(),"error":result.error}))
	quit(0 if result.success else 1)
