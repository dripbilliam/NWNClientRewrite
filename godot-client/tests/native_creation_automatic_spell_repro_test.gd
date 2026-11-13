extends "res://tests/native_creation_class_controls_test.gd"
const SpellReproGame=preload("res://systems/native_data/game_ui_rules.gd")
# Preserve the original expected-rejection mode; after mode exercises the
# same controls and resource override through the corrected native BIC worker.
var expect_accept:=false
var parsed_spell_shape: Dictionary={}
var feat_diagnostic: Dictionary={}
func describe_automatic_feats(rules) -> Dictionary:
	var helper=preload("res://systems/native_data/creation_feat_automatic.gd");var tables=preload("res://systems/native_data/creation_feat_tables.gd");var snapshot=preload("res://systems/native_data/creation_feat_snapshot.gd");var choice=preload("res://systems/native_data/creation_feat_choice_rules.gd")
	var receipt: Dictionary=rules.draft.sourceAutomaticFeats;var view: RefCounted=helper.RuleView.new();view.tables=rules.tables;view.draft=receipt.context.duplicate(true);view.draft.skills=receipt.preSkills.duplicate()
	var decoded: Dictionary=tables.decode(rules.tables.feat);var value: Dictionary=snapshot.resolve_spells(snapshot.compose(view,[],decoded),view)
	if not value.ready:return {"reason":value.get("reason")}
	var source: Dictionary=value.source;var chosen: Array=[];var remaining: int=(int(source.normal)+int(source.bonus))&255;var candidates: Array=[]
	var preferences: Dictionary=rules.tables.get(receipt.preferences.name,{})
	for at in preferences.get("orderedRows",[]).size():
		if remaining==0:break
		var read: Dictionary=tables.integer(preferences,at,"FeatIndex")
		if not read.get("ready",false) or not read.get("ok",false):continue
		var id:=int(read.value)&65535;var candidate: Dictionary=source.duplicate();candidate.selected=chosen.duplicate();candidate.featId=id;candidate.feat=source.definitions[id] if id<source.definitions.size() else {}
		var result: Dictionary=choice.evaluate(candidate);candidates.append({"id":id,"result":result,"raw":rules.row("feat",id),"genericReason":rules.feat_requirement(id,rules.granted_feats()+chosen),"flags":choice.flags(source,id)})
		if result.get("allowed",false):chosen.append(id);remaining=(remaining-1)&255
	return {"receipt":receipt,"selected":chosen,"remaining":remaining,"fortitude":source.fortitude,"scores":source.scores,"spellLevels":source.spellLevels,"candidates":candidates}
func write_table(path: String,value: Dictionary) -> void:
	var body:="2DA V2.0\nDEFAULT: "+str(value.get("defaultValue","****"))+"\n"+" ".join(value.columns)+"\n"
	for row in value.orderedRows.size():body+=str(value.rowLabels[row])+" "+" ".join(value.orderedCells[row])+"\n"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(body);file.close()
