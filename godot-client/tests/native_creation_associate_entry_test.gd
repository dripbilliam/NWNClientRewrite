extends "res://tests/native_creation_gender_test.gd"
func write_table(path: String,value: Dictionary) -> void:
	var content:="2DA V2.0\nDEFAULT: "+str(value.get("defaultValue","****"))+"\n"+" ".join(value.columns)+"\n"
	for index in value.orderedRows.size():content+=str(value.rowLabels[index])+" "+" ".join(value.orderedCells[index])+"\n"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(content);file.close()
func find_class(table: Dictionary,label: String) -> int:
	for id in table.orderedRows.size():
		if str(preload("res://systems/native_data/game_ui_rules.gd").cell(table.orderedRows[id],"Label","")).to_lower()==label:return id
	return -1
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original and active catalogs mount read-only")
	var raw_classes:=preload("res://systems/native_data/two_da.gd").new().parse(base.get_resource("classes",2017).get_string_from_utf8());var wizard:=find_class(raw_classes,"wizard");var druid:=find_class(raw_classes,"druid")
	check(wizard>=0 and druid>=0,"Physical class IDs come from actual active class metadata")
	var fixtures:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(fixtures)
	var custom: Dictionary=preload("res://tests/native_creation_fixture_tables.gd").row_update(raw_classes,wizard,{"Arcane":"2","PickSchool":"0","PickDomains":"0","SpellbookRestricted":"0","MinAssociateLevel":"1"});write_table(fixtures.path_join("classes.2da"),custom)
	var templates: Array=base.resource_names(2027).filter(func(name):return str(name).begins_with("nw_ac"));templates.sort();check(not templates.is_empty(),"An actual installed UTC supplies the sparse active pet preview")
	if templates.is_empty():quit(1);return
	var file:=FileAccess.open(fixtures.path_join("scope_pet_01.utc"),FileAccess.WRITE);file.store_buffer(base.get_resource(str(templates[0]),2027));file.close()
	file=FileAccess.open(fixtures.path_join("hen_familiar.2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSTRREF BASERESREF DESCRIPTION\n0 **** **** ****\n1 **** **** ****\n2 69000 scope_pet_ 69001\n");file.close()
	check(active.mount_directory(fixtures,100000001),"Sparse active familiar rows and original UTC mount as real resources")
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	ui.text.overrides[69000]="Active sparse familiar";ui.text.overrides[69001]="Active familiar information";ui.text.mark_changed()
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(752)
	var actions: Array=[]
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready,20),"Actual source Creator initializes"):
		var front=creator.source_frontend;var pane=front.associate
		pane.action_requested.connect(func(operation,value,identity):
			actions.append({"operation":operation,"value":value.duplicate(true),"scope":identity.duplicate()})
			if operation=="generate":creator.refresh_source())
		check(creator.commit_source_class(wizard,creator.summary_identity()).get("accepted",false) and creator.rules.num(creator.rules.cls(),"Arcane")==1,"Actual raw Arcane2 publication normalizes through the native private class compiler")
		creator.refresh_source();await frames()
		check(not pane.started and creator.rules.draft.familiar== -1 and creator.rules.draft.familiarName.is_empty() and actions.is_empty(),"Background class binding neither starts the lazy child nor applies entry/type/name effects")
		front.open_child("package-post-skills",0x800e)
		check(front.child=="package-associate" and pane.wanted,"The actual class-dependent post coordinator opens the lazy source child")
		if check(await wait_for(func():return pane.layout_ready and pane.state.ready and not pane.generating and not pane.state.current_name.is_empty(),15),"First lazy preparation automatically generates through real native LTR/filter workers"):
			var name: String=pane.state.current_name;var ticket: Array=front.ticket.duplicate()
			check(pane.state.arcane==1 and pane.state.entries.map(func(row):return int(row.id))==[2] and pane.state.selected==0 and pane.state.preview().physicalId==2,"Native visible index0 maps through sparse active row IDs to the actual physical2 preview")
			check(creator.rules.draft.familiar==0 and creator.rules.draft.familiarName==name and creator.rules.draft.companion== -1,"Original raw -1→0 preparation effect stays separate from mapped physical selection and other namespace")
			check(int(creator.associate_names.diagnostics.get("generationWorkerThread",-1))!=OS.get_main_thread_id(),"Initial empty name uses the actual asynchronous native generation worker")
			check(actions.filter(func(row):return row.operation=="enter" and row.scope==ticket).size()==1 and actions.filter(func(row):return row.operation=="generate" and row.scope==ticket).size()==1,"Lazy show plus reentrant current-source publication emits exactly one entry/generation")
			pane.source_prepared();pane.open();await frames(4)
			check(actions.filter(func(row):return row.operation=="enter" and row.scope==ticket).size()==1 and actions.filter(func(row):return row.operation=="generate" and row.scope==ticket).size()==1,"Duplicate readiness/open does not regenerate a completed current entry")
			await click(pane.buttons.cancelbutton)
			check(front.child.is_empty() and creator.rules.draft.familiar==0 and creator.rules.draft.familiarName==name,"Original Cancel preserves already-observed private preparation type/name effects")
			front.open_child("package-post-skills",0x800e);await frames(4);await click(pane.buttons.okbutton)
			check(front.child.is_empty() and creator.rules.draft.familiar==2 and creator.rules.draft.familiarName==name,"Original OK stores the mapped physical row2 rather than raw initial type0 or a display index")
		creator.cancel();creator.open(753)
		if check(await wait_for(func():return creator.phase=="editing",15),"A new actual creation draft initializes for companion entry"):
			check(creator.commit_source_class(druid,creator.summary_identity()).get("accepted",false) and creator.rules.draft.companion== -1 and creator.rules.draft.companionName.is_empty(),"Druid binding preserves original unset companion until real entry")
			front.open_child("package-post-skills",0x800e)
			check(front.child=="package-associate" and pane.layout_ready and pane.generating and creator.rules.draft.companion==0,"Warm real companion entry applies raw0 and begins empty-name generation")
			var old_ticket: Array=front.ticket.duplicate();var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;surface.push_input(event,true);await frames(4)
			check(front.child.is_empty() and creator.rules.draft.companion==0 and creator.rules.draft.companionName.is_empty(),"Typed Escape during asynchronous name preparation retires the child without fabricating a late name")
			check(not creator.associate_request_current({"identity":creator.summary_identity(),"ticket":old_ticket,"value":{}}),"A retired companion entry cannot admit its delayed request")
			front.open_child("package-post-skills",0x800e)
			check(await wait_for(func():return pane.state.ready and not pane.generating and not pane.state.current_name.is_empty(),15),"Reopened companion entry can complete its fresh actual name request")
			check(creator.rules.draft.familiar== -1 and creator.rules.draft.familiarName.is_empty() and creator.rules.draft.companion==0 and creator.rules.draft.companionName==pane.state.current_name,"Companion preparation respects the current constructor namespace and fresh name owner")
			await click(pane.buttons.cancelbutton)
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Entry effects and input never fabricate an upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Actual class-dependent source Associate entry, first lazy asset preparation, real LTR/filter name worker, original raw0 versus sparse physical row mapping, reentrant/duplicate preparation, manual OK/Cancel, pending-name Escape/reopen and namespaces. Authored active2DA backed by real installed UTC, controlled art/fonts; no server/BIC/pixel or complete class flow acceptance."}
	file=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
