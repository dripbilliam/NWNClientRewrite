extends "res://tests/native_level_up_recommended_test.gd"
# Current-source actual installed native controls and real private 2DA
# worker; authored received DTO/active data and nonrendering art/fonts are explicit.
var fixture_case:="domains"
var target_stage:="domains"
var canonical: Dictionary={}
var canonical_before: Dictionary={}
var received_value: Dictionary={}
var received_before: Dictionary={}
var begin_value: Dictionary={}
var next_token:=700
var pressed_observations: Array=[]
var work_results: Array=[]
var help_before: Array=[]
var late_request:=-1
var late_ticket: Array=[]
var fixture_resources:=""
var fixture_prepared:=false
var click_cancel:=false
var change_catalog:=false
var resource_sources: Dictionary={}
func record_bytes(name: String,type: int,bytes: PackedByteArray) -> void:
	var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(bytes)
	resource_sources[name+":"+str(type)]={"name":name,"type":type,"bytes":bytes.size(),"sha256":digest.finish().hex_encode()}
func read_table(name: String) -> Dictionary:
	var bytes: PackedByteArray=catalog.get_resource(name,2017);record_bytes(name,2017,bytes)
	var parser:=TwoDa.new();var value: Dictionary=parser.parse(bytes.get_string_from_utf8());check(parser.failure.is_empty(),"Installed active table decodes: "+name);return value
func record_pane(key: String) -> void:
	var pane=front.panes[key];record_bytes(str(pane.resource),2047,catalog.get_resource(str(pane.resource),2047))
	for name in pane.models:record_bytes(str(name),2002,catalog.get_resource(str(name),2002))
func package_body() -> String:
	if fixture_case.begins_with("failed-"):return "This is not a 2DA resource.\n"
	if fixture_case.begins_with("empty-"):return "2DA V2.0\nDomain1 Domain2 School\n0 5 2 7\n1 **** **** ****\n"
	if fixture_case.begins_with("default-"):return "2DA V2.0\nDEFAULT: 2\nUnrelated\n0 8\n1 9\n"
	return "2DA V2.0\nDomain1 Domain2 School\n0 5 2 7\n1 2 0 5\n"
func setup_fixture(args: Dictionary) -> bool:
	catalog=Catalog.new()
	if not gate(catalog.mount_install(args.install),"Read-only installed source catalog mounts"):return false
	fixture_resources=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(fixture_resources)
	var resource_file:=FileAccess.open(fixture_resources.path_join("packages.2da"),FileAccess.WRITE)
	if not gate(resource_file!=null,"Declared active Packages fixture has a private output file"):return false
	resource_file.store_string(package_body());resource_file.close()
	if not gate(catalog.mount_directory(fixture_resources,100000001),"Only declared Packages overrides installed data"):return false
	base_text=preload("res://systems/native_data/talk_text.gd").new();active_text=preload("res://systems/native_data/talk_text.gd").new()
	if not gate(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and active_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Independent installed caption and active-text owners open"):return false
	for name in ["classes","racialtypes","skills","feat","spells","exptable","portraits"]:canonical[name]=read_table(name)
	var fields: Dictionary={"PlayerClass":"1","SkillPointBase":"0","SkillsTable":"lvr_skills","FeatsTable":"lvr_feats","AttackBonusTable":"lvr_bab","BonusFeatsTable":"****","StatGainTable":"****","SpellGainTable":"****","SpellKnownTable":"****","PickDomains":"0","PickSchool":"0","SpellCaster":"0","SpellbookRestricted":"0","SkipSpellSelection":"0","MinAssociateLevel":"255","Arcane":"0","HitDie":"8","Package":"1"}
	canonical.classes=Fixtures.row_update(canonical.classes,3,fields)
	fields.PickDomains="1";fields.PickSchool="1";canonical.classes=Fixtures.row_update(canonical.classes,2,fields)
	canonical.racialtypes=Fixtures.row_update(canonical.racialtypes,0,{"NormalFeatEveryNthLevel":"255"})
	canonical.ruleset={"orderedRows":[{"Label":"MIN_LEVEL_FOR_MAX_HP","Value":"4"},{"Label":"CHARGEN_ENABLE_RECOMMENDED_BUTTON","Value":"0" if fixture_case=="disabled" else "1"}]}
	canonical.lvr_skills={"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"},{"SkillIndex":"1","ClassSkill":"0"}]};canonical.lvr_feats={"orderedRows":[]};canonical.lvr_bab={"orderedRows":[{"BAB":"1"},{"BAB":"2"},{"BAB":"3"},{"BAB":"4"}]}
	var domain_rows: Array=[]
	for id in 6:domain_rows.append({"Name":str(6011+id) if id in [0,2,5] else "0","Description":str(5985+id),"GrantedFeat":"65535","Icon":"****"})
	canonical.domains={"orderedRows":domain_rows}
	var school_rows: Array=[]
	for id in 9:school_rows.append({"StringRef":str(381+id),"Description":str(381+id)})
	canonical.spellschools={"orderedRows":school_rows};active_text.tables=canonical;canonical_before=canonical.duplicate(true)
	var ranks: Array=[];ranks.resize(canonical.skills.orderedRows.size()&255);ranks.fill(0);ranks[0]=1
	received_value={"actorId":42,"race":0,"classes":[{"id":3,"level":3}],"baseAbilities":[14,14,14,14,14,14],"skills":ranks,"fieldDC6":0,"feats":[],"fieldC0":0,"fieldD4":0,"fieldE34":-1,"fieldE48":"","fieldE30":-1,"fieldE38":""};received_before=received_value.duplicate(true)
	var available: Array=[];available.resize(canonical.classes.orderedRows.size()&255);available.fill(false);available[2]=true
	begin_value={"token":next_token,"snapshot":received_value,"available":available,"protocolFeatures":{"multiclassRuleset":true},"draftContext":{"baseFortitude":0}}
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	painter=Painter.new();painter.art=Art.new();painter.fonts=Doubles.HeadlessFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	desktop=Desktop.new();desktop.rules=preload("res://systems/native_data/game_ui_rules.gd").new();desktop.rules.text=active_text;desktop.owner_ui={"text":active_text,"catalog":catalog,"modal_order":null,"modal_surfaces":null};desktop.art=painter.art
	panel=RuntimePanel.new();surface.add_child(panel);panel.setup(str(args.report)+".layout.cfg");controller=NativeOwner.new();controller.configure(desktop,panel);panel.request.connect(controller.input);controller.configure_source(painter,base_text,catalog,"")
	runtime=controller.source_runtime;front=runtime.frontend;private_owner=runtime.source_owner;fixture_prepared=true;return true
