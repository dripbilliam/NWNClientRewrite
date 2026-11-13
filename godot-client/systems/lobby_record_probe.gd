extends "res://systems/lobby_pages_probe.gd"
# Owned local action-test input only. No public connection or physical pointer.
var identity: Array=[]
var result: Dictionary={}
var owner_id: int=0
func current_identity() -> Array:
	var ui=client.character_lobby; var packet: Dictionary=ui.state.get("preview",{}) if ui.state.get("preview") is Dictionary else {}
	return [ui.connection,ui.state.get("selected"),str(packet.get("sha256",""))]
func owned() -> bool:
	if not running or not is_instance_valid(client) or client.closing: return false
	var ui=client.character_lobby
	return is_instance_valid(ui) and is_instance_valid(ui.native_chooser) and ui.native_chooser.get_instance_id()==owner_id and current_identity()==identity
func retire() -> void:
	result={"success":false,"cancelled":true,"identity":identity.duplicate()}; running=false; client=null
func wait_until(predicate: Callable,seconds: float=30) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while owned() and Time.get_ticks_msec()<end:
		if predicate.call(): return owned()
		await client.process_frame
	return false
func click(button: Button) -> void:
	if not owned() or not is_instance_valid(button): return
	var point:=button.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; client.root.push_input(motion,true); await client.process_frame
	for pressed in [true,false]:
		if not owned(): return
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0; client.root.push_input(event,true); await client.process_frame
func run(tree) -> void:
	client=tree; identity=current_identity(); owner_id=client.character_lobby.native_chooser.get_instance_id(); result={}
	var ui=client.character_lobby; var native=ui.native_chooser; var pane=native.record_feats
	var ready: bool=await wait_until(func():return native.layout_ready and client.gameplay_ui.tables_ready and native.frame.fonts.pending.is_empty() and not ui.record_preview().is_empty() and native.record_projection.get("ready",false) and native.skill_projection.get("ready",false) and native.spell_projection.get("ready",false) and native.rule_jobs.is_empty() and ui.can_select() and ui.native_selection.is_empty() and native.automatic_selection.is_empty() and native.record_tabs.all(func(tab):return tab.is_visible_in_tree() and not tab.disabled))
	if not owned(): retire(); return
	check(ready,"Actual native BIC record and active tables are ready for pregame Feats input")
	if ready:
		check(not is_instance_valid(client.world) and not client.gameplay_ui.presentation_enabled,"Preview inspection remains pregame without entering the world")
		await click(native.record_tabs[1])
		if not owned(): retire(); return
		var skills=native.record_skills
		check(native.record_index==1 and skills.is_visible_in_tree() and not skills.rows.is_empty(),"Original Skills tab opens native BIC-derived values after active class-table loading")
		check(skills.entries.all(func(row):return native.skill_projection.entries.any(func(expected):return expected.id==row.id and expected.value==row.value)),"Original Skill row values retain the independently tested native pregame arithmetic")
		if not skills.rows.is_empty():
			await click(skills.rows[0])
			if not owned(): retire(); return
			check(skills.selected==0 and not skills.description.get_parsed_text().is_empty() and skills.rows[0].get_child(2).text==str(int(skills.entries[0].value)),"Actual Skill row input displays current native help and the separate source value label")
		await click(native.record_tabs[2])
		if not owned(): retire(); return
		check(native.record_index==2 and pane.is_visible_in_tree() and not pane.entries.is_empty(),"Original Feats tab opens rows from the actual selected local BIC")
		var owned_feats: Array=ui.record_preview().get("feats",[])
		check(pane.entries.all(func(row):return owned_feats.has(int(row.id))),"Displayed pregame feat IDs belong to the independently hashed BIC source")
		if not pane.rows.is_empty():
			await click(pane.rows[0])
			if not owned(): retire(); return
			check(pane.selected==0 and pane.rows[0].button_pressed and not pane.description.get_parsed_text().is_empty(),"Actual original-row input selects received feat help through native active resources")
		await click(native.record_tabs[3])
		if not owned(): retire(); return
		var spells=native.record_spells
		check(native.record_index==3 and spells.is_visible_in_tree() and spells.entries.size()==native.spell_projection.entries.size(),"Original Spells tab opens the selected BIC's native spell rows")
		var known: Array=[]
		for book in ui.record_preview().get("spellSource",{}).get("books",[]): known.append_array(book.get("known",[]))
		check(spells.entries.all(func(row):return row.summary or known.has(int(row.id))),"Known pregame spell IDs belong to the typed BIC source, alongside original summary rows")
		var spell_index:=-1
		for index in spells.entries.size():
			if not spells.entries[index].summary: spell_index=index; break
		if spell_index>=0:
			await click(spells.rows[spell_index])
			if not owned(): retire(); return
			check(spells.selected==spell_index and not spells.description.get_parsed_text().is_empty(),"Actual known-spell row input displays native active help without casting")
		else: check(spells.description.get_parsed_text().is_empty(),"A character without known-spell rows retains empty pregame help")
		await click(native.record_tabs[0])
		if not owned(): retire(); return
		check(native.record_index==0 and native.statistics.is_visible_in_tree() and not pane.is_visible_in_tree(),"Returning to Character restores its original body before Play")
	var proof:={"success":owned() and checks.size()==12 and checks.all(func(item):return item.passed),"checks":checks,"connection":identity[0],"key":identity[1],"sha256":identity[2],"publicConnections":0,"endpoint":"127.0.0.1:5125","scope":"Native pregame Skills/Feats/Spells input on this exact connection/key/BIC digest before authoritative local admission. No gameplay/casting action is fabricated."}
	result=proof
	if owned(): client.report.lobby_record=proof
	running=false; client=null
