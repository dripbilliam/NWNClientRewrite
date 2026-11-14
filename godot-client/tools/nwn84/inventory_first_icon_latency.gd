extends SceneTree
# Offline click-to-visible-icon timing. Each invocation has a fresh item service;
# the caller runs both backends in separate processes at the same resolution.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Owner=preload("res://systems/native_inventory.gd")
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
var failures: Array=[]

func _initialize() -> void: call_deferred("run")

func visible_icon_count(owner,ids: Array) -> int:
	if not owner.ui.is_visible_in_tree(): return 0
	var count:=0
	for id in ids:
		var button=owner.ui.buttons.get(id)
		if button==null or not button.is_visible_in_tree(): continue
		if owner.retained_item_icons:
			var host=owner.ui.scene_host
			if is_instance_valid(host) and host.presentation.is_visible_in_tree() and host.binding_ready(str(id)): count+=1
		elif button.image.texture!=null and button.image.is_visible_in_tree(): count+=1
	return count

func measure_view(owner,ids: Array,label: String,started_us: int) -> Dictionary:
	var first_icon_ms: Variant=null
	var all_icons_ms: Variant=null
	var ui_visible_ms: Variant=null
	var controls_ms: Variant=null
	var deadline:=Time.get_ticks_msec()+90000
	var peak:=0
	var frames:=0
	var frame_elapsed: Array=[]
	while Time.get_ticks_msec()<deadline:
		await RenderingServer.frame_post_draw
		frames+=1
		var elapsed_ms:=float(Time.get_ticks_usec()-started_us)/1000.0
		if owner.detailed_timings:frame_elapsed.append(elapsed_ms)
		if controls_ms==null:
			var all_controls:=true
			for id in ids:
				if not owner.ui.buttons.has(id): all_controls=false;break
			if all_controls: controls_ms=elapsed_ms
		if ui_visible_ms==null and owner.ui.is_visible_in_tree(): ui_visible_ms=elapsed_ms
		var visible:=visible_icon_count(owner,ids)
		peak=maxi(peak,visible)
		if first_icon_ms==null and visible>0: first_icon_ms=elapsed_ms
		if visible==ids.size(): all_icons_ms=elapsed_ms;break
	if all_icons_ms==null:failures.append(label+" timed out with "+str(peak)+"/"+str(ids.size())+" visible icons")
	return {"label":label,"action_started_ms":float(started_us)/1000.0,"expected_icons":ids.size(),"peak_icons":peak,"frames":frames,"frame_elapsed_ms":frame_elapsed,"controls_ms":controls_ms,"ui_visible_ms":ui_visible_ms,"first_icon_ms":first_icon_ms,"all_icons_ms":all_icons_ms,"view":owner.view_serial,"page":owner.page,"prepared":owner.icons.bundles.size() if owner.retained_item_icons else owner.icons.textures.size(),"pending":owner.icons.pending.size(),"host_revision":owner.ui.scene_host.revision if owner.retained_item_icons else null,"presented_revision":owner.ui.scene_host.presented_revision if owner.retained_item_icons else null}

func switch_page(owner,page: int,ids: Array,label: String) -> Dictionary:
	var started_us:=Time.get_ticks_usec()
	owner.input_request({"kind":"inventory-page","viewId":owner.view_serial,"page":page})
	return await measure_view(owner,ids,label,started_us)