func enter_target() -> bool:
	if panel.wanted:await key_escape()
	panel.reset();panel.open();next_token+=1;var next: Dictionary=begin_value.duplicate(true);next.token=next_token
	controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":JSON.parse_string(JSON.stringify(next))}))
	if not gate(await ready("class"),"Actual Class prepares for a fresh private transaction"):return false
	record_pane("class")
	check(front.panes["class"].state.selected_class()==2,"Physical allowed Class is the appended class2, not received slot0/class3")
	await click(front.panes["class"].buttons.okbutton)
	if not gate(await ready("attributes"),"Actual total-level4 Attributes follows physical Class OK"):return false
	record_pane("attributes")
	await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
	if not gate(await ready("skills"),"Actual Skills follows the one manual ability choice"):return false
	record_pane("skills")
	var skills_pane=front.panes.skills
	for step in 16:
		if private_owner.skills.points==0:break
		var previous: int=private_owner.skills.points;await click(skills_pane.buttons["up:0"])
		if not gate(private_owner.skills.points<previous,"Physical skill arrow spends a valid point"):return false
	if not gate(private_owner.skills.points==0,"No skill quota is bypassed to enter the post-child flow"):return false
	await click(skills_pane.buttons.okbutton)
	if not gate(await ready("domains"),"Native flow reaches real Domain controls without any Recommended action"):return false
	record_pane("domains")
	check(not runtime.tables.has("packages") and not canonical.has("packages"),"Packages is initially absent from both private and canonical maps")
	check(private_owner.selected_domains.is_empty() and private_owner.selected_school==-1,"No child choice has committed on entry")
	if target_stage=="school":
		await select_domains([5,2]);await click(front.panes.domains.buttons.okbutton)
		if not gate(await ready("school"),"Manual Domain OK reaches real School controls without loading Packages"):return false
		record_pane("school")
		check(private_owner.selected_domains==[5,2] and not runtime.tables.has("packages"),"Only physical Domain OK commits local choices; Packages remains absent")
	return true
func select_domains(ids: Array) -> void:
	var pane=front.panes.domains
	for id in pane.state.chosen.duplicate():await click(pane.buttons["domain:"+str(id)+":remove"])
	for id in ids:await click(pane.buttons["domain:"+str(id)+":add"])
func edit_before_recommend() -> void:
	if target_stage=="domains":await select_domains([5,2])
	else:await click(front.panes.school.buttons.necromancy)
	var pane=front.panes[target_stage];help_before=[pane.state.help_title,pane.state.help_description]
func observe_result(stage: String,value: Dictionary,request: int,ticket: Array) -> void:
	if stage==target_stage:work_results.append({"stage":stage,"value":value.duplicate(true),"request":request,"ticket":ticket.duplicate()})
