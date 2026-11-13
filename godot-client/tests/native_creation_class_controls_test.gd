extends "res://tests/native_creation_gender_test.gd"
class OfflineContext extends Node:
	var args: Dictionary={"creation-package":"manual"}
class BranchInput extends "res://tests/native_creation_source_live_probe.gd":
	var repeat_checked: Dictionary={}
	func click(button: Button,label: String) -> bool:
		if not await super.click(button,label):return false
		if label not in ["package-feats Recommended","package-spells Recommended"] or repeat_checked.has(label):return true
		repeat_checked[label]=true
		if not check(await wait_for(func():return creator.phase=="editing"),label+" preparation settles before Reset",creator.status):return false
		var pane=front.feats if label=="package-feats Recommended" else front.spells
		var before: Variant=creator.source_feats.selected.duplicate() if label=="package-feats Recommended" else creator.source_spells.state.known.duplicate(true)
		if not await super.click(pane.buttons.resetbutton,label+" native Reset"):return false
		if not check(await wait_for(func():return creator.phase=="editing"),label+" Reset completes"):return false
		if label=="package-feats Recommended":
			if not check(creator.source_feats.selected.is_empty(),"Native Feats Reset clears only private selected feats"):return false
		else:
			if not check(creator.source_spells.receipt.events==[{"operation":"reset"}],"Native Spells Reset replaces its replay transcript"):return false
		if not await super.click(pane.buttons.recommendbutton,label+" after Reset"):return false
		if not check(await wait_for(func():return creator.phase=="editing"),label+" repeated recommendation settles",creator.status):return false
		var after: Variant=creator.source_feats.selected if label=="package-feats Recommended" else creator.source_spells.state.known
		return check(after==before,label+" preserves exact active preference choices after Reset")

	func choose_without_recommend(pane,tag: String) -> bool:
		if tag=="package-domains":
			while pane.state.chosen.size()<2:
				if not check(not pane.state.available_ids.is_empty(),"Actual Domains has another active physical choice"):return false
				var id:=int(pane.state.available_ids[0]);pane.list.ensure_control_visible(pane.row_nodes[id]);await frames()
				if not await click(pane.buttons["domain:"+str(id)+":add"],"Domains actual row add "+str(id)):return false
		elif tag=="package-school":
			if not await click(pane.buttons[pane.State.TAGS[0]],"School actual General choice"):return false
		elif tag=="package-spells":
			var levels: Array=[int(pane.model.get("level",-1))]
			for level in 10:
				if not levels.has(level):levels.append(level)
			for level in levels:
				if not pane.buttons.okbutton.disabled:break
				if level<0 or pane.buttons["spelllevel"+str(level)].disabled:continue
				if not await click(pane.buttons["spelllevel"+str(level)],"Spells actual level "+str(level)):return false
				for turn in 256:
					if not pane.buttons.okbutton.disabled:break
					var index:=-1
					for at in pane.model.get("available",[]).size():
						if pane.model.available[at].get("enabled",true):index=at;break
					if index<0:break
					pane.lists.available.scroll_vertical=int(absf(pane.plan.row.hooks.next.y)*index);await frames()
					var slot:=-1
					for at in pane.rows.available.size():
						if int(pane.rows.available[at].index)==index:slot=at;break
					if not check(slot>=0,"Actual virtual spell pool binds the selected active row"):return false
					if not await click(pane.buttons["available:"+str(slot)+":arrow"],"Spells actual add "+str(pane.model.available[index].id)):return false
		return true
	func configure_package() -> bool:
		if not await open_main("packagesbutton"):return false
		if not check(await wait_for(func():return front.packages.layout_ready and front.child=="packagesbutton"),"Actual Package resources prepare"):return false
		if not await click(front.packages.buttons.configurepckg,"Package Configure"):return false
		for turn in 12:
			if not check(await wait_for(func():return creator.phase=="editing" and (front.child.is_empty() or front.child.begins_with("package-"))),"Class continuation remains current",creator.status):return false
			if front.child=="package-post-skills":
				if not check(await wait_for(func():return front.child!="package-post-skills"),"Original class continuation resolves",preload("res://systems/native_data/creation_post_feats.gd").creation_source(creator.rules)):return false
			if front.child.is_empty():return check(front.flow.completed.packages,"Complete actual manual Package branch returns to Main")
			var tag: String=front.child;var pane
			match tag:
				"package-configuration":pane=front.skills
				"package-feats":pane=front.feats
				"package-school":pane=front.school
				"package-domains":pane=front.domains
				"package-spells":pane=front.spells
				"package-associate":pane=front.associate
				_:return check(false,"Recognized actual native class child",tag)
			if not check(await wait_for(func():return pane.layout_ready and pane.buttons.has("okbutton")),tag+" source layout prepares"):return false
			var manual_spells: bool=tag=="package-spells" and owner_world.args.get("creation-spells-selection")=="manual"
			if not manual_spells and pane.buttons.has("recommendbutton") and not pane.buttons.recommendbutton.disabled:
				if not await click(pane.buttons.recommendbutton,tag+" Recommended"):return false
			else:
				if not await choose_without_recommend(pane,tag):return false
			if not await accept(pane,tag):return false
			if not check(await wait_for(func():return front.child!=tag or front.ticket!=pane.scope),tag+" retires its exact source ticket",creator.status):return false
		return check(false,"Original finite class branch terminates")
