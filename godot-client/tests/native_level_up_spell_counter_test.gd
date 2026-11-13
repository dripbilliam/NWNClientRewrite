extends "res://tests/native_creation_spells_state_test.gd"
const Counter=preload("res://systems/native_data/level_up_spell_counter.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(corpus.get("success",false) and corpus.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and corpus.originalExecutions==480 and corpus.cases==120,"Pinned mode1 no-scroll counter-history scope executes unchanged original initialization four ways")
	var derived:=0;var unavailable:=0
	for row in corpus.rows:
		var before:=JSON.stringify(row.input);var result:=Counter.derive(row.input.capacity,row.input.minimum,row.input.known)
		if row.reached.is_empty():
			unavailable+=1;check(not result.ready and result.counter==null,"No reached native overwrite preserves explicit prior-counter unavailability "+str(row.corpusIndex));continue
		derived+=1;check(result.ready and result.counter==int(row.derivedCounter) and result.reached==row.reached.map(func(level):return int(level)),"Mode1 counter derives only the last reached native known-left write "+str(row.corpusIndex),result)
		for run in row.runs:
			var value: Dictionary=row.input.duplicate(true);value.storedRemaining=result.counter;var state:=State.new();var ready:=state.configure(value);var expected: Dictionary=run.output
			check(ready.ready and state.remaining==int(expected.remaining) and state.selected_level==int(expected.selected) and state.tabs==expected.tabs and state.finished==expected.finished and state.can_accept()==expected.ok and state.known==book(expected.known),"Derived counter reproduces complete original initialization regardless of previous WORD "+str(row.corpusIndex)+"/"+str(run.storedRemaining),state.view())
		check(JSON.stringify(row.input)==before,"Counter preparation preserves borrowed received books/getters "+str(row.corpusIndex))
	check(derived==int(corpus.guaranteedOverwriteCases) and unavailable==int(corpus.priorCounterCases) and derived>0 and unavailable>0,"Guaranteed overwrite and genuine prior-counter cases stay distinct")
	var source:=fixture();source.capacity[0]=3;source.capacity[1]=7;source.known[1]=[1,2]
	var result:=Counter.derive(source.capacity,source.minimum,source.known)
	check(result.ready and result.counter==5 and result.reached==[0,1],"Final reached level determines the original WORD before memorizing display, rather than chosen tab or prior counter")
	source.minimum[1]=false;result=Counter.derive(source.capacity,source.minimum,source.known);check(result.ready and result.counter==3 and result.reached==[0],"A failed minimum getter does not own a counter overwrite")
	source.minimum[0]=false;check(not Counter.derive(source.capacity,source.minimum,source.known).ready,"Positive capacity alone cannot invent a reached write")
	source.minimum[0]=true;source.capacity[0]=256;check(not Counter.derive(source.capacity,source.minimum,source.known).ready,"Malformed non-BYTE getter remains unavailable")
	check(not Counter.derive([],[],[]).ready,"Missing storage is explicit rather than counter zero")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"guaranteedCases":derived,"priorCounterCases":unavailable,"originalExecutions":480,"runtimeIntegrated":false,"gpu":false,"serverConnections":0,"scope":"NEW mode1 MemorizesSpells1/LearnScroll0 counter boundary compared with unchanged original9ce190/9c6e70 across120 cases/four prior WORDs. Derives only guaranteed native known-left writes, preserves explicit unknown when no write is reached. No source controls/server/pixel acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
