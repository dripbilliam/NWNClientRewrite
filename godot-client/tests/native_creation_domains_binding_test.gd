extends "res://tests/native_creation_school_binding_test.gd"
func domain_rules(creator,ui) -> void:
	school_rules(creator,ui)
	creator.rules.tables.classes=coherent_row(creator.rules.tables.classes,0,{"PickDomains":"1"})
	creator.rules.tables.domains={"orderedRows":[]}
	for id in 6:
		creator.rules.tables.domains.orderedRows.append({"Name":str(9200+id),"Description":str(9300+id),"GrantedFeat":"8" if id==3 else "4","Icon":"id_test_"+str(id)})
		ui.text.overrides[9200+id]="Server domain "+str(id);ui.text.overrides[9300+id]="Server domain help "+str(id)
	creator.rules.tables.packages=coherent_row(creator.rules.tables.packages,0,{"Domain1":"3","Domain2":"0"});ui.text.revision+=1;creator.render()
func enter_domains(creator) -> bool:
	var front=creator.source_frontend
	front.flow.enabled.packages=true;front.refresh();await click(front.main.buttons.packagesbutton);await click(front.packages.buttons.configurepckg)
	if not check(await wait_for(func():return front.child=="package-configuration" and front.skills.wanted,10),"Actual Package Configure transfers into Skills before Domains"):return false
	await click(front.skills.buttons.okbutton)
	if not check(front.child=="package-feats" and front.feats.wanted,"Actual Skills OK opens Feats before Domains"):return false
	await choose_feat(front.feats,0);await choose_feat(front.feats,2);await click(front.feats.buttons.okbutton)
	return await wait_for(func():return front.child=="package-domains" and front.domains.wanted and front.domains.layout_ready,15)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original native catalogs mount read-only")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(302)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.feats.layout_ready and creator.source_frontend.school.layout_ready,50),"Real creator source children prepare",creator.resource_errors):
		domain_rules(creator,ui)
		var front=creator.source_frontend;var pane=front.domains;var identity: Array=creator.summary_identity();front.begin(identity,{"classBase":0},creator.rules.rows("classes"))
		check(not pane.started,"Unused class-dependent Domain resources are not started during ordinary picker setup")
		if check(await enter_domains(creator),"Actual Package→Skills→Feats chain reaches the class-data-driven Domain child"):
			check(front.flow.completed.packages and creator.source_post.stage==1 and creator.rules.draft.domains.is_empty(),"Original800e parent callback and Domain-stage cursor preserve an uncommitted draft")
			await click(pane.buttons["domain:5"]);check(pane.help_title.text=="Server domain 5" and pane.help_body.get_parsed_text()=="Server domain help 5","Actual Domain row uses active server help")
			await click(pane.buttons["domain:5:add"]);await click(pane.buttons["domain:2:add"]);check(creator.rules.draft.domains.is_empty() and pane.state.chosen==[5,2],"Physical Domain arrows edit only temporary choices")
			await click(pane.buttons.recommendbutton);check(pane.state.chosen==[3,0],"Original Recommended reads the selected package's active physical domain IDs")
			pane.capture("domain:3:remove");var old_ticket: Array=front.ticket.duplicate();ui.text.overrides[9303]="Changed server domain help";ui.text.revision+=1;creator.refresh_source();pane.invoke("domain:3:remove")
			check(front.ticket!=old_ticket and pane.state.chosen==[3,0] and pane.help_body.get_parsed_text()=="Changed server domain help","Text reticket retires held input while preserving candidate and refreshing active domain help")
			await click(pane.buttons.okbutton)
			check(front.child=="package-school" and front.school.wanted and creator.rules.draft.domains==[3,0] and creator.source_post.stage==2,"Domain OK commits physical IDs and transfers8013 through the real coordinator into School")
			check(creator.rules.granted_feats().has(8) and creator.rules.draft.feats.map(func(item):return int(item.id))==[0,2],"Domain grant is derived by the existing feat owner without duplicating editable feat choices")
			await click(front.school.buttons.okbutton);check(front.child.is_empty() and front.main.visible and front.flow.completed.packages,"The complete configured Domain→School sequence finishes at the original parent")
			if check(await enter_domains(creator),"The actual Package chain can reopen Domains after acceptance"):
				await click(pane.buttons["domain:1:add"]);await key(KEY_ESCAPE)
				check(front.child.is_empty() and not front.flow.completed.packages and creator.rules.draft.domains.is_empty() and creator.rules.draft.feats.is_empty() and creator.source_post.stage==0,"Domain Escape reverses Package progress and clears derived choices through its real draft owner")
				front.open_child("package-domains");await frames();var before:=JSON.stringify(creator.rules.draft);var old_identity:=identity.duplicate();creator.draft_scope+=1
				check(creator.commit_source_domains(true,[0,3],old_identity).is_empty() and JSON.stringify(creator.rules.draft)==before,"Retired draft cannot commit Domain IDs")
				front.dismiss()
	check(not sent.any(func(message):return message.get("kind","")=="native-creation-submit"),"Source Domain interaction does not fabricate a network character upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native Gameplay/creator/frontend Package-Skills-Feats-Domain-School physical controls, active class/domain/package/help data, commits/grants, callback and cancellation/stale lifetimes. Controlled art/fonts, no original pixels, level-up, server upload or full creation-chain acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
