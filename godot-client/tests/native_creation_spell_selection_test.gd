extends "res://tests/native_creation_spells_snapshot_test.gd"
const Selection=preload("res://systems/native_data/creation_spell_selection.gd")
const Validation=preload("res://systems/native_data/creation_spells_validation.gd")
const FrozenText=preload("res://systems/native_data/creation_spell_text_snapshot.gd")
func selection_rules():
	var rules=rules_fixture();rules.draft.memorized={};rules.draft.sourceSpellSlots=true
	rules.tables.packages={"orderedRows":[{"SpellPref2DA":"server_prefs"}]};rules.tables.server_prefs={"orderedRows":[{"SpellIndex":"1"}]}
	for level in 10:rules.creation_spell_slots[level]=3 if level==0 else 2 if level==1 else 0
	return rules
func selection_text():
	var text:=AdapterFixture.Text.new();text.names={100:"Cantrip",101:"Allowed",102:"Opposed",103:"Unused"};return text
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var rules=selection_rules();var text=selection_text();var session:=Selection.new();var identity: Array=[400,1];var result:=session.begin(rules,text,identity)
	check(result.ready and rules.draft.known[0]==[0] and rules.draft.sourceSpellChoices and not rules.creation_spell_selection.completed,"Actual owned draft receives original automatic cantrips and an unfinished scoped transcript")
	check(not Validation.verify(rules,text,rules.creation_spell_selection).valid,"Unfinished native selection cannot be accepted for saving")
	result=session.edit("add",1,rules,text,identity);check(result.ready and rules.draft.known[1]==[1] and session.state.remaining==4,"Native add publishes the owned book and original unused budget")
	check(rules.spell_count(1)==5 and rules.spell_options(0).is_empty(),"Custom original choices deliberately differ from the older generic exact-count/UserType methods")
	result=session.commit(rules,text,identity);check(result.get("accepted",false) and result.code==0x8011 and rules.draft.memorized[0]==[0] and rules.draft.memorized[1]==[1],"Original spell OK commits first-known preparations against the earlier school-owned slot cache",result)
	check(Validation.verify(rules,text,rules.creation_spell_selection).valid,"Final source validator accepts actual native choices without generic filtering")
	var snapshot:=session.read(rules,text,identity);snapshot.known[0].name="Caller mutation";check(session.state.definitions[1].name=="Allowed","Detached native view cannot mutate live chooser metadata")
	var before:=JSON.stringify(rules.draft);check(not session.edit("remove",1,rules,text,[400,2]).ready and JSON.stringify(rules.draft)==before,"Stale draft scope cannot mutate the owned book")
	rules.draft.known[1].append(2);check(not Validation.verify(rules,text,rules.creation_spell_selection).valid and not session.read(rules,text,identity).ready,"Unrecorded/opposed spell injection is rejected at both query and save boundaries");rules.draft.known[1]=[1]
	text.names[101]="Current server name";text.revision+=1;result=session.read(rules,text,identity);check(result.ready and result.known[0].name=="Current server name" and session.state.remaining==4,"Text-only publication refreshes names without granting a new budget or losing choices")
	var frozen:=FrozenText.capture(rules,text);check(frozen.ready and frozen.text.is_complete() and frozen.text.raw({"strRef":101})=="Current server name","Save captures detached spell-name data on the owner thread")
	text.names[101]="Later name";text.revision+=1;check(frozen.text.raw({"strRef":101})=="Current server name","A later live text change cannot mutate the BIC worker snapshot")
	var worker=rules.get_script().new();worker.tables=rules.tables.duplicate();worker.draft=rules.draft.duplicate(true);worker.creation_spell_slots=rules.creation_spell_slots.duplicate();worker.creation_spell_selection=rules.creation_spell_selection.duplicate(true);worker.creation_spell_text=frozen.text
	check(Validation.verify(worker,worker.creation_spell_text,worker.creation_spell_selection).valid,"Worker-style draft/slot/transcript/text snapshot validates without a live TalkText owner")
	frozen.text.raw({"strRef":999});check(not frozen.text.is_complete() and not Validation.verify(worker,worker.creation_spell_text,worker.creation_spell_selection).ready,"An incomplete detached text snapshot remains explicitly unavailable")
	var changed: Dictionary=rules.tables.spells.duplicate(true);changed.orderedRows[1].SERVER_CAST="9";rules.tables.spells=changed
	check(not session.read(rules,text,identity).ready and not Validation.verify(rules,text,rules.creation_spell_selection).valid,"Replacing active spell rules invalidates incompatible recorded choices instead of silently rebuilding another book")
	check(is_same(worker.tables.spells,rules.tables.spells)==false,"The worker's publication map remains pinned to its original table objects")
	session.close();rules=selection_rules();text=selection_text();session.begin(rules,text,identity);result=session.edit("recommend",-1,rules,text,identity)
	check(result.ready and rules.draft.known[1]==[1] and session.state.remaining==4 and session.state.can_accept(),"Current Package preference and native fallback drive actual session recommendation",result)
	check(session.commit(rules,text,identity).get("accepted",false) and Validation.verify(rules,text,rules.creation_spell_selection).valid,"Recommended choices replay against current active metadata at commit")
	rules.creation_spell_slots.erase(1);check(not Validation.verify(rules,text,rules.creation_spell_selection).ready,"Missing school cache does not invent zero preparation slots")
	rules=selection_rules();session.close();session.begin(rules,text,identity);session.edit("add",1,rules,text,identity);session.edit("reset",-1,rules,text,identity)
	check(rules.draft.known[1].is_empty() and session.state.remaining==5 and rules.creation_spell_selection.events==[{"operation":"reset"}],"Reset restores the original baseline and compacts irrelevant prior edits")
	rules.reset_choices();check(not rules.draft.has("sourceSpellChoices") and rules.creation_spell_selection.is_empty() and rules.creation_spell_text==null,"Derived reset retires the completed/source marker, transcript and text owner")
	session.close();check(not session.state.ready and session.owner==null and session.scope.is_empty(),"Closing native selection retires its private scope, counters and weak owner")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual native Rules-backed first-level spell selection, transcript/recommendation replay, owned-book and school-cache commit, metadata/scope/mutation guards and detached worker-style text/table/draft data. No real creator controls, actual BIC worker/server upload or original pixels acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
