extends SceneTree
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func parse(root_record: Dictionary) -> Dictionary:
	var parser:=Gff.new(); var doc:=parser.parse(Writer.new().write("BIC ",root_record),"BIC ")
	check(parser.failure.is_empty(),"Typed skill-source fixture is a native BIC document")
	return Skills.source(doc)
func run() -> void:
	var output:=""; var fixture:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): fixture=arg.substr(9)
	if output.is_empty() or fixture.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.rows.size()==72,"Skill arithmetic oracle pins the complete72-case original instruction fixture")
	for index in original.rows.size():
		var row: Dictionary=original.rows[index]; var before:=JSON.stringify(row.case); var value:=Skills.compute(row.case.source,row.case.tables)
		check(value.ready and value.errors.is_empty() and value.dependencies.is_empty(),"Original skill case %d has all active native dependencies"%index)
		check(value.classGains==row.classGains.map(func(v):return int(v)) and value.scores==row.scores.map(func(v):return int(v)),"Original per-class byte accumulation and total clamp match case %d"%index)
		check(value.values==row.values.map(func(v):return int(v)),"Original pregame skill values, modifiers and signed byte wrapping match case %d"%index)
		check(value.mask==int(row.mask) and value.entries==row.entries.map(func(v):return {"id":int(v.id),"value":int(v.value),"lostAbilities":v.lostAbilities}),"Original skill admission/mask aliasing matches case %d"%index)
		check(JSON.stringify(row.case)==before,"Skill display projection never mutates BIC or active table sources: case %d"%index)
	var defaults:=parse(Writer.record({}))
	check(defaults.race==6 and defaults.classes==[{"id":4,"level":1}] and defaults.ranks.is_empty() and defaults.abilities.values().all(func(v):return v==0),"Missing BIC fields use the source base-stats constructor defaults, not guessed ranks or ability scores")
	var typed:=parse(Writer.record({"Str":Writer.field(0,18),"Dex":Writer.field(5,99),"Race":Writer.field(0,2),"ClassList":Writer.field(15,[Writer.record({"Class":Writer.field(5,1),"ClassLevel":Writer.field(3,3)}),Writer.record({"Class":Writer.field(3,2),"ClassLevel":Writer.field(3,4)})]),"SkillList":Writer.field(15,[Writer.record({"Rank":Writer.field(0,255)}),Writer.record({"Rank":Writer.field(2,7)}),Writer.record({})])}))
	check(typed.abilities.Str==18 and typed.abilities.Dex==0 and typed.race==2,"Typed BYTE ability/race reads reject an integer with the wrong original field type")
	check(typed.classes==[{"id":1,"level":3}] and typed.ranks==[255,0,0],"Wrong-type/trailing invalid classes and wrong-type/missing rank fields follow original defaults")
	var zero:=parse(Writer.record({"Race":Writer.field(2,9),"ClassList":Writer.field(15,[Writer.record({"Class":Writer.field(5,1),"ClassLevel":Writer.field(3,0)})])}))
	check(zero.race==6 and zero.classes==[{"id":1,"level":1}],"Original BYTE race and nonzero class-level setter retain constructor defaults on incompatible fields")
	var test_source: Dictionary=original.rows[2].case.source.duplicate(true); var tables: Dictionary=original.rows[2].case.tables.duplicate(true); test_source.classes=[{"id":0,"level":3}]; tables.erase("sg0"); tables.erase("sk0")
	check(not Skills.compute(test_source,{}).ready and Skills.dependencies(test_source,{})==["classes","racialtypes","skills","ruleset"],"Unpublished base rule tables keep Skills pending instead of briefly publishing empty or guessed values")
	check(not Skills.compute(test_source,tables).ready and Skills.dependencies(test_source,tables)==["sk0","sg0"],"Missing active class tables report dependencies instead of inventing preview values")
	test_source.classes=[{"id":250,"level":3}]
	check(Skills.dependencies(test_source,tables)==["sk0","sg0"],"Invalid original class IDs also prepare class-zero dependencies before the eligibility loop's source normalization")
	tables=original.rows[2].case.tables.duplicate(true); test_source.classes=[{"id":0,"level":61}]
	check(not Skills.compute(test_source,tables).ready and not Skills.compute(test_source,tables).errors.is_empty(),"Beyond-storage stat-gain levels remain unavailable instead of emulating invalid memory reads")
	test_source.classes=[{"id":0,"level":3}]; tables.ruleset={"orderedRows":[{"Label":"CHARGEN_ABILITY_MODIFIER_INCREMENT","Value":"0"}]}
	check(not Skills.compute(test_source,tables).ready,"Malformed zero-divisor ability rules never produce fabricated skill values")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"native_only":true,"fullSkillUiParity":false,"fullGameplaySkillParity":false,"fullUiParity":false,"scope":"Original pregame arithmetic/admission/byte-width oracle and typed BIC skill source extraction only. Skills tab, dynamic dependency loading, rendered controls and original-client comparison remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
