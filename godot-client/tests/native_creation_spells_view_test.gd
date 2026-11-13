extends "res://tests/native_portrait_chooser_test.gd"
const Spells=preload("res://systems/native_spells_chooser.gd")
const SpellState=preload("res://systems/native_data/creation_spells_state.gd")
func key_spell(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func source_model(count: int) -> Dictionary:
	var result:={"memorizes":true,"learnScroll":true,"pickSchool":false,"keepBudget":false,"classLevel":1,"intModifier":2,"baseInt":14,"school":0,"storedRemaining":0,"opposition":null,"capacity":[],"gain":[],"minimum":[],"known":[],"spells":[]}
	for level in 10:result.capacity.append(0);result.gain.append(1 if level<2 else 0);result.minimum.append(level<2);result.known.append([])
	for id in count+1:result.spells.append({"id":id,"level":0 if id==0 else 1,"school":1,"name":"Server spell %04d"%id,"description":20000+id,"icon":"sp_fixture_"+str(id)})
	result.known[0]=[0];result.known[1]=[count];return result
func wait_spell(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+20000
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await process_frame
	return false
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Original Spells catalog mounts read-only")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(catalog.get_resource("cg_spells",2047))=="5ecd6d81abc022bf42ea3ed9bbe49156b5859e4fceb310e38e1651cf82149929","Pinned original Spells GFF hierarchy")
	surface=SubViewport.new();surface.size=Vector2i(1200,800);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=HeadlessArt.new();var fonts:=HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var text=preload("res://systems/native_data/talk_text.gd").new();text.overrides[20001]="The server's first spell description"
	var state:=SpellState.new();check(state.configure(source_model(1024)).ready,"Complete custom1024-spell source snapshot admits the existing original policy")
	var pane:=Spells.new();surface.add_child(pane);pane.position=Vector2(30,30);pane.configure(painter,captions,catalog,"")
	var actions: Array=[];var results: Array=[];var phases: Array=[]
	pane.action_requested.connect(func(operation,id,ticket):
		var began:=Time.get_ticks_usec()
		actions.append([operation,id,ticket.duplicate()])
		if operation=="add":state.add(id)
		elif operation=="remove":state.remove(id)
		elif operation=="level":state.select_level(id)
		elif operation=="reset":state.reset_choices()
		var policy_done:=Time.get_ticks_usec();var projection:=state.view();var projected:=Time.get_ticks_usec();pane.update_model(projection)
		if operation in ["add","remove"]:phases.append({"policyMs":(policy_done-began)/1000.0,"projectionMs":(projected-policy_done)/1000.0,"viewMs":(Time.get_ticks_usec()-projected)/1000.0}))
	pane.finished.connect(func(accepted,ticket):results.append([accepted,ticket.duplicate()]))
	pane.set_context(state.view(),false,text,art,[310,1]);pane.open();pane.start()
	check(await wait_spell(func():return pane.layout_ready or not pane.failure.is_empty()) and pane.layout_ready and pane.failure.is_empty(),"Original Spells workers/model helpers prepare: "+pane.failure)
	var samples: Array=[];var pool_count:=0
	if pane.layout_ready and pane.failure.is_empty():
		await frames();pool_count=pane.rows.available.size()+pane.rows.known.size()
		check(pool_count<=24 and pane.model.available.size()==1023 and pane.rows.available[0].label.text=="Server spell 0001","A large physical spell table uses only the bounded visible-row pool")
		check(pane.rows.known.all(func(cell):return not cell.button.visible) and pane.remaining.text=="5" and pane.buttons.okbutton.disabled,"Prior known spells are hidden and the shared original budget drives OK")
		check(painter.button_geometry[pane.buttons.spelllevel7.get_instance_id()].overrides=={"gui_replace01":"ir_level789"} and pane.buttons.spelllevel2.disabled,"Original level icons and class-dependent tab admission are retained")
		var nodes: Array=pane.rows.available.map(func(cell):return cell.button.get_instance_id())+pane.rows.known.map(func(cell):return cell.button.get_instance_id())
		await click(pane.buttons["available:0"]);check(actions.is_empty() and pane.selected.available==1 and state.known[1]==[1024],"Physical row selection does not invent an add action")
		await click(pane.buttons["available:0:arrow"]);check(state.known[1]==[1024,1] and pane.remaining.text=="4" and pane.rows.known[0].id==1,"Physical original arrow changes the policy book while retaining the initial snapshot")
		await click(pane.buttons["known:0:arrow"]);check(state.known[1]==[1024] and pane.remaining.text=="5" and pane.rows.available[0].id==1,"Physical remove restores the original budget and sorted available row")
		await click(pane.buttons.spelllevel0);check(state.selected_level==0 and pane.empty_label.visible and pane.rows.known.all(func(cell):return not cell.button.visible),"Cantrip tab hides initial known choices and uses the original empty-list label")
		await click(pane.buttons.spelllevel1);check(state.selected_level==1 and not pane.empty_label.visible,"Physical level tab returns to the correct active spell pool")
		pane.buttons["available:0:info"].show();await click(pane.buttons["available:0:info"])
		check(await wait_spell(func():return pane.info_popup.layout_ready or not pane.info_popup.failure.is_empty()) and pane.info_popup.layout_ready and pane.info_popup.failure.is_empty(),"Distinct original CSpellInfoPanel source child prepares: "+pane.info_popup.failure)
		if pane.info_popup.layout_ready:
			await frames();check(pane.modal_active and pane.info_popup.title.text=="Server spell 0001" and pane.info_popup.description.get_parsed_text()=="The server's first spell description" and pane.info_popup.plan.entries.closebutton.callback=="0x1409c8080","Information child uses active spell text and its own original Close callback")
			var child_identity: Array=pane.popup_identity.duplicate();pane.retire_input();check(pane.popup_identity==child_identity and pane.modal_active,"Retiring parent held input leaves its distinct current information request identity intact")
			var before:=actions.size();await click(pane.buttons["available:0:arrow"]);check(actions.size()==before,"An actual modal information child blocks lower-list mouse input")
			await click(pane.info_popup.buttons.closebutton);check(not pane.modal_active and not pane.info_popup.wanted,"Physical spell information Close restores the parent without changing choices")
		var old_id: int=pane.rows.available[1].id;var before:=actions.size();await mouse(pane.buttons["available:1:arrow"],true);pane.lists.available.scroll_vertical=2200;await frames();await mouse(pane.buttons["available:1:arrow"],false);await frames()
		check(pane.rows.available[1].id!=old_id and actions.size()==before,"Held input cannot select a different spell after its pooled row is rebound by scrolling")
		check(nodes==pane.rows.available.map(func(cell):return cell.button.get_instance_id())+pane.rows.known.map(func(cell):return cell.button.get_instance_id()),"Scrolling retains every row and nested helper control")
		pane.lists.available.scroll_vertical=0;await frames()
		for turn in 12:
			var id: int=pane.rows.available[0].id;var count_before:=actions.size();var began:=Time.get_ticks_usec();pane.capture("available:0:arrow");pane.invoke("available:0:arrow");var added: bool=state.known[1]==[1024,id];pane.capture("known:0:arrow");pane.invoke("known:0:arrow");samples.append((Time.get_ticks_usec()-began)/1000.0)
			check(added and actions.size()==count_before+2 and state.known[1]==[1024] and pane.rows.available[0].id==id,"Repeated physical-handler add/remove changes and restores the actual policy book "+str(turn))
		check(samples.max()<50.0,"Actual1024-definition handler pairs avoid an obnoxious synchronous stall: "+str(samples))
		pane.capture("available:0:arrow");pane.set_context(state.view(),false,text,art,[310,2]);pane.invoke("available:0:arrow");check(state.known[1]==[1024] and pane.buttons.recommendbutton.disabled,"Reticketed held input and unbound recommendation cannot mutate choices")
		pane.set_busy(true);before=actions.size();await click(pane.buttons.resetbutton);check(actions.size()==before,"Pending owner work prevents duplicate reset actions");pane.set_busy(false)
		pane.update_model({"ready":false});check(pane.rows.available.all(func(cell):return not cell.button.visible) and pane.rows.known.all(func(cell):return not cell.button.visible) and pane.remaining.text.is_empty(),"Missing getter state explicitly retires all data-bound cells and counters")
		state.configure(source_model(2));pane.set_context(state.view(),false,text,art,[311,1]);pane.open();pane.scale=Vector2(.65,.65);pane.position=Vector2(10,10);surface.size=Vector2i(640,400);await frames();await click(pane.buttons["available:0:arrow"])
		check(state.known[1]==[2,1] and not pane.buttons.okbutton.disabled and pane.remaining.text=="4","Scaled actual input permits original OK when the available pool is exhausted with spare budget")
		await click(pane.buttons.okbutton);check(results==[[true,[311,1]]] and not pane.wanted,"Original OK returns the accepted scope exactly once")
		pane.set_context(state.view(),false,text,art,[312,1]);pane.open();await frames();await key_spell(KEY_ESCAPE);check(results[-1]==[false,[312,1]],"Spell chooser Escape cancels only its active lifetime")
		var damaged: Dictionary=pane.models.duplicate();damaged.erase("ctl_cg_btn_feat");check(not str(preload("res://systems/native_data/creation_spells_layout.gd").parse(pane.source,damaged).error).is_empty(),"Missing original spell row helper is explicit")
	pane.close();check(art.bindings.values().all(func(name):return not str(name).begins_with("sp_fixture_")),"Close retires every active spell icon binding");pane.free();check(painter.button_geometry.is_empty() and painter.decorated.is_empty(),"Final deletion retires pooled rows, nested helpers and source metadata");painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"handlerPairMs":samples,"actionPhases":phases,"pooledRows":pool_count,"scope":"Installed CG_SPELLS/CSpellInfoPanel layouts, physical tabs/arrows/help/OK/Escape, original pure policy books,1024-definition bounded controls, input/scoping/cleanup and synchronous handler samples. Controlled art/fonts; no actual creator draft/controller, Recommended, original pixels, server or level-up acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
