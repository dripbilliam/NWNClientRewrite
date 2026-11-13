extends SceneTree
# Tiny hidden GUI-only raster acceptance, never a frame-rate benchmark.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var samples: Array=[]
func _initialize() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS,true);root.hide();run.call_deferred()
func check(value: bool,message: String) -> bool:
	checks+=1
	if not value:failures.append(message)
	return value
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	check(not root.visible and root.get_flag(Window.FLAG_NO_FOCUS),"The owned test window is hidden and non-activating")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original GUI catalog mounts read-only")
	var icons:=Icons.new();root.add_child(icons);icons.configure(catalog,"")
	var captured: Dictionary={}
	var capture:=func():
		if icons.pending_draw.is_empty():return
		var draw: Dictionary=icons.pending_draw;var job: Dictionary=draw.job;var meshes: Array=[]
		for mesh in draw.model.meshes:
			var material=mesh.material_override
			meshes.append({"visible":mesh.visible,"source":mesh.get_meta("native_source_part_index",-1),"material":material.get_class(),"cull":material.cull_mode if material is StandardMaterial3D else -1,"color":str(material.albedo_color) if material is StandardMaterial3D else str(material.get_shader_parameter("original_color"))})
		captured[job.key]={"meshes":meshes,"clip":job.clip}
	RenderingServer.frame_pre_draw.connect(capture)
	for icon in ["ir_cantrips","ir_level1","ir_level6"]:
		var key: String=icons.request_model("ctl_cg_btn_splvl","uncheckedup",{"gui_replace01":icon})
		var deadline:=Time.get_ticks_msec()+12000
		while icons.pending.has(key) and Time.get_ticks_msec()<deadline:
			await process_frame
			# Rendering is explicitly limited to the private32px SubViewport.
			if not icons.pending_draw.is_empty():RenderingServer.force_draw(false,0.0)
		if not check(icons.textures.has(key),"Actual native raster completes for "+icon):continue
		var image: Image=icons.textures[key].get_image();var interior:=0;var bright:=0
		for y in range(5,image.get_height()-5):
			for x in range(5,image.get_width()-5):
				var color:=image.get_pixel(x,y)
				if color.a>.2:
					interior+=1
					if maxf(color.r,maxf(color.g,color.b))>.12:bright+=1
		image.save_png(str(args.report).trim_suffix(".json")+"-"+icon+".png")
		var row:={"icon":icon,"width":image.get_width(),"height":image.get_height(),"interiorPixels":interior,"brightInteriorPixels":bright,"sha256":Cache.digest(image.get_data()),"draw":captured.get(key,{})};samples.append(row)
		check(bright>5,"Replacement icon has visible interior pixels rather than an empty tab: "+icon)
	check(samples.size()==3 and samples.map(func(row):return row.sha256).reduce(func(unique,item):
		if not unique.has(item):unique.append(item)
		return unique,[]).size()==3,"Distinct original replacement bitmaps produce distinct native tab rasters")
	RenderingServer.frame_pre_draw.disconnect(capture);icons.close();icons.free();await process_frame;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"scope":"Three original32px spell-tab rasters through the real private GUI renderer and actual replacement textures, hidden/no-focus owned window. Not a GPU benchmark, original-client visual comparison, whole-pane/input/server or full UI acceptance.","gpuRaster":true,"gpuBenchmark":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
