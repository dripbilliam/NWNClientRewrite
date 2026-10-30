extends SceneTree
const Spells=preload("res://systems/native_data/pregame_spells.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var fixture:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): fixture=arg.substr(9)
	if output.is_empty() or fixture.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==72,"Spell oracle pins72 original pregame ability/gain/SetData/AddKnown executions")
	for index in original.rows.size():
		var row: Dictionary=original.rows[index]; var before:=JSON.stringify(row.case); var result:=Spells.compute(row.case.source,row.case.tables)
		check(result.ready and result.errors.is_empty() and result.dependencies.is_empty(),"Native pregame spell dependencies are complete in original case %d"%index)
		check(result.minimums==row.minimums and result.slots==row.slots.map(func(values):return values.map(func(value):return int(value))),"Original spell minimum/gain/specialization/prestige behavior matches case %d"%index)
		var captured: Array=[]
		for entry in result.entries:
			var data: Dictionary=row.case.tables.spells.orderedRows[int(entry.id)] if not entry.summary else {}
			captured.append({"id":int(entry.id),"nameRef":int(entry.nameRef) if entry.summary else int(data.Name),"icon":str(entry.icon) if entry.summary else str(data.IconResRef).to_lower()})
		check(captured==row.captured.map(func(entry):return {"id":int(entry.id),"nameRef":int(entry.nameRef),"icon":entry.icon}),"Complete original summary/known row enumeration matches case %d"%index)
		check(JSON.stringify(row.case)==before,"Spell display leaves original BIC/table sources unchanged: case %d"%index)
	var writer:=Writer.new(); var parser:=Gff.new()
	var fields:={"ClassList":Writer.field(15,[Writer.record({"Class":Writer.field(5,0),"ClassLevel":Writer.field(3,4),"School":Writer.field(0,3),"KnownList0":Writer.field(15,[Writer.record({"Spell":Writer.field(2,4)}),Writer.record({"Spell":Writer.field(5,9)}),Writer.record({"Spell":Writer.field(2,4)})]),"KnownList9":Writer.field(15,[Writer.record({"Spell":Writer.field(2,2)})])})])}
	var document:=parser.parse(writer.write("BIC ",Writer.record(fields)),"BIC "); check(parser.failure.is_empty(),"Native typed spell-source fixture parses as a BIC")
	var source:=Spells.source(document,Skills.source(document))
	check(source.books==[{"known":[4,65535,4,2],"school":3}],"Original WORD spell fields preserve duplicates and import order while wrong types use FFFF")
	var tables: Dictionary=original.rows[0].case.tables.duplicate(true); var stats: Dictionary=original.rows[0].case.source.stats.duplicate(true); stats.classes=[{"id":0,"level":4}]
	for ability in Skills.KEYS: stats.abilities[ability]=18
	for data in tables.racialtypes.orderedRows:
		for ability in Skills.KEYS: data[ability+"Adjust"]=0
	for data in tables.sg0.orderedRows:
		for ability in Skills.KEYS: data[ability]=0
	tables.spells.orderedRows[4].Book0="2"; tables.spells.orderedRows[2].Book0="0"; source.stats=stats; var result:=Spells.compute(source,tables)
	check(result.entries.filter(func(entry):return not entry.summary).map(func(entry):return [entry.id,entry.level])==[[2,0],[4,2],[4,2]],"KnownList suffix does not override the active class spell column and duplicate spells remain distinct")
	check(not Spells.compute(source,{}).ready and not Spells.compute(source,{}).dependencies.is_empty(),"Unpublished rules keep Spells pending instead of showing invented rows")
	var default_doc:=parser.parse(writer.write("BIC ",Writer.record({})),"BIC "); var defaults:=Spells.source(default_doc,Skills.source(default_doc))
	check(defaults.books==[{"known":[],"school":0}],"Missing book data retains the source default class with an empty known list and school")
	var excessive: Dictionary=source.duplicate(true); excessive.books[0].known=[]
	for at in 256: excessive.books[0].known.append(4)
	check(not Spells.compute(excessive,tables).ready,"Beyond-byte-width known-row loops stay unavailable rather than hanging the native UI")
	var malformed: Dictionary=source.duplicate(true); malformed.error="Invalid source"
	check(not Spells.compute(malformed,tables).ready,"An invalid raw spell source cannot produce a successful preview")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"native_only":true,"fullUiParity":false,"fullSpellUiParity":false,"fullGameplaySpellParity":false,"scope":"Original pregame minimum, slots, prestige and complete SetData/AddKnown admission oracle plus typed source/active-column regrouping. Rendered controls and full original-client comparison remain separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
