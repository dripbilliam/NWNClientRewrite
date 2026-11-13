extends "res://tests/native_level_up_source_controls_test.gd"
const ReplyFixture=preload("res://tests/native_level_up_reply_fixture.gd")
const NativeOwner=preload("res://systems/native_level_up.gd")
const RuntimePanel=preload("res://systems/server_level_up.gd")
const Fixtures=preload("res://tests/native_creation_fixture_tables.gd")
class Desktop extends RefCounted:
	var generation:=501
	var area_id:=7
	var actor_id:=42
	var rules
	var owner_ui: Dictionary={}
	var art
	var state:={"module":{"serverFlags":{"field158":false,"field164":false}}}
	var commands: Array=[]
	var actor_value: Dictionary={"objectType":5,"id":42,"areaId":7,"nativeLifetime":1,"clientKnownLifetime":1,"replicationRemoved":false}
	func actor() -> Dictionary:return actor_value
	func command(value: Dictionary) -> void:
		var outgoing:=value.duplicate(true);outgoing.generation=generation;outgoing.areaId=area_id;outgoing.actorId=actor_id
		commands.append(outgoing)
	func class_tables_ready(_id: int) -> bool:return true
var front
var controller
var runtime
var private_owner
var desktop
var panel
var observations: Array=[]
var first_timings: Dictionary={}
var cancel_on_press:=false
func gate(value: bool,label: String) -> bool:check(value,label);return value
func wait_for(predicate: Callable,seconds: float=15) -> bool:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await process_frame
	return false
func ready(key: String) -> bool:return await wait_for(func():return front.panes.has(key) and front.panes[key].wanted and front.panes[key].layout_ready)
func key_escape() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=true;surface.push_input(event,true);await frames();event=InputEventKey.new();event.keycode=KEY_ESCAPE;event.pressed=false;surface.push_input(event,true);await frames()
func cancel_recommendation() -> void:
	observations.append({"kind":"busy-cancel","pending":private_owner.recommendation_pending,"enabled":not front.panes[front.stage].buttons.cancelbutton.disabled})
	await key_escape()
func recommended_pressed(key: String) -> void:
	observations.append({"kind":key,"pending":private_owner.recommendation_pending,"ability":private_owner.attributes.selected,"cancel":not front.panes[key].buttons.cancelbutton.disabled})
	if cancel_on_press:cancel_recommendation.call_deferred()
func read_table(name: String) -> Dictionary:
	var parser:=TwoDa.new();var value:=parser.parse(catalog.get_resource(name,2017).get_string_from_utf8());check(parser.failure.is_empty(),"Actual active table decodes: "+name);return value
