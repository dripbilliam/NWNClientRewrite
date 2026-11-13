extends "res://tests/native_level_up_recommended_test.gd"
const Dependencies=preload("res://systems/native_data/level_up_class_dependencies.gd")
var class_events: Array=[]
var case_mode:=""
var case_tables: Dictionary={}
var target_class:=-1
var foreign_catalog
var public_race_name:=""
func find_class(table: Dictionary,label: String) -> int:
	for id in table.orderedRows.size():
		if str(table.orderedRows[id].get("Label","")).to_lower()==label:return id
	return -1
func class_pressed() -> void:
	if not private_owner.class_preparing:return
	var pane=front.panes["class"];var ticket: Array=front.ticket.duplicate();var selected: int=pane.state.selected_class();var stream=runtime.hit_die_owner.stream
	var event:={"mode":case_mode,"ticket":ticket,"request":runtime.recommendation_work.serial,"pending":private_owner.class_preparing,"committed":private_owner.class_id,"selected":selected,"initialEmpty":private_owner.initial_tables.is_empty(),"cancel":not pane.buttons.cancelbutton.disabled,"ok":not pane.buttons.okbutton.disabled,"rowsDisabled":pane.row_buttons.all(func(row):return row.disabled),"draws":stream.draws}
	# Source UI stays on this same ticket while partial tables publish. None
	# of these repeated/synthetic actions can commit a second class choice.
	pane.complete(true);private_owner.accepted("class",3,ticket);private_owner.show_class()
	if case_mode=="good":
		var parser:=TwoDa.new();var published:=parser.parse(catalog.get_resource(public_race_name,2017).get_string_from_ascii());active_text.publish_table(public_race_name,published)
		active_text.publish_table("lvc_unrelated",{"orderedRows":[]});runtime.table_published(-1,{})
	event.sameTicket=front.ticket==ticket and pane.scope==ticket;event.sameSelection=pane.state.selected_class()==selected and private_owner.pending_class_id==selected;class_events.append(event)
	if case_mode=="cancel":key_escape.call_deferred()
	elif case_mode=="catalog":
		foreign_catalog=Catalog.new();desktop.owner_ui.catalog=foreign_catalog;runtime.table_published(-1,{})
