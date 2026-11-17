extends SceneTree
# Select a real rendered texture from the local GodotFeedback1 dense_a tile.
# Source-only preparation: no server, credentials, download or screenshot.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")

func _initialize()->void:
	run.call_deferred()

func run()->void:
	var install:=""
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--install="):install=argument.substr(10)
		if argument.begins_with("--report="):report=argument.substr(9)
	if install.is_empty() or report.is_empty() or FileAccess.file_exists(report):
		printerr("Unique --report and --install are required")
		quit(2)
		return
	var result:Dictionary={"format":"nwn79-nwsync-world-texture-target-v1","success":false,"area":"dense_a","module":"GodotFeedback1","tileModel":"ttr01_g01_01","candidates":[],"selected":{},"error":""}
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):
		result.error="Original installation catalog mount failed: "+str(catalog.failure)
	else:
		var model:PackedByteArray=catalog.get_resource("ttr01_g01_01",2002)
		if model.is_empty():
			result.error="Original dense_a tile model is unavailable: "+str(catalog.failure)
		else:
			var decoder:=Assets.new()
			var prepared:Dictionary=decoder.decode(model,2002,"mdl-original","")
			if not str(prepared.get("error","")).is_empty():
				result.error="Original dense_a tile decode failed: "+str(prepared.error)
			else:
				var counts:Dictionary={}
				for node in prepared.value.nodes:
					var mesh:Dictionary=node.get("mesh",{})
					if not bool(mesh.get("render",false)):continue
					var indices:PackedInt32Array=mesh.get("indices",PackedInt32Array())
					if indices.size()<3:continue
					for raw_name in mesh.get("textures",[]):
						var name:=str(raw_name).to_lower()
						if name.is_empty() or name=="null":continue
						counts[name]=int(counts.get(name,0))+indices.size()
				var best_name:=""
				var best_indices:=0
				for name in counts:
					var raster:Dictionary=catalog.raster_location(str(name))
					if raster.is_empty():continue
					var raw:PackedByteArray=catalog.get_resource(str(name),int(raster.type))
					if raw.is_empty():continue
					var row:Dictionary={"name":str(name),"type":int(raster.type),"indexReferences":int(counts[name]),"originalSha256":Cache.digest(raw)}
					result.candidates.append(row)
					if int(counts[name])>best_indices:
						best_name=str(name)
						best_indices=int(counts[name])
						result.selected=row
				if best_name.is_empty():result.error="Rendered dense_a tile had no available original raster dependency"
				else:result.success=true
			decoder.free()
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null:
		printerr("Target report is unwritable")
		quit(2)
		return
	file.store_string(JSON.stringify(result,"  ")+"\n")
	file.close()
	print(JSON.stringify({"success":result.success,"candidateCount":result.candidates.size(),"selected":result.selected,"error":result.error}))
	quit(0 if result.success else 1)
