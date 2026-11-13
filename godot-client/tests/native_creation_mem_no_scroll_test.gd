extends "res://tests/native_creation_spells_snapshot_test.gd"
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var text:=AdapterFixture.Text.new();var rules=rules_fixture()
	rules.tables.classes.orderedRows[0].merge({"MemorizesSpells":"1","LearnScroll":"0","SpellKnownTable":"server_known"},true)
	rules.tables.server_known={"orderedRows":[{"SpellLevel0":"0","SpellLevel1":"1"}]}
	var before:=JSON.stringify(rules.draft);var result:=Snapshot.compose(rules,text)
	check(result.ready,"A custom memorizing non-scroll class with an eligible enabled level has a defined original initialization counter",result)
	if result.ready:
		var state:=State.new();check(state.configure(result.source).ready and state.remaining==1 and state.selected_level==1,"Original9ce190 writes the remaining count from the active known-capacity getter before display")
		check(not result.source.learnScroll and result.source.memorizes and result.source.capacity.slice(0,2)==[0,1] and state.known[0].is_empty(),"MemorizesSpells and LearnScroll retain separate table flags; no scroll-learning cantrip injection")
		check(state.available_ids==[1] and not state.can_accept(),"Actual custom column/opposing-school metadata still gates available physical spell IDs and completion")
		check(state.add(1) and state.remaining==0 and state.can_accept() and state.known[1]==[1],"Adding the actual admissible spell completes the defined counter without a first-level scroll budget")
		check(state.remove(1) and state.remaining==1 and not state.can_accept() and state.reset_choices() and state.known[1].is_empty(),"Remove/reset restore private choices and the original non-scroll capacity")
		check(JSON.stringify(rules.draft)==before,"Snapshot/private selection does not mutate the canonical creation draft")
	rules.draft.known={1:[1]};result=Snapshot.compose(rules,text)
	check(result.ready,"A received existing spell book still initializes the counter even when its remaining count is zero",result)
	if result.ready:
		var state:=State.new();check(state.configure(result.source).ready and state.can_accept() and state.remaining==0,"Full active capacity is an original completion, not a pending unsupported class")
	rules.draft.known={};rules.tables.server_known.orderedRows[0].SpellLevel1="0";result=Snapshot.compose(rules,text)
	check(not result.ready and str(result.reason).contains("counter"),"Memorizing non-scroll zero-enabled initialization remains explicit because original ctor does not initialize the prior counter")
	rules.tables.server_known.orderedRows[0].SpellLevel1="1";rules.draft.abilities.Int=3;result=Snapshot.compose(rules,text)
	check(not result.ready and str(result.reason).contains("counter"),"Enabled but minimum-ineligible levels do not prove an original counter write")
	rules.draft.abilities.Int=14;rules.tables.erase("server_known");result=Snapshot.compose(rules,text)
	check(not result.ready and result.dependencies==["server_known"],"Missing active class-known data remains a real resource dependency")
	rules.tables.server_known={"orderedRows":[{"SpellLevel0":"0","SpellLevel1":"0"}]};rules.tables.classes.orderedRows[0].MemorizesSpells="0";result=Snapshot.compose(rules,text)
	var zero:=State.new();check(result.ready and zero.configure(result.source).ready and zero.can_accept() and zero.remaining==0 and zero.tabs.all(func(enabled):return not enabled),"Non-memorizing zero-capacity custom classes complete without invented enabled levels or fallback spells")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Authored active class/known/spell table adapter plus existing original-backed private spell state. Source-reviewed9ce190 counter writes, separate MemorizesSpells/LearnScroll gates, full/zero/minimum/missing data and private add/remove/reset. No native controls, BIC or server admission proof."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
