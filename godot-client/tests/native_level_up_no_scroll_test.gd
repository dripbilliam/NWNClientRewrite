extends "res://tests/native_level_up_recommended_test.gd"
const FeatSnapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
const SpellSnapshot=preload("res://systems/native_data/level_up_spells_snapshot.gd")
func select_spell(id: int) -> bool:
	var pane=front.panes.spells
	for slot in pane.rows.available.size():
		if int(pane.rows.available[slot].id)==id:await click(pane.buttons["available:"+str(slot)+":arrow"]);return true
	return false
func remove_spell(id: int) -> bool:
	var pane=front.panes.spells
	for slot in pane.rows.known.size():
		if int(pane.rows.known[slot].id)==id:await click(pane.buttons["known:"+str(slot)+":arrow"]);return true
	return false
func extra_cases(begin: Dictionary,received: Dictionary,before: Dictionary,raw_tables: Dictionary) -> void:
	var parser:=TwoDa.new();var active:=raw_tables.duplicate(true)
	active.classes=Fixtures.row_update(active.classes,3,{"SpellCaster":"1","MemorizesSpells":"1","LearnScroll":"0","SpellbookRestricted":"1","SpellcastingAbil":"INT","SpellTableColumn":"PrivateNoScroll","SpellGainTable":"lvns_gain","SpellKnownTable":"lvns_known","Arcane":"1","SkipSpellSelection":"0","PickDomains":"0","PickSchool":"0","MinAssociateLevel":"255"})
	active.spells=parser.parse_reference("2DA V2.0\nName SpellDesc PrivateNoScroll School IconResRef\n0 62000 62100 0 A server_cantrip\n1 62001 62101 1 A server_alpha\n2 62002 62102 1 V server_beta\n3 62003 62103 1 I server_gamma\n")
	active.lvns_gain=parser.parse_reference("2DA V2.0\nNumSpellLevels SpellLevel0 SpellLevel1\n0 2 1 2\n1 2 1 2\n2 2 1 2\n3 2 1 2\n");active.lvns_known=active.lvns_gain.duplicate(true)
	active.packages=parser.parse_reference("2DA V2.0\nSpellPref2DA\n0 lvns_pref\n");active.lvns_pref=parser.parse_reference("2DA V2.0\nSpellIndex\n0 3\n1 1\n2 0xGG\n")
	for entry in [[62000,"Native Cantrip"],[62001,"Alpha"],[62002,"Beta"],[62003,"Gamma"]]:active_text.overrides[entry[0]]=entry[1]
	active_text.revision+=1;active_text.tables=active;var retained:=active.duplicate(true)
	var value:=begin.duplicate(true);value.token=90;value.snapshot.spellbooks={"0":{"known":[0]}};value.snapshot.classes[0].school=0
	panel.reset();panel.open();controller.receive_result(ReplyFixture.echo(desktop,{"accepted":true,"operation":"begin","result":value}))
	if gate(await ready("class"),"Memorizing/no-scroll class opens the actual source Class pane"):
		await click(front.panes["class"].buttons.okbutton)
		if gate(await ready("attributes"),"Native next-level ability flow remains separate from first-level creation"):
			await click(front.panes.attributes.buttons.dexupbutton);await click(front.panes.attributes.buttons.okbutton)
			if gate(await ready("skills"),"Valid mode1 Skills opens before custom memorizing/no-scroll Spells"):
				await click(front.panes.skills.buttons.okbutton)
				if gate(await ready("spells"),"Guaranteed native counter overwrite permits original custom-class Spells instead of standard editor"):
					var state=private_owner.spells.state;var pane=front.panes.spells
					check(panel.source_active and not panel.visible and runtime.active and state.source.memorizes and not state.source.learnScroll,"Custom flag combination stays in the native source transaction")
					check(private_owner.spells.context.counterInitialization.ready and private_owner.spells.context.counterInitialization.reached==[0,1] and state.source.storedRemaining==2 and state.remaining==2 and state.selected_level==1,"Mode1 derives the last reached native known-left write, with no unknown prior counter or forced maximum")
					check(state.baseline[0]==[0] and state.known[0]==[0] and state.known[1].is_empty(),"Received known cantrip remains owned without first-level automatic book injection")
					await click(pane.buttons.spelllevel0);await click(pane.buttons.spelllevel1)
					check(state.remaining==2 and state.selected_level==1,"Memorizing level display preserves its initialized shared counter even though LearnScroll is false")
					check(await select_spell(1) and await select_spell(2) and state.remaining==0 and pane.model.canAccept,"Physical private spell arrows consume exactly the source-derived two selections")
					check(await remove_spell(1) and state.remaining==1 and not pane.model.canAccept,"Physical removal refunds the same counter and restores original admission requirements")
					await click(pane.buttons.resetbutton);check(state.known[1].is_empty() and state.known[0]==[0] and state.remaining==2,"Physical Reset repeats the native no-scroll initialization overwrite from copied baseline")
					await click(pane.buttons.recommendbutton)
					check(await wait_for(func():return not private_owner.recommendation_pending) and state.known[1]==[3,1] and state.remaining==0 and pane.model.canAccept,"Original preferences and descending GUI initialization complete custom mode1 without reading unreachable malformed rows")
					observations.append({"kind":"no-scroll-recommendation-timing","value":private_owner.recommendation_diagnostics.spells.duplicate(true)})
					await click(pane.buttons.okbutton)
					if gate(await ready("summary"),"Custom memorizing/no-scroll private delta reaches actual native Summary"):
						await click(front.panes.summary.buttons.okbutton)
						var sent: Array=desktop.commands.filter(func(command):return command.operation=="submit" and command.token==90)
						check(sent.size()==1 and sent[0].proposal.known[1]==[3,1] and sent[0].proposal.removed[0].is_empty() and sent[0].proposal.removed[1].is_empty(),"One typed proposal carries the exact new private book, without replacing received ownership")
	if panel.wanted:await key_escape()
	var unable: Dictionary=value.snapshot.duplicate(true);unable.baseAbilities[3]=3;var private:=FeatSnapshot.compose(unable,3,1,unable.skills,runtime.tables if runtime.active else active,{"baseFortitude":0})
	var missing:=SpellSnapshot.compose(unable,private,active,active_text)
	check(not missing.ready and str(missing.reason).contains("prior private selection counter"),"No guaranteed write retains explicit prior-counter unavailability rather than invented zero")
	check(received==before and active==retained,"Custom mode1 controls preserve canonical received snapshot and active source tables")
	active_text.tables=raw_tables
