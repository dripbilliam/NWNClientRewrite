extends "res://tests/native_creation_spells_binding_test.gd"
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture_dir:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(fixture_dir)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original catalogs mount read-only")
	var candidates: Array=base.resource_names(2027).filter(func(name):return str(name).begins_with("nw_ac"));candidates.sort()
	check(not candidates.is_empty(),"Installed native animal templates are available")
	if candidates.is_empty():quit(1);return
	var utc:=base.get_resource(str(candidates[0]),2027);var parser=preload("res://systems/native_data/gff_document.gd").new();var template: Dictionary=parser.parse(utc)
	check(parser.failure.is_empty() and template.type=="UTC ","Read-only installed associate template is a native UTC")
	var file:=FileAccess.open(fixture_dir.path_join("fix_assoc_01.utc"),FileAccess.WRITE);file.store_buffer(utc);file.close()
	file=FileAccess.open(fixture_dir.path_join("hen_companion.2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSTRREF BASERESREF DESCRIPTION\n0 61000 fix_assoc_ 61010\n1 **** **** ****\n2 61001 fix_assoc_ 61011\n");file.close()
	file=FileAccess.open(fixture_dir.path_join("fixture_sprefs.2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSpellIndex\n0 4\n1 1\n");file.close()
	check(active.mount_directory(fixture_dir,100000001),"Authored sparse active companion table and native UTC override mount")
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(601)
	var samples: Array=[];var bytes_size:=0
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.school.layout_ready,50),"Actual creator and original workers prepare",creator.resource_errors):
		spell_rules(creator,ui);creator.rules.tables.classes=coherent_row(creator.rules.tables.classes,0,{"Arcane":"2","MinAssociateLevel":"1"});ui.text.overrides[61000]="First active animal";ui.text.overrides[61001]="Second active animal";ui.text.overrides[61010]="Custom server animal help";ui.text.revision+=1;creator.render()
		var front=creator.source_frontend;front.begin(creator.summary_identity(),{"classBase":0},creator.rules.rows("classes"))
		if check(await enter_spells(creator),"Physical Package→Skills→Feats→School→Spells enters actual class chain"):
			await click(front.spells.buttons.recommendbutton);await click(front.spells.buttons.okbutton)
			if check(await wait_for(func():return creator.phase=="editing" and front.child=="package-associate" and front.associate.layout_ready and front.associate.state.ready,15),"Original continuation reaches actual Familiar/Companion controls",creator.resource_errors):
				var pane=front.associate
				check(pane.state.arcane==2 and pane.state.entries.map(func(row):return int(row.id))==[0,2] and pane.rows[1].label.text=="Second active animal","Real active table preserves raw Arcane and sparse physical rows")
				await click(pane.buttons["row:1"])
				check(await wait_for(func():return not pane.summary_identity.is_empty(),15),"Existing native asset worker loads the active UTC and original private-sheet projectors complete",creator.resource_errors)
				var template_name: String=ui.text.name(preload("res://systems/native_data/character_preview.gd").project(template.root),-1)
				check(not template_name.is_empty() and not template_name.contains("SpellFixture") and creator.associate_templates.has("fix_assoc_01") and pane.summary_view.labels.title.text.contains(template_name),"Private summary displays the selected native localized template identity rather than the player")
				await click(pane.buttons.gennamebutton)
				check(await wait_for(func():return not pane.generating and not pane.state.current_name.is_empty(),15),"Real native LTR/NameFilter workers generate a scoped associate name")
				var chosen_name: String=pane.state.current_name
				check(chosen_name==creator.rules.draft.familiarName and int(creator.associate_names.diagnostics.get("generationWorkerThread",-1))!=OS.get_thread_caller_id(),"Current generated name reaches the actual draft on a worker")
				pane.rows[0].helper.show();await click(pane.rows[0].helper)
				if check(await wait_for(func():return pane.info_popup.layout_ready,10),"Actual creator configures original associate help owner"):
					check(not pane.info_popup.modal_owner_ticket.is_empty() and pane.info_popup.description.get_parsed_text()=="Custom server animal help","Active help uses real explicit modal registration and server TLK")
					await click(pane.info_popup.buttons.okbutton)
				await click(pane.buttons["row:1"])
				var began:=Time.get_ticks_usec();pane.capture("okbutton");pane.invoke("okbutton");samples.append((Time.get_ticks_usec()-began)/1000.0)
				check(front.child.is_empty() and front.main.visible and front.flow.completed.packages and creator.rules.draft.familiar==2 and creator.rules.draft.companion==0 and creator.rules.draft.familiarName==chosen_name,"Original OK commits selected physical type/name and finishes the actual Package chain")
				check(samples.max()<50.0,"Actual associate commit avoids an obnoxious synchronous stall: "+str(samples))
				var errors: Array=creator.rules.errors();check(errors.is_empty(),"Actual completed draft passes save validation",errors)
				if errors.is_empty():
					creator.phase="preparing";creator.begin_build()
					check(await wait_for(func():return creator.build_task<0 and creator.phase in ["waiting","editing"],20),"Real native BIC worker completes")
					var submissions: Array=sent.filter(func(message):return message.get("kind")=="native-creation-submit")
					check(submissions.size()==1 and int(submissions[0].draft)==creator.draft_scope,"Submit intent carries exact draft identity")
					if submissions.size()==1:
						var bytes:=Marshalls.base64_to_raw(str(submissions[0].data));bytes_size=bytes.size();var bic: Dictionary=parser.parse(bytes,"BIC ")
						check(parser.failure.is_empty() and bic.root.FamiliarType==2 and bic.root.FamiliarName==chosen_name and bic.root.CompanionType==0,"Parsed real BIC preserves physical associate choice and actual generated name")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	file=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"commitMs":samples,"bicBytes":bytes_size,"template":str(candidates[0]),"scope":"Actual native creator Package/Skills/Feats/School/Spells/Associate control chain, active sparse2DA/TLK/UTC, actual asset+name+private stats workers, modal help, draft commit and parsed real BIC submit intent. Controlled art/fonts, authored overrides; no server upload/admission, original pixels or full creation/level-up acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
