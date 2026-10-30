extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var messages: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+60000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func click(button: Button) -> void:
	var point:=button.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; root.push_input(event,true); await process_frame
func same_equipment(actual: Array,observed: Array) -> bool:
	if actual.size()!=observed.size(): return false
	for entry in observed:
		var matches: Array=actual.filter(func(value):return int(value.slot)==int(entry.slot))
		if matches.size()!=1: return false
		var a: Dictionary=matches[0].item; var b: Dictionary=entry.item
		if int(a.baseItem)!=int(b.baseItem) or int(a.modelType)!=int(b.modelType): return false
		for field in ["parts","colors"]:
			if a.get(field,[]).map(func(value):return int(value))!=b.get(field,[]).map(func(value):return int(value)): return false
		var colors_a: Array=a.get("partColors",[]); var colors_b: Array=b.get("partColors",[])
		if colors_a.size()!=colors_b.size(): return false
		for index in colors_a.size():
			if colors_a[index].map(func(value):return int(value))!=colors_b[index].map(func(value):return int(value)): return false
	return true
func run() -> void:
	var output:=""; var install:=""; var wire_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
		if arg.begins_with("--wire-fixture="): wire_path=arg.substr(15)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,800)
	var ui:=Lobby.new(); root.add_child(ui); ui.preferences.open_file(""); ui.enable_picker(); ui.request.connect(func(value):messages.append(value.duplicate(true)))
	var state:={"phase":"character-selection","connected":true,"canSelect":true,"canLobbyPages":true,"canCreate":true,"localAllowed":false,"selected":null,"choices":[{"key":"server:wizard","label":"Spector ial Melmion","source":"server","serverSource":17,"firstName":{"text":"Spectorial"},"lastName":{"text":"Melmion"},"classes":[{"id":10,"level":15}]},{"key":"server:fighter","label":"Junta Khan","source":"server","serverSource":17,"firstName":{"text":"Junta"},"lastName":{"text":"Khan"},"classes":[{"id":4,"level":15}]}]}
	var wire: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(wire_path)) if not wire_path.is_empty() else {}
	if wire.is_empty(): state.choices=[state.choices[0]]; state.choices[0].portraitRef="po_el_m_06_"; state.choices[0].label="Spectorial Melimion"
	if not wire.is_empty():
		var row: Dictionary=wire.character.duplicate(true); row.serverSource=row.source; row.source="server"; row.key="server:"+str(int(row.serverSource))+":"+str(row.resref); row.label="Received original-server character"; state.choices=[row]
	ui.apply_state({"connection":1,"state":state})
	check(ui.picker.shell.built and ui.picker.visible and not ui.window_column.visible and not is_instance_valid(ui.native_chooser),"Production picker appears before classic artwork, catalog or3D services are constructed")
	check(messages.size()==1 and messages[0].kind=="lobby-choose","Immediate server roster makes one normal acknowledged selection request")
	var key: String=messages[0].key; state.selected=key; state.selectionAck={"key":key,"requestId":messages[0].requestId}; ui.apply_state({"connection":1,"state":state})
	await process_frame; await process_frame
	check(ui.native_selection.is_empty() and not ui.picker.shell.play.disabled and not is_instance_valid(ui.picker.stage),"Acknowledged server-vault selection enables Play without a local save or model")
	await click(ui.picker.shell.play)
	check(messages[-1].kind=="lobby-play" and messages[-1].connection==1 and messages[-1].key==key,"Actual modern Enter World input issues the existing authoritative lobby request")
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Active native preview catalog mounts read-only")
	check(catalog.mount_directory(install.path_join("data/prt"),90000000,[3,2033]),"Native preview catalog includes installed portrait artwork like the production session catalog")
	var text=preload("res://systems/native_data/talk_text.gd").new(); text.base.open_file(install.path_join("lang/en/data/dialog.tlk")); ui.picker.configure_source(text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var folder:=output.trim_suffix(".json")+"-bytes"; var sha:=""; var file_path:=""
	if wire.is_empty():
		DirAccess.make_dir_recursive_absolute(folder); var bytes:=FileAccess.get_file_as_bytes(install.path_join("data/lcv/wizard.bic")); sha=Cache.digest(bytes); file_path=folder.path_join(sha+".bic"); var file:=FileAccess.open(file_path,FileAccess.WRITE); file.store_buffer(bytes); file.close(); state.preview={"format":"native-bic-file-v1","path":file_path,"bytes":bytes.size(),"sha256":sha}
	else:
		folder=str(wire.directory); state.preview=wire.packet; sha=str(wire.packet.sha256); file_path=str(wire.packet.path)
	ui.configure_preview(folder); ui.apply_state({"connection":1,"state":state})
	check(not ui.picker.shell.play.disabled,"A received preview-byte ticket cannot put Play behind model preparation")
	var model: Dictionary={}; var equipment_included: bool=wire.get("equipmentIncluded",true)
	check(await wait_for(func():return is_instance_valid(ui.picker.stage) and ui.picker.stage.state.phase in ["ready","unavailable"]),"Native selected-byte decoding reaches a terminal optional preview state")
	check(ui.native_preview.value.visualSource.equipmentComplete==equipment_included,"Native equipment completeness agrees with independent decoding of the actual original-server reply")
	if equipment_included:
		check(ui.picker.stage.actor_ready and not ui.picker.shell.portrait.visible,"Complete character data builds its real model without a model-readiness admission gate")
		if is_instance_valid(ui.picker.stage.stream): model=ui.picker.stage.stream.snapshot()
	else:
		check(not ui.picker.stage.actor_ready and not is_instance_valid(ui.picker.stage.stream) and not ui.picker.stage.surface.visible and ui.picker.shell.portrait.visible and ui.picker.shell.stage_status.text.contains("does not include equipment"),"An equipment-omitting server reply shows the portrait and explanation instead of a misleading unclothed model")
	check(ui.picker.stage.wanted==[1,key,sha] and not ui.picker.shell.play.disabled,"Both complete and incomplete previews stay bound to the selected connection/key/digest and leave Play available")
	var portraits_ready: bool=await wait_for(func():return ui.picker.shell.row_portraits[key].texture!=null and ui.picker.shell.portrait.texture!=null)
	if not portraits_ready: print("PORTRAIT_DIAGNOSTIC ",JSON.stringify({"rowReady":ui.picker.shell.row_portraits[key].texture!=null,"previewReady":ui.picker.shell.portrait.texture!=null,"failed":ui.picker.art.failed.keys(),"textures":ui.picker.art.textures.keys(),"waiting":ui.picker.art.waiting.keys(),"jobs":ui.picker.art.jobs,"source":ui.record_preview().get("portraitRef",""),"rawType":catalog.raster_location("po_el_m_06_t")}))
	check(portraits_ready,"Actual native portrait artwork fills the roster and fallback without a local character file")
	check(ui.picker.shell.row_portraits[key].flip_v and ui.picker.shell.row_portraits[key].texture.get_width()*100.0/64.0==ui.picker.shell.row_portraits[key].texture.get_height(),"The original padded portrait is cropped and flipped rather than stretched")
	var shell_us: int=ui.picker.shell.built_us
	var cached_preview_checked:=false; var saved_path:=""; var cache_folder:=output.trim_suffix(".json")+"-appearance-cache"
	if equipment_included or wire.has("observedActor"):
		ui.appearance_cache.directory=cache_folder; state.previewAccountScope=str(wire.get("accountScope","c".repeat(64))); state.endpoint={"host":"127.0.0.1","port":5126}
		var actor: Dictionary=wire.observedActor if wire.has("observedActor") else preload("res://systems/native_data/bic_visual.gd").actor(ui.native_preview.value.visualSource,ui.picker.stage.baseitems)
		state.phase="playing"; state.canSelect=false; ui.apply_state({"connection":1,"state":state})
		var scope: Array=ui.appearance_cache.identity(state); saved_path=ui.appearance_cache.filename(scope)
		check(ui.save_last_seen(actor) and ui.appearance_identity.is_empty(),"An admitted production controller saves only its selected character's observed appearance before disconnect teardown")
		ui.close_native(); state.phase="character-selection"; state.canSelect=true; state.preview=null; state.selectionAck=null; ui.apply_state({"connection":2,"state":state}); ui.picker.configure_source(text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
		check(await wait_for(func():return is_instance_valid(ui.picker.stage) and ui.picker.stage.actor_ready),"Reopening the same server/account/character builds its last-seen equipment without a BIC reply")
		check(ui.picker.stage_cached and ui.picker.shell.stage_status.text.begins_with("Last seen appearance") and not ui.picker.shell.play.disabled,"Cached appearance is visibly labeled and never controls Play admission")
		var restored: Dictionary=preload("res://systems/native_data/bic_visual.gd").actor(ui.appearance_cache.read_seen(scope).source,ui.picker.stage.baseitems)
		check(same_equipment(restored.appearance.equipment,actor.appearance.equipment),"The last-seen preview retains the actual observed slot, base-item, model parts and dye colors")
		if DisplayServer.get_name()!="headless":
			await process_frame; await process_frame; await RenderingServer.frame_post_draw; check(root.get_texture().get_image().save_png(output.trim_suffix(".json")+".cached.png")==OK,"Actual native last-seen equipped-character screenshot captured before joining")
		var count:=messages.size(); state.preview={"visualSource":{"appearance":{},"equipmentComplete":false}}; ui.apply_state({"connection":2,"state":state})
		check(ui.picker.stage_cached and ui.picker.stage.actor_ready and messages.size()==count,"A later stats-only reply keeps the last-seen model without issuing gameplay or inventory requests")
		state.preview={"format":"native-bic-file-v1","path":file_path,"bytes":FileAccess.get_file_as_bytes(file_path).size(),"sha256":sha}; ui.apply_state({"connection":2,"state":state})
		if equipment_included:
			check(await wait_for(func():return ui.picker.stage.actor_ready and not ui.picker.stage_cached) and ui.picker.stage.wanted==[2,key,sha] and not ui.picker.shell.stage_status.text.begins_with("Last seen"),"Fresh complete server data supersedes the cached model and its stale-data label")
		else:
			check(ui.picker.stage_cached and ui.picker.stage.actor_ready and ui.picker.shell.stage_status.text.begins_with("Last seen"),"The real reconnected server's stats-only byte reply leaves the labeled cached equipment visible")
		state.previewAccountScope="d".repeat(64); state.preview={"visualSource":{"appearance":{},"equipmentComplete":false}}; ui.apply_state({"connection":3,"state":state})
		check(not ui.picker.stage_cached and not ui.picker.stage.actor_ready and ui.picker.shell.portrait.visible and ui.picker.stage.state.phase=="unavailable","Another account cannot display the previous account's last-seen appearance")
		cached_preview_checked=true
	if DisplayServer.get_name()!="headless":
		await process_frame; await process_frame; await RenderingServer.frame_post_draw; check(root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Actual production picker screenshot captured")
	state.preview=null; state.selected=null; state.selectionAck=null; state.choices=[]; ui.apply_state({"connection":4,"state":state}); await process_frame
	check(ui.picker.shell.play.disabled and not ui.picker.stage.actor_ready and not ui.picker.stage.surface.visible and ui.picker.shell.portrait.texture==null,"Connection replacement immediately removes the old model, portrait and Play selection")
	ui.close_native(); ui.free(); text.close(); await process_frame; await process_frame
	if wire.is_empty(): DirAccess.remove_absolute(file_path); DirAccess.remove_absolute(folder)
	if not saved_path.is_empty(): check(DirAccess.remove_absolute(saved_path)==OK and DirAccess.remove_absolute(cache_folder)==OK,"Only the owned controller-test appearance snapshot is removed")
	var report:=FileAccess.open(output,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"shell_build_us":shell_us,"model":model,"equipmentIncluded":equipment_included,"cachedPreviewChecked":cached_preview_checked,"publicConnections":0,"fullUiParity":false,"serverVaultWireValidated":false,"scope":"Production picker/controller with supplied server-vault metadata and selected-byte ticket: immediate shell, normal selection/Play requests, actual pointer input, complete native model or explicit incomplete-data portrait fallback, last-seen save/reopen/label/fresh replacement/account guards, portrait artwork/cropping and stale-source cleanup. Real original server-vault wire/admission validation is separate."},"  ")+"\n"); report.close(); quit(0 if failures.is_empty() else 1)
