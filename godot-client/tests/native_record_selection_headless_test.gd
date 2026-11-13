extends SceneTree
const Sheet=preload("res://systems/server_character_sheet.gd")
const Frame=preload("res://systems/native_character_sheet_frame.gd")
var checks:=0
var failures: Array=[]
var sent: Array=[]
var surface: SubViewport
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func frames(count: int=3) -> void:
	for index in count: await process_frame
func click(control: Control) -> void:
	var point:=control.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; surface.push_input(event,true); await frames()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	surface=SubViewport.new(); surface.size=Vector2i(1280,900); surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface)
	var sheet:=Sheet.new(); surface.add_child(sheet); sheet.setup(""); sheet.request.connect(func(value):sent.append(value.duplicate(true)))
	var message:={"kind":"sheet-view","viewId":1,"page":1,"model":{"identity":[42,55,1],"name":"Received character"},"entries":[{"entryId":71,"id":5,"name":"Skill one","icon":"","value":4,"canDrag":true,"description":{"text":"First received description"}},{"entryId":900,"id":8,"name":"Skill two","icon":"","value":2,"canDrag":true,"description":{"spans":[{"text":"Colored detail ","color":"#00ff00"},{"text":"repeated paragraph\n".repeat(300)}]}}]}
	sheet.open(); sheet.receive(message); await frames()
	check(sheet.entry_data.size()==2 and sheet.entry_nodes.has(71) and sheet.entry_nodes.has(900),"Actual received record retains arbitrary private entry IDs independently of row order")
	var native:=Frame.new(); native.panel=sheet; native.layout_ready=true; sheet.native_skin=native
	var group:=ButtonGroup.new()
	for row in sheet.entry_nodes.values(): row.toggle_mode=true; row.button_group=group
	var requests_before:=sent.size(); var first: Button=sheet.entry_nodes[71]; var second: Button=sheet.entry_nodes[900]
	await click(first)
	check(sheet.selected.get("1")==5 and sheet.description.get_parsed_text()=="First received description","Physical row selection updates the actual received detail content")
	check(first.button_pressed and not second.button_pressed and native.selected_entry==71,"Actual native selection method preserves source-style radio state")
	check(sent.size()==requests_before,"Selecting a detail row never waits for or sends a server request")
	var count: int=sheet.selection_timings.count; await click(first)
	check(sheet.selection_timings.count==count+1 and first.button_pressed and not second.button_pressed,"Repeated selection remains valid without rebuilding or retoggling all rows")
	await click(second)
	check(sheet.selected.get("1")==8 and second.button_pressed and not first.button_pressed,"Switching native selection retires the previous radio state")
	check(sheet.description.get_parsed_text().begins_with("Colored detail ") and sheet.description.get_parsed_text().ends_with("paragraph\n"),"Long colored received descriptions retain their full text")
	check(sheet.selection_timings.entry==8 and sheet.selection_timings.characters==sheet.description.get_total_character_count() and sheet.selection_timings.max_ms>=sheet.selection_timings.last_ms,"Selection diagnostics expose bounded timing/ID/count metadata without description contents")
	count=int(sheet.selection_timings.count); sheet.select_entry(123456)
	check(sheet.selection_timings.count==count and sheet.selected.get("1")==8,"Unknown private IDs do not select unrelated entries")
	check(sent.size()==requests_before,"Repeated and long-text detail selection remains entirely local")
	sheet.native_skin=null; native.close(); native.free()
	var old=first; var next: Dictionary=message.duplicate(true); next.viewId=2; next.model.identity=[43,55,1]; next.entries[0].description={"text":"Replacement detail"}; sheet.receive(next)
	var before: String=sheet.description.get_parsed_text(); count=int(sheet.selection_timings.count); old.pressed.emit()
	check(sheet.description.get_parsed_text()==before and sheet.selection_timings.count==count,"A held retired record row cannot select in the replacement view")
	sheet.reset(); check(sheet.entry_data.is_empty() and sheet.entry_nodes.is_empty() and not sheet.wanted,"World reset retires private entry data and widget ownership together")
	var diagnostic: Dictionary=sheet.selection_timings.duplicate(); sheet.free(); surface.queue_free(); await frames()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"selection":diagnostic,"publicConnections":0,"graphical":false,"scope":"Actual record widget input and native selection method over authored received-row fixtures, long text, no-network selection and stale/reset behavior. Source artwork is not constructed; no pixel or live FPS acceptance."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