func observe_pressed() -> void:
	var pane=front.panes[target_stage];late_request=runtime.recommendation_work.serial;late_ticket=front.ticket.duplicate()
	var observer:=Callable(self,"observe_result")
	if not runtime.recommendation_work.completed.is_connected(observer):runtime.recommendation_work.completed.connect(observer)
	var local_value: Variant=pane.state.chosen.duplicate() if target_stage=="domains" else pane.state.selected
	var committed: Variant=private_owner.selected_domains.duplicate() if target_stage=="domains" else private_owner.selected_school
	pressed_observations.append({"stage":target_stage,"pending":private_owner.recommendation_pending,"local":local_value,"committed":committed,"help":[pane.state.help_title,pane.state.help_description],"cancelEnabled":not pane.buttons.cancelbutton.disabled,"okDisabled":pane.buttons.okbutton.disabled,"packagesBeforeWork":runtime.tables.has("packages"),"ticket":late_ticket.duplicate(),"request":late_request})
	# Deliberately hostile child callback, not a choice injection: it must be
	# rejected while the real physical action is pending and leave all commits.
	private_owner.accepted_child(target_stage,[0,2] if target_stage=="domains" else 1,front.ticket.duplicate())
	check(private_owner.current(front.ticket) and (private_owner.selected_domains==committed if target_stage=="domains" else private_owner.selected_school==committed),"Pending child callback cannot commit or advance")
	if change_catalog:desktop.owner_ui.catalog=Catalog.new()
	if click_cancel:key_escape.call_deferred()
func recommend() -> bool:
	var pane=front.panes[target_stage]
	if not gate(not pane.buttons.recommendbutton.disabled,"Real mode1 Recommended is enabled with Packages initially absent"):return false
	var observer:=Callable(self,"observe_pressed")
	if not pane.buttons.recommendbutton.pressed.is_connected(observer):pane.buttons.recommendbutton.pressed.connect(observer)
	await click(pane.buttons.recommendbutton);return true
