extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Palette=preload("res://systems/native_data/palette_texture.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures:Array=[]
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message)
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed catalog opens read-only")
	var result:Dictionary={"models":{},"palettes":{}}
	var bytes:PackedByteArray=catalog.get_resource("gui_cg_color_tmp",6);var decoder:=Palette.new();var info:Dictionary=decoder.header(bytes)
	check(catalog.failure.is_empty() and decoder.failure.is_empty() and not info.is_empty(),"Original GUI_CG_COLOR_TMP is a valid type6 PLT")
	var channels:Dictionary={}
	if not info.is_empty():
		for pixel in int(info.width)*int(info.height):
			var layer:int=bytes[25+pixel*2];var intensity:int=bytes[24+pixel*2]
			if not channels.has(layer):channels[layer]=[]
			if not channels[layer].has(intensity):channels[layer].append(intensity)
		for values in channels.values():values.sort()
	result.plt={"sha256":Cache.digest(bytes),"bytes":bytes.size(),"header":info,"channels":channels}
	for name in ["pal_skin01","pal_hair01","pal_tattoo01"]:
		var raw:PackedByteArray=catalog.get_resource(name,3);var parser:=Raster.new();var value:Dictionary=parser.parse(raw,3)
		check(catalog.failure.is_empty() and parser.failure.is_empty() and value.get("width")==256,"Original palette width/type/pixels are valid: "+name)
		result.palettes[name]={"sha256":Cache.digest(raw),"width":value.get("width"),"height":value.get("height"),"pixelSha256":Cache.digest(value.mips[0].data) if not value.is_empty() else ""}
	for name in ["ctl_cg_btn_colw","ctl_cg_btn_col","ctl_cg_colr_skin","ctl_cg_colr_hair","ctl_cg_colr_tatt"]:
		var raw:PackedByteArray=catalog.get_resource(name,2002);var parser:=Actor.new();var model:Dictionary=parser.parse(raw)
		check(catalog.failure.is_empty() and parser.failure.is_empty(),"Original color button model parses: "+name)
		var meshes:Array=[]
		for node in model.get("nodes",[]):
			if node.get("mesh",{}).get("render",false):meshes.append({"name":node.name,"textures":node.mesh.get("textures",[]),"vertexCount":node.mesh.get("vertices",[]).size()/3,"uvSets":node.mesh.get("uv",[]).size()})
		result.models[name]={"sha256":Cache.digest(raw),"meshes":meshes,"clips":model.get("animations",[]).map(func(clip):return clip.name)}
	result.merge({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Read-only installed GUI color PLT, native palette raster dimensions and source button texture layers; no original sampling or UI acceptance."})
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close();quit(0 if failures.is_empty() else 1)
