extends "res://tests/native_creation_spells_snapshot_test.gd"
const Automatic=preload("res://systems/native_data/creation_spell_automatic.gd")
const PackageRules=preload("res://systems/native_data/creation_package_rules.gd")
func model(kind: String="preferences"):
	var rules=rules_fixture();rules.draft.merge({"goodEvil":50,"lawChaos":50,"school":0,"packageSource":true,"memorized":{}},true)
	rules.tables.packages={"orderedRows":[{"SpellPref2DA":"auto_spells"}]}
	rules.tables.auto_spells={"orderedRows":[{"SpellIndex":"1"},{"SpellIndex":"2"}]}
	rules.tables.spellschools.orderedRows[0].Letter="****";rules.tables.spellschools.orderedRows[1].Letter="A"
	if kind=="missing":rules.tables.packages.orderedRows[0].SpellPref2DA="****";rules.tables.erase("auto_spells")
	elif kind=="empty":rules.tables.auto_spells={"orderedRows":[]}
	elif kind=="failed":rules.tables.auto_spells={}
	return rules
func complete(rules) -> Dictionary:
	var initial:=Automatic.before(rules);check(initial.ready,"Original package starts with a detached empty spell baseline",initial)
	if initial.ready and rules.tables.packages.orderedRows[0].SpellPref2DA!="****":PackageRules.recommend_spells(rules,rules.tables.packages.orderedRows[0])
	var result:=Automatic.capture(rules,initial,[891,4]);check(result.ready,"Completed automatic operation captures only bounded scalar/ID receipt",result)
	if result.ready:rules.draft.sourceAutomaticSpells=result.receipt
	return result.get("receipt",{})
