extends "res://tests/native_creation_spells_state_test.gd"
const Preferences=preload("res://systems/native_data/creation_spell_preferences.gd")
const PREFERENCE_ORACLE_SHA="571d3644f9227ee6444a63d9f44e06e48f99f01065d80f1b7b2c732d4a5f7102"
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==PREFERENCE_ORACLE_SHA,"Immutable original preference-helper corpus digest")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==480,"Pinned complete original480 preference-helper executions")
	for at in oracle.rows.size():
		var row: Dictionary=oracle.rows[at];var before:=JSON.stringify(row.input);var result:=Preferences.apply(row.input)
		check(result.ready,"Complete native preference getter snapshot admits "+str(at),result)
		if not result.ready:continue
		var expected_calls: Array=row.output.calls.map(func(call):return [str(call[0]),int(call[1])])
		check(result.remaining==int(row.output.remaining) and result.highest==int(row.output.highest) and result.known==book(row.output.known) and result.calls==expected_calls,"Original full preference helper book/budget/top-level/mutation order "+str(at),{"expected":row.output,"actual":result})
		check(JSON.stringify(row.input)==before,"Preference helper cannot mutate borrowed books or physical table rows "+str(at))
	var value:=fixture();value.restricted=true;value.loaded=true;value.preferences=[0,1,1,2,3];value.capacity[1]=1
	var result:=Preferences.apply(value);check(result.ready and result.known[0]==[0] and result.known[1]==[1,2,3] and result.remaining==2,"Memorizing helper skips duplicate choices, adds free cantrips and consumes the shared budget only for noncantrips")
	result.known[1].clear();check(value.known[1].is_empty(),"Returned preference books are detached")
	value.memorizes=false;value.pickSchool=true;value.school=1;value.opposition=0;value.gain=[0,0,0,0,0,0,0,0,0,0];result=Preferences.apply(value)
	check(result.ready and result.known[0]==[0] and result.known[1]==[1] and result.remaining==0,"Non-memorizing preferences use capacity/minimum while preserving the original absence of opposition/gain filtering")
	value.restricted=false;result=Preferences.apply(value);check(result.ready and result.known==value.known and result.remaining==0 and result.highest==0,"Unrestricted classes do not invent preference-book additions")
	value.loaded=false;value.known[1]=[3];result=Preferences.apply(value);check(result.ready and result.known[1]==[3] and result.remaining==0,"An actual failed preference-table load preserves current books and returns original zero budget")
	check(not Preferences.apply({}).ready,"Unavailable metadata does not become a fabricated zero-valued preference rule")
	value.restricted=true;value.loaded=true;value.memorizes=true;value.gain[1]=1;value.spells[1].school=null;value.opposition=2;check(not Preferences.apply(value).ready,"Opposition-required original school data remains explicitly unavailable")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":480,"scope":"Complete original7eb630 instructions compared with detached native preference helper using captured active table/getter/book/allocation boundaries. No full9c9df0 chooser coordinator, source controller, actual loader, server or pixel acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
