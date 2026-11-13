extends "res://tests/native_creation_gender_test.gd"
const SkillState=preload("res://systems/native_data/creation_skill_state.gd")
const SkillSummary=preload("res://systems/native_data/creation_skill_summary.gd")
const SkillOracle=preload("res://tests/native_creation_skill_points_test.gd")
func enter_skills(creator) -> bool:
	var front=creator.source_frontend
	front.flow.enabled.packages=true;front.refresh();await click(front.main.buttons.packagesbutton);await click(front.packages.buttons.configurepckg)
	return await wait_for(func():return creator.phase=="editing" and front.child=="package-configuration" and front.skills.wanted and front.skills.layout_ready,90)
func row_for(pane,class_skill: bool) -> int:
	for index in pane.model.entries.size():
		var entry: Dictionary=pane.model.entries[index]
		if entry.enabled and entry.classSkill==class_skill:return index
	return -1
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	SkillOracle.verify_oracle(args.oracle,check)
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Independent original artwork and active skill-rule catalogs mount")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();text.base.open_file(args.install.path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,text,base,"");creator.open(181)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.skills.layout_ready,90),"Actual native creator and original Skills models prepare"):
		var front=creator.source_frontend;var pane=front.skills;var scope: Array=creator.summary_identity();var wizard:=-1
		for id in creator.rules.rows("classes").size():
			if str(creator.rules.cell(creator.rules.row("classes",id),"Label","")).to_lower()=="wizard":wizard=id
		check(wizard>=0,"The active class table supplies the Wizard test fixture")
		creator.rules.select_class(wizard);creator.rules.recommend_abilities();creator.render();front.begin(scope,{"classBase":wizard},creator.rules.rows("classes"))
		if check(await enter_skills(creator),"Configure Package opens the real original Skills view without completing Package"):
			check(pane.assets.catalog==base and pane.data_text==ui.text and pane.plan.size.is_equal_approx(Vector2(742,526)) and pane.plan.entries.size()==12,"Original frame size and all nested controls survive the unused empty off-frame label")
			check(pane.selected==-1 and pane.cost.text.is_empty() and pane.help.current.slice(1)==[58250,58251] and pane.points.text==str(creator.rules.skill_balance()),"Original initial Skills state has no selected row, general help and blank cost")
			check(pane.help.title.vertical_alignment==VERTICAL_ALIGNMENT_CENTER and not pane.plan.entries.helpbox.model.hooks.has("icon"),"Original help title uses its constructor alignment and shipped help model has no Icon attachment")
			check(pane.row_buttons.size()==pane.model.entries.size() and pane.model.entries.all(func(entry):return creator.rules.num(creator.rules.row("skills",entry.id),"HideFromLevelUp")==0),"Only visible physical skills become source row controls")
			var ordered:=true
			for index in range(1,pane.model.entries.size()):ordered=ordered and SkillState.compare(pane.model.entries[index-1].name,pane.model.entries[index].name)<=0
			check(ordered and SkillState.compare("A","a")==0 and SkillState.compare("Z","a")>0,"Original legacy case-insensitive ordering is retained")
			var pending_index:=row_for(pane,true)
			if check(pending_index>=0,"A real class skill is available for dependency retirement"):
				var pending_id: int=pane.model.entries[pending_index].id;pane.list.ensure_control_visible(pane.row_buttons[pending_index]);await frames()
				var old_row: int=pane.row_buttons[pending_index].get_instance_id();var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=pane.buttons["up:"+str(pending_id)].get_global_rect().get_center();event.global_position=event.position;event.pressed=true;surface.push_input(event,true);pane.set_process(false)
				var old_geometry: Array=[old_row,pane.buttons["up:"+str(pending_id)].get_instance_id(),pane.buttons["down:"+str(pending_id)].get_instance_id()]
				check(old_geometry.all(func(id):return painter.button_geometry.has(id)),"Actual source row and both arrows are registered with the shared artwork painter before retirement")
				check(int(creator.rules.draft.skills.get(pending_id,0))==1 and pane.repeat_clock.active,"A physical held source arrow is active before its dependency disappears")
				var dependency: String=str(creator.rules.cell(creator.rules.cls(),"SkillsTable","")).to_lower();var saved: Dictionary=creator.rules.tables[dependency];creator.rules.tables.erase(dependency);creator.refresh_source()
				check(not pane.model.get("ready",false) and pane.row_buttons.is_empty() and pane.buttons.size()==3 and pane.buttons.values().all(func(button):return button.disabled) and not pane.repeat_clock.active,"Unpublished active rules retire old row controls and held repeat instead of indexing empty entries")
				check(pane.points.text.is_empty() and pane.cost.text.is_empty() and pane.help.title.text.is_empty() and pane.help.body.get_parsed_text().is_empty() and pane.help_icon_resource.is_empty(),"Pending skill rules clear prior rule-derived numbers, help and icon state")
				check(not old_geometry.any(func(id):return painter.button_geometry.has(id)),"Freed source row and arrow controls retire their shared painter geometry registrations")
				for resource in ["ctl_cg_btn_skill","ctl_cg_btn_skup","ctl_cg_btn_skdn"]:painter.art_loaded("gui:"+resource+":late-retirement-regression",null,{})
				check(pane.row_buttons.is_empty() and not old_geometry.any(func(id):return painter.button_geometry.has(id)),"Actual delayed source-model artwork publication cannot access or restore retired Skills controls")
				pane.invoke("up:"+str(pending_id));pane.advance_repeat(1000000);event.pressed=false;surface.push_input(event,true);await frames();check(int(creator.rules.draft.skills.get(pending_id,0))==1,"A retired held arrow cannot apply a late rank after dependency loss")
				# The view may also receive pending context before its text provider.
				pane.set_context({"ready":false,"entries":[],"details":{}},true,null,ui.desktop.art,front.ticket);creator.rules.tables[dependency]=saved;creator.refresh_source()
				check(pane.model.get("ready",false) and not pane.row_buttons.is_empty() and pane.row_buttons[pending_index].get_instance_id()!=old_row and pane.selected==-1 and pane.cost.text.is_empty() and pane.help.current.slice(1)==[58250,58251] and pane.points.text==str(creator.rules.skill_balance()),"Republished rules restore fresh rows/general help after pending context without stale text or input")
				creator.rules.reset_source_choices();creator.refresh_source()
			var index:=row_for(pane,true);check(index>=0,"Source skill rows include an allowed class skill")
			if index>=0:
				var entry: Dictionary=pane.model.entries[index];var id:=int(entry.id);pane.list.ensure_control_visible(pane.row_buttons[index]);await frames();await click(pane.row_buttons[index])
				check(pane.selected==index and pane.cost.text=="1" and pane.help.title.text==ui.text.raw({"strRef":entry.title}) and pane.help.body.get_parsed_text().begins_with(ui.text.raw({"strRef":6597})+": 0\n"),"Physical source row selection displays original rank/modifier/check help and active description")
				check(pane.row_buttons[index].get_child(0).text.ends_with(ui.text.raw({"strRef":52951})) and pane.help_icon_resource==entry.icon,"Class-skill suffix and requested icon come from active data")
				var row_identity: int=pane.row_buttons[index].get_instance_id();var old_ticket: Array=front.ticket.duplicate();var points: int=creator.rules.skill_balance();await click(pane.buttons["up:"+str(id)])
				check(int(creator.rules.draft.skills.get(id,0))==1 and creator.rules.skill_balance()==points-1 and pane.ranks[index].text=="1" and pane.points.text==str(points-1),"Actual source arrow edits the live rank, remaining WORD and number labels")
				check(pane.row_buttons[index].get_instance_id()==row_identity and front.ticket==old_ticket,"Own numeric edits retain the source row and committing input ticket")
				var button: Button=pane.buttons["up:"+str(id)];var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=button.get_global_rect().get_center();event.global_position=event.position;event.pressed=true;surface.push_input(event,true);pane.set_process(false)
				check(int(creator.rules.draft.skills[id])==2 and pane.repeat_clock.active,"Physical timer press selects and increments immediately")
				pane.advance_repeat(500000);check(int(creator.rules.draft.skills[id])==2,"First repeat uses the original strict500ms threshold")
				pane.advance_repeat(1);check(int(creator.rules.draft.skills[id])==3,"First eligible repeat edits the live draft")
				pane.advance_repeat(50000);check(int(creator.rules.draft.skills[id])==3,"Periodic repeat uses the original strict50ms threshold")
				pane.advance_repeat(1);event.pressed=false;surface.push_input(event,true);await frames();check(int(creator.rules.draft.skills[id])==4 and not pane.repeat_clock.active,"Repeat reaches the original class cap and release adds no duplicate rank")
				creator.rules.draft.feats=[{"id":0,"kind":"normal"}];creator.rules.draft.known={1:[1]};creator.rules.draft.memorized={1:[1]};creator.rules.draft.domains=[1,2]
				var help_before: String=pane.help.body.get_parsed_text();var cost_before: String=pane.cost.text;await click(pane.buttons.recommendbutton)
				check(await wait_for(func():return creator.phase=="editing" and not pane.busy,90),"Recommended finishes through the real native preference loader")
				check(pane.help.body.get_parsed_text()==help_before and pane.cost.text==cost_before and creator.rules.draft.skills.size()>0,"Original Recommended refreshes rank/point labels while retaining displayed help and cost")
				check(creator.rules.draft.feats==[{"id":0,"kind":"normal"}] and creator.rules.draft.known=={1:[1]} and creator.rules.draft.memorized=={1:[1]} and creator.rules.draft.domains==[1,2],"Skill recommendation preserves unrelated feat/spell/domain choices")
			var abilities: Dictionary=creator.rules.draft.abilities.duplicate();await click(pane.buttons.cancelbutton)
			check(front.child.is_empty() and not front.flow.completed.packages and creator.rules.draft.skills.is_empty() and creator.rules.draft.feats.is_empty() and creator.rules.draft.known.is_empty() and creator.rules.draft.domains.is_empty() and creator.rules.draft.abilities==abilities,"Original Skills Cancel resets derived choices and returns3 without discarding ability allocation")
			check(await enter_skills(creator),"The source Skills view reopens through Package")
			await key(KEY_ESCAPE);check(front.child.is_empty() and creator.rules.draft.skills.is_empty(),"Escape uses the same creation reset/result as Cancel")
			check(await enter_skills(creator),"A fresh source Skills entry has a fresh action scope")
			index=row_for(pane,false)
			if check(index>=0,"An active cross-class skill is available"):
				var id: int=pane.model.entries[index].id;pane.list.ensure_control_visible(pane.row_buttons[index]);await frames();var points: int=creator.rules.skill_balance();await click(pane.buttons["up:"+str(id)])
				check(creator.rules.skill_balance()==points-2 and pane.cost.text=="2" and int(creator.rules.draft.skills[id])==1,"Physical cross-class arrow selects its row and spends the active cost2")
				await click(pane.buttons["down:"+str(id)]);check(int(creator.rules.draft.skills[id])==0 and creator.rules.skill_balance()==points,"Down refunds the active cost and does not cross creation's zero baseline")
				var old: Array=front.ticket.duplicate();pane.capture("up:"+str(id));ui.text.revision+=1;creator.refresh_source();pane.invoke("up:"+str(id));check(front.ticket!=old and int(creator.rules.draft.skills.get(id,0))==0 and pane.repeat_tag.is_empty(),"Active text replacement retires held skill edits and repeat state")
				index=row_for(pane,false);pane.list.ensure_control_visible(pane.row_buttons[index]);await frames();creator.jobs[-718]={"kind":"test-barrier"};old=front.ticket.duplicate();await click(pane.buttons.recommendbutton)
				check(creator.phase=="skills-preparing" and pane.busy and pane.buttons.cancelbutton.disabled,"Pending skill recommendation suspends duplicate input")
				ui.text.revision+=1;await frames(4);creator.jobs.erase(-718)
				check(await wait_for(func():return creator.phase=="editing" and not pane.busy,30) and front.ticket!=old and int(creator.rules.draft.skills.get(id,0))==0,"Text replacement during actual pending work prevents late preference writes")
				surface.size=Vector2i(512,400);await frames();front.place();index=row_for(pane,false);pane.list.ensure_control_visible(pane.row_buttons[index]);await frames();await click(pane.buttons["up:"+str(id)])
				check(pane.scale.x<1 and int(creator.rules.draft.skills[id])==1,"Original skill arrow hit regions remain aligned under scaling")
			front.flow.completed.packages=false;var slots: Dictionary=creator.rules.feat_slots();var expected:=SkillSummary.calculate(SkillSummary.source(creator.rules),creator.rules.tables);await click(pane.buttons.okbutton)
			check(front.child==("package-feats" if int(slots.normal)!=0 or int(slots.bonus)!=0 else "package-post-skills") and not pane.wanted and not front.flow.completed.packages and creator.rules.skill_summary_mask==int(expected.mask),"Skills OK commits eligibility and transfers to the original next-stage route without premature Package completion")
			front.retire_child();front.flow.enabled.packages=true;front.refresh();surface.size=Vector2i(1600,1000);await frames();check(await enter_skills(creator),"Skills can be revisited after a staged downstream handoff")
			index=row_for(pane,true)
			if index>=0:
				var id: int=pane.model.entries[index].id;pane.list.ensure_control_visible(pane.row_buttons[index]);await frames();front.bind_skills(scope,front.skills_context,true,ui.text,ui.desktop.art,func(_operation,_id,_identity,_ticket):front.dismiss();return {"ready":true},creator.commit_source_skills);await click(pane.buttons["up:"+str(id)])
				check(not front.wanted and creator.rules.draft.skills.is_empty(),"Reentrant draft retirement rejects a late skill result")
			creator.cancel();creator.open(182);await wait_for(func():return creator.phase=="editing",90)
			check(creator.summary_identity()!=scope and creator.commit_source_skills(true,scope).is_empty(),"Retired skill commits cannot affect a replacement connection draft")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Headless source inspection never fabricates a character upload")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"sourceArtworkDouble":true,"scope":"Original144 allocation cases plus real source Skills models, physical row/arrows/repeat, live draft, recommendation/reset/OK, scaling and scoped retirement. Unported downstream children, original pixels/help-icon attachment and authoritative upload remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
