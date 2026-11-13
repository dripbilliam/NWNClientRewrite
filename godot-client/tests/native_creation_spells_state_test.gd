extends SceneTree
const State=preload("res://systems/native_data/creation_spells_state.gd")
const ORACLE_SHA256="3a9c8c080d9d988206ca5ed26bab193a66bee853b947fd3fbde657ec37756532"
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"detail":detail})
func book(value: Array) -> Array:return value.map(func(row):return row.map(func(id):return int(id)))
func fixture(memorizes: bool=true) -> Dictionary:
	var value:={"memorizes":memorizes,"learnScroll":memorizes,"pickSchool":false,"keepBudget":false,"classLevel":1,"intModifier":2,"baseInt":14,"school":0,"storedRemaining":0,"opposition":null,"capacity":[],"gain":[],"minimum":[],"known":[],"spells":[]}
	for level in 10:value.capacity.append(1 if level<2 else 0);value.gain.append(1 if level<2 else 0);value.minimum.append(level<2);value.known.append([])
	for id in 4:value.spells.append({"id":id,"level":0 if id==0 else 1,"school":0,"name":["Cantrip","Alpha","alpha","Zulu"][id]})
	return value
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==ORACLE_SHA256,"Immutable original spell chooser corpus digest")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==480,"Original480 complete initialization/OK callbacks with explicit getter/GUI boundaries")
	for at in oracle.rows.size():
		var row: Dictionary=oracle.rows[at];var state:=State.new();var before:=JSON.stringify(row.input);var result:=state.configure(row.input);var expected: Dictionary=row.output
		check(result.ready,"Complete native getter snapshot admits policy "+str(at),result)
		if not result.ready:continue
		check(state.remaining==int(expected.remaining) and state.selected_level==int(expected.selected) and state.tabs==expected.tabs and state.finished==expected.finished and state.can_accept()==expected.ok,"Original tab enablement/unfinished/global-or-level budget/initial tab/OK "+str(at),{"expected":expected,"actual":state.view()})
		check(state.known==book(expected.known),"Original conditional cantrip learning and preservation of prior known lists "+str(at),{"expected":expected.known,"actual":state.known})
		check(JSON.stringify(row.input)==before,"Spell policy cannot mutate its borrowed native snapshot "+str(at))
	var state:=State.new();var source:=fixture();source.known[0]=[0];check(state.configure(source).ready and state.remaining==5 and state.selected_level==1,"Memorizing scroll learner has a shared budget and hides prior known entries")
	check(state.available_ids==[2,1,3] and state.known_ids.is_empty(),"Source list uses existing original bytewise lower-bound ordering, including equal names")
	check(state.add(1) and state.add(2) and state.known_ids==[1,2] and state.remaining==3,"A new spell appends to the displayed selected list and consumes shared budget")
	state.select_level(0);check(state.known_ids.is_empty() and not state.remove(0),"Memorizing initial known snapshot is hidden and scroll-learning cantrips cannot be removed")
	state.select_level(1);check(state.known_ids==[2,1],"Changing tabs rebuilds selected rows in original name order")
	check(state.add(3) and state.remaining==2 and state.can_accept(),"Exhausted available choices permit OK without fabricating extra spell selections")
	check(state.remove(2) and state.remaining==3 and not state.can_accept() and state.available_ids==[2],"Remove returns original budget and reopens the current unfinished level")
	var model:=state.view();model.known.clear();model.tabs[1]=false;check(state.known_ids.size()==2 and state.tabs[1],"Detached UI projections cannot mutate policy arrays")
	check(state.reset_choices() and state.known[0]==[0] and state.known[1].is_empty() and state.remaining==5,"Reset restores initial known ownership and reinitializes native choices")
	var spontaneous:=State.new();source=fixture(false);check(spontaneous.configure(source).ready and spontaneous.selected_level==0 and spontaneous.remaining==1,"Non-memorizing caster begins at the lowest unfinished level with its own capacity")
	check(spontaneous.add(0) and spontaneous.selected_level==1 and spontaneous.remaining==1 and spontaneous.known[0]==[0],"Filling the first level advances only to the immediate next level with remaining capacity")
	check(spontaneous.add(1) and spontaneous.can_accept() and spontaneous.remaining==0,"Per-level choices complete independently")
	source.capacity[1]=99;check(spontaneous.known_left(1)==0,"Mutating caller metadata cannot change cached native getter results")
	check(not State.new().configure({}).ready,"Missing native getter results remain explicitly unavailable")
	var tied:=fixture(false);tied.spells=[];tied.capacity[1]=0
	var names:=["ALPHA","alpha","Alpha","beta","ALPHA"]
	for id in names.size():tied.spells.append({"id":id,"level":0,"school":0,"name":names[id]})
	var insertion:=State.new();check(insertion.configure(tied).ready and insertion.available_ids==[4,2,1,0,3],"Cached legacy-byte keys retain original ASCII folding and tie order")
	var added:=insertion.add(1);var removed:=insertion.remove(1)
	check(added and removed and insertion.available_ids==[1,4,2,0,3],"Single-row lower-bound return preserves all existing equal-name rows instead of re-sorting their order",insertion.available_ids)
	check(State.Order.compare(PackedByteArray([65,0,90]),PackedByteArray([97]))==0,"Original byte comparator stops at source NUL without constructing an invalid Godot string")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":480,"scope":"Pure native spell-chooser policy vs complete original initialization/OK callbacks with captured getters/GUI/list services; detached model, ordered list and add/remove/reset/auto-advance behavior from static original evidence. Active-table draft adapter, source controls, full getter/loader/recommendation/commit and server/pixel acceptance remain open.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
