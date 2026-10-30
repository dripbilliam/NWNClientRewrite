extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); var decoder:=Assets.new(); var failures: Array=[]; var models: Dictionary={}; var rasters: Dictionary={}
	if not catalog.mount_install(install): failures.append(catalog.failure)
	if failures.is_empty():
		for name in ["pnl_chrsht2","pnl_chrsht_char2","ctl_pre_btn_tab","ctl_pre_btn_tab2","ctl_chr_btn_tab5"]:
			var raw: PackedByteArray=catalog.get_resource(name,2002); var parsed:=decoder.decode(raw,2002,"mdl-original","")
			if not str(parsed.error).is_empty(): failures.append(name+": "+str(parsed.error)); continue
			var nodes: Array=[]
			for node in parsed.value.nodes:
				var mesh: Dictionary=node.get("mesh",{}); var material: Dictionary={}
				for key in mesh:
					if key not in ["vertices","normals","indices","uv","faces","tangents","skin","weights","bone_indices"]: material[key]=mesh[key]
				nodes.append({"name":node.name,"parent":node.parent,"position":node.position,"alpha":node.get("alpha",1),"selfillum":node.get("selfillum",[]),"features":node.features,"mesh":material,"vertices":mesh.get("vertices",PackedFloat32Array()),"uv":mesh.get("uv",[])})
				for texture in mesh.get("textures",[]):
					if str(texture).is_empty() or rasters.has(texture): continue
					var location: Dictionary=catalog.raster_location(str(texture))
					if location.is_empty(): continue
					var bytes: PackedByteArray=catalog.get_resource(str(texture),int(location.type)); var raster:=decoder.decode(bytes,int(location.type),"raster","")
					if not str(raster.error).is_empty(): failures.append(str(texture)+": "+str(raster.error)); continue
					rasters[texture]={"sha256":Cache.digest(bytes),"format":raster.value.format,"width":raster.value.width,"height":raster.value.height}
					if catalog.has_resource(str(texture),2022):
						var txi: PackedByteArray=catalog.get_resource(str(texture),2022); rasters[texture].txi={"sha256":Cache.digest(txi),"text":txi.get_string_from_ascii()}
					var format: int={"rgba8":Image.FORMAT_RGBA8,"dxt1_rgb":Image.FORMAT_DXT1,"dxt5":Image.FORMAT_DXT5}.get(raster.value.format,-1)
					if format>=0:
						var image:=Image.create_from_data(int(raster.value.width),int(raster.value.height),false,format,raster.value.mips[0].data)
						if image.is_compressed(): image.decompress()
						image.flip_y(); image.save_png(output.trim_suffix(".json")+"-"+str(texture)+".png")
			models[name]={"sha256":Cache.digest(raw),"nodes":nodes}
	decoder.free(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":models.size(),"failures":failures,"models":models,"rasters":rasters,"publicConnections":0,"scope":"Read-only installed chooser MDL material/UV/controller and original raster evidence; no UI parity or rendered behavior accepted."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
