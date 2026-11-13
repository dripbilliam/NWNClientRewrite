extends "res://tests/native_raster_conversion_test.gd"
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const GuiInfo=preload("res://systems/native_data/gui_texture_info.gd")
var completed: Dictionary={}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","install","oracle","inventory"]) or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle is Dictionary and oracle.get("binarySha256","")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.get("observations",[]).size()==18,"Pinned original loader observations include all bounded header cases")
	check(Convert.available,"Actual compiled PLT converter is available")
	if oracle is Dictionary:
		for observation in oracle.get("observations",[]):
			var raw:=plt(int(observation.width),int(observation.height)); raw.encode_u32(8,int(observation.attribute))
			var reference:=Palette.new(); reference.use_native=false; var native:=Palette.new(); native.use_native=true
			var info:=reference.header(raw)
			check(int(observation.accepted)==1 and int(observation.metadata[2])==int(observation.attribute) and not info.is_empty() and int(info.get("width",0))==int(observation.width) and int(info.get("height",0))==int(observation.height),"Header admission matches executed original attribute "+str(observation.attribute)+" at "+str(observation.width)+"x"+str(observation.height))
			var a:=reference.decode(raw,palettes()); var b:=native.decode(raw,palettes())
			check(reference.failure.is_empty() and native.failure.is_empty() and not a.is_empty() and same(a,b),"Both converters preserve complete pixels for original-admitted header "+str(observation.attribute))
			check(int(native.stats.native_pixels)==int(observation.width)*int(observation.height) and int(native.stats.gd_pixels)==0,"Original-admitted header uses the compiled pixel path "+str(observation.attribute))
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Installed original catalog mounts without network")
	var inventory: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.inventory)); var samples: Array=inventory.get("samples_outside_current_parser",[]) if inventory is Dictionary else []
	check(samples.size()==6,"Original inventory scan supplies six independently hashed declared11 resources")
	var prepared_samples: Array=[]
	for sample in samples:
		var raw: PackedByteArray=catalog.get_resource(str(sample.name),6)
		check(catalog.failure.is_empty() and Cache.digest(raw)==str(sample.sha256) and raw.decode_u32(8)==11,"Installed problematic PLT matches independent source hash: "+str(sample.name))
		var gd:=Palette.new(); gd.use_native=false; var native:=Palette.new(); native.use_native=true
		var a:=gd.prepare(catalog,str(sample.name),[0,0,30,30,42,55,64,64,0,0]); var b:=native.prepare(catalog,str(sample.name),[0,0,30,30,42,55,64,64,0,0])
		check(str(a.get("error","")).is_empty() and str(b.get("error","")).is_empty() and a.has("value") and b.has("value") and same(a.get("value"),b.get("value")),"Actual source palettes bake exact GD/native pixels: "+str(sample.name))
		check(int(b.get("conversion",{}).get("native_pixels",0))==int(sample.width)*int(sample.height),"Installed PLT uses compiled conversion: "+str(sample.name))
		if b.has("value"): prepared_samples.append({"name":sample.name,"sha256":sample.sha256,"rgba_sha256":Cache.digest(b.value.mips[0].data)})
	var worker:=Assets.new(); root.add_child(worker); worker.configure(catalog); worker.completed.connect(func(id,result):completed[id]=result)
	for entry in [["ihelm_017","gui_icon_2x2l"],["ipm_chest050","gui_icon_armr1l"]]:
		var request: int=worker.request(entry[1],2002,"gui-icon-v1",{"icon_layers":[{"name":entry[0],"type":6,"palette":[0,0,30,30,42,55,64,64,0,0]}],"icon_descriptor":["installed-header-test",entry[0]],"gui_texture_info":GuiInfo.REVISION})
		var deadline:=Time.get_ticks_msec()+20000
		while not completed.has(request) and Time.get_ticks_msec()<deadline: await process_frame
		var result: Dictionary=completed.get(request,{"error":"No worker result"}); var texture: Dictionary=result.get("textures",{}).get("gui_replace01",{}).get("value",{})
		check(str(result.get("error","")).is_empty() and texture.get("format","")=="rgba8" and not texture.get("mips",[]).is_empty(),"Actual native GUI-icon worker publishes original replacement pixels: "+entry[0]+" "+str(result.get("error","")))
	worker.close(); check(worker.running.is_empty() and worker.pending.is_empty(),"Actual icon worker drains before owner retirement"); worker.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":prepared_samples,"scope":"Executed original uncompressed header admission, actual installed PLT/palette pixels across native/GD and complete GUI-icon worker preparation. No original GPU pixel or graphical icon acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
