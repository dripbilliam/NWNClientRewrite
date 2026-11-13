extends "res://tests/native_creation_feat_binding_test.gd"
const SchoolState=preload("res://systems/native_data/creation_school_state.gd")
const PostFlow=preload("res://systems/native_data/creation_post_feats.gd")
func coherent_row(table: Dictionary,index: int,values: Dictionary) -> Dictionary:
	return preload("res://tests/native_creation_fixture_tables.gd").row_update(table,index,values)
func school_rules(creator,ui) -> void:
	install_rules(creator,ui)
	var fields:={"PickDomains":"0","PickSchool":"1","SpellbookRestricted":"1","SkipSpellSelection":"1","Arcane":"1","MinAssociateLevel":"255","MemorizesSpells":"1","LearnScroll":"1","SpellCaster":"1","SpellcastingAbil":"INT","SpellGainTable":"fixture_spellgain"}
	creator.rules.tables.classes=coherent_row(creator.rules.tables.classes,0,fields)
	var adjustments: Dictionary={}
	for key in ["Str","Dex","Con","Int","Wis","Cha"]:adjustments[key+"Adjust"]="0"
	creator.rules.tables.racialtypes=coherent_row(creator.rules.tables.racialtypes,0,adjustments)
	creator.rules.tables.fixture_spellgain={"orderedRows":[{"NumSpellLevels":"2","SpellLevel0":"3","SpellLevel1":"1"}]}
	creator.rules.tables.spellschools={"orderedRows":[]}
	for id in 12:
		creator.rules.tables.spellschools.orderedRows.append({"StringRef":str(9000+id),"Description":str(9100+id)})
		ui.text.overrides[9000+id]="Server school "+str(id);ui.text.overrides[9100+id]="Server school help "+str(id)
	creator.rules.tables.packages={"orderedRows":[{"ClassID":"0","PlayerClass":"1","Name":"0","School":"2"}]}
	creator.rules.draft.abilities.Int=14;creator.rules.draft.school=0;ui.text.revision+=1;creator.render()
func enter_school(creator) -> bool:
	var front=creator.source_frontend
	front.flow.enabled.packages=true;front.refresh();await click(front.main.buttons.packagesbutton);await click(front.packages.buttons.configurepckg)
	if not check(await wait_for(func():return front.child=="package-configuration" and front.skills.wanted,10),"Actual Package Configure transfers into Skills"):return false
	await click(front.skills.buttons.okbutton)
	if not check(front.child=="package-feats" and front.feats.wanted,"Actual Skills OK opens original Feats"):return false
	await choose_feat(front.feats,0);await choose_feat(front.feats,2);await click(front.feats.buttons.okbutton)
	return await wait_for(func():return front.child=="package-school" and front.school.wanted and front.school.layout_ready,10)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original catalogs mount read-only")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(base.get_resource("cg_school",2047))=="e8a39577f48a35ab4c71fb04c07e2bff41593d1930a02d0f970dcddf156b43af","Original School GFF hierarchy is pinned")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(300)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.school.layout_ready,50),"Real creator and School workers prepare",creator.resource_errors):
		school_rules(creator,ui)
		var source:=PostFlow.creation_source(creator.rules);check(source.get("PickSchool")==1 and source.get("PickDomains")==0 and source.get("MinAssociateLevel")==255,"Active physical class metadata drives the custom first-level continuation",source)
		var front=creator.source_frontend;var pane=front.school;var identity: Array=creator.summary_identity();front.begin(identity,{"classBase":0},creator.rules.rows("classes"))
		if check(await enter_school(creator),"The real Package→Skills→Feats chain reaches original School"):
			check(front.flow.completed.packages and creator.source_post.stage==2 and not front.main.visible,"Original800e callback updates Package behind its still-active School modal")
			check(pane.state.selected==0 and pane.help.current.slice(1)==[381,381] and int(creator.rules.draft.school)==0,"Initial General selection retains original introductory help without committing")
			creator.rules.draft.known={0:[55]};creator.rules.draft.memorized={0:[55]};var feats: Array=creator.rules.draft.feats.duplicate(true)
			await click(pane.buttons.necromancy)
			check(pane.state.selected==7 and pane.help.title.text=="Server school 7" and pane.help.body.get_parsed_text()=="Server school help 7" and int(creator.rules.draft.school)==0,"Physical school tabs use active server help and leave the actor uncommitted")
			await click(pane.buttons.recommendbutton);check(pane.state.selected==2 and pane.help.title.text=="Server school 2","Recommended reads active package School rather than a stock preset")
			var ticket: Array=front.ticket.duplicate();pane.capture("illusion");ui.text.overrides[9102]="Changed server school help";ui.text.revision+=1;creator.refresh_source();pane.invoke("illusion")
			check(front.ticket!=ticket and pane.state.selected==2 and pane.help.body.get_parsed_text()=="Changed server school help","Text replacement retires held input while retaining current uncommitted school/help")
			await click(pane.buttons.okbutton)
			check(front.child.is_empty() and front.main.visible and not pane.wanted and int(creator.rules.draft.school)==2 and creator.rules.draft.feats==feats,"School OK commits its byte and returns to Main when active class rules skip later children")
			check(creator.rules.draft.known.is_empty() and creator.rules.draft.memorized.is_empty() and creator.rules.spell_slots(1)==2 and creator.source_post.stage==0,"School clears spells and preserves the original old-school slot reset ordering")
			check(front.flow.completed.packages and front.flow.enabled.customize,"Original post-school callback preserves prior Package completion and unlocks customization")
			if check(await enter_school(creator),"The original Package chain is reusable after School acceptance"):
				await click(pane.buttons.evocation);await key(KEY_ESCAPE)
				check(front.child.is_empty() and not front.flow.completed.packages and creator.rules.draft.feats.is_empty() and creator.rules.draft.skills.is_empty() and int(creator.rules.draft.school)==2 and creator.source_post.stage==0,"School Escape returns3, reverses Package progress and clears derived choices without inventing a school reset")
				front.open_child("package-school");await frames();var old_scope:=identity.duplicate();creator.draft_scope+=1;var before:=JSON.stringify(creator.rules.draft)
				check(creator.commit_source_school(true,8,old_scope).is_empty() and JSON.stringify(creator.rules.draft)==before,"A retired draft cannot commit a school")
				front.dismiss()
	check(not sent.any(func(message):return message.get("kind","")=="native-creation-submit"),"Source interaction never fabricates a network character upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"gpu":false,"sourceArtworkDouble":true,"scope":"Actual Gameplay/creator/original Package-Skills-Feats-School physical controls with coherent active custom tables, help, Recommended, callback transfer, spell-cache order, Cancel/Escape and stale draft. Headless artwork doubles, no original pixels/server upload acceptance; unported Domain/Spells/Associate children remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
