extends "res://tests/native_creation_gender_test.gd"
const Profile=preload("res://tests/native_creation_feat_profile_clock.gd")
const ProfiledState=preload("res://tests/native_profiled_feat_state.gd")
const PlainState=preload("res://tests/native_unindexed_feat_state.gd")
var dispatches: Array=[]
func digest(bytes: PackedByteArray) -> String:
	var value:=HashingContext.new();value.start(HashingContext.HASH_SHA256);value.update(bytes);return value.finish().hex_encode()
func profiled_click(button: Button) -> Dictionary:
	var point:=button.get_global_transform_with_canvas()*(button.size*.5);var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await process_frame
	Profile.reset();var samples: Array=[]
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;event.position=point;event.global_position=point
		var token:=Profile.enter("input.dispatch");var start:=Time.get_ticks_usec();surface.push_input(event,true);samples.append(Time.get_ticks_usec()-start);Profile.leave(token);await process_frame
	var result:=Profile.finish();await frames();return {"dispatchUsec":samples,"phases":result}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report","recipe"]) or FileAccess.file_exists(args.report):quit(2);return
	var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.recipe));check(recipe.get("sourceControls",0)==91 and recipe.has_all(["classId","race","abilities","skills","packageId","feats"]),"Fixture carries only detached class-dependent inputs from actual91 source-control/original admitted export")
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Read-only installed catalog supplies the actual base Fighter workload")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(749)
	var resources: Dictionary={};var observations: Array=[];var counts: Dictionary={}
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.feats.layout_ready,20),"Actual source Creator/Feats controls prepare"):
		var rules=creator.rules;rules.draft.raceId=int(recipe.race);check(creator.commit_source_class(int(recipe.classId),creator.summary_identity()).get("accepted",false),"The actual class callback admits the captured physical class")
		for index in 6:rules.draft.abilities[rules.ABILITIES[index]]=int(recipe.abilities[index])
		rules.draft.skills={}
		for id in recipe.skills.size():
			if int(recipe.skills[id])!=0:rules.draft.skills[id]=int(recipe.skills[id])
		rules.draft.packageId=int(recipe.packageId);rules.draft.domains=[];rules.draft.school=0;rules.draft.feats=[]
		creator.package_tables();check(await wait_for(func():return creator.jobs.is_empty() and creator.resource_queue.is_empty(),10),"Original active package dependency resources prepare before the synchronous sample")
		check(rules.cls()==recipe.classRow,"Complete compiled installed class row matches the actual live source context")
		var state:=ProfiledState.new();creator.source_feats=state
		var front=creator.source_frontend;front.begin(creator.summary_identity(),{"classBase":int(recipe.classId)},rules.rows("classes"));creator.refresh_source();front.open_child("package-feats");await frames(5)
		var pane=front.feats;var before: Dictionary=pane.model.duplicate(true);counts={"physicalDefinitions":state._decoded.get("definitions",[]).size(),"beforeAvailableRows":before.get("available",[]).size(),"beforeKnownRows":before.get("known",[]).size(),"beforeRowNodes":pane.rows.available.size()+pane.rows.known.size()}
		check(before.get("ready",false) and not pane.buttons.recommendbutton.disabled and creator.phase=="editing","Actual Feats factory binds captured class/abilities/skills and an admitted Recommended control")
		var preferences: String=preload("res://systems/native_data/creation_package_rules.gd").resource(rules,rules.row("packages",int(recipe.packageId)),"FeatPref2DA")
		for name in state.model_tables(rules):
			if rules.tables.get(name) is Dictionary and active.has_resource(str(name),2017):resources[name]={"sha256":digest(active.get_resource(str(name),2017)),"physicalRows":rules.tables[name].get("orderedRows",[]).size()}
		if not preferences.is_empty():resources[preferences]={"sha256":digest(active.get_resource(preferences,2017)),"physicalRows":rules.rows(preferences).size()}
		resources["dialog.tlk"]={"sha256":FileAccess.get_sha256(str(args.install).path_join("lang/en/data/dialog.tlk"))}
		for turn in 2:
			var row:=await profiled_click(pane.buttons.recommendbutton);row.action="recommend";row.turn=turn;row.selected=state.selected.duplicate();row.availableRows=pane.model.get("available",[]).size();row.knownRows=pane.model.get("known",[]).size();observations.append(row)
			var committed: Array=pane.model.known.filter(func(entry):return entry.enabled).map(func(entry):return int(entry.id));row.commitOrder=committed
			var actual: Array=rules.granted_feats()+committed
			check(creator.phase=="editing" and actual==recipe.feats.map(func(id):return int(id)),"Real Recommended reproduces the displayed commit order of exact original admitted export feats "+str(turn),{"actual":actual,"expected":recipe.feats,"privateSelection":state.selected})
			var reference:=PlainState.new();var expected:=reference.apply("recommend",-1,rules,ui.text,preferences)
			check(expected==pane.model and reference.selected==state.selected,"Clock-only wrappers preserve the complete unprofiled native policy/model output "+str(turn))
			if turn==0:
				row=await profiled_click(pane.buttons.resetbutton);row.action="reset";observations.append(row)
				check(state.selected.is_empty() and pane.model==before,"Actual Reset restores the exact original pre-choice model before the second functional sample")
		counts.afterAvailableRows=pane.model.get("available",[]).size();counts.afterKnownRows=pane.model.get("known",[]).size();counts.afterRowNodes=pane.rows.available.size()+pane.rows.known.size();counts.prepares=state.builds;counts.modelBuilds=state.model_builds
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Diagnostic input never sends a character upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"counts":counts,"observations":observations,"resources":resources,"gpu":false,"serverConnections":0,"responsivenessAccepted":false,"artwork":"Controlled non-rendering art/font providers; source node creation/free and rule/model logic are real. Live art/raster queue costs are not inferred.","scope":"NEW copied-only clock wrappers call unchanged super/static owners for real installed Fighter workload derived from actual admitted source export. Exact feat IDs/order and complete plain-policy model equality checked across real Recommended/Reset input. Nested inclusive/exclusive phase times are diagnostic, not FPS/live latency or full creation acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