func run() -> void:
	var options: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:options[pair[0]]=pair[1]
	if not options.has_all(["install","oracle","report","backend","idle-ms","layout"]) or FileAccess.file_exists(str(options.report)) or str(options.backend) not in ["retained","legacy"] or str(options.layout) not in ["compact","full"]:quit(2);return
	var idle_ms:=int(options["idle-ms"])
	if idle_ms<0 or idle_ms>20000:quit(2);return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	var primary:=DisplayServer.get_primary_screen()
	for screen in DisplayServer.get_screen_count():
		if screen!=primary:
			root.current_screen=screen;root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80);break
	root.size=Vector2i(1100,850)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var catalog:=Catalog.new()
	if not catalog.mount_install(str(options.install)):failures.append("Installed catalog")
	if not catalog.mount_erf(str(options.install).path_join("data/nwm/Prelude.nwm"),100000000):failures.append("Prelude models")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(options.oracle)))
	var selected: Array=[];var one_by_one: Array=[];var one_by_two: Array=[];var seen: Dictionary={}
	for row in oracle.get("cases",[]):
		if row.get("error",false) or int(row.get("gender",-1))!=0 or int(row.get("plan",{}).get("width",0))!=1 or int(row.get("plan",{}).get("height",0)) not in [1,2]:continue
		var identity:=JSON.stringify(row.get("selected",{}).get("layers",[]))
		if seen.has(identity):continue
		seen[identity]=true
		if int(row.plan.height)==1:one_by_one.append(row)
		else:one_by_two.append(row)
	if one_by_one.size()<12 or str(options.layout)=="full" and one_by_two.size()<12:failures.append("Distinct installed 1x1 and 1x2 icons")
	if str(options.layout)=="full":
		selected.append_array(one_by_one.slice(0,12))
		selected.append_array(one_by_two.slice(0,12))
	else:selected=one_by_one.slice(0,12)
	var tables: Dictionary={}
	for name in ["baseitems","capart","parts_robe","cloakmodel","iprp_spells","encumbrance"]:
		var parser:=Table.new();tables[name]=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii())
		if not parser.failure.is_empty():failures.append("Original table "+name)
	if not failures.is_empty():finish(options,{"success":false,"failures":failures});return
	var text:=Text.new();text.tables=tables
	var surface:=Control.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(surface)
	var owner:=Owner.new();root.add_child(owner);owner.configure(surface,catalog,"",text)
	var frame_profiler
	if str(options.get("profile","false"))=="true":
		frame_profiler=FrameProfile.new();root.add_child(frame_profiler);frame_profiler.maximum_rows=1000;frame_profiler.configure(root)
	var asset_events: Array=[];var icon_events: Array=[];var host_events: Array=[]
	if str(options.get("profile","false"))=="true":
		owner.detailed_timings=true
		if owner.retained_item_icons and is_instance_valid(owner.ui.scene_host):owner.ui.scene_host.presented.connect(func(revision: int):host_events.append({"revision":revision,"presented_ms":float(Time.get_ticks_usec())/1000.0}))
		owner.icons.assets.completed.connect(func(_id: int,result: Dictionary):
			var phases: Dictionary=result.get("phases",{})
			var selected_phases: Dictionary={}
			for name in ["service_queue_ms","worker_queue_ms","source_digest_ms","memory_lookup_ms","model_ms","icon_textures_ms","textures_ms","memory_save_ms","prework_hit"]:
				if phases.has(name):selected_phases[name]=phases[name]
			asset_events.append({"resource":str(result.get("resource_name","")),"requested_ms":float(result.get("requested_ms",0.0)),"worker_started_ms":float(result.get("started_ms",0.0)),"delivered_ms":float(Time.get_ticks_usec())/1000.0,"read_ms":float(result.get("read_ms",0.0)),"worker_ms":float(result.get("worker_ms",0.0)),"cache_hit":bool(result.get("cache_hit",false)),"memory_cache_hit":bool(result.get("memory_cache_hit",false)),"prework_hit":bool(result.get("prework_hit",false)),"dependencies":result.get("dependencies",[]).size(),"error":str(result.get("error","")),"phases":selected_phases}))
		if owner.retained_item_icons:
			owner.icons.prepared.connect(func(key: String,_bundle: Dictionary,error: String):icon_events.append({"key":key,"ready_ms":float(Time.get_ticks_usec())/1000.0,"error":error}))
		else:
			owner.icons.completed.connect(func(key: String,_texture: Texture2D,error: String):icon_events.append({"key":key,"ready_ms":float(Time.get_ticks_usec())/1000.0,"error":error}))
	if owner.retained_item_icons!=(str(options.backend)=="retained"):failures.append("Whole-system backend mismatch")
	var actor:={"id":1,"objectType":5,"replicated":{"name":{"text":"Icon latency"}},"inventoryStats":{"field70":12,"field28c":149},"playerState":{"combat":{"field898":27,"armorClass":13}},"appearance":{"gender":0}}
	var objects: Array=[actor];var entries: Array=[];var pages: Array=[[],[]]
	var per_page:=selected.size()/2
	for index in selected.size():
		var id:=100+index
		var page:=index/per_page
		var x:=index%6
		var row_in_page: int=(index%per_page)/6
		var y:=page*6+row_in_page*(2 if str(options.layout)=="full" and page==1 else 1)
		objects.append({"id":id,"objectType":6,"item":selected[index].item.duplicate(true),"inventoryLocation":{"ownerId":1,"channel":"R","x":x,"y":y}})
		entries.append({"id":id,"x":x,"y":y})
		pages[page].append(id)
	owner.set_world(1,3,1,objects,{"inventories":[["R",{"entries":entries,"pageCount":2}]],"containers":[]})
	var idle_started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-idle_started<idle_ms:await RenderingServer.frame_post_draw
	var prepared_before_open: int=owner.icons.bundles.size() if owner.retained_item_icons else owner.icons.textures.size()
	var pending_before_open: int=owner.icons.pending.size()
	var opened_us:=Time.get_ticks_usec()
	owner.ui.open()
	var rows: Array=[]
	rows.append(await measure_view(owner,pages[0],"initial_inventory_open",opened_us))
	rows.append(await switch_page(owner,1,pages[1],"first_visit_page_2"))
	rows.append(await switch_page(owner,0,pages[0],"repeat_visit_page_1"))
	rows.append(await switch_page(owner,1,pages[1],"repeat_visit_page_2"))
	var final_pixels:=false
	if owner.retained_item_icons and is_instance_valid(owner.ui.scene_host):
		var image: Image=owner.ui.scene_host.viewport.get_texture().get_image()
		final_pixels=image!=null and image.get_used_rect().has_area()
	else:
		for id in pages[1]:
			var button=owner.ui.buttons.get(id)
			if button!=null and button.image.texture!=null:
				var image: Image=button.image.texture.get_image()
				if image!=null and image.get_used_rect().has_area():final_pixels=true;break
	if not final_pixels:failures.append("Final page icon texture has no visible pixels")
	var report:={"success":failures.is_empty(),"backend":str(options.backend),"layout":str(options.layout),"idle_before_open_ms":idle_ms,"prepared_before_open":prepared_before_open,"pending_before_open":pending_before_open,"rows":rows,"asset_events":asset_events,"icon_events":icon_events,"host_events":host_events,"refresh_events":owner.timing_rows.duplicate(true) if owner.detailed_timings else [],"frame_profile_rows":frame_profiler.rows.duplicate(true) if frame_profiler!=null else [],"final_icon_pixels":final_pixels,"failures":failures,"scope":"Offline installed-content inventory at 1100x850, Forward+/Vulkan, VSync off. Compact has six distinct 1x1 icons per page; full has twelve 1x1 on page 1 and twelve 1x2 on page 2. Times are action to completed visible-icon frame. No server, world, or Arelith."}
	if frame_profiler!=null:frame_profiler.set_enabled(false);frame_profiler.free()
	owner.close();owner.free();surface.free();text.close();await process_frame
	finish(options,report)

func finish(options: Dictionary,report: Dictionary) -> void:
	var file:=FileAccess.open(str(options.report),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
	print(JSON.stringify({"success":report.success,"backend":report.get("backend",""),"idle_ms":report.get("idle_before_open_ms",0),"rows":report.get("rows",[]),"failures":report.failures}))
	quit(0 if report.success else 1)
