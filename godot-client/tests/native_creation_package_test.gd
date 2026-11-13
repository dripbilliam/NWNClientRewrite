extends "res://tests/native_creation_gender_test.gd"
const PackageState=preload("res://systems/native_data/creation_package_state.gd")
const PackageRules=preload("res://systems/native_data/creation_package_rules.gd")
class OracleText:
	extends RefCounted
	var missing: Array=[]
	func raw(value: Dictionary) -> String:return "Text"+str(int(value.strRef)) if fetch_reference(int(value.strRef)).found else ""
	func fetch_reference(ref: int) -> Dictionary:return {"found":not missing.has(ref),"text":"Text"+str(ref)}
func verify_oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)=="8da744cb9f61d94b529bf429ebf03c47a36222c7901bf32fd8bbddca65181b26","Original Package callback corpus is immutable")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));check(corpus.binarySha256==ORIGINAL and corpus.rows.size()==72,"Original72 Package fixtures and252 callback operations identify the corpus")
	for row in corpus.rows:
		var rule=preload("res://systems/native_data/creation_rules.gd").new();rule.tables=row.case.tables.duplicate(true);var classes: Array=[];classes.resize(int(row.case.classId)+1);classes.fill({});classes[-1]={"Package":str(int(row.case.default)),"PickSchool":str(int(row.case.pickSchool)),"PickDomains":str(int(row.case.pickDomains)),"MinAssociateLevel":"0"};rule.tables.classes={"orderedRows":classes}
		rule.draft={"classId":int(row.case.classId),"raceId":0,"abilities":{"Str":8,"Dex":8,"Con":8,"Int":8,"Wis":8,"Cha":8},"skills":{},"feats":[],"known":{},"memorized":{},"domains":[8,9],"school":7,"packageId":777,"packageGold":999}
		var text:=OracleText.new();text.missing=row.case.missingText.map(func(ref):return int(ref));var state:=PackageState.new();state.reset(PackageState.choices(rule,text))
		check(state.selected==int(row.initial.selected) and state.entries.map(func(entry):return int(entry.id))==row.initial.ids.map(func(id):return int(id)) and [state.help_title,state.help_description]==[int(row.initial.help.title),int(row.initial.help.description)] and state.can_accept()==row.initial.ok,"Actual native state matches original population, physical sentinel and initial general help",row.case.classId)
		for step in row.results:
			match str(step.operation.kind):
				"title":state.general_help()
				"recommend":state.recommend()
				"select":state.select_index(int(step.operation.index))
				"ok","configure":
					var id: int=state.configure_package() if step.operation.kind=="configure" else state.selected_package()
					if not rule.row("packages",id).is_empty():
						var result: Dictionary=PackageRules.apply(rule,id,step.operation.kind=="ok")
						check(result.get("accepted",false) and int(rule.draft.packageId)==int(step.state.package) and int(rule.draft.packageGold)==int(step.state.gold) and int(rule.draft.school)==int(step.state.school) and rule.draft.domains.map(func(value):return int(value))==step.state.domains.map(func(value):return int(value)) and rule.draft.packageEquipment==step.state.equipment,"Native package scalar writes and pending equipment match original OK/Configure instructions",step)
			check(state.selected==int(step.state.selected) and [state.help_title,state.help_description]==[int(step.state.help.title),int(step.state.help.description)],"Native help/recommend/selection state matches original callback",step)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	verify_oracle(args.oracle)
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Independent pregame and active package catalogs mount")
	check(FileAccess.get_sha256(args.install.path_join("bin/win32/nwmain.exe"))==ORIGINAL,"Original callback target remains pinned")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(base.get_resource("cg_package",2047))=="7447e9ba4f6dd37177bc4de40bdcd9220b6cd240d517ab9f81e3bfc3155bdc4b","Original Package GUI remains pinned")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();text.base.open_file(args.install.path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,text,base,"");creator.open(171)
	if check(await wait_for(func():return creator.phase=="editing" and is_instance_valid(creator.source_frontend.packages) and creator.source_frontend.packages.layout_ready,90),"Real draft and original Package controls prepare"):
		var front=creator.source_frontend;var pane=front.packages;var scope: Array=creator.summary_identity();var wizard:=-1
		for id in creator.rules.rows("classes").size():
			if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()=="wizard":wizard=id
		check(wizard>=0,"The active class table supplies the Wizard fixture")
		creator.rules.select_class(wizard);creator.render();creator.view.recommend.pressed.emit();await wait_for(func():return creator.phase=="editing",90)
		var before: Dictionary=creator.rules.draft.duplicate(true)
		front.begin(scope,{"classBase":wizard},creator.rules.rows("classes"));front.flow.enabled.packages=true;front.flow.completed.packages=true;front.flow.enabled.customize=true;front.refresh();await frames();await click(front.main.buttons.packagesbutton)
		check(pane.wanted and pane.assets.catalog==base and pane.data_text==ui.text and pane.row_buttons.size()>0 and pane.plan.choice_buttons.size()==4,"Original eight-entry frame and four action buttons use active package data")
		check(creator.rules.draft.feats.is_empty() and creator.rules.draft.skills.is_empty() and creator.rules.draft.known.is_empty() and creator.rules.draft.abilities==before.abilities and creator.rules.draft.portrait==before.portrait,"Original Package entry clears derived choices immediately and preserves allocation/portrait",{"feats":creator.rules.draft.feats,"skills":creator.rules.draft.skills,"known":creator.rules.draft.known,"abilities":creator.rules.draft.abilities,"expected":before.abilities,"portrait":creator.rules.draft.portrait,"expectedPortrait":before.portrait})
		check(pane.state.selected==0 and pane.help_region.current.slice(1)==[483,487] and not pane.buttons.okbutton.disabled,"Initial first-row selection retains original general Package help")
		pane.list.ensure_control_visible(pane.row_buttons[-1]);await frames();await click(pane.row_buttons[-1]);check(pane.state.selected==pane.row_buttons.size()-1 and pane.help_region.current[1]==pane.state.entries[-1].title,"Physical package row changes selection and active help without a draft commit")
		await click(pane.title);check(pane.help_region.current.slice(1)==[483,487],"Original Package title restores general help without changing the selected row")
		await click(pane.buttons.recommendbutton);check(pane.state.selected==0 and pane.help_region.current[1]==pane.state.entries[0].title,"Recommended chooses first listed package rather than a guessed class default")
		await click(pane.buttons.cancelbutton);check(front.child.is_empty() and not front.flow.completed.packages and not front.flow.enabled.customize and creator.rules.draft.feats.is_empty(),"Cancel returns original3 and preserves entry reset while invalidating later customization")
		await click(front.main.buttons.packagesbutton);await key(KEY_ESCAPE);check(front.child.is_empty() and not front.flow.completed.packages,"Escape has Package-specific result3")
		await click(front.main.buttons.packagesbutton);var selected: int=pane.state.selected_package();await click(pane.buttons.okbutton)
		check(await wait_for(func():return creator.phase=="editing" and front.child.is_empty(),90),"Actual source Package OK loads referenced tables and returns to its parent")
		check(front.flow.completed.packages and front.flow.enabled.customize and int(creator.rules.draft.packageId)==selected and creator.rules.draft.get("packageSource",false),"Automatic source package commits real native data and original8008")
		check(creator.rules.draft.abilities==before.abilities and creator.rules.draft.portrait==before.portrait and creator.rules.draft.head==before.head and creator.rules.draft.soundset==before.soundset,"Automatic package does not redo abilities or appearance/portrait/voice")
		check(creator.rules.draft.skills.size()>0 and creator.rules.draft.feats.size()>0 and creator.rules.draft.known.get(1,[]).size()>0,"Actual active package preference tables populate skills, feats and known spells")
		creator.rules.draft.firstName="Native";creator.rules.draft.lastName="Package";check(creator.rules.errors().is_empty(),"Original-data source package produces a valid first-level native draft",creator.rules.errors())
		var builder:=Builder.new();var bytes:=builder.build(creator.rules);check(not bytes.is_empty() and builder.failure.is_empty(),"Native source package serializes without a JS creation service",builder.failure)
		var package: Dictionary=creator.rules.row("packages",selected);check(int(creator.rules.draft.packageGold)==creator.rules.num(package,"Gold") and creator.rules.draft.packageEquipment==PackageRules.equipment(creator.rules,package),"Actual source starting gold/equipment use referenced active package data")
		var parser:=Gff.new();var document:=parser.parse(bytes,"BIC ");check(parser.failure.is_empty() and int(document.root.Gold)==int(creator.rules.draft.packageGold) and document.root.get("ItemList",[]).size()==creator.rules.draft.packageEquipment.size(),"Native BIC stores the source callback's starting gold and pending equipment")
		await click(front.main.buttons.packagesbutton);var old: Array=front.ticket.duplicate();pane.capture("okbutton");ui.text.revision+=1;creator.refresh_source();pane.invoke("okbutton");check(front.ticket!=old and not pane.busy and creator.rules.draft.skills.is_empty(),"Active text replacement retires a held automatic package action")
		surface.size=Vector2i(512,400);await frames();front.place();pane.list.ensure_control_visible(pane.row_buttons[-1]);await frames();await click(pane.row_buttons[-1]);check(pane.scale.x<1 and pane.state.selected==pane.row_buttons.size()-1,"Original Package rows keep pointer alignment under scaling")
		var handoffs: Array=[];front.child_requested.connect(func(tag,ticket):handoffs.append([tag,ticket.duplicate()]))
		selected=pane.state.selected_package();await click(pane.buttons.configurepckg)
		check(await wait_for(func():return creator.phase=="editing" and front.child=="package-configuration",90),"Configure Package transfers scoped ownership to its distinct customization route")
		check(handoffs.is_empty() and front.skills.wanted and int(creator.rules.draft.packageId)==selected and creator.rules.draft.skills.is_empty() and creator.rules.draft.feats.is_empty() and creator.rules.draft.known.is_empty(),"Configure opens the bound original Skills child and preserves starting data without automatic preferences",{"handoffs":handoffs.size(),"skills":creator.rules.draft.skills,"feats":creator.rules.draft.feats,"known":creator.rules.draft.known,"selected":selected,"actual":creator.rules.draft.packageId})
		# Source Configure fallback is the raw class Package, even when no rows
		# are listed. Its unfinished customization modal remains explicitly staged.
		front.retire_child();var original_packages: Dictionary=creator.rules.tables.packages;var rows: Dictionary=original_packages.duplicate(true)
		for row in rows.orderedRows:row.PlayerClass="0"
		creator.rules.tables.packages=rows;creator.refresh_source();front.flow.enabled.packages=true;front.refresh();await click(front.main.buttons.packagesbutton)
		check(pane.row_buttons.is_empty() and pane.buttons.okbutton.disabled and not pane.buttons.configurepckg.disabled and pane.state.configure_package()==creator.rules.num(creator.rules.cls(),"Package",-1),"No listed package leaves automatic OK disabled but retains exact active class Configure fallback")
		await click(pane.buttons.configurepckg);check(await wait_for(func():return creator.phase=="editing" and front.child=="package-configuration",90),"Actual no-row Configure fallback reaches the same real draft handoff")
		# An explicit pending-job barrier isolates retirement of the real async
		# draft owner. Actual resource loading is checked by the mounted-data test.
		front.retire_child();creator.rules.tables.packages=original_packages;creator.refresh_source();front.flow.enabled.packages=true;front.flow.completed.packages=false;front.refresh();await click(front.main.buttons.packagesbutton)
		creator.jobs[-617]={"kind":"test-barrier"};old=front.ticket.duplicate();await click(pane.buttons.okbutton)
		check(creator.phase=="package-preparing" and pane.busy and pane.buttons.cancelbutton.disabled,"Pending package data suspends duplicate controls without an early parent acceptance")
		ui.text.revision+=1;await frames(4);creator.jobs.erase(-617)
		check(await wait_for(func():return creator.phase=="editing" and not pane.busy,30) and front.ticket!=old and creator.rules.draft.skills.is_empty() and not front.flow.completed.packages,"Text replacement retires the real pending package action before preferences apply",{"phase":creator.phase,"busy":pane.busy,"old":old,"ticket":front.ticket,"skills":creator.rules.draft.skills,"completed":front.flow.completed.packages})
		front.bind_packages(scope,front.packages_context,true,ui.text,ui.desktop.art,creator.enter_source_packages,func(_operation,_id,_identity,_ticket):front.dismiss();return {"accepted":true,"code":0x8008});await click(pane.buttons.okbutton)
		check(not front.wanted and creator.rules.draft.skills.is_empty(),"Reentrant Package owner retirement cannot accept a late callback")
		creator.refresh_source();front.begin(scope,{"classBase":wizard},creator.rules.rows("classes"));front.flow.enabled.packages=true;front.refresh();await click(front.main.buttons.packagesbutton);creator.jobs[-617]={"kind":"test-barrier"};await click(pane.buttons.okbutton)
		creator.cancel();creator.jobs.erase(-617);await frames(5);check(creator.phase=="closed" and not front.wanted and creator.rules.draft.skills.is_empty(),"Closing the draft during real pending Package work prevents late preference writes")
		creator.open(172);await wait_for(func():return creator.phase=="editing",90);front.packages_result("automatic",selected,old)
		check(creator.summary_identity()!=scope and not creator.enter_source_packages(scope),"Retired package callbacks cannot mutate a replacement native draft")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Headless inspection does not fabricate an upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"sourceArtworkDouble":true,"scope":"Original72 Package population/selection/scalar/transfer fixtures plus actual source controls, real draft/BIC actions, pending/held/reentrant retirement and scaling. Original pixels, associate name generation, full recommendation-provider instruction parity and the configuration child remain unaccepted. Authoritative upload is checked separately."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
