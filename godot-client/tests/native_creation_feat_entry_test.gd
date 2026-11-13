extends "res://tests/native_creation_feat_binding_test.gd"
func has_available(pane,id: int) -> bool:
	return pane.model.get("available",[]).any(func(row):return not row.has("children") and int(row.id)==id)
func enter_skills(front) -> bool:
	front.flow.enabled.packages=true;front.refresh();await click(front.main.buttons.packagesbutton)
	if not check(await wait_for(func():return front.packages.layout_ready and front.child=="packagesbutton",10),"Actual Package opens before current Skills"):return false
	await click(front.packages.buttons.configurepckg)
	return check(await wait_for(func():return front.child=="package-configuration" and front.skills.layout_ready,10),"Actual Configure opens current native Skills")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original source resources mount read-only")
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(781)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.feats.layout_ready,20),"Actual creator/source Feats prepare"):
		install_rules(creator,ui)
		# The generic adapter's skill0 is deliberately usable, while installed
		# skill0 is Animal Empathy. Keep the controlled prerequisite available
		# to this controlled class through actual skill metadata, not a rank edit.
		creator.rules.tables.skills=preload("res://tests/native_creation_fixture_tables.gd").row_update(creator.rules.tables.skills,0,{"AllClassesCanUse":"1"});ui.text.revision+=1;creator.render()
		var front=creator.source_frontend;var identity: Array=creator.summary_identity();var state=creator.source_feats
		var warm: Dictionary=creator.feat_source_model(identity);var builds:=int(state.builds);var definitions: Variant=state._decoded.get("definitions");var entries: Variant=state._entries
		check(warm.ready and builds>0 and not warm.available.any(func(row):return not row.has("children") and int(row.id)==3),"Warm immutable definitions exclude actual feat3 before its rank1 prerequisite")
		if await enter_skills(front):
			await click(front.skills.buttons["up:0"])
			check(int(creator.rules.draft.skills.get(0,0))==1,"Physical native Skill0 up arrow commits exactly one rank")
			await click(front.skills.buttons.okbutton)
			check(front.child=="package-feats" and front.feats.wanted and front.feats.model.get("ready",false),"Actual Skills OK presents the freshly bound current Feats model")
			check(has_available(front.feats,3),"Skill-dependent physical feat3 is available before the first Feats click or recommendation")
			check(creator.source_feats==state and state.builds==builds and is_same(state._decoded.get("definitions"),definitions) and is_same(state._entries,entries),"Skills OK preserves State identity and immutable decoded/name caches")
			await choose_feat(front.feats,0);await choose_feat(front.feats,3);await click(front.feats.buttons.okbutton)
			check(front.child.is_empty() and creator.rules.draft.feats.map(func(row):return int(row.id))==[0,3],"Current physical eligibility commits the exact selected active feat IDs")
			if await enter_skills(front):
				check(creator.rules.draft.skills.is_empty(),"Original repeated Package entry clears the prior skill allocation")
				await click(front.skills.buttons.okbutton)
				check(front.child=="package-feats" and not has_available(front.feats,3) and state.selected.is_empty(),"Repeated Skills OK removes obsolete rank-dependent eligibility and prior private selection before input")
				check(creator.source_feats==state and state.builds==builds and is_same(state._decoded.get("definitions"),definitions) and is_same(state._entries,entries),"Repeated current publication reuses immutable caches without retaining stale model data")
				await click(front.feats.buttons.cancelbutton)
				check(front.child.is_empty() and creator.source_feats==state and state.builds==builds,"Within-draft Feats Cancel returns Main without discarding immutable caches")
				if await enter_skills(front):
					await click(front.skills.buttons.okbutton)
					check(front.child=="package-feats" and creator.source_feats==state and state.builds==builds and not has_available(front.feats,3),"Reopen after Cancel retains caches and republishes current prerequisite eligibility")
					await click(front.feats.buttons.cancelbutton)
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Focused entry/cache checks never fabricate a character upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Actual Package Configure/Skills up0/OK publishes current feat3 prerequisite eligibility before any Feats click, exact physical selection/commit, repeated entry removal, State/immutable definitions/name-cache identity. Controlled active scalar tables and nonrendering art/fonts; no live latency, BIC/server or pixel acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
