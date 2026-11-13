extends "res://tests/native_creation_feat_binding_test.gd"
func package_fixture(creator,ui,arcane: int) -> void:
	install_rules(creator,ui)
	creator.rules.tables.classes=preload("res://tests/native_creation_fixture_tables.gd").row_update(creator.rules.tables.classes,0,{"Arcane":str(arcane),"MinAssociateLevel":"1","Package":"2"})
	creator.rules.tables.packages={"orderedRows":[{"ClassID":"0","PlayerClass":"0"},{"ClassID":"0","PlayerClass":"0"},{"ClassID":"0","PlayerClass":"1","Name":"52000","Description":"52001","Associate":"2"}]}
	ui.text.overrides[52000]="Active recommended package";ui.text.overrides[52001]="Active package description";ui.text.revision+=1
	creator.rules.draft.familiarName="Previous Familiar";creator.rules.draft.companionName="Previous Companion";creator.render()
func open_package(creator) -> bool:
	var front=creator.source_frontend
	if not front.wanted:front.begin(creator.summary_identity(),{"classBase":0},creator.rules.rows("classes"))
	front.flow.enabled.packages=true;front.refresh();await click(front.main.buttons.packagesbutton)
	return front.child=="packagesbutton" and front.packages.layout_ready
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Independent original UI and active creation catalogs mount read-only")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(741)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.packages.layout_ready,20),"Actual source Main/Package prepare",creator.resource_errors):
		var front=creator.source_frontend;var pane=front.packages
		package_fixture(creator,ui,1)
		if check(await open_package(creator),"Physical Package entry opens current sparse active choices"):
			check(pane.state.entries.map(func(entry):return int(entry.id))==[2],"Recommended package preserves its active physical row rather than a stock package ID")
			await click(pane.buttons.recommendbutton);await click(pane.buttons.okbutton)
			check(await wait_for(func():return creator.phase=="editing" and front.child.is_empty(),15),"Automatic package waits for its real asynchronous name before completing8008",creator.status)
			check(creator.rules.draft.familiar==2 and creator.rules.draft.familiarName!="Previous Familiar" and not str(creator.rules.draft.familiarName).is_empty() and creator.rules.draft.companionName=="Previous Companion" and not creator.rules.draft.get("packageAssociateNamePending",false),"Original familiar name generation completes before Package acceptance without overwriting the other namespace")
			if is_instance_valid(creator.get("package_names")):
				check(int(creator.package_names.names.diagnostics.get("generationWorkerThread",-1))!=OS.get_main_thread_id(),"Automatic package name uses the actual native generation worker")
		package_fixture(creator,ui,0)
		if check(await open_package(creator),"Source Package reopens for the non-arcane active class"):
			await click(pane.buttons.okbutton);await wait_for(func():return creator.phase=="editing" and front.child.is_empty(),15)
			check(creator.rules.draft.companion==2 and creator.rules.draft.companionName!="Previous Companion" and creator.rules.draft.familiarName=="Previous Familiar" and not creator.rules.draft.get("packageAssociateNamePending",false),"Non-arcane Recommended writes only the companion type/name through the same original generator")
		package_fixture(creator,ui,1)
		if check(await open_package(creator),"Source Package reopens for Configure"):
			await click(pane.buttons.configurepckg)
			check(await wait_for(func():return front.child=="package-configuration" and front.skills.wanted,10) and creator.rules.draft.familiarName=="Previous Familiar" and creator.rules.draft.companionName=="Previous Companion" and not creator.rules.draft.get("packageAssociateNamePending",false),"Configure transfers to actual Skills without running automatic pet naming")
			await click(front.skills.buttons.cancelbutton)
		if check(await open_package(creator),"Source Package opens for cancellation while active data preparation is pending"):
			creator.jobs[-741]={"kind":"authored-io-barrier"};await click(pane.buttons.okbutton)
			check(creator.phase=="package-preparing" and pane.busy and not pane.buttons.cancelbutton.disabled,"Real pending preparation keeps Cancel available while duplicate actions are disabled")
			await key(KEY_ESCAPE);creator.jobs.erase(-741);await frames(5)
			check(creator.phase=="editing" and front.child.is_empty() and not front.flow.completed.packages and creator.rules.draft.familiarName=="Previous Familiar","Escape retires the pending package request; late work cannot assign or complete it")
		if check(await open_package(creator),"Source Package reopens for actual name-worker cancellation"):
			pane.capture("okbutton");pane.invoke("okbutton")
			check(creator.phase=="package-preparing" and is_instance_valid(creator.package_names) and not creator.package_names.names.resources_ready and pane.help_body.get_parsed_text().contains("name"),"Actual asynchronous name-resource preparation exposes progress in the original help scroll")
			var request: int=creator.package_request
			var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;surface.push_input(event,true)
			check(creator.phase=="editing" and creator.package_request==request+1 and front.child.is_empty() and creator.package_names.identity.is_empty(),"Typed Escape retires the actual name invocation before its delayed worker can publish")
			await wait_for(func():return creator.package_names.names.jobs.is_empty() and creator.package_names.names.assets.running.is_empty(),5);await frames()
			check(creator.rules.draft.familiarName=="Previous Familiar" and not front.flow.completed.packages,"Completed retired name work cannot alter the draft or finish Package")
		if check(await open_package(creator),"Source Package reopens for a real missing-LTR capture"):
			var gap_dir:=str(args.report)+".missing-ltr";DirAccess.make_dir_recursive_absolute(gap_dir)
			var gap_file:=FileAccess.open(gap_dir.path_join("manifest.json"),FileAccess.WRITE);gap_file.store_string(JSON.stringify({"version":2,"complete":true,"availability":{"familiar:2036":1},"resources":{}}));gap_file.close()
			var gap=preload("res://systems/native_data/recorded_catalog.gd").new();check(gap.mount(gap_dir),"Closed-world missing-LTR resource fixture mounts without invented optional-loader success")
			ui.catalog=gap;await click(pane.buttons.okbutton)
			check(await wait_for(func():return creator.phase=="editing" and front.child=="packagesbutton" and not pane.busy,10),"A real missing LTR returns to the current open Package instead of accepting a default name",creator.status)
			check(not creator.status.is_empty() and pane.help_body.get_parsed_text()==creator.status and not pane.buttons.cancelbutton.disabled and creator.rules.draft.familiarName=="Previous Familiar" and not front.flow.completed.packages,"Missing-resource reason is visible in the original help area with Cancel available and no accepted choice")
			ui.catalog=active;await click(pane.buttons.cancelbutton)
		if check(await open_package(creator),"The corrected active catalog can retry after a missing resource"):
			await click(pane.buttons.okbutton);await wait_for(func():return creator.phase=="editing" and front.child.is_empty(),10)
			check(front.flow.completed.packages and creator.rules.draft.familiarName!="Previous Familiar" and not creator.rules.draft.get("packageAssociateNamePending",false),"A fresh real generator invocation succeeds after reopening without reusing the failed resource result")
		creator.rules.draft.familiarName="Scope sentinel"
		if check(await open_package(creator),"Source Package reopens for active text lifetime replacement"):
			var completed_before: bool=front.flow.completed.packages
			pane.capture("okbutton");pane.invoke("okbutton");ui.text.revision+=1
			check(await wait_for(func():return creator.phase=="editing" and not pane.busy,10) and front.child=="packagesbutton" and creator.rules.draft.familiarName=="Scope sentinel","A text revision during real name preparation cannot apply a stale name or8008",{"phase":creator.phase,"child":front.child,"name":creator.rules.draft.familiarName,"completed":front.flow.completed.packages,"priorCompleted":completed_before,"error":creator.status})
			check(front.flow.completed.packages==completed_before,"A rejected reopened request preserves the original parent's prior completion flag while its current child stays open")
			check(pane.help_body.get_parsed_text().contains("changed"),"Rejected stale package preparation gives visible retry feedback")
			await click(pane.buttons.cancelbutton)
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Focused package controls never fabricate a character upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Actual source Main/Package/Skills control input with authored active sparse package/class metadata and installed LTR/filter worker. Automatic familiar/companion naming, Configure distinction and pending cancellation. Controlled art/fonts; no complete creation BIC/server or original pixel acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
