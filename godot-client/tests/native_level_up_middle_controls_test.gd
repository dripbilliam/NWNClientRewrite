extends "res://tests/native_level_up_source_controls_test.gd"
const Frontend=preload("res://systems/native_level_up_frontend.gd")
const SkillState=preload("res://systems/native_data/level_up_skill_state.gd")
const FeatState=preload("res://systems/native_data/level_up_feat_state.gd")
const Navigation=preload("res://systems/native_data/level_up_navigation.gd")
const PrivateVitals=preload("res://systems/native_data/level_up_vitals.gd")
var front
var skills:=SkillState.new()
var feats:=FeatState.new()
var nav:=Navigation.new()
var active: Dictionary={}
var received: Dictionary={}
var accepted: Array=[]
var cancelled: Array=[]
var submits: Array=[]
func gate(value: bool,label: String) -> bool:
	check(value,label);return value
func ready(predicate: Callable) -> bool:
	var until:=Time.get_ticks_msec()+22000
	while Time.get_ticks_msec()<until:
		if predicate.call():return true
		await process_frame
	return false
func key_event(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;surface.push_input(event,true);await frames()
func changed(stage: String,operation: String,id: int,identity: Array) -> void:
	if not front.owns(identity):return
	if stage=="skills":
		if operation in ["up","down"]:skills.move(id,1 if operation=="up" else -1,active)
		front.update_middle(stage,skills.compose(active,active_text),front.scope)
	elif stage=="feats":front.update_middle(stage,feats.act(operation,id,active,active_text),front.scope)
func navigation_cases() -> void:
	var route:=Navigation.new();var begin:=route.begin([77,1]);var old: Array=begin.ticket.duplicate()
	var advanced:={"ready":true,"current":1,"classes":[{"id":0,"level":3},{"id":1,"level":1}],"level":4}
	check(route.after_class(old,advanced).stage=="attributes","Original total4 enters the one-point attribute child for a new class")
	check(not route.after_attributes(route.ticket,-1).ready and route.stage=="attributes","Missing required private ability choice cannot skip Attributes")
	check(route.after_attributes(route.ticket,5).stage=="skills" and not route.after_class(old,advanced).ready,"Attributes advances once; stale Class callback cannot replace Skills")
	var table:={"classes":{"orderedRows":[{}, {"PickDomains":"1","PickSchool":"1","SpellbookRestricted":"1","SkipSpellSelection":"0","MinAssociateLevel":"1","Arcane":"1"}]}}
	check(route.after_skills(route.ticket,{"normal":0,"bonus":0},table).stage=="domains","Zero original feat counters skip Feats and new-class1 opens Domains")
	for expected in ["school","spells","associate","summary"]:
		var previous:=route.ticket.duplicate();var result:=route.after_child(previous,table)
		check(result.ready and result.stage==expected,"Mode1 original post-feat child order: "+expected)
		check(not route.after_child(previous,table).ready,"Retired child ticket cannot advance the next original stage: "+expected)
	check(route.submit(route.ticket).send and not route.submit(route.ticket).send,"Original Summary sends exactly once in the private navigation owner")
	var cancel:=route.cancel(route.ticket);check(cancel.cancel and cancel.submissionPending and not route.wanted,"Cancel retires UI while retaining pending-submission distinction")
	begin=route.begin([78,1]);route.after_class(begin.ticket,{"ready":true,"current":0,"classes":[{"id":0,"level":2}],"level":3})
	check(not route.after_skills(route.ticket,{"normal":0,"bonus":0},{"classes":{"orderedRows":[{}]}}).ready and route.stage=="post","Missing active post-feat metadata has a distinct cancellable pending stage")
	var retry: Array=route.ticket.duplicate();table={"classes":{"orderedRows":[{"SpellbookRestricted":"0","MinAssociateLevel":"255"}]}}
	check(route.retry_post(retry,table).stage=="summary","Retry reads current active rules and skips first-level-only Domains/School for class2")
	check(not route.cancel(retry).cancel,"Retired preparation callback cannot close the replacement Summary")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	navigation_cases()
	catalog=Catalog.new();check(catalog.mount_install(args.install),"Read-only original Skills/Feats/Summary resources mount")
	base_text=preload("res://systems/native_data/talk_text.gd").new();active_text=preload("res://systems/native_data/talk_text.gd").new()
	check(base_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")) and active_text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original captions and active custom TLK use separate owners")
	active_text.overrides[100]="Custom current skill";active_text.overrides[101]="Custom level feat"
	surface=SubViewport.new();surface.size=Vector2i(1200,850);surface.disable_3d=true;surface.handle_input_locally=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	painter=Painter.new();painter.art=Art.new();painter.fonts=Doubles.HeadlessFonts.new();painter.add_child(painter.art);painter.add_child(painter.fonts);painter.art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	front=Frontend.new();surface.add_child(front);front.configure(painter,base_text,catalog,"");front.action_requested.connect(changed)
	front.accepted.connect(func(stage,id,identity):accepted.append([stage,id,identity.duplicate()]))
	front.cancelled.connect(func(identity):cancelled.append(identity.duplicate()))
	front.submit_requested.connect(func(identity):submits.append(identity.duplicate()))
	active={"classes":{"orderedRows":[{"SkillsTable":"server_skills","FeatsTable":"server_feats","AttackBonusTable":"server_bab","SkillPointBase":"2","PickDomains":"0","PickSchool":"0","SpellbookRestricted":"0","SkipSpellSelection":"0","MinAssociateLevel":"255","Arcane":"0"}]},"racialtypes":{"orderedRows":[{"NormalFeatEveryNthLevel":"3","NumberNormalFeatsEveryNthLevel":"1"}]},"ruleset":{"orderedRows":[]},"skills":{"orderedRows":[{"Name":"100","Description":"200","KeyAbility":"STR","Untrained":"1","AllClassesCanUse":"1"}]},"server_skills":{"orderedRows":[{"SkillIndex":"0","ClassSkill":"1"}]},"server_feats":{"orderedRows":[]},"server_bab":{"orderedRows":[{"BAB":"1"},{"BAB":"2"},{"BAB":"30"}]},"feat":{"orderedRows":[{"Feat":"99","AllClassesCanUse":"1"},{"Feat":"101","Description":"201","AllClassesCanUse":"1","MinAttackBonus":"22","Icon":"if_powerattack"}]}}
	received={"race":0,"classes":[{"id":0,"level":2}],"baseAbilities":[12,12,14,14,12,12],"skills":[1],"fieldDC6":0,"feats":[0]}
	var saved:=received.duplicate(true);var started:=nav.begin([91,7]);var next:=nav.after_class(started.ticket,PrivateVitals.project(received,0,-1,active))
	check(next.ready and next.stage=="skills" and skills.configure(received,0,-1,active),"Original new-total3 skips Attributes and prepares separate mode1 rank baseline")
	front.present_middle("skills",skills.compose(active,active_text),false,active_text,painter.art,nav.ticket)
	if gate(await ready(func():return front.panes.skills.layout_ready),"Actual original mode1 Skills controls finish resource workers"):
		var pane=front.panes.skills
		check(pane.plan.size==Vector2(742,526) and pane.row_buttons.size()==1 and pane.ranks[0].text=="1" and pane.points.text=="4","Original control geometry displays received entry ranks and private next-level points")
		check(pane.row_buttons[0].get_child(0).text.begins_with("Custom current skill") and pane.buttons.recommendbutton.disabled,"Physical skill name comes from active TLK; unavailable mode1 recommendation is explicitly disabled")
		await click(pane.buttons["up:0"])
		check(skills.ranks==[2] and skills.changes()==[1] and pane.ranks[0].text=="2" and pane.points.text=="3","Actual mode1 arrow edits only the private rank and carried point display")
		await click(pane.buttons["down:0"]);await click(pane.buttons["down:0"])
		check(skills.ranks==[1] and pane.ranks[0].text=="1","Actual decrement refunds own edit and cannot spend the received rank baseline")
		await click(pane.buttons["up:0"]);await click(pane.buttons.okbutton)
		check(accepted.size()==1 and accepted[-1][0]=="skills" and not pane.wanted,"Real Skills OK transfers scoped acceptance rather than completing the level-up")
		feats.configure(received,0,-1,skills.ranks,{"baseFortitude":0});var feat_model:=feats.model(active,active_text)
		next=nav.after_skills(nav.ticket,{"normal":feat_model.normal,"bonus":feat_model.bonus},active)
		check(next.ready and next.stage=="feats" and feat_model.ready,"Original total-level feat slots route into mode1 Feats")
		front.present_middle("feats",feat_model,false,active_text,painter.art,nav.ticket)
		if gate(await ready(func():return front.panes.feats.layout_ready and front.panes.feats.info_popup.layout_ready and front.panes.feats.group_popup.layout_ready),"Actual original Feats/group/info controls finish resource workers"):
			var feat_pane=front.panes.feats
			check(feat_pane.rows.available.size()==1 and feat_pane.model.available[0].id==1 and feat_pane.rows.available[0].get_child(0).text=="Custom level feat" and feat_pane.remaining.text=="1","Mode1 source view uses original lists with custom IDs/TLK and new-level BAB eligibility")
			await click(feat_pane.buttons["available:0:arrow"])
			check(feats.selected==[1] and feat_pane.model.known[-1].id==1 and feat_pane.remaining.text=="0" and not feat_pane.buttons.okbutton.disabled,"Actual add arrow spends the private original feat slot")
			var old: Array=front.ticket.duplicate();front.middle_action("remove",1,old,"skills")
			check(feats.selected==[1],"A stale other-stage callback cannot edit the current mode1 feat choice")
			await click(feat_pane.buttons.okbutton);next=nav.after_feats(nav.ticket,feats.validate(active,active_text),active)
			check(accepted.size()==2 and accepted[-1][0]=="feats" and next.ready and next.stage=="summary","Original Feats OK validates private choices and follows mode1 post-feat routing to Summary")
			front.present_summary("Private original level-up summary",true,nav.ticket)
			if gate(await ready(func():return front.panes.summary.layout_ready),"Original final Summary source controls prepare lazily"):
				await click(front.panes.summary.buttons.okbutton);await click(front.panes.summary.buttons.okbutton)
				var sent:=nav.submit(nav.ticket);check(submits.size()==1 and sent.send and not nav.submit(nav.ticket).send and front.panes.summary.wanted,"Physical final Summary sends once and stays open; local send is not a server acknowledgment")
				await click(front.panes.summary.buttons.cancelbutton);var cancellation:=nav.cancel(nav.ticket)
				check(cancelled.size()==1 and cancellation.cancel and cancellation.submissionPending and not cancellation.serverAcknowledged,"Summary Cancel preserves distinction between closing UI and pending original submission")
		# Pending data still has a safe real Cancel/Escape route. These wrappers
		# never alter the shared creation chooser's busy/reset semantics.
		front.present_middle("skills",{"ready":false},false,active_text,painter.art,[92,1]);await frames()
		check(front.panes.skills.buttons.okbutton.disabled and not front.panes.skills.buttons.cancelbutton.disabled,"Unavailable mode1 skill rows stay inactive while Cancel remains usable")
		await click(front.panes.skills.buttons.cancelbutton);check(cancelled.size()==2,"Physical Cancel retires unavailable mode1 skill preparation")
		front.present_middle("feats",{"ready":false},false,active_text,painter.art,[93,1]);await frames();await key_event(KEY_ESCAPE)
		check(cancelled.size()==3 and not front.panes.feats.wanted,"Escape retires unavailable mode1 Feats without a selection/actor write")
	check(received==saved,"The composed source-control chain never mutates received classes/feats/ranks/abilities")
	front.close();front.free();painter.art.close();painter.close();painter.queue_free();base_text.close();active_text.close();await frames(5);surface.queue_free();await frames()
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"runtimeIntegrated":false,"scope":"Actual installed Skills/Feats/Summary controls and worker publication through staged mode1 frontend/private adapters, physical input and pending/cancel boundaries. No runtime entry, class-dependent source child adapters, server save or pixels accepted."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
