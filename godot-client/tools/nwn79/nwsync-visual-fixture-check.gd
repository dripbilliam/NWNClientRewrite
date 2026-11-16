extends SceneTree
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
	if not descriptor_path.is_absolute_path() or not report_path.is_absolute_path() or FileAccess.file_exists(report_path):quit(2);return
	var result: Dictionary={"format":"nwn79-nwsync-visual-fixture-preflight-v1","success":false,"entries":[],"manifestEntries":0,"iconPixel":false,"error":""}
	if not FileAccess.file_exists(descriptor_path):
		result.error="Authored fixture descriptor is missing"
	else:
		var descriptor=JSON.parse_string(FileAccess.get_file_as_string(descriptor_path))
		if not descriptor is Dictionary or str(descriptor.get("format",""))!="nwn79-private-nwsync-visual-v1":
			result.error="Invalid authored visual fixture descriptor"
		else:
			var directory:=descriptor_path.replace("\\","/").get_base_dir()
			var manifest_path:=directory.path_join("manifest.bin")
			if not FileAccess.file_exists(manifest_path):
				result.error="Authored manifest is missing"
			else:
				var manifest: Dictionary=Store.decode_manifest(FileAccess.get_file_as_bytes(manifest_path),str(descriptor.manifestHash))
				if manifest.has("error"):
					result.error=str(manifest.error)
				else:
					result.manifestEntries=manifest.entries.size()
					for authored in descriptor.entries:
						var hash:=str(authored.hash)
						var key:=str(authored.name)+":"+str(int(authored.type))
						var path:=directory.path_join("blobs").path_join(hash+".bin")
						if not manifest.entries.has(key) or not FileAccess.file_exists(path):
							result.error="Authored resource is absent from manifest or fixture: "+key+" manifest="+str(manifest.entries.has(key))+" file="+str(FileAccess.file_exists(path))
							break
						var mapped: Dictionary=manifest.entries[key]
						if str(mapped.hash)!=hash or int(mapped.size)!=int(authored.size):
							result.error="Authored resource identity differs from manifest"
							break
						var blob:=FileAccess.get_file_as_bytes(path)
						if blob.size()<16 or int(blob.decode_u32(8))!=int(authored.algorithm):
							result.error="Authored blob compression identity differs"
							break
						var decoded: Dictionary=Store.decode_blob(blob,hash,int(authored.size))
						if decoded.has("error"):
							result.error=str(decoded.error)
							break
						result.entries.append({"name":str(authored.name),"type":int(authored.type),"size":decoded.bytes.size(),"hash":Store.sha1(decoded.bytes),"algorithm":int(authored.algorithm),"passed":true})
						if str(authored.name)=="gd_sync_icon":
							var image:=Image.new()
							if image.load_tga_from_buffer(decoded.bytes)!=OK or image.get_size()!=Vector2i(16,16):
								result.error="Authored TGA failed Godot decode"
								break
							var pixel:=image.get_pixel(0,0)
							result.iconPixel=absf(pixel.r-240.0/255.0)<0.001 and absf(pixel.g-170.0/255.0)<0.001 and absf(pixel.b-20.0/255.0)<0.001 and absf(pixel.a-1.0)<0.001
					if result.error.is_empty() and result.manifestEntries==13 and result.entries.size()==13 and result.iconPixel:
						result.success=true
					elif result.error.is_empty():result.error="Authored visual cohort is incomplete"
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	if file==null:printerr("NWN79 visual preflight report is unwritable");quit(2);return
	file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print(JSON.stringify({"success":result.success,"entries":result.entries.size(),"iconPixel":result.iconPixel,"error":result.error}))
	quit(0 if result.success else 1)
