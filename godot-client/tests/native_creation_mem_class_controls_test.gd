extends "res://tests/native_creation_class_controls_test.gd"
var recommended:=false
func configure_active_catalog(base,active,args: Dictionary) -> void:
	recommended=str(args["class"]).ends_with("-recommended")
	var parser:=preload("res://systems/native_data/two_da.gd").new();var raw:=parser.parse(base.get_resource("classes",2017).get_string_from_utf8());var selected:=-1
	for id in raw.orderedRows.size():
		if str(preload("res://systems/native_data/game_ui_rules.gd").cell(raw.orderedRows[id],"Label","")).to_lower()=="wizard":selected=id;break
	if not check(selected>=0,"Controlled memorizing/non-scroll case uses the actual active physical Wizard row"):return
	var table: Dictionary=preload("res://tests/native_creation_fixture_tables.gd").row_update(raw,selected,{"MemorizesSpells":"1","LearnScroll":"0","SpellKnownTable":"fixture_memknown"})
	var directory:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(directory)
	var content:="2DA V2.0\nDEFAULT: "+str(table.get("defaultValue","****"))+"\n"+" ".join(table.columns)+"\n"
	for row in table.orderedRows.size():content+=str(table.rowLabels[row])+" "+" ".join(table.orderedCells[row])+"\n"
	var file:=FileAccess.open(directory.path_join("classes.2da"),FileAccess.WRITE);file.store_string(content);file.close()
	file=FileAccess.open(directory.path_join("fixture_memknown.2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nNumSpellLevels SpellLevel0 SpellLevel1\n0 2 0 1\n");file.close()
	check(active.mount_directory(directory,100000001),"Actual private active class/known resources override installed defaults without mutating raw catalog tables")
	args["class"]="wizard"
func source_fields(document: Dictionary,rules,expected: Dictionary) -> void:
	super.source_fields(document,rules,expected)
	check(rules.num(rules.cls(),"MemorizesSpells")==1 and rules.num(rules.cls(),"LearnScroll")==0,"Current source controller retains independent actual class flags")
	check(rules.draft.known.get(0,[]).is_empty(),"Neither original custom route injects scroll-learning cantrips")
	# Original9ce190 initializes non-scroll manual selection from known
	# capacity. The separate preference helper7eb630 instead branches on
	# MemorizesSpells and uses3+INT at first level, independently of LearnScroll.
	var count: int=3+maxi(0,rules.modifier(int(rules.abilities().Int))) if recommended else 1
	check(rules.draft.known.get(1,[]).size()==count,"Actual Recommended preserves original memorizing budget independent of LearnScroll" if recommended else "Actual manual spell arrows use the original known capacity1")
	check(not document.root.ClassList[0].has("KnownList0") and document.root.ClassList[0].get("KnownList1",[]).size()==count,"Full typed BIC preserves the exact distinct original non-scroll book")
