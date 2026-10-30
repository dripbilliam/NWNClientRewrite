extends SceneTree
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Store=preload("res://systems/native_data/prework_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Controller=preload("res://systems/native_asset_prework.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const Session=preload("res://native_session_world.gd") # Parse the actual entry wiring too.
var checks:=0
var failures: Array=[]
var output:=""
var folder:=""
var phase:=""
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); print("FAIL: ",message)
func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=point; root.push_input(event,true); await process_frame
func model() -> PackedByteArray:
	return "newmodel authored\nsetsupermodel authored parent\nbeginmodelgeom authored\nnode trimesh root\nparent NULL\nbitmap paint\nverts 3\n0 0 0\n1 0 0\n0 1 0\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored\n".to_utf8_buffer()
func make_catalog():
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder.path_join("input")),"Authored local content mounts"); catalog.build_resource_index(); return catalog
func request(catalog,decoder: String,save: bool=false,options: Dictionary={}) -> Dictionary:
	var service:=Assets.new(); root.add_child(service); service.cache_directory=folder.path_join("cache"); service.prework_write=save; service.configure(catalog)
	var answer: Dictionary={}; service.completed.connect(func(_id,result):answer.merge(result))
	check(service.request("authored",2002,decoder,options)>0,"Actual worker request is accepted")
	var deadline:=Time.get_ticks_msec()+30000
	while answer.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(not answer.is_empty() and str(answer.get("error","timeout")).is_empty(),"Actual worker completes without asset error")
	service.close(); service.queue_free(); return answer
