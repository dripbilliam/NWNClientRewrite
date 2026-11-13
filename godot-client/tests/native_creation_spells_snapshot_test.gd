extends "res://tests/native_creation_spells_state_test.gd"
const Snapshot=preload("res://systems/native_data/creation_spells_snapshot.gd")
const AdapterFixture=preload("res://tests/native_creation_feat_adapter_test.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
func rules_fixture():
	var rules=AdapterFixture.fixture()
	rules.tables.classes.orderedRows[0].merge({"SpellCaster":"1","PlayerClass":"1","MemorizesSpells":"1","LearnScroll":"1","SpellbookRestricted":"1","PickSchool":"1","SpellcastingAbil":"INT","SpellTableColumn":"SERVER_CAST","SpellGainTable":"server_gain","SpellKnownTable":""},true)
	for key in SkillsKeys():rules.tables.racialtypes.orderedRows[0][str(key)+"Adjust"]="0"
	rules.tables.server_gain={"orderedRows":[{"NumSpellLevels":"2","SpellLevel0":"3","SpellLevel1":"1"}]}
	rules.tables.spellschools={"orderedRows":[{"Opposition":"****"},{"Opposition":"2"}]}
	rules.tables.spells={"orderedRows":[{"Name":"100","SpellDesc":"200","School":"D","SERVER_CAST":"0","UserType":"0","Master":"3","IconResRef":"SERVER_ICON_0"},{"Name":"101","SpellDesc":"201","School":"A","SERVER_CAST":"1"},{"Name":"102","SpellDesc":"202","School":"C","SERVER_CAST":"1"},{"Name":"103","School":"****"}]}
	rules.draft.abilities.Int=14;rules.draft.school=1;rules.draft.known={}
	return rules
func SkillsKeys() -> Array:return ["Str","Dex","Con","Int","Wis","Cha"]
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var rules=rules_fixture();var text:=AdapterFixture.Text.new();var before:=JSON.stringify(rules.draft);var result:=Snapshot.compose(rules,text)
	check(result.ready,"Active custom first-level caster snapshot composes without Feats/Skills ownership",result)
	if result.ready:
		var state:=State.new();check(state.configure(result.source).ready,"Active-table snapshot feeds the original spell policy without invented values")
		check(result.source.gain[1]==3 and result.source.minimum[1] and result.source.capacity==[0,0,0,0,0,0,0,0,0,0],"Existing spell-gain owner supplies current-school/ability bonus while missing known table has native zero capacity",result.source)
		check(state.known[0]==[0] and state.available_ids==[1] and state.remaining==5,"Automatic cantrips ignore UserType/Master; active opposition filters the chooser's available spells")
		check(result.source.spells[3].school==null and result.source.spells[3].level==255 and result.source.spells[1].icon==null,"Unused undefined school/absent icons remain explicit; failed class-level lookup retains255")
		check(state.add(1) and state.can_accept() and state.remaining==4,"Exhausted custom spell list can complete without a fabricated exact-count requirement")
		check(JSON.stringify(rules.draft)==before,"Snapshot and private chooser leave the draft untouched before controller binding")
	rules.draft.school=0;result=Snapshot.compose(rules,text);var state:=State.new()
	check(result.ready and state.configure(result.source).ready and state.available_ids==[1,2] and result.source.gain[1]==2,"Replacing the active school recomputes real gain/opposition rather than reusing another scope")
	rules.draft.abilities.Int=9;rules.tables.racialtypes.orderedRows[0].IntAdjust="2";result=Snapshot.compose(rules,text);state=State.new()
	check(result.ready and state.configure(result.source).ready and state.known[0].is_empty() and result.source.intModifier==0 and result.source.baseInt==9 and result.source.minimum[1],"Raw Intelligence cantrip gate stays distinct from effective racial/ability eligibility")
	rules=rules_fixture();rules.tables.classes.orderedRows[0].merge({"MemorizesSpells":"0","LearnScroll":"0","SpellKnownTable":"server_known"},true);rules.tables.server_known={"orderedRows":[{"SpellLevel0":"4","SpellLevel1":"2"}]};result=Snapshot.compose(rules,text);state=State.new()
	check(result.ready and result.source.capacity.slice(0,2)==[4,2] and state.configure(result.source).ready and state.selected_level==0 and state.remaining==4,"Custom spontaneous known capacity uses the active known table and lowest unfinished level")
	rules.tables.server_known.orderedRows[0].SpellLevel0="0";rules.draft.abilities.Int=10;result=Snapshot.compose(rules,text)
	check(result.ready and result.source.capacity[1]==0,"Original restricted-known threshold uses the previous-level cell and effective ability")
	rules.tables.server_known.orderedRows[0].SpellLevel0="4";result=Snapshot.compose(rules,text);check(result.ready and result.source.capacity[1]==2,"A nonzero previous known count preserves native capacity even when minimum casting eligibility is false")
	rules=rules_fixture();rules.tables.classes.orderedRows[0].LearnScroll="0";check(not Snapshot.compose(rules,text).ready,"Uninitialized native shared-counter combination stays pending")
	rules=rules_fixture();rules.tables.spells.orderedRows[3].SERVER_CAST="1";result=Snapshot.compose(rules,text);check(result.ready and not State.new().configure(result.source).ready,"An eligible undefined school byte is not invented as school0")
	rules=rules_fixture();rules.tables.spells.orderedRows[1].SERVER_CAST="0xGG";check(not Snapshot.compose(rules,text).ready,"Malformed native class-level conversion remains unavailable")
	rules=rules_fixture();rules.tables.erase("spells");result=Snapshot.compose(rules,text);check(not result.ready and result.dependencies==["spells"],"Missing active table reports its dependency")
	rules=rules_fixture();rules.tables.spells=Parser.new().parse_reference("2DA V2.0\nName SpellDesc School SERVER_CAST server_cast IconResRef\n0 110 210 A 1 9 is_actual\n");result=Snapshot.compose(rules,text)
	check(result.ready and result.source.spells[0].level==1 and result.source.spells[0].icon=="is_actual","Original first physical case-insensitive column wins in authored parsed2DA data")
	var samples: Array=[];rules=rules_fixture();rules.draft.school=0;rules.tables.spells={"orderedRows":[]}
	for id in 1024:rules.tables.spells.orderedRows.append({"Name":str(1000+id),"SpellDesc":str(2000+id),"School":"A","SERVER_CAST":str(id%2),"IconResRef":"is_custom"})
	for at in 3:
		var start:=Time.get_ticks_usec();result=Snapshot.compose(rules,text);samples.append((Time.get_ticks_usec()-start)/1000.0)
	check(result.ready and result.source.spells.size()==1024,"Large custom physical spell table is decoded without a built-in class/spell list")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"snapshot1024Ms":samples,"scope":"First-level active-table spell snapshot composed with existing native ability/spell-gain owners and original policy. Custom class/column/opposition/known/gain/race, missing/undefined data and publication-replacement fixtures. No actual source view/controller, full loader/getter execution, recommendation/commit or server/pixel acceptance; copied480 corpus is unused by this adapter fixture.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
