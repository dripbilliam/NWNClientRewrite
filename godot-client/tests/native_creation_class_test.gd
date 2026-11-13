extends "res://tests/native_creation_gender_test.gd"
const Classes=preload("res://systems/native_data/creation_class_state.gd")
const ClassRules=preload("res://systems/native_data/creation_class_rules.gd")
const CreationRules=preload("res://systems/native_data/creation_rules.gd")
class NamedText:
	extends RefCounted
	func raw(value: Dictionary) -> String:return "Active name "+str(value.strRef)
func prerequisites(path: String) -> void:
	check(FileAccess.get_sha256(path)=="91c7ef88d732a10e670b5c1224851afa05f42aa3bc498ba03ac10aa9d2c7ec38","Immutable original Class prerequisite corpus with preserved return register")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));check(corpus.binarySha256==ORIGINAL and corpus.rows.size()==600,"600 executed original creation-mode Class prerequisite cases")
	for row in corpus.rows:check(ClassRules.eligible(row.input.requirements,row.input.source)==(int(row.result)!=0),"Original prerequisite branches and independent OR groups",row)
func commits(path: String) -> void:
	check(FileAccess.get_sha256(path)=="0bf1aa0767c8e35a2418b0804ce4a96e2424f83dc6128de0a4ce6f0bad598850","Immutable original complete Class commit corpus")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));check(corpus.binarySha256==ORIGINAL and corpus.rows.size()==49,"49 original Class configurations with255 operations")
	for row in corpus.rows:
		var rules:=CreationRules.new();rules.tables=row.case.tables.duplicate(true);rules.creation_base_hp=int(row.initial.baseHP)
		rules.draft={"classId":int(row.initial.classId),"raceId":0,"abilities":row.case.source.abilities.duplicate(),"skills":{},"feats":[],"known":{},"memorized":{},"domains":[1,2],"packageId":123,"goodEvil":int(row.initial.goodEvil),"lawChaos":int(row.initial.lawChaos)}
		for id in row.case.source.primaryFeats+row.case.source.bonusFeats:rules.draft.feats.append({"id":int(id),"kind":"normal"})
		for step in row.results:
			if step.operation.kind=="class":
				check(rules.commit_class(int(step.operation.id)),"Native draft accepts original active Class row",step.operation)
				var state: Dictionary=step.state
				var abilities_match: bool=rules.ABILITIES.all(func(key):return int(rules.draft.abilities[key])==int(state.abilities[key]))
				check(abilities_match and int(rules.creation_base_hp)==int(state.baseHP) and int(rules.creation_class_points)==int(state.points) and int(rules.draft.goodEvil)==int(state.goodEvil) and int(rules.draft.lawChaos)==int(state.lawChaos),"Actual Class commit matches raw allocation, point BYTE, HP cache and original alignment defaults",{"actual":rules.draft,"points":rules.creation_class_points,"baseHP":rules.creation_base_hp,"expected":state})
				check(rules.draft.domains==[1,2] and int(rules.draft.packageId)==123,"Class modal leaves derived reset and Package to their original parent/child owners")
			else:rules.draft.abilities[str(step.operation.key)]=int(step.operation.value)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","commit-oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	prerequisites(args.oracle);commits(args["commit-oracle"])
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Independent pregame and active catalogs mount")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(base.get_resource("cg_class",2047))=="45156aa0e9d86248573551f32bb1b955a9558688b2aa5c8f01f91f65ced5aa1e","Pinned original CG_CLASS source")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original base captions load")
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,text,base,"");creator.open(141)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.class_chooser.layout_ready,100),"Real native draft and original Class modal prepare",creator.source_frontend.class_chooser.failure):
		var front=creator.source_frontend;var pane=front.class_chooser;var scope: Array=creator.summary_identity()
		check(not front.wanted and pane.assets.catalog==base and front.class_text==ui.text,"Class artwork remains independently pregame-owned with active server rules/text")
		front.begin(scope,{"classBase":int(creator.rules.draft.classId)},creator.rules.rows("classes"));front.flow.enabled["class"]=true;front.refresh();await frames();await click(front.main.buttons.classbutton)
		check(pane.wanted and front.child=="classbutton" and pane.title.text==text.raw({"strRef":61920}),"Actual parent Class control opens original creation title61920")
		check(pane.state.selected==0 and pane.plan.row.hooks.next==Vector2(0,44) and pane.plan.row.bounds.size.is_equal_approx(Vector2(324,42)),"Source creation selects first displayed row with shared authored class-row geometry")
		var previous:=int(creator.rules.draft.classId);var wizard:=-1;var disabled:=-1
		for index in pane.state.entries.size():
			if str(creator.rules.cell(creator.rules.row("classes",int(pane.state.entries[index].id)),"Label","")).to_lower()=="wizard":wizard=index
			if not pane.state.entries[index].enabled:disabled=index
		if check(wizard>=0,"Active Class table exposes Wizard"):
			pane.list.scroll_vertical=wizard*44;await frames();await click(pane.row_buttons[wizard])
			check(pane.state.selected_class()==int(pane.state.entries[wizard].id) and int(creator.rules.draft.classId)==previous,"Physical Class row previews without committing draft")
			await click(pane.title);check(pane.help_refs==[480,484] and pane.state.selected==wizard,"Class title restores original general help without changing selection")
			await click(pane.buttons.cancelbutton);check(front.child.is_empty() and not front.flow.completed["class"] and int(creator.rules.draft.classId)==previous,"Class Cancel returns2 and preserves original draft/parent completion")
			await click(front.main.buttons.classbutton);await click(pane.buttons.recommendbutton)
			check(pane.state.selected_class()==4,"Creation Recommended selects physical row4 through the active class map")
			pane.list.scroll_vertical=wizard*44;await frames();await click(pane.row_buttons[wizard]);await click(pane.buttons.okbutton)
			check(front.child.is_empty() and front.flow.completed["class"] and front.flow.enabled.align and int(creator.rules.draft.classId)==int(pane.state.entries[wizard].id),"Class OK commits real native draft and advances original CG_MAIN8004")
			check(int(creator.rules.creation_class_points)==27 and int(creator.rules.draft.abilities.Int)==11,"Real Wizard commit initializes server-defined primary allocation and remaining points")
		if disabled>=0:
			await click(front.main.buttons.classbutton);pane.list.scroll_vertical=disabled*44;await frames();await click(pane.row_buttons[disabled])
			check(pane.state.selected==disabled and not pane.row_buttons[disabled].disabled and pane.buttons.okbutton.disabled and pane.row_buttons[disabled].get_child(0).modulate==Color(.5,.5,.5,1),"Unavailable Class remains selectable for help, with gray caption and disabled OK")
			var old_class:=int(creator.rules.draft.classId);await click(pane.buttons.okbutton);check(int(creator.rules.draft.classId)==old_class and pane.wanted,"Disabled Class OK cannot send a commit")
			await key(KEY_ESCAPE);check(front.child.is_empty() and front.wanted,"Physical Escape cancels only Class")
		# Replace the server's physical rows/text while keeping independent artwork.
		var custom: Dictionary=creator.rules.tables.classes.duplicate(true);custom.orderedRows[4].Name="123456";custom.orderedRows[4].Description="654321";custom.orderedRows[4].Icon="server_class_icon";custom.orderedRows[4].HitDie="19";custom.orderedRows[4].PlayerClass="0";creator.rules.tables.classes=custom;creator.refresh_source()
		var values:=Classes.choices(creator.rules,NamedText.new(),true);var choices:=Classes.new();choices.reset(values);choices.recommend()
		check(choices.selected_class()==-1 and not choices.can_accept() and choices.help_title==123456 and choices.help_description==654321,"Hidden server row4 gives original no-selection behavior and active help references without invented stock class")
		custom.orderedRows[4].PlayerClass="1";custom.orderedRows[4].PreReqTable="server_req";creator.rules.tables.server_req={"orderedRows":[{"ReqType":"RACE","ReqParam1":"99","ReqParam2":"0"}]};creator.rules.tables.classes=custom;creator.refresh_source()
		values=Classes.choices(creator.rules,NamedText.new(),true);choices.reset(values);choices.recommend()
		check(choices.selected_class()==4 and not choices.can_accept() and choices.entries[choices.selected].name=="Active name 123456" and choices.entries[choices.selected].icon=="server_class_icon","Custom class name, icon, visibility and prerequisites come from active server tables")
		var unavailable_seen:=false;var grouped:=true
		for entry in values.entries:
			if not entry.enabled:unavailable_seen=true
			elif unavailable_seen:grouped=false
		check(grouped,"Optional original sorting groups available rows ahead of unavailable rows")
		creator.rules.tables.server_req.orderedRows[0].ReqParam1=str(int(creator.rules.draft.raceId));creator.refresh_source();check(creator.rules.class_requirement(4).is_empty(),"Server prerequisite change immediately alters actual draft eligibility")
		await click(front.main.buttons.classbutton);await click(pane.buttons.recommendbutton);var old_ticket: Array=front.ticket.duplicate();pane.capture("okbutton");ui.text.revision+=1;creator.refresh_source();pane.invoke("okbutton")
		check(front.ticket!=old_ticket and pane.wanted and front.child=="classbutton","Active text/table replacement invalidates held Class input")
		front.flow.enabled.packages=true;creator.rules.draft.domains=[1,2];creator.rules.draft.skills={0:1};creator.rules.skill_summary_mask=9;await click(pane.buttons.recommendbutton);await click(pane.buttons.okbutton)
		check(int(creator.rules.draft.classId)==4 and int(creator.rules.creation_base_hp)==19 and creator.rules.draft.domains.is_empty() and creator.rules.draft.skills.is_empty() and creator.rules.skill_summary_mask==0 and not front.flow.enabled.packages,"Actual source commit uses server HitDie19 and original conditional parent reset/invalidation")
		surface.size=Vector2i(512,400);await frames();front.place();await click(front.main.buttons.classbutton);await click(pane.buttons.recommendbutton)
		check(pane.scale.x<1 and pane.state.selected_class()==4,"Scaled Class controls preserve pointer alignment")
		var retiring:=func(id,_identity):front.dismiss();return {"accepted":true,"classId":id,"code":0x8004}
		front.bind_classes(scope,front.class_values,true,ui.text,ui.desktop.art,retiring);await click(pane.buttons.okbutton)
		check(not front.wanted,"Reentrant draft retirement prevents late Class result advancement")
		creator.cancel();creator.open(142);await wait_for(func():return creator.phase=="editing",100);front.class_result(true,4,old_ticket)
		check(creator.summary_identity()!=scope and creator.commit_source_class(4,scope).is_empty() and not front.wanted,"Closed/replaced draft rejects previous Class tickets and direct commits")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"UI inspection never fabricates upload/server acceptance")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"sourceArtworkDouble":true,"scope":"600 original prerequisite executions;49 original Class commit configurations/255 transitions; actual source Class mouse/keyboard, active server table/text changes, availability/help, original geometry, conditional reset, scaling and lifetime. Creation only; level-up routing, complete source creator, exact pixels and wider Attributes allocation acceptance remain separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
