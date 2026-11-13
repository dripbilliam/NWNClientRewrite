extends SceneTree
const Sheet=preload("res://systems/server_character_sheet.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
var surface: SubViewport
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
	return value
func mouse(point: Vector2,pressed: bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=point; event.global_position=point; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; surface.push_input(event,true); await process_frame
func click(control: Control) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=control.get_global_rect().get_center(); motion.global_position=motion.position; surface.push_input(motion,true); await process_frame
	await mouse(motion.position,true); await mouse(motion.position,false)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.trim_prefix("--report=")
		if arg.begins_with("--install="): install=arg.trim_prefix("--install=")
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1440,960)
	surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed base resource catalog mounts read-only")
	var ui:=Gameplay.new(); root.add_child(ui); ui.set_process(false); ui.generation=1; ui.area_id=55; ui.controlled_id=42
	check(ui.text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Actual original dialog.tlk opens in the native text owner")
	for name in ["skills","feat","classes","racialtypes","exptable","ruleset"]:
		ui.text.publish_table(name,Table.new().parse(catalog.read_resource(name,2017).get_string_from_ascii()))
	var desktop:=Desktop.new(); ui.add_child(desktop); desktop.set_process(false); desktop.owner_ui=ui; desktop.rules.text=ui.text; ui.desktop=desktop
	var sheet:=Sheet.new(); sheet.setup(""); surface.add_child(sheet); desktop.sheet=sheet; sheet.request.connect(desktop.input_request); desktop.request.connect(func(message):requests.append(message.duplicate(true)))
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Native skill test"},"hitPoints":{"current":10,"maximum":10},"stats":{"racialType":6,"classes":[{"id":10,"level":3}]}},"inventoryStats":{"skills":[]},"playerState":{"abilities":{"current":[10,10,10,10,10,10]},"feats":[0,1,2]}}
	desktop.objects={42:actor}; desktop.generation=1; desktop.area_id=55; desktop.actor_id=42; ui.text.objects=desktop.objects
	sheet.wanted=true; sheet.page=1; sheet.show()
	var details:=await additional_checks(ui,output,actor)
	ui.close(); ui.free(); sheet.free(); catalog=null; await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":{"additional":details},"publicConnections":0,"scope":"Real Godot record-entry pointer input, native desktop and receive owners, installed base skills/TLK plus authored dynamic server overrides. Artwork/raster/font publication and original-server acceptance are separate."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)

func skill_requests() -> Array:
	return requests.filter(func(message):return message.get("kind","")=="native-panel" and message.get("panel","")=="skill")

func additional_checks(ui,_output: String,actor: Dictionary) -> Dictionary:
	var desktop=ui.desktop; var sheet=desktop.sheet
	var skills: Array=ui.text.tables.skills.orderedRows
	var perform:=-1
	for index in skills.size():
		if str(skills[index].get("Label","")).to_lower()=="perform": perform=index; break
	if not check(perform>=0,"Installed skills.2da supplies the Perform row instead of a hardcoded skill ID"): return {}
	var ref:=int(skills[perform].Description)
	actor.inventoryStats.skills=[{"index":perform,"flag":true,"value":-1},{"index":0,"flag":true,"value":4}]
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":ref,"text":"Ability: Charisma.\n<CUSTOM9001>\nThe character with high Perform is skilled in a type of artistic expression."}]},desktop.generation)
	ui.receive({"kind":"custom-token","id":9001,"text":""},desktop.generation)
	sheet.page=1; desktop.refresh_sheet()
	await process_frame; await process_frame; await process_frame
	var id:=-1
	for key in sheet.entry_data:
		if int(sheet.entry_data[key].id)==perform: id=int(key); break
	if not check(id>=0,"A received negative skill value remains a selectable server-visible row"): return {}
	var row: Button=sheet.entry_nodes[id]; var current_view: int=sheet.view_id
	var before: int=skill_requests().size()
	await click(row)
	check(skill_requests().size()==before+1,"A real native row press/release sends exactly one skill inspection")
	check(skill_requests().back()=={"kind":"native-panel","panel":"skill","open":true,"skillId":perform,"targetId":42,"actorId":42,"areaId":55,"generation":1},"Skill inspection carries the current displayed actor, area generation and active skill ID")
	check(sheet.description.get_parsed_text().contains("artistic expression") and not sheet.description.get_parsed_text().contains("disguise"),"First selection displays the currently received basic description")
	ui.receive({"kind":"custom-token","id":9001,"text":"Your current disguise skill is: -1"},desktop.generation)
	await process_frame; await process_frame
	check(is_instance_valid(row) and sheet.entry_nodes[id]==row and sheet.view_id==current_view,"A received custom-token change does not rebuild the skill list or retire current input controls")
	await click(row)
	check(skill_requests().size()==before+2 and sheet.description.get_parsed_text().contains("Your current disguise skill is: -1"),"Clicking the same native row again resolves new server-supplied custom text and sends another GUI event")
	check(sheet.entry_nodes[id]==row and sheet.view_id==current_view,"Repeated inspection preserves row identity and the private drag/view lifetime")
	ui.receive({"kind":"tlk-overrides","entries":[{"strRef":ref,"text":"Server-specific Perform description\n<c"+String.chr(1)+String.chr(255)+String.chr(1)+">Updated disguise help</c>\n[b]literal[/b]"}]},desktop.generation)
	await process_frame; await click(row)
	check(sheet.description.get_parsed_text().contains("Server-specific Perform description") and sheet.description.get_parsed_text().contains("[b]literal[/b]") and not sheet.description.bbcode_enabled,"Repeated selection fetches the latest active TLK override while preserving literal markup and native rich spans")
	var frozen: Dictionary=actor.duplicate(true); var samples: Array=[]
	for iteration in 200:
		var start:=Time.get_ticks_usec(); row.pressed.emit(); samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	check(samples[189]<8.0,"Warm repeated selection stays below8ms p95 without whole-menu reconstruction")
	check(actor==frozen,"Inspection never changes received ranks, calculates disguise or invents a server outcome")
	var obsolete_request:={"kind":"sheet-select","viewId":sheet.view_id,"page":1,"entryId":id}
	var old_row: Button=row
	var count: int=skill_requests().size(); desktop.refresh_sheet(); await process_frame
	check(skill_requests().size()==count,"Restoring selected rows during a server refresh does not send click events")
	desktop.input_request(obsolete_request)
	check(skill_requests().size()==count,"A retired view cannot issue a skill inspection after rebuilding")
	check(not is_instance_valid(old_row) or not old_row.current(),"Retired physical controls cannot inspect the replacement view")
	var new_view: int=sheet.view_id
	var new_id: int=sheet.entry_nodes.keys()[0]
	var saved: Dictionary=sheet.entry_data[new_id].description.duplicate(true)
	sheet.receive({"kind":"sheet-description","viewId":current_view,"page":1,"entryId":new_id,"description":{"text":"stale"}})
	check(sheet.entry_data[new_id].description==saved,"Late text for a retired view cannot decorate a new row")
	sheet.receive({"kind":"sheet-description","viewId":new_view,"page":2,"entryId":new_id,"description":{"text":"wrong page"}})
	check(sheet.entry_data[new_id].description==saved,"A description from another page cannot replace current skill help")
	await click(sheet.tabs[2]); await process_frame
	var feat_count: int=skill_requests().size()
	if not sheet.entry_nodes.is_empty(): await click(sheet.entry_nodes.values()[0])
	check(skill_requests().size()==feat_count,"Feat inspection is not mislabeled as a skill GUI event")
	sheet.close_sheet(); desktop.input_request({"kind":"sheet-select","viewId":sheet.view_id,"page":sheet.page,"entryId":0})
	check(skill_requests().size()==feat_count,"Closing the record retires skill-inspection admission")
	return {"repeated_selection_ms":{"p50":samples[99],"p95":samples[189],"max":samples.back(),"samples":samples.size()},"physical_input":true,"server_updates":"Authored messages through the real native UI receive path","live_server_validated":false,"native_gui_event":3,"skill_id":perform,"tlk_reference":ref}
