extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();var failure:="";var rows:Array=[]
	if not catalog.mount_install(args.install):failure=catalog.failure
	for resource in ["ctl_att"]:
		var location:Dictionary=catalog.raster_location(resource);var bytes:=catalog.get_resource(resource,int(location.type));var decoder:=Assets.new();var result:=decoder.decode(bytes,int(location.type),"raster",resource);decoder.free()
		if not str(result.error).is_empty():failure=str(result.error);break
		var data:Dictionary=result.value;var format:int={"rgba8":Image.FORMAT_RGBA8,"dxt1_rgb":Image.FORMAT_DXT1,"dxt1_rgba":Image.FORMAT_DXT1,"dxt3":Image.FORMAT_DXT3,"dxt5":Image.FORMAT_DXT5}.get(data.format,-1)
		if format<0:failure="Unsupported diagnostic format: "+str(data.format);break
		var image:=Image.create_from_data(int(data.width),int(data.height),false,format,data.mips[0].data)
		if image.is_compressed() and image.decompress()!=OK:failure="Original bitmap could not be decompressed on CPU.";break
		image.save_png(str(args.report)+"."+resource+".png")
		rows.append({"resource":resource,"location":location,"width":data.width,"height":data.height,"sha256":Cache.digest(bytes),"txi":catalog.get_resource(resource,2022).get_string_from_ascii() if catalog.has_resource(resource,2022) else "<absent>"})
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failure.is_empty(),"checks":1,"failures":[] if failure.is_empty() else [failure],"rows":rows,"gpu":false},"\t")+"\n");file.close();quit(0 if failure.is_empty() else 1)