func exercise() -> void:
	if not await enter_target():return
	await edit_before_recommend();var pane=front.panes[target_stage];var initial_ticket: Array=front.ticket.duplicate()
	if fixture_case=="disabled":
		check(pane.buttons.recommendbutton.disabled,"Active rule disables the physical Recommended action")
		await click(pane.buttons.recommendbutton)
		check(not private_owner.recommendation_pending and not runtime.tables.has("packages") and pane.state.chosen==[5,2],"Disabled input neither clears local choices nor requests Packages");return
	var prior: Variant=pane.state.chosen.duplicate() if target_stage=="domains" else pane.state.selected
	private_owner.action("school" if target_stage=="domains" else "domains","recommend",-1,initial_ticket)
	check(not private_owner.recommendation_pending and (pane.state.chosen==prior if target_stage=="domains" else pane.state.selected==prior),"Wrong-stage action cannot borrow the current ticket or reset choices")
	click_cancel=fixture_case.begins_with("busy-");change_catalog=fixture_case.begins_with("catalog-")
	if not await recommend():return
	if not gate(not pressed_observations.is_empty(),"Physical button reached the typed current-stage handler"):return
	var observed: Dictionary=pressed_observations[0]
	check(observed.pending and observed.cancelEnabled and observed.okDisabled and not observed.packagesBeforeWork,"Real pending worker disables edits/OK, preserves Cancel, and starts with no Packages")
	check(observed.local==[] if target_stage=="domains" else observed.local==7,"Domains clears begun local tabs before loading; School preserves the edited tab")
	check(observed.help==help_before,"The pre-load operation preserves native displayed help references")
	if click_cancel:
		if not gate(await wait_for(func():return not panel.wanted),"Physical Escape cancels a pending Package recommendation"):return
		click_cancel=false
		if not await enter_target():return
		var new_pane=front.panes[target_stage];var fresh: Variant=new_pane.state.chosen.duplicate() if target_stage=="domains" else new_pane.state.selected
		runtime.recommendation_work.completed.emit(target_stage,{"ready":true,"loaded":true,"apply":true,"nativeValues":[0,2] if target_stage=="domains" else [1]},late_request,late_ticket)
		check(new_pane.scope==front.ticket and (new_pane.state.chosen==fresh if target_stage=="domains" else new_pane.state.selected==fresh) and not runtime.tables.has("packages"),"Old worker completion cannot relabel, populate or advance the newer pane");return
	if change_catalog:
		check(await wait_for(func():return not runtime.active),"Changed active catalog retires the private source flow")
		check(not pane.wanted and not private_owner.wanted,"A replaced catalog cannot publish or apply a stale result");desktop.owner_ui.catalog=catalog;return
	if not gate(await wait_for(func():return not private_owner.recommendation_pending),"Real private Packages job completes under the current ticket"):return
	check(private_owner.recommendation_diagnostics.has(target_stage) and private_owner.recommendation_diagnostics[target_stage].work.resources==["packages"],"Exactly the on-demand Packages dependency was loaded")
	check(runtime.tables.has("packages") and not canonical.has("packages") and received_value==received_before,"Publication is private and leaves actor/canonical table data unchanged")
	var failed: bool=fixture_case.begins_with("failed-");var empty: bool=fixture_case.begins_with("empty-");var defaults: bool=fixture_case.begins_with("default-")
	if not gate(not work_results.is_empty(),"The actual worker result is observed without replacing its publisher"):return
	var worker: Dictionary=work_results[0].value
	record_bytes("packages",2017,catalog.get_resource("packages",2017))
	if not failed:
		check(worker.get("context",{}).get("packageId")==1 and worker.get("context",{}).get("classIndex")==1 and worker.context.source=="native_class","Appended current class uses physical Class.Package1 rather than copied slot0 Package0")
		if empty or defaults:check(worker.reads.all(func(read):return not read.lookupReturned and int(read.value)==(2 if defaults else 0)),"Ignored-false GetINT outputs are observed as native zero or table DEFAULT, never prior GUI choice")
	else:check(worker.get("loaded")==false and [pane.state.help_title,pane.state.help_description]==help_before and not private_owner.reason.is_empty(),"Failed Packages load preserves help and records unavailable state")
	if target_stage=="domains":
		check(private_owner.selected_domains.is_empty(),"Recommended changes remain local until physical Domain OK")
		if failed or empty or defaults:
			check(pane.state.chosen.is_empty() and pane.buttons.okbutton.disabled and not private_owner.reason.is_empty(),"Load failure or duplicate native output creates no filler domains and remains explicit")
			await select_domains([5,0]);check(not pane.buttons.okbutton.disabled,"Manual input recovers after unavailable recommendation")
		else:
			check(pane.state.chosen==[2,0] and pane.state.selected_chosen==0 and pane.state.help_title==int(pane.state.entry(2).title),"Later-class Package1 yields ordered physical domains2/0 and first chosen help")
			await select_domains([5,2]);await click(pane.buttons.recommendbutton)
			check(await wait_for(func():return not private_owner.recommendation_pending) and pane.state.chosen==[2,0],"Repeat restores exact recommendations without compounding local choices")
		var final_domains: Array=pane.state.chosen.duplicate();await click(pane.buttons.okbutton)
		check(await ready("school") and private_owner.selected_domains==final_domains,"Only physical Domain OK commits the exact local pair")
	else:
		var expected: int=7 if failed else 0 if empty else 2 if defaults else 5
		check(pane.state.selected==expected and private_owner.selected_school==-1,"School uses ignored-false native output or preserves edited tab on failed load, with no early commit")
		if failed:await click(pane.buttons.evocation)
		else:
			await click(pane.buttons.necromancy);await click(pane.buttons.recommendbutton)
			check(await wait_for(func():return not private_owner.recommendation_pending) and pane.state.selected==expected,"Repeated School recommendation uses current native values rather than prior tab")
		var final_school: int=pane.state.selected;await click(pane.buttons.okbutton)
		check(private_owner.selected_school==final_school and front.stage=="summary","Only physical School OK commits, then actual native flow reaches Summary")
func cleanup() -> void:
	if fixture_prepared:
		if panel.wanted:await key_escape()
		check(desktop.commands.all(func(value):return value.operation!="submit"),"No partial level-up is submitted")
		check(received_value==received_before and canonical==canonical_before,"Canonical source tables and received snapshot remain exact")
		controller.close();panel.free();painter.art.close();painter.close();painter.queue_free()
	if base_text!=null:base_text.close()
	if active_text!=null:active_text.close()
	await frames(5)
	if is_instance_valid(surface):surface.queue_free();await frames()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report","case"]) or FileAccess.file_exists(str(args.report)):quit(2);return
	fixture_case=str(args.case);target_stage="school" if fixture_case.ends_with("school") else "domains"
	if not fixture_case in ["domains","school","failed-domains","failed-school","empty-domains","empty-school","default-domains","default-school","busy-domains","busy-school","catalog-domains","catalog-school","disabled"]:quit(2);return
	if setup_fixture(args):await exercise()
	await cleanup()
	var value: Dictionary={"success":failures.is_empty(),"checks":checks,"failures":failures,"case":fixture_case,"pressed":pressed_observations,"workResults":work_results,"resourceSources":resource_sources.values(),"serverConnections":0,"gpu":false,"originalPixelsAccepted":false,"scope":"Current-source physical native Class/Attributes/Skills/Domain/School controls, real private 2DA worker/publication, authored received/class metadata, controlled nonrendering art/fonts; no live server or pixel acceptance."}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(value,"\t"));file.close();quit(0 if value.success else 1)
