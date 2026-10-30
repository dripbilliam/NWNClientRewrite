extends SceneTree
const Controller=preload("res://systems/native_ui_preload.gd")
const Settings=preload("res://systems/native_render_settings.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Entry=preload("res://native_session_world.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.pressed=down; event.button_index=MOUSE_BUTTON_LEFT; root.push_input(event,true); await process_frame
func wait_owner(owner,seconds: int=60) -> void:
	var deadline:=Time.get_ticks_msec()+seconds*1000
	while owner.state.active and Time.get_ticks_msec()<deadline: await process_frame
	check(not owner.state.active,"Explicit UI preload reaches a terminal state")
func wait_icon(owner,key: String) -> Texture2D:
	var deadline:=Time.get_ticks_msec()+30000
	while owner.pending.has(key) and Time.get_ticks_msec()<deadline: await process_frame
	return owner.textures.get(key)
func run() -> void:
	var output:=""; var install:=""; var folder:=""; var phase:="cold"; var all_models:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
		elif arg.begins_with("--cache="): folder=arg.substr(8)
		elif arg.begins_with("--phase="): phase=arg.substr(8)
		elif arg=="--all-models=true": all_models=true
	if output.is_empty() or install.is_empty() or folder.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,800)
	var menu:=Settings.new(); root.add_child(menu); menu.setup(output+".preferences.cfg",output+".layout.cfg"); menu.set_prework_sources(["Installed original game"],false); menu.show(); menu.tabs.current_tab=menu.ui_preload_prepare.get_parent().get_index()
	var owner:=Controller.new(); root.add_child(owner)
	if not all_models: owner.model_filter=["pb_but_inv","ctl_btr_btn_acpt","pnl_opt_key","gui_ra_menu","scrollbar_simple"]
	owner.changed.connect(menu.update_ui_preload)
	var requests: Array=[]; var model_requests: Array=[]
	menu.ui_preload_requested.connect(func():
		requests.append(true); owner.start_sources({"install":install,"modsDirectory":"","disabledMods":[]},folder))
	menu.prework_requested.connect(func():model_requests.append(true))
	menu.ui_preload_cancel_requested.connect(owner.cancel)
	await process_frame; await process_frame
	check(menu.ui_preload_prepare.text=="Preload all menus" and not menu.ui_preload_prepare.disabled and menu.ui_preload_content.item_count==1,"Separate UI preload tab exposes a local content choice and its own action")
	await click(menu.ui_preload_prepare)
	check(requests.size()==1 and model_requests.is_empty() and owner.state.active,"Actual UI preload click starts native menu work without invoking model/world preparation")
	check(menu.prework_prepare.disabled and menu.prework_clear.disabled and menu.ui_preload_content.disabled and not menu.ui_preload_cancel.disabled,"Conflicting preparation/clear/content changes lock while UI work runs; its Cancel remains available")
	check(not owner.start_sources({"install":install},folder),"A second UI preload cannot overlap the current owner")
	await wait_owner(owner,600 if all_models else 60)
	var completed: Dictionary=owner.state.duplicate(true)
	check(not completed.get("cancelled",false) and int(completed.get("gui_documents",0))==104 and int(completed.get("fonts",0))>=3,"Unopened original GUI definitions and fonts are included")
	var known_issues: Array=completed.get("issues",[]).filter(func(message):return str(message).begins_with("fnt_13pp_chat01:") or str(message).begins_with("fnt_chatspacer:") or str(message).begins_with("ctl_btn_srv_lan: Invalid ASCII animated-mesh sample period") or str(message).begins_with("ctl_spellbox_nxt: Invalid ASCII animated-mesh sample period"))
	check(int(completed.failed)==known_issues.size(),"Compatible menus complete; the four known legacy font/model reader issues are explicitly reported")
	check(int(completed.completed)==int(completed.total) and int(completed.total)>104,"Progress covers menu states, definitions and fonts, and reaches completion")
	check(int(completed.get("peak_private_images",99))<=1 and int(completed.get("peak_saves",99))<=2 and int(completed.get("peak_save_bytes",0))<=owner.maximum_save_bytes,"Prepared image/write working sets remain bounded")
	check(owner.catalog==null and owner.icons==null and owner.fonts==null and owner.assets==null and owner.saves.is_empty() and owner.plan_task<0,"Completion releases private catalog, model/font GPU owners and all save/discovery workers")
	check(not menu.ui_preload_prepare.disabled and menu.ui_preload_cancel.disabled and menu.ui_preload_progress.value==menu.ui_preload_progress.max_value,"Separate progress and control availability reflect completion")
	if phase=="cold": check(int(completed.saved)>0 and int(completed.rendered)>0,"Cold preload actually renders and verifies persistent menu images")
	else: check(int(completed.rendered)==0 and int(completed.reused)>0,"A fresh engine reuses finished UI pixels rather than rebuilding or rendering models")
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.trim_suffix(".json")+"-complete.png")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Ordinary menu consumer mounts its own fresh original catalog"); catalog.build_resource_index()
	var layout_assets:=Icons.Assets.new(); root.add_child(layout_assets); layout_assets.cache_directory=folder; layout_assets.configure(catalog)
	var layout_result: Dictionary={}; layout_assets.completed.connect(func(_id,result):layout_result.merge(result))
	layout_assets.request("pnl_opt_key",2002,"actor-model")
	var layout_deadline:=Time.get_ticks_msec()+30000
	while layout_result.is_empty() and Time.get_ticks_msec()<layout_deadline: await process_frame
	check(layout_result.get("prework_hit",false) and not layout_result.get("memory_cache_hit",false) and str(layout_result.get("error","timeout")).is_empty(),"The real layout-owner request also reuses its assembled original model from disk")
	layout_assets.close(); layout_assets.queue_free()
	var consumer:=Icons.new(); root.add_child(consumer); consumer.configure(catalog,folder)
	var pixels: Array=[]; var bounds: Array=[]
	for clip in ["up","down","hilite"]:
		var key: String=consumer.request_model("pb_but_inv",clip); var image:=await wait_icon(consumer,key)
		check(image!=null,"Unopened original inventory button state is ready from UI preload: "+clip)
		if image!=null: pixels.append(image.get_image().get_data()); bounds.append(consumer.image_bounds[key])
	check(int(consumer.stats.get("prework_hits",0))==3 and int(consumer.stats.rendered)==0 and consumer.cached_models.is_empty(),"Real GUI consumers skip model construction, drawing and GPU readback after preload")
	consumer.close(); consumer.queue_free()
	if phase=="cold":
		var reference:=Icons.new(); root.add_child(reference); reference.configure(catalog,folder+"-reference")
		for index in 3:
			var key: String=reference.request_model("pb_but_inv",["up","down","hilite"][index]); var image:=await wait_icon(reference,key)
			check(image!=null and pixels.size()==3 and image.get_image().get_data()==pixels[index] and reference.image_bounds[key]==bounds[index],"Preloaded pixels and original geometry equal an unbaked render")
		reference.close(); reference.queue_free()
	# Cancellation during the real private source scan must retire without
	# dispatching the deferred whole-catalog bake, and preserve completed work.
	await click(menu.ui_preload_prepare); await click(menu.ui_preload_cancel); await wait_owner(owner)
	check(owner.state.cancelled and owner.loader==null and owner.catalog==null and owner.saves.is_empty() and owner.plan_task<0,"Actual separate Cancel drains source discovery and active workers")
	check(not menu.prework_prepare.disabled and not menu.prework_clear.disabled and not menu.ui_preload_prepare.disabled,"Cancelling UI preload restores independent preparation controls")
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")
	owner.close(); owner.free(); menu.free(); catalog=null; await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"preload":completed,"phase":phase,"all_models":all_models,"entry_owner_sha256":FileAccess.get_sha256("res://native_session_world.gd"),"publicConnections":0,"scope":"Actual separate native UI preload/cancel controls; unopened original menu states, GUI definitions and fonts; bounded native pixel generation, verified persistent saves and fresh-owner/fresh-process reuse. Variable-size/live-content layouts remain runtime work."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
