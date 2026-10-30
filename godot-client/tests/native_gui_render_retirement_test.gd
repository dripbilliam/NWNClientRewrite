extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Icons=preload("res://systems/native_item_icons.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label)
	return value
func wait_for(predicate: Callable) -> bool:
	var until:=Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<until: await process_frame
	return predicate.call()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original GUI render resources mount read-only")
	for reuse in [true,false]:
		var icons:=Icons.new(); root.add_child(icons); icons.configure(catalog,ProjectSettings.globalize_path("res://.cache/native-gui-render-retirement")); icons.reuse_models_enabled=reuse; icons.set_process(false)
		var key:=icons.request_model("gui_ra_circle56","up"); check(not key.is_empty(),"Original GUI model requested")
		if not check(await wait_for(func():return not icons.queue.is_empty()),"Original GUI preparation reaches the native render queue"): icons.close(); icons.free(); continue
		icons._profile_process(0.0)
		check(icons.active and not icons.pending_draw.is_empty() and RenderingServer.frame_post_draw.is_connected(icons.frame_rendered),"Actual GUI draw waits for its owned post-draw callback")
		var model: WeakRef=weakref(icons.pending_draw.model)
		icons.close()
		check(not icons.active and icons.pending_draw.is_empty() and not RenderingServer.frame_post_draw.is_connected(icons.frame_rendered),"Closing cancels the owned post-draw callback")
		check(model.get_ref()==null and icons.assets.running.is_empty() and icons.assets.pending.is_empty(),"Closing retires cached/transient GUI models and preparation workers")
		icons.free()
		for draw in 3: await process_frame
		check(model.get_ref()==null,"No freed GUI owner resumes after subsequent real rendered frames")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual original GUI model preparation/draw with cached and transient active models closed before frame-post-draw, then owner freed and later frames rendered. No server/performance claim."},"\t")); file.close()
	print("NATIVE_GUI_RENDER_RETIREMENT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
