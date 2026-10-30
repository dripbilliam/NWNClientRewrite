extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Prework=preload("res://systems/native_prework_process.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func wait_texture(owner,key: String) -> Texture2D:
	var deadline:=Time.get_ticks_msec()+30000
	while not owner.textures.has(key) and owner.stats.errors.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	return owner.textures.get(key)
func run() -> void:
	var report:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
	if report.is_empty() or install.is_empty() or FileAccess.file_exists(report): quit(2); return
	var folder:=OS.get_temp_dir().path_join("nwn-prework-original-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original resources mount read-only"); catalog.build_resource_index()
	var owner:=Icons.new(); root.add_child(owner); owner.configure(catalog,folder)
	var pixels: Array=[]; var bounds: Array=[]
	for clip in ["up","down","hilite"]:
		var key: String=owner.request_model("pb_but_inv",clip); var texture:=await wait_texture(owner,key)
		check(texture!=null,"Original inventory button renders: "+clip)
		if texture!=null: pixels.append(texture.get_image().get_data()); bounds.append(owner.image_bounds[key])
	var controller:=Prework.new(); root.add_child(controller)
	controller.extra_variants=Icons.Assets.Prework.known_requests(catalog)
	check(controller.start_sources({"install":install,"modsDirectory":"","disabledMods":[]},folder,false),"Isolated current-session prework starts for original assets")
	var deadline:=Time.get_ticks_msec()+30000
	while controller.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not controller.state.active and int(controller.state.failed)==0 and int(controller.state.saved)>=3,"Original GUI states and their prepared model variants are saved")
	owner.close(); owner.queue_free(); controller.close(); controller.queue_free(); catalog=null; await process_frame; await process_frame
	# New catalogs, sources, resource pools and icon owners; no original owner
	# or session memory store survives. The other test also restarts the process.
	catalog=Catalog.new(); check(catalog.mount_install(install),"Fresh original catalog opens"); catalog.build_resource_index()
	owner=Icons.new(); root.add_child(owner); owner.configure(catalog,folder)
	for index in 3:
		var key: String=owner.request_model("pb_but_inv",["up","down","hilite"][index]); var texture:=await wait_texture(owner,key)
		check(texture!=null,"Saved original button state loads")
		if texture!=null and pixels.size()==3:
			check(texture.get_image().get_data()==pixels[index],"Original GUI pixels are byte-exact after disk reuse")
			check(owner.image_bounds[key]==bounds[index],"Original GUI state geometry survives disk reuse")
	check(int(owner.stats.get("prework_hits",0))==3 and int(owner.stats.rendered)==0 and owner.cached_models.is_empty(),"Warm original UI requires no model construction, render or GPU readback")
	owner.close(); owner.queue_free(); await process_frame; await process_frame
	var store:=Icons.Assets.Prework.new(); store.configure(folder); var cleared:=store.clear()
	check(int(cleared.get("removed",0))>=3 and cleared.get("errors",[]).is_empty(),"Original-derived prework clears without touching installed sources")
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"scope":"Installed original GUI up/down/hilite rendering, explicit baking, exact disk-reused pixels/bounds and scoped clear; no whole-world speedup or full UI parity claim"},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