func source_fields(document: Dictionary,rules,expected: Dictionary) -> void:
	var parsed: Dictionary=document.root;var class_id:=int(rules.draft.classId);var cls: Dictionary=parsed.ClassList[0]
	check(int(cls.Class)==class_id and int(cls.ClassLevel)==1,"Parsed BIC keeps the actual active physical class and first-level branch")
	check(parsed.FeatList.map(func(row):return int(row.Feat))==expected.feats,"Parsed BIC keeps exact active granted/selected feat order")
	check(parsed.SkillList.map(func(row):return int(row.Rank))==expected.skills,"Parsed BIC keeps exact actual native skill ranks")
	if rules.num(rules.cls(),"PickSchool")!=0:check(int(cls.School)==int(rules.draft.school),"Parsed School is the actual accepted physical BYTE choice")
	else:check(not cls.has("School"),"Classes without School omit its native file field")
	if rules.num(rules.cls(),"PickDomains")!=0:
		check([int(cls.Domain1),int(cls.Domain2)]==rules.draft.domains and cls.Domain1!=cls.Domain2,"Parsed Domains preserve two distinct accepted active physical IDs")
	else:check(not cls.has("Domain1") and not cls.has("Domain2"),"Classes without Domains omit both native file fields")
	var spells: Array=[]
	for level in 10:
		var key:="KnownList"+str(level);var wanted: Array=rules.draft.known.get(level,[])
		if wanted.is_empty():check(not cls.has(key),"Empty source spell level is omitted "+str(level))
		else:
			check(cls.get(key,[]).map(func(row):return int(row.Spell))==wanted,"Parsed spell level retains exact actual native book/order "+str(level))
			spells.append_array(wanted)
	check(spells==expected.known,"Complete learned spell projection agrees with the committed source controls")
	var pet:=Builder.source_pet_fields(rules)
	check(pet.ready,"Actual class-owned pet writer metadata is available")
	if pet.ready:
		for key in ["FamiliarType","FamiliarName","CompanionType","CompanionName"]:
			if pet.fields.has(key):
				check(parsed.get(key)==pet.fields[key].value and document.field_types[0][key]==pet.fields[key].type,"Parsed native pet field matches its current class namespace/type "+key)
			else:check(not parsed.has(key),"Unused native associate field is absent "+key)