func wait_controller(owner) -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not owner.state.active,"Explicit action reaches completion")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--folder="): folder=arg.substr(9)
		elif arg.begins_with("--phase="): phase=arg.substr(8)
	if output.is_empty() or folder.is_empty() or FileAccess.file_exists(output): quit(2); return
	if phase=="cold":
		DirAccess.make_dir_recursive_absolute(folder.path_join("input"))
		write(folder.path_join("input/authored.mdl"),model())
		write(folder.path_join("input/parent.mdl"),"newmodel parent\nbeginmodelgeom parent\nnode dummy root\nparent NULL\nendnode\nendmodelgeom parent\n".to_utf8_buffer())
		var tga:=PackedByteArray(); tga.resize(18); tga[2]=2; tga[12]=1; tga[14]=1; tga[16]=32; tga[17]=40; tga.append_array(PackedByteArray([20,120,240,255])); write(folder.path_join("input/paint.tga"),tga)
	var catalog=make_catalog(); var store:=Store.new(); check(store.configure(folder.path_join("cache")),"Prework uses its own generated directory")
	var owner:=Controller.new(); root.add_child(owner)
	var controls:=Settings.new(); root.add_child(controls); controls.setup(folder.path_join("preferences.cfg"),""); controls.set_prework_available(true)
	root.size=Vector2i(1100,800); controls.show(); controls.tabs.current_tab=controls.prework_prepare.get_parent().get_index(); await process_frame; await process_frame
	owner.changed.connect(controls.update_prework)
	controls.prework_requested.connect(func():owner.start(catalog,folder.path_join("cache")))
	controls.prework_clear_requested.connect(func():owner.clear_saved(folder.path_join("cache")))
	controls.prework_cancel_requested.connect(owner.cancel)
	var icons:=Icons.new(); root.add_child(icons); icons.configure(catalog,folder.path_join("cache"))
	if phase=="cold":
		var ordinary:=await request(catalog,"actor-model",false,{"relevant_tracks":true})
		check(not ordinary.get("prework_saved",false) and DirAccess.get_files_at(store.directory).is_empty(),"Ordinary use does not silently generate saved prework")
		var key: String=icons.request_model("authored","")
		var deadline:=Time.get_ticks_msec()+30000
		while not icons.textures.has(key) and icons.stats.errors.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(icons.textures.has(key) and int(icons.stats.rendered)==1,"Cold GUI image renders on an actual viewport")
		if icons.textures.has(key): write(folder.path_join("expected-icon.bin"),icons.textures[key].get_image().get_data()); write(folder.path_join("expected-bounds.bin"),var_to_bytes(icons.image_bounds[key]))
		await click(controls.prework_prepare); await wait_controller(owner)
		check(int(owner.state.saved)>=3 and int(owner.state.failed)==0,"Explicit button saves model variants and finished UI pixels")
		check(not controls.prework_active and controls.prework_progress.value==controls.prework_progress.max_value,"Settings show completed progress and re-enable preparation")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(output+".png")
		write(folder.path_join("expected-model.bin"),var_to_bytes(ordinary.value))
	else:
		var warm:=await request(catalog,"actor-model",false,{"relevant_tracks":true})
		check(warm.get("prework_hit",false) and not warm.get("memory_cache_hit",false),"Fresh engine process reuses assembled model prework")
		check(Cache.digest(var_to_bytes(warm.value))==Cache.digest(FileAccess.get_file_as_bytes(folder.path_join("expected-model.bin"))),"Persisted prepared mesh, skin and rig data match the previous process")
		var key: String=icons.request_model("authored","")
		var deadline:=Time.get_ticks_msec()+30000
		while not icons.textures.has(key) and icons.stats.errors.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(icons.textures.has(key) and int(icons.stats.get("prework_hits",0))==1 and int(icons.stats.rendered)==0,"Fresh process restores finished artwork without model rendering or GPU readback")
		if icons.textures.has(key):
			check(icons.textures[key].get_image().get_data()==FileAccess.get_file_as_bytes(folder.path_join("expected-icon.bin")),"Persistent UI pixels are byte-exact across processes")
			check(var_to_bytes(icons.image_bounds[key])==FileAccess.get_file_as_bytes(folder.path_join("expected-bounds.bin")),"Persistent GUI bounds preserve input/layout geometry")
		# A dependency change must invalidate even though the requested root MDL is identical.
		var tga:=FileAccess.get_file_as_bytes(folder.path_join("input/paint.tga")); tga[18]=100; write(folder.path_join("input/paint.tga"),tga)
		var changed:=await request(make_catalog(),"actor-model",true,{"relevant_tracks":true})
		check(not changed.get("prework_hit",false) and changed.get("prework_saved",false) and changed.textures.paint.sha256!=warm.textures.paint.sha256,"Changed texture bytes rebuild and replace stale model prework")
		var refreshed:=await request(make_catalog(),"actor-model",false,{"relevant_tracks":true})
		check(refreshed.get("prework_hit",false),"Rebuilt dependency result is reusable")
		var scoped:=Assets.new(); root.add_child(scoped); scoped.cache_directory=folder.path_join("cache"); scoped.configure(make_catalog())
		var responses: Array=[]; scoped.completed.connect(func(_id,result):responses.append(result))
		for index in 2:
			scoped.request("authored",2002,"actor-model",{"relevant_tracks":true})
			while responses.size()<=index: await process_frame
		check(responses[0].get("prework_hit",false) and responses[1].get("memory_cache_hit",false),"Persistent loads populate the faster session memory cache")
		scoped.request("absent",2002,"bytes")
		while responses.size()<3: await process_frame
		check(not str(responses[2].error).is_empty(),"Optional cache probes cannot mask original resource read failures")
		scoped.close(); scoped.queue_free()
		var parent:=FileAccess.get_file_as_bytes(folder.path_join("input/parent.mdl")); parent.append_array("\n# changed parent\n".to_utf8_buffer()); write(folder.path_join("input/parent.mdl"),parent)
		var inherited:=await request(make_catalog(),"actor-model",true,{"relevant_tracks":true})
		check(not inherited.get("prework_hit",false) and inherited.get("prework_saved",false),"Supermodel changes invalidate assembled prework")
		# Direct store probes cover a newly introduced preferred format and optional resource.
		var tracked:=Store.Inputs.new(make_catalog()); tracked.raster_location("paint"); tracked.has_resource("optional",2002)
		var probe:=Cache.key("probe",Store.REVISION); var before_clear:=store.generation()
		check(store.save_entry(probe,tracked.snapshot(),{"probe":true},before_clear),"Dependency decisions can be persisted")
		write(folder.path_join("input/optional.mdl"),model())
		check(store.load_entry(probe,make_catalog()).is_empty(),"A formerly absent optional resource invalidates prework")
		# A corrupt derived file is a miss, followed by the original preparation path.
		for filename in DirAccess.get_files_at(store.directory):
			var path:=store.directory.path_join(filename); var file:=FileAccess.open(path,FileAccess.READ_WRITE)
			if file!=null and file.get_length()>48: file.seek(48); var byte:=file.get_8(); file.seek(48); file.store_8(byte^255); file.close()
		var repaired:=await request(make_catalog(),"actor-model",true,{"relevant_tracks":true})
		check(not repaired.get("prework_hit",false) and repaired.get("prework_saved",false),"Corrupt saved prework falls back and repairs")
		write(store.directory.path_join("keep.txt"),"unrelated".to_utf8_buffer())
		write(folder.path_join("cache/download-sentinel.bin"),"original-download".to_utf8_buffer())
		controls.prework_prepare.pressed.emit(); controls.prework_cancel.pressed.emit(); await wait_controller(owner)
		check(str(owner.state.message).begins_with("Preparation cancelled"),"Cancel stops preparation while retaining finished results")
		controls.prework_prepare.pressed.emit(); await process_frame; await click(controls.prework_clear); await wait_controller(owner)
		check(DirAccess.get_files_at(store.directory)==PackedStringArray(["keep.txt"]),"Clear drains work and removes only owned generated entries")
		check(FileAccess.get_file_as_bytes(folder.path_join("cache/download-sentinel.bin"))=="original-download".to_utf8_buffer() and FileAccess.file_exists(folder.path_join("input/authored.mdl")),"Clear preserves downloads and original files")
		check(not store.save_entry(probe,[],{"late":true},before_clear),"A queued old-generation save cannot recreate cleared work")
		check(icons.textures.has(key),"Clear does not destroy artwork currently in use")
		var flushed:=await request(make_catalog(),"actor-model",false,{"relevant_tracks":true})
		check(not flushed.get("prework_hit",false),"After Clear, later requests use original preparation")
		controls.prework_prepare.pressed.emit(); await process_frame; owner.close()
		check(not controls.prework_active and not controls.prework_prepare.disabled and not owner.clearing,"Connection/session retirement drains work and restores the controls")
		check(owner.clear_saved(folder.path_join("cache")),"Clear remains available after retiring a preparation run"); await wait_controller(owner)
	icons.close(); icons.queue_free(); owner.close(); owner.queue_free(); controls.queue_free(); await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"phase":phase,"public_connections":0,"scope":"Two fresh Godot processes; explicit controls, authored native model/texture/parent dependencies, graphical icon pixels and bounds, corruption repair, cancellation and scoped flush"}
	write(output,JSON.stringify(result,"\t").to_utf8_buffer()); print(JSON.stringify(result)); quit(0 if failures.is_empty() else 1)
