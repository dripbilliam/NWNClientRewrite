extends "res://tests/native_level_up_recommended_test.gd"
var middle_observations: Array=[]
var middle_timings: Dictionary={}
var cancel_middle:=false
func choose_feat(id: int) -> bool:
	var pane=front.panes.feats
	for index in pane.model.get("available",[]).size():
		if int(pane.model.available[index].id)==id:
			await click(pane.buttons["available:"+str(index)+":arrow"]);return true
	return false
func choose_spell(id: int) -> bool:
	var pane=front.panes.spells
	for slot in pane.rows.available.size():
		if int(pane.rows.available[slot].id)==id:
			await click(pane.buttons["available:"+str(slot)+":arrow"]);return true
	return false
func middle_pressed(key: String) -> void:
	var pane=front.panes[key]
	middle_observations.append({"kind":"pressed","stage":key,"pending":private_owner.recommendation_pending,"feats":private_owner.feats.selected.duplicate(),"known":private_owner.spells.state.known.duplicate(true) if key=="spells" else [],"cancel":not pane.buttons.cancelbutton.disabled,"ok":not pane.buttons.okbutton.disabled,"recommend":not pane.buttons.recommendbutton.disabled})
	if cancel_middle:key_escape.call_deferred()
func middle_reset(stage: String,_request: int,_ticket: Array) -> void:
	middle_observations.append({"kind":"reset","stage":stage,"feats":private_owner.feats.selected.duplicate(),"known":private_owner.spells.state.known.duplicate(true) if stage=="spells" else []})