func reject(rules,receipt: Variant,label: String) -> void:
	var value:=Automatic.verify(rules,receipt);check(not value.get("ready",false) or not value.get("valid",false),label,value)
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	for kind in ["missing","empty","failed","preferences"]:
		var rules=model(kind);var tables: Dictionary=rules.tables.duplicate(true);var receipt:=complete(rules);var draft: Dictionary=rules.draft.duplicate(true);var result:=Automatic.verify(rules,receipt)
		check(result.get("ready",false) and result.get("valid",false),"Original automatic replay permits ignored preference remainder: "+kind,result)
		check(rules.tables==tables and rules.draft==draft,"Replay leaves canonical active tables and accepted private draft unchanged: "+kind)
		check(rules.draft.known.get(1,[]).size()==(2 if kind=="preferences" else 0),"No arbitrary level1 fillers: "+kind)
		check(rules.draft.known.get(0,[])==([] if kind=="missing" else [0]),"Cantrip injection follows actual caller invocation, including failed table load: "+kind)
		check(var_to_bytes(receipt).size()<3072 and not str(receipt).contains("orderedRows"),"Input receipt contains no table/definition graph: "+kind)
	var rules=model();var receipt:=complete(rules)
	check(rules.draft.memorized[0]==[0] and rules.draft.memorized[1]==[1,2],"Memorization takes each known prefix once, without cycling to fill extra slots")
	for field in ["classId","raceId","packageId","school","goodEvil","lawChaos"]:
		var changed=model();changed.draft=rules.draft.duplicate(true);changed.draft[field]+=1;reject(changed,receipt,"Changed character context rejects: "+field)
	var changed=model();changed.draft=rules.draft.duplicate(true);changed.draft.abilities.Int+=1;reject(changed,receipt,"Changed raw ability context rejects")
	changed=model();changed.draft=rules.draft.duplicate(true);changed.draft.domains=[0,1];reject(changed,receipt,"Changed domain context rejects")
	for field in ["known","memorized"]:
		changed=model();changed.draft=rules.draft.duplicate(true);changed.draft[field][1].reverse();reject(changed,receipt,"Changed accepted book order rejects: "+field)
	changed=model();changed.draft=rules.draft.duplicate(true);changed.tables.auto_spells.orderedRows.reverse();reject(changed,receipt,"Changed current preferences replay and reject old output")
	changed=model();changed.draft=rules.draft.duplicate(true);changed.tables.spells.orderedRows[1].SERVER_CAST="2";reject(changed,receipt,"Changed active physical spell level rejects")
	for table in [{},{"orderedRows":[]},{"orderedRows":"bad"},{"orderedRows":[{"SpellIndex":"0xZZ"}]}]:
		changed=model();changed.draft=rules.draft.duplicate(true);changed.tables.auto_spells=table;reject(changed,receipt,"Changed/invalid preference publication rejects: "+str(table))
	changed=model();changed.draft=rules.draft.duplicate(true);changed.tables.erase("auto_spells");reject(changed,receipt,"Unloaded named preferences stay unavailable")
	for patch in [{"completed":false},{"version":2},{"scope":[891,-1]},{"context":7},{"initialKnown":[]},{"known":[]},{"memorized":7},{"operation":7}]:
		var bad:=receipt.duplicate(true);bad.merge(patch,true);reject(rules,bad,"Malformed receipt rejects without engine failure: "+str(patch))
	changed=model();changed.draft=rules.draft.duplicate(true);changed.draft.sourceSpellChoices=true;reject(changed,receipt,"Manual mode cannot claim automatic ignored remainder")
	changed=model();changed.draft=rules.draft.duplicate(true);changed.draft.packageSource=false;reject(changed,receipt,"Generic selection cannot claim automatic ignored remainder")
	rules.reset_choices();check(not rules.draft.has("sourceAutomaticSpells") and not rules.draft.has("sourceSpellChoices"),"Derived reset retires both native selection modes")
	for learn in [0,1]:
		var custom=model("empty");custom.tables.classes.orderedRows[0].LearnScroll=str(learn);custom.draft.abilities.Int=9;custom.tables.racialtypes.orderedRows[0].IntAdjust="4"
		var custom_receipt:=complete(custom);var value:=Automatic.verify(custom,custom_receipt)
		check(value.get("valid",false) and custom.draft.known[0]==[0],"Package cantrip gate uses MemorizesSpells alone, independent of GUI LearnScroll/rawInt gate: "+str(learn),value)
	var custom=model("empty");custom.tables.classes.orderedRows[0].LearnScroll="0"
	check(not Snapshot.compose(custom,AdapterFixture.Text.new()).ready and Snapshot.compose(custom,AdapterFixture.Text.new(),false).ready,"Only automatic data projection opts out of missing manual selection counter")
	var custom_receipt:=complete(custom);check(Automatic.verify(custom,custom_receipt).get("valid",false),"Mem1/Learn0 automatic replay uses no invented prior GUI counter")
	custom=model();custom.tables.classes.orderedRows[0].merge({"MemorizesSpells":"0","LearnScroll":"0","SpellKnownTable":"auto_known"},true);custom.tables.auto_known={"orderedRows":[{"SpellLevel0":"1","SpellLevel1":"1"}]}
	custom_receipt=complete(custom);var value:=Automatic.verify(custom,custom_receipt)
	check(value.get("valid",false) and custom.draft.known.get(0,[]).is_empty() and custom.draft.known[1]==[1] and custom.draft.memorized.is_empty(),"Spontaneous preference capacity is replayed without cantrip injection or invented preparation",value)
	custom=model();custom.tables.classes.orderedRows[0].SpellbookRestricted="0";custom.tables.erase("auto_spells");custom_receipt=complete(custom)
	check(Automatic.verify(custom,custom_receipt).get("valid",false) and custom.draft.known.is_empty(),"Unrestricted package skips the spell helper without demanding unused named preferences")
	for bad in [{0:[1,1]},{0:[65536]},{0:[1.0]}]:check(not Automatic.books(bad).ready,"Known storage rejects duplicate/overflow/noninteger IDs: "+str(bad))
	var huge: Array=[];huge.resize(256);huge.fill(0);check(not Automatic.books({0:huge},true).ready,"Native BYTE traversal domain rejects256 prepared entries")
	custom=model();custom.draft.known={0:[0]};check(not Automatic.before(custom).ready,"Package cannot transplant a nonempty pre-entry spell baseline")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Original-backed automatic Package spell receipt/replay: actual existing recommendation producer, skipped/empty/failed preferences, known-prefix preparation, spontaneous/native data projection, active tables/context invalidation, compact storage bounds and manual/generic/reset separation. No server or complete controls/BIC acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
