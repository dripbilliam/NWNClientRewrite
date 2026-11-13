extends "res://tests/native_creation_gender_test.gd"
const AdapterFixture=preload("res://tests/native_creation_feat_adapter_test.gd")
var click_times: Array=[]
func available_index(pane,id: int) -> int:
	for index in pane.model.get("available",[]).size():
		if not pane.model.available[index].has("children") and int(pane.model.available[index].id)==id:return index
	return -1
func install_rules(creator,ui) -> void:
	var data=AdapterFixture.fixture()
	var tables: Dictionary=creator.rules.tables
	for name in ["feat","masterfeats","classfeats","classskills","attack","saves","bonus","racefeats"]:tables[name]=data.tables[name]
	var classes: Dictionary=tables.classes.duplicate(true);var races: Dictionary=tables.racialtypes.duplicate(true)
	var class_fields: Dictionary=data.tables.classes.orderedRows[0].duplicate();class_fields.merge({"PickDomains":"0","PickSchool":"0","SpellbookRestricted":"0","SkipSpellSelection":"0","Arcane":"0","MinAssociateLevel":"255","MemorizesSpells":"0"},true)
	classes=preload("res://tests/native_creation_fixture_tables.gd").row_update(classes,0,class_fields)
	var race_fields: Dictionary=data.tables.racialtypes.orderedRows[0].duplicate()
	for key in ["Str","Dex","Con","Int","Wis","Cha"]:race_fields[key+"Adjust"]="0"
	races=preload("res://tests/native_creation_fixture_tables.gd").row_update(races,0,race_fields)
	tables.classes=classes;tables.racialtypes=races
	creator.rules.draft.merge(data.draft,true)
	for id in 11:ui.text.overrides[id]="Fixture feat "+str(id);ui.text.overrides[id+1000]="Server description "+str(id)
	ui.text.overrides[0]="Alpha";ui.text.overrides[2]="Dependent";ui.text.overrides[4]="Granted";ui.text.overrides[8]="Child A";ui.text.overrides[9]="Child B";ui.text.overrides[100]="Family";ui.text.revision+=1
	creator.rules.record_skill_points(int(creator.rules.source_skill_budget()));creator.render()
func choose_feat(pane,id: int) -> void:
	var index:=available_index(pane,id)
	if not check(index>=0,"Physical chooser exposes active physical feat "+str(id),pane.model):return
	pane.lists.available.ensure_control_visible(pane.rows.available[index]);await frames()
	var began:=Time.get_ticks_usec();await click(pane.buttons["available:"+str(index)+":arrow"]);click_times.append((Time.get_ticks_usec()-began)/1000.0)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Actual original GUI resources mount read-only")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(208)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.feats.layout_ready,50),"Real creator and original source Feats prepare",creator.resource_errors):
		install_rules(creator,ui)
		var front=creator.source_frontend;var pane=front.feats;var identity: Array=creator.summary_identity()
		front.begin(identity,{"classBase":0},creator.rules.rows("classes"));front.flow.enabled.packages=true;front.flow.completed.packages=false
		var transfer: Dictionary=creator.commit_source_skills(true,identity);check(transfer.get("next","")=="package-feats","Committed native Skills cache transfers to Feats")
		front.open_child(str(transfer.get("next","package-feats")));await frames(5)
		check(front.child=="package-feats" and pane.wanted and pane.model.ready and not front.flow.completed.packages,"Original Feats owns the transferred Package callback without completing it")
		var before:=JSON.stringify(creator.rules.draft.feats)
		await choose_feat(pane,0);check(creator.source_feats.selected==[0] and pane.model.remaining==1 and JSON.stringify(creator.rules.draft.feats)==before,"Actual add-arrow changes private selection and source count, not committed draft")
		await choose_feat(pane,2);check(creator.source_feats.selected==[0,2] and pane.model.canAccept and not pane.buttons.okbutton.disabled,"Dependent add-arrow fills the original reservations")
		await click(pane.buttons.okbutton)
		check(front.child.is_empty() and front.main.visible and not pane.wanted and creator.rules.draft.get("sourceFeatChoices",false) and creator.rules.draft.feats.map(func(value):return int(value.id))==[0,2],"Actual OK commits visible physical feat IDs and finishes the active no-further-child route")
		check(front.flow.completed.packages,"Original800e callback completes Package after the active class rules require no later child")
		creator.rules.reset_source_choices();creator.source_feats=preload("res://systems/native_data/creation_feat_state.gd").new();creator.render();front.retire_child();front.open_child("package-feats");await frames()
		await choose_feat(pane,0);await click(pane.buttons.cancelbutton)
		check(front.child.is_empty() and creator.rules.draft.feats.is_empty() and creator.rules.draft.skills.is_empty() and creator.source_feats.selected.is_empty(),"Actual Cancel returns3 and resets derived choices through the current owner")
		front.open_child("package-feats");await frames()
		creator.rules.tables.packages={"orderedRows":[{"ClassID":"0","PlayerClass":"1","Name":"0","FeatPref2DA":"fixture_preferences"}]};creator.rules.tables.fixture_preferences={"orderedRows":[{"FeatIndex":"0"},{"FeatIndex":"2"}]}
		creator.jobs[-991]={"kind":"test-barrier"};await click(pane.buttons.recommendbutton)
		check(creator.phase=="feats-preparing" and pane.busy and pane.buttons.cancelbutton.disabled,"Actual pending recommendation prevents duplicate source input")
		ui.text.revision+=1;await frames(4);creator.jobs.erase(-991)
		check(await wait_for(func():return creator.phase=="editing" and not pane.busy,10) and creator.source_feats.selected.is_empty(),"Active text replacement during pending work rejects late preference writes")
		var stale: Array=front.ticket.duplicate();var index:=available_index(pane,0)
		if index>=0:
			pane.capture("available:"+str(index)+":arrow");ui.text.revision+=1;creator.refresh_source();pane.invoke("available:"+str(index)+":arrow")
			check(front.ticket!=stale and creator.source_feats.selected.is_empty(),"A held source click cannot cross active text/ticket replacement")
		var old_scope:=identity.duplicate();creator.draft_scope+=1;var before_replaced:=JSON.stringify(creator.rules.draft)
		check(creator.commit_source_feats(true,old_scope).is_empty() and JSON.stringify(creator.rules.draft)==before_replaced,"A stale connection/draft cannot commit Feats")
		front.dismiss()
	check(not sent.any(func(message):return message.get("kind","")=="native-creation-submit"),"Isolated source interaction never uploads a fabricated character")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"input_including_frame_waits_ms":click_times,"publicConnections":0,"gpu":false,"sourceArtworkDouble":true,"scope":"Actual creator/frontend/original Feats controls with custom active rules: click/add/dependent/OK/cancel/scoped handoff and stale input. Source artwork uses headless doubles; no original pixels or server upload acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