func active_fixture(base,active,args: Dictionary) -> void:
	var parser:=preload("res://systems/native_data/two_da.gd").new();var classes:=parser.parse(base.get_resource("classes",2017).get_string_from_utf8());var packages:=parser.parse(base.get_resource("packages",2017).get_string_from_utf8());var wizard:=-1
	for id in classes.orderedRows.size():
		if str(preload("res://systems/native_data/game_ui_rules.gd").cell(classes.orderedRows[id],"Label","")).to_lower()=="wizard":wizard=id;break
	if args["case"]=="stock":check(wizard>=0,"Ordinary automatic case keeps actual installed Wizard/package resources unchanged");return
	var changed:=0;var name: String="empty_sprefs" if args["case"]=="empty" else "****"
	for id in packages.orderedRows.size():
		if SpellReproGame.number(SpellReproGame.cell(packages.orderedRows[id],"ClassID"),-1)==wizard:
			packages=preload("res://tests/native_creation_fixture_tables.gd").row_update(packages,id,{"SpellPref2DA":name});changed+=1
	check(wizard>=0 and changed>0,"Private spell-pref reproduction discovers actual Wizard class/package IDs")
	var directory:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(directory);write_table(directory.path_join("packages.2da"),packages)
	if args["case"]=="empty":
		var file:=FileAccess.open(directory.path_join("empty_sprefs.2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSpellIndex\n");file.close()
	check(active.mount_directory(directory,100000001),"Only private package spell-pref resources override the actual installed catalog")
func exercise(driver,creator,class_label: String) -> bool:
	var front=creator.source_frontend
	if not await driver.open_main("genderbutton") or not await ready(driver,front.gender,"Gender"):return false
	if not await driver.click(front.gender.buttons.malebutton,"Gender Male") or not await driver.accept(front.gender,"Gender"):return false
	if not await driver.open_main("racebutton") or not await ready(driver,front.race,"Race"):return false
	if not await driver.click(front.race.buttons.recommendbutton,"Race Recommended") or not await driver.accept(front.race,"Race"):return false
	if not await driver.open_main("portraitbutton"):return false
	if not driver.check(await driver.wait_for(func():return front.portrait.layout_ready and not front.portrait.cells.is_empty() and not front.portrait.cells[0].button.disabled),"Actual Portrait resources/choices prepare"):return false
	if not await driver.click(front.portrait.cells[0].button,"Portrait first active choice") or not await driver.accept(front.portrait,"Portrait"):return false
	if not await driver.open_main("classbutton") or not await ready(driver,front.class_chooser,"Class"):return false
	var selected:=-1
	for index in front.class_chooser.state.entries.size():
		var id:=int(front.class_chooser.state.entries[index].id)
		if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()==class_label:selected=index;break
	if not driver.check(selected>=0,"Requested class comes from actual active source rows",class_label):return false
	front.class_chooser.list.ensure_control_visible(front.class_chooser.row_buttons[selected]);await driver.frames()
	if not await driver.click(front.class_chooser.row_buttons[selected],"Class "+class_label) or not await driver.accept(front.class_chooser,"Class"):return false
	if not await driver.open_main("alignbutton") or not await ready(driver,front.alignment,"Alignment"):return false
	var alignment:=int(front.alignment.state.enabled.find(true))
	if not driver.check(alignment>=0,"Actual selected class has an admitted native alignment"):return false
	if not await driver.click(front.alignment.buttons[front.alignment.State.TAGS[alignment]],"Alignment first admitted choice") or not await driver.accept(front.alignment,"Alignment"):return false
	if not await driver.open_main("abilitiesbutton") or not await ready(driver,front.attributes,"Attributes"):return false
	if not await driver.click(front.attributes.buttons.recommendbutton,"Attributes Recommended") or not await driver.accept(front.attributes,"Attributes"):return false
	var auto_input=preload("res://tests/native_creation_source_live_probe.gd").new();root.add_child(auto_input);auto_input.owner_world=driver.owner_world;auto_input.creator=creator;auto_input.front=front
	driver.owner_world.args["creation-package"]="recommended"
	var accepted: bool=await auto_input.configure_package();driver.checks+=int(auto_input.checks);driver.failures.append_array(auto_input.failures);driver.events.append_array(auto_input.events);auto_input.queue_free()
	if not check(accepted and front.flow.completed.packages and front.child.is_empty(),"Actual automatic Package completes8008 despite an exhausted/skipped spell preference helper"):return false
	if driver.owner_world.args.get("spell-case")=="stock":check(not creator.rules.draft.known.get(1,[]).is_empty(),"Ordinary Wizard automatic recommendations use its actual active spell preferences")
	else:check(creator.rules.draft.known.get(1,[]).is_empty(),"No level1 preference or greedy filler was invented")
	if expect_accept:
		var first_receipt: Dictionary=creator.rules.draft.get("sourceAutomaticSpells",{}).duplicate(true)
		if not check(first_receipt.get("completed",false),"Actual automatic Package publishes its separate completed spell receipt"):return false
		if not await driver.open_main("packagesbutton"):return false
		check(not creator.rules.draft.has("sourceAutomaticSpells"),"Actual Package reopen retires the automatic spell receipt")
		if not await driver.click(front.packages.buttons.configurepckg,"Package Configure after automatic spells"):return false
		if not check(await driver.wait_for(func():return front.child=="package-configuration" and front.skills.layout_ready),"Actual Configure enters manual Skills without reusing automatic spell authority"):return false
		check(not creator.rules.draft.has("sourceAutomaticSpells"),"Manual Configure cannot select the automatic spell validation branch")
		if not await driver.click(front.skills.buttons.cancelbutton,"Skills Cancel after automatic spells"):return false
		if not check(await driver.wait_for(func():return front.child.is_empty()),"Actual manual Cancel returns to Main"):return false
		var replay_input=preload("res://tests/native_creation_source_live_probe.gd").new();root.add_child(replay_input);replay_input.owner_world=driver.owner_world;replay_input.creator=creator;replay_input.front=front
		var replayed: bool=await replay_input.configure_package();driver.checks+=int(replay_input.checks);driver.failures.append_array(replay_input.failures);driver.events.append_array(replay_input.events);replay_input.queue_free()
		if not check(replayed and creator.rules.draft.has("sourceAutomaticSpells") and creator.rules.draft.sourceAutomaticSpells.known==first_receipt.known,"Fresh physical Recommended replays source data and republishes its current automatic receipt"):return false
	if not await driver.open_main("customizebutton"):return false
	var tail=creator.tail
	if not driver.check(await driver.wait_for(func():return tail.stage=="appearance" or not tail.failure.is_empty(),20) and tail.stage=="appearance","Native source Appearance prepares",tail.failure):return false
	if not await driver.accept(tail.appearance,"Appearance"):return false
	if not driver.check(await driver.wait_for(func():return tail.stage=="information" and tail.information.random_ready and tail.information.pending_random<0,15),"Actual Info name worker prepares",tail.failure):return false
	await driver.type_text(tail.information.edits.firstnameedit,"EmptyPrefs");await driver.type_text(tail.information.edits.lastnameedit,"SourceCaster")
	if not await driver.accept(tail.information,"Information"):return false
	var retained: Dictionary=creator.rules.draft.duplicate(true)
	if expect_accept:feat_diagnostic=describe_automatic_feats(creator.rules)
	if expect_accept:driver.capture_expected()
	if not await driver.open_main("playbutton"):return false
	if expect_accept:
		if not check(await driver.wait_for(func():return creator.phase=="waiting" or creator.phase=="editing" and not creator.status.is_empty(),20) and creator.phase=="waiting","Mandatory BIC worker accepts original automatic empty-preference semantics",creator.status):return false
		var submissions: Array=sent.filter(func(message):return message.get("kind")=="native-creation-submit")
		if not check(submissions.size()==1,"Physical Play emits one completed typed BIC intent without claiming server admission"):return false
		var bytes:=Marshalls.base64_to_raw(submissions[0].data);var parser:=Gff.new();var document:=parser.parse(bytes,"BIC ")
		if not check(not bytes.is_empty() and parser.failure.is_empty(),"Automatic empty-preference BIC parses with actual native field types"):return false
		source_fields(document,creator.rules,driver.expected)
		var cls: Dictionary=document.root.ClassList[0];var expected_known: Dictionary={};var expected_prepared: Dictionary={}
		for level in 10:
			var known: Array=retained.known.get(level,[]);var prepared: Array=retained.memorized.get(level,[]);var known_key:="KnownList"+str(level);var prepared_key:="MemorizedList"+str(level)
			expected_known[level]=known;expected_prepared[level]=prepared
			var serialized: Array=prepared.duplicate()
			while serialized.size()<creator.rules.spell_slots(level):serialized.append(65535)
			check(cls.get(prepared_key,[]).map(func(row):return int(row.Spell))==serialized,"Native first-level preparation saves the known prefix and FFFF unbound slots "+str(level))
			for key in [known_key,prepared_key]:
				for row in cls.get(key,[]):check(row.keys()==["Spell"],"Native first-level spell row contains only Spell, without invented Ready/Meta/Domain fields: "+key,row)
		parsed_spell_shape={"known":expected_known,"memorized":expected_prepared,"bytes":bytes.size()}
		check(retained.has("sourceAutomaticSpells") and not retained.get("sourceSpellChoices",false),"Distinct automatic receipt survives actual source Tail without claiming manual completion")
		check(creator.rules.draft==retained,"Mandatory replay and serialization preserve accepted source choices")
		return true
	if not check(await driver.wait_for(func():return creator.phase=="editing" and not creator.status.is_empty(),20),"Mandatory BIC worker returns a visible source validation rejection",creator.status):return false
	check(creator.status.contains("Choose level 1 spells."),"Exact generic automatic known-count guard reproduces the original-caller completeness distinction",creator.status)
	check(front.main.visible and front.child.is_empty() and front.status_view.visible and creator.rules.draft==retained,"Actual Main presents the reason and preserves chosen source controls")
	check(not sent.any(func(message):return message.get("kind")=="native-creation-submit"),"Rejected local BIC is never misreported as an authoritative upload")
	return true
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report","case"]) or args["case"] not in ["missing","empty","stock"] or FileAccess.file_exists(args.report):quit(2);return
	expect_accept=args.get("expect","before")=="after"
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original catalogs mount read-only");active_fixture(base,active,args)
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(811)
	var context:=OfflineContext.new();context.args["spell-case"]=args["case"];root.add_child(context);var driver:=BranchInput.new();root.add_child(driver);driver.owner_world=context;driver.creator=creator;driver.front=creator.source_frontend
	var confirmed:=false
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.wanted and creator.source_frontend.main.layout_ready,20),"Ordinary source Main prepares"):confirmed=await exercise(driver,creator,"wizard")
	check(await wait_for(func():return creator.preview.retiring.is_empty(),10),"Owned async preview retires before test teardown")
	var status: String=creator.status;var events: Array=driver.events.duplicate(true);var count:=int(driver.checks);var errors: Array=driver.failures.duplicate(true)
	ui.close();ui.free();painter.free();driver.queue_free();context.queue_free();surface.queue_free();await frames(6);checks+=count;failures.append_array(errors)
	var samples: Array=[]
	if args.get("profile","")=="true":
		var measured: Variant=load("res://systems/native_data/creation_package_rules.gd");samples=measured.native_test_samples.duplicate()
	var result:={"success":confirmed and failures.is_empty(),"checks":checks,"failures":failures,"case":args["case"],"expect":args.get("expect","before"),"reproductionConfirmed":confirmed,"status":status,"parsed":parsed_spell_shape,"featDiagnostic":feat_diagnostic,"recommendationUsec":samples,"events":events,"gpu":false,"serverConnections":0,"scope":"Actual native automatic Package/Tail/Play and mandatory BIC worker with private missing/empty SpellPref2DA resource override or ordinary unmodified stock data; before mode preserves expected generic rejection, after mode parses native books. Controlled nonrendering art/fonts; optional copied-only policy clocks exclude GPU/network. Original8e4620/7eb630 source parity, no executed original client/server, admission or pixel claim."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
