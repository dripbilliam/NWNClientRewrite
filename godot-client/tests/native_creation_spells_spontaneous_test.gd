extends "res://tests/native_creation_spells_binding_test.gd"
# Exercise the separate non-memorizing first-level encoder with a completed
# actual source transaction, not a source-marker-only draft or fake validator.
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original catalogs mount read-only")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(402)
	var worker_ran:=false;var bytes_size:=0
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.school.layout_ready,50),"Actual creator source workers prepare",creator.resource_errors):
		spell_rules(creator,ui)
		# Custom active data deliberately separates LearnScroll from
		# MemorizesSpells, as the original chooser does; no stock class whitelist.
		creator.rules.tables.classes=coherent_row(creator.rules.tables.classes,0,{"MemorizesSpells":"0","SpellKnownTable":"fixture_known"})
		creator.rules.tables.fixture_known={"orderedRows":[{"SpellLevel0":"1","SpellLevel1":"2"}]}
		creator.render()
		var front=creator.source_frontend;front.begin(creator.summary_identity(),{"classBase":0},creator.rules.rows("classes"))
		if check(await enter_spells(creator),"Real Package→Skills→Feats→School enters non-memorizing Spells"):
			var pane=front.spells
			check(not creator.source_spells.state.source.memorizes and creator.source_spells.state.source.learnScroll and pane.model.remaining==2,"Active independent class flags use known capacity, not the scroll budget")
			await click(pane.buttons["available:0:arrow"]);await click(pane.buttons["available:0:arrow"])
			check(creator.rules.draft.known[0]==[0] and creator.rules.draft.known[1]==[1,4] and not pane.buttons.okbutton.disabled,"Actual source controls fill known capacities with physical spell IDs")
			await click(pane.buttons.okbutton)
			var errors: Array=creator.rules.errors()
			check(front.child.is_empty() and SpellValidation.verify(creator.rules,ui.text,creator.rules.creation_spell_selection).valid and errors.is_empty(),"Non-memorizing source commit passes real transcript and complete save validation",errors)
			if errors.is_empty():
				creator.phase="preparing";creator.begin_build();worker_ran=true
				check(await wait_for(func():return creator.build_task<0 and creator.phase in ["waiting","editing"],20),"Actual non-memorizing BIC worker finishes")
				var submissions: Array=sent.filter(func(message):return message.get("kind","")=="native-creation-submit")
				check(creator.phase=="waiting" and submissions.size()==1,"Real worker emits one scoped submit intent",creator.status)
				if submissions.size()==1:
					var bytes:=Marshalls.base64_to_raw(str(submissions[0].data));bytes_size=bytes.size();var parser=preload("res://systems/native_data/gff_document.gd").new();var document:=parser.parse(bytes,"BIC ")
					check(parser.failure.is_empty(),"Worker output is a valid original BIC")
					if parser.failure.is_empty():
						var cls: Dictionary=document.root.ClassList[0]
						check(cls.KnownList0.map(func(row):return int(row.Spell))==[0] and cls.KnownList1.map(func(row):return int(row.Spell))==[1,4],"Non-memorizing BIC preserves exact selected known order")
						check(not cls.has("SpellsPerDayList") and range(10).all(func(level):return not cls.has("MemorizedList"+str(level))),"Source first-level BIC leaves spontaneous daily uses to the server and omits memorized lists")
						var output:=FileAccess.open(str(args.report)+".bic",FileAccess.WRITE);output.store_buffer(bytes);output.close()
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"workerRan":worker_ran,"bicBytes":bytes_size,"scope":"Actual native source Package-Skills-Feats-School-Spells non-memorizing custom class, physical known choices and validated real BIC worker output. No server upload/admission, original pixels, generic creator or full class/level-up acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