func ready(driver,pane,label: String) -> bool:
	return driver.check(await driver.wait_for(func():return pane.layout_ready),label+" original source controls prepare")
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
	if not await driver.configure_package():return false
	var post:=preload("res://systems/native_data/creation_post_feats.gd").creation_source(creator.rules)
	var expected_children: Array=["package-configuration","package-feats"]
	if post.get("PickDomains",0)!=0:expected_children.append("package-domains")
	if post.get("PickSchool",0)!=0:expected_children.append("package-school")
	if post.get("SpellbookRestricted",0)!=0 and post.get("SkipSpellSelection",0)==0:expected_children.append("package-spells")
	if (int(post.get("MinAssociateLevel",255))&255)<=1:expected_children.append("package-associate")
	for tag in expected_children:
		if not driver.check(driver.events.any(func(row):return row.event==tag+" OK"),"Actual class-dependent branch was physically accepted "+tag,post):return false
	if not await driver.open_main("customizebutton"):return false
	var tail=creator.tail
	if not driver.check(await driver.wait_for(func():return tail.stage=="appearance" or not tail.failure.is_empty(),20) and tail.stage=="appearance","Actual native Appearance provider opens",tail.failure):return false
	if not await driver.accept(tail.appearance,"Appearance"):return false
	if not driver.check(await driver.wait_for(func():return tail.stage=="information" and tail.information.random_ready and tail.information.pending_random<0,15),"Actual native Info/name worker becomes ready",tail.failure):return false
	await driver.type_text(tail.information.edits.firstnameedit,"Native"+class_label.capitalize())
	await driver.type_text(tail.information.edits.lastnameedit,"ClassFlow")
	if not await driver.accept(tail.information,"Information"):return false
	if not driver.check(front.child.is_empty() and creator.rules.draft.get("sourceTailChoices",false),"Native Info completes the current actual source draft"):return false
	var errors: Array=Builder.validation_errors(creator.rules)
	if not driver.check(errors.is_empty(),"All actual class/source choices pass full native Builder admission",errors):return false
	driver.capture_expected()
	if not await driver.open_main("playbutton"):return false
	return driver.check(await driver.wait_for(func():return creator.phase=="waiting" or creator.phase=="editing" and not creator.status.is_empty(),20) and creator.phase=="waiting","Physical Play waits for actual typed native BIC worker, without inventing server admission",creator.status)
func make_driver():return BranchInput.new()
func observe_bic(_bytes: PackedByteArray) -> void:pass
func configure_active_catalog(_base,_active,_args: Dictionary) -> void:pass
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report","class"]) or FileAccess.file_exists(args.report):quit(2);return
	var requested_class: String=str(args["class"])
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Original control and active data catalogs mount read-only")
	configure_active_catalog(base,active,args)
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(773)
	var context:=OfflineContext.new();root.add_child(context);var driver: Variant=make_driver();root.add_child(driver);driver.owner_world=context;driver.creator=creator;driver.front=creator.source_frontend
	if requested_class=="memorizing-non-scroll":context.args["creation-spells-selection"]="manual"
	var built:=false;var class_row: Dictionary={};var parsed_summary: Dictionary={}
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.wanted and creator.source_frontend.main.layout_ready,20),"Ordinary Creator opens original native Main"):
		if await exercise(driver,creator,str(args["class"]).to_lower()):
			class_row=creator.rules.cls().duplicate(true)
			var submissions: Array=sent.filter(func(message):return message.get("kind")=="native-creation-submit")
			if check(submissions.size()==1,"Actual native Play emits exactly one completed BIC intent"):
				var bytes:=Marshalls.base64_to_raw(submissions[0].data);observe_bic(bytes);var parser:=Gff.new();var document:=parser.parse(bytes,"BIC ");built=not bytes.is_empty() and parser.failure.is_empty()
				if check(built,"Complete actual class-dependent BIC parses with native field types"):
					source_fields(document,creator.rules,driver.expected);parsed_summary={"classId":creator.rules.draft.classId,"known":driver.expected.known,"feats":driver.expected.feats,"skills":driver.expected.skills,"domains":driver.expected.domains,"school":driver.expected.school,"bytes":bytes.size()}
	check(await wait_for(func():return creator.preview.retiring.is_empty(),10),"Owned async native preview retirement drains before teardown")
	var events: Array=driver.events.duplicate(true);var driver_checks:=int(driver.checks);var driver_failures: Array=driver.failures.duplicate(true)
	ui.close();ui.free();painter.free();driver.queue_free();context.queue_free();surface.queue_free();await frames(6)
	failures.append_array(driver_failures);checks+=driver_checks
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"case":requested_class,"class":args["class"],"classRow":class_row,"built":built,"parsed":parsed_summary,"events":events,"gpu":false,"serverConnections":0,"scope":"Actual original native Main through class-dependent manual Package controls, active recommendations/Reset, School/Domains/Spells/Associate as required, real name/appearance workers, source Tail and physical Play into typed BIC worker. Installed active data and controlled nonrendering art/fonts. No live server admission, pixel or FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
