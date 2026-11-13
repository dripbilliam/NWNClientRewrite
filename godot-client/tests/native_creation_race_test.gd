extends "res://tests/native_creation_gender_test.gd"
const RaceState=preload("res://systems/native_data/creation_race_state.gd")
const EditPopup=preload("res://systems/native_generic_edit.gd")
class FixtureText:
	extends RefCounted
	func raw(value: Dictionary) -> String:return "Biography "+str(int(value.strRef)-1000)
func edit_oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)=="3a18509ac2043d5ad9abf4f54df688ef4ac8644886f4d536d2590cbf2b79cfdd","Immutable original generic-edit key guard evidence")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));check(corpus.binarySha256==ORIGINAL and corpus.rows.size()==325,"325 original SetMaxCharacters/HandleKeyPress executions")
	var dialog:=EditPopup.new();dialog.edit=LineEdit.new();dialog.add_child(dialog.edit)
	var keys:={"letter":KEY_A,"backspace":KEY_BACKSPACE,"linefeed":KEY_ENTER,"enter":KEY_ENTER,"escape":KEY_ESCAPE,"left":KEY_LEFT,"right":KEY_RIGHT,"delete":KEY_DELETE,"home":KEY_HOME,"end":KEY_END,"tab":KEY_TAB,"paste":KEY_V,"shift":KEY_SHIFT}
	for row in corpus.rows:
		dialog.maximum=int(row.input.limit) if int(row.input.limit)>0 else -1;dialog.edit.text="A".repeat(int(row.input.length));var event:=InputEventKey.new();event.keycode=keys[row.input.name];event.ctrl_pressed=row.input.name=="paste"
		check(dialog.maximum==int(row.maximum) and dialog.blocked_key(event)==not bool(row.forwarded),"Shared native edit follows original maximum/forwarding policy",row.input)
	dialog.free()
