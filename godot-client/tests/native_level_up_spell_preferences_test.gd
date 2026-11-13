extends "res://tests/native_creation_spells_state_test.gd"
const PreferenceLoop=preload("res://systems/native_data/level_up_spell_preferences.gd")
const OriginalPreferences=preload("res://systems/native_data/creation_spell_preferences.gd")
const Coordinator=preload("res://systems/native_data/level_up_spell_recommendations.gd")
const OriginalCoordinator=preload("res://systems/native_data/creation_spell_recommendations.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const PREFERENCE_ORACLE_SHA="571d3644f9227ee6444a63d9f44e06e48f99f01065d80f1b7b2c732d4a5f7102"
func same_result(left: Dictionary,right: Dictionary) -> bool:
	return left.ready and right.ready and left.known==right.known and left.remaining==right.remaining and left.highest==right.highest and left.calls==right.calls
func table(ids: Array) -> Dictionary:
	return {"headers":["SpellIndex"],"orderedRows":ids.map(func(id):return {"SpellIndex":"****" if id==null else str(int(id))})}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==PREFERENCE_ORACLE_SHA,"Pinned unchanged original480 preference-helper executions")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==480,"Original helper corpus has the expected binary and cases")
	for at in oracle.rows.size():
		var row: Dictionary=oracle.rows[at];var borrowed:=JSON.stringify(row.input);var result:=PreferenceLoop.apply(row.input,table(row.input.preferences));var expected_calls: Array=row.output.calls.map(func(call):return [str(call[0]),int(call[1])])
		check(result.ready and result.known==book(row.output.known) and result.remaining==int(row.output.remaining) and result.highest==int(row.output.highest) and result.calls==expected_calls,"Lazy mode1 table loop matches complete original7eb630 execution "+str(at),result)
		check(same_result(result,OriginalPreferences.apply(row.input)),"Valid active preference table preserves accepted shared policy output "+str(at))
		check(JSON.stringify(row.input)==borrowed,"Recommendation never mutates received getter/books input "+str(at))
	var parser:=Parser.new();var source:=fixture();source.restricted=true;source.loaded=true;source.preferences=[];source.classLevel=4;source.spells.append({"id":4,"level":1,"school":0,"name":"Last"})
	var result:=PreferenceLoop.apply(source,parser.parse_reference("2DA V2.0\nSpellIndex\n0 1\n1 2\n2 0xGG\n"))
	check(result.ready and result.known[1]==[1,2] and result.remaining==0 and result.reads==[0,1],"Memorizing budget reaches zero before an unreachable malformed preference conversion")
	result=PreferenceLoop.apply(source,parser.parse_reference("2DA V2.0\nSpellIndex\n0 0\n1 1\n2 2\n3 0xGG\n"))
	check(result.ready and result.known[0]==[0] and result.known[1]==[1,2] and result.reads==[0,1,2],"Cantrip does not consume the shared native budget; later malformed row remains unread")
	result=PreferenceLoop.apply(source,parser.parse_reference("2DA V2.0\nSpellIndex\n0 1\n1 0xGG\n"))
	check(not result.ready,"Reached malformed native conversion stays pending without returning partial choices")
	result=PreferenceLoop.apply(source,parser.parse_reference("2DA V2.0\nSpellIndex\n0 65537\n1 -1\n2 ****\n3 1\n4 2\n"))
	check(result.ready and result.known[1]==[1,2] and result.reads==[0,1,2,3,4],"SpellIndex retains INT width rather than feat WORD narrowing, and failed lookups skip")
	result=PreferenceLoop.apply(source,table([]));check(result.ready and result.known==source.known and result.remaining==2,"Successful zero-row preference retains the original class-level budget")
	source.loaded=false;result=PreferenceLoop.apply(source,{})
	check(result.ready and result.known==source.known and result.remaining==0 and result.reads.is_empty(),"Failed preference load skips table access and returns original zero budget")
	source.loaded=true;source.restricted=false;result=PreferenceLoop.apply(source,parser.parse_reference("2DA V2.0\nSpellIndex\n0 0xGG\n"))
	check(result.ready and result.reads.is_empty() and result.remaining==0,"Unrestricted helper does not read unavailable preference conversions")
	source.restricted=true;source.memorizes=false;source.capacity[1]=1;result=PreferenceLoop.apply(source,table([1,2,3,4]))
	check(result.ready and result.known[1]==[1] and result.remaining==0 and result.reads==[0,1,2,3],"Nonmemorizing branch reads each preference but honors capacity without a shared budget")
	check(not PreferenceLoop.apply({},{}).ready,"Absent source getters remain explicit rather than fabricated")
	for memorizes in [false,true]:
		for kind in ["skipped","failed","empty","preferences"]:
			var input:=fixture(memorizes);var left:=State.new();var right:=State.new();left.configure(input);right.configure(input);left.add(1);right.add(1)
			var ids: Array=[3,1,2] if kind=="preferences" else [];var plan:={"ready":true,"helperInvoked":kind!="skipped","loaded":kind!="failed","restricted":true,"preferences":ids,"opposition":null};var detached:=plan.duplicate();detached.erase("preferences");detached.preferenceTable=table(ids)
			var original:=OriginalCoordinator.apply(left,plan);var current:=Coordinator.apply(right,detached)
			check(original.ready and current.ready and left.view()==right.view() and original.preferenceCalls==current.preferenceCalls and original.greedyCalls==current.greedyCalls and original.highest==current.highest,"Mode1 coordinator preserves accepted manual reset/preference/descending GUI behavior "+str(memorizes)+" "+kind,{"original":original,"current":current})
	var chooser:=State.new();source=fixture();source.classLevel=4;chooser.configure(source);chooser.add(3)
	result=Coordinator.apply(chooser,{"ready":true,"helperInvoked":true,"loaded":true,"restricted":true,"preferenceTable":parser.parse_reference("2DA V2.0\nSpellIndex\n0 1\n1 2\n2 0xGG\n"),"opposition":null})
	check(result.ready and result.reads==[0,1] and chooser.known[1]==[1,2] and chooser.remaining==0 and chooser.can_accept(),"Actual chooser reset and lazy preference execution retain manual acceptance without reading the unreachable row")
	var retained:=chooser.known.duplicate(true);check(not Coordinator.apply(chooser,{"ready":false}).ready and chooser.known==retained,"Invalid unresolved plan cannot apply or reset a ready private chooser")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":480,"runtimeIntegrated":false,"serverConnections":0,"gpu":false,"scope":"NEW mode1-only lazy active-table preference boundary vs480 complete unchanged original7eb630 executions; valid-input differential, INT width, reached/unreached malformed rows, cantrip and memorizing/nonmemorizing counter behavior. No source actions/controls/server/pixel acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
