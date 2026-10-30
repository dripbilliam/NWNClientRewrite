extends SceneTree
const Stage=preload("res://systems/native_character_stage.gd")
const Visual=preload("res://systems/native_data/bic_visual.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable,seconds: int=60) -> bool:
	var end:=Time.get_ticks_msec()+seconds*1000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(600,800)
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original native appearance catalog mounts read-only")
	var bytes:=FileAccess.get_file_as_bytes(install.path_join("data/lcv/wizard.bic")); var parser:=Gff.new(); var document:=parser.parse(bytes,"BIC "); var source:=Visual.source(document)
	check(parser.failure.is_empty() and not source.has("error"),"Selected installed BIC supplies an actual appearance/equipment source")
	var view:=Stage.new(); root.add_child(view); view.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var incomplete:=source.duplicate(true); incomplete.equipmentComplete=false; view.observe([0,"stats-only"],incomplete)
	check(view.state.phase=="unavailable" and not view.actor_ready and not is_instance_valid(view.stream) and not view.surface.visible,"A stats-only server reply stays portrait-only instead of constructing a misleading unclothed model")
	var began:=Time.get_ticks_msec(); view.observe([1,"wizard",Cache.digest(bytes)],source)
	check(view.state.phase=="preparing" and not view.actor_ready,"Optional appearance work starts without blocking the native UI caller")
	check(await wait_for(func():return view.state.phase in ["ready","unavailable"]),"Native actor preparation reaches a terminal preview state")
	check(view.state.phase=="ready" and view.stream.actors.has(1),"Existing native world pipeline builds the selected character's actual model")
	var model_stats: Dictionary=view.stream.snapshot() if is_instance_valid(view.stream) else {}; var ready_ms:=Time.get_ticks_msec()-began
	if view.actor_ready:
		var actor=view.stream.actors[1]
		check(actor.meshes.size()>0 and actor.model_names.size()>1 and actor.failure.is_empty(),"Real character body/equipment meshes and their original model identities are retained")
		view.hide(); check(view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and view.stream.process_mode==Node.PROCESS_MODE_DISABLED,"Hidden preview stops viewport rendering and actor updates")
		view.show(); var yaw_before: float=view.yaw; var motion:=InputEventMouseMotion.new(); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; motion.relative=Vector2(20,0); view.surface_input(motion)
		var wheel:=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_UP; wheel.pressed=true; view.surface_input(wheel)
		check(view.yaw!=yaw_before and view.zoom<1.0,"Preview-only drag and wheel input rotates and zooms the actual model")
		if DisplayServer.get_name()!="headless":
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Native original character preview screenshot saved")
	view.observe([2,"old",Cache.digest(bytes)],source); view.observe([3,"latest"],{"error":"Owned missing-appearance fixture"})
	check(view.state.phase=="unavailable" and view.state.identity==[3,"latest"] and view.pending.is_empty(),"A later missing appearance retires old work instead of showing another character")
	check(await wait_for(func():return not is_instance_valid(view.retiring)) and not is_instance_valid(view.stream),"Superseded preview worker results and actors retire without publishing into the new selection")
	view.close(); check(view.closed and view.wanted.is_empty() and not is_instance_valid(view.stream) and not is_instance_valid(view.retiring),"Preview close joins outstanding work and clears its selected identity")
	view.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"model":model_stats,"ready_ms":ready_ms,"publicConnections":0,"native_only":true,"livePickerIntegrated":false,"onlinePreviewCompletenessValidated":false,"fullUiParity":false,"scope":"Actual installed BIC through native actor planning/decoding/mesh publication, private viewport, preview input, visibility and selection retirement. Live picker/server-vault integration remains separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