func race_oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)=="ca7e4016c4cbca47afd96dc4d19e6775237924e08060686b2c65577c627003cf","Immutable original Race/Subrace callback evidence")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));check(corpus.binarySha256==ORIGINAL and corpus.rows.size()==384,"384 executions of original Race OK/Cancel/Subrace callback")
	for observation in corpus.rows:
		var input: Dictionary=observation.input;var out: Dictionary=observation.output;var rules=preload("res://systems/native_data/creation_rules.gd").new();var rows: Array=[]
		for id in 8:rows.append({"PlayerRace":"1","Age":str(20+id),"Appearance":str(100+id),"Biography":str(1000+id),"AbilitiesPointBuyNumber":str(int(input.points))})
		rules.tables={"racialtypes":{"orderedRows":rows},"ruleset":{"orderedRows":[{"Label":"CHARGEN_BASE_ABILITY_MIN","Value":str(int(input.minimum))}]}}
		rules.draft={"raceId":int(input.previous),"appearanceType":999,"age":777,"classId":10,"biography":"Old Biography","subrace":"Old Subrace","abilities":{}};rules.creation_base_hp=12;rules.creation_point_budget=77
		for ability in rules.ABILITIES:rules.draft.abilities[ability]=19
		if not input.cancel:
			if input.subrace is String:rules.draft.subrace=str(input.subrace)
			var selected: int=[0,6][int(input.selected)] if int(input.selected) in [0,1] else -1
			var subrace_value: Variant=input.subrace if input.subrace is String else "Old Subrace" if int(input.flag)!=0 else null
			rules.select_race(selected,FixtureText.new(),subrace_value)
		var d: Dictionary=rules.draft
		check(int(d.raceId)==int(out.race) and int(d.appearanceType)==int(out.appearance) and int(d.age)==int(out.age) and int(rules.creation_point_budget)==int(out.points) and d.biography==out.biography and d.subrace==out.subrace,"Actual draft fields match original complete Race callback",input)
		check(rules.ABILITIES.map(func(key):return int(d.abilities[key]))==out.abilities.map(func(value):return int(value)) and int(d.classId)==int(out.classId) and int(rules.creation_base_hp)==int(out.baseHP),"Original raw-ability reset preserves class and base-hit-die cache",input)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","edit-oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	race_oracle(args.oracle)
	edit_oracle(args["edit-oracle"])
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Separate original frame and active draft catalogs mount")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(base.get_resource("cg_race",2047))=="5d1c7fcce1814e932de57a25bacaa90a54e2b3e05a5e8a65d244212d8b792170","Exact pinned original CG_RACE resource")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(base.get_resource("util_editpopup",2047))=="bca0ac612d83a58193f708a9c26dff1db1c5ba628f88bc5dfafb5f4f28dc2a45","Exact pinned original UTIL_EDITPOPUP resource")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original pregame captions use independent base TLK")
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,text,base,"");creator.open(130)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.race.layout_ready and creator.source_frontend.race.subrace.layout_ready,100),"Real native creator, Race and shared edit dialog prepare",creator.source_frontend.race.failure):
		var front=creator.source_frontend;var scope: Array=creator.summary_identity();var pane=front.race
		check(not front.wanted and pane.assets.catalog==base and pane.subrace.assets.catalog==base and front.race_text==ui.text,"Source frames remain pregame-owned; Race text/rules come from the active draft")
		check(pane.plan.row.bounds.size.is_equal_approx(Vector2(324,42)) and pane.plan.row.hooks.next==Vector2(0,44) and pane.plan.help_body.size==Vector2(323,317),"Original class-style Race row and help hooks retain their authored dimensions")
		front.begin(scope,{"classBase":int(creator.rules.draft.classId)},creator.rules.rows("classes"));await frames();await click(front.main.buttons.genderbutton);await click(front.gender.buttons.okbutton);await click(front.main.buttons.racebutton);await frames()
		check(pane.data_text==ui.text and pane.state.entries==front.race_values,"Opening Race binds the active text/choice provider without overriding original frame resources")
		var previous:=int(creator.rules.draft.raceId);var selected:=0
		for index in pane.state.entries.size():
			if int(pane.state.entries[index].id)!=previous:selected=index;break
		await click(pane.row_buttons[selected]);var choice: int=pane.state.selected_race()
		check(choice!=previous and int(creator.rules.draft.raceId)==previous,"Actual Race row previews selection without mutating the draft")
		check(pane.help_title.text==ui.text.raw({"strRef":int(pane.state.entries[selected].title)}) and int(pane.state.entries[selected].title)==creator.rules.num(creator.rules.row("racialtypes",choice),"NamePlural"),"Original selected help title comes from NamePlural rather than ConverName")
		await click(pane.title);check(pane.help_refs==[481,485] and pane.state.selected_race()==choice,"Clicking the original title restores general help without changing selected Race")
		await click(pane.buttons.cancelbutton);check(int(creator.rules.draft.raceId)==previous and not front.flow.completed.race,"Race Cancel leaves the draft and parent completion unchanged")
		await click(front.main.buttons.racebutton);await click(pane.row_buttons[selected]);await click(pane.buttons.subracebutton);await frames()
		check(pane.subrace.wanted and pane.subrace.edit.has_focus() and pane.subrace.title_ref==8185 and pane.subrace.maximum==20,"Actual Subrace opens source UTIL_EDITPOPUP with focus, title and native20-character typing limit")
		pane.subrace.edit.text="Test Subrace";await click(pane.subrace.buttons.cancelbutton)
		check(pane.wanted and not pane.subrace.wanted and str(creator.rules.draft.subrace).is_empty(),"Subrace Cancel returns to Race without a draft text write")
		await click(pane.buttons.subracebutton);pane.subrace.edit.text="Escaped";await key(KEY_ESCAPE)
		check(pane.wanted and not pane.subrace.wanted and str(creator.rules.draft.subrace).is_empty(),"Physical Escape cancels only the focused Subrace modal without committing text")
		await click(pane.buttons.subracebutton);pane.subrace.edit.text="Subrace with old text beyond twenty";var event:=InputEventKey.new();event.keycode=KEY_A;event.unicode=97
		check(pane.subrace.edit.text.length()>20 and pane.subrace.blocked_key(event),"Existing text is retained while the native key-length guard blocks further typing")
		var retained_text: String=pane.subrace.edit.text;pane.subrace.edit.caret_column=retained_text.length();await type_text(pane.subrace.edit,"a")
		check(pane.subrace.edit.text==retained_text,"Physical typing cannot bypass the native length guard on an over-limit existing string")
		event.keycode=KEY_BACKSPACE;event.unicode=0;check(not pane.subrace.blocked_key(event),"Backspace remains available at the original typing limit")
		pane.subrace.edit.text="Chosen Subrace";await key(KEY_ENTER);await frames()
		check(int(creator.rules.draft.raceId)==choice and creator.rules.draft.subrace=="Chosen Subrace" and front.flow.completed.race and front.flow.enabled.portrait and front.child.is_empty(),"Actual Subrace OK immediately commits Race through the live owner and advances CG_MAIN")
		check(creator.rules.draft.abilities.values().all(func(value):return int(value)==creator.rules.cfg("BASE_ABILITY_MIN",8)) and creator.rules.draft.biography==ui.text.raw({"strRef":creator.rules.num(creator.rules.race(),"Biography",4294967295)}),"Real Race commit resets biography and raw abilities from active rules")
		await click(front.main.buttons.racebutton);await click(pane.buttons.recommendbutton);check(pane.state.selected_race()==6,"Recommended picks physical race6")
		var old_ticket: Array=front.ticket.duplicate();pane.capture("okbutton");creator.cancel();creator.open(131);await wait_for(func():return creator.phase=="editing",100);pane.invoke("okbutton");front.race_result(true,choice,"Stale",old_ticket)
		check(creator.summary_identity()!=scope and not front.wanted and creator.rules.draft.subrace!="Stale" and creator.commit_source_race(choice,"Stale",scope).is_empty(),"Old held input, accepted subrace and owner callbacks cannot mutate a new draft")
		# A custom server can hide physical race6. Original Recommended then has
		# no selected row, while accepted Subrace still writes its text/flag.
		var custom: Dictionary=creator.rules.tables.racialtypes.duplicate(true);custom.orderedRows[6].PlayerRace="0";creator.rules.tables.racialtypes=custom;creator.refresh_source();scope=creator.summary_identity()
		front.begin(scope,{"classBase":int(creator.rules.draft.classId)},creator.rules.rows("classes"));await click(front.main.buttons.genderbutton);await click(front.gender.buttons.okbutton);await click(front.main.buttons.racebutton)
		var previous_title: int=pane.state.help_title;await click(pane.buttons.recommendbutton)
		check(pane.state.selected==-1 and pane.state.help_title==previous_title and pane.state.help_description==-1,"Missing physical recommendation6 clears the description but retains original prior title and no selection")
		await click(pane.buttons.subracebutton);pane.subrace.edit.text="Retained Custom";await click(pane.subrace.buttons.okbutton)
		check(pane.wanted and pane.state.selected==-1 and pane.subrace_accepted and creator.rules.draft.subrace=="Retained Custom" and not front.flow.completed.race,"Subrace acceptance without a valid Race writes text but does not fabricate a completed race")
		await click(pane.row_buttons[1]);await click(pane.buttons.okbutton)
		check(creator.rules.draft.subrace=="Retained Custom" and int(creator.rules.draft.raceId)==int(pane.state.entries[1].id) and front.flow.completed.race,"Later valid Race OK preserves an already accepted subrace flag across the changed race")
		await click(front.main.buttons.racebutton);front.bind_races(scope,front.race_values,front.current_race,front.current_subrace,false,ui.text,ui.desktop.art,creator.commit_source_race);await frames()
		var selected_before: int=pane.state.selected;await click(pane.buttons.recommendbutton)
		check(pane.buttons.recommendbutton.disabled and pane.state.selected==selected_before and pane.buttons.recommendbutton.get_child(0).modulate==Color(.5,.5,.5,1),"Server rules can disable Recommended with original gray availability and no action")
		var input_ticket: Array=front.ticket.duplicate();pane.capture("okbutton");ui.text.revision+=1;creator.refresh_source();pane.invoke("okbutton")
		check(front.ticket!=input_ticket and front.child=="racebutton" and pane.wanted,"Active text replacement retickets the open child and rejects a previously held result")
		pane.row_buttons[0].set_pressed_no_signal(true);pane.invoke("race:0")
		check(pane.row_buttons[0].button_pressed==(pane.state.selected==0),"Rejected late radio input restores the actual widget's checked state")
		surface.size=Vector2i(512,400);await frames();front.place();var prior_draft:=int(creator.rules.draft.raceId)
		await click(pane.row_buttons[0]);check(pane.scale.x<1 and pane.state.selected_race()==int(pane.state.entries[0].id) and int(creator.rules.draft.raceId)==prior_draft,"Actual source row input stays aligned after viewport scaling without mutating the draft")
		await key(KEY_ESCAPE);check(front.child.is_empty() and front.wanted and creator.phase=="editing" and int(creator.rules.draft.raceId)==prior_draft,"Physical Race Escape returns result2 to its parent without cancelling the whole creator")
		# Model the later parent state, then reaccept the same race through its
		# physical control: the original reset is unconditional, not ID-change-only.
		front.flow.enabled.packages=true;front.flow.completed["class"]=true;creator.rules.draft.skills={0:1};creator.rules.draft.feats=[{"id":1,"kind":"normal"}];creator.rules.draft.domains=[1,2];creator.rules.skill_summary_mask=7
		creator.rules.draft.biography="Edited biography";await click(front.main.buttons.racebutton);await click(pane.buttons.okbutton)
		check(creator.rules.draft.skills.is_empty() and creator.rules.draft.feats.is_empty() and creator.rules.draft.domains.is_empty() and creator.rules.skill_summary_mask==0 and not front.flow.completed["class"] and front.flow.enabled.portrait,"Same-race acceptance resets actual derived choices and invalidates completed parent steps when Packages was enabled")
		check(creator.rules.draft.biography==ui.text.raw({"strRef":creator.rules.num(creator.rules.race(),"Biography",4294967295)}),"Same-race acceptance restores original biography through the actual owner")
		var retiring:=func(selected_id,_subrace,_identity):front.dismiss();return {"accepted":true,"race":selected_id,"subrace":"Late","code":0x800a}
		front.bind_races(scope,front.race_values,front.current_race,front.current_subrace,true,ui.text,ui.desktop.art,retiring);await click(front.main.buttons.racebutton);await click(pane.buttons.okbutton)
		check(not front.wanted and creator.rules.draft.subrace!="Late" and front.current_subrace!="Late","A reentrant owner retirement rejects an otherwise valid Race result before parent advancement")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Inspection does not fabricate a character upload or server acceptance")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"sourceArtworkDouble":true,"scope":"384 original Race/Subrace callbacks,325 original ASCII key-guard executions, exact GUI resources and real source control/draft input: mouse, Enter/Escape, title help, missing/disabled recommendation, accepted-subrace flag, same-race resets, scaled input, data replacement and stale/reentrant retirement. Headless artwork/font doubles; complete source creator activation, clipboard/composition/further key routing, existing-BIC preservation and exact pixels remain open. Authoritative upload is checked separately by the owned local probe."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