func open_target(begin: Dictionary,token: int,active: Dictionary) -> bool:
	active_text.tables=active;var value:=begin.duplicate(true);value.token=token;value.available.fill(false);value.available[target_class]=true;value.available[3]=true
	panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	if not await ready("class"):return false
	var pane=front.panes["class"]
	for index in pane.state.entries.size():
		if int(pane.state.entries[index].id)==target_class:await click(pane.row_buttons[index]);break
	if not pane.buttons.okbutton.pressed.is_connected(class_pressed):pane.buttons.okbutton.pressed.connect(class_pressed)
	return pane.state.selected_class()==target_class
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,raw_tables: Dictionary) -> void:
	cancel_on_press=false
	target_class=find_class(raw_tables.classes,"fighter");check(target_class>=0,"Actual installed class label resolves the newly selected Fighter physical ID")
	var active:=raw_tables.duplicate(true)
	# Source runtime privately compiles raw flags. This local list only records
	# the actual selected class resource names; no table bodies are authored.
	var target_names: Array=[]
	for field in ["SkillsTable","FeatsTable","AttackBonusTable","BonusFeatsTable"]:
		var name:=str(active.classes.orderedRows[target_class].get(field,"")).to_lower()
		if name not in ["","****"]:target_names.append(name)
	check(target_names.all(func(name):return not active.has(name)),"New class named tables are genuinely absent from the received/global map")
	public_race_name=str(target_names[0])
	case_mode="good";case_tables=active
	if gate(await open_target(begin,120,active),"Actual source Class permits physical Fighter selection before its named tables are loaded"):
		var pane=front.panes["class"];await click(pane.buttons.okbutton)
		if gate(await ready("attributes"),"Scoped actual class workers complete and enter the correct total-level4 Attributes"):
			check(private_owner.class_id==target_class and private_owner.class_diagnostics.work.resources.size()>0 and target_names.all(func(name):return runtime.tables.has(name) and private_owner.initial_tables.has(name)),"Selected class and immutable rule capture commit only after all real named tables publish")
			check(target_names.all(func(name):return name==public_race_name or not active.has(name)) and active.has("lvc_unrelated") and is_same(runtime.tables[public_race_name],active[public_race_name]),"Private class jobs preserve an authoritative publication race and unrelated data without overwriting the canonical map")
			await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
			if gate(await ready("skills"),"New class enters actual usable Skills without generic fallback"):
				check(panel.source_active and not panel.visible and private_owner.skills.resources_ready and private_owner.skills.class_id==target_class and private_owner.skills.points==4,"Skills has the newly selected class's real budget and mode1 readiness")
				await click(front.panes.skills.buttons.recommendbutton)
				check(await wait_for(func():return not private_owner.recommendation_pending) and private_owner.recommendation_diagnostics.has("skills"),"The same ResourceWork serial can serve a later recommendation after Class preparation")
		await key_escape()
	var first: Dictionary=class_events[0] if not class_events.is_empty() else {}
	check(first.get("pending",false) and first.committed==-1 and first.initialEmpty and first.cancel and not first.ok and first.rowsDisabled and first.sameTicket and first.sameSelection,"Busy Class keeps the exact selection/ticket and Cancel while blocking rows/duplicate/synthetic OK and premature commit")
	# Use a distinct declared absent dependency to exercise failed-read behavior
	# independently of successful immutable source caches.
	var failed:=raw_tables.duplicate(true);failed.classes=Fixtures.row_update(failed.classes,target_class,{"SkillsTable":"lvc_absent"});case_mode="failed"
	if gate(await open_target(begin,121,failed),"A new selected-class resource failure is prepared under its own transaction"):
		await click(front.panes["class"].buttons.okbutton)
		if gate(await wait_for(func():return not private_owner.class_preparing and not private_owner.class_error.is_empty()),"Missing required table completes as explicit native Class error"):
			var pane=front.panes["class"]
			check(front.stage=="class" and pane.wanted and pane.state.selected_class()==target_class and private_owner.class_id==-1 and panel.source_active and not panel.visible and not runtime.recommendation_work.wanted and not runtime.tables.has("lvc_absent") and not pane.buttons.cancelbutton.disabled,"Failed class preparation ends its job, preserves selection/native Class and never publishes a fake empty table or generic fallback")
			for index in pane.state.entries.size():
				if int(pane.state.entries[index].id)==3:await click(pane.row_buttons[index]);break
			active_text.publish_table("lvc_unrelated2",{"orderedRows":[]});runtime.table_published(-1,{})
			check(front.panes["class"].state.selected_class()==3,"Unrelated accepted publication preserves the user's changed physical class selection after failure")
			await click(pane.buttons.okbutton);check(await ready("attributes") and private_owner.class_id==3,"User can choose another available class after resource failure without a second begin")
		await key_escape()
	case_mode="cancel";var cancelled_request:=-1;var cancelled_ticket: Array=[]
	if gate(await open_target(begin,122,raw_tables.duplicate(true)),"Class preparation reopens after prior transactions"):
		await click(front.panes["class"].buttons.okbutton)
		check(await wait_for(func():return not panel.wanted) and not runtime.active,"Physical Escape cancels pending selected-class preparation")
		var event: Dictionary=class_events[-1];cancelled_request=int(event.request);cancelled_ticket=event.ticket;check(event.draws==first.draws,"Class resource preparation never consumes the hit-die random stream")
	case_mode="reopen"
	if gate(await open_target(begin,123,raw_tables.duplicate(true)),"Reopened native Class has a fresh owned ticket"):
		runtime.recommendation_work.completed.emit("class",{"ready":true},cancelled_request,cancelled_ticket)
		check(front.stage=="class" and private_owner.class_id==-1 and not private_owner.class_preparing,"Retired class-resource completion cannot commit a class in the new transaction")
		await key_escape()
	case_mode="catalog"
	if gate(await open_target(begin,124,raw_tables.duplicate(true)),"Fresh Class opens before catalog retirement case"):
		await click(front.panes["class"].buttons.okbutton);check(await wait_for(func():return not panel.wanted) and not runtime.active,"Catalog replacement cancels native class preparation without applying stale data or entering the generic editor")
		desktop.owner_ui.catalog=catalog;foreign_catalog=null
	check(received==before and desktop.commands.all(func(command):return command.operation!="submit"),"Class preparation lifecycle preserves received state and never sends a partial level-up")
	active_text.tables=raw_tables;observations.append({"kind":"selected-class-dependency-preparation","events":class_events})
