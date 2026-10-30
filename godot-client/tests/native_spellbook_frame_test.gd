extends "res://tests/native_quickbar_frame_test.gd"
var skin
func wait_until(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+15000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func book_settled(ui) -> bool:
	if not skin.layout_ready or not settled(ui): return false
	for bar in skin.bars:
		if not bar.art_ready or bar.snapshot().layout_pending or bar.snapshot().thumb_pending: return false
	return true
func find_entry(book,spell: int,mask: int=0,memory: bool=false) -> Dictionary:
	for row in book.state.memory if memory else book.state.known:
		if int(row.spellId)==spell and int(row.metamagic)==mask: return row
	return {}
func preparation_checks(_ui,_output: String,_actor: Dictionary,_header: Dictionary,_spells: Dictionary) -> Dictionary: return {}
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1500,900); surface=SubViewport.new(); surface.size=root.size; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; surface.gui_disable_input=false; surface.handle_input_locally=true; root.add_child(surface); surface.notify_mouse_entered()
	var display:=TextureRect.new(); root.add_child(display); display.texture=surface.get_texture(); display.size=root.size; display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original installed spellbook corpus mounts read-only")
	var ui:=Gameplay.new(); surface.add_child(ui); ui.configure(catalog,install,ProjectSettings.globalize_path("user://native-prepared-v2"),output+".layout.cfg"); ui.request.connect(func(m):requests.append(m.duplicate(true)))
	check(await wait_until(func():return ui.tables_ready and ui.inventory.frame_skin.fonts!=null),"Active original spells/classes/feats/ruleset/TLK owners prepare")
	var desktop=ui.desktop; var book=desktop.book; skin=desktop.book_frame
	check(not skin.requested,"Closed spellbook does not schedule model work")
	var spells: Dictionary={}; var known: Array=[]; var family:=-1
	for id in ui.text.tables.spells.orderedRows.size():
		var level: int=desktop.rules.spell_level(id,10)
		if level<=3:
			known.append(id)
			if not spells.has(level) and (level!=1 or (desktop.rules.number(desktop.rules.cell(desktop.rules.row("spells",id),"MetaMagic"),0)&1)!=0): spells[level]=id
			if family<0 and not desktop.rules.spell_children(id).is_empty(): family=id
	check(spells.has(0) and spells.has(1) and spells.has(2) and spells.has(3) and family>=0,"Fixture discovers owned spell levels and a real family from active rules")
	if spells.size()<4 or family<0:
		print("Fixture diagnostic ",spells," family=",family); ui.close(); ui.free(); quit(2); return
	known=spells.values(); if not known.has(family): known.append(family)
	var slots: Array=[]
	for at in 19: slots.append({"spell":int(spells[3]) if at<2 else -1,"ready":at==0,"metamagic":0})
	var actor:={"id":42,"objectType":5,"areaId":55,"replicated":{"name":{"text":"Spellbook test"},"position":[0,0,0],"hitPoints":{"current":10,"maximum":15},"stats":{"racialType":6,"classes":[{"id":10,"level":10},{"id":2,"level":10}]}},"playerState":{"feats":[11,12],"spellbooks":{"0":{"known":known,"memorized":{"0":[{"spell":int(spells[0]),"ready":true}],"1":[{"spell":-1,"ready":false}],"3":slots}},"1":{"known":[],"memorized":{}}}}}
	var baseline:=actor.duplicate(true); var header:={"area":{"id":55},"ui":{"quickbar":[]}}
	ui.inventory.frame_skin.art.models.assets.maximum_pending=2
	ui.set_world(1,55,42,[actor],{},header); desktop.book_level=3; desktop.panel("spells")
	check(await wait_until(func():return skin.layout_ready or not skin.failure.is_empty()),"Original programmatic spellbook models finish bounded preparation")
	var diagnostic: Dictionary={"failure":skin.failure}
	if skin.layout_ready and skin.failure.is_empty():
		var ready:=await wait_until(func():return book_settled(ui))
		check(ready,"Original tab/row/scrollbar poses, icons and fonts publish")
		if not ready:
			var bars: Array=[]
			for bar in skin.bars: bars.append(bar.snapshot())
			print("READINESS ",JSON.stringify({"bars":bars,"art":ui.inventory.frame_skin.art.models.snapshot(),"desktop_art":desktop.art.models.snapshot(),"fonts":ui.inventory.frame_skin.fonts.fonts.keys()}))
			ui.close(); ui.free(); await process_frame; await process_frame
			var failed_file:=FileAccess.open(output,FileAccess.WRITE); failed_file.store_string(JSON.stringify({"success":false,"checks":checks,"failures":failures,"diagnostic":{"bars":bars}})); failed_file.close(); quit(1); return
		book.position=Vector2(30,50); skin.memory.position=Vector2(410,50)
		var preparation_diagnostic: Dictionary=await preparation_checks(ui,output,actor,header,spells)
		check(book.size==Vector2(360,471) and skin.memory.size==Vector2(360,471),"Main and separate memorization windows retain original360x471 extents")
		check(not book.window_column.visible and skin.class_tabs.size()==8 and skin.level_tabs.size()==10,"Generic controls are replaced by eight class and ten level icon tabs")
		check(skin.memory.visible and book.state.groups.size()==3 and book.state.memoryGroups.size()==10,"Owned metamagic branches and every received prepared level remain available together")
		var handles: Dictionary={}; var keys: Dictionary={}
		for row in book.rows.values(): handles[row.entryId]=true; keys[row.key]=true
		check(handles.size()==book.rows.size() and keys.size()==book.rows.size(),"All known/metamagic/memorized entries own distinct private IDs and keys")
		var source:=find_entry(book,int(spells[1]),1); check(not source.is_empty() and source.level==3 and source.binding.metamagic==1,"Empowered lower-level spells carry their destination level and active mask")
		check(skin.leaves.has(int(find_entry(book,int(spells[3])).entryId)) and not skin.leaves.has(int(source.entryId)),"Normal root starts expanded and metamagic roots start collapsed")
		await click(skin.roots["known:0:3:1"].get_global_rect().get_center()); await wait_until(func():return book_settled(ui))
		source=find_entry(book,int(spells[1]),1)
		check(skin.expanded.get("0:3:1",false) and skin.leaves.has(int(source.entryId)),"Real root click expands an independent metamagic group")
		check(skin.leaves.has(int(find_entry(book,int(spells[3])).entryId)),"Expanding another root leaves normal entries expanded")
		var normal_key: String=ui.inventory.frame_skin.art.models.model_key("ctl_sb_btn_sptab","checkedup",{"gui_replace01":"IR_LEVEL3"})
		var other_key: String=ui.inventory.frame_skin.art.models.model_key("ctl_sb_btn_sptab","uncheckedup",{"gui_replace01":"IR_LEVEL2"})
		check(normal_key!=other_key and ui.inventory.frame_skin.art.textures.has(normal_key) and ui.inventory.frame_skin.art.textures.has(other_key),"Original icon overrides produce independently cached tab art")
		var slot0: Dictionary=book.state.memoryGroups[3].entries[0]; var slot9: Dictionary=book.state.memoryGroups[3].entries[9]
		check(absf(book.widgets[int(slot9.entryId)].position.y-book.widgets[int(slot0.entryId)].position.y-33)<1.1,"Tenth prepared cell wraps to a second original nine-column row")
		check(book.widgets[int(slot0.entryId)].image.size==Vector2(32,32) and book.widgets[int(slot0.entryId)].caption.visible==false,"Prepared cells preserve32px source icons without generic text stretching")
		var before: int=requests.size(); var destination: Dictionary=book.state.memoryGroups[3].entries[2]
		book.widgets[int(destination.entryId)]._drop_data(Vector2.ZERO,book.widgets[int(source.entryId)].payload)
		check(requests.size()==before+1 and requests.back().kind=="native-prepare" and requests.back().classIndex==0 and requests.back().level==3 and requests.back().slot==2 and requests.back().spellId==int(spells[1]) and requests.back().metamagic==1,"Known-to-memory drop routes source level/metamagic and received destination slot")
		check(actor==baseline,"Preparing only emits a proposal and leaves received authoritative data unchanged")
		before=requests.size(); destination=book.state.memoryGroups[1].entries[0]
		book.widgets[int(destination.entryId)]._drop_data(Vector2.ZERO,book.widgets[int(source.entryId)].payload)
		check(requests.size()==before,"Cross-level drop cannot prepare into an incompatible received slot")
		var selected: Dictionary=find_entry(book,int(spells[3])); var point: Vector2=book.widgets[int(selected.entryId)].get_global_rect().get_center()
		await click(point); check(book.selected_id==int(selected.entryId) and skin.extras[int(selected.entryId)].help.visible,"Actual leaf click selects its private entry and reveals contextual buttons")
		before=requests.size(); await click(skin.extras[int(selected.entryId)].prepare.get_global_rect().get_center())
		check(requests.size()==before+1 and requests.back().kind=="native-prepare" and requests.back().level==3 and requests.back().slot==3,"Native prepare arrow skips a pending empty slot at the clicked entry's level")
		await click(skin.extras[int(selected.entryId)].help.get_global_rect().get_center()); check(skin.help_window.visible and not book.details.get_parsed_text().is_empty(),"Native help button opens the active spell's original description")
		check(book.details.get_parsed_text()==ui.text.raw({"strRef":desktop.rules.number(desktop.rules.cell(desktop.rules.row("spells",int(selected.spellId)),"SpellDesc"))}),"Help resolves active SpellDesc rather than the absent generic Description column")
		check(skin.help_window.size==skin.definition.help.size and skin.definition.help.resource=="pnl_cg_spinfo" and skin.help_bar.failure.is_empty(),"Description uses the original CG_SPELLINFO geometry and scrollbar contract")
		check(await wait_until(func():return skin.help_icon.texture!=null) and skin.help_icon.size==Vector2(32,32) and skin.help_icon.position==skin.definition.help.icon-Vector2(16,16),"Original spell-info icon uses its separate source attachment without stretching")
		await shot(output,"-help")
		skin.help_window.hide(); before=requests.size(); await click(book.widgets[int(slot0.entryId)].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		check(skin.action_window.visible and requests.size()==before,"Right click opens explicit native-styled spell commands without accidentally casting")
		before=requests.size(); book.clear.pressed.emit()
		check(requests.size()==before+1 and requests.back().kind=="native-prepare" and requests.back().clear and requests.back().slot==0,"Explicit Clear action uses the selected received memorized slot")
		skin.action_window.hide(); skin.help_window.hide(); var saved: int=book.view_id; actor.playerState.combat={"armorClass":42}; ui.set_world(1,55,42,[actor],{},header)
		check(book.view_id==saved,"Unrelated combat updates do not rebuild or retire a spellbook drag")
		await click(skin.level_tabs[1].get_global_rect().get_center()); check(book.state.level==1 and skin.memory_expanded.get("0:1",false) and skin.memory_expanded.get("0:3",false),"Selecting a level opens it without collapsing another prepared level")
		await wait_until(func():return book_settled(ui)); await shot(output,"-prepared")
		desktop.book_level=desktop.rules.spell_level(family,10); desktop.refresh_book(); await wait_until(func():return book_settled(ui))
		var parent:=find_entry(book,family); book.select_entry(int(parent.entryId)); await wait_until(func():return book_settled(ui))
		check(skin.family.visible and not book.state.family.is_empty() and book.state.family.all(func(row):return row.canDrag and int(row.binding.intParam)==int(row.spellId)),"Parent spell opens active rules' distinct draggable child spells")
		var child: Dictionary=book.state.family[0]; var binding: Dictionary=child.binding.duplicate(true); before=requests.size(); desktop.quickbar.buttons[0]._drop_data(Vector2.ZERO,book.widgets[int(child.entryId)].payload)
		check(requests.size()==before+1 and requests.back().kind=="native-quickbar-assign" and requests.back().button==binding,"Family child drag assigns that exact child binding to the real quickbar route")
		var old_view: int=book.view_id; desktop.input_request({"kind":"book-family-back","viewId":old_view-1})
		check(book.view_id==old_view and skin.family.visible,"Retired family Back messages cannot change the current variant tree")
		skin.family.close_button.pressed.emit(); check(desktop.family_path.is_empty() and not skin.family.visible,"Closing variants clears the family path without closing the spellbook")
		await wait_until(func():return book_settled(ui)); await shot(output,"-family-closed")
		var world:=WorldInput.new(); surface.add_child(world); await click(Vector2(1100,550)); await key(KEY_W); await key(KEY_W,false); await click(Vector2(1100,550),MOUSE_BUTTON_MIDDLE)
		check(world.clicks==1 and world.movement==1 and world.middle==1,"Open spell windows preserve outside movement, WASD and middle camera input")
		var start: Vector2=skin.memory.position; var title_point: Vector2=skin.memory.heading.get_global_rect().get_center(); await motion(title_point); await mouse(title_point,true); await motion(title_point+Vector2(25,30),Vector2(25,30),true); await mouse(title_point+Vector2(25,30),false)
		check(skin.memory.position.distance_to(start+Vector2(25,30))<0.01,"Separate memorization window supports actual title dragging")
		var config:=ConfigFile.new(); config.load(output+".layout.cfg"); check(config.get_value("positions","spell-memorization",Vector2.ZERO)==skin.memory.position,"Memorization movement persists under its own menu key")
		skin.memory.close_button.pressed.emit(); check(not skin.memory.visible and book.visible,"Closing memorization leaves the main spellbook open")
		book.close_button.pressed.emit(); desktop.panel("spells"); check(book.visible and skin.memory.visible and skin.memory.position==start+Vector2(25,30),"Reopening restores the memorization window at its retained position")
		await click(skin.class_tabs[1].get_global_rect().get_center()); check(int(book.state.classIndex)==1 and book.state.memory.is_empty() and skin.memory.visible,"Second class tab selects the active class and never invents preparation slots")
		await click(skin.class_tabs[0].get_global_rect().get_center()); check(int(book.state.classIndex)==0 and book.state.memory.size()==21,"Switching class restores only its received slots across levels")
		ui.controls.scale=Vector2.ONE*1.25; await process_frame; await process_frame
		check(book.get_global_rect().size==Vector2(450,588.75) and skin.memory.get_global_rect().size==Vector2(450,588.75),"125percent UI scale preserves original window proportions")
		await shot(output,"-scaled"); ui.controls.scale=Vector2.ONE
		var stale: Button=skin.level_tabs[2]; var stale_slot: Button=book.widgets.values()[0]; before=requests.size(); book.reset(); stale.pressed.emit(); stale_slot.selected.emit(); stale_slot.activated.emit()
		check(requests.size()==before and not skin.memory.visible and not skin.family.visible and not skin.help_window.visible and not skin.action_window.visible,"Reset hides sibling windows and rejects retained tab/slot callbacks")
		check(int(ui.inventory.frame_skin.art.models.stats.get("model_backlog_peak",0))>2 and ui.inventory.frame_skin.art.models.deferred_models.is_empty(),"A GUI burst exceeding two worker slots drains without dropping tab or scrollbar art")
		var queued=preload("res://systems/native_item_icons.gd").new(); surface.add_child(queued); queued.configure(catalog,ProjectSettings.globalize_path("user://native-prepared-v2")); queued.assets.maximum_pending=1
		for at in 32: queued.request_model("scrollbar_simple","",{},0,"gui_scrollbar",[{"clip":"size","time":0.1+float(at)/100}])
		check(queued.deferred_models.size()==31 and queued.pending.size()==32,"Deferred GUI ownership remains explicit under one-slot worker pressure")
		queued.close(); check(queued.deferred_models.is_empty() and queued.pending.is_empty() and queued.requests.is_empty(),"Retiring GUI preparation clears queued and dispatched ownership without late publication"); queued.free()
		diagnostic=skin.snapshot(); diagnostic.preparation=preparation_diagnostic; diagnostic.physicalMouseWarped=false; diagnostic.art_failures=ui.inventory.frame_skin.art.failed.keys(); check(diagnostic.art_failures.is_empty(),"Original GUI poses and texture replacements have no missing-art failures")
	else: check(false,"Native spellbook activates without fallback")
	ui.close(); ui.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostic":diagnostic,"requests":requests,"publicConnections":0,"fullSpellbookParity":false,"scope":"Original layout/art plus isolated native input and original-compatible request proposals. Real server outcomes tested separately; exact help modal, gestures/states and original-client comparison remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
