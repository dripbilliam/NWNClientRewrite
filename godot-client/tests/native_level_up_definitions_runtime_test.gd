extends "res://tests/native_level_up_recommended_test.gd"
const PlainTables=preload("res://systems/native_data/creation_feat_tables.gd")
const PrivateSnapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
var cache_observations: Array=[]
func label_id(table: Dictionary,label: String) -> int:
	for id in table.get("orderedRows",[]).size():
		if str(table.orderedRows[id].get("Label","")).to_lower()==label:return id
	return -1
func open_cache_case(begin: Dictionary,active: Dictionary,id: int,token: int,level: int=3) -> bool:
	active_text.tables=active;var value:=begin.duplicate(true);value.token=token;value.snapshot.classes=[{"id":id,"level":level,"school":0}];value.snapshot.feats=[40.0];value.available.fill(false);value.available[id]=true
	panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	return await ready("class")
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,raw_tables: Dictionary) -> void:
	cancel_on_press=false
	var fighter:=label_id(raw_tables.classes,"fighter");var wizard:=label_id(raw_tables.classes,"wizard")
	if not gate(fighter>=0 and wizard>=0,"Installed active class labels resolve physical owned-class cases"):return
	# No generic select_class preload supplies these tables. The real private
	# Class ResourceWork must load the initially owned class as well as a new one.
	var active:=raw_tables.duplicate(true);var names: Array=[]
	for field in ["SkillsTable","FeatsTable","AttackBonusTable","BonusFeatsTable"]:
		var name:=str(active.classes.orderedRows[fighter].get(field,"")).to_lower()
		if name not in ["","****"]:names.append(name);active.erase(name)
	check(names.all(func(name):return not active.has(name)),"Initially owned class dependencies start cold without generic editor warming")
	runtime.definitions_work.set_process(false)
	if gate(await open_cache_case(begin,active,fighter,201),"Actual native Class opens while its plain metadata worker is unadmitted"):
		var pane=front.panes["class"];var ticket: Array=front.ticket.duplicate();var pending_draws: int=int(runtime.hit_die_owner.stream.draws)
		check(not runtime.read_definitions().get("ready",false),"Controlled late worker publication has not leaked definitions into the current draft")
		await click(pane.buttons.okbutton)
		if gate(await wait_for(func():return not runtime.pending_class_completion.is_empty()),"Cold class resource result waits explicitly for the matching background decode"):
			check(private_owner.class_preparing and private_owner.class_id==-1 and private_owner.initial_tables.is_empty() and front.ticket==ticket and pane.state.selected_class()==fighter,"No class/rule commit or selection/ticket replacement happens before both jobs are ready")
			check(pane.buttons.okbutton.disabled and pane.row_buttons.all(func(row):return row.disabled) and not pane.buttons.cancelbutton.disabled,"Native waiting Class blocks duplicate edits while retaining Cancel")
			pane.complete(true);private_owner.accepted("class",fighter,ticket);runtime.definitions_prepared(-1)
			check(private_owner.class_id==-1 and private_owner.class_preparing and int(runtime.hit_die_owner.stream.draws)==pending_draws,"Synthetic OK and early completion cannot commit Class or consume a random draw")
		runtime.definitions_work.set_process(true)
		if gate(await ready("attributes"),"Current metadata completion releases the same native Class into Attributes"):
			check(private_owner.class_id==fighter and names.all(func(name):return runtime.tables.has(name) and private_owner.initial_tables.has(name)),"Actual owned-class dependencies are privately loaded before immutable admission")
			var decoded: Dictionary=runtime.read_definitions();var oracle:=PlainTables.decode(runtime.tables.feat)
			check(decoded.ready and decoded==oracle,"Runtime borrows the exact plain decode without TLK/sort or operation-index fields")
			await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
			if gate(await ready("skills"),"Admitted class reaches functioning native Skills"):
				var builds: int=int(runtime.definitions_work.stats.submitted);var first: Dictionary=private_owner.snapshot();var expected:=PrivateSnapshot.compose(private_owner.received,private_owner.class_id,private_owner.attributes.selected,private_owner.skills.ranks,runtime.tables,private_owner.context,[],oracle)
				check(first.ready and first==expected and first.source.owned.has(40) and first.source.owned.all(func(id):return id is int),"Cached definitions preserve full current Snapshot and received WORD-ID normalization")
				var skill:=-1
				for key in front.panes.skills.buttons:
					if str(key).begins_with("up:") and not front.panes.skills.buttons[key].disabled:skill=int(str(key).trim_prefix("up:"));break
				if gate(skill>=0,"An actual eligible native skill arrow is available"):
					await click(front.panes.skills.buttons["up:"+str(skill)])
					var edited: Dictionary=private_owner.snapshot();var changed:=PrivateSnapshot.compose(private_owner.received,private_owner.class_id,private_owner.attributes.selected,private_owner.skills.ranks,runtime.tables,private_owner.context,[],oracle)
					check(edited.ready and edited==changed and edited.source.skills!=first.source.skills,"Each operation recomputes private ranks instead of caching mutable eligibility or Snapshot state")
				var began:=Time.get_ticks_usec();var fast1: Dictionary=private_owner.snapshot();var fast2: Dictionary=private_owner.snapshot();var two_usec:=Time.get_ticks_usec()-began
				var primary: Array=runtime.primary_feats()
				check(fast1==fast2 and int(runtime.definitions_work.stats.submitted)==builds and primary==fast1.source.owned+private_owner.feats.selected,"Skills/Summary/submit source reads and Runtime primary_feats share one plain decode")
				cache_observations.append({"kind":"cached-direct-snapshots","classId":fighter,"twoCallsUsec":two_usec,"definitions":decoded.definitions.size(),"worker":runtime.definitions_work.snapshot()})
		await key_escape()
	runtime.definitions_work.set_process(true)
	# An early Cancel retires ownership immediately even if a worker has not
	# published. Its old completion cannot supply the next draft's definitions.
	runtime.definitions_work.set_process(false)
	if gate(await open_cache_case(begin,raw_tables.duplicate(true),fighter,202),"A separate transaction starts another owned background warm"):
		var old_scope: Array=runtime.rules_scope.duplicate();var old_serial: int=runtime.definitions_work.serial
		await click(front.panes["class"].buttons.okbutton);var began:=Time.get_ticks_usec();await key_escape();var cancel_usec:=Time.get_ticks_usec()-began
		check(not runtime.active and not panel.wanted and runtime.pending_class_completion.is_empty() and int(runtime.definitions_work.stats.closeUsec)==0,"Physical Cancel retires pending class/decode without waiting for or force-closing the CPU task")
		if gate(await open_cache_case(begin,raw_tables.duplicate(true),fighter,203),"Reopen creates a fresh metadata scope before the old result is consumed"):
			runtime.definitions_prepared(old_serial);check(front.stage=="class" and private_owner.class_id==-1 and runtime.rules_scope!=old_scope,"A retired completion cannot commit a class in the reopened transaction")
			runtime.definitions_work.set_process(true);await key_escape()
		cache_observations.append({"kind":"cancel-pending-definitions","callbackAndFixtureFramesUsec":cancel_usec,"worker":runtime.definitions_work.snapshot()})
	runtime.definitions_work.set_process(true)
	# Keep invalid data explicit at the same original native surface.
	var malformed:=raw_tables.duplicate(true);malformed.feat={"orderedRows":[{"Feat":"0xZ"}],"defaultValue":"****"}
	if gate(await open_cache_case(begin,malformed,fighter,204),"A malformed active feat table still permits cancellable native Class presentation"):
		await click(front.panes["class"].buttons.okbutton)
		if gate(await wait_for(func():return not private_owner.class_error.is_empty() and not private_owner.class_preparing),"Malformed decoded metadata becomes an explicit completed native Class error"):
			check(front.stage=="class" and private_owner.class_id==-1 and panel.source_active and not panel.visible and not front.panes["class"].buttons.cancelbutton.disabled,"Decode failure never fabricates empty definitions or swaps to the generic editor")
		await key_escape()
	for retirement in ["catalog","feat"]:
		runtime.definitions_work.set_process(false)
		var replacement_tables:=raw_tables.duplicate(true)
		if gate(await open_cache_case(begin,replacement_tables,fighter,206 if retirement=="catalog" else 207),"Pending metadata is owned before "+str(retirement)+" replacement"):
			await click(front.panes["class"].buttons.okbutton)
			if gate(await wait_for(func():return not runtime.pending_class_completion.is_empty()),"Class resource completion is held before "+str(retirement)+" replacement"):
				var old_request: int=runtime.definitions_work.serial;var foreign_catalog=Catalog.new()
				if retirement=="catalog":desktop.owner_ui.catalog=foreign_catalog
				else:active_text.publish_table("feat",replacement_tables.feat.duplicate(true))
				runtime.table_published(-1,{})
				check(await wait_for(func():return not runtime.active and not panel.wanted),"Changed "+str(retirement)+" retires the exact pending native transaction")
				runtime.definitions_prepared(old_request)
				check(not runtime.active and runtime.pending_class_completion.is_empty() and not panel.visible,"Old metadata callback cannot revive a changed-owner draft or expose generic controls")
				desktop.owner_ui.catalog=catalog;foreign_catalog=null
		runtime.definitions_work.set_process(true)
	# Missing metadata arrives through the actual accepted table publication
	# boundary, not a frame scan or mutation of the canonical graph.
	var late:=raw_tables.duplicate(true);var original_feat: Dictionary=late.feat;late.erase("feat")
	if gate(await open_cache_case(begin,late,fighter,205),"Native Class can wait for genuinely absent active feat metadata"):
		await click(front.panes["class"].buttons.okbutton)
		check(await wait_for(func():return private_owner.class_preparing and not runtime.pending_class_completion.is_empty()),"Missing metadata keeps a compact same-ticket class hold")
		var late_scope: Array=runtime.rules_scope.duplicate();var late_ticket: Array=front.ticket.duplicate()
		active_text.publish_table("feat",original_feat);runtime.table_published(-1,{})
		check(await ready("attributes") and runtime.rules_scope==late_scope and front.ticket!=late_ticket and private_owner.class_id==fighter,"Late accepted metadata releases only the held current transaction into its next owned stage")
		if panel.wanted:await key_escape()
	check(received==before and desktop.commands.all(func(command):return command.operation!="submit"),"Background definition preparation never mutates received stats or submits a partial level-up")
	active_text.tables=raw_tables;observations.append({"kind":"private-plain-definitions-runtime","values":cache_observations})