func middle_start(begin: Dictionary,token: int) -> bool:
	var value:=begin.duplicate(true);value.token=token;panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	if not await ready("class"):return false
	await click(front.panes["class"].buttons.okbutton)
	if not await ready("attributes"):return false
	await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
	if not await ready("skills"):return false
	await click(front.panes.skills.buttons.okbutton)
	return await ready("feats")
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,raw_tables: Dictionary) -> void:
	var directory:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):directory=argument.trim_prefix("--report=")+".middle-resources"
	DirAccess.make_dir_recursive_absolute(directory)
	for name in ["good","empty"]:
		var file:=FileAccess.open(directory.path_join("lvfs_feat_"+name+".2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nFeatIndex\n"+("0 65539\n1 0xGG\n" if name=="good" else ""));file.close()
		file=FileAccess.open(directory.path_join("lvfs_spell_"+name+".2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSpellIndex\n"+("0 3\n1 1\n2 0xGG\n" if name=="good" else ""));file.close()
	check(catalog.mount_directory(directory,100000002),"Mode1 declares exact named preference fixtures above installed data")
	var parser:=TwoDa.new();var active:=raw_tables.duplicate(true)
	var fields:={"SpellCaster":"1","MemorizesSpells":"1","LearnScroll":"1","SpellbookRestricted":"1","SpellcastingAbil":"INT","SpellTableColumn":"CustomMode1","SpellGainTable":"lvfs_gain","SpellKnownTable":"lvfs_known","Arcane":"1","SkipSpellSelection":"0","PickDomains":"0","PickSchool":"0","MinAssociateLevel":"255","Package":"1"}
	active.classes=Fixtures.row_update(active.classes,3,fields);active.racialtypes=Fixtures.row_update(active.racialtypes,0,{"NormalFeatEveryNthLevel":"4","NumberNormalFeatsEveryNthLevel":"1"})
	active.feat=parser.parse_reference("2DA V2.0\nFEAT AllClassesCanUse Icon\n0 61000 1 custom_0\n1 61001 1 custom_1\n2 61002 1 custom_2\n3 61003 1 custom_3\n4 61004 1 custom_4\n")
	active.spells=parser.parse_reference("2DA V2.0\nName SpellDesc CustomMode1 School IconResRef\n0 62000 62100 0 A server_cantrip\n1 62001 62101 1 A server_alpha\n2 62002 62102 1 V server_beta\n3 62003 62103 1 I server_gamma\n")
	active.lvfs_gain=parser.parse_reference("2DA V2.0\nNumSpellLevels SpellLevel0 SpellLevel1\n0 2 3 3\n1 2 3 3\n2 2 3 3\n3 2 3 3\n");active.lvfs_known=active.lvfs_gain.duplicate(true)
	for id in 5:active_text.overrides[61000+id]="Current feat "+str(id)
	for entry in [[62000,"Native Cantrip"],[62001,"Alpha"],[62002,"Beta"],[62003,"Gamma"]]:active_text.overrides[entry[0]]=entry[1]
	active_text.revision+=1
	var value:=begin.duplicate(true);value.snapshot.spellbooks={"0":{"known":[0]}};value.snapshot.classes[0].school=0
	for variant in ["good","empty","failed","missing"]:
		var tables:=active.duplicate(true);var feat_pref: String="****" if variant=="missing" else "lvfs_feat_"+str(variant);var spell_pref: String="****" if variant=="missing" else "lvfs_spell_"+str(variant)
		tables.packages=parser.parse_reference("2DA V2.0\nFeatPref2DA SpellPref2DA\n0 "+feat_pref+" "+spell_pref+"\n1 lvfs_feat_empty lvfs_spell_empty\n");active_text.tables=tables
		var token:=70+["good","empty","failed","missing"].find(variant)
		if not gate(await middle_start(value,token),"Actual Class→Attributes→Skills→Feats prepares "+variant):continue
		var pane=front.panes.feats;var start_at:=middle_observations.size()
		if not pane.buttons.recommendbutton.pressed.is_connected(middle_pressed.bind("feats")):pane.buttons.recommendbutton.pressed.connect(middle_pressed.bind("feats"))
		check(not pane.buttons.recommendbutton.disabled,"Native mode1 Feats Recommended is enabled by active rule switch "+variant)
		check(await choose_feat(4) and private_owner.feats.selected==[4],"Physical feat row/arrow starts a real private selection "+variant)
		if variant=="good":
			private_owner.action("spells","recommend",-1,front.ticket.duplicate())
			check(not private_owner.recommendation_pending and private_owner.navigation.stage=="feats" and private_owner.feats.selected==[4],"A current ticket cannot authorize a synthetic action from another child stage")
		await click(pane.buttons.recommendbutton)
		if not gate(await wait_for(func():return not private_owner.recommendation_pending),"Scoped Feats Recommended finishes "+variant):continue
		var expected: Array=[3] if variant=="good" else [4] if variant=="missing" else []
		check(private_owner.feats.selected==expected,"Native Feats success/reset/failed String outcomes preserve exact preference-only IDs "+variant)
		check(middle_observations.slice(start_at).any(func(row):return row.kind=="pressed" and row.stage=="feats" and row.pending and row.cancel and not row.ok and not row.recommend and row.feats==[4]),"Feats does not reset before successful String and disables repeat actions while retaining Cancel "+variant)
		middle_timings["feats-"+variant]=private_owner.recommendation_diagnostics.feats.duplicate(true)
		await click(pane.buttons.recommendbutton);check(await wait_for(func():return not private_owner.recommendation_pending) and private_owner.feats.selected==expected,"Repeated native Feats recommendation does not compound choices "+variant)
		if expected.is_empty():check(await choose_feat(4),"Manual feat selection remains usable after empty/failed recommendation "+variant)
		await click(pane.buttons.okbutton)
		if not gate(await ready("spells"),"Actual accepted Feats enters existing-class mode1 Spells "+variant):continue
		pane=front.panes.spells
		if not pane.buttons.recommendbutton.pressed.is_connected(middle_pressed.bind("spells")):pane.buttons.recommendbutton.pressed.connect(middle_pressed.bind("spells"))
		runtime.recommendation_work.reset_choices.connect(middle_reset)
		check(not pane.buttons.recommendbutton.disabled and private_owner.spells.state.remaining==2 and private_owner.spells.state.baseline[0]==[0],"Mode1 Spells retains copied cantrip baseline and level4 budget2 "+variant)
		check(await choose_spell(2) and private_owner.spells.state.known[1]==[2],"Physical spell arrow changes only the current private book "+variant)
		start_at=middle_observations.size();await click(pane.buttons.recommendbutton)
		if not gate(await wait_for(func():return not private_owner.recommendation_pending),"Scoped Spells Recommended finishes "+variant):continue
		var expected_book: Array=[3,1] if variant=="good" else [] if variant=="failed" else [1,2]
		check(private_owner.spells.state.known[1]==expected_book and private_owner.spells.state.known[0]==[0] and pane.model.canAccept,"Native preference then descending GUI fill/failed-load/skipped-helper books are exact "+variant)
		check(middle_observations.slice(start_at).any(func(row):return row.kind=="pressed" and row.stage=="spells" and row.pending and row.cancel and row.known[1].is_empty()),"Spells refunds private additions immediately before package lookup with usable Cancel "+variant)
		check(middle_observations.slice(start_at).any(func(row):return row.kind=="reset" and row.stage=="spells")!=(variant=="missing"),"Only a successful SpellPref String owns the second reset "+variant)
		middle_timings["spells-"+variant]=private_owner.recommendation_diagnostics.spells.duplicate(true)
		await click(pane.buttons.recommendbutton);check(await wait_for(func():return not private_owner.recommendation_pending) and private_owner.spells.state.known[1]==expected_book,"Repeated Spells Recommended is baseline-owned and idempotent "+variant)
		await click(pane.buttons.resetbutton);check(private_owner.spells.state.known[1].is_empty() and private_owner.spells.state.known[0]==[0] and private_owner.spells.state.remaining==2,"Physical Reset preserves copied baseline and restores mode1 budget "+variant)
		await click(pane.buttons.recommendbutton);await wait_for(func():return not private_owner.recommendation_pending)
		if variant=="good":
			await click(pane.buttons.okbutton)
			if gate(await ready("summary"),"Recommended mode1 private choices reach actual original Summary"):
				await click(front.panes.summary.buttons.okbutton)
				var sent: Array=desktop.commands.filter(func(command):return command.operation=="submit" and command.token==token)
				check(sent.size()==1 and sent[0].proposal.feats==[3] and sent[0].proposal.known[1]==[3,1] and sent[0].proposal.removed[1].is_empty(),"Typed proposal carries only exact mode1 recommended feat/book deltas, without optimistic received mutation")
		await key_escape();runtime.recommendation_work.reset_choices.disconnect(middle_reset)
		check(not runtime.active and received==before,"Cancel retires this recommendation transaction without changing received state "+variant)
	# One fresh request is cancelled while a real named resource job is pending.
	active_text.tables=active.duplicate(true);active_text.tables.packages=parser.parse_reference("2DA V2.0\nFeatPref2DA SpellPref2DA\n0 lvfs_feat_cancel lvfs_spell_good\n")
	if gate(await middle_start(value,80),"Fresh draft reopens after all prior recommendation requests"):
		var pane=front.panes.feats;cancel_middle=true;var retired: Array=front.ticket.duplicate();await click(pane.buttons.recommendbutton)
		check(await wait_for(func():return not panel.wanted) and not runtime.active,"Physical Escape remains admitted during pending Feats preference IO")
		var request: int=runtime.recommendation_work.serial;runtime.recommendation_work.completed.emit("feats",{"ready":true,"invoked":true,"loaded":true,"name":"lvfs_feat_good"},request-1,retired)
		check(not runtime.active and not panel.wanted,"Retired feat recommendation result cannot reopen or modify a cancelled source draft")
		cancel_middle=false
	active_text.tables=active.duplicate(true);active_text.tables.packages=parser.parse_reference("2DA V2.0\nFeatPref2DA SpellPref2DA\n0 lvfs_feat_good lvfs_s_cancel\n")
	if gate(await middle_start(value,81),"New source draft reopens after cancellation while Feats IO was pending"):
		var pane=front.panes.feats;await click(pane.buttons.recommendbutton);await wait_for(func():return not private_owner.recommendation_pending);await click(pane.buttons.okbutton)
		if gate(await ready("spells"),"Actual current Spells opens for busy-cancel request"):
			pane=front.panes.spells;cancel_middle=true;var retired: Array=front.ticket.duplicate();await click(pane.buttons.recommendbutton)
			check(await wait_for(func():return not panel.wanted) and not runtime.active,"Physical Escape remains admitted during pending Spells preference IO")
			var request: int=runtime.recommendation_work.serial;runtime.recommendation_work.completed.emit("spells",{"ready":true,"helperInvoked":false},request-1,retired)
			check(not runtime.active and not panel.wanted,"Retired spell recommendation cannot recreate a cancelled chooser or submit")
			cancel_middle=false
	active_text.tables=raw_tables
	observations.append({"kind":"mode1-feat-spell-results","observations":middle_observations,"timings":middle_timings})
