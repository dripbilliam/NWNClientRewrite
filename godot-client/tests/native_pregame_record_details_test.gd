extends SceneTree
const Details=preload("res://systems/native_data/pregame_record_details.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func parse(fields: Dictionary) -> Dictionary:
	var parser:=Gff.new(); var document:=parser.parse(Writer.new().write("BIC ",Writer.record(fields)),"BIC ")
	check(parser.failure.is_empty(),"Combat fixture is a typed native BIC")
	return Details.source(document)
func run() -> void:
	var output:=""; var oracle:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): oracle=arg.substr(9)
	if output.is_empty() or oracle.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle))
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==72,"Detail comparison pins72 complete original SetData executions")
	for index in original.rows.size():
		var row: Dictionary=original.rows[index]; var before:=JSON.stringify(row); var result:=Details.compute(row.source,row.tables,row.source.stats.classes)
		check(result.ready and result.dependencies.is_empty(),"Original detail case %d resolves active class BAB tables"%index)
		if index==0: print("CHARACTER_DETAIL_COMPARISON ",JSON.stringify({"native":Details.markup(result.entries,func(ref):return row.lookup[str(ref)]),"original":row.captured}))
		check(Details.markup(result.entries,func(ref):return row.lookup[str(ref)])==row.captured,"Exact original row enumeration, label punctuation, colors and numbers case %d"%index)
		check(JSON.stringify(row)==before,"Detail display does not change source fields or tables case %d"%index)
	var defaults:=parse({})
	check(defaults.savingThrows==[0,0,0] and defaults.combatPreview==[0,0,0],"Absent BIC saves and CombatInfo use original zero defaults")
	var typed:=parse({"FortSaveThrow":Writer.field(1,-128),"RefSaveThrow":Writer.field(1,127),"WillSaveThrow":Writer.field(1,-1),"CombatInfo":Writer.field(14,Writer.record({"SpellResistance":Writer.field(0,255),"ArcaneSpellFail":Writer.field(0,128),"ArmorCheckPen":Writer.field(0,9)}))})
	check(typed.savingThrows==[-128,127,-1] and typed.combatPreview==[255,128,9],"Original CHAR saves and BYTE CombatInfo values retain signed/unsigned widths")
	var wrong:=parse({"FortSaveThrow":Writer.field(0,99),"RefSaveThrow":Writer.field(3,12),"WillSaveThrow":Writer.field(5,-1),"CombatInfo":Writer.field(14,Writer.record({"SpellResistance":Writer.field(2,255),"ArcaneSpellFail":Writer.field(1,12),"ArmorCheckPen":Writer.field(5,9)}))})
	check(wrong.savingThrows==[0,0,0] and wrong.combatPreview==[0,0,0],"Same-valued fields with incompatible GFF types do not masquerade as original imported fields")
	var sample: Dictionary=original.rows[0].duplicate(true); var table: String=sample.tables.classes.orderedRows[int(sample.source.stats.classes[0].id)].AttackBonusTable; sample.tables.erase(table)
	check(not Details.compute(sample.source,sample.tables,sample.source.stats.classes).ready and Details.compute(sample.source,sample.tables,sample.source.stats.classes).dependencies.has(table),"Unpublished active BAB resources stay pending instead of using a generic class progression")
	check(not Details.compute(sample.source,{},sample.source.stats.classes).ready,"Missing class definitions keep detail values unavailable")
	var out:=FileAccess.open(output,FileAccess.WRITE); out.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"fullUiParity":false,"fullRecordParity":false,"native_only":true,"scope":"Complete original pregame detail text execution compared with native display projection, typed save/combat import and active class-table dependencies. Original UI drawing, input and non-pregame variants remain separate."},"  ")+"\n"); out.close(); quit(0 if failures.is_empty() else 1)