func extra_cases(_begin: Dictionary,_received: Dictionary,_before: Dictionary,_tables: Dictionary) -> void:pass
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var mode: String=str(args.get("case","existing"));var later: bool=mode=="later";catalog=Catalog.new();check(catalog.mount_install(args.install),"Installed original control/data catalog mounts read-only")
	var resources:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(resources)
	var row0: String="**** ****" if mode=="missing" else "DEX missing_lvr" if mode=="failed" else "DEX lvr_skill0"
	var packages_body: String="not a native2DA" if mode=="package-failed" else "2DA V2.0\nAttribute SkillPref2DA\n0 "+row0+"\n1 CON lvr_skill1\n"
	var pref_body: String="2DA V2.0\nSkillIndex\n" if mode=="empty" else "2DA V2.0\nSkillIndex\n0 0\n1 1\n"
	for entry in [["packages.2da",packages_body],["lvr_skill0.2da",pref_body],["lvr_skill1.2da","2DA V2.0\nSkillIndex\n0 1\n"]]:
		var file:=FileAccess.open(resources.path_join(entry[0]),FileAccess.WRITE);file.store_string(entry[1]);file.close()
	check(catalog.mount_directory(resources,100000001),"Only declared active Package/preference fixtures override original resources")
	base_text=preload("res://systems/native_data/talk_text.gd").new();active_text=preload("res://systems/native_data/talk_text.gd").new();check(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and active_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original captions and active TLK owners are distinct")
	var tables: Dictionary={}
	for name in ["classes","racialtypes","skills","feat","spells","exptable","portraits"]:tables[name]=read_table(name)
	var fields:={"PlayerClass":"1","SkillPointBase":"2","SkillsTable":"lvr_skills","FeatsTable":"lvr_feats","AttackBonusTable":"lvr_bab","BonusFeatsTable":"****","StatGainTable":"****","SpellGainTable":"****","SpellKnownTable":"****","PickDomains":"0","PickSchool":"0","SpellCaster":"0","SpellbookRestricted":"0","SkipSpellSelection":"0","MinAssociateLevel":"255","Arcane":"0","HitDie":"8","Package":"1"}
	tables.classes=Fixtures.row_update(tables.classes,3,fields);tables.classes=Fixtures.row_update(tables.classes,2,fields)
	tables.racialtypes=Fixtures.row_update(tables.racialtypes,0,{"NormalFeatEveryNthLevel":"255"})
	tables.ruleset={"orderedRows":[{"Label":"MIN_LEVEL_FOR_MAX_HP","Value":"4"},{"Label":"CHARGEN_ENABLE_RECOMMENDED_BUTTON","Value":"1"}]};tables.lvr_skills={"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"},{"SkillIndex":"1","ClassSkill":"0"}]};tables.lvr_feats={"orderedRows":[]};tables.lvr_bab={"orderedRows":[{"BAB":"1"},{"BAB":"2"},{"BAB":"3"},{"BAB":"4"}]}
	active_text.tables=tables;var raw_before:=tables.duplicate(true);var ranks: Array=[];ranks.resize(tables.skills.orderedRows.size()&255);ranks.fill(0);ranks[0]=1
	var received:={"actorId":42,"race":0,"classes":[{"id":2 if later else 3,"level":3}],"baseAbilities":[14,14,14,14,14,14],"skills":ranks,"fieldDC6":0,"feats":[],"fieldC0":0,"fieldD4":0,"fieldE34":-1,"fieldE48":"","fieldE30":-1,"fieldE38":""};var before:=received.duplicate(true);var available: Array=[];available.resize(tables.classes.orderedRows.size()&255);available.fill(false);available[3]=true
	var begin:={"token":61,"snapshot":received,"available":available,"protocolFeatures":{"multiclassRuleset":true},"draftContext":{"baseFortitude":0}}
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	painter=Painter.new();painter.art=Art.new();painter.fonts=Doubles.HeadlessFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	desktop=Desktop.new();desktop.rules=preload("res://systems/native_data/game_ui_rules.gd").new();desktop.rules.text=active_text;desktop.owner_ui={"text":active_text,"catalog":catalog,"modal_order":null,"modal_surfaces":null};desktop.art=painter.art
	panel=RuntimePanel.new();surface.add_child(panel);panel.setup(str(args.report)+".layout.cfg");controller=NativeOwner.new();controller.configure(desktop,panel);panel.request.connect(controller.input);controller.configure_source(painter,base_text,catalog,"");runtime=controller.source_runtime;front=runtime.frontend;private_owner=runtime.source_owner
	panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":JSON.parse_string(JSON.stringify(begin))}))
	if gate(await ready("class"),"Actual source Class prepares"):
		await click(front.panes["class"].buttons.okbutton)
		if gate(await ready("attributes"),"Actual next-total4 Attributes prepares without first-level state"):
			var pane=front.panes.attributes;pane.buttons.recommendbutton.pressed.connect(recommended_pressed.bind("attributes"))
			check(not pane.buttons.recommendbutton.disabled,"Original active switch enables mode1 Attributes Recommended")
			await click(pane.buttons.strupbutton);check(private_owner.attributes.selected==0,"Manual arrow starts the single private ability choice")
			await click(pane.buttons.recommendbutton)
			var expected_ability: int= -1 if mode=="package-failed" else 0 if mode=="missing" else 2 if later else 1
			if gate(await wait_for(func():return not private_owner.recommendation_pending and private_owner.attributes.selected==expected_ability),"Physical Attributes Recommended resolves exact current-slot Package Attribute"):
				check(observations.any(func(value):return value.kind=="attributes" and value.pending and value.ability==-1 and value.cancel),"Attribute refund happens before async load and Cancel remains enabled while busy")
				check(runtime.tables.has("packages") and not tables.has("packages") and private_owner.received==JSON.parse_string(JSON.stringify(before)),"Private package resource publication does not mutate canonical table map/received snapshot")
				first_timings.attributes=private_owner.recommendation_diagnostics.attributes.duplicate(true)
				if mode=="package-failed":
					check(pane.buttons.okbutton.disabled and pane.help.body.get_parsed_text().contains("unavailable"),"Failed Packages load leaves the refunded ability unspent and explains unavailable recommendations")
					await click(pane.buttons.dexupbutton);check(private_owner.attributes.selected==1,"Manual source arrows recover after a failed recommendation load")
				await click(pane.buttons.okbutton)
				if gate(await ready("skills"),"Original mode1 Skills follows the accepted private ability"):
					pane=front.panes.skills;pane.buttons.recommendbutton.pressed.connect(recommended_pressed.bind("skills"));await click(pane.buttons["up:0"])
					check(private_owner.skills.changes()[0]==1,"Manual private skill edit exists before Recommended")
					runtime.recommendation_work.reset_skills.connect(func(_request,_ticket):observations.append({"kind":"skills-baseline","rank0":private_owner.skills.ranks[0],"points":private_owner.skills.points}))
					await click(pane.buttons.recommendbutton)
					if gate(await wait_for(func():return not private_owner.recommendation_pending),"Physical Skills Recommended completes scoped active preferences"):
						var changes: Array=private_owner.skills.changes();var no_lookup: bool=mode in ["missing","package-failed"];var no_choices: bool=mode in ["empty","failed"]
						check(changes[0]==1 and changes[1]==0 if no_lookup else changes.all(func(value):return value==0) if no_choices else changes[1]==2 and changes[0]==0 if later else changes[0]==4 and changes[1]==0,"Original preference-only allocation preserves failed-lookup edits or resets exactly before valid preference execution")
						check(private_owner.skills.points==(3 if no_lookup else 4 if no_choices else 0) and not tables.has("lvr_skill0") and not tables.has("lvr_skill1"),"No arbitrary filler or global preference table publication")
						var reset_observed: bool=observations.any(func(value):return value.kind=="skills-baseline" and value.rank0==1 and value.points==4)
						check(not reset_observed if no_lookup else reset_observed,"Skills resets baseline only after successful SkillPref string lookup, before preference load outcome")
						if mode=="failed":check(pane.help.body.get_parsed_text().contains("unavailable") and not pane.buttons.cancelbutton.disabled,"Failed named preference load remains visible and cancellable after baseline reset")
						first_timings.skills=private_owner.recommendation_diagnostics.skills.duplicate(true)
						await click(pane.buttons.recommendbutton);check(await wait_for(func():return not private_owner.recommendation_pending) and private_owner.skills.changes()==changes,"Repeated Recommended restores baseline rather than compounding ranks")
	var timing: Dictionary=private_owner.recommendation_diagnostics.duplicate(true)
	if panel.wanted:await key_escape()
	check(not panel.wanted and desktop.commands.all(func(value):return value.operation!="submit"),"Actual cancellation never submits a partial or automatic level-up")
	var next:=begin.duplicate(true);next.token=62;panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":next}))
	if await ready("class"):
		await click(front.panes["class"].buttons.okbutton)
		if await ready("attributes"):
			cancel_on_press=true
			if not front.panes.attributes.buttons.recommendbutton.pressed.is_connected(recommended_pressed.bind("attributes")):front.panes.attributes.buttons.recommendbutton.pressed.connect(recommended_pressed.bind("attributes"))
			await click(front.panes.attributes.buttons.recommendbutton)
			check(await wait_for(func():return not panel.wanted),"Physical Escape cancels while recommendation data is being prepared")
			check(observations.any(func(value):return value.kind=="busy-cancel" and value.pending and value.enabled),"Busy source surface keeps cancellation admitted")
			var serial: int=runtime.recommendation_work.serial;runtime.recommendation_work.completed.emit("attributes",{"ready":true,"loaded":true,"attribute":"CHA"},serial-1,[501,7,42,61,1,"attributes"])
			check(not panel.wanted and not runtime.active,"Retired completion cannot reopen or edit the cancelled draft")
	await extra_cases(begin,received,before,tables)
	check(received==before and tables==raw_before,"Received actor snapshot and canonical active table graph remain exact")
	controller.close();panel.free();painter.art.close();painter.close();painter.queue_free();base_text.close();active_text.close();await frames(5);surface.queue_free();await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"case":mode,"observations":observations,"firstTimings":first_timings,"timings":timing,"serverConnections":0,"gpu":false,"scope":"Actual mode1 Class/Attributes/Skills Recommended controls, declared active Package/preference resources via real workers, slot0 versus appended-class package, original refund/baseline/cost/order and failed/empty lookup/load semantics, repeat, busy Cancel/Escape and retired completion. Controlled nonrendering art/fonts and authored received snapshot; no packet/server/pixel acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if result.success else 1)
