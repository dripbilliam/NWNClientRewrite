extends SceneTree
const Record=preload("res://systems/native_data/pregame_record.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func parse(fields: Dictionary) -> Dictionary:
	var parser:=Gff.new(); var doc:=parser.parse(Writer.new().write("BIC ",Writer.record(fields)),"BIC ")
	check(parser.failure.is_empty(),"Record fixture is a typed native BIC")
	return Record.source(doc,preload("res://systems/native_data/pregame_skills.gd").source(doc))
func run() -> void:
	var output:=""; var fixture:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): fixture=arg.substr(9)
	if output.is_empty() or fixture.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==72,"Comparison pins the72-case original numeric-prefix instruction oracle")
	for index in original.rows.size():
		var row: Dictionary=original.rows[index]; var before:=JSON.stringify(row); var value:=Record.compute(row.source,row.tables)
		check(value.ready and value.errors.is_empty() and value.dependencies.is_empty(),"Original record case %d resolves its active dependencies"%index)
		if not value.ready: continue
		for ability in 6:
			check(str(value.abilities[ability].score)==row.captured[str(0x210+ability*0x130)] and str(value.abilities[ability].modifier)==row.captured[str(0x2a8+ability*0x130)],"Original record score and modifier case %d ability %d"%[index,ability])
		check(str(value.currentHP)+"/"+str(value.maximumHP)==row.captured[str(0x940)] and str(value.armorClass)==row.captured.ac,"Original signed HP/current/AC labels case %d"%index)
		check("XP label: "+str(value.experience)==row.captured[str(0xf30)] and "Next label: "+("Maximum label" if value.nextMaximumRef>=0 else str(value.nextExperience))==row.captured[str(0xfc8)],"Original localized signed XP and level40 boundary case %d"%index)
		check(value.alignmentRef==int(row.alignmentRef),"Original alignment thresholds case %d"%index)
		check(JSON.stringify(row)==before,"Preview never changes imported data or active tables case %d"%index)
	var defaults:=parse({})
	check(defaults.armorClass==0 and defaults.maximumHP==0 and defaults.currentHP==0 and defaults.experience==0 and defaults.goodEvil==85 and defaults.lawChaos==15,"Missing fields retain the actual base-stats constructor defaults including alignment")
	var typed:=parse({"ArmorClass":Writer.field(3,-2),"HitPoints":Writer.field(3,12),"CurrentHitPoints":Writer.field(3,6),"MaxHitPoints":Writer.field(3,40),"PregameCurrent":Writer.field(3,17),"Experience":Writer.field(4,4294967295),"GoodEvil":Writer.field(0,255),"LawfulChaotic":Writer.field(0,70),"Subrace":Writer.field(10,"Server subrace")})
	check(typed.armorClass==-2 and typed.maximumHP==40 and typed.currentHP==17 and typed.experience==4294967295,"Strict SHORT/DWORD BIC reads preserve signed values and the distinct PregameCurrent field")
	check(typed.goodEvil==100 and typed.lawChaos==70 and typed.subrace=="Server subrace","Original BYTE alignment clamp and CExoString subrace import")
	var wrong:=parse({"ArmorClass":Writer.field(5,99),"MaxHitPoints":Writer.field(3,40),"PregameCurrent":Writer.field(2,17),"CurrentHitPoints":Writer.field(3,6),"Experience":Writer.field(5,123),"GoodEvil":Writer.field(2,0),"Subrace":Writer.field(11,"wrong_type")})
	check(wrong.armorClass==0 and wrong.maximumHP==40 and wrong.currentHP==40 and wrong.experience==0 and wrong.goodEvil==85 and wrong.subrace.is_empty(),"Wrong-type fields use original defaults; maximum HP supplies absent/wrong-type PregameCurrent")
	var sample: Dictionary=original.rows[0].duplicate(true); sample.tables.erase("exptable")
	check(not Record.compute(sample.source,sample.tables).ready and Record.compute(sample.source,sample.tables).dependencies.has("exptable"),"Missing active XP resource stays pending instead of inventing a value")
	sample=original.rows[0].duplicate(true); sample.tables.exptable={"orderedRows":[]}
	check(not Record.compute(sample.source,sample.tables).ready and not Record.compute(sample.source,sample.tables).errors.is_empty(),"Malformed active XP data reports unavailable instead of guessing a next-level threshold")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"native_only":true,"fullRecordParity":false,"fullUiParity":false,"scope":"Original Character numeric-prefix/threshold oracle and strict typed BIC display import. Heading text, full combat details, rendered input and original-client visual comparison require separate acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
