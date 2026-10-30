extends SceneTree
# Real installed GUI actor rendering, not isolated sampler-material tests.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
var checks:=0
var failures: Array=[]
var samples: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original GUI corpus mounts read-only")
	var icons:=Icons.new(); root.add_child(icons); icons.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	# Each state is drawn through the normal Actor.install path.
	for pose in ["uncheckedup","checkedup","uncheckeddown","checkeddown","disabled"]:
		var key: String=icons.request_model("ctl_pre_btn_tab",pose)
		var captured: Dictionary={}
		var capture:=func():
			if icons.pending_draw.is_empty() or icons.pending_draw.job.key!=key: return
			var job: Dictionary=icons.pending_draw.job
			captured.merge({"pose":pose,"actor":icons.pending_draw.model is Actor,"clamp":job.bundle.textures.gui_pre_playtabs.gui_sampler.clamp,"meshes":[]},true)
			for mesh in icons.pending_draw.model.meshes:
				var material=mesh.material_override
				captured.meshes.append({"repeat":material.texture_repeat if material is StandardMaterial3D else null,"source":mesh.get_meta("native_source_part_index",-1)})
		RenderingServer.frame_pre_draw.connect(capture)
		var deadline:=Time.get_ticks_msec()+30000
		while icons.pending.has(key) and Time.get_ticks_msec()<deadline:
			await process_frame
		RenderingServer.frame_pre_draw.disconnect(capture)
		check(icons.textures.has(key),"Original tab state produces native pixels: "+pose)
		if not icons.textures.has(key): continue
		check(captured.get("actor",false) and captured.get("clamp")==3,"Actual animated tab bundle retains original clamp3: "+pose)
		check(not captured.get("meshes",[]).is_empty() and captured.meshes.all(func(row):return row.repeat==false and row.source>=0),"Published actor meshes apply their own original texture sampler: "+pose)
		var image: Image=icons.textures[key].get_image(); image.save_png(output.trim_suffix(".json")+"-"+pose+".png")
		var bright: Array=[]
		for y in image.get_height():
			var color:=image.get_pixel(image.get_width()/2,y)
			if color.a>0.1 and maxf(color.r,maxf(color.g,color.b))>0.25: bright.append(y)
		captured.bright_rows=bright; captured.size=[image.get_width(),image.get_height()]; captured.pixel_sha256=Cache.digest(image.get_data()); samples.append(captured)
		check(bright.size()<=2,"Original clamped tab has one border instead of repeated atlas stripes: "+pose+" "+str(bright))
	# The next resource has the same bitmap but distinct physical source nodes.
	var reused_key: String=icons.request_model("ctl_pre_btn_tab2","uncheckedup")
	check(await wait_for(func():return not icons.pending.has(reused_key)) and icons.textures.has(reused_key),"Second original tab variant renders through the actor path")
	check(samples.size()==5 and icons.pending.is_empty() and icons.stats.errors.is_empty(),"All installed tab states finish without GUI renderer failures")
	icons.close(); icons.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"fullUiParity":false,"scope":"Installed original animated tab states, actual actor mesh sampler publication and border pixels through the normal GUI renderer. Original GPU/state/input/scale parity remains separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
